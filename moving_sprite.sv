module moving_sprite #(
    parameter SPR_WIDTH    = 19,   // width in pixels
    parameter SPR_HEIGHT   = 27,   // number of lines
    parameter SPR_FRAMES   = 3,    // number of frames in graphic

    parameter COLR_BITS    = 8,    // bits per pixel
    parameter SPR_TRANS    = 8'hFF,    // transparent palette entry
    
    parameter SPR_FILE     = "main_character.mem",
    parameter SPR_PALETTE  = "main_character_palette.mem",

    parameter POS_DIGIT    = 4 * 4,

    parameter CORDW        = 16,

    parameter H_RES        = 800,
    parameter V_RES        = 600
    ) (
        input  i_clk_pix,
        input  i_rst_n,
        input  i_frame,
        input  i_line,
        input  signed [CORDW-1:0] i_sx,
        input  signed [CORDW-1:0] i_sy,
        
        input [4:0] i_scale_x,    // width scale-factor
        input [4:0] i_scale_y,    // height scale-factor
        input i_face_left,
        input i_walking,
        input i_jumping,

        input signed [CORDW-1:0] i_sprx,
        input signed [CORDW-1:0] i_spry,

        output o_trans,
        output o_drawing,
        output [23:0] o_color
    );
    
    localparam SPR_PIXELS = SPR_WIDTH * SPR_HEIGHT;
    localparam SPR_DEPTH  = SPR_PIXELS * SPR_FRAMES;
    localparam SPR_ADDRW  = $clog2(SPR_DEPTH);

    logic spr_start, spr_drawing;
    logic [COLR_BITS-1:0] spr_pix;

    // ANCHOR sprite graphic ROM
    logic [COLR_BITS-1:0] spr_rom_data;
    logic [SPR_ADDRW-1:0] spr_rom_addr, spr_base_addr;
    rom_sync #(
        .WIDTH(COLR_BITS),
        .DEPTH(SPR_DEPTH),
        .INIT_F(SPR_FILE)
    ) spr_rom (
        .clk(i_clk_pix),
        .addr(spr_base_addr + spr_rom_addr),
        .data(spr_rom_data)
    );

    // ANCHOR sprite frame selector
    logic [5:0] cnt_anim;  // count from 0-63
    always_ff @(posedge i_clk_pix) begin
        if (i_frame) begin
            // select sprite frame
            cnt_anim <= 0;
            spr_base_addr <= 0;
            if (i_walking || i_jumping) begin
                cnt_anim <= cnt_anim + 1;
                if (i_jumping) begin
                    case (cnt_anim[2:0])
                        0: spr_base_addr <= 0;
                        2: spr_base_addr <= SPR_PIXELS;
                        4: spr_base_addr <= 0;
                        6: spr_base_addr <= 2 * SPR_PIXELS;
                        default: spr_base_addr <= spr_base_addr;
                    endcase
                end else begin // jumping
                    case (cnt_anim)
                        0: spr_base_addr <= 0;
                        15: spr_base_addr <= SPR_PIXELS;
                        31: spr_base_addr <= 0;
                        47: spr_base_addr <= 2 * SPR_PIXELS;
                        default: spr_base_addr <= spr_base_addr;
                    endcase
                end
            end
        end
    end

    // ANCHOR signal to start sprite drawing
    always_comb spr_start = (i_line && i_sy == i_spry);

    sprite #(
        .WIDTH(SPR_WIDTH),
        .HEIGHT(SPR_HEIGHT),
        .COLR_BITS(COLR_BITS),
        .ADDRW(SPR_ADDRW)
        ) spr_instance (
        .i_clk(i_clk_pix),
        .i_rst_n(i_rst_n),
        .i_start(spr_start),
        .i_sx(i_sx),
        .i_sprx(i_sprx),
        .i_data_in(spr_rom_data),
        .i_face(i_face_left),
        .i_scale_x(i_scale_x),
        .i_scale_y(i_scale_y),

        .o_pos(spr_rom_addr),
        .o_pix(spr_pix),
        .o_drawing(spr_drawing),
        .o_done()
    );

    // ANCHOR colour lookup table (ROM)
    logic [23:0] clut_colr;
    rom_async #(
        .WIDTH(24),
        .DEPTH(256),
        .INIT_F(SPR_PALETTE)
    ) clut (
        // .clk(i_clk_pix),
        .addr(spr_pix),
        .data(clut_colr)
    );

    // ANCHOR map sprite colour index to palette using CLUT and incorporate background
    logic spr_trans;  // sprite pixel transparent?
    logic [7:0] red_spr, green_spr, blue_spr;  // sprite colour components
    logic [7:0] red, green, blue;              // final colour
    always_comb begin
        spr_trans = (spr_pix == SPR_TRANS);
        {red_spr, green_spr, blue_spr} = clut_colr;
        red   = (spr_drawing && !spr_trans) ? red_spr   : 8'hFF;
        green = (spr_drawing && !spr_trans) ? green_spr : 8'h00;
        blue  = (spr_drawing && !spr_trans) ? blue_spr  : 8'hFF;
    end

    always_comb begin
        o_drawing   = spr_drawing;
        o_trans     = spr_trans;
        o_color     = {red, blue, green};
    end
endmodule
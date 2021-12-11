module top_sprite (
    input  wire logic i_clk_pix,
    input  wire logic i_rst_n,
    input  wire logic i_key_0,
    input  wire logic i_sw_0,

    output      logic vga_hsync,    // horizontal sync
    output      logic vga_vsync,    // vertical sync
    output      logic vga_blank_n,
    output      logic vga_sync_n,
    output      logic [7:0] vga_r,  // 8-bit VGA red
    output      logic [7:0] vga_g,  // 8-bit VGA green
    output      logic [7:0] vga_b,   // 8-bit VGA blue

    output      logic [4:0] qx_hex,
    output      logic [4:0] qy_hex
    );

    localparam H_RES_FULL = 1056;
    localparam V_RES_FULL = 628;
    localparam H_RES      = 800;
    localparam V_RES      = 600;

    // ANCHOR display sync signals and coordinates
    localparam CORDW = 16;  // screen coordinate width in bits
    logic signed [CORDW-1:0] sx, sy;
    logic hsync, vsync, de, frame, line;
    display_signal #(
        .CORDW(CORDW),
        .H_RES(H_RES),  // horizontal resolution (pixels)
        .V_RES(V_RES),  // vertical resolution (lines)
        .H_FP(40),      // horizontal front porch
        .H_SYNC(128),   // horizontal sync
        .H_BP(88),      // horizontal back porch
        .V_FP(1),       // vertical front porch
        .V_SYNC(4),     // vertical sync
        .V_BP(23),      // vertical back porch
        .H_POL(1),      // horizontal sync polarity (0:neg, 1:pos)
        .V_POL(1)       // vertical sync polarity (0:neg, 1:pos)
        ) display_inst (
        .clk_pix(i_clk_pix),
        .rst_n(i_rst_n),
        .sx,
        .sy,
        .hsync,
        .vsync,
        .de,
        .frame,
        .line
    );

    //===============================================================
    // ANCHOR moving sprite
    localparam SPR_WIDTH    = 32;   // width in pixels
    localparam SPR_HEIGHT   = 20;   // number of lines
    localparam SPR_FRAMES   = 3;    // number of frames in graphic

    localparam SPR_SCALE_X  = 2;    // width scale-factor
    localparam SPR_SCALE_Y  = 2;    // height scale-factor

    localparam COLR_BITS    = 4;    // bits per pixel (2^4=16 colours)
    localparam SPR_TRANS    = 9;    // transparent palette entry
    
    localparam SPR_FILE     = "hedgehog_walk.mem";
    localparam SPR_PALETTE  = "hedgehog_palette.mem";

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

    // ANCHOR draw sprite at position
    localparam SPR_SPEED_X = 2;
    logic signed [CORDW-1:0] sprx, spry;

    // ANCHOR sprite frame selector
    logic [5:0] cnt_anim;  // count from 0-63
    always_ff @(posedge i_clk_pix) begin
        if (frame) begin
            // select sprite frame
            cnt_anim <= cnt_anim + 1;
            case (cnt_anim)
                0: spr_base_addr <= 0;
                15: spr_base_addr <= SPR_PIXELS;
                31: spr_base_addr <= 0;
                47: spr_base_addr <= 2 * SPR_PIXELS;
                default: spr_base_addr <= spr_base_addr;
            endcase

            // walk right-to-left: -132 covers sprite width and within blanking
            sprx <= (sprx > -132) ? sprx - SPR_SPEED_X : H_RES;
        end
        if (!i_rst_n) begin
            sprx <= H_RES;
            spry <= 240;
        end
    end

    // ANCHOR signal to start sprite drawing
    always_comb spr_start = (line && sy == spry);

    sprite #(
        .WIDTH(SPR_WIDTH),
        .HEIGHT(SPR_HEIGHT),
        .COLR_BITS(COLR_BITS),
        .SCALE_X(SPR_SCALE_X),
        .SCALE_Y(SPR_SCALE_Y),
        .ADDRW(SPR_ADDRW)
        ) spr_instance (
        .i_clk(i_clk_pix),
        .i_rst_n(i_rst_n),
        .i_start(spr_start),
        .i_sx(sx),
        .i_sprx(sprx),
        .i_data_in(spr_rom_data),

        .o_pos(spr_rom_addr),
        .o_pix(spr_pix),
        .o_drawing(spr_drawing),
        .o_done()
    );

    // ANCHOR background colour
    logic [11:0] bg_colr;
    always_ff @(posedge i_clk_pix) begin
        if (line) begin
            if      (sy == 0)   bg_colr <= 12'h239;
            else if (sy == 80)  bg_colr <= 12'h24A;
            else if (sy == 140) bg_colr <= 12'h25B;
            else if (sy == 190) bg_colr <= 12'h26C;
            else if (sy == 230) bg_colr <= 12'h27D;
            else if (sy == 265) bg_colr <= 12'h29E;
            else if (sy == 295) bg_colr <= 12'h2BF;
            else if (sy == 320) bg_colr <= 12'h260;
        end
    end

    // ANCHOR colour lookup table (ROM) 11x12-bit entries
    logic [11:0] clut_colr;
    rom_async #(
        .WIDTH(12),
        .DEPTH(11),
        .INIT_F(SPR_PALETTE)
    ) clut (
        .addr(spr_pix),
        .data(clut_colr)
    );

    // ANCHOR map sprite colour index to palette using CLUT and incorporate background
    logic spr_trans;  // sprite pixel transparent?
    logic [3:0] red_spr, green_spr, blue_spr;  // sprite colour components
    logic [3:0] red_bg,  green_bg,  blue_bg;   // background colour components
    logic [7:0] red, green, blue;              // final colour
    always_comb begin
        spr_trans = (spr_pix == SPR_TRANS);
        {red_spr, green_spr, blue_spr} = clut_colr;
        {red_bg,  green_bg,  blue_bg}  = bg_colr;
        red[7:4]   = (spr_drawing && !spr_trans) ? red_spr   : red_bg;
        green[7:4] = (spr_drawing && !spr_trans) ? green_spr : green_bg;
        blue[7:4]  = (spr_drawing && !spr_trans) ? blue_spr  : blue_bg;
    end

    // ANCHOR VGA output
    always_ff @(posedge i_clk_pix) begin
        vga_hsync <= hsync;
        vga_vsync <= vsync;
        vga_blank_n <= de;
        vga_sync_n  <= 1;
        vga_r <= de ? red   : 8'h0;
        vga_g <= de ? green : 8'h0;
        vga_b <= de ? blue  : 8'h0;
    end
endmodule
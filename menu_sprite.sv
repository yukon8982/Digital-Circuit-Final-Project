module menu_sprite #(
    parameter SPR_WIDTH    = 19,   // width in pixels
    parameter SPR_HEIGHT   = 27,   // number of lines
    parameter SPR_FRAMES   = 3,    // number of frames in graphic

    parameter SPR_SCALE_X  = 2,    // width scale-factor
    parameter SPR_SCALE_Y  = 2,    // height scale-factor

    parameter COLR_BITS    = 8,    // bits per pixel
    parameter SPR_TRANS    = 8'hFF,    // transparent palette entry
    
    parameter SPR_FILE     = "main_character.mem",
    parameter SPR_PALETTE  = "main_character_palette.mem",

    parameter POS_DIGIT    = 4 * 4;

    parameter CORDW        = 16;

    parameter H_RES        = 800,
    parameter V_RES        = 600
    ) (
        input  i_clk_pix,
        input  i_rst_n,
        input  [5:0] i_ctrl,
        input  i_frame,
        input  i_line,
        input  signed [CORDW-1:0] i_sx,
        input  signed [CORDW-1:0] i_sy,
        input  [15:0] i_speed,
        input  [POS_DIGIT-1:0] i_floor,
        input  [POS_DIGIT-1:0] i_char_pos,

        output signed [CORDW-1:0] o_spry,
        output o_trans,
        output o_drawing,
        output [23:0] o_color
    );
    
    localparam SPR_PIXELS = SPR_WIDTH * SPR_HEIGHT;
    localparam SPR_DEPTH  = SPR_PIXELS * SPR_FRAMES;
    localparam SPR_ADDRW  = $clog2(SPR_DEPTH);
    localparam SPR_TRUE_HEIGHT = SPR_HEIGHT * SPR_SCALE_Y;

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
    logic signed [CORDW-1:0] sprx, spry;
    logic spr_face;

    assign o_spry = spry;
    // ANCHOR sprite x movement FSM
    enum {
        IDLE_movement_x,       
        LEFT_movement_x,
        RIGHT_movement_x
    } state_movement_x, state_movement_x_next;

    always_ff @(posedge i_clk_pix) begin
        state_movement_x <= state_movement_x_next;
        if (i_frame) begin
            case (state_movement_x)
                LEFT_movement_x: begin
                    // sprx <= (sprx > -150) ? sprx - i_speed : H_RES;
                    spr_face <= 1;
                end
                RIGHT_movement_x: begin
                    // sprx <= (sprx < H_RES+150) ? sprx + i_speed : -(SPR_WIDTH*SPR_SCALE_X);
                    spr_face <= 0;
                end
            endcase
        end

        if (!i_rst_n) begin
            state_movement_x <= IDLE_movement_x;
            sprx <= i_char_pos;
            spr_face <= 0;
        end
    end

    logic [1:0] move_ctrl_x;
    assign move_ctrl_x = i_ctrl[1:0];
    always_comb begin
        casez (move_ctrl_x) // up before down, right before left
            2'b1?: state_movement_x_next = RIGHT_movement_x;
            2'b?1: state_movement_x_next = LEFT_movement_x;
            default: state_movement_x_next = IDLE_movement_x;
        endcase
    end

    // ANCHOR sprite y movement FSM
    enum {
        IDLE_movement_y,       
        JUMP_movement_y,
        FALL_movement_y
    } state_movement_y, state_movement_y_next;

    parameter JUMP_HEIGHT = 20; // frame
    logic [15:0] cnt_jump, cnt_fall;
    always_ff @(posedge i_clk_pix) begin
        state_movement_y <= state_movement_y_next;
        if (i_frame) begin
            case (state_movement_y)
                IDLE_movement_y: begin
                    cnt_jump <= 1;
                    cnt_fall <= 0;
                    spry <= V_RES-i_floor-SPR_TRUE_HEIGHT;
                end
                JUMP_movement_y: begin
                    cnt_jump <= cnt_jump + 1;
                    spry <= spry + (cnt_jump - JUMP_HEIGHT);
                end
                FALL_movement_y: begin
                    cnt_fall <= cnt_fall + 1;
                    spry <= spry + (cnt_fall);
                end
            endcase
        end

        if (!i_rst_n) begin
            cnt_jump            <= 0;
            cnt_fall            <= 0;
            state_movement_y    <= FALL_movement_y;
            spry                <= -200;
        end
    end

    logic move_ctrl_jump_y;
    assign move_ctrl_jump_y = i_ctrl[4];
    always_comb begin
        case(state_movement_y)
            IDLE_movement_y: state_movement_y_next = (move_ctrl_jump_y) ? JUMP_movement_y :
                                                     (spry < V_RES-i_floor-SPR_TRUE_HEIGHT) ? FALL_movement_y : 
                                                     IDLE_movement_y;
            JUMP_movement_y: state_movement_y_next = (cnt_jump == JUMP_HEIGHT) ? FALL_movement_y : JUMP_movement_y;
            FALL_movement_y: state_movement_y_next = (spry+cnt_fall < V_RES-i_floor-SPR_TRUE_HEIGHT) ? FALL_movement_y : IDLE_movement_y;
        endcase
    end

    // ANCHOR sprite frame selector
    logic [5:0] cnt_anim;  // count from 0-63
    always_ff @(posedge i_clk_pix) begin
        if (i_frame) begin
            // select sprite frame
            if ((state_movement_x == IDLE_movement_x)&&(state_movement_y == IDLE_movement_y)) begin
                cnt_anim <= 0;
                spr_base_addr <= 0;
            end else begin
                cnt_anim <= cnt_anim + 1;
                if (state_movement_y == IDLE_movement_y) begin
                    case (cnt_anim)
                        0: spr_base_addr <= 0;
                        15: spr_base_addr <= SPR_PIXELS;
                        31: spr_base_addr <= 0;
                        47: spr_base_addr <= 2 * SPR_PIXELS;
                        default: spr_base_addr <= spr_base_addr;
                    endcase
                end else begin // jumping
                    case (cnt_anim[2:0])
                        0: spr_base_addr <= 0;
                        2: spr_base_addr <= SPR_PIXELS;
                        4: spr_base_addr <= 0;
                        6: spr_base_addr <= 2 * SPR_PIXELS;
                        default: spr_base_addr <= spr_base_addr;
                    endcase
                end

            end
        end
    end

    // ANCHOR signal to start sprite drawing
    always_comb spr_start = (i_line && i_sy == spry);

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
        .i_sx(i_sx),
        .i_sprx(sprx),
        .i_data_in(spr_rom_data),
        .i_face(spr_face),

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
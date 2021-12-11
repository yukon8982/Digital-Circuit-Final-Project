module top (
    input  wire logic i_clk_pix,
    input  wire logic i_rst_n,
    input  wire logic [2:0] i_key,
    input  wire logic [17:0] i_sw,

    output      logic vga_hsync,    // horizontal sync
    output      logic vga_vsync,    // vertical sync
    output      logic vga_blank_n,
    output      logic vga_sync_n,
    output      logic [7:0] vga_r,  // 8-bit VGA red
    output      logic [7:0] vga_g,  // 8-bit VGA green
    output      logic [7:0] vga_b   // 8-bit VGA blue
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
    // ANCHOR main character sprite
    logic [15:0] main_chara_speed;
    logic main_chara_trans, main_chara_drawing;
    logic [7:0] main_chara_red, main_chara_blue, main_chara_green;
    assign main_chara_speed = 4;
    moving_sprite #(
        .SPR_WIDTH       ( 19 ),
        .SPR_HEIGHT      ( 27 ),
        .SPR_FRAMES      ( 3 ),
        .SPR_SCALE_X     ( 4 ),
        .SPR_SCALE_Y     ( 4 ),
        .COLR_BITS       ( 8 ),
        .SPR_TRANS       ( 8'hFF ),
        .SPR_FILE        ( "main_character.mem" ),
        .SPR_PALETTE     ( "main_character_palette.mem" ),
        .CORDW           ( CORDW ),
        .H_RES           ( H_RES ),
        .V_RES           ( V_RES )
        ) sprite_main_character(
        .i_clk_pix ( i_clk_pix ),
        .i_rst_n   ( i_rst_n   ),
        .i_ctrl    ( {i_key[0], i_sw[4:1]} ),
        .i_frame   ( frame   ),
        .i_line    ( line    ),
        .i_sx      ( sx      ),
        .i_sy      ( sy      ),
        .i_speed   ( main_chara_speed),

        .o_trans   ( main_chara_trans   ),
        .o_drawing ( main_chara_drawing ),
        .o_red     ( main_chara_red     ),
        .o_blue    ( main_chara_blue    ),
        .o_green   ( main_chara_green   )
    );

    // ANCHOR background colour
    logic [23:0] bg_colr;
    assign bg_colr = 24'h6BE9F2;

    // ANCHOR map sprite colour index to palette using CLUT and incorporate background
    logic [7:0] red_bg,  green_bg,  blue_bg;   // background colour components
    logic [7:0] red, green, blue;              // final colour
    always_comb begin
        {red_bg,  green_bg,  blue_bg}  = bg_colr;
        red   = (main_chara_drawing && !main_chara_trans) ? main_chara_red   : red_bg;
        green = (main_chara_drawing && !main_chara_trans) ? main_chara_green : green_bg;
        blue  = (main_chara_drawing && !main_chara_trans) ? main_chara_blue  : blue_bg;
    end

    //===============================================================
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
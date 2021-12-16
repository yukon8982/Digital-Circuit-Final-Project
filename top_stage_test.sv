module top (
    input       i_clk_pix,
    input       i_rst_n,
    input       [2:0] i_key,
    input       [17:0] i_sw,

    output [4:0] HEX_0,

    output      vga_hsync,    // horizontal sync
    output      vga_vsync,    // vertical sync
    output      vga_blank_n,
    output      vga_sync_n,
    output      [7:0] vga_r,  // 8-bit VGA red
    output      [7:0] vga_g,  // 8-bit VGA green
    output      [7:0] vga_b   // 8-bit VGA blue
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
    logic main_start, main_ready, main_processing;
    logic main_drawing;
    logic [7:0] main_red, main_blue, main_green;

    main_game #(
        .STG_FILE   ( "stg.mem" ),
        .BLK_BITS   ( 4 * 13 ),
        .STG_DEPTH  ( 8 ),
        .POS_DIGIT  ( 4 * 4 ),
        .BUFFER_LEN ( 10 ),
        .MAP_LENGTH ( 10000 ),
        .CORDW      ( 16 ),
        .H_RES      ( 800 ),
        .V_RES      ( 600 )
        )main_game(
        .i_clk_pix  ( i_clk_pix  ),
        .i_rst_n    ( i_rst_n    ),
        .i_frame    ( frame    ),
        .i_line     ( line     ),
        .i_sx       ( sx       ),
        .i_sy       ( sy       ),
        .i_start    (main_start),
        .i_key      (i_key),
        .i_sw       (i_sw),
        .o_ready    (main_ready),
        .o_processing   (main_processing),
        .o_check_addr (HEX_0),
        .o_drawing  ( main_drawing  ),
        .o_red      (main_red),
        .o_blue     (main_blue),
        .o_green    (main_green)
    );
    //===============================================================
    logic menu_processing;
    logic menu_drawing;
    logic [7:0] menu_red, menu_blue, menu_green;

    menu #(
        .SPR_SCALE_X  ( 4 ),
        .SPR_SCALE_Y  ( 4 ),
        .SPR_WIDTH    ( 19 ),
        .SPR_HEIGHT   ( 27 ),
        .CORDW        ( CORDW ),
        .H_RES        ( H_RES ),
        .V_RES        ( V_RES )
        )menu(
        .i_clk_pix    ( i_clk_pix    ),
        .i_rst_n      ( i_rst_n      ),
        .i_frame      ( frame      ),
        .i_line       ( line       ),
        .i_sx         ( sx         ),
        .i_sy         ( sy         ),
        .i_key        ( i_key        ),
        .i_sw         ( i_sw         ),
        .i_main_ready ( main_ready ),
        .o_main_start ( main_start ),
        .o_drawing    ( menu_drawing    ),
        .o_processing ( menu_processing ),
        .o_red        ( menu_red        ),
        .o_blue       ( menu_blue       ),
        .o_green      ( menu_green      )
    );


    // ANCHOR background colour
    logic [23:0] bg_colr;
    assign bg_colr = 24'h6BE9F2;

    // ANCHOR determine color in different processing stage
    logic [7:0] red_bg,  green_bg,  blue_bg;   // background colour components
    logic [7:0] red, green, blue;              // final colour
    always_comb begin
        {red_bg,  green_bg,  blue_bg}  = bg_colr;
        red   = red_bg;
        green = green_bg;
        blue  = blue_bg;

        if (menu_processing) begin
            red   = (menu_drawing ) ? menu_red   : red_bg;
            green = (menu_drawing ) ? menu_green : green_bg;
            blue  = (menu_drawing ) ? menu_blue  : blue_bg;
        end
        else if (main_processing) begin
            red   = (main_drawing ) ? main_red   : red_bg;
            green = (main_drawing ) ? main_green : green_bg;
            blue  = (main_drawing ) ? main_blue  : blue_bg;
        end
        
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
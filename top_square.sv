module top_square (
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

    // display sync signals and coordinates
    localparam CORDW = 16;  // screen coordinate width in bits
    logic signed [CORDW-1:0] sx, sy;
    logic hsync, vsync, de, frame, line;
    display_480p #(
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
    // 32 x 32 (64 x 64) pixel square

    // moving square
    logic animate;  // high for one clock tick at start of vertical blanking
    always_comb animate = frame;

    localparam Q_SPEED = 4;     // pixels moved per frame
    logic signed [CORDW-1:0] qx, qy;   // square position
    assign qx_hex = {qx[10:6]};
    assign qy_hex = {qy[10:6]};
    logic [CORDW-1:0] Q_SIZE;

    // update square position once per frame
    always_ff @(posedge i_clk_pix) begin
        if (animate) begin
            if (qx >= H_RES - 1 - Q_SIZE) begin
                qx <= 0;
                qy <= (qy >= V_RES - 1 - Q_SIZE) ? 0 : qy + Q_SIZE;
            end else begin
                qx <= qx + Q_SPEED;
            end
        end
        if (!i_rst_n) begin
            qx <= 0;
            qy <= 0;
        end
    end

    // is square at current screen position?
    logic q_draw;
    always_comb begin
        Q_SIZE = (i_sw_0) ? 64 : 32;
        q_draw = (sx >= qx) && (sx < qx + Q_SIZE) && (sy >= qy) && (sy < qy + Q_SIZE);
    end 

    // VGA output
    always_ff @(posedge i_clk_pix) begin
        vga_hsync <= hsync;
        vga_vsync <= vsync;
        vga_blank_n <= de;
        vga_sync_n  <= 1;
        vga_r <= !de ? 8'h0 : (q_draw ? 8'hff : 8'h0);
        vga_g <= !de ? 8'h0 : (q_draw ? 8'h80 : 8'h80);
        vga_b <= !de ? 8'h0 : (q_draw ? 8'h0 : 8'hff);
    end
endmodule

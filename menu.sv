module menu #(
        parameter MAIN_SPR_WIDTH    = 19,
        parameter MAIN_SPR_HEIGHT   = 27,

        parameter CORDW        = 16,

        parameter H_RES        = 800,
        parameter V_RES        = 600
    ) (
        input                       i_clk_pix,
        input                       i_rst_n,

        input                       i_frame,
        input                       i_line,
        input  signed [CORDW-1:0]   i_sx,
        input  signed [CORDW-1:0]   i_sy,

        input  [2:0]                i_key,
        input  [17:0]               i_sw,

        input                       i_main_ready,
        
        output                      o_main_start,
        output                      o_drawing,
        output                      o_processing,
        output [7:0]                o_red,
        output [7:0]                o_blue,
        output [7:0]                o_green
    );
    
    localparam POS_DIGIT = 4*4;
    logic start;
    assign start = i_key[0];
    //main character sprite=====================================================
    logic [4:0] MAIN_SPR_SCALE_X, MAIN_SPR_SCALE_Y;

    logic [15:0] main_chara_speed;
    logic main_chara_trans, main_chara_drawing, main_jump;
    logic [23:0] main_chara_color;
    logic signed [POS_DIGIT-1:0] menu_floor;
    logic [POS_DIGIT-1:0] char_pos;
    assign menu_floor = 300;
    assign main_chara_speed = 4;
    assign char_pos = 400 - MAIN_SPR_WIDTH*MAIN_SPR_SCALE_X/2;
    menu_sprite #(
        .SPR_WIDTH       ( MAIN_SPR_WIDTH ),
        .SPR_HEIGHT      ( MAIN_SPR_HEIGHT ),
        .SPR_FRAMES      ( 3 ),
        .COLR_BITS       ( 8 ),
        .SPR_TRANS       ( 8'hFF ),
        .SPR_FILE        ( "main_character.mem" ),
        .SPR_PALETTE     ( "main_character_palette.mem" ),
        .POS_DIGIT       (POS_DIGIT),
        .CORDW           ( CORDW ),
        .H_RES           ( H_RES ),
        .V_RES           ( V_RES )
        ) sprite_main_character(
        .i_clk_pix ( i_clk_pix ),
        .i_rst_n   ( i_rst_n   ),
        .i_ctrl    ( {1'b0, (main_jump||start), 4'b0010} ), // right walking animation
        .i_frame   ( i_frame   ),
        .i_line    ( i_line    ),
        .i_sx      ( i_sx      ),
        .i_sy      ( i_sy      ),
        .i_scale_x  (MAIN_SPR_SCALE_X),
        .i_scale_y  (MAIN_SPR_SCALE_Y),
        .i_speed   ( main_chara_speed),
        .i_floor   ( menu_floor ),
        .i_char_pos (char_pos),

        .o_spry    (),
        .o_trans   ( main_chara_trans   ),
        .o_drawing ( main_chara_drawing ),
        .o_color   ( main_chara_color   ),
    );
    //menu control =====================================================
    enum {
        IDLE_menu,
        TRANSITION_menu,      
        TRANSITION_END_menu
    } state_menu, state_menu_next;

    logic [31:0] cnt_trans;
    logic [6:0]  cnt_scale;
    logic [4:0]  spr_scale;
     always_ff @(posedge i_clk_pix) begin
        state_menu <= state_menu_next;
        case(state_menu)
            IDLE_menu: begin
                cnt_trans <= 0;
                main_jump <= 0;
                if (i_frame) begin
                    cnt_scale <= (cnt_scale[6:2] == 31) ? 0 : cnt_scale + 1;
                    spr_scale <= 6;
                    // case(cnt_scale[6:2])
                    //     0:  spr_scale <= 6;
                    //     6:  spr_scale <= 5;
                    //     8:  spr_scale <= 4;
                    //     10:  spr_scale <= 3;
                    //     16:  spr_scale <= 2;
                    //     22:  spr_scale <= 3;
                    //     24:  spr_scale <= 4;
                    //     26:  spr_scale <= 5;
                    //     default: spr_scale <= 6;
                    // endcase
                end
            end
            TRANSITION_menu: begin
                o_main_start <= 1;
                cnt_scale <= 0;
                cnt_trans <= cnt_trans + 1; // for fadeout or animation or what

            end
            TRANSITION_END_menu: begin
                o_main_start <= 0;
            end
        endcase

        if (!i_rst_n) begin
            state_menu <= IDLE_menu;
            main_jump <= 0;
            o_main_start <= 0;
            cnt_trans <= 0;
            cnt_scale <= 0;
            spr_scale <= 6;
        end
     end


    always_comb begin
        state_menu_next = IDLE_menu;
        MAIN_SPR_SCALE_X = spr_scale;
        MAIN_SPR_SCALE_Y = spr_scale;

        case (state_menu)
            IDLE_menu:       state_menu_next = start ? TRANSITION_menu : IDLE_menu;
            TRANSITION_menu: state_menu_next = (i_main_ready && (cnt_trans >= 32'd60000000)) ? TRANSITION_END_menu : TRANSITION_menu;
            TRANSITION_END_menu:       state_menu_next = TRANSITION_END_menu;
        endcase
    end

    //======================================================
    always_comb begin
        o_processing = (state_menu != TRANSITION_END_menu);
        o_drawing = (   
                        (main_chara_drawing && !main_chara_trans)
                    );

        {o_red, o_blue, o_green} =  (main_chara_drawing && !main_chara_trans) ? main_chara_color :
                                    24'h00FFFF;
    end

endmodule
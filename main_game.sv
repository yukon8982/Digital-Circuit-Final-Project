module main_game #(
        parameter STG_FILE     = "stg.mem",

        parameter BLK_BITS     = 4 * 13,
        parameter STG_DEPTH    = 8,
        parameter POS_DIGIT    = 4 * 4,
        parameter BUFFER_LEN   = 10,

        parameter MAP_LENGTH   = 10000,

        parameter SPR_SCALE_X  = 4,
        parameter SPR_SCALE_Y  = 4,
        parameter SPR_WIDTH    = 19,
        parameter SPR_HEIGHT   = 27,

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
        input                       i_start,

        input  [2:0]                i_key,
        input  [17:0]               i_sw,
        
        output                      o_ready,
        output                      o_processing,
        output [4:0]                o_check_addr,
        output                      o_drawing,
        output [7:0]                o_red,
        output [7:0]                o_blue,
        output [7:0]                o_green
    );

    localparam STG_ADDRW  = $clog2(STG_DEPTH);
    logic [BLK_BITS-1:0] stg_rom_data;
    logic [STG_ADDRW-1:0] stg_addr;
    rom_async #(
        .WIDTH(BLK_BITS),
        .DEPTH(STG_DEPTH),
        .INIT_F(STG_FILE)
    ) stg_rom (
        .addr(stg_addr),
        .data(stg_rom_data)
    );

    logic [POS_DIGIT-1:0] char_pos;

    localparam MAP_W  = $clog2(MAP_LENGTH);
    localparam SPR_TRUE_WIDTH = SPR_WIDTH * SPR_SCALE_X;
    localparam SPR_TRUE_HEIGHT = SPR_HEIGHT * SPR_SCALE_Y;
    logic stg_drawing, stg_ready;
    logic signed [POS_DIGIT-1:0] stg_floor;
    logic [MAP_W-1:0] map_x;
    //stage ===================================================================================
    typedef struct packed{
        logic valid;
        logic [POS_DIGIT-1:0] left, right, height;
        logic [POS_DIGIT-1:0] stat;
    } block;

    enum {
        IDLE_stage,       
        LOADING_stage,      
        PLAY_stage        
    } state_stage, state_stage_next;
    logic ready;
    assign ready = (state_stage == PLAY_stage);

    logic load_fin, load_more;
    block buffer [BUFFER_LEN-1:0];
    logic [BUFFER_LEN-1:0] pix_in_blk;
    logic [$clog2(BUFFER_LEN)-1:0] blk_now;
    logic blk_on;

    logic [23:0] stg_color;
    assign stg_color = 24'h505050;

    always_ff @(posedge i_clk_pix) begin
        state_stage <= state_stage_next;

        case(state_stage)
            LOADING_stage: begin
                buffer[BUFFER_LEN-1:1] <= buffer[BUFFER_LEN-2:0];
                buffer[0] <= '{1'b1, stg_rom_data[BLK_BITS-1:BLK_BITS-POS_DIGIT], stg_rom_data[BLK_BITS-1-POS_DIGIT:BLK_BITS-2*POS_DIGIT], stg_rom_data[BLK_BITS-1-2*POS_DIGIT:BLK_BITS-3*POS_DIGIT], stg_rom_data[BLK_BITS-3*POS_DIGIT-1:0]};
                stg_addr <= (stg_addr == STG_DEPTH-1) ? 0 : stg_addr + 1;
                blk_now <= blk_now + 1;
            end
            PLAY_stage: begin
                o_ready <= 1;
                blk_now <=  (buffer[blk_now].right < (char_pos + 5*SPR_SCALE_X + map_x)) ? blk_now - 1 :
                            blk_now;
                blk_on  <=  (buffer[blk_now].left < (char_pos + 5*SPR_SCALE_X + map_x));
                if (load_more) begin
                    buffer[BUFFER_LEN-1:1] <= buffer[BUFFER_LEN-2:0];
                    buffer[0] <= '{1'b1, stg_rom_data[BLK_BITS-1:BLK_BITS-POS_DIGIT], stg_rom_data[BLK_BITS-1-POS_DIGIT:BLK_BITS-2*POS_DIGIT], stg_rom_data[BLK_BITS-1-2*POS_DIGIT:BLK_BITS-3*POS_DIGIT], stg_rom_data[BLK_BITS-3*POS_DIGIT-1:0]};
                    stg_addr <= (stg_addr == STG_DEPTH-1) ? 0 : stg_addr + 1;
                    blk_now <= blk_now + 1;
                end
            end
        endcase

        if (!i_rst_n) begin
            state_stage <= IDLE_stage;
            o_ready     <= 0;
            stg_addr    <= 0;
            blk_now     <= 0;
            blk_on      <= 0;
            buffer      <= '{BUFFER_LEN{'{'b0, 'b0, 'b0, 'b0, 'b0}}};
        end
    end

    logic signed [MAP_W-1:0] pix_x, pix_y;
    always_comb begin      
        state_stage_next  = IDLE_stage;
        pix_x       = map_x + i_sx;
        pix_y       = i_sy;

        load_fin = (buffer[0].valid && (buffer[0].left > H_RES));
        load_more = (buffer[0].left <= map_x + H_RES);
        for (int i = 0; i < BUFFER_LEN; i++) begin
            pix_in_blk[i] = ((buffer[i].valid) && 
                             (pix_x <= buffer[i].right) && // pix <= R
                             (pix_x >= buffer[i].left) && // L <= pix
                             (
                                 (~(buffer[i].stat[0]) && (pix_y >= (V_RES - buffer[i].height))) || // bottom blk
                                 ((buffer[i].stat[0]) && (pix_y <= buffer[i].height)) // top blk
                             ));
        end
        stg_drawing = |pix_in_blk;

        stg_floor   =   (blk_on) ? buffer[blk_now].height :
                        -5;

        case (state_stage)
            IDLE_stage:       state_stage_next = i_start ? LOADING_stage : IDLE_stage;
            LOADING_stage: begin
                state_stage_next = load_fin ? PLAY_stage : LOADING_stage;
            end    
            PLAY_stage:       state_stage_next = PLAY_stage;
        endcase
    end
    //main character sprite=====================================================
    logic [15:0] main_chara_speed;
    logic main_chara_trans, main_chara_drawing;
    logic [23:0] main_chara_color;
    logic signed [CORDW-1:0] spry;
    assign main_chara_speed = 4;
    assign char_pos = 150;
    moving_sprite #(
        .SPR_WIDTH       ( SPR_WIDTH ),
        .SPR_HEIGHT      ( SPR_HEIGHT ),
        .SPR_FRAMES      ( 3 ),
        .SPR_SCALE_X     ( SPR_SCALE_X ),
        .SPR_SCALE_Y     ( SPR_SCALE_Y ),
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
        .i_ctrl    ( {i_key[1:0], i_sw[4:1]} ),
        .i_frame   ( i_frame   ),
        .i_line    ( i_line    ),
        .i_sx      ( i_sx      ),
        .i_sy      ( i_sy      ),
        .i_speed   ( main_chara_speed),
        .i_floor   ( stg_floor ),
        .i_char_pos (char_pos),

        .o_spry    (spry),
        .o_trans   ( main_chara_trans   ),
        .o_drawing ( main_chara_drawing ),
        .o_color   ( main_chara_color   ),
    );
    //===================================================================================
    always_ff @(posedge i_clk_pix) begin
        if (i_frame) begin
            map_x <=    (i_sw[2]) ? ( ((spry <= V_RES-buffer[blk_now].height-SPR_TRUE_HEIGHT)||(char_pos + SPR_TRUE_WIDTH + map_x <= buffer[blk_now].left)) ? map_x + main_chara_speed :
                                    map_x):
                        map_x;
        end

        if (!i_rst_n) begin
            map_x <= 0;
        end
    end

    always_comb begin
        o_processing = (state_stage == PLAY_stage);
        o_drawing = (   stg_drawing || 
                        (main_chara_drawing && !main_chara_trans)
                    );

        {o_red, o_blue, o_green} =  (main_chara_drawing && !main_chara_trans) ? main_chara_color :
                                    (stg_drawing) ? stg_color :
                                    24'hFFFF00;

        o_check_addr[STG_ADDRW-1:0] = blk_now;
    end

endmodule
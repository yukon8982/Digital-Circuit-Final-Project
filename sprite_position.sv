module sprite_position #(
    parameter SPR_WIDTH    = 19,   // width in pixels
    parameter SPR_HEIGHT   = 27,   // number of lines

    parameter POS_DIGIT    = 4 * 4,
    parameter MAP_W = 20,

    parameter CORDW        = 16,

    parameter H_RES        = 800,
    parameter V_RES        = 600
    ) (
        input  i_clk_pix,
        input  i_rst_n,
        input  [5:0] i_ctrl,
        input  i_frame,
        input  i_line,

        input  [4:0] i_scale_x,
        input  [4:0] i_scale_y,
        input  signed [POS_DIGIT-1:0] i_floor,
        input  [POS_DIGIT-1:0] i_blk_height,
        input  [POS_DIGIT-1:0] i_blk_left,
        input  [POS_DIGIT-1:0] i_blk_right,

        input  [POS_DIGIT-1:0] i_char_pos,
        input                       i_jump,
        input  [15:0]               i_jump_height, // sync wuth jump
        input                       i_run,
        input  [15:0]               i_run_speed,

        output o_face_left,
        output o_walking,
        output o_jumping,

        output        [MAP_W-1:0] o_map_x,
        output signed [CORDW-1:0] o_sprx,
        output signed [CORDW-1:0] o_spry
    );
    
    logic [CORDW-1:0] SPR_TRUE_WIDTH, SPR_TRUE_HEIGHT;
    assign SPR_TRUE_WIDTH = SPR_WIDTH * i_scale_x;
    assign SPR_TRUE_HEIGHT = SPR_HEIGHT * i_scale_y;

    // ANCHOR divide frame rate
    logic cnt_frame;
    always_ff @(posedge i_clk_pix) begin
        if (i_frame) begin
            cnt_frame = cnt_frame + 1;
        end

        if (!i_rst_n) begin
            cnt_frame <= 0;
        end
    end


    // ANCHOR draw sprite at position
    logic signed [CORDW-1:0] sprx, spry;
    logic spr_face;

    assign o_sprx = sprx;
    assign o_spry = spry;
    assign o_face_left = spr_face;
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
                    spr_face <= 1;
                end
                RIGHT_movement_x: begin
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

    logic move_ctrl_x;
    assign move_ctrl_x = i_run;
    always_comb begin
        casez (move_ctrl_x) // up before down, right before left
            1'b1: state_movement_x_next = RIGHT_movement_x;
            default: state_movement_x_next = IDLE_movement_x;
        endcase
    end

    always_ff @(posedge i_clk_pix) begin
        if (i_frame) begin
            o_map_x <=    (move_ctrl_x) ? ( ((spry <= V_RES-i_blk_height-SPR_TRUE_HEIGHT)||
                                    (i_char_pos + SPR_TRUE_WIDTH + o_map_x + i_run_speed <= i_blk_left)) ? o_map_x + i_run_speed :
                                    i_blk_left - i_char_pos - SPR_TRUE_WIDTH):
                        o_map_x;
        end

        if (!i_rst_n) begin
            o_map_x <= 0;
        end
    end

    // ANCHOR sprite y movement FSM
    enum {
        IDLE_movement_y,       
        JUMP_movement_y,
        FALL_movement_y
    } state_movement_y, state_movement_y_next;

    logic [15:0] cnt_jump, cnt_fall;
    always_ff @(posedge i_clk_pix) begin
        state_movement_y <= state_movement_y_next;
        if (i_frame && cnt_frame) begin
            case (state_movement_y)
                IDLE_movement_y: begin
                    cnt_jump <= 1;
                    cnt_fall <= 0;
                    spry <= V_RES-i_floor-SPR_TRUE_HEIGHT;
                end
                JUMP_movement_y: begin
                    cnt_jump <= cnt_jump + 1;
                    spry <= spry + (cnt_jump - i_jump_height);
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
    assign move_ctrl_jump_y = i_jump;
    always_comb begin
        case(state_movement_y)
            IDLE_movement_y: state_movement_y_next = (move_ctrl_jump_y) ? JUMP_movement_y :
                                                     (spry < V_RES-i_floor-SPR_TRUE_HEIGHT) ? FALL_movement_y : 
                                                     IDLE_movement_y;
            JUMP_movement_y: state_movement_y_next = (cnt_jump == i_jump_height) ? FALL_movement_y : JUMP_movement_y;
            FALL_movement_y: state_movement_y_next = (spry+cnt_fall < V_RES-i_floor-SPR_TRUE_HEIGHT) ? FALL_movement_y : IDLE_movement_y;
        endcase
    end

    assign o_walking = (state_movement_x != IDLE_movement_x);
    assign o_jumping = (state_movement_y != IDLE_movement_y);
    
endmodule
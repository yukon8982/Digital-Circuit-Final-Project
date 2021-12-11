module sprite #(
    parameter WIDTH=8,         // graphic width in pixels
    parameter HEIGHT=8,        // graphic height in pixels
    parameter SCALE_X=1,       // sprite width scale-factor
    parameter SCALE_Y=1,       // sprite height scale-factor
    parameter COLR_BITS=4,     // bits per pixel (2^4=16 colours)
    parameter CORDW=16,        // screen coordinate width in bits
    parameter ADDRW=6          // width of graphic memory address bus
    ) (
    input  i_clk,                      // clock
    input  i_rst_n,                    // reset
    input  i_start,                    // start control
    input  signed [CORDW-1:0] i_sx,    // horizontal screen position
    input  signed [CORDW-1:0] i_sprx,  // horizontal sprite position
    input  [COLR_BITS-1:0] i_data_in,  // data from external memory
    input  i_face,                     // facing direction
    
    output [ADDRW-1:0] o_pos,          // sprite pixel position
    output [COLR_BITS-1:0] o_pix,      // pixel colour to draw
    output o_drawing,                  // sprite is drawing
    output o_done                      // sprite drawing is complete
    );

    // position within sprite
    logic [$clog2(WIDTH)-1:0]  ox; // x position within sprite
    logic [$clog2(HEIGHT)-1:0] oy; // y position within sprite

    // scale counters
    logic [$clog2(SCALE_X)-1:0] cnt_x; // x scale counters
    logic [$clog2(SCALE_Y)-1:0] cnt_y; // y scale counters

    enum {
        IDLE,       // awaiting start signal
        START,      // prepare for new sprite drawing
        AWAIT_POS,  // await horizontal position
        DRAW,       // draw pixel
        NEXT_LINE,  // prepare for next sprite line
        DONE        // set done signal, then go idle
    } state, state_next;

    always_ff @(posedge i_clk) begin
        state <= state_next;  // advance to next state

        case (state)
            START: begin
                o_done <= 0;
                oy <= 0;
                cnt_y <= 0;
                o_pos <= (i_face) ? WIDTH : 0;
            end
            AWAIT_POS: begin
                ox <= 0;
                cnt_x <= 0;
            end
            DRAW: begin
                if (SCALE_X <= 1 || cnt_x == SCALE_X-1) begin
                    ox <= ox + 1;
                    cnt_x <= 0;
                    o_pos <= (i_face) ? o_pos - 1 : o_pos + 1;
                end else begin
                    cnt_x <= cnt_x + 1;
                end
            end
            NEXT_LINE: begin
                if (SCALE_Y <= 1 || cnt_y == SCALE_Y-1) begin
                    oy <= oy + 1;
                    cnt_y <= 0;
                    o_pos <= (i_face) ? o_pos + 2*WIDTH : o_pos;
                end else begin
                    cnt_y <= cnt_y + 1;
                    o_pos <= (i_face) ? o_pos + WIDTH : o_pos - WIDTH;  // go back to start of line
                end
            end
            DONE: o_done <= 1;
        endcase

        if (!i_rst_n) begin
            state <= IDLE;
            ox <= 0;
            oy <= 0;
            cnt_x <= 0;
            cnt_y <= 0;
            o_pos <= 0;
            o_done <= 0;
        end
    end

    // output current pixel colour when drawing
    always_comb o_pix = (state == DRAW) ? i_data_in : 0;

    // create status signals
    logic last_pixel, last_line;
    always_comb begin
        last_pixel = (ox == WIDTH-1  && cnt_x == SCALE_X-1);
        last_line  = (oy == HEIGHT-1 && cnt_y == SCALE_Y-1);
        o_drawing = (state == DRAW);
    end

    // determine next state
    always_comb begin
        case (state)
            IDLE:       state_next = i_start ? START : IDLE;
            START:      state_next = AWAIT_POS;
            AWAIT_POS:  state_next = (i_sx == i_sprx-2) ? DRAW : AWAIT_POS;  // BRAM
            DRAW:       state_next = !last_pixel ? DRAW :
                                    (!last_line ? NEXT_LINE : DONE);
            NEXT_LINE:  state_next = AWAIT_POS;
            DONE:       state_next = IDLE;
            default:    state_next = IDLE;
        endcase
    end
endmodule

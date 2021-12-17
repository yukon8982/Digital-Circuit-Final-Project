module stage #(
        parameter BLK_BITS     = 4 * 13,
        parameter ADDRW        = 5,
        parameter STG_DEPTH    = 8;
        parameter MAP_W        = 16,
        parameter POS_DIGIT    = 4 * 4,
        parameter BUFFER_LEN   = 10,

        parameter CORDW        = 16,
        parameter H_RES        = 800,
        parameter V_RES        = 600
    ) (
        input  i_clk_pix,
        input  i_rst_n,

        input  i_start,
        input  [MAP_W-1:0] i_map_x,
        input  signed [CORDW-1:0] i_sx,
        input  signed [CORDW-1:0] i_sy,
        input  [BLK_BITS-1:0] i_data,

        output o_drawing,
        output o_ready,
        output [ADDRW-1:0] o_addr
    );
    typedef struct packed{
        logic valid;
        logic [POS_DIGIT-1:0] left, right, height;
        logic [POS_DIGIT-1:0] stat;
    } block;

    enum {
        IDLE,       
        LOADING,      
        PLAY        
    } state, state_next;

    assign o_ready = (state == PLAY);

    logic load_fin, load_more;
    block buffer [BUFFER_LEN-1:0];
    logic [BUFFER_LEN-1:0] pix_in_blk;
    always_ff @(posedge i_clk_pix) begin
        state <= state_next;

        case(state)
            LOADING: begin
                buffer[BUFFER_LEN-1:1] <= buffer[BUFFER_LEN-2:0];
                buffer[0] <= '{1'b1, i_data[BLK_BITS-1:BLK_BITS-POS_DIGIT], i_data[BLK_BITS-1-POS_DIGIT:BLK_BITS-2*POS_DIGIT], i_data[BLK_BITS-1-2*POS_DIGIT:BLK_BITS-3*POS_DIGIT], i_data[BLK_BITS-3*POS_DIGIT-1:0]};
                o_addr <= (o_addr == STG_DEPTH-1) ? 0 : o_addr + 1;
                
                load_fin <= (buffer[0].valid && (buffer[0].left > H_RES));
            end
            PLAY: begin
                o_drawing <= |pix_in_blk;
                if (load_more) begin
                    buffer[BUFFER_LEN-1:1] <= buffer[BUFFER_LEN-2:0];
                    buffer[0] <= '{1'b1, i_data[BLK_BITS-1:BLK_BITS-POS_DIGIT], i_data[BLK_BITS-1-POS_DIGIT:BLK_BITS-2*POS_DIGIT], i_data[BLK_BITS-1-2*POS_DIGIT:BLK_BITS-3*POS_DIGIT], i_data[BLK_BITS-3*POS_DIGIT-1:0]};
                    o_addr <= (o_addr == STG_DEPTH-1) ? 0 : o_addr + 1;
                end
            end
        endcase

        if (!i_rst_n) begin
            o_addr <= 0;
            o_drawing <= 0;
            buffer <= '{BUFFER_LEN{'{'b0, 'b0, 'b0, 'b0, 'b0}}};
            load_fin <= 0;
        end
    end

    logic signed [MAP_W-1:0] pix_x, pix_y;
    always_comb begin      
        state_next = IDLE;
        pix_x = i_map_x + i_sx;
        pix_y = i_sy;

        
        load_more = (buffer[0].left <= i_map_x + H_RES);
        for (int i = 0; i < BUFFER_LEN; i++) begin
            pix_in_blk[i] = ((buffer[i].valid) && 
                             (pix_x <= buffer[i].right) && // pix <= R
                             (pix_x >= buffer[i].left) && // L <= pix
                             (
                                 (~(buffer[i].stat[0]) && (pix_y >= (V_RES - buffer[i].height))) || // bottom blk
                                 ((buffer[i].stat[0]) && (pix_y <= buffer[i].height)) // top blk
                             ));
        end

        case (state)
            IDLE:       state_next = i_start ? LOADING : IDLE;
            LOADING: begin
                state_next = load_fin ? PLAY : LOADING;
            end    
            PLAY:       state_next = PLAY;
        endcase
    end
endmodule
module FSM(
    input clk,
    input rst,
    input start, 
    input [1:0] mode, 
    input stall_inject, 
    input x_valid, 
    input w_valid, 
    input batch_complete, 
    input y_ready, 
    output reg clear_en,
    output reg accept_en,
    output reg done
);

localparam IDLE     = 3'd0;
localparam CONFIG   = 3'd1;
localparam WAIT_IN  = 3'd2;
localparam COMPUTE  = 3'd3;
localparam HOLD_OUT = 3'd4;

reg [2:0] state;
reg [2:0] next_state;
reg [1:0] mode_reg;
wire input_ready;
wire run_ok;

assign input_ready = x_valid && w_valid;
assign run_ok = input_ready && !stall_inject;

always @(posedge clk) begin
    if (rst) begin
        state <= IDLE;
        mode_reg <= 2'b00;
    end else begin
        state <= next_state;
        if (state == CONFIG) mode_reg <= mode;
    end
end

always @(*) begin
    next_state = state;
    case (state)
        IDLE: begin
            if (start) next_state = CONFIG;
        end
        CONFIG: begin
            next_state = WAIT_IN;
        end
        WAIT_IN: begin
            if (mode_reg == 2'b01) begin
                if (run_ok) begin
                    if (batch_complete) next_state = HOLD_OUT;
                    else next_state = COMPUTE;
                end
            end else begin
                next_state = HOLD_OUT;
            end
        end
        COMPUTE: begin
            if (mode_reg == 2'b01) begin
                if (run_ok) begin
                    if (batch_complete) next_state = HOLD_OUT;
                    else next_state = COMPUTE;
                end else begin
                    next_state = WAIT_IN;
                end
            end else begin
                next_state = HOLD_OUT;
            end
        end
        HOLD_OUT: begin
            if (y_ready) next_state = IDLE;
        end
        default: begin
            next_state = IDLE;
        end
    endcase
end

always @(*) begin
    clear_en = 1'b0;
    accept_en = 1'b0;
    done = 1'b0;

    case (state)
        CONFIG: begin
            clear_en = 1'b1;
        end
        WAIT_IN: begin
            if (mode_reg == 2'b01 && run_ok) accept_en = 1'b1;
        end
        COMPUTE: begin
            if (mode_reg == 2'b01 && run_ok) accept_en = 1'b1;
        end
        HOLD_OUT: begin
            done = 1'b1;
        end
        default: begin
        end
    endcase
end

endmodule

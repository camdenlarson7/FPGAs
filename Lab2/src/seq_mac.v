`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/03/2026 02:13:04 PM
// Design Name: 
// Module Name: seq_mac
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

// Sequential MAC for Dot Product: y = sum(x_i * w_i) for i = 0 to N-1
// N = 64, x/w: signed[7:0] (INT8), y: signed[31:0]
//
// FSM States: IDLE -> CONFIG -> WAIT_IN -> COMPUTE -> HOLD_OUT -> IDLE
//
// Interface signals:
//   Inputs : clk, rst_n, start, x[7:0], w[7:0], x_valid, w_valid,
//            stall_inject, y_ready
//   Outputs: done, y[31:0]



module seq_mac #(
    parameter N = 64    // Number of MAC iterations
)(
    input  wire        clk,
    input  wire        rst_n,           // Active-low synchronous reset

    // Control
    input  wire        start,
    input  wire        stall_inject,
    input  wire        y_ready,

    // Data inputs
    input  wire signed [7:0]  x,
    input  wire signed [7:0]  w,
    input  wire               x_valid,
    input  wire               w_valid,

    // Outputs
    output reg  signed [31:0] y,
    output reg                done
);

    
    // FSM state encoding (one-hot)
    localparam [4:0]
        IDLE     = 5'b00001,
        CONFIG   = 5'b00010,
        WAIT_IN  = 5'b00100,
        COMPUTE  = 5'b01000,
        HOLD_OUT = 5'b10000;

    reg [4:0] state, next_state;

    // Datapath registers
    reg signed [31:0] acc;
    reg        [7:0]  k;

    // Combinational signals
    wire signed [15:0] product;
    wire signed [31:0] product_ext;
    wire               inputs_ready;
    wire               k_done;

    assign product      = x * w;
    assign product_ext  = {{16{product[15]}}, product};
    assign inputs_ready = x_valid & w_valid & ~stall_inject;

    // k is the value BEFORE increment this cycle.
    // COMPUTE increments k on the posedge, so we compare k == N-1
    // to detect the final iteration - after increment k will be N.
    assign k_done = (k == (N-1));


    always @(posedge clk) begin
        if (!rst_n) state <= IDLE;
        else        state <= next_state;
    end

    // FSM: next-state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE:     if (start)        next_state = CONFIG;
            CONFIG:                     next_state = WAIT_IN;
            WAIT_IN:  if (inputs_ready) next_state = COMPUTE;
            COMPUTE:  if (k_done)       next_state = HOLD_OUT;
                      else              next_state = WAIT_IN;
            HOLD_OUT: if (y_ready)      next_state = IDLE;
            default:                    next_state = IDLE;
        endcase
    end

    // Datapath: accumulator and counter
    always @(posedge clk) begin
        if (!rst_n) begin
            acc <= 32'sd0;
            k   <= 8'd00;
        end else begin
            case (state)
                CONFIG:  begin acc <= 32'sd0; k <= 8'd00;          end
                COMPUTE: begin acc <= acc + product_ext; k <= k + 1'd1; end
                default: begin end
            endcase
        end
    end

    // -------------------------------------------------------------------------
    // Output logic
    // -------------------------------------------------------------------------
    always @(posedge clk) begin
        if (!rst_n) begin
            y    <= 32'sd0;
            done <= 1'b0;
        end else begin
            case (state)
                COMPUTE: begin
                    // Latch final result on last MAC cycle
                    if (k_done) y <= acc + product_ext;
                end
                HOLD_OUT: done <= 1'b1;
                IDLE:     done <= 1'b0;
                default:  done <= 1'b0;
            endcase
        end
    end

endmodule
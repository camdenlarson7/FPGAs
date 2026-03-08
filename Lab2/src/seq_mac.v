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
    parameter N = 64
)(
    output [31:0] y,
    output mode0_done,
    input [7:0] x,
    input [7:0] w,
    input clear_en,
    input accept_en,
    input clk,
    input rst
);

    
    reg signed [31:0] acc;
    reg [7:0] k;
    wire signed [15:0] product;
    wire signed [31:0] product_ext;

    assign y = acc;
    assign product = $signed(x) * $signed(w);
    assign product_ext = {{16{product[15]}}, product};
    assign mode0_done = (k == N);

    always @(posedge clk) begin
        if (rst) begin
            acc <= 32'sd0;
            k <= 8'd0;
        end else begin
            if (clear_en) begin
                acc <= 32'sd0;
                k <= 8'd0;
            end else if (accept_en && (k < N)) begin
                acc <= acc + product_ext;
                k <= k + 1'b1;
            end
        end
    end

endmodule
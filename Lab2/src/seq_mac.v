`timescale 1ns / 1ps
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
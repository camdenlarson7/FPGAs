// early exit sequential MAC for dot product
//

module early_exit_mac #(
    parameter N = 64
    parameter signed T = 32'sd5000;
) (
    output [31:0] y,
    output mode2_done,
    output early_exit_hit,
    input [7:0] x,
    input [7:0] w,
    input clear_en,
    input accept_en,
    input clk,
    input rst
);

    reg signed [31:0] acc;
    // reg signed [31:0] T; // parameterized T instead
    reg [7:0] k;
    wire signed [15:0] product;
    wire signed [31:0] product_ext;

    assign y = acc;
    assign product = $signed(x) * $signed(w);
    assign product_ext = {{16{product[15]}}, product};
    assign early_exit_hit = (acc >= T);
    assign mode2_done = (k == N) || early_exit_hit; // terminate when k = N

    always @(posedge clk) begin
        if (rst) begin
            acc <= 32'sd0;
            k <= 8'd0;
        end else begin
            if (clear_en) begin
                acc <= 32'sd0;
                k <= 8'd0;
            end else if (accept_en && (k < N) && (acc < T)) begin
                acc <= acc + product_ext; // y_partial = acc
                k <= k + 1'b1;
            end
        end
    end

endmodule

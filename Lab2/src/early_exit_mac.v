module early_exit_mac #(
    parameter N = 64,
    parameter T = 0
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
reg [$clog2(N+1)-1:0] k;
wire signed [15:0] product;
wire signed [31:0] product_ext;
wire signed [31:0] acc_next;

assign y = acc;
assign product = $signed(x) * $signed(w);
assign product_ext = {{16{product[15]}}, product};
assign acc_next = acc + product_ext;

assign mode2_done = (k == N);
assign early_exit_hit = accept_en && !mode2_done && ($signed(T) != 32'sd0) &&
                        (($signed(acc_next) >= $signed(T)) ||
                         ($signed(acc_next) <= -$signed(T)));

always @(posedge clk) begin
    if (rst) begin
        acc <= 32'sd0;
        k <= 0;
    end else begin
        if (clear_en) begin
            acc <= 32'sd0;
            k <= 0;
        end else if (accept_en && !mode2_done) begin
            acc <= acc_next;
            k <= k + 1'b1;
        end
    end
end

endmodule

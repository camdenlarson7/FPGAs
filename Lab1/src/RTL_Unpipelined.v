module RTL_Unpipelined(
input wire signed [15:0] a,
input wire signed [15:0] b, 
input wire signed [15:0] c, 
input wire signed [15:0] d, 
input wire signed [15:0] e,
output wire signed [31:0] y,
input wire clk, 
input wire rst,
input wire out_ready,
input wire in_valid,
output wire out_valid,
output wire in_ready
);

reg out_v;
reg signed [31:0] y_r;

assign out_valid = out_v;
assign y = y_r;
assign in_ready = (~out_v) || (out_v && out_ready);

wire signed [31:0] prod_ab = $signed(a) * $signed(b);
wire signed [31:0] prod_cd = $signed(c) * $signed(d);
wire signed [31:0] sum_prods = prod_ab + prod_cd;
wire signed [31:0] total = sum_prods + $signed(e);

always @(posedge clk) begin
    if (rst) begin
        out_v <= 1'b0;
        y_r <= 32'd0;
    end else begin
        if (out_v && out_ready) begin
            out_v <= 1'b0;
        end
        if (in_valid && in_ready) begin
            y_r <= total;
            out_v <= 1'b1;
        end
    end
end

endmodule
module RTL_Pipelined(
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

// Stage 1
reg signed [31:0] p1_s1;
reg signed [31:0] p2_s1;
reg signed [15:0] e_s1;
reg valid_s1;

// Stage 2
reg signed [31:0] sum_s2;
reg signed [15:0] e_s2;
reg valid_s2;

// Stage 3
reg signed [31:0] y_s3;
reg valid_s3;

wire ready_s1;
wire ready_s2;

assign ready_s1 = (~valid_s1) || (valid_s1 && ready_s2);
assign ready_s2 = (~valid_s2) || (valid_s2 && ready_s3);
assign ready_s3 = (~valid_s3) || (valid_s3 && out_ready);

assign in_ready = ready_s1;
assign out_valid = valid_s3;
assign y = y_s3;

always @(posedge clk) begin
    if (rst) begin
        valid_s1 <= 1'b0;
        valid_s2 <= 1'b0;
        valid_s3 <= 1'b0;
        p1_s1 <= 32'd0;
        p2_s1 <= 32'd0;
        e_s1 <= 16'd0;
        sum_s2 <= 32'd0;
        e_s2 <= 16'd0;
        y_s3 <= 32'd0;
    end else begin
        if (valid_s1 && ready_s2) begin
            valid_s1 <= 1'b0;
        end
        if (in_valid && ready_s1) begin
            p1_s1 <= $signed(a) * $signed(b);
            p2_s1 <= $signed(c) * $signed(d);
            e_s1 <= e;
            valid_s1 <= 1'b1;
        end
        if (valid_s2 && ready_s3) begin
            valid_s2 <= 1'b0;
        end
        if (valid_s1 && ready_s2) begin
            sum_s2 <= p1_s1 + p2_s1;
            e_s2 <= e_s1;
            valid_s2 <= 1'b1;
        end
        if (valid_s3 && out_ready) begin
            valid_s3 <= 1'b0;
        end
        if (valid_s2 && ready_s3) begin
            y_s3 <= sum_s2 + $signed(e_s2);
            valid_s3 <= 1'b1;
        end
    end
end

endmodule
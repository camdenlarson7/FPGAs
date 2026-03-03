module parallel_mac #(
    parameter U = 8
) (
    output [31:0] y,
    output batch_complete,
    input [7:0] x,
    input [7:0] w,
    input clear_en,
    input accept_en,
    input clk,
    input rst
);

reg [31:0] y_partial;
assign y = y_partial;
reg [7:0] x_reg [0:U-1];
reg [7:0] w_reg [0:U-1];
reg [31:0] acc;
reg [$clog2(U+1)-1:0] fill_count;
integer j;

assign batch_complete = (fill_count == U-1);

always @(posedge clk) begin
    if (rst) begin
        for (j = 0; j < U; j = j + 1) begin
            x_reg[j] <= 8'd0;
            w_reg[j] <= 8'd0;
        end
        y_partial <= 32'd0;
        fill_count <= 0;
    end else begin
        if (clear_en) begin
            fill_count <= 0;
            y_partial <= 32'd0;
            for (j = 0; j < U; j = j + 1) begin
                x_reg[j] <= 8'd0;
                w_reg[j] <= 8'd0;
            end
        end else if (accept_en) begin
            for (j = U-1; j > 0; j = j - 1) begin
                x_reg[j] <= x_reg[j-1];
                w_reg[j] <= w_reg[j-1];
            end

            x_reg[0] <= x;
            w_reg[0] <= w;

            if (batch_complete) begin
                acc = x * w;
                for (j = 1; j < U; j = j + 1) begin
                    acc = acc + (x_reg[j-1] * w_reg[j-1]);
                end
                y_partial <= acc;
                fill_count <= 0;
            end else begin
                fill_count <= fill_count + 1'b1;
            end
        end
    end
end

endmodule

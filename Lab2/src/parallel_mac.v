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
reg [$clog2(U+1)-1:0] fill_count;
reg [15:0] prod_reg [0:U-1];
reg [31:0] add_acc;
reg [$clog2(U+1)-1:0] add_index;
reg add_active;
reg batch_complete_r;
integer j;

assign batch_complete = batch_complete_r;

always @(posedge clk) begin
    if (rst) begin
        for (j = 0; j < U; j = j + 1) begin
            x_reg[j] <= 8'd0;
            w_reg[j] <= 8'd0;
            prod_reg[j] <= 16'd0;
        end
        y_partial <= 32'd0;
        fill_count <= 0;
        add_acc <= 32'd0;
        add_index <= 0;
        add_active <= 1'b0;
        batch_complete_r <= 1'b0;
    end else begin
        batch_complete_r <= 1'b0;

        if (clear_en) begin
            fill_count <= 0;
            y_partial <= 32'd0;
            add_acc <= 32'd0;
            add_index <= 0;
            add_active <= 1'b0;
            for (j = 0; j < U; j = j + 1) begin
                x_reg[j] <= 8'd0;
                w_reg[j] <= 8'd0;
                prod_reg[j] <= 16'd0;
            end
        end else begin
            if (accept_en && !add_active) begin
                for (j = U-1; j > 0; j = j - 1) begin
                    x_reg[j] <= x_reg[j-1];
                    w_reg[j] <= w_reg[j-1];
                end

                x_reg[0] <= x;
                w_reg[0] <= w;

                if (fill_count == U-1) begin
                    prod_reg[0] <= x * w;
                    for (j = 1; j < U; j = j + 1) begin
                        prod_reg[j] <= x_reg[j-1] * w_reg[j-1];
                    end
                    fill_count <= 0;
                    add_acc <= 32'd0;
                    add_index <= 0;
                    add_active <= 1'b1;
                end else begin
                    fill_count <= fill_count + 1'b1;
                end
            end

            if (add_active) begin
                add_acc <= add_acc + prod_reg[add_index];

                if (add_index == U-1) begin
                    y_partial <= add_acc + prod_reg[add_index];
                    add_active <= 1'b0;
                    batch_complete_r <= 1'b1;
                    add_index <= 0;
                end else begin
                    add_index <= add_index + 1'b1;
                end
            end
        end
    end
end

endmodule

module dot_product_accelerator #(
    parameter N = 64,
    parameter U = 8
) (
    output [31:0] y_data,
    output done,
    input [7:0] x_data,
    input [7:0] w_data,
    input start,
    input [1:0] mode,
    input x_valid,
    input w_valid,
    input stall_inject,
    input y_ready,
    input clk,
    input rst
);

wire clear_en;
wire accept_en;
wire [31:0] y_mode0;
wire [31:0] y_mode1;
wire [31:0] y_mode2;
wire batch_complete_mode1;
reg [1:0] mode_reg;

always @(posedge clk) begin
    if (rst) mode_reg <= 2'b00;
    else if (start) mode_reg <= mode;
end

assign y_data = (mode_reg == 2'b00) ? y_mode0 :
                (mode_reg == 2'b01) ? y_mode1 :
                (mode_reg == 2'b10) ? y_mode2 : 32'd0;

FSM controller (
    .clk(clk),
    .rst(rst),
    .start(start),
    .mode(mode),
    .stall_inject(stall_inject),
    .x_valid(x_valid),
    .w_valid(w_valid),
    .batch_complete(batch_complete_mode1),
    .y_ready(y_ready),
    .clear_en(clear_en),
    .accept_en(accept_en),
    .done(done)
);

sequential_mac #(.N(N)) mode0_datapath (
    .y(y_mode0),
    .x(x_data),
    .w(w_data),
    .clear_en(clear_en),
    .accept_en(accept_en),
    .clk(clk),
    .rst(rst)
);

parallel_mac #(.U(U)) mode1_datapath (
    .y(y_mode1),
    .x(x_data),
    .w(w_data),
    .clear_en(clear_en),
    .accept_en(accept_en),
    .batch_complete(batch_complete_mode1),
    .clk(clk),
    .rst(rst)
);

early_exit_mac #(.N(N)) mode2_datapath (
    .y(y_mode2),
    .x(x_data),
    .w(w_data),
    .clear_en(clear_en),
    .accept_en(accept_en),
    .clk(clk),
    .rst(rst)
);

endmodule

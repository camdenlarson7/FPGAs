module dot_product_accelerator #(
    parameter N = 64,
    parameter U = 8,
    parameter T = 32'sd5000; // change value of T for mode2 early exit threshold
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
wire mode0_done;
wire mode2_done;
wire early_exit_hit;
reg [1:0] mode_reg;

//assign mode2_done = 1'b1;
//assign early_exit_hit = 1'b0;


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
    .mode0_done(mode0_done),
    .mode1_done(batch_complete_mode1),
    .mode2_done(mode2_done),
    .early_exit_hit(early_exit_hit),
    .y_ready(y_ready),
    .clear_en(clear_en),
    .accept_en(accept_en),
    .done(done)
);

seq_mac #(.N(N)) mode0_datapath (
    .y(y_mode0),
    .mode0_done(mode0_done),
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

early_exit_mac #(.N(N), .T(T)) mode2_datapath (
    .y(y_mode2),
    .x(x_data),
    .w(w_data),
    .mode2_done(mode2_done),
    .early_exit_hit(early_exit_hit),
    .clear_en(clear_en),
    .accept_en(accept_en),
    .clk(clk),
    .rst(rst) // add in mode2_done()
);

endmodule

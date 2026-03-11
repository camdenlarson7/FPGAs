// iverilog -o tb_dot_product.vvp tb_dot_product.v dot_product_accelerator.v FSM.v parallel_mac.v seq_mac.v early_exit_mac.v
// vvp tb_dot_product.vvp

module tb_dot_product;
localparam U = 8;
localparam N = 64;
localparam MODE2_T = 32;
reg [7:0] x;
reg [7:0] w;
reg clk;
reg rst;
reg start;
reg [1:0] mode;
reg x_valid;
reg w_valid;
reg stall_inject;
reg y_ready;
wire [31:0] y;
wire done;
integer k;
integer expected_mode0;
integer expected_mode2;


dot_product_accelerator #(
    .U(U),
    .N(N),
    .MODE2_T(MODE2_T)
) dut (
    .y_data(y),
    .done(done),
    .x_data(x),
    .w_data(w),
    .start(start),
    .mode(mode),
    .x_valid(x_valid),
    .w_valid(w_valid),
    .stall_inject(stall_inject),
    .y_ready(y_ready),
    .clk(clk),
    .rst(rst)
);

always #5 clk = ~clk;

initial begin
    clk = 0;
    rst = 1;
    x = 0;
    w = 0;
    start = 0;
    mode = 2'b01;
    x_valid = 0;
    w_valid = 0;
    stall_inject = 0;
    y_ready = 0;

    $display("Starting MODE1 test");

    @(negedge clk);
    start = 1;
    x_valid = 1;
    w_valid = 1;
    x = 1;
    w = 2;
    #2;
    rst = 0;
    @(negedge clk);
    start = 0;
    @(negedge clk);

    for (k = 1; k < U; k = k + 1) begin
        @(negedge clk);
        x = k + 1;
        w = (k + 1) * 2;
        stall_inject = 0;
    end

    wait(done == 1);
    $display("MODE1 expected=408 y=%0d", y);
    @(negedge clk);
    y_ready = 1;
    @(negedge clk);
    y_ready = 0;

    mode = 2'b00;
    expected_mode0 = N;
    $display("Starting MODE0 test");
    @(negedge clk);
    start = 1;
    x = 8'd1;
    w = 8'd1;
    x_valid = 1;
    w_valid = 1;
    @(negedge clk);
    start = 0;

    for (k = 0; k < N; k = k + 1) begin
        @(negedge clk);
        x = 8'd1;
        w = 8'd1;
    end

    wait(done == 1);
    $display("MODE0 expected=%0d y=%0d", expected_mode0, y);
    @(negedge clk);
    y_ready = 1;
    @(negedge clk);
    y_ready = 0;

    mode = 2'b10;
    expected_mode2 = 36;
    $display("Starting MODE2 test");
    @(negedge clk);
    start = 1;
    x = 8'd4;
    w = 8'd3;
    x_valid = 1;
    w_valid = 1;
    @(negedge clk);
    start = 0;

    while (done == 0) begin
        @(negedge clk);
        x = 8'd4;
        w = 8'd3;
    end

    $display("MODE2 expected=%0d y=%0d", expected_mode2, y);
    @(negedge clk);
    y_ready = 1;
    @(negedge clk);
    y_ready = 0;

    #20;
    $finish;
end

endmodule

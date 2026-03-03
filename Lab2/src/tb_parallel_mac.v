// iverilog -o tb_parallel_mac.vvp tb_parallel_mac.v dot_product_accelerator.v FSM.v parallel_mac_datapath.v sequential_mac.v early_exit_mac.v
// vvp tb_parallel_mac.vvp

module tb_parallel_mac;
localparam U = 8;
localparam N = 64;
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
integer expected;

dot_product_accelerator #(
    .U(U),
    .N(N)
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
    expected = 0;
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
    stall_inject = 0;
    wait(done == 1);
    $display("expected=%0d y=%0d", 408, y);
    @(negedge clk);
    y_ready = 1;
    @(negedge clk);
    y_ready = 0;
    #20;
    $finish;
end

initial begin
    $monitor("t=%0t rst=%0b start=%0b mode=%0b xv=%0b wv=%0b stall=%0b done=%0b yready=%0b x=%0d w=%0d y=%0d", $time, rst, start, mode, x_valid, w_valid, stall_inject, done, y_ready, x, w, y);
end

initial begin
    $dumpfile("tb_parallel_mac.vcd");
    $dumpvars(0, tb_parallel_mac);
end

endmodule
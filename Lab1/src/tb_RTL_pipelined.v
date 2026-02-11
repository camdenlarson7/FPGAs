// Testbench for RTL_Pipelined module
// To compile and run using icarus verilog:
//   iverilog -o tb_RTL_pipelined.vvp tb_RTL_pipelined.v RTL_Pipelined.v
//   vvp tb_RTL_pipelined.vvp

`timescale 1ns/1ps

module tb_RTL_pipelined;

reg clk;
reg rst;

reg signed [15:0] a;
reg signed [15:0] b;
reg signed [15:0] c;
reg signed [15:0] d;
reg signed [15:0] e;
reg in_valid;
reg out_ready;

wire signed [31:0] y;
wire out_valid;
wire in_ready;

// Test data storage - queue for expected results
reg signed [31:0] expected_queue [0:299];
reg signed [15:0] input_a_queue [0:299];
reg signed [15:0] input_b_queue [0:299];
reg signed [15:0] input_c_queue [0:299];
reg signed [15:0] input_d_queue [0:299];
reg signed [15:0] input_e_queue [0:299];
integer write_ptr = 0;
integer read_ptr = 0;

// Test statistics
integer num_tests = 0;
integer num_passed = 0;
integer num_failed = 0;
integer inputs_sent = 0;
integer outputs_received = 0;

RTL_Pipelined uut (
    .a(a),
    .b(b),
    .c(c),
    .d(d),
    .e(e),
    .y(y),
    .clk(clk),
    .rst(rst),
    .out_ready(out_ready),
    .in_valid(in_valid),
    .out_valid(out_valid),
    .in_ready(in_ready)
);

// Clock generation: 10ns period (100MHz)
always #5 clk = ~clk;

// Input feeding process - continuously feed inputs when pipeline is ready
initial begin
    // Initialize signals
    clk = 0;
    rst = 1;
    a = 0;
    b = 0;
    c = 0;
    d = 0;
    e = 0;
    in_valid = 0;
    out_ready = 1;
    
    // Apply reset
    #20;
    rst = 0;
    #10;
    
    $display("Starting pipelined testbench with 200 test vectors");
    $display("Pipeline should process 1 input per cycle when ready");
    $display("Time: %0t", $time);
    
    // Generate and send 200 test vectors continuously
    repeat (200) begin
        
        while (!in_ready) begin
            @(posedge clk);
        end
        
        // Generate random inputs
        a = $random;
        b = $random;
        c = $random;
        d = $random;
        e = $random;
        
        // Store inputs and expected result in queue
        input_a_queue[write_ptr] = a;
        input_b_queue[write_ptr] = b;
        input_c_queue[write_ptr] = c;
        input_d_queue[write_ptr] = d;
        input_e_queue[write_ptr] = e;
        expected_queue[write_ptr] = ($signed(a) * $signed(b)) + ($signed(c) * $signed(d)) + $signed(e);
        write_ptr = write_ptr + 1;
        
        // Apply input with valid signal
        in_valid = 1;
        #1;  // Small delay for setup time constraints
        
        @(posedge clk);
        
        #1;
        in_valid = 0;
        
        inputs_sent = inputs_sent + 1;
    end
    
    $display("All 200 inputs sent at time %0t", $time);
end

// Output checking process
initial begin
    
    wait(rst == 0);
    @(posedge clk);
    
    // Check 200 outputs
    repeat (200) begin
        
        while (!out_valid) begin
            @(posedge clk);
        end
        
        // Check result
        num_tests = num_tests + 1;
        if (y === expected_queue[read_ptr]) begin
            num_passed = num_passed + 1;
            $display("Test %0d PASSED: a=%0d, b=%0d, c=%0d, d=%0d, e=%0d => y=%0d (expected=%0d)", 
                     num_tests, input_a_queue[read_ptr], input_b_queue[read_ptr], 
                     input_c_queue[read_ptr], input_d_queue[read_ptr], input_e_queue[read_ptr],
                     y, expected_queue[read_ptr]);
        end else begin
            num_failed = num_failed + 1;
            $display("Test %0d FAILED: a=%0d, b=%0d, c=%0d, d=%0d, e=%0d => y=%0d (expected=%0d)", 
                     num_tests, input_a_queue[read_ptr], input_b_queue[read_ptr],
                     input_c_queue[read_ptr], input_d_queue[read_ptr], input_e_queue[read_ptr],
                     y, expected_queue[read_ptr]);
        end
        read_ptr = read_ptr + 1;
        outputs_received = outputs_received + 1;
        
        @(posedge clk);
    end
    
    // Print summary
    $display("Test Summary:");
    $display("Total Tests: %0d", num_tests);
    $display("Passed: %0d", num_passed);
    $display("Failed: %0d", num_failed);
    if (num_failed == 0) begin
        $display("ALL TESTS PASSED!");
    end else begin
        $display("SOME TESTS FAILED!");
    end
    
    // End simulation
    #10;
    $finish;
end

endmodule

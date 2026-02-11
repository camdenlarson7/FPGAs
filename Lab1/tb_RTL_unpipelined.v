// Testbench for RTL_Pipelined module
// To compile and run using icarus verilog:
//   iverilog -o tb_RTL_unpipelined.vvp tb_RTL_unpipelined.v RTL_Unpipelined.v
//   vvp tb_RTL_pipelined.vvp

`timescale 1ns/1ps

module tb_RTL_unpipelined;

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

// Expected result and saved inputs for checking
reg signed [31:0] expected;
reg signed [15:0] saved_a, saved_b, saved_c, saved_d, saved_e;

// Test statistics
integer num_tests = 0;
integer num_passed = 0;
integer num_failed = 0;

// Instantiate the module under test
RTL_Unpipelined uut (
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

// Test procedure
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
    
    // Seed the random number generator for reproducibility
    $display("Starting testbench with 200 random test vectors");
    $display("Time: %0t", $time);
    
    // Generate and test 200 random vectors
    repeat (200) begin
        
        while (!in_ready) begin
            @(posedge clk);
        end
        
        // Generate random inputs using seeded random
        a = $random;
        b = $random;
        c = $random;
        d = $random;
        e = $random;
        
        // Save inputs for checking later
        saved_a = a;
        saved_b = b;
        saved_c = c;
        saved_d = d;
        saved_e = e;
        
        // Calculate expected result
        expected = ($signed(a) * $signed(b)) + ($signed(c) * $signed(d)) + $signed(e);
        
        // Set inputs and valid signal
        in_valid = 1;
        #1;  // Small delay to ensure no setup time violations
        
        @(posedge clk);
        
        // Deassert in_valid after inputs are captured
        #1;
        in_valid = 0;
        
        while (!out_valid) begin
            @(posedge clk);
        end
        
        // Check result when out_valid is high
        num_tests = num_tests + 1;
        if (y === expected) begin
            num_passed = num_passed + 1;
            $display("Test %0d PASSED: a=%0d, b=%0d, c=%0d, d=%0d, e=%0d => y=%0d (expected=%0d)", 
                     num_tests, saved_a, saved_b, saved_c, saved_d, saved_e, y, expected);
        end else begin
            num_failed = num_failed + 1;
            $display("Test %0d FAILED: a=%0d, b=%0d, c=%0d, d=%0d, e=%0d => y=%0d (expected=%0d)", 
                     num_tests, saved_a, saved_b, saved_c, saved_d, saved_e, y, expected);
        end
        
        // Wait for the handshake to complete before next transaction
        while (out_valid) begin
            @(posedge clk);
        end
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
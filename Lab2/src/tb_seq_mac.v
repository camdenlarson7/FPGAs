`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/03/2026 02:16:24 PM
// Design Name: 
// Module Name: tb_seq_mac
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module tb_seq_mac;

    localparam N     = 64;
    localparam CLK_P = 10;

    reg        clk, rst_n, start, stall_inject, y_ready;
    reg        x_valid, w_valid;
    reg  signed [7:0] x, w;
    wire signed [31:0] y;
    wire        done;

    seq_mac #(.N(N)) dut (
        .clk(clk), .rst_n(rst_n), .start(start),
        .stall_inject(stall_inject), .y_ready(y_ready),
        .x(x), .w(w), .x_valid(x_valid), .w_valid(w_valid),
        .y(y), .done(done)
    );

    initial clk = 0;
    always #(CLK_P/2) clk = ~clk;

    reg signed [7:0]  xs [0:N-1];
    reg signed [7:0]  ws [0:N-1];
    reg signed [31:0] expected;
    integer i, errors, seed;

    
    task run_mac;
        input inject_stall;
        input delay_ready;
        integer j, timeout;
        begin
            // Pulse start
            @(negedge clk); start = 1; x_valid = 0; w_valid = 0;
            @(negedge clk); start = 0;
            // Wait for CONFIG and WAIT_IN entry 
            @(posedge clk); // IDLE -> CONFIG
            @(posedge clk); // CONFIG -> WAIT_IN

            for (j = 0; j < N; j = j + 1) begin
                if (inject_stall && j == 20) begin
                    // Present data + stall: FSM stays in WAIT_IN
                    @(negedge clk);
                    x = xs[j]; w = ws[j]; x_valid = 1; w_valid = 1;
                    stall_inject = 1;
                    @(posedge clk); // WAIT_IN stalls (inputs_ready = 0)
                    @(posedge clk); // WAIT_IN stalls
                    @(posedge clk); // WAIT_IN stalls
                    @(negedge clk); stall_inject = 0;
                    // inputs still valid, stall gone
                    @(posedge clk); // WAIT_IN -> COMPUTE
                    @(negedge clk); x_valid = 0; w_valid = 0;
                    @(posedge clk); // COMPUTE 
                end else begin
                    @(negedge clk); x = xs[j]; w = ws[j]; x_valid = 1; w_valid = 1;
                    @(posedge clk); // WAIT_IN -> COMPUTE
                    @(negedge clk); x_valid = 0; w_valid = 0;
                    @(posedge clk); // COMPUTE
                end
            end

            // Wait for done with timeout
            timeout = 0;
            while (!done && timeout < 20) begin
                @(posedge clk);
                timeout = timeout + 1;
            end
            if (!done) begin
                $display("  ERROR: done never asserted after computation");
            end

            // Output handshake
            if (delay_ready) repeat(5) @(posedge clk);
            @(negedge clk); y_ready = 1;
            @(posedge clk); // HOLD_OUT -> IDLE
            @(negedge clk); y_ready = 0;
            @(posedge clk); // settle
        end
    endtask

    task compute_expected;
        integer j;
        begin
            expected = 32'sd0;
            for (j = 0; j < N; j = j + 1)
                expected = expected + $signed(xs[j]) * $signed(ws[j]);
        end
    endtask

    initial begin
        errors=0; seed=42;
        stall_inject=0; y_ready=0; start=0;
        x_valid=0; w_valid=0; x=0; w=0;

        rst_n = 0; repeat(4) @(negedge clk);
        rst_n = 1; repeat(2) @(negedge clk);

        // TEST 1: all ones, expect 64
        $display("[TEST 1] All-ones (expect y=64)");
        for (i=0;i<N;i=i+1) begin xs[i]=8'sd1; ws[i]=8'sd1; end
        compute_expected; run_mac(0,0);
        if (y!==expected) begin $display("  FAIL: exp=%0d got=%0d",expected,y); errors=errors+1; end
        else $display("  PASS: y=%0d",y);

        // TEST 2: max INT8
        $display("[TEST 2] Max positive INT8 (expect y=%0d)", 127*127*64);
        for (i=0;i<N;i=i+1) begin xs[i]=8'sd127; ws[i]=8'sd127; end
        compute_expected; run_mac(0,0);
        if (y!==expected) begin $display("  FAIL: exp=%0d got=%0d",expected,y); errors=errors+1; end
        else $display("  PASS: y=%0d",y);

        // TEST 3: alternating signs
        $display("[TEST 3] Alternating +127/-128 with w=1");
        for (i=0;i<N;i=i+1) begin xs[i]=(i%2==0)?8'sd127:-8'sd128; ws[i]=8'sd1; end
        compute_expected; run_mac(0,0);
        if (y!==expected) begin $display("  FAIL: exp=%0d got=%0d",expected,y); errors=errors+1; end
        else $display("  PASS: y=%0d",y);

        // TEST 4: stall injection
        $display("[TEST 4] Stall injection at iteration 20");
        for (i=0;i<N;i=i+1) begin xs[i]=$random(seed)%128; ws[i]=$random(seed)%128; end
        compute_expected; run_mac(1,0);
        if (y!==expected) begin $display("  FAIL: exp=%0d got=%0d",expected,y); errors=errors+1; end
        else $display("  PASS: y=%0d",y);

        // TEST 5: backpressure
        $display("[TEST 5] Output backpressure (5 cycle delay)");
        for (i=0;i<N;i=i+1) begin xs[i]=$random(seed)%128; ws[i]=$random(seed)%128; end
        compute_expected; run_mac(0,1);
        if (y!==expected) begin $display("  FAIL: exp=%0d got=%0d",expected,y); errors=errors+1; end
        else $display("  PASS: y=%0d",y);

        // TEST 6: random sweep
        $display("[TEST 6] Random vector sweep (10 runs)");
        seed=12345;
        repeat(10) begin
            for (i=0;i<N;i=i+1) begin xs[i]=$random(seed); ws[i]=$random(seed); end
            compute_expected; run_mac(0,0);
            if (y!==expected) begin $display("  FAIL: exp=%0d got=%0d",expected,y); errors=errors+1; end
        end
        if (errors==0) $display("  PASS: all random runs correct");

        $display("----------------------------------------");
        if (errors==0) $display("ALL TESTS PASSED");
        else           $display("FAILED: %0d error(s)",errors);
        $display("----------------------------------------");
        $finish;
    end

    initial begin #2000000; $display("TIMEOUT"); $finish; end

endmodule
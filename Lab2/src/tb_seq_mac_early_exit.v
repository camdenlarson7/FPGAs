`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/07/2026 07:16:25 PM
// Design Name: 
// Module Name: tb_seq_mac_early_exit
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


module tb_seq_mac_early_exit;

    localparam N     = 64;
    localparam CLK_P = 10;

    reg        clk, rst_n, start, stall_inject, y_ready;
    reg        x_valid, w_valid;
    reg  signed [7:0]  x, w;
    reg  signed [31:0] T;
    wire signed [31:0] y;
    wire               done, early_exit;

    seq_mac_early_exit #(.N(N)) dut (
        .clk(clk), .rst_n(rst_n), .start(start),
        .stall_inject(stall_inject), .y_ready(y_ready),
        .T(T), .x(x), .w(w), .x_valid(x_valid), .w_valid(w_valid),
        .y(y), .done(done), .early_exit(early_exit)
    );

    initial clk = 0;
    always #(CLK_P/2) clk = ~clk;

    reg signed [7:0]  xs [0:N-1];
    reg signed [7:0]  ws [0:N-1];
    reg signed [31:0] expected_y;
    integer           expected_exit_k;
    integer           errors, seed, i;

    
    
    // Golden model: compute expected_y and expected_exit_k for given threshold
    task compute_golden;
        input signed [31:0] thresh;
        integer j;
        reg signed [31:0] partial;
        begin
            partial = 32'sd0;
            expected_exit_k = -1;
            for (j = 0; j < N; j = j + 1) begin
                partial = partial + $signed(xs[j]) * $signed(ws[j]);
                if (thresh != 32'sd0 && expected_exit_k == -1) begin
                    if (partial >= thresh || partial <= -thresh)
                        expected_exit_k = j;
                end
            end
            if (expected_exit_k != -1) begin
                // Recompute partial sum up to exit point
                partial = 32'sd0;
                for (j = 0; j <= expected_exit_k; j = j + 1)
                    partial = partial + $signed(xs[j]) * $signed(ws[j]);
                expected_y = partial;
            end else begin
                // Full dot product
                partial = 32'sd0;
                for (j = 0; j < N; j = j + 1)
                    partial = partial + $signed(xs[j]) * $signed(ws[j]);
                expected_y = partial;
            end
        end
    endtask

    
    // Task: run one full (or early-exit) computation
    
    task run_mac;
        input inject_stall;
        input delay_ready;
        integer j, timeout;
        begin
            @(negedge clk); start = 1; x_valid = 0; w_valid = 0;
            @(negedge clk); start = 0;
            @(posedge clk); // IDLE -> CONFIG
            @(posedge clk); // CONFIG -> WAIT_IN

            for (j = 0; j < N; j = j + 1) begin
                if (inject_stall && j == 10) begin
                    @(negedge clk);
                    x = xs[j]; w = ws[j]; x_valid = 1; w_valid = 1;
                    stall_inject = 1;
                    @(posedge clk); // WAIT_IN stalls (inputs_ready=0)
                    @(posedge clk);
                    @(posedge clk);
                    @(negedge clk); stall_inject = 0;
                    @(posedge clk); // WAIT_IN -> COMPUTE
                    @(negedge clk); x_valid = 0; w_valid = 0;
                    @(posedge clk); // COMPUTE fires
                end else begin
                    @(negedge clk); x = xs[j]; w = ws[j]; x_valid = 1; w_valid = 1;
                    @(posedge clk); // WAIT_IN -> COMPUTE
                    @(negedge clk); x_valid = 0; w_valid = 0;
                    @(posedge clk); // COMPUTE fires
                end
            end

            
            timeout = 0;
            while (!done && timeout < 20) begin
                @(posedge clk);
                timeout = timeout + 1;
            end
            if (!done) $display("  ERROR: done never asserted (timeout)");

            // Output handshake
            if (delay_ready) repeat(5) @(posedge clk);
            @(negedge clk); y_ready = 1;
            @(posedge clk); // HOLD_OUT -> IDLE
            @(negedge clk); y_ready = 0;
            @(posedge clk); // settle
        end
    endtask

    // -------------------------------------------------------------------------
    // Tests
    // -------------------------------------------------------------------------
    initial begin
        errors = 0; seed = 42;
        stall_inject = 0; y_ready = 0; start = 0;
        x_valid = 0; w_valid = 0; x = 0; w = 0; T = 0;

        rst_n = 0; repeat(4) @(negedge clk);
        rst_n = 1; repeat(2) @(negedge clk);

        // ------------------------------------------------------------------
        // TEST 1: T=0 disabled, all-ones - full run, y=64, early_exit=0
        // ------------------------------------------------------------------
        $display("[TEST 1] T=0 disabled, all-ones (expect y=64, early_exit=0)");
        T = 32'sd0;
        for (i=0;i<N;i=i+1) begin xs[i]=8'sd1; ws[i]=8'sd1; end
        compute_golden(T); run_mac(0,0);
        if (y!==expected_y || early_exit!==1'b0) begin
            $display("  FAIL: exp_y=%0d got_y=%0d early_exit=%0b", expected_y, y, early_exit);
            errors=errors+1;
        end else $display("  PASS: y=%0d early_exit=%0b", y, early_exit);

        // ------------------------------------------------------------------
        // TEST 2: T very large - threshold never fires, y=64, early_exit=0
        // ------------------------------------------------------------------
        $display("[TEST 2] T=2000000 (never triggers), all-ones (expect y=64, early_exit=0)");
        T = 32'sd2000000;
        for (i=0;i<N;i=i+1) begin xs[i]=8'sd1; ws[i]=8'sd1; end
        compute_golden(T); run_mac(0,0);
        if (y!==expected_y || early_exit!==1'b0) begin
            $display("  FAIL: exp_y=%0d got_y=%0d early_exit=%0b", expected_y, y, early_exit);
            errors=errors+1;
        end else $display("  PASS: y=%0d early_exit=%0b", y, early_exit);

        // ------------------------------------------------------------------
        // TEST 3: T=1, x=2/w=1 - exits after k=0 (partial=2), early_exit=1
        // ------------------------------------------------------------------
        $display("[TEST 3] T=1, x=2/w=1 (expect early_exit at k=0, y=2)");
        T = 32'sd1;
        for (i=0;i<N;i=i+1) begin xs[i]=8'sd2; ws[i]=8'sd1; end
        compute_golden(T); run_mac(0,0);
        if (y!==expected_y || early_exit!==1'b1) begin
            $display("  FAIL: exp_y=%0d got_y=%0d early_exit=%0b (exp exit_k=%0d)",
                     expected_y, y, early_exit, expected_exit_k);
            errors=errors+1;
        end else $display("  PASS: y=%0d early_exit=%0b (exit_k=%0d)", y, early_exit, expected_exit_k);

        // ------------------------------------------------------------------
        // TEST 4: T=100, x=5/w=5 - positive exit at k=3 (partial=100)
        // ------------------------------------------------------------------
        $display("[TEST 4] T=100, x=5/w=5 (positive exit at k=3, y=100)");
        T = 32'sd100;
        for (i=0;i<N;i=i+1) begin xs[i]=8'sd5; ws[i]=8'sd5; end
        compute_golden(T); run_mac(0,0);
        if (y!==expected_y || early_exit!==1'b1) begin
            $display("  FAIL: exp_y=%0d got_y=%0d early_exit=%0b (exp exit_k=%0d)",
                     expected_y, y, early_exit, expected_exit_k);
            errors=errors+1;
        end else $display("  PASS: y=%0d early_exit=%0b (exit_k=%0d)", y, early_exit, expected_exit_k);

        // ------------------------------------------------------------------
        // TEST 5: T=100, x=-5/w=5 - negative exit at k=3 (partial=-100)
        // ------------------------------------------------------------------
        $display("[TEST 5] T=100, x=-5/w=5 (negative exit at k=3, y=-100)");
        T = 32'sd100;
        for (i=0;i<N;i=i+1) begin xs[i]=-8'sd5; ws[i]=8'sd5; end
        compute_golden(T); run_mac(0,0);
        if (y!==expected_y || early_exit!==1'b1) begin
            $display("  FAIL: exp_y=%0d got_y=%0d early_exit=%0b (exp exit_k=%0d)",
                     expected_y, y, early_exit, expected_exit_k);
            errors=errors+1;
        end else $display("  PASS: y=%0d early_exit=%0b (exit_k=%0d)", y, early_exit, expected_exit_k);

        // ------------------------------------------------------------------
        // TEST 6: T=64, x=1/w=1 - threshold hits exactly at k=N-1 (last iter)
        //         early_exit must be 0 (coincident with natural completion)
        // ------------------------------------------------------------------
        $display("[TEST 6] T=64, x=1/w=1 - coincident threshold+completion (early_exit=0)");
        T = 32'sd64;
        for (i=0;i<N;i=i+1) begin xs[i]=8'sd1; ws[i]=8'sd1; end
        compute_golden(T); run_mac(0,0);
        if (y!==expected_y || early_exit!==1'b0) begin
            $display("  FAIL: exp_y=%0d got_y=%0d early_exit=%0b (exp exit_k=%0d)",
                     expected_y, y, early_exit, expected_exit_k);
            errors=errors+1;
        end else $display("  PASS: y=%0d early_exit=%0b (exit_k=%0d, correctly 0)", y, early_exit, expected_exit_k);

        // ------------------------------------------------------------------
        // TEST 7: Stall injection with active threshold
        // ------------------------------------------------------------------
        $display("[TEST 7] T=500, stall at iter 10, random data");
        T = 32'sd500; seed = 42;
        for (i=0;i<N;i=i+1) begin xs[i]=$random(seed)%64; ws[i]=$random(seed)%64; end
        compute_golden(T); run_mac(1,0);
        if (y!==expected_y) begin
            $display("  FAIL: exp_y=%0d got_y=%0d early_exit=%0b (exp exit_k=%0d)",
                     expected_y, y, early_exit, expected_exit_k);
            errors=errors+1;
        end else $display("  PASS: y=%0d early_exit=%0b", y, early_exit);

        // ------------------------------------------------------------------
        // TEST 8: Output backpressure while in HOLD_OUT after early exit
        // ------------------------------------------------------------------
        $display("[TEST 8] T=200, x=10/w=10 - backpressure 5 cycles");
        T = 32'sd200;
        for (i=0;i<N;i=i+1) begin xs[i]=8'sd10; ws[i]=8'sd10; end
        compute_golden(T); run_mac(0,1);
        if (y!==expected_y) begin
            $display("  FAIL: exp_y=%0d got_y=%0d early_exit=%0b", expected_y, y, early_exit);
            errors=errors+1;
        end else $display("  PASS: y=%0d early_exit=%0b (held stable under backpressure)", y, early_exit);

        // ------------------------------------------------------------------
        // TEST 9: Random sweep T=0, 10 runs
        // ------------------------------------------------------------------
        $display("[TEST 9] Random sweep T=0 (10 runs)");
        T = 32'sd0; seed = 99999;
        repeat(10) begin
            for (i=0;i<N;i=i+1) begin xs[i]=$random(seed); ws[i]=$random(seed); end
            compute_golden(T); run_mac(0,0);
            if (y!==expected_y) begin
                $display("  FAIL: exp=%0d got=%0d", expected_y, y);
                errors=errors+1;
            end
        end
        if (errors==0) $display("  PASS: all T=0 random runs correct");

        // ------------------------------------------------------------------
        // TEST 10: Random sweep with random T, 10 runs
        // ------------------------------------------------------------------
        $display("[TEST 10] Random T sweep (10 runs)");
        seed = 77777;
        repeat(10) begin
            T = ($random(seed) % 5000) + 1; // T in [1..5000]
            for (i=0;i<N;i=i+1) begin xs[i]=$random(seed); ws[i]=$random(seed); end
            compute_golden(T); run_mac(0,0);
            if (y!==expected_y) begin
                $display("  FAIL: T=%0d exp=%0d got=%0d early_exit=%0b (exp exit_k=%0d)",
                         T, expected_y, y, early_exit, expected_exit_k);
                errors=errors+1;
            end
        end
        if (errors==0) $display("  PASS: all random T runs correct");

        $display("----------------------------------------");
        if (errors==0) $display("ALL TESTS PASSED");
        else           $display("FAILED: %0d error(s)", errors);
        $display("----------------------------------------");
        $finish;
    end

    initial begin #5000000; $display("TIMEOUT"); $finish; end

endmodule
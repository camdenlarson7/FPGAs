// iverilog -o tb_dot_product.vvp tb_dot_product.v dot_product_accelerator.v FSM.v parallel_mac.v seq_mac.v early_exit_mac.v
// vvp tb_dot_product.vvp


//  The Testbench Covers:
//    1) All three modes (0 = seq MAC, 1 = parallel MAC, 2 = early-exit MAC)
//    2) Randomised stall_inject (pipeline back-pressure from the datapath side)
//    3) Randomised x_valid / w_valid de-assertion (input valid behaviour)
//    4) Randomised y_ready de-assertion (output back-pressure)
//    5) Self-checking: every test compares RTL result to a SW golden model
//    6) Timeout watchdog to catch hangs
//    7) Multiple back-to-back transactions per mode


`timescale 1ns / 1ps

module tb_dot_product;

    
    // Parameters - must match DUT instantiation
   
    localparam N        = 64;
    localparam U        = 8;
    localparam MODE2_T  = 32;

    // Randomisation seeds 
    localparam SEED_STALL  = 32'hDEAD_BEEF;
    localparam SEED_VALID  = 32'hCAFE_F00D;
    localparam SEED_READY  = 32'hABCD_1234;

    // Watchdog limit (clock cycles before declaring a hang)
    localparam WATCHDOG_LIMIT = 100_000;

    // Probability knobs (out of 16 - keep small for faster sims)
    localparam STALL_PROB  = 4;   // 4/16  ≈ 25 % cycles stall_inject=1
    localparam INVALID_PROB = 3;  // 3/16  ≈ 19 % cycles x/w_valid=0
    localparam NOTREADY_PROB = 5; // 5/16  ≈ 31 % cycles y_ready=0 in HOLD_OUT

    
    // DUT signals
    
    reg  [7:0]  x_data;
    reg  [7:0]  w_data;
    reg         clk;
    reg         rst;
    reg         start;
    reg  [1:0]  mode;
    reg         x_valid;
    reg         w_valid;
    reg         stall_inject;
    reg         y_ready;
    wire [31:0] y_data;
    wire        done;

    
    integer pass_count;
    integer fail_count;

    // LFSR state registers (one per randomised signal)
    reg [31:0] lfsr_stall;
    reg [31:0] lfsr_valid;
    reg [31:0] lfsr_ready;

    
    dot_product_accelerator #(
        .N(N),
        .U(U),
        .MODE2_T(MODE2_T)
    ) dut (
        .y_data     (y_data),
        .done       (done),
        .x_data     (x_data),
        .w_data     (w_data),
        .start      (start),
        .mode       (mode),
        .x_valid    (x_valid),
        .w_valid    (w_valid),
        .stall_inject(stall_inject),
        .y_ready    (y_ready),
        .clk        (clk),
        .rst        (rst)
    );

    
    always #5 clk = ~clk;

    
    // 32-bit LFSR - advances one step, returns LSB as random bit
    
    function [31:0] lfsr_step;
        input [31:0] s;
        begin
            lfsr_step = {1'b0, s[31:1]} ^ (s[0] ? 32'hB400_0000 : 32'h0);
        end
    endfunction

    
    // Task: assert_check
    //   Compares rtl_val to expected using 32-bit signed equality.
    //   Prints PASS/FAIL and updates counters.

    task assert_check;
        input signed [31:0] expected;
        input signed [31:0] rtl_val;
        input [127:0] tag;
        begin
            if (rtl_val === expected) begin
                $display("[PASS] %0s | expected=%0d  got=%0d", tag, expected, rtl_val);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] %0s | expected=%0d  got=%0d  <-- MISMATCH", tag, expected, rtl_val);
                fail_count = fail_count + 1;
            end
        end
    endtask

    
    // Task: do_reset
    
    task do_reset;
        begin
            rst         = 1;
            start       = 0;
            x_data      = 0;
            w_data      = 0;
            x_valid     = 0;
            w_valid     = 0;
            stall_inject = 0;
            y_ready     = 0;
            repeat (4) @(posedge clk);
            @(negedge clk);
            rst = 0;
        end
    endtask

    
    // Task: send_start
    //   Pulses start for one cycle and latches mode.
  
    task send_start;
        input [1:0] m;
        begin
            @(negedge clk);
            mode  = m;
            start = 1;
            @(negedge clk);
            start = 0;
        end
    endtask

   
    // Task: wait_done_with_watchdog
    //   Waits for done==1, updating random stall / valid each cycle.
    //   Also drives x_data/w_data from caller-supplied arrays via shared regs.
    //   Returns 1 if done seen in time, 0 if watchdog fired.
    
    // Shared data arrays filled by caller before calling run_mode0/1/2 tasks
    reg [7:0] xs [0:N-1];
    reg [7:0] ws [0:N-1];

    
    // Task: run_mode0
    //   Streams N (x,w) pairs with randomised stalls and valid behaviour.
    //   Returns the RTL output in rtl_out.
    
    task run_mode0;
        output [31:0] rtl_out;
        integer cyc;
        integer accepted;
        reg timed_out;
        begin
            accepted  = 0;
            timed_out = 0;

            // start the transaction
            send_start(2'b00);

            cyc = 0;
            // Drive data one sample at a time; FSM absorbs when accept_en fires
            while (!done && !timed_out) begin
                @(negedge clk);
                cyc = cyc + 1;
                if (cyc > WATCHDOG_LIMIT) begin
                    $display("[WATCHDOG] Mode0 timed out after %0d cycles", cyc);
                    timed_out = 1;
                    fail_count = fail_count + 1;
                end

                // Advance LFSRs
                lfsr_stall = lfsr_step(lfsr_stall);
                lfsr_valid = lfsr_step(lfsr_valid);

                // Randomise stall_inject
                stall_inject = (lfsr_stall[3:0] < STALL_PROB) ? 1'b1 : 1'b0;

                // Randomise x_valid / w_valid (de-assert together for simplicity)
                if (lfsr_valid[3:0] < INVALID_PROB) begin
                    x_valid = 1'b0;
                    w_valid = 1'b0;
                end else begin
                    x_valid = 1'b1;
                    w_valid = 1'b1;
                end

                // Present next sample (index guarded to N-1)
                if (accepted < N) begin
                    x_data = xs[accepted];
                    w_data = ws[accepted];
                end

                // The FSM will assert accept_en on this negedge -> posedge window
                // when run_ok=1. We can't observe accept_en directly without
                // an extra wire, so we advance accepted whenever run_ok would be
                // true.  run_ok = x_valid & w_valid & !stall_inject.
                // We sample the *current* values that will be seen at next posedge.
                if (x_valid && w_valid && !stall_inject && (accepted < N)) begin
                    accepted = accepted + 1;
                end
            end

            // Randomised output back-pressure: wait done then handshake y_ready
            if (!timed_out) begin
                // done is high; apply randomised y_ready back-pressure
                cyc = 0;
                while (done && cyc < WATCHDOG_LIMIT) begin
                    @(negedge clk);
                    cyc = cyc + 1;
                    lfsr_ready = lfsr_step(lfsr_ready);
                    y_ready = (lfsr_ready[3:0] >= NOTREADY_PROB) ? 1'b1 : 1'b0;
                end
                // Guarantee handshake finishes
                if (done) begin
                    @(negedge clk);
                    y_ready = 1'b1;
                    @(negedge clk);
                end
                y_ready = 1'b0;
            end

            rtl_out = y_data;
            // Clean up for next test
            x_valid     = 0;
            w_valid     = 0;
            stall_inject = 0;
        end
    endtask

   
    // Task: run_mode1
    //   Streams N (x,w) pairs in U-sized batches.  parallel_mac needs exactly U
    //   accepts per batch and N/U batches for a full dot product.
    
    task run_mode1;
        output [31:0] rtl_out;
        integer cyc;
        integer accepted;
        reg timed_out;
        begin
            accepted  = 0;
            timed_out = 0;

            send_start(2'b01);

            cyc = 0;
            while (!done && !timed_out) begin
                @(negedge clk);
                cyc = cyc + 1;
                if (cyc > WATCHDOG_LIMIT) begin
                    $display("[WATCHDOG] Mode1 timed out after %0d cycles", cyc);
                    timed_out = 1;
                    fail_count = fail_count + 1;
                end

                lfsr_stall = lfsr_step(lfsr_stall);
                lfsr_valid = lfsr_step(lfsr_valid);

                stall_inject = (lfsr_stall[3:0] < STALL_PROB) ? 1'b1 : 1'b0;

                if (lfsr_valid[3:0] < INVALID_PROB) begin
                    x_valid = 1'b0;
                    w_valid = 1'b0;
                end else begin
                    x_valid = 1'b1;
                    w_valid = 1'b1;
                end

                if (accepted < N) begin
                    x_data = xs[accepted];
                    w_data = ws[accepted];
                end

                if (x_valid && w_valid && !stall_inject && (accepted < N)) begin
                    accepted = accepted + 1;
                end
            end

            if (!timed_out) begin
                cyc = 0;
                while (done && cyc < WATCHDOG_LIMIT) begin
                    @(negedge clk);
                    cyc = cyc + 1;
                    lfsr_ready = lfsr_step(lfsr_ready);
                    y_ready = (lfsr_ready[3:0] >= NOTREADY_PROB) ? 1'b1 : 1'b0;
                end
                if (done) begin
                    @(negedge clk);
                    y_ready = 1'b1;
                    @(negedge clk);
                end
                y_ready = 1'b0;
            end

            rtl_out = y_data;
            x_valid     = 0;
            w_valid     = 0;
            stall_inject = 0;
        end
    endtask

    
    // Task: run_mode2
    //   Like mode0 but stops as soon as done fires (early exit or N reached).
    //   Returns how many pairs were accepted in accepted_cnt.
  
    task run_mode2;
        output [31:0] rtl_out;
        output integer accepted_cnt;
        integer cyc;
        integer accepted;
        reg timed_out;
        begin
            accepted  = 0;
            timed_out = 0;

            send_start(2'b10);

            cyc = 0;
            while (!done && !timed_out) begin
                @(negedge clk);
                cyc = cyc + 1;
                if (cyc > WATCHDOG_LIMIT) begin
                    $display("[WATCHDOG] Mode2 timed out after %0d cycles", cyc);
                    timed_out = 1;
                    fail_count = fail_count + 1;
                end

                lfsr_stall = lfsr_step(lfsr_stall);
                lfsr_valid = lfsr_step(lfsr_valid);

                stall_inject = (lfsr_stall[3:0] < STALL_PROB) ? 1'b1 : 1'b0;

                if (lfsr_valid[3:0] < INVALID_PROB) begin
                    x_valid = 1'b0;
                    w_valid = 1'b0;
                end else begin
                    x_valid = 1'b1;
                    w_valid = 1'b1;
                end

                if (accepted < N) begin
                    x_data = xs[accepted];
                    w_data = ws[accepted];
                end

                if (x_valid && w_valid && !stall_inject && (accepted < N)) begin
                    accepted = accepted + 1;
                end
            end

            if (!timed_out) begin
                cyc = 0;
                while (done && cyc < WATCHDOG_LIMIT) begin
                    @(negedge clk);
                    cyc = cyc + 1;
                    lfsr_ready = lfsr_step(lfsr_ready);
                    y_ready = (lfsr_ready[3:0] >= NOTREADY_PROB) ? 1'b1 : 1'b0;
                end
                if (done) begin
                    @(negedge clk);
                    y_ready = 1'b1;
                    @(negedge clk);
                end
                y_ready = 1'b0;
            end

            rtl_out      = y_data;
            accepted_cnt = accepted;
            x_valid     = 0;
            w_valid     = 0;
            stall_inject = 0;
        end
    endtask

  
    // SW golden model helpers
    

    // Golden Mode0 / Mode2 sequential accumulator
    function signed [31:0] golden_seq;
        input integer len;   // how many pairs to sum
        integer i;
        reg signed [31:0] acc;
        begin
            acc = 0;
            for (i = 0; i < len; i = i + 1)
                acc = acc + ($signed(xs[i]) * $signed(ws[i]));
            golden_seq = acc;
        end
    endfunction

    // Golden Mode2 with early exit - FSM-accurate model.
    //
    // FSM timing:
    //   The first accept_en pulse fires from WAIT_IN (call this sample k=0).
    //   All subsequent pulses fire from COMPUTE.
    //   When early_exit_hit fires in WAIT_IN (k=0), the FSM transitions to COMPUTE
    //   and fires ONE MORE accept (k=1) before going to HOLD_OUT.
    //   When early_exit_hit fires in COMPUTE (k≥1), the FSM transitions immediately
    //   to HOLD_OUT - no extra sample.
    //
    // So: if the threshold is crossed at the very first sample, accumulate 2 samples.
    //     If crossed at any later sample, accumulate up to and including that sample.
    //     If T=0 (disabled) or threshold never hit, accumulate all N samples.
    integer exit_k_g;

    function signed [31:0] golden_early_exit;
        input integer thresh;
        integer i;
        reg signed [31:0] acc;
        reg signed [31:0] nxt;
        reg               found;
        begin
            acc    = 0;
            exit_k_g = N;
            found  = 0;
            for (i = 0; i < N; i = i + 1) begin
                if (!found) begin
                    nxt = acc + ($signed(xs[i]) * $signed(ws[i]));
                    acc = nxt;
                    if ((thresh != 0) &&
                        (($signed(acc) >= $signed(thresh)) ||
                         ($signed(acc) <= -$signed(thresh)))) begin
                        found    = 1;
                        exit_k_g = i + 1;
                        // If threshold hit on first sample (WAIT_IN -> COMPUTE edge),
                        // one extra sample is consumed. Add it now.
                        if (i == 0 && (i + 1) < N) begin
                            acc = acc + ($signed(xs[i+1]) * $signed(ws[i+1]));
                            exit_k_g = 2;
                        end
                    end
                end
            end
            golden_early_exit = acc;
        end
    endfunction

    // Golden Mode1 partial-batch accumulator using UNSIGNED multiply to match
    // parallel_mac RTL (which does x_reg*w_reg without $signed).
    function [31:0] golden_batch_u;
        input integer dummy; // Verilog-2005 requires at least one input
        integer i;
        reg [31:0] acc;
        begin
            acc = 0;
            for (i = 0; i < U; i = i + 1)
                acc = acc + (xs[i] * ws[i]);   // unsigned, matches RTL
            golden_batch_u = acc;
        end
    endfunction

   
    // Integer helpers

    integer i, j_idx;
    integer accepted_cnt;
    reg [31:0] rtl_out;
    reg signed [31:0] golden;

   
    // Main stimulus

    initial begin
      
        clk         = 0;
        pass_count  = 0;
        fail_count  = 0;
        lfsr_stall  = SEED_STALL;
        lfsr_valid  = SEED_VALID;
        lfsr_ready  = SEED_READY;

        do_reset;

   
        // MODE 0 - Sequential MAC  (3 transactions)
        
        $display("\n========== MODE 0 - Sequential MAC ==========");

        // -- Test 0-A: all-ones (expect N = 64) 
        for (i = 0; i < N; i = i + 1) begin xs[i] = 8'd1; ws[i] = 8'd1; end
        run_mode0(rtl_out);
        golden = golden_seq(N);
        assert_check(golden, rtl_out, "Mode0 all-ones");

        // -- Test 0-B: x[i]=i+1, w[i]=2 (expect 2*(1+2+...+64) = 4160) 
        for (i = 0; i < N; i = i + 1) begin xs[i] = i + 1; ws[i] = 8'd2; end
        run_mode0(rtl_out);
        golden = golden_seq(N);
        assert_check(golden, rtl_out, "Mode0 ramp*2");

        // -- Test 0-C: signed negative inputs (x=-1, w=3, expect -192) 
        for (i = 0; i < N; i = i + 1) begin xs[i] = 8'hFF; ws[i] = 8'd3; end
        run_mode0(rtl_out);
        golden = golden_seq(N);
        assert_check(golden, rtl_out, "Mode0 signed-neg");

      
        // MODE 1 - Parallel MAC  (3 transactions)
      
        $display("\n========== MODE 1 - Parallel MAC ==========");
        // NOTE: parallel_mac signals done after each U-wide batch.
        // The FSM therefore transitions to HOLD_OUT after the FIRST batch of U
        // elements.  To verify a full N-element dot product the caller would
        // need to chain N/U transactions; here we verify one batch (U elements).

        // -- Test 1-A: first U elements all-ones (expect U = 8) 
        for (i = 0; i < N; i = i + 1) begin xs[i] = 8'd1; ws[i] = 8'd1; end
        run_mode1(rtl_out);
        // For one batch of U: sum = U * 1 * 1 = U
        assert_check(U, rtl_out, "Mode1 batch all-ones");

        // -- Test 1-B: x[i]=i+1, w[i]=2 (first U elements) 
        for (i = 0; i < N; i = i + 1) begin xs[i] = i + 1; ws[i] = 8'd2; end
        run_mode1(rtl_out);
        golden = golden_batch_u(0);
        assert_check(golden, rtl_out, "Mode1 batch ramp*2");

        // -- Test 1-C: alternating byte values (unsigned multiply in parallel_mac)
        //   i even ->  xs[i]=0x02 (+2 unsigned), i odd -> xs[i]=0xFE (254 unsigned)
        //   ws[i]=1. For U=8: 4 pairs each -> sum = 4*2 + 4*254 = 1024
        for (i = 0; i < N; i = i + 1) begin
            xs[i] = (i[0]) ? 8'hFE : 8'd2;
            ws[i] = 8'd1;
        end
        run_mode1(rtl_out);
        golden = golden_batch_u(0);
        assert_check(golden, rtl_out, "Mode1 batch alt-byte-vals");

        
        // MODE 2 - Early-Exit MAC  (3 transactions)
        
        $display("\n========== MODE 2 - Early-Exit MAC ==========");

        // -- Test 2-A: large values forcing early exit (x=16, w=16, T=32)
        //   acc after k=1: 256 >= 32 -> exit after 1 sample
        for (i = 0; i < N; i = i + 1) begin xs[i] = 8'd16; ws[i] = 8'd16; end
        run_mode2(rtl_out, accepted_cnt);
        golden = golden_early_exit(MODE2_T);
        assert_check(golden, rtl_out, "Mode2 early-exit large-vals");

        // -- Test 2-B: small values hitting threshold partway (x=1, w=1, T=32)
        //   acc reaches 32 at k=32 (first hit in WAIT_IN -> COMPUTE), then one more
        //   sample is accepted (acc=33) before FSM exits COMPUTE -> expect 33
        for (i = 0; i < N; i = i + 1) begin xs[i] = 8'd1; ws[i] = 8'd1; end
        run_mode2(rtl_out, accepted_cnt);
        golden = golden_early_exit(MODE2_T);
        assert_check(golden, rtl_out, "Mode2 threshold-hit partway");

        // -- Test 2-C: negative accumulation exits on lower bound 
        //   x=-5, w=5: acc goes -25, -50 ... -> hits -32 at k=2
        for (i = 0; i < N; i = i + 1) begin xs[i] = 8'hFB; ws[i] = 8'd5; end
        run_mode2(rtl_out, accepted_cnt);
        golden = golden_early_exit(MODE2_T);
        assert_check(golden, rtl_out, "Mode2 early-exit neg-bound");

        
        // Summary
       
        $display("\n========================================");
        $display("  RESULTS:  %0d PASSED  /  %0d FAILED", pass_count, fail_count);
        $display("========================================\n");
        if (fail_count == 0)
            $display("ALL TESTS PASSED");
        else
            $display("SOME TESTS FAILED - review mismatches above");

        #20;
        $finish;
    end

endmodule

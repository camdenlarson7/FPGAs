`timescale 1ns / 1ps

// On-board validation for dot_product_accelerator

// Hold BTN0 to reset; release to (re-)run all three tests automatically.
//
// What is tested
// --------------
//  Test 0  -  Mode 0 (seq_mac)        : N=64 all-ones  -> y = 64
//  Test 1  -  Mode 1 (parallel_mac)   : N=8,  U=8      -> y = 8   (one full batch)
//  Test 2  -  Mode 2 (early_exit_mac) : N=64 all-ones,
//                                        T=0  (disabled) -> y = 64
//
// LED mapping (LD0-LD3, active-high)
//  LD0  -  Mode 0 PASS
//  LD1  -  Mode 1 PASS
//  LD2  -  Mode 2 PASS
//  LD3  -  All three PASS  (all correct -> all four LEDs light)
//
//  Mode 0 / Mode 2 : FSM asserts accept_en every cycle that
//                    x_valid & w_valid & !stall_inject is true.
//                    -> hold x_valid=w_valid=1 continuously; the FSM does
//                      the counting internally via seq_mac / early_exit_mac.
//
//  Mode 1          : same continuous-valid approach. parallel_mac gates
//                    itself with !add_active and counts fill_count
//                    internally, so no slot-by-slot toggling is needed.
//

 
module dpa_led_test (
    input  wire       clk,       
    input  wire       btn_rst,   // BTN0: press = reset/hold, release = run (D19)
    output reg  [3:0] led        
);
 
    
    // Parameters
    localparam N_SEQ  = 64;   // elements for Mode 0 and Mode 2
    localparam N_PAR  = 8;    // elements for Mode 1 (= U, one full batch)
    localparam U      = 8;    // parallelism of parallel_mac
    localparam T_MODE2 = 0;   // early-exit threshold = 0 -> disabled, full run
 
    localparam EXP_MODE0 = 32'd64;  
    localparam EXP_MODE1 = 32'd8;    
    localparam EXP_MODE2 = 32'd64;   
 
    
    // Reset synchroniser
    reg rst_meta, rst_sync;
    always @(posedge clk) begin
        rst_meta <= btn_rst;
        rst_sync <= rst_meta;
    end
    // rst_sync is the synchronised, active-high reset used everywhere below.
 
    
    // DUT signals
    
    reg        start;
    reg [1:0]  mode;
    reg        x_valid, w_valid;
    reg        y_ready;
    wire [31:0] y_data;
    wire        done;
 
    
    wire [31:0] y0;
    wire        done0;
    dot_product_accelerator #(.N(N_SEQ), .U(U), .MODE2_T(0)) u_dpa0 (
        .clk         (clk),
        .rst         (rst_sync),
        .mode        (mode),
        .start       (start),
        .stall_inject(1'b0),
        .y_ready     (y_ready),
        .x_data      (8'h01),
        .w_data      (8'h01),
        .x_valid     (x_valid),
        .w_valid     (w_valid),
        .y_data      (y0),
        .done        (done0)
    );
 
    // -- Mode 1: N=8, U=8, T=0  (one full batch = full dot product) -----------
    wire [31:0] y1;
    wire        done1;
    dot_product_accelerator #(.N(N_PAR), .U(U), .MODE2_T(0)) u_dpa1 (
        .clk         (clk),
        .rst         (rst_sync),
        .mode        (mode),
        .start       (start),
        .stall_inject(1'b0),
        .y_ready     (y_ready),
        .x_data      (8'h01),
        .w_data      (8'h01),
        .x_valid     (x_valid),
        .w_valid     (w_valid),
        .y_data      (y1),
        .done        (done1)
    );
 
    // -- Mode 2: N=64, U=8, T=0 (early-exit disabled, full run) ---------------
    wire [31:0] y2;
    wire        done2;
    dot_product_accelerator #(.N(N_SEQ), .U(U), .MODE2_T(T_MODE2)) u_dpa2 (
        .clk         (clk),
        .rst         (rst_sync),
        .mode        (mode),
        .start       (start),
        .stall_inject(1'b0),
        .y_ready     (y_ready),
        .x_data      (8'h01),
        .w_data      (8'h01),
        .x_valid     (x_valid),
        .w_valid     (w_valid),
        .y_data      (y2),
        .done        (done2)
    );
 
    // Mux the active DUT outputs based on which test is running
    // test_id: 0=mode0, 1=mode1, 2=mode2
    reg [1:0] test_id;
    wire [31:0] y_active = (test_id == 2'd0) ? y0 :
                           (test_id == 2'd1) ? y1 : y2;
    wire        done_active = (test_id == 2'd0) ? done0 :
                              (test_id == 2'd1) ? done1 : done2;
 
    
    // Sequencer FSM
   
    localparam [3:0]
        S_IDLE      = 4'd0,   // wait for rst to deassert
        S_START     = 4'd1,   // pulse start for one cycle
        S_RUNNING   = 4'd2,   // hold x_valid=w_valid=1 until done
        S_ACK       = 4'd3,   // pulse y_ready for one cycle
        S_CHECK     = 4'd4,   // latch pass/fail
        S_NEXT      = 4'd5,   // advance to next test or finish
        S_DONE      = 4'd6;   // hold LEDs forever
 
    reg [3:0]  state;
    reg [15:0] watchdog;      // safety timeout 
    reg        pass0, pass1, pass2;
 
    // Modes sent to DUT per test
    // test_id 0 -> mode 2'b00 (seq_mac)
    // test_id 1 -> mode 2'b01 (parallel_mac)
    // test_id 2 -> mode 2'b10 (early_exit_mac)
    wire [1:0] mode_for_test = test_id[1:0];  // same encoding by design
 
    // Expected result per test
    wire [31:0] expected = (test_id == 2'd0) ? EXP_MODE0 :
                           (test_id == 2'd1) ? EXP_MODE1 : EXP_MODE2;
 
    always @(posedge clk) begin
        if (rst_sync) begin
            // ---- synchronous reset ----
            state    <= S_IDLE;
            test_id  <= 2'd0;
            watchdog <= 16'd0;
            pass0    <= 1'b0;
            pass1    <= 1'b0;
            pass2    <= 1'b0;
            led      <= 4'b0000;
            start    <= 1'b0;
            y_ready  <= 1'b0;
            x_valid  <= 1'b0;
            w_valid  <= 1'b0;
            mode     <= 2'b00;
        end else begin
            // Default: de-assert all one-cycle pulses
            start   <= 1'b0;
            y_ready <= 1'b0;
 
            case (state)
 
                
                // S_IDLE: one idle cycle after reset clears; then kick off test 0
                
                S_IDLE: begin
                    test_id <= 2'd0;
                    state   <= S_START;
                end
 
                // -----------------------------------------------------------------
                // S_START: set mode, pulse start, arm valid signals
                // The DUT FSM will transition IDLE → CONFIG on this posedge,
                // then CONFIG → WAIT_IN on the next posedge.
                // We begin asserting x_valid/w_valid here so they are already
                // high when the FSM reaches WAIT_IN one cycle later.
                // -----------------------------------------------------------------
                S_START: begin
                    mode     <= mode_for_test;
                    start    <= 1'b1;
                    x_valid  <= 1'b1;
                    w_valid  <= 1'b1;
                    watchdog <= 16'd0;
                    state    <= S_RUNNING;
                end
 
                
                // S_RUNNING: keep valid high; DUT FSM controls accept_en.
                S_RUNNING: begin
                    x_valid  <= 1'b1;
                    w_valid  <= 1'b1;
                    watchdog <= watchdog + 1'b1;
 
                    if (done_active) begin
                        // De-assert valid before the ACK cycle
                        x_valid <= 1'b0;
                        w_valid <= 1'b0;
                        state   <= S_ACK;
                    end else if (watchdog == 16'hFFFF) begin
                        // Timeout: force a fail for this test
                        x_valid <= 1'b0;
                        w_valid <= 1'b0;
                        state   <= S_CHECK;   // skip ACK; DUT still in COMPUTE
                    end
                end
 
                
                // S_ACK: pulse y_ready for one cycle -> DUT transitions
                S_ACK: begin
                    y_ready <= 1'b1;
                    state   <= S_CHECK;
                end
 
                
                // S_CHECK: compare y_data against the expected value and latch result
                S_CHECK: begin
                    case (test_id)
                        2'd0: pass0 <= (y_active == expected);
                        2'd1: pass1 <= (y_active == expected);
                        2'd2: pass2 <= (y_active == expected);
                        default: ;
                    endcase
                    state <= S_NEXT;
                end
 
                
                // S_NEXT: advance to the next test or latch final LED state
                
                S_NEXT: begin
                    if (test_id == 2'd2)
                        state <= S_DONE;
                    else begin
                        test_id <= test_id + 1'b1;
                        state   <= S_START;
                    end
                end
 
                
                // S_DONE: drive LEDs and hold until next reset
                
                S_DONE: begin
                    led[0] <= pass0;
                    led[1] <= pass1;
                    led[2] <= pass2;
                    led[3] <= pass0 & pass1 & pass2;
                end
 
                default: state <= S_IDLE;
 
            endcase
        end
    end
 
endmodule
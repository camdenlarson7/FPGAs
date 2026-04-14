// =============================================================================
// fpga_top.v
// Verilog wrapper for the nn_demo_top HLS IP.
//
// Button (BTN0):
//   - First  press : starts computation (LEDs clear, IP runs)
//   - Second press : restarts from scratch
//
// LED mapping:
//   LED0 = linear_pass  (Part A result)
//   LED1 = 0            (unused)
//   LED2 = conv_pass    (Part B result)
//   LED3 = done         (computation finished)
//
// Clock: 100 MHz from PS FCLK_CLK0 (connect in Vivado block design)
//        or add a board-oscillator clock via XDC.
// =============================================================================

module fpga_top (
    input        clk,       // 125 MHz system clock
    input        btn,       // BTN0 (D19) — run
    input        btn_rst,   // BTN1 (D20) — reset / clear LEDs
    output [3:0] leds       // leds_4bits_tri_o[3:0]
);

    // -----------------------------------------------------------------------
    // Button synchroniser + rising-edge detect (avoids metastability)
    // -----------------------------------------------------------------------
    reg btn_s0, btn_s1, btn_s2;

    always @(posedge clk) begin
        btn_s0 <= btn;
        btn_s1 <= btn_s0;
        btn_s2 <= btn_s1;
    end

    wire btn_rise = btn_s1 & ~btn_s2;  // one-cycle pulse on rising edge (run)

    // Synchronise BTN1 (reset)
    reg rst_s0, rst_s1, rst_s2;
    always @(posedge clk) begin
        rst_s0 <= btn_rst;
        rst_s1 <= rst_s0;
        rst_s2 <= rst_s1;
    end
    wire rst_rise = rst_s1 & ~rst_s2;  // one-cycle pulse on rising edge (reset)

    // -----------------------------------------------------------------------
    // FSM
    // -----------------------------------------------------------------------
    localparam IDLE    = 3'd0;
    localparam RESET   = 3'd1;
    localparam START   = 3'd2;
    localparam RUNNING = 3'd3;
    localparam DONE    = 3'd4;

    reg [2:0] state;

    reg        ap_start_r;
    reg        ap_rst_r;
    reg        led0_r;    // linear_pass latch
    reg        led2_r;    // conv_pass latch
    reg        led3_r;    // done latch

    // HLS IP outputs
    wire       ap_done;
    wire       ap_idle;
    wire       ap_ready;
    wire       linear_pass_w;
    wire       conv_pass_w;

    always @(posedge clk) begin
        // Default: deassert start and reset each cycle
        ap_start_r <= 1'b0;
        ap_rst_r   <= 1'b0;

        // BTN1 resets from any state
        if (rst_rise) begin
            ap_rst_r <= 1'b1;
            led0_r   <= 1'b0;
            led2_r   <= 1'b0;
            led3_r   <= 1'b0;
            state    <= IDLE;
        end else

        case (state)

            // -----------------------------------------------------------------
            // Wait for BTN0 to start
            IDLE: begin
                if (btn_rise) begin
                    ap_rst_r <= 1'b1;
                    state    <= RESET;
                end
            end

            // -----------------------------------------------------------------
            // Hold reset until IP signals ap_idle, then proceed
            RESET: begin
                ap_rst_r <= 1'b1;
                if (ap_idle) begin
                    ap_rst_r <= 1'b0;
                    state    <= START;
                end
            end

            // -----------------------------------------------------------------
            // Assert ap_start for one cycle
            START: begin
                ap_start_r <= 1'b1;
                state      <= RUNNING;
            end

            // -----------------------------------------------------------------
            RUNNING: begin
                if (ap_done) begin
                    led0_r <= linear_pass_w;
                    led2_r <= conv_pass_w;
                    led3_r <= 1'b1;
                    state  <= DONE;
                end
            end

            // -----------------------------------------------------------------
            // Hold LEDs until BTN1 resets (handled above)
            DONE: begin
            end

        endcase
    end

    // -----------------------------------------------------------------------
    // HLS IP instantiation
    // (module name matches the HLS function name after export)
    // -----------------------------------------------------------------------
    nn_demo_top_0 u_nn_demo (
        .ap_clk      (clk),
        .ap_rst      (ap_rst_r),
        .ap_start    (ap_start_r),
        .ap_done     (ap_done),
        .ap_idle     (ap_idle),
        .ap_ready    (ap_ready),
        .linear_pass (linear_pass_w),
        .conv_pass   (conv_pass_w)
    );

    // -----------------------------------------------------------------------
    // LED output
    // -----------------------------------------------------------------------
    assign leds[0] = led0_r;
    assign leds[1] = 1'b0;
    assign leds[2] = led2_r;
    assign leds[3] = led3_r;

endmodule

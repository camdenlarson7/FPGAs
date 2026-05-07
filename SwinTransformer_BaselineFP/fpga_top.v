module fpga_top (
    input        clk,       // 125 MHz system clock (H16)
    input        btn,       // BTN0 (D19) — run
    input        btn_rst,   // BTN1 (D20) — reset / clear LEDs
    output [3:0] leds       // leds[3:0]: R14 P14 N16 M14
);

    // Button synchroniser + rising-edge detect (avoids metastability)
    
    reg btn_s0, btn_s1, btn_s2;
    always @(posedge clk) begin
        btn_s0 <= btn;
        btn_s1 <= btn_s0;
        btn_s2 <= btn_s1;
    end
    wire btn_rise = btn_s1 & ~btn_s2;

    reg rst_s0, rst_s1, rst_s2;
    always @(posedge clk) begin
        rst_s0 <= btn_rst;
        rst_s1 <= rst_s0;
        rst_s2 <= rst_s1;
    end
    wire rst_rise = rst_s1 & ~rst_s2;

    
    // FSM
    localparam IDLE    = 3'd0;
    localparam RESET   = 3'd1;
    localparam START   = 3'd2;
    localparam RUNNING = 3'd3;
    localparam DONE    = 3'd4;

    reg [2:0] state;

    reg ap_start_r;
    reg ap_rst_r;
    reg led0_r;   // swin_pass latch
    reg led3_r;   // done latch

    wire ap_done;
    wire ap_idle;
    wire ap_ready;
    wire swin_pass_w;

    always @(posedge clk) begin
        ap_start_r <= 1'b0;
        ap_rst_r   <= 1'b0;

        if (rst_rise) begin
            ap_rst_r <= 1'b1;
            led0_r   <= 1'b0;
            led3_r   <= 1'b0;
            state    <= IDLE;
        end else

        case (state)

            IDLE: begin
                if (btn_rise) begin
                    ap_rst_r <= 1'b1;
                    state    <= RESET;
                end
            end

            // Hold reset until IP signals ap_idle
            RESET: begin
                ap_rst_r <= 1'b1;
                if (ap_idle) begin
                    ap_rst_r <= 1'b0;
                    state    <= START;
                end
            end

            // Assert ap_start for one cycle
            START: begin
                ap_start_r <= 1'b1;
                state      <= RUNNING;
            end

            RUNNING: begin
                if (ap_done) begin
                    led0_r <= swin_pass_w;
                    led3_r <= 1'b1;
                    state  <= DONE;
                end
            end

            DONE: begin
                // Hold LEDs until BTN1 resets (handled above)
            end

            default: state <= IDLE;

        endcase
    end

    // HLS IP instantiation
    // module_name used in create_ip: swin_demo_top_0
    swin_demo_top_0 u_swin_demo (
        .ap_clk    (clk),
        .ap_rst    (ap_rst_r),
        .ap_start  (ap_start_r),
        .ap_done   (ap_done),
        .ap_idle   (ap_idle),
        .ap_ready  (ap_ready),
        .swin_pass (swin_pass_w)
    );

    // LED output
    // LED0 = pass, LED1 = 0, LED2 = 0, LED3 = done
    assign leds[0] = led0_r;
    assign leds[1] = 1'b0;
    assign leds[2] = 1'b0;
    assign leds[3] = led3_r;

endmodule

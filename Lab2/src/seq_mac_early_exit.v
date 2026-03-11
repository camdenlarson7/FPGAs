`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/07/2026 07:14:02 PM
// Design Name: 
// Module Name: seq_mac_early_exit
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


module seq_mac_early_exit #(
    parameter N = 64
)(
    input  wire        clk,
    input  wire        rst_n,

    // Control
    input  wire        start,
    input  wire        stall_inject,
    input  wire        y_ready,

    // Threshold (signed 32-bit; 0 = disabled)
    input  wire signed [31:0] T,

    // Data inputs
    input  wire signed [7:0]  x,
    input  wire signed [7:0]  w,
    input  wire               x_valid,
    input  wire               w_valid,

    // Outputs
    output reg  signed [31:0] y,
    output reg                done,
    output reg                early_exit   // 1 = exited before k reached N-1
);

    
    // FSM state encoding (one-hot)
    localparam [4:0]
        IDLE     = 5'b00001,
        CONFIG   = 5'b00010,
        WAIT_IN  = 5'b00100,
        COMPUTE  = 5'b01000,
        HOLD_OUT = 5'b10000;

    reg [4:0] state, next_state;

    
    // Datapath registers
    
    reg signed [31:0] acc;
    reg        [7:0]  k;

    // -------------------------------------------------------------------------
    // Combinational datapath signals
    // -------------------------------------------------------------------------
    wire signed [15:0] product;
    wire signed [31:0] product_ext;
    wire signed [31:0] acc_next;      // Combinational next accumulator value
    wire               inputs_ready;
    wire               k_done;        // True when this is the last iteration
    wire               threshold_met; // True when |acc_next| >= T and T != 0

    assign product      = x * w;
    assign product_ext  = {{16{product[15]}}, product};
    assign acc_next     = acc + product_ext;
    assign inputs_ready = x_valid & w_valid & ~stall_inject;

    // k is the pre-increment value; k_done fires on the last iteration
    assign k_done = (k == (N-1));

   
    assign threshold_met = (T != 32'sd0) &&
                           (($signed(acc_next) >= $signed(T)) ||
                            ($signed(acc_next) <= -$signed(T)));

    
    // FSM: state register
    always @(posedge clk) begin
        if (!rst_n) state <= IDLE;
        else        state <= next_state;
    end

    
    // FSM: next-state logic (combinational)
    always @(*) begin
        next_state = state;
        case (state)
            IDLE:    if (start)                         next_state = CONFIG;
            CONFIG:                                     next_state = WAIT_IN;
            WAIT_IN: if (inputs_ready)                  next_state = COMPUTE;
            COMPUTE: if (k_done || threshold_met)       next_state = HOLD_OUT;
                     else                               next_state = WAIT_IN;
            HOLD_OUT: if (y_ready)                      next_state = IDLE;
            default:                                    next_state = IDLE;
        endcase
    end

 
    // Datapath: accumulator and counter
   
    always @(posedge clk) begin
        if (!rst_n) begin
            acc <= 32'sd0;
            k   <= 8'h00;
        end else begin
            case (state)
                CONFIG:  begin
                    acc <= 32'sd0;
                    k   <= 8'h00;
                end
                COMPUTE: begin
                    acc <= acc_next;
                    k   <= k + 1'b1;
                end
                default: begin end
            endcase
        end
    end

    
    always @(posedge clk) begin
        if (!rst_n) begin
            y          <= 32'sd0;
            done       <= 1'b0;
            early_exit <= 1'b0;
        end else begin
            case (state)
                COMPUTE: begin
                    if (k_done || threshold_met) begin
                        y          <= acc_next;
                        early_exit <= threshold_met && !k_done;
                    end
                end
                HOLD_OUT: done <= 1'b1;
                IDLE:     begin done <= 1'b0; early_exit <= 1'b0; end
                default:  begin done <= 1'b0; end
            endcase
        end
    end

endmodule
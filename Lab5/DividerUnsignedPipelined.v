`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12/02/2025 09:57:17 AM
// Design Name: 
// Module Name: DividerUnsignedPipelined
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


module DividerUnsignedPipelined(
    input clk, rst, stall,
    input [31:0] i_dividend,
    input [31:0] i_divisor,
    output [31:0] o_remainder,
    output [31:0] o_quotient
    );
    
    wire [31:0] dend_wire [0:32];
    wire [31:0] div_wire [0:32];
    wire [31:0] rem_wire [0:32];
    wire [31:0] quot_wire [0:32];
    
    reg [31:0] dend_reg [1:7];
    reg [31:0] div_reg [1:7];
    reg [31:0] rem_reg [1:7];
    reg [31:0] quot_reg [1:7];
    
    assign dend_wire[0] = i_dividend;
    assign div_wire[0] = i_divisor;
    assign rem_wire[0] = 32'b0;
    assign quot_wire[0] = 32'b0;
    
    genvar i;
    generate
        for (i = 0; i < 32; i = i + 1) begin : iter_gen
            wire [31:0] i_dend, i_div, i_rem, i_quot;
            if (i > 0 && (i % 4 == 0)) begin
                // i = 4 take from reg[1]
                assign i_dend = dend_reg[i/4];
                assign i_div  = div_reg[i/4];
                assign i_rem  = rem_reg[i/4];
                assign i_quot = quot_reg[i/4];
            end 
            else begin    
                assign i_dend = dend_wire[i];
                assign i_div  = div_wire[i];
                assign i_rem  = rem_wire[i];
                assign i_quot = quot_wire[i];
            end
            
            divu_1iter uut(
                .i_dividend(i_dend),
                .i_divisor(i_div),
                .i_remainder(i_rem),
                .i_quotient(i_quot),
                .o_dividend(dend_wire[i+1]),
                .o_divisor(div_wire[i+1]),
                .o_remainder(rem_wire[i+1]),
                .o_quotient(quot_wire[i+1])
            );
        end
    endgenerate
    
    integer k;
    always @(posedge clk) begin
        if (rst) begin
            for (k = 1; k <= 7; k = k + 1) begin
                dend_reg[k] <= 0;
                div_reg[k] <= 0;
                rem_reg[k] <= 0;
                quot_reg[k] <= 0;
            end       
        end
        // Stage 1 (iter 0-3) -> Reg 1
             dend_reg[1] <= dend_wire[4]; div_reg[1] <= div_wire[4]; rem_reg[1] <= rem_wire[4]; quot_reg[1] <= quot_wire[4];
             
             // Stage 2 (iter 4-7) -> Reg 2
             dend_reg[2] <= dend_wire[8]; div_reg[2] <= div_wire[8]; rem_reg[2] <= rem_wire[8]; quot_reg[2] <= quot_wire[8];

             // next stages...
             dend_reg[3] <= dend_wire[12]; div_reg[3] <= div_wire[12]; rem_reg[3] <= rem_wire[12]; quot_reg[3] <= quot_wire[12];
             dend_reg[4] <= dend_wire[16]; div_reg[4] <= div_wire[16]; rem_reg[4] <= rem_wire[16]; quot_reg[4] <= quot_wire[16];
             dend_reg[5] <= dend_wire[20]; div_reg[5] <= div_wire[20]; rem_reg[5] <= rem_wire[20]; quot_reg[5] <= quot_wire[20];
             dend_reg[6] <= dend_wire[24]; div_reg[6] <= div_wire[24]; rem_reg[6] <= rem_wire[24]; quot_reg[6] <= quot_wire[24];
             dend_reg[7] <= dend_wire[28]; div_reg[7] <= div_wire[28]; rem_reg[7] <= rem_wire[28]; quot_reg[7] <= quot_wire[28];
    end
    // final result
    assign o_remainder = rem_wire[32];
    assign o_quotient = quot_wire[32];
    
endmodule

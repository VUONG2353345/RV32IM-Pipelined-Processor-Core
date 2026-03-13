`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/28/2025 05:03:10 PM
// Design Name: 
// Module Name: divu_1iter
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


module divu_1iter(
        input [31:0] i_dividend,
        input [31:0] i_divisor,
        input [31:0] i_remainder,
        input [31:0] i_quotient,
        output reg [31:0] o_dividend,
        output reg [31:0] o_divisor,
        output reg [31:0] o_remainder,
        output reg [31:0] o_quotient
    );
    //temp variables
    reg [31:0] remainder_shifted;
    integer i;
    always @(*) begin
        // pass-through
        o_divisor = i_divisor;
        
        // shift
        remainder_shifted = (i_remainder << 1) | ((i_dividend >> 31) & 1'b1);
        o_dividend = i_dividend << 1;
        
        // compare and subtract
        if (remainder_shifted < i_divisor) begin
            o_quotient = i_quotient << 1;
            o_remainder = remainder_shifted;
        end
        else begin
            o_quotient = (i_quotient << 1) | 1'b1;
            o_remainder = remainder_shifted - i_divisor;
        end
    end
    
endmodule

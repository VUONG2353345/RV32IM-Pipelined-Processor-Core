`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12/07/2025 05:06:59 PM
// Design Name: 
// Module Name: tb_processor
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


module tb_processor;
    reg clock_proc;
    reg clock_mem;
    reg rst;
    wire halt;
    
    Processor uut (
        .clock_proc(clock_proc), 
        .clock_mem(clock_mem), 
        .rst(rst), 
        .halt(halt)
    );
    
    initial begin
        clock_proc = 0;
        forever #5 clock_proc = ~clock_proc;
    end
    
    initial begin
        clock_mem = 0;
        #2;
        forever #5 clock_mem = ~clock_mem;
    end

    // test
    initial begin
        rst = 1;
        #20;
        rst = 0;
        
        // run 200ns
        #200;
        $finish;
    end
endmodule

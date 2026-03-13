`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12/10/2025 01:33:50 PM
// Design Name: 
// Module Name: system
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


`timescale 1ns / 1ps

module system (
    input wire clk,             // Clock 125 MHz
    input wire [0:0] btn,       // button 0 reset button
    output wire [3:0] ck_io,    // leds
    output wire halt_led        
);

    // clk divider
    // 125 MHz / 8 = 15.625 MHz.
    reg [2:0] clk_counter;
    initial clk_counter = 0;
    
    always @(posedge clk) begin
        clk_counter <= clk_counter + 1;
    end

    wire clock_proc_internal;
    assign clock_proc_internal = (clk_counter < 4);

    wire clock_mem_internal;
    assign clock_mem_internal = (clk_counter >= 2 && clk_counter <= 5);

    wire rst_internal;
    assign rst_internal = btn[0];

    // processor
    Processor my_processor (
        .clock_proc(clock_proc_internal),
        .clock_mem (clock_mem_internal),
        .rst       (rst_internal),
        .halt      (halt_led),     // blue led connect
        .led_bcd   (ck_io)         // 4 leds
    );

endmodule

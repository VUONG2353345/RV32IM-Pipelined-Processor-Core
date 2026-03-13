`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12/11/2025 03:00:54 PM
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


module system (
    input clk,             // Clock 125 MHz
    input [0:0] btn,       // button 0 reset button
    output [3:0] ck_io,    // leds
    output halt_led
);

    // clk divider
    // 125 MHz / 8 = 15.625 MHz.
    reg [2:0] clk_counter;
    initial clk_counter = 0;
    
    always @(posedge clk) begin
        clk_counter <= clk_counter + 1;
    end

    wire sys_clk;
    // prevent timing fail
    assign sys_clk = clk_counter[2];

    wire proc_halt;
    wire [31:0] debug_pc;
    Processor my_processor (
        .clk(sys_clk),
        .rst(btn[0]),            
        .halt(proc_halt),        
        .trace_writeback_pc(debug_pc), 
        .trace_writeback_inst()  // khong can dung tren mach
    );

    assign halt_led = proc_halt;

    // 4 led
    // take 5:2 bit to see changes in commands
    // LED dung yen = CPU reset hoac bi treo
    // LED chay = CPU dang chay
    assign ck_io = debug_pc[5:2];

endmodule

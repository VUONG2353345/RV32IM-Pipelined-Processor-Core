`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12/11/2025 12:47:06 PM
// Design Name: 
// Module Name: process_tb_assignment
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


module process_tb_assignment;
// 1. Khai báo tín hi?u
    reg clk;
    reg rst;
    
    // Các tín hi?u output t? Processor ?? quan sát
    wire halt;
    wire [31:0] trace_writeback_pc;
    wire [31:0] trace_writeback_inst;

    // 2. Instance module Processor (Top-level c?a Lab 5)
    // L?u ý: Tên module ph?i kh?p v?i file DatapathPipelined.v
    Processor uut (
        .clk(clk),
        .rst(rst),
        .halt(halt),
        .trace_writeback_pc(trace_writeback_pc),
        .trace_writeback_inst(trace_writeback_inst)
    );

    // 3. T?o xung Clock
    // Chu k? 10ns (T?n s? 100MHz), ??o tr?ng thái m?i 5ns
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // 4. Quy trình Reset và Ki?m tra
    initial begin
        // Kh?i t?o
        rst = 1;
        
        // Gi? Reset trong 20ns (2 chu k? clock)
        #20;
        
        // Th? Reset (Active Low ho?c High tùy thi?t k?, ? ?ây Lab dùng Active High cho rst)
        rst = 0;
        
        // Ch? ??i mô ph?ng ch?y
        $display("-------------------------------------------------------------");
        $display("Simulation Started...");
        $display("Time\t\tPC Writeback\tInstruction\tHalt");
        $display("-------------------------------------------------------------");
    end

    // 5. Monitor: In k?t qu? ra Console m?i khi có xung clock d??ng
    always @(posedge clk) begin
        if (!rst) begin
            $display("%0t\t\t%h\t\t%h\t\t%b", $time, trace_writeback_pc, trace_writeback_inst, halt);
            
            // N?u CPU báo Halt thì d?ng mô ph?ng sau m?t chút
            if (halt) begin
                $display("-------------------------------------------------------------");
                $display("HALT signal detected. Simulation finished successfully.");
                #50; // Ch?y thêm vài cycle ?? nhìn rõ waveform
                $finish;
            end
        end
    end

    // 6. Timeout: Phòng tr??ng h?p CPU b? treo (vòng l?p vô h?n không có ecall)
    initial begin
        #50000; // Ch?y t?i ?a 50,000ns (tùy ch?nh n?u ch??ng trình dài)
        $display("-------------------------------------------------------------");
        $display("TIMEOUT: Simulation force stopped (Run too long).");
        $finish;
    end
endmodule

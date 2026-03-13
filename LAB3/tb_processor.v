`timescale 1ns / 1ps

module tb_processor;

    // Inputs
    reg clock_proc;
    reg clock_mem;
    reg rst;

    // Outputs
    wire halt;
    wire [3:0] led_bcd; // Nếu bạn đã sửa module Processor có cổng này

    // Instantiate the Unit Under Test (UUT)
    Processor uut (
        .clock_proc(clock_proc), 
        .clock_mem(clock_mem), 
        .rst(rst), 
        .halt(halt),
        .led_bcd(led_bcd)
    );

    // Tạo Clock: 10ns period (100MHz)
    // clock_mem lệch pha 90 độ so với clock_proc (theo yêu cầu đề bài)
    initial begin
        clock_proc = 0;
        forever #5 clock_proc = ~clock_proc;
    end

    initial begin
        clock_mem = 0;
        #2.5; // Lệch pha 1/4 chu kỳ
        forever #5 clock_mem = ~clock_mem;
    end

    // Test Stimulus
    initial begin
        // 1. Khởi tạo
        rst = 1;
        
        // 2. Giữ Reset trong 100ns
        #100;
        rst = 0;
        
        // 3. Chạy mô phỏng cho đến khi Halt hoặc hết giờ
        wait(halt == 1);
        
        #100;
        $display("Processor Halted!");
        $finish;
    end
      
endmodule
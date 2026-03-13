`timescale 1ns / 1ps

module tb_led_string_system;

    // --- 1. KHAI BÁO TÍN HIỆU ---
    reg clk;
    reg reset_n;    
    reg [3:1] btn;  

    wire [3:0] led;
    wire uart_tx_out;

    // --- 2. CẤU HÌNH "TỶ LỆ VÀNG" (GIỐNG HÌNH MẪU) ---
    // Clock = 200, Baud = 100 -> UART chiếm 50% độ rộng của 1 chu kỳ đèn
    parameter SIM_CLOCK_FREQ = 200; 
    parameter SIM_BAUD_RATE  = 100; 

    // Instantiate UUT
    led_string_system #(
        .CLOCK_FREQ(SIM_CLOCK_FREQ),
        .BAUD_RATE(SIM_BAUD_RATE)
    ) uut (
        .clk(clk), 
        .reset_n(reset_n), 
        .btn(btn), 
        .led(led), 
        .uart_tx_out(uart_tx_out)
    );

    // Tạo Clock 10ns (100MHz)
    initial begin
        clk = 0;
        forever #5 clk = ~clk; 
    end

    // --- 3. KỊCH BẢN TEST CHÍNH XÁC TỪNG NHỊP ---
    initial begin
        // --- BƯỚC 1: RESET HỆ THỐNG ---
        $display("Time: %0t | System Reset", $time);
        reset_n = 1; // Active High (Theo code của bạn)
        btn = 3'b000;
        #100;        // Giữ Reset một chút
        reset_n = 0; // Thả Reset -> LED mặc định là 3 (0011)
        
        // --- BƯỚC 2: CHỜ 2 NHỊP ĐỂ HIỆN SỐ 3 (QUAN TRỌNG) ---
        // Dùng @(posedge) để bắt chính xác thời điểm chuyển giây
        // Việc này tạo ra đoạn "3" dài 2 ô trên biểu đồ
        @(posedge uut.tick_1hz); 
        @(posedge uut.tick_1hz);

        // --- BƯỚC 3: DỊCH TRÁI (3 -> 6 -> C -> 9) ---
        $display("Time: %0t | Start Shift Left", $time);
        btn[1] = 1; #100; btn[1] = 0; // Nhấn nút dứt khoát
        
        // Chờ 3 nhịp tiếp theo để thấy đèn nhảy
        @(posedge uut.tick_1hz); // Nhảy sang 6
        @(posedge uut.tick_1hz); // Nhảy sang C
        @(posedge uut.tick_1hz); // Nhảy sang 9

        // --- BƯỚC 4: DỊCH PHẢI (9 -> C -> 6 -> 3) ---
        $display("Time: %0t | Start Shift Right", $time);
        btn[2] = 1; #100; btn[2] = 0;

        // Chờ 3 nhịp để quay về chốn cũ
        @(posedge uut.tick_1hz); // Quay về C
        @(posedge uut.tick_1hz); // Quay về 6
        @(posedge uut.tick_1hz); // Quay về 3 (VỀ ĐÍCH)
        
        // --- BƯỚC 5: DỪNG (PAUSE) ---
        $display("Time: %0t | Pause", $time);
        btn[3] = 1; #100; btn[3] = 0;
        
        // Chờ thêm vài nhịp để chứng minh nó đứng yên mãi mãi
        repeat(4) @(posedge uut.tick_1hz);

        $display("Simulation Finished.");
        $finish; 
    end
      
endmodule
`timescale 1ns / 1ps

module tb_led_decoration;

    // 1. Khai báo tín hiệu
    reg clk;
    reg reset_n;
    reg [1:0] sw;

    wire [3:0] seg0, seg1, seg2, seg3;

    // 2. Gọi module (UUT) và GHI ĐÈ THAM SỐ
    // CLOCK_LIMIT = 10 -> Chỉ cần 10 xung là nhảy bước (Mô phỏng siêu nhanh)
    led_decoration_system #( .CLOCK_LIMIT(10) ) uut (
        .clk(clk),
        .reset_n(reset_n),
        .sw(sw),
        .seg0_bcd(seg0), .seg1_bcd(seg1),
        .seg2_bcd(seg2), .seg3_bcd(seg3)
    );

    // 3. Tạo xung Clock 125MHz
    initial begin
        clk = 0;
        forever #4 clk = ~clk; 
    end

    // 4. Kịch bản Test
    initial begin
        $display("==================================================");
        $display("START SIMULATION: LED DECORATION (FAST MODE)");
        $display("Display Legend: 2=Two, 5=Five, f=Blank");
        $display("==================================================");

        // --- INIT ---
        reset_n = 0; sw = 2'b00;
        
        // --- 1. RESET ---
        $display("[Time 0] Resetting...");
        reset_n = 1; #20; reset_n = 0;
        
        // --- 2. TEST EFFECT 1: QUA TRÁI (00) ---
        // Logic: 0 -> 3 -> 2 -> 1 -> 0
        $display("\n--- TESTING: SCROLL LEFT (SW=00) ---");
        sw = 2'b00;
        #300; // Chờ đủ lâu để thấy vài vòng lặp

        // --- 3. TEST EFFECT 2: QUA PHẢI (01) ---
        // Logic: 0 -> 1 -> 2 -> 3 -> 0
        $display("\n--- TESTING: SCROLL RIGHT (SW=01) ---");
        reset_n = 1; #10; reset_n = 0; // Reset về 0 cho dễ nhìn
        sw = 2'b01;
        #300;

        // --- 4. TEST EFFECT 3: BOUNCE (10) ---
        // Logic: 0 -> 1 -> 2 -> 1 -> 0
        $display("\n--- TESTING: BOUNCE (SW=10) ---");
        reset_n = 1; #10; reset_n = 0;
        sw = 2'b10;
        #400; // Chờ lâu hơn để thấy nảy đi nảy lại

        $display("\n==================================================");
        $display("SIMULATION FINISHED");
        $finish;
    end

    // Monitor kết quả
    initial begin
        $monitor("Time=%t | Step=%d | Display: [%h][%h][%h][%h]", 
                 $time, uut.step, seg3, seg2, seg1, seg0);
    end

endmodule
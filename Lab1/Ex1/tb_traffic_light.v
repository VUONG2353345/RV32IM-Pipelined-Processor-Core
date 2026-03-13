`timescale 1ns / 1ps

module tb_traffic_light;

    // 1. Khai báo tín hiệu
    reg clk;
    reg reset_n;
    reg [1:0] sw;
    reg [1:0] btn;

    // Output
    wire [2:0] led_rgb1;
    wire [2:0] led_rgb2;
    wire [3:0] seg0, seg1, seg2, seg3;

    // 2. Gọi module (Unit Under Test)
    traffic_light_system #( .CLOCK_LIMIT(10) ) uut (
        .clk(clk),
        .reset_n(reset_n),
        .sw(sw),
        .btn(btn),
        .led_rgb1(led_rgb1), .led_rgb2(led_rgb2),
        .seg0_bcd(seg0), .seg1_bcd(seg1),
        .seg2_bcd(seg2), .seg3_bcd(seg3)
    );

    // 3. Tạo xung Clock 125MHz chuẩn (Chu kỳ 8ns)
    initial begin
        clk = 0;
        forever #4 clk = ~clk; // Đảo trạng thái mỗi 4ns
    end

    // Định nghĩa 1 giây thực tế trong mô phỏng (1 tỷ ns)
    localparam ONE_SEC = 1000000000; 

    // 4. Kịch bản Test
    initial begin
        $display("==================================================");
        $display("START REAL-TIME SIMULATION (125MHz Clock)");
        $display("Warning: This simulation will take a long time!");
        $display("==================================================");

        // --- KHỞI TẠO ---
        reset_n = 0; // Chưa Reset (Run)
        sw = 2'b00;  // Run Mode
        btn = 2'b00; 

        // --- 1. RESET HỆ THỐNG ---
        $display("[Time: 0] Applying Reset...");
        reset_n = 1; // Nhấn Reset (Active High logic trong code bạn)
        #1000;       // Giữ Reset 1us
        reset_n = 0; // Thả Reset
        $display("[Time: 1us] System Started. Waiting for countdown...");

        // --- 2. CHỜ MÔ PHỎNG (QUAN TRỌNG) ---
        // Đèn Xanh mặc định 10s. Ta chờ 11s để thấy nó chuyển sang Vàng.
        // Tổng thời gian chờ = 11 tỷ ns.
        
        $display("Waiting for 11 seconds (Green -> Yellow)...");
        #(11.0 * ONE_SEC); 

        // Lúc này đèn phải là Vàng. Chờ tiếp 3s để sang Đỏ.
        $display("Waiting for 3 seconds (Yellow -> Red)...");
        #(3.0 * ONE_SEC);

        $display("==================================================");
        $display("SIMULATION FINISHED at ~14s");
        $finish;
    end

    // 5. Monitor: Chỉ in ra khi giây thay đổi (để đỡ rác màn hình)
    // Theo dõi thay đổi ở hàng đơn vị (seg0)
    always @(seg0) begin
        // In thời gian hiện tại đổi ra giây
        $display("Time: %0t s | Display: %d%d | LED1: %b | LED2: %b", 
                 $time/1000000000.0, seg1, seg0, led_rgb1, led_rgb2);
    end

endmodule
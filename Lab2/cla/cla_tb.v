`timescale 1ns / 1ps

module tb_system_clean;

    // 1. Tín hiệu mô phỏng phần cứng
    reg [6:0] btn;      // Nút bấm (Input)
    wire [31:0] sum;    // Kết quả tổng 32-bit (cần để nối dây)
    wire [7:0] led;     // Đèn Led (Output - chỉ lấy 8 bit cuối)

    // 2. Gọi module CLA (Unit Under Test)
    // Tái hiện logic: A = 26, B = Button
    cla uut (
        .a(32'd26),          // Cố định số 26 như đề bài
        .b({25'd0, btn}),    // Nối nút bấm vào B (phần cao là 0)
        .cin(1'b0),          // Không nhớ
        .sum(sum)            // Kết quả ra sum
    );

    // Gán 8 bit thấp của tổng ra đèn LED
    assign led = sum[7:0];

    // 3. Kịch bản Test
    initial begin
        // In tiêu đề bảng
        $display("-------------------------------------------");
        $display("| Time |  Nut Bam (Btn) | Ket Qua (LED) |");
        $display("|      | (Input + 26)   | (Decimal)     |");
        $display("-------------------------------------------");

        // Tự động in khi btn hoặc led thay đổi
        // %0d: In số gọn, cắt bỏ số 0 ở đầu
        $monitor("| %4t |       %0d        |       %0d       |", $time, btn, led);

        // --- TEST CASE 1: Không bấm (0) ---
        btn = 0;   
        #10; // Đợi 10ns

        // --- TEST CASE 2: Bấm số 1 ---
        btn = 1;   
        #10;

        // --- TEST CASE 3: Bấm số 4 ---
        btn = 4;   
        #10;

        // --- TEST CASE 4: Bấm số 10 ---
        btn = 10;  
        #10;

        // --- TEST CASE 5: Bấm số 74 (Để tổng chẵn 100) ---
        btn = 74;  
        #10;

        $display("-------------------------------------------");
        $finish; // Dừng
    end

endmodule
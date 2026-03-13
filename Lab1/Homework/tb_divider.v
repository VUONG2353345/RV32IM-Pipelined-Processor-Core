`timescale 1ns / 1ps

module tb_divider;

    // 1. Khai báo tín hiệu
    reg [31:0] i_dividend;
    reg [31:0] i_divisor;
    wire [31:0] o_quotient;
    wire [31:0] o_remainder;

    // 2. Gọi module cần test
    divider_unsigned uut (
        .i_dividend(i_dividend), 
        .i_divisor(i_divisor), 
        .o_quotient(o_quotient), 
        .o_remainder(o_remainder)
    );

    // 3. Kịch bản test
    initial begin
        $display("------------------------------------------------");
        $display("Bat dau mo phong Divider Unsigned...");

        // --- TEST CASE 1: 4 / 2 ---
        i_dividend = 4; i_divisor = 2; #10;
        $display("Test 1: %0d / %0d = %0d (Du %0d)", i_dividend, i_divisor, o_quotient, o_remainder);
        if (o_quotient == 2 && o_remainder == 0) $display(" -> PASSED"); else $display(" -> FAILED");

        // --- TEST CASE 2: 10 / 4 ---
        i_dividend = 10; i_divisor = 4; #10;
        $display("Test 2: %0d / %0d = %0d (Du %0d)", i_dividend, i_divisor, o_quotient, o_remainder);
        if (o_quotient == 2 && o_remainder == 2) $display(" -> PASSED"); else $display(" -> FAILED");

        // --- TEST CASE 3: 100 / 3 ---
        i_dividend = 100; i_divisor = 3; #10;
        $display("Test 3: %0d / %0d = %0d (Du %0d)", i_dividend, i_divisor, o_quotient, o_remainder);
        
        // --- TEST CASE 4: Chia số lớn ---
        i_dividend = 32'd2000000; i_divisor = 32'd5; #10;
        $display("Test 4: %0d / %0d = %0d (Du %0d)", i_dividend, i_divisor, o_quotient, o_remainder);

        // --- TEST CASE 5: Chia cho 1 (Identity) ---
        i_dividend = 12345678; i_divisor = 1; #10;
        $display("Test 5 (Div by 1): %0d / %0d = %0d (Du %0d)", i_dividend, i_divisor, o_quotient, o_remainder);
        if (o_quotient == 12345678 && o_remainder == 0) $display(" -> PASSED"); else $display(" -> FAILED");

        // --- TEST CASE 6: Số bị chia nhỏ hơn Số chia ---
        i_dividend = 50; i_divisor = 100; #10;
        $display("Test 6 (Small / Big): %0d / %0d = %0d (Du %0d)", i_dividend, i_divisor, o_quotient, o_remainder);
        if (o_quotient == 0 && o_remainder == 50) $display(" -> PASSED"); else $display(" -> FAILED");

        // --- TEST CASE 7: Số bị chia bằng 0 ---
        i_dividend = 0; i_divisor = 999; #10;
        $display("Test 7 (Zero Dividend): %0d / %0d = %0d (Du %0d)", i_dividend, i_divisor, o_quotient, o_remainder);
        if (o_quotient == 0 && o_remainder == 0) $display(" -> PASSED"); else $display(" -> FAILED");

        // --- TEST CASE 8: Chia chính nó ---
        i_dividend = 32'd987654321; i_divisor = 32'd987654321; #10;
        $display("Test 8 (Self Divide): %0d / %0d = %0d (Du %0d)", i_dividend, i_divisor, o_quotient, o_remainder);
        if (o_quotient == 1 && o_remainder == 0) $display(" -> PASSED"); else $display(" -> FAILED");

        // --- TEST CASE 9: MAX 32-BIT VALUE ---
        i_dividend = 32'hFFFFFFFF; i_divisor = 2; #10;
        $display("Test 9 (Max 32-bit): %h / %h = %h (Du %h)", i_dividend, i_divisor, o_quotient, o_remainder);
        if (o_quotient == 32'h7FFFFFFF && o_remainder == 1) $display(" -> PASSED"); else $display(" -> FAILED");

        // === KẾT THÚC MÔ PHỎNG TẠI ĐÂY ===
        $display("------------------------------------------------");
        $display("Mo phong hoan tat!");
        $finish; 
    end

endmodule
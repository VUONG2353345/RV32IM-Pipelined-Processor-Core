module divu_1iter (
    input  wire [31:0] i_dividend,
    input  wire [31:0] i_divisor,
    input  wire [31:0] i_remainder,
    input  wire [31:0] i_quotient,
    output wire [31:0] o_dividend,
    output wire [31:0] o_remainder,
    output wire [31:0] o_quotient
);

    /* Bước 1: Tính toán Remainder tạm thời
       Code C: remainder = (remainder << 1) | ((dividend >> 31) & 0x1);
       Verilog: Dịch i_remainder 1 bit và lấy bit 31 của i_dividend đưa vào vị trí 0
    */
    wire [31:0] remainder_shifted;
    assign remainder_shifted = {i_remainder[30:0], i_dividend[31]};

    /*
       Bước 2: So sánh và cập nhật kết quả
       Code C: if (remainder < divisor) ... else ...
    */
    wire is_less;
    assign is_less = (remainder_shifted < i_divisor);

    // Cập nhật Quotient: Dịch trái, nếu chia được (không nhỏ hơn) thì bit cuối là 1, ngược lại là 0
    assign o_quotient = is_less ? (i_quotient << 1) : ((i_quotient << 1) | 32'b1);

    // Cập nhật Remainder: Nếu chia được thì trừ đi Divisor, ngược lại giữ nguyên
    assign o_remainder = is_less ? remainder_shifted : (remainder_shifted - i_divisor);

    /*
       Bước 3: Chuẩn bị Dividend cho vòng lặp sau
       Code C: dividend = dividend << 1;
    */
    assign o_dividend = i_dividend << 1;

endmodule
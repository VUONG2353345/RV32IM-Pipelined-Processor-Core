module divider_unsigned (
    input  wire [31:0] i_dividend,
    input  wire [31:0] i_divisor,
    output wire [31:0] o_remainder,
    output wire [31:0] o_quotient
);

    // Tạo các mảng dây nối (wire arrays) để kết nối 32 tầng
    // Cần 33 phần tử: từ 0 (input đầu) đến 32 (output cuối)
    wire [31:0] dividend_chain  [32:0];
    wire [31:0] remainder_chain [32:0];
    wire [31:0] quotient_chain  [32:0];

    // Khởi tạo giá trị đầu vào cho tầng đầu tiên (Tương ứng khởi tạo biến trong C)
    assign dividend_chain[0]  = i_dividend;
    assign remainder_chain[0] = 32'b0;      // Remainder ban đầu = 0
    assign quotient_chain[0]  = 32'b0;      // Quotient ban đầu = 0

    // Sử dụng vòng lặp generate để tạo 32 instances của divu_1iter
    genvar i;
    generate
        for (i = 0; i < 32; i = i + 1) begin : div_loop
            divu_1iter inst (
                .i_dividend (dividend_chain[i]),
                .i_divisor  (i_divisor),          // Divisor không đổi qua các tầng
                .i_remainder(remainder_chain[i]),
                .i_quotient (quotient_chain[i]),
                .o_dividend (dividend_chain[i+1]), // Output nối vào Input của tầng i+1
                .o_remainder(remainder_chain[i+1]),
                .o_quotient (quotient_chain[i+1])
            );
        end
    endgenerate

    // Kết quả cuối cùng lấy từ output của tầng thứ 32
    assign o_quotient  = quotient_chain[32];
    assign o_remainder = remainder_chain[32];

endmodule
`timescale 1ns / 1ps

module tb_regfile;

    // Inputs
    reg clk;
    reg rst;
    reg we;
    reg [4:0] rd;
    reg [31:0] rd_data;
    reg [4:0] rs1;
    reg [4:0] rs2;

    // Outputs
    wire [31:0] rs1_data;
    wire [31:0] rs2_data;

    // Instantiate the Unit Under Test (UUT)
    RegFile uut (
        .clk(clk), 
        .rst(rst), 
        .we(we), 
        .rd(rd), 
        .rd_data(rd_data), 
        .rs1(rs1), 
        .rs2(rs2), 
        .rs1_data(rs1_data), 
        .rs2_data(rs2_data)
    );

    // Tạo xung Clock (Chu kỳ 10ns)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        // 1. Khởi tạo giá trị ban đầu
        rst = 1;
        we = 0;
        rd = 0;
        rd_data = 0;
        rs1 = 0;
        rs2 = 0;

        // Đợi 20ns cho reset xong
        #20;
        rst = 0;
        #10;

        // --- TEST CASE 1: Kiểm tra thanh ghi x0 (Luôn phải bằng 0) ---
        $display("TEST 1: Checking x0 behavior...");
        we = 1;
        rd = 5'd0;          // Cố tình ghi vào x0
        rd_data = 32'h12345678; // Ghi giá trị rác vào
        #10; // Đợi 1 chu kỳ clock để ghi
        
        we = 0;             // Ngừng ghi
        rs1 = 5'd0;         // Đọc lại x0
        #5;                 // Đợi tín hiệu ổn định
        
        if (rs1_data == 32'd0) 
            $display("PASS: x0 is 0.");
        else 
            $display("FAIL: x0 is not 0 (Got: %h)", rs1_data);


        // --- TEST CASE 2: Kiểm tra Ghi/Đọc thanh ghi thường (x1) ---
        $display("TEST 2: Write/Read x1...");
        we = 1;
        rd = 5'd1;          // Chọn ghi vào x1
        rd_data = 32'hDEADBEEF; // Giá trị cần ghi
        #10; // Đợi ghi xong
        
        we = 0;
        rs1 = 5'd1;         // Đọc lại x1
        #5;
        
        if (rs1_data == 32'hDEADBEEF) 
            $display("PASS: x1 stores correct value.");
        else 
            $display("FAIL: x1 Wrong value (Got: %h)", rs1_data);

        // --- TEST CASE 3: Kiểm tra 2 cổng đọc cùng lúc (rs1, rs2) ---
        $display("TEST 3: Dual Read...");
        // Ghi vào x2
        we = 1; rd = 5'd2; rd_data = 32'hAAAA_BBBB; #10;
        
        we = 0;
        rs1 = 5'd1; // Đọc x1 (vừa ghi ở Test 2)
        rs2 = 5'd2; // Đọc x2
        #5;
        
        if (rs1_data == 32'hDEADBEEF && rs2_data == 32'hAAAA_BBBB)
            $display("PASS: Dual read works.");
        else
            $display("FAIL: Dual read failed.");

        $finish;
    end
      
endmodule
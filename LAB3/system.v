module system (
    input         clk,         // Nối với chân xung nhịp 125MHz của board
    input  [0:0]  btn,         // Nút nhấn dùng làm Reset (btn[0])
    output [3:0]  ck_io,       // 4 chân nối ra LED 7 đoạn trên Extension Board
    output        halt_led     // (Tùy chọn) 1 LED đơn trên board để báo hiệu HALT
);

    wire [31:0] cpu_debug_data;
    wire processor_halt;
    
    // Tùy chỉnh clock: Board Arty Z7 chạy 125MHz, CPU có thể chạy chậm hơn hoặc bằng.
    // Ở đây ta dùng trực tiếp clock hệ thống cho đơn giản.
    // Nếu muốn thấy LED nháy chậm, bạn cần bộ chia clock (Clock Divider).
    
    // Instance Processor (đã sửa trong DatapathSingleCycle.v)
    Processor my_cpu (
        .clock_proc   (clk),          // Clock cho CPU
        .clock_mem    (~clk),         // Clock cho Memory (ngược pha)
        .rst          (btn[0]),       // Nút reset
        .halt         (processor_halt),
        .led_bcd      (cpu_debug_data) // Lấy dữ liệu debug ra
    );

    // Nối 4 bit thấp của dữ liệu debug ra chân ck_io (ra LED Extension)
    assign ck_io = cpu_debug_data[3:0];
    
    // (Tùy chọn) Báo hiệu khi CPU dừng
    assign halt_led = processor_halt;

endmodule
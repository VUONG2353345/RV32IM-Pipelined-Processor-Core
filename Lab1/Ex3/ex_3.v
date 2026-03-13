module led_string_system #(
    // Parameter cho phép thay đổi từ bên ngoài (Testbench hoặc Top module)
    parameter CLOCK_FREQ = 125000000, 
    parameter BAUD_RATE  = 9600       
)(
    input clk,              
    input reset_n,          // BTN0: Mode Reset (về 0011) - Active High
    input [3:1] btn,        // BTN1, BTN2, BTN3
    
    output reg [3:0] led,   // 4 LEDs
    output uart_tx_out      // Kết nối tới PC
);

    // --- CẤU HÌNH THỜI GIAN ---
    // Giới hạn đếm để tạo ra 1 giây chính xác dựa trên Clock đầu vào
    localparam CLOCK_LIMIT = CLOCK_FREQ - 1;

    // --- 1. QUẢN LÝ MODE (TRẠNG THÁI) ---
    // 0: Pause, 1: Shift Left, 2: Shift Right
    reg [1:0] mode;
    
    // Xử lý nút nhấn
    always @(posedge clk or posedge reset_n) begin
        if (reset_n) begin
            mode <= 0; // Reset về mặc định
        end else begin
            if (btn[3])      mode <= 0; // Pause
            else if (btn[1]) mode <= 1; // Left Ring
            else if (btn[2]) mode <= 2; // Right Ring
        end
    end

    // --- 2. BỘ TẠO XUNG 1Hz ---
    reg [31:0] counter; 
    reg tick_1hz;

    always @(posedge clk or posedge reset_n) begin
        if (reset_n) begin
            counter <= 0;
            tick_1hz <= 0;
        end else begin
            if (counter >= CLOCK_LIMIT) begin 
                counter <= 0;
                tick_1hz <= 1;
            end else begin
                counter <= counter + 1;
                tick_1hz <= 0;
            end
        end
    end

    // --- 3. LOGIC DỊCH BIT (LED SHIFT) ---
    // Default string: 0011 [cite: 133]
    always @(posedge clk or posedge reset_n) begin
        if (reset_n) begin
            led <= 4'b0011; 
        end else if (tick_1hz) begin
            case (mode)
                1: led <= {led[2:0], led[3]}; // Circular Shift Left [cite: 135]
                2: led <= {led[0], led[3:1]}; // Circular Shift Right [cite: 136]
                default: led <= led;          // Pause [cite: 137]
            endcase
        end
    end

    // --- 4. GỬI UART VỀ MÁY TÍNH ---
    reg uart_start;
    reg [7:0] uart_data;
    wire uart_busy;
    
    // Instance module uart_tx
    // Truyền parameter xuống module con để đồng bộ tốc độ
    uart_tx #(
        .CLOCK_FREQ(CLOCK_FREQ),
        .BAUD_RATE(BAUD_RATE)
    ) u_tx (
        .clk(clk), 
        .rst(reset_n),
        .start(uart_start), 
        .data(uart_data),
        .tx(uart_tx_out), 
        .busy(uart_busy)
    );

    reg [3:0] tx_state;
    reg [3:0] led_snapshot;

    // Mã ASCII
    localparam CHAR_0 = 8'h30; // '0'
    localparam CHAR_1 = 8'h31; // '1'
    localparam CHAR_LF = 8'h0A; // '\n' (Line Feed)

    always @(posedge clk or posedge reset_n) begin
        if (reset_n) begin
            tx_state <= 0;
            uart_start <= 0;
            uart_data <= 0;
        end else begin
            case (tx_state)
                0: begin // IDLE: Chờ tín hiệu 1Hz để gửi
                    uart_start <= 0;
                    if (tick_1hz) begin
                        led_snapshot <= led; // Chụp lại trạng thái LED
                        tx_state <= 1;
                    end
                end

                // Gửi Bit 3
                1: begin
                    if (!uart_busy) begin
                        uart_data <= (led_snapshot[3]) ? CHAR_1 : CHAR_0;
                        uart_start <= 1;
                        tx_state <= 2;
                    end
                end
                2: begin uart_start <= 0; tx_state <= 3; end
                
                // Gửi Bit 2
                3: begin
                    if (!uart_busy) begin
                        uart_data <= (led_snapshot[2]) ? CHAR_1 : CHAR_0;
                        uart_start <= 1;
                        tx_state <= 4;
                    end
                end
                4: begin uart_start <= 0; tx_state <= 5; end

                // Gửi Bit 1
                5: begin
                    if (!uart_busy) begin
                        uart_data <= (led_snapshot[1]) ? CHAR_1 : CHAR_0;
                        uart_start <= 1;
                        tx_state <= 6;
                    end
                end
                6: begin uart_start <= 0; tx_state <= 7; end

                // Gửi Bit 0
                7: begin
                    if (!uart_busy) begin
                        uart_data <= (led_snapshot[0]) ? CHAR_1 : CHAR_0;
                        uart_start <= 1;
                        tx_state <= 8;
                    end
                end
                8: begin uart_start <= 0; tx_state <= 9; end

                // Gửi Xuống dòng (\n)
                9: begin
                    if (!uart_busy) begin
                        uart_data <= CHAR_LF; 
                        uart_start <= 1;
                        tx_state <= 10;
                    end
                end
                10: begin 
                    uart_start <= 0; 
                    tx_state <= 11; // Chờ UART rảnh hoàn toàn
                end
                
                11: begin
                    if (!uart_busy) tx_state <= 0; // Quay về IDLE
                end
                
            endcase
        end
    end
endmodule
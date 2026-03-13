module uart_tx #(
    parameter CLOCK_FREQ = 125000000,
    parameter BAUD_RATE  = 9600
)(
    input clk,          
    input rst,
    input start,        
    input [7:0] data,   
    output reg tx,      
    output reg busy     
);
    // Tính toán số chu kỳ clock cho mỗi bit
    localparam CLKS_PER_BIT = CLOCK_FREQ / BAUD_RATE;
    
    localparam IDLE = 0, START_BIT = 1, DATA_BITS = 2, STOP_BIT = 3;
    reg [1:0] state;
    reg [13:0] clk_count;
    reg [2:0] bit_index;
    reg [7:0] data_reg;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            tx <= 1; 
            busy <= 0;
            clk_count <= 0;
            bit_index <= 0;
        end else begin
            case (state)
                IDLE: begin
                    tx <= 1;
                    clk_count <= 0;
                    bit_index <= 0;
                    if (start) begin
                        state <= START_BIT;
                        data_reg <= data;
                        busy <= 1;
                    end else begin
                        busy <= 0;
                    end
                end
                
                START_BIT: begin 
                    tx <= 0;
                    if (clk_count < CLKS_PER_BIT - 1) begin
                        clk_count <= clk_count + 1;
                    end else begin
                        clk_count <= 0;
                        state <= DATA_BITS;
                    end
                end
                
                DATA_BITS: begin 
                    tx <= data_reg[bit_index];
                    if (clk_count < CLKS_PER_BIT - 1) begin
                        clk_count <= clk_count + 1;
                    end else begin
                        clk_count <= 0;
                        if (bit_index < 7) begin
                            bit_index <= bit_index + 1;
                        end else begin
                            bit_index <= 0;
                            state <= STOP_BIT;
                        end
                    end
                end
                
                STOP_BIT: begin 
                    tx <= 1;
                    if (clk_count < CLKS_PER_BIT - 1) begin
                        clk_count <= clk_count + 1;
                    end else begin
                        state <= IDLE;
                        busy <= 0;
                    end
                end
            endcase
        end
    end
endmodule
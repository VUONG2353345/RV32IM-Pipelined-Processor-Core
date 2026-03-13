`timescale 1ns / 1ps

module led_decoration_system #(parameter CLOCK_LIMIT = 25000000) ( // Default: 25M cycles ~ 0.2s (5Hz)
    input clk,             // System Clock 125MHz
    input reset_n,         // BTN0 - Active High Reset
    input [1:0] sw,        // SW1, SW0 - Mode Selection
    
    // Output 4 7-segment LEDs
    output reg [3:0] seg0_bcd, 
    output reg [3:0] seg1_bcd, 
    output reg [3:0] seg2_bcd, 
    output reg [3:0] seg3_bcd  
);

    wire rst = reset_n; // Active High Reset logic
    
    // BCD Constants
    localparam NUM_2 = 4'd2;
    localparam NUM_5 = 4'd5;
    localparam BLANK = 4'hF; 

    // --- CLOCK DIVIDER (Using Parameter) ---
    reg [25:0] counter;
    reg move_tick;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            counter <= 0;
            move_tick <= 0;
        end else begin
            // Generates a tick based on CLOCK_LIMIT
            if (counter >= CLOCK_LIMIT - 1) begin
                counter <= 0;
                move_tick <= 1;
            end else begin
                counter <= counter + 1;
                move_tick <= 0;
            end
        end
    end

    // --- EFFECT CONTROL LOGIC ---
    reg [1:0] step; 
    reg direction; // 0: Moving Right, 1: Moving Left

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            step <= 0;
            direction <= 0;
        end else if (move_tick) begin
            
            case (sw)
                // --- EFFECT 1: SCROLL LEFT (00) ---
                // Sequence: 0 -> 3 -> 2 -> 1 -> 0... (Decrement)
                2'b00: begin
                    step <= step - 1; 
                end

                // --- EFFECT 2: SCROLL RIGHT (01) ---
                // Sequence: 0 -> 1 -> 2 -> 3 -> 0... (Increment)
                2'b01: begin
                    step <= step + 1;
                end

                // --- EFFECT 3: BOUNCE (10) ---
                // Sequence: 0 -> 1 -> 2 -> 1 -> 0... (Ping-pong)
                2'b10: begin
                    if (direction == 0) begin // Moving Right
                        if (step == 2) begin  // Hit Right Edge
                            direction <= 1;   // Change Direction to Left
                            step <= 1;        // Move back
                        end else begin
                            step <= step + 1;
                        end
                    end else begin // Moving Left
                        if (step == 0) begin  // Hit Left Edge
                            direction <= 0;   // Change Direction to Right
                            step <= 1;        // Move forward
                        end else begin
                            step <= step - 1;
                        end
                    end
                end

                // --- DEFAULT (11) ---
                default: step <= 0; 
            endcase
        end
    end

    // --- DISPLAY CONTROLLER (4 LEDs) ---
    always @(*) begin
        // Default: All OFF
        seg3_bcd = BLANK; seg2_bcd = BLANK; seg1_bcd = BLANK; seg0_bcd = BLANK;

        // Map 'step' to display position
        case (step)
            0: begin // [2][5][ ][ ] (Left Edge)
                seg3_bcd = NUM_2; seg2_bcd = NUM_5;
            end
            1: begin // [ ][2][5][ ] (Middle)
                seg2_bcd = NUM_2; seg1_bcd = NUM_5;
            end
            2: begin // [ ][ ][2][5] (Right Edge)
                seg1_bcd = NUM_2; seg0_bcd = NUM_5;
            end
            3: begin // [5][ ][ ][2] (Wrap Around - Scroll Loop only)
                seg0_bcd = NUM_2; seg3_bcd = NUM_5;
            end
        endcase
    end

endmodule
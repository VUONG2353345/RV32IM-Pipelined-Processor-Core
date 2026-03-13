`timescale 1ns / 1ps

module traffic_light_system #(parameter CLOCK_LIMIT = 62500000)(
    input clk,             // System Clock (125MHz)
    input reset_n,         // BTN0 - Reset Input
    input [1:0] sw,        // SW0: Mode Select (0: Run, 1: Config), SW1: Light Select
    input [1:0] btn,       // BTN1: Increase Time Button
    
    // Output RGB LEDs (Controls the traffic light colors)
    output reg [2:0] led_rgb1, 
    output reg [2:0] led_rgb2, 
    
    // Output 7-Segment Display (BCD Inputs A,B,C,D)
    output [3:0] seg0_bcd, // Units Digit
    output [3:0] seg1_bcd, // Tens Digit
    output [3:0] seg2_bcd, // Unused (OFF)
    output [3:0] seg3_bcd  // Unused (OFF)
);

    // --- SIGNAL DECLARATIONS ---
    wire rst = reset_n; // Internal Active High Reset signal
    
    // Finite State Machine (FSM) States
    localparam S_G1_R2 = 2'b00; // Lane 1 Green, Lane 2 Red
    localparam S_Y1_R2 = 2'b01; // Lane 1 Yellow, Lane 2 Red
    localparam S_R1_G2 = 2'b10; // Lane 1 Red, Lane 2 Green
    localparam S_R1_Y2 = 2'b11; // Lane 1 Red, Lane 2 Yellow
    
    reg [1:0] current_state;
    reg [5:0] timer; // Countdown timer (6-bit to support > 15s)

    // Configuration registers (Default: Green=10s, Yellow=3s)
    reg [5:0] set_green_time;
    reg [5:0] set_yellow_time;

    // Clock Divider signals
    reg [26:0] clk_counter;
    reg clk_1hz;

    // Button Edge Detection signals
    reg btn1_prev;
    wire btn1_posedge;

    // =========================================================
    // 1. BUTTON EDGE DETECTION
    // Detects the rising edge of BTN1 to prevent multiple increments
    // =========================================================
    always @(posedge clk) begin
        btn1_prev <= btn[1];
    end
    // Logic 1 only when button changes from LOW to HIGH
    assign btn1_posedge = btn[1] && !btn1_prev;

    // =========================================================
    // 2. CONFIGURATION LOGIC (SETTING TIME)
    // Allows user to adjust green/yellow duration when SW0 = 1
    // =========================================================
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            set_green_time <= 10;
            set_yellow_time <= 3;
        end else begin
            // Only active in Config Mode (SW0 = 1)
            if (sw[0] == 1) begin
                if (btn1_posedge) begin
                    if (sw[1] == 0) begin // SW1=0: Adjust Green Light
                        // Increment time, wrap around to 5 if > 60
                        if (set_green_time < 60) set_green_time <= set_green_time + 1;
                        else set_green_time <= 5; 
                    end else begin        // SW1=1: Adjust Yellow Light
                        // Increment time, wrap around to 2 if > 20
                        if (set_yellow_time < 20) set_yellow_time <= set_yellow_time + 1;
                        else set_yellow_time <= 2; 
                    end
                end
            end
        end
    end

    // =========================================================
    // 3. CLOCK DIVIDER
    // Converts 125MHz system clock to 1Hz (1 second pulse)
    // Uses CLOCK_LIMIT parameter for simulation flexibility
    // =========================================================
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            clk_counter <= 0;
            clk_1hz <= 0;
        end else begin
            // Toggle clk_1hz when counter reaches limit
            if (clk_counter >= CLOCK_LIMIT - 1) begin
                clk_counter <= 0;
                clk_1hz <= ~clk_1hz;
            end else begin
                clk_counter <= clk_counter + 1;
            end
        end
    end

    // =========================================================
    // 4. FINITE STATE MACHINE (FSM)
    // Controls traffic light sequence and countdown timer
    // =========================================================
    always @(posedge clk_1hz or posedge rst) begin
        if (rst) begin
            current_state <= S_G1_R2;
            timer <= 9; // Initial timer
        end else begin
            // FSM only runs in Run Mode (SW0 = 0)
            if (sw[0] == 0) begin
                if (timer == 0) begin
                    // State Transition Logic
                    case (current_state)
                        S_G1_R2: begin 
                            current_state <= S_Y1_R2; 
                            timer <= set_yellow_time - 1; 
                        end
                        S_Y1_R2: begin 
                            current_state <= S_R1_G2; 
                            timer <= set_green_time - 1;  
                        end
                        S_R1_G2: begin 
                            current_state <= S_R1_Y2; 
                            timer <= set_yellow_time - 1; 
                        end
                        S_R1_Y2: begin 
                            current_state <= S_G1_R2; 
                            timer <= set_green_time - 1;  
                        end
                    endcase
                end else begin
                    // Decrement timer
                    timer <= timer - 1;
                end
            end
        end
    end

    // =========================================================
    // 5. RGB LED CONTROLLER
    // Determines LED colors based on Mode and State
    // =========================================================
    always @(*) begin
        // If in Config Mode (SW0=1): Turn all LEDs White (Indicator)
        if (sw[0] == 1) begin
             led_rgb1 = 3'b111; // 111 = White
             led_rgb2 = 3'b111;
        end else begin
            // Run Mode: Set colors based on FSM state
            // Mapping: 3'b010 = Green, 3'b001 = Yellow, 3'b100 = Red
            case (current_state)
                S_G1_R2: begin led_rgb1 = 3'b010; led_rgb2 = 3'b100; end // Green - Red
                S_Y1_R2: begin led_rgb1 = 3'b001; led_rgb2 = 3'b100; end // Yellow - Red
                S_R1_G2: begin led_rgb1 = 3'b100; led_rgb2 = 3'b010; end // Red - Green
                S_R1_Y2: begin led_rgb1 = 3'b100; led_rgb2 = 3'b001; end // Red - Yellow
                default: begin led_rgb1 = 3'b000; led_rgb2 = 3'b000; end
            endcase
        end
    end

    // =========================================================
    // 6. 7-SEGMENT DISPLAY CONTROLLER
    // Selects value to display and converts Binary to BCD
    // =========================================================
    reg [5:0] display_val;

    // Mux to select what to display
    always @(*) begin
        if (sw[0] == 1) begin
            // Config Mode: Display the setting value (Green or Yellow setting)
            if (sw[1] == 0) display_val = set_green_time;
            else            display_val = set_yellow_time;
        end else begin
            // Run Mode: Display the countdown timer (+1 for human readability)
            display_val = timer + 1; 
        end
    end

    // Binary to BCD Conversion (Splitting Tens and Units)
    wire [3:0] tens = display_val / 10;
    wire [3:0] units = display_val % 10;

    // Assign to Output Ports
    assign seg1_bcd = tens;  // Tens Digit
    assign seg0_bcd = units; // Units Digit
    
    assign seg2_bcd = 4'd0;  // Turn OFF
    assign seg3_bcd = 4'd0;  // Turn OFF

endmodule
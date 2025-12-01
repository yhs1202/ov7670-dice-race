`timescale 1ns / 1ps

//=============================================================================
// Module: ROI_Color_Detector
// Description: RGB color detection within a Region of Interest (ROI)
//              Designed for easy integration with future game FSM
//
// Architecture Integration:
//   - Receives 320占쏙옙240 pixel stream from ImgMemReader_ColorDetect
//   - Processes RGB888 (8-bit per channel) for accurate color detection
//   - Outputs frame-level dominant color with confidence
//
// Features:
//   - Configurable ROI boundaries (in 320占쏙옙240 coordinate space)
//   - RGB threshold-based color detection
//   - Per-frame dominant color determination with minimum threshold
//   - Color confidence output for noise rejection
//   - Frame-synchronous valid signal for FSM triggering
//
// Timing:
//   - Accumulates color counts during entire frame
//   - Outputs result 1 cycle after frame_start pulse (frame boundary)
//   - color_valid pulse is synchronized with frame timing
//=============================================================================

module ROI_Color_Detector #(
    parameter ROI_X_START = 10'd100,   // ROI left boundary (320횞240 space)
    parameter ROI_X_END   = 10'd220,   // ROI right boundary
    parameter ROI_Y_START = 10'd60,    // ROI top boundary
    parameter ROI_Y_END   = 10'd180,   // ROI bottom boundary
    
    // RGB Thresholds (8-bit values, 0-255 range)
    // Adjusted for OV7670 camera color characteristics
    // RED detection: R > R_MIN && G < G_MAX && B < B_MAX
    parameter RED_R_MIN = 8'd150,      // Minimum red channel value (lowered for camera)
    parameter RED_G_MAX = 8'd120,      // Maximum green (to reject yellow)
    parameter RED_B_MAX = 8'd120,      // Maximum blue (to reject magenta)
    
    // GREEN detection: R < R_MAX && G > G_MIN && B < B_MAX
    parameter GREEN_R_MAX = 8'd120,    // Maximum red (to reject yellow)
    parameter GREEN_G_MIN = 8'd150,    // Minimum green channel value
    parameter GREEN_B_MAX = 8'd120,    // Maximum blue (to reject cyan)
    
    // BLUE detection: R < R_MAX && G < G_MAX && B > B_MIN
    parameter BLUE_R_MAX = 8'd120,     // Maximum red (to reject magenta)
    parameter BLUE_G_MAX = 8'd120,     // Maximum green (to reject cyan)
    parameter BLUE_B_MIN = 8'd150,     // Minimum blue channel value
    
    // WHITE detection: R > R_MIN && G > G_MIN && B > B_MIN (all channels high)
    parameter WHITE_R_MIN = 8'd180,    // Minimum red for white
    parameter WHITE_G_MIN = 8'd180,    // Minimum green for white
    parameter WHITE_B_MIN = 8'd180,    // Minimum blue for white
    
    // Minimum pixel count to declare a color (noise rejection)
    parameter MIN_PIXEL_THRESHOLD = 16'd100,     // Increased for stability
    parameter WHITE_PIXEL_THRESHOLD = 16'd500    // Higher threshold for white background
) (
    input  logic        clk,
    input  logic        reset,
    
    // Pixel stream input (synchronized with display timing)
    input  logic        pixel_valid,    // High when valid pixel data
    input  logic        frame_start,    // Pulse at start of new frame
    input  logic [9:0]  x_coord,        // Pixel X coordinate (0-319)
    input  logic [9:0]  y_coord,        // Pixel Y coordinate (0-239)
    input  logic [7:0]  pixel_r,        // 8-bit red channel
    input  logic [7:0]  pixel_g,        // 8-bit green channel
    input  logic [7:0]  pixel_b,        // 8-bit blue channel
    
    // ROI indicator (for display overlay)
    output logic        in_roi,         // High when current pixel is in ROI
    
    // Per-pixel color detection (real-time, combinational)
    output logic        is_red,         // High when red detected at current pixel
    output logic        is_green,       // High when green detected
    output logic        is_blue,        // High when blue detected
    output logic        is_white,       // High when white detected at current pixel
    
    // Frame-level dominant color output (for FSM integration)
    output logic [1:0]  dominant_color, // 2'b01=RED, 2'b10=GREEN, 2'b11=BLUE, 2'b00=NONE/WHITE
    output logic        color_valid,    // Pulse for 1 cycle when R/G/B detected (NOT for white/none)
    output logic        white_detected, // Pulse when white background detected (turn end signal)
    output logic [15:0] color_confidence // Pixel count of dominant color (0-14400 max for 120횞120 ROI)
);

    //=========================================================================
    // Color encoding for FSM compatibility
    //=========================================================================
    localparam [1:0] COLOR_NONE  = 2'b00;  // No color or WHITE (IDLE state)
    localparam [1:0] COLOR_RED   = 2'b01;  // 1-step movement
    localparam [1:0] COLOR_GREEN = 2'b10;  // 2-step movement
    localparam [1:0] COLOR_BLUE  = 2'b11;  // 3-step movement
    
    //=========================================================================
    // Internal signals
    //=========================================================================
    logic in_roi_x, in_roi_y;
    logic is_red_detect, is_green_detect, is_blue_detect, is_white_detect;
    
    // Pixel counters for each color within ROI
    logic [15:0] red_count;
    logic [15:0] green_count;
    logic [15:0] blue_count;
    logic [15:0] white_count;
    
    // Latched results at frame end
    logic [15:0] red_count_latched;
    logic [15:0] green_count_latched;
    logic [15:0] blue_count_latched;
    logic [15:0] white_count_latched;
    logic [1:0]  dominant_color_reg;
    logic [15:0] confidence_reg;
    logic        white_detected_reg;
    
    // Frame control
    logic frame_active;
    logic frame_end_detect;
    logic frame_start_d;
    
    //=========================================================================
    // ROI Detection
    //=========================================================================
    assign in_roi_x = (x_coord >= ROI_X_START) && (x_coord < ROI_X_END);
    assign in_roi_y = (y_coord >= ROI_Y_START) && (y_coord < ROI_Y_END);
    assign in_roi = in_roi_x && in_roi_y;
    
    //=========================================================================
    // RGB Threshold Color Detection (Real-time per pixel)
    //=========================================================================
    // RED: High R, Low G, Low B
    assign is_red_detect = (pixel_r >= RED_R_MIN) && 
                           (pixel_g < RED_G_MAX) && 
                           (pixel_b < RED_B_MAX);
    
    // GREEN: Low R, High G, Low B
    assign is_green_detect = (pixel_r < GREEN_R_MAX) && 
                             (pixel_g >= GREEN_G_MIN) && 
                             (pixel_b < GREEN_B_MAX);
    
    // BLUE: Low R, Low G, High B
    assign is_blue_detect = (pixel_r < BLUE_R_MAX) && 
                            (pixel_g < BLUE_G_MAX) && 
                            (pixel_b >= BLUE_B_MIN);
    
    // WHITE: All channels high (background/IDLE state)
    assign is_white_detect = (pixel_r >= WHITE_R_MIN) && 
                             (pixel_g >= WHITE_G_MIN) && 
                             (pixel_b >= WHITE_B_MIN);
    
    // Output real-time detection (only within ROI)
    assign is_red   = in_roi && pixel_valid && is_red_detect;
    assign is_green = in_roi && pixel_valid && is_green_detect;
    assign is_blue  = in_roi && pixel_valid && is_blue_detect;
    assign is_white = in_roi && pixel_valid && is_white_detect;
    
    //=========================================================================
    // Frame Control Logic
    // frame_start pulse marks the beginning of a new frame
    // We use this to:
    //   1. Latch previous frame's color counts
    //   2. Reset counters for new frame
    //   3. Generate color_valid output pulse
    //=========================================================================
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            frame_start_d <= 1'b0;
            frame_active <= 1'b0;
        end else begin
            frame_start_d <= frame_start;
            
            // Frame is active between frame_start pulses
            if (frame_start)
                frame_active <= 1'b1;
        end
    end
    
    // Detect frame boundary (rising edge of frame_start)
    assign frame_end_detect = frame_start && !frame_start_d;
    
    //=========================================================================
    // Color Pixel Counters (accumulate during frame)
    // Counters track how many pixels of each color are detected in ROI
    //=========================================================================
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            red_count   <= 16'd0;
            green_count <= 16'd0;
            blue_count  <= 16'd0;
            white_count <= 16'd0;
        end else begin
            // At frame boundary, latch and reset
            if (frame_end_detect) begin
                red_count   <= 16'd0;
                green_count <= 16'd0;
                blue_count  <= 16'd0;
                white_count <= 16'd0;
            end 
            // During frame, accumulate color counts within ROI
            else if (pixel_valid && in_roi) begin
                // Count each color independently (pixel can match multiple colors)
                // WHITE has priority - if white, don't count other colors
                if (is_white_detect)
                    white_count <= white_count + 16'd1;
                else begin
                    if (is_red_detect)
                        red_count <= red_count + 16'd1;
                    if (is_green_detect)
                        green_count <= green_count + 16'd1;
                    if (is_blue_detect)
                        blue_count <= blue_count + 16'd1;
                end
            end
        end
    end
    
    //=========================================================================
    // Dominant Color Determination (at frame boundary)
    // Uses winner-takes-all strategy with minimum threshold
    //
    // Game Logic:
    //   - R/G/B color has PRIORITY over WHITE
    //   - WHITE is only detected when NO R/G/B colors are present
    //   - This ensures dice color is captured first, then turn ends when dice removed
    //=========================================================================
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            red_count_latched   <= 16'd0;
            green_count_latched <= 16'd0;
            blue_count_latched  <= 16'd0;
            white_count_latched <= 16'd0;
            dominant_color_reg  <= COLOR_NONE;
            white_detected_reg  <= 1'b0;
            confidence_reg      <= 16'd0;
            color_valid         <= 1'b0;
        end else begin
            color_valid <= 1'b0;         // Default: single-cycle pulse
            white_detected_reg <= 1'b0;  // Default: single-cycle pulse
            
            if (frame_end_detect) begin
                // Latch counts from previous frame (before reset)
                red_count_latched   <= red_count;
                green_count_latched <= green_count;
                blue_count_latched  <= blue_count;
                white_count_latched <= white_count;
                
                // PRIORITY 1: Check for R/G/B colors FIRST (dice on screen)
                // Determine dominant color using winner-takes-all
                if (red_count >= green_count && red_count >= blue_count && red_count > MIN_PIXEL_THRESHOLD) begin
                    dominant_color_reg <= COLOR_RED;
                    confidence_reg     <= red_count;
                    color_valid        <= 1'b1;  // Valid color detected!
                end 
                else if (green_count >= red_count && green_count >= blue_count && green_count > MIN_PIXEL_THRESHOLD) begin
                    dominant_color_reg <= COLOR_GREEN;
                    confidence_reg     <= green_count;
                    color_valid        <= 1'b1;  // Valid color detected!
                end 
                else if (blue_count >= red_count && blue_count >= green_count && blue_count > MIN_PIXEL_THRESHOLD) begin
                    dominant_color_reg <= COLOR_BLUE;
                    confidence_reg     <= blue_count;
                    color_valid        <= 1'b1;  // Valid color detected!
                end 
                // PRIORITY 2: No R/G/B detected, check for WHITE (dice removed, turn end)
                else if (white_count > WHITE_PIXEL_THRESHOLD) begin
                    // White background detected - signal turn end
                    // Only triggers when NO dice colors are present
                    dominant_color_reg <= COLOR_NONE;
                    confidence_reg     <= white_count;
                    white_detected_reg <= 1'b1;  // Turn end signal
                    color_valid        <= 1'b0;  // NO color_valid for white
                end
                else begin
                    // No color exceeds threshold (ambiguous state)
                    dominant_color_reg <= COLOR_NONE;
                    confidence_reg     <= 16'd0;
                    color_valid        <= 1'b0;
                end
            end
        end
    end
    
    //=========================================================================
    // Output assignments
    //=========================================================================
    assign dominant_color = dominant_color_reg;
    assign color_confidence = confidence_reg;
    assign white_detected = white_detected_reg;
    
endmodule

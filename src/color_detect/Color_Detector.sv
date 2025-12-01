`timescale 1ns / 1ps

//=============================================================================
// Module: Color_Detector
// Description: Main color detection module that integrates ROI_Color_Detector
//              and Color_Result_Manager. Detects dice colors within ROI and
//              provides stable output for game logic.
//
// Architecture:
//   - ROI_Color_Detector: Performs RGB color detection within ROI
//   - Color_Result_Manager: Manages results with voting and state tracking
//   - Display_Overlay: Removed (handled in upper level module)
//
// Input: Pixel stream from frame buffer (RGB565 format)
// Output: Stable color detection results for game FSM
//=============================================================================

module Color_Detector (
    input  logic        clk,
    input  logic        reset,
    input  logic        DE,                    // Display enable
    input  logic [ 9:0] x_pixel,               // VGA X coordinate
    input  logic [ 9:0] y_pixel,               // VGA Y coordinate
    input  logic [15:0] pixel_rgb_data,        // RGB565 pixel data from frame buffer
    
    // Output to Game Logic (from Color_Result_Manager)
    output logic [ 1:0] stable_color,          // 00=NONE, 01=RED, 10=GREEN, 11=BLUE
    output logic        result_ready,          // Pulse: valid dice color detected
    output logic        turn_end,              // Pulse: white background (turn complete)
    output logic        current_state_white,   // Level: currently detecting WHITE background
    output logic [15:0] stable_confidence      // Debug: confidence value
);
    
    //=========================================================================
    // ROI Parameters (in 320x240 coordinate space)
    //=========================================================================
    localparam ROI_X_START = 10'd100;
    localparam ROI_X_END = 10'd220;
    localparam ROI_Y_START = 10'd60;
    localparam ROI_Y_END = 10'd180;
    
    //=========================================================================
    // Pixel Stream Processing
    // Extract RGB888 from RGB565 and generate frame timing
    //=========================================================================
    // RGB565 format: [15:11]=R, [10:5]=G, [4:0]=B
    // Convert to 8-bit for color detection
    logic [7:0] pixel_r8, pixel_g8, pixel_b8;
    assign pixel_r8 = {pixel_rgb_data[15:11], 3'b000};  // Scale 5-bit to 8-bit
    assign pixel_g8 = {pixel_rgb_data[10:5], 2'b00};    // Scale 6-bit to 8-bit
    assign pixel_b8 = {pixel_rgb_data[4:0], 3'b000};    // Scale 5-bit to 8-bit
    
    // Pixel valid: only process pixels in the 320x240 frame buffer region
    logic pixel_valid;
    assign pixel_valid = DE && (x_pixel < 10'd320) && (y_pixel < 10'd240);
    
    // Frame start detection: detect start of new frame (when y_pixel wraps to 0)
    logic y_pixel_d;
    logic frame_start;
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            y_pixel_d <= 10'd0;
        end else begin
            y_pixel_d <= y_pixel;
        end
    end
    assign frame_start = (y_pixel == 10'd0) && (y_pixel_d != 10'd0) && DE;
    
    //=========================================================================
    // ROI Color Detection
    //=========================================================================
    logic [1:0] dominant_color_raw;
    logic       color_valid_raw;
    logic       white_detected_raw;
    logic [15:0] confidence_raw;
    
    ROI_Color_Detector #(
        .ROI_X_START          (ROI_X_START),
        .ROI_X_END            (ROI_X_END),
        .ROI_Y_START          (ROI_Y_START),
        .ROI_Y_END            (ROI_Y_END),
        // Adjusted thresholds for OV7670 camera
        .RED_R_MIN            (8'd140),
        .RED_G_MAX            (8'd130),
        .RED_B_MAX            (8'd130),
        .GREEN_R_MAX          (8'd130),
        .GREEN_G_MIN          (8'd140),
        .GREEN_B_MAX          (8'd130),
        .BLUE_R_MAX           (8'd130),
        .BLUE_G_MAX           (8'd130),
        .BLUE_B_MIN           (8'd140),
        .WHITE_R_MIN          (8'd160),
        .WHITE_G_MIN          (8'd160),
        .WHITE_B_MIN          (8'd160),
        .MIN_PIXEL_THRESHOLD  (16'd200),
        .WHITE_PIXEL_THRESHOLD(16'd5000)
    ) U_ROI_Color_Detector (
        .clk             (clk),
        .reset           (reset),
        .pixel_valid     (pixel_valid),
        .frame_start     (frame_start),
        .x_coord         (x_pixel),
        .y_coord         (y_pixel),
        .pixel_r         (pixel_r8),
        .pixel_g         (pixel_g8),
        .pixel_b         (pixel_b8),
        .in_roi          (),              // Not used internally
        .is_red          (),              // Not used internally
        .is_green        (),              // Not used internally
        .is_blue         (),              // Not used internally
        .is_white        (),              // Not used internally
        .dominant_color  (dominant_color_raw),
        .color_valid     (color_valid_raw),
        .white_detected  (white_detected_raw),
        .color_confidence(confidence_raw)
    );
    
    //=========================================================================
    // Color Result Management (with voting and state tracking)
    //=========================================================================
    Color_Result_Manager #(
        .ENABLE_VOTING    (1),
        .MIN_CONFIDENCE   (16'd100),
        .WHITE_FRAME_COUNT(3)         // Consecutive WHITE frames required
    ) U_Result_Manager (
        .clk                (clk),
        .reset              (reset),
        .detected_color     (dominant_color_raw),
        .color_valid        (color_valid_raw),
        .color_confidence   (confidence_raw),
        .white_detected     (white_detected_raw),
        .stable_color       (stable_color),
        .result_ready       (result_ready),
        .turn_end           (turn_end),
        .current_state_white(current_state_white),
        .stable_confidence  (stable_confidence)
    );

endmodule

`timescale 1ns / 1ps

//=============================================================================
// Module: Display_Overlay
// Description: Overlay graphics on video stream (ROI box, color indicators)
//
// IMPORTANT: This module works with 320x240 frame buffer displayed on 640x480 VGA
//            ROI parameters are in 320x240 coordinate space
//            VGA coordinates (x_coord, y_coord) go up to 640x480
//
// Features:
//   - ROI bounding box visualization (scaled 2x for VGA display)
//   - Dominant color indicator box in corner
//   - Passes through original pixel data outside overlay regions
//=============================================================================

module Display_Overlay #(
    // ROI parameters in 320x240 coordinate space
    parameter ROI_X_START = 10'd100,
    parameter ROI_X_END   = 10'd220,
    parameter ROI_Y_START = 10'd60,
    parameter ROI_Y_END   = 10'd180,
    parameter BOX_THICKNESS = 2'd2      // ROI box border thickness (in 320x240 space)
) (
    input  logic        clk,
    input  logic        reset,
    
    // VGA timing (640x480 coordinate space)
    input  logic [9:0]  x_coord,
    input  logic [9:0]  y_coord,
    input  logic        display_enable,
    
    // Original pixel data (from frame buffer, valid only for x<320, y<240)
    input  logic [3:0]  pixel_r_in,
    input  logic [3:0]  pixel_g_in,
    input  logic [3:0]  pixel_b_in,
    
    // Color detection info
    input  logic [1:0]  dominant_color,   // Detected dominant color from Color_Result_Manager
    input  logic        white_detected,   // Level signal: currently in WHITE/IDLE state
    
    // Overlaid output
    output logic [3:0]  pixel_r_out,
    output logic [3:0]  pixel_g_out,
    output logic [3:0]  pixel_b_out
);

    //=========================================================================
    // Color encoding
    //=========================================================================
    localparam [1:0] COLOR_NONE  = 2'b00;
    localparam [1:0] COLOR_RED   = 2'b01;
    localparam [1:0] COLOR_GREEN = 2'b10;
    localparam [1:0] COLOR_BLUE  = 2'b11;
    
    //=========================================================================
    // Check if we're in the 320x240 frame buffer display region
    //=========================================================================
    logic in_framebuffer_region;
    assign in_framebuffer_region = (x_coord < 10'd320) && (y_coord < 10'd240);
    
    //=========================================================================
    // ROI Boundary Detection (in 320x240 space, so check against x_coord/y_coord directly)
    // Only draw ROI border when within the 320x240 region
    //=========================================================================
    logic on_roi_border;
    logic on_roi_left, on_roi_right, on_roi_top, on_roi_bottom;
    
    assign on_roi_left   = in_framebuffer_region &&
                           (x_coord >= ROI_X_START) && (x_coord < ROI_X_START + BOX_THICKNESS) && 
                           (y_coord >= ROI_Y_START) && (y_coord < ROI_Y_END);
    
    assign on_roi_right  = in_framebuffer_region &&
                           (x_coord >= ROI_X_END - BOX_THICKNESS) && (x_coord < ROI_X_END) && 
                           (y_coord >= ROI_Y_START) && (y_coord < ROI_Y_END);
    
    assign on_roi_top    = in_framebuffer_region &&
                           (y_coord >= ROI_Y_START) && (y_coord < ROI_Y_START + BOX_THICKNESS) && 
                           (x_coord >= ROI_X_START) && (x_coord < ROI_X_END);
    
    assign on_roi_bottom = in_framebuffer_region &&
                           (y_coord >= ROI_Y_END - BOX_THICKNESS) && (y_coord < ROI_Y_END) && 
                           (x_coord >= ROI_X_START) && (x_coord < ROI_X_END);
    
    assign on_roi_border = on_roi_left || on_roi_right || on_roi_top || on_roi_bottom;
    
    //=========================================================================
    // Color Indicator Area (top-left corner, outside ROI)
    //=========================================================================
    localparam INDICATOR_X = 10'd10;
    localparam INDICATOR_Y = 10'd10;
    localparam INDICATOR_SIZE = 10'd30;
    
    logic on_color_indicator;
    assign on_color_indicator = (x_coord >= INDICATOR_X) && (x_coord < INDICATOR_X + INDICATOR_SIZE) &&
                                (y_coord >= INDICATOR_Y) && (y_coord < INDICATOR_Y + INDICATOR_SIZE);
    
    //=========================================================================
    // Overlay Rendering
    // Note: Color detection signals (is_red, is_green, etc.) are only valid
    //       when in_framebuffer_region is true AND in_roi is true
    //=========================================================================
    logic [3:0] overlay_r, overlay_g, overlay_b;
    logic apply_overlay;
    
    always_comb begin
        // Default: pass through original pixel
        overlay_r = pixel_r_in;
        overlay_g = pixel_g_in;
        overlay_b = pixel_b_in;
        apply_overlay = 1'b0;
        
        if (display_enable) begin
            // Priority 1: Color indicator box (shows dominant color result)
            // This is always visible regardless of frame buffer region
            if (on_color_indicator) begin
                // WHITE detection has highest priority (dice removed = turn end)
                if (white_detected) begin
                    // Bright white for WHITE background detection
                    overlay_r = 4'hF;
                    overlay_g = 4'hF;
                    overlay_b = 4'hF;
                end
                else begin
                    case (dominant_color)
                        COLOR_RED: begin
                            overlay_r = 4'hF;
                            overlay_g = 4'h0;
                            overlay_b = 4'h0;
                        end
                        COLOR_GREEN: begin
                            overlay_r = 4'h0;
                            overlay_g = 4'hF;
                            overlay_b = 4'h0;
                        end
                        COLOR_BLUE: begin
                            overlay_r = 4'h0;
                            overlay_g = 4'h0;
                            overlay_b = 4'hF;
                        end
                        default: begin
                            // Dark gray for no detection (still looking for dice)
                            overlay_r = 4'h4;
                            overlay_g = 4'h4;
                            overlay_b = 4'h4;
                        end
                    endcase
                end
                apply_overlay = 1'b1;
            end
            
            // Priority 2: ROI border (yellow for visibility)
            else if (on_roi_border) begin
                overlay_r = 4'hF;
                overlay_g = 4'hF;
                overlay_b = 4'h0;  // Yellow border
                apply_overlay = 1'b1;
            end
            
            // Priority 3: Show original camera image (no color overlay in ROI)
            // Remove the real-time color highlighting as it causes timing issues
            // The color indicator box shows the detected color instead
        end
    end
    
    //=========================================================================
    // Output Assignment
    //=========================================================================
    assign pixel_r_out = apply_overlay ? overlay_r : pixel_r_in;
    assign pixel_g_out = apply_overlay ? overlay_g : pixel_g_in;
    assign pixel_b_out = apply_overlay ? overlay_b : pixel_b_in;
    
endmodule

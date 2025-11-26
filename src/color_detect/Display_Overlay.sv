`timescale 1ns / 1ps

//=============================================================================
// Module: Display_Overlay
// Description: Overlay graphics on video stream (ROI box, color indicators)
//
// Features:
//   - ROI bounding box visualization
//   - Dominant color display (fill ROI or corner indicator)
//   - Modular design - easy to add game UI elements later
//=============================================================================

module Display_Overlay #(
    parameter ROI_X_START = 10'd100,
    parameter ROI_X_END   = 10'd220,
    parameter ROI_Y_START = 10'd60,
    parameter ROI_Y_END   = 10'd180,
    parameter BOX_THICKNESS = 2'd2      // ROI box border thickness
) (
    input  logic        clk,
    input  logic        reset,
    
    // VGA timing
    input  logic [9:0]  x_coord,
    input  logic [9:0]  y_coord,
    input  logic        display_enable,
    
    // Original pixel data
    input  logic [3:0]  pixel_r_in,
    input  logic [3:0]  pixel_g_in,
    input  logic [3:0]  pixel_b_in,
    
    // Color detection info
    input  logic        in_roi,
    input  logic [1:0]  dominant_color,
    input  logic        is_red,
    input  logic        is_green,
    input  logic        is_blue,
    
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
    // ROI Boundary Detection
    //=========================================================================
    logic on_roi_border;
    logic on_roi_left, on_roi_right, on_roi_top, on_roi_bottom;
    
    assign on_roi_left   = (x_coord >= ROI_X_START) && (x_coord < ROI_X_START + BOX_THICKNESS) && 
                           (y_coord >= ROI_Y_START) && (y_coord < ROI_Y_END);
    
    assign on_roi_right  = (x_coord >= ROI_X_END - BOX_THICKNESS) && (x_coord < ROI_X_END) && 
                           (y_coord >= ROI_Y_START) && (y_coord < ROI_Y_END);
    
    assign on_roi_top    = (y_coord >= ROI_Y_START) && (y_coord < ROI_Y_START + BOX_THICKNESS) && 
                           (x_coord >= ROI_X_START) && (x_coord < ROI_X_END);
    
    assign on_roi_bottom = (y_coord >= ROI_Y_END - BOX_THICKNESS) && (y_coord < ROI_Y_END) && 
                           (x_coord >= ROI_X_START) && (x_coord < ROI_X_END);
    
    assign on_roi_border = on_roi_left || on_roi_right || on_roi_top || on_roi_bottom;
    
    //=========================================================================
    // Color Indicator Area (top-left corner of screen)
    //=========================================================================
    localparam INDICATOR_X = 10'd10;
    localparam INDICATOR_Y = 10'd10;
    localparam INDICATOR_SIZE = 10'd40;
    
    logic on_color_indicator;
    assign on_color_indicator = (x_coord >= INDICATOR_X) && (x_coord < INDICATOR_X + INDICATOR_SIZE) &&
                                (y_coord >= INDICATOR_Y) && (y_coord < INDICATOR_Y + INDICATOR_SIZE);
    
    //=========================================================================
    // Overlay Rendering
    //=========================================================================
    logic [3:0] overlay_r, overlay_g, overlay_b;
    logic apply_overlay;
    
    always_comb begin
        overlay_r = pixel_r_in;
        overlay_g = pixel_g_in;
        overlay_b = pixel_b_in;
        apply_overlay = 1'b0;
        
        if (display_enable) begin
            // Priority 1: ROI border (white)
            if (on_roi_border) begin
                overlay_r = 4'hF;
                overlay_g = 4'hF;
                overlay_b = 4'hF;
                apply_overlay = 1'b1;
            end
            
            // Priority 2: Real-time color detection visualization within ROI
            // Option A: Highlight detected pixels
            else if (in_roi) begin
                if (is_red) begin
                    // Boost red channel
                    overlay_r = 4'hF;
                    overlay_g = pixel_g_in >> 1;  // Dim other channels
                    overlay_b = pixel_b_in >> 1;
                    apply_overlay = 1'b1;
                end else if (is_green) begin
                    overlay_r = pixel_r_in >> 1;
                    overlay_g = 4'hF;
                    overlay_b = pixel_b_in >> 1;
                    apply_overlay = 1'b1;
                end else if (is_blue) begin
                    overlay_r = pixel_r_in >> 1;
                    overlay_g = pixel_g_in >> 1;
                    overlay_b = 4'hF;
                    apply_overlay = 1'b1;
                end
            end
            
            // Priority 3: Color indicator box (shows dominant color result)
            else if (on_color_indicator) begin
                case (dominant_color)
                    COLOR_RED: begin
                        overlay_r = 4'hF;
                        overlay_g = 4'h0;
                        overlay_b = 4'h0;
                        apply_overlay = 1'b1;
                    end
                    COLOR_GREEN: begin
                        overlay_r = 4'h0;
                        overlay_g = 4'hF;
                        overlay_b = 4'h0;
                        apply_overlay = 1'b1;
                    end
                    COLOR_BLUE: begin
                        overlay_r = 4'h0;
                        overlay_g = 4'h0;
                        overlay_b = 4'hF;
                        apply_overlay = 1'b1;
                    end
                    default: begin
                        // Gray for no detection
                        overlay_r = 4'h5;
                        overlay_g = 4'h5;
                        overlay_b = 4'h5;
                        apply_overlay = 1'b1;
                    end
                endcase
            end
        end
    end
    
    //=========================================================================
    // Output Assignment
    //=========================================================================
    assign pixel_r_out = apply_overlay ? overlay_r : pixel_r_in;
    assign pixel_g_out = apply_overlay ? overlay_g : pixel_g_in;
    assign pixel_b_out = apply_overlay ? overlay_b : pixel_b_in;
    
endmodule


//=============================================================================
// Alternative Module: Simple ROI Box Only (minimal overlay)
//=============================================================================
module Display_Overlay_Simple #(
    parameter ROI_X_START = 10'd100,
    parameter ROI_X_END   = 10'd220,
    parameter ROI_Y_START = 10'd60,
    parameter ROI_Y_END   = 10'd180
) (
    input  logic        clk,
    input  logic [9:0]  x_coord,
    input  logic [9:0]  y_coord,
    input  logic        display_enable,
    input  logic [3:0]  pixel_r_in,
    input  logic [3:0]  pixel_g_in,
    input  logic [3:0]  pixel_b_in,
    input  logic [1:0]  dominant_color,
    output logic [3:0]  pixel_r_out,
    output logic [3:0]  pixel_g_out,
    output logic [3:0]  pixel_b_out
);

    logic on_border;
    
    // Detect 2-pixel thick border
    assign on_border = display_enable && (
        ((x_coord == ROI_X_START || x_coord == ROI_X_START + 1 || 
          x_coord == ROI_X_END - 1 || x_coord == ROI_X_END - 2) && 
         (y_coord >= ROI_Y_START && y_coord < ROI_Y_END)) ||
        ((y_coord == ROI_Y_START || y_coord == ROI_Y_START + 1 || 
          y_coord == ROI_Y_END - 1 || y_coord == ROI_Y_END - 2) && 
         (x_coord >= ROI_X_START && x_coord < ROI_X_END))
    );
    
    // White border
    assign pixel_r_out = on_border ? 4'hF : pixel_r_in;
    assign pixel_g_out = on_border ? 4'hF : pixel_g_in;
    assign pixel_b_out = on_border ? 4'hF : pixel_b_in;
    
endmodule

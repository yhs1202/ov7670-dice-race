`timescale 1ns / 1ps

//=============================================================================
// Module: Posterize_Filter
// Description: Posterize/Pop Art effect filter
//              Reduces color levels to create artistic poster-like effect
//
// Features:
//   - Color quantization (reduces color levels)
//   - Creates pop art / poster art aesthetic
//   - Real-time processing - no memory required
//
// Effect: Reduces color depth to create artistic, poster-like appearance
//=============================================================================

module Posterize_Filter #(
    parameter IMG_WIDTH  = 160,
    parameter IMG_HEIGHT = 120,
    parameter COLOR_LEVELS = 4  // Number of color levels (2-8, higher = more colors)
) (
    input  logic       clk,
    input  logic       reset,
    input  logic [9:0] x_local,
    input  logic [9:0] y_local,
    input  logic       filter_en,
    input  logic [15:0] rgb565_in,  // RGB565: [15:11]=R, [10:5]=G, [4:0]=B
    output logic [15:0] rgb565_out
);

    //=========================================================================
    // Color quantization: reduce color levels to create poster effect
    // RGB565: R(5-bit, 0-31), G(6-bit, 0-63), B(5-bit, 0-31)
    // Simple approach: quantize to COLOR_LEVELS (default 4 levels for pop art effect)
    //=========================================================================
    logic [4:0] poster_r, poster_b;
    logic [5:0] poster_g;
    
    // Quantize each channel to COLOR_LEVELS levels
    always_comb begin
        if (filter_en) begin
            // R channel: 5-bit (0-31) -> COLOR_LEVELS levels
            // Default: 4 levels for pop art effect
            if (rgb565_in[15:11] < 8)
                poster_r = 5'd0;
            else if (rgb565_in[15:11] < 16)
                poster_r = 5'd10;
            else if (rgb565_in[15:11] < 24)
                poster_r = 5'd21;
            else
                poster_r = 5'd31;
            
            // G channel: 6-bit (0-63) -> COLOR_LEVELS levels
            if (rgb565_in[10:5] < 16)
                poster_g = 6'd0;
            else if (rgb565_in[10:5] < 32)
                poster_g = 6'd21;
            else if (rgb565_in[10:5] < 48)
                poster_g = 6'd42;
            else
                poster_g = 6'd63;
            
            // B channel: 5-bit (0-31) -> COLOR_LEVELS levels
            if (rgb565_in[4:0] < 8)
                poster_b = 5'd0;
            else if (rgb565_in[4:0] < 16)
                poster_b = 5'd10;
            else if (rgb565_in[4:0] < 24)
                poster_b = 5'd21;
            else
                poster_b = 5'd31;
            
            rgb565_out = {poster_r, poster_g, poster_b};
        end else begin
            // Filter disabled: pass through
            rgb565_out = rgb565_in;
        end
    end

endmodule


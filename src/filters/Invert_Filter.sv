`timescale 1ns / 1ps

//=============================================================================
// Module: Invert_Filter
// Description: Negative/Invert filter for video stream
//              Creates film negative effect by inverting RGB values
//
// Features:
//   - Full RGB inversion (complementary colors)
//   - Real-time processing
//   - Simple implementation - no memory required
//
// Effect: Dark becomes bright, bright becomes dark
//         Creates classic negative film aesthetic
//=============================================================================

module Invert_Filter #(
    parameter IMG_WIDTH  = 160,
    parameter IMG_HEIGHT = 120
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
    // RGB Inversion: complement for RGB565
    // RGB565: R(5-bit), G(6-bit), B(5-bit)
    //=========================================================================
    always_comb begin
        if (filter_en) begin
            // Invert each channel: max - input_value
            rgb565_out = {(5'd31 - rgb565_in[15:11]),  // R: 5-bit, max 31
                          (6'd63 - rgb565_in[10:5]),   // G: 6-bit, max 63
                          (5'd31 - rgb565_in[4:0])};    // B: 5-bit, max 31
        end else begin
            // Filter disabled: pass through
            rgb565_out = rgb565_in;
        end
    end

endmodule


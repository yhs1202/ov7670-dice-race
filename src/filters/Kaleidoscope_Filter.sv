`timescale 1ns / 1ps

//=============================================================================
// Module: Kaleidoscope_Filter
// Description: 4-way symmetry mirror effect (kaleidoscope)
//              Creates mirror patterns by reflecting top-right quadrant
//
// Features:
//   - 4-way symmetry around image center
//   - Uses frame buffer for coordinate transformation
//   - All pixels mapped to top-right quadrant, then mirrored
//
// Effect: Creates kaleidoscope pattern with 4 symmetric sections
//=============================================================================

module Kaleidoscope_Filter #(
    parameter IMG_WIDTH  = 160,
    parameter IMG_HEIGHT = 120,
    parameter ADDR_WIDTH = $clog2(IMG_WIDTH * IMG_HEIGHT)
) (
    input  logic       clk,
    input  logic       reset,
    input  logic [9:0] x_local,
    input  logic [9:0] y_local,
    input  logic       filter_en,
    input  logic [15:0] rgb565_in,  // RGB565: [15:11]=R, [10:5]=G, [4:0]=B
    // Frame buffer interface
    output logic [ADDR_WIDTH-1:0] read_addr,  // Source pixel address
    input  logic [15:0] frame_buffer_data,     // RGB565 from frame buffer
    output logic [15:0] rgb565_out
);

    //=========================================================================
    // Calculate center point of image
    //=========================================================================
    localparam CENTER_X = IMG_WIDTH / 2;   // 80
    localparam CENTER_Y = IMG_HEIGHT / 2;  // 60
    
    //=========================================================================
    // Coordinate transformation: map all pixels to top-right quadrant
    //=========================================================================
    logic [9:0] dx, dy;
    
    // Calculate offset from center (absolute distance)
    assign dx = (x_local >= CENTER_X) ? (x_local - CENTER_X) : (CENTER_X - x_local);
    assign dy = (y_local >= CENTER_Y) ? (y_local - CENTER_Y) : (CENTER_Y - y_local);
    
    // Source coordinate: always use top-right quadrant (1st quadrant)
    // This creates 4-way symmetry by mirroring
    logic [9:0] source_x_raw, source_y_raw;
    assign source_x_raw = CENTER_X + dx;  // Always on right side (80 + dx, max 160)
    assign source_y_raw = (dy > CENTER_Y) ? 9'd0 : (CENTER_Y - dy);  // Always on top side, prevent negative
    
    // Clamp to bounds (saturating arithmetic)
    logic [9:0] clamped_x, clamped_y;
    assign clamped_x = (source_x_raw >= IMG_WIDTH) ? (IMG_WIDTH - 1) : source_x_raw;
    assign clamped_y = source_y_raw;  // Already clamped above to prevent negative
    
    // Calculate frame buffer read address for source pixel
    assign read_addr = filter_en ? ((IMG_WIDTH * clamped_y) + clamped_x) : {ADDR_WIDTH{1'b0}};
    
    //=========================================================================
    // Extract RGB from frame buffer (RGB565: direct pass-through)
    //=========================================================================
    always_comb begin
        if (filter_en) begin
            // Direct RGB565 pass-through
            rgb565_out = frame_buffer_data;
        end else begin
            rgb565_out = rgb565_in;
        end
    end

endmodule


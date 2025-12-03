`timescale 1ns / 1ps

//=============================================================================
// Module: Fisheye_Filter
// Description: Fisheye zoom effect with circular mask
//              Creates circular viewport with magnification at center
//
// Features:
//   - Circular mask based on distance from center
//   - Inside circle: magnified image (zoomed in)
//   - Outside circle: black pixels
//   - Uses frame buffer for coordinate transformation
//
// Effect: Circular zoom window effect
//=============================================================================

module Fisheye_Filter #(
    parameter IMG_WIDTH  = 160,
    parameter IMG_HEIGHT = 120,
    parameter ADDR_WIDTH = $clog2(IMG_WIDTH * IMG_HEIGHT),
    parameter CIRCLE_RADIUS = 70,  // Radius of the circle (fixed at 70)
    parameter MAGNIFICATION = 2    // Zoom factor (1 = no zoom, 2 = 2x zoom)
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
    localparam CENTER_X = IMG_WIDTH  / 2;   // 80
    localparam CENTER_Y = IMG_HEIGHT / 2;   // 60
    
    //=========================================================================
    // Calculate Euclidean distance from center (dx^2 + dy^2)
    //=========================================================================
    logic [9:0] dx, dy;
    logic [19:0] dx_squared, dy_squared;
    logic [20:0] distance_squared;
    logic [10:0] radius_squared;
    
    // Calculate dx and dy (absolute distance from center)
    assign dx = (x_local >= CENTER_X) ? (x_local - CENTER_X) : (CENTER_X - x_local);
    assign dy = (y_local >= CENTER_Y) ? (y_local - CENTER_Y) : (CENTER_Y - y_local);
    
    // Calculate squared values
    assign dx_squared = dx * dx;
    assign dy_squared = dy * dy;
    assign distance_squared = dx_squared + dy_squared;
    
    // Compare squared radius (avoid sqrt)
    assign radius_squared = CIRCLE_RADIUS * CIRCLE_RADIUS;
    
    //=========================================================================
    // Check if pixel is inside circle
    //=========================================================================
    logic inside_circle;
    assign inside_circle = (distance_squared <= radius_squared);
    
    //=========================================================================
    // Coordinate transformation for magnification
    // For fisheye zoom: map current position to source position (closer to center)
    //=========================================================================
    logic [9:0] source_x, source_y;
    logic signed [10:0] dx_signed, dy_signed;  // Signed for direction
    
    // Calculate signed offset from center (for direction)
    assign dx_signed = $signed(x_local) - $signed(CENTER_X);
    assign dy_signed = $signed(y_local) - $signed(CENTER_Y);
    
    // Source coordinate: divide offset by magnification and add to center
    // This creates zoom effect: pixels closer to center are mapped to smaller source area
    // For MAGNIFICATION=2, divide offset by 2 (right shift 1 bit)
    logic signed [10:0] source_dx, source_dy;
    assign source_dx = dx_signed / MAGNIFICATION;
    assign source_dy = dy_signed / MAGNIFICATION;
    
    // Calculate source pixel coordinates
    logic signed [11:0] source_x_signed, source_y_signed;
    assign source_x_signed = $signed(CENTER_X) + source_dx;
    assign source_y_signed = $signed(CENTER_Y) + source_dy;
    
    // Clamp to image bounds
    assign source_x = (source_x_signed < 0) ? 10'd0 : 
                      (source_x_signed >= IMG_WIDTH) ? (IMG_WIDTH - 1) : 
                      source_x_signed[9:0];
    assign source_y = (source_y_signed < 0) ? 10'd0 : 
                      (source_y_signed >= IMG_HEIGHT) ? (IMG_HEIGHT - 1) : 
                      source_y_signed[9:0];
    
    // Calculate frame buffer read address (only for inside circle magnification)
    assign read_addr = (filter_en && inside_circle) ? ((IMG_WIDTH * source_y) + source_x) : {ADDR_WIDTH{1'b0}};
    
    //=========================================================================
    // Output: inside = magnified, outside = darkened original
    //=========================================================================
    always_comb begin
        if (filter_en) begin
            if (inside_circle) begin
                // Inside circle: use magnified pixel from frame buffer
                rgb565_out = frame_buffer_data;
            end else begin
                // Outside circle: simple difference - darken original input
                // Just make it darker to show difference (no frame buffer needed)
                logic [4:0] dark_r, dark_b;
                logic [5:0] dark_g;
                dark_r = rgb565_in[15:11] >> 1;  // R: divide by 2
                dark_g = rgb565_in[10:5] >> 1;   // G: divide by 2
                dark_b = rgb565_in[4:0] >> 1;    // B: divide by 2
                rgb565_out = {dark_r, dark_g, dark_b};
            end
        end else begin
            // Filter disabled: pass through
            rgb565_out = rgb565_in;
        end
    end

endmodule

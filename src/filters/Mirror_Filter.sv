`timescale 1ns / 1ps

//=============================================================================
// Module: Mirror_Filter
// Description: Horizontal mirror/flip effect
//              Creates left-right mirror reflection
//
// Features:
//   - Horizontal mirror (left-right flip)
//   - Uses frame buffer for coordinate transformation
//   - Simple and effective visual effect
//
// Effect: Creates mirror reflection - left becomes right, right becomes left
//=============================================================================

module Mirror_Filter #(
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
    // Horizontal mirror: flip X coordinate
    // Left side (x < IMG_WIDTH/2) → Right side (IMG_WIDTH - 1 - x)
    // Right side (x >= IMG_WIDTH/2) → Left side (IMG_WIDTH - 1 - x)
    //=========================================================================
    logic [9:0] mirror_x;
    
    // Calculate mirrored X coordinate
    assign mirror_x = IMG_WIDTH - 1 - x_local;
    
    // Calculate frame buffer read address for mirrored pixel
    assign read_addr = filter_en ? ((IMG_WIDTH * y_local) + mirror_x) : {ADDR_WIDTH{1'b0}};
    
    //=========================================================================
    // Output: use mirrored pixel from frame buffer
    //=========================================================================
    always_comb begin
        if (filter_en) begin
            // Use mirrored pixel from frame buffer
            rgb565_out = frame_buffer_data;
        end else begin
            rgb565_out = rgb565_in;
        end
    end

endmodule


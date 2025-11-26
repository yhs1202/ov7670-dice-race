`timescale 1ns / 1ps

//=============================================================================
// Module: ImgMemReader_ColorDetect
// Description: Enhanced image memory reader with integrated color detection
//              Reads from frame buffer and provides pixel stream to color detector
//
// Features:
//   - Reads QVGA (320x240) image from frame buffer
//   - Converts RGB565 to RGB888 for accurate color detection
//   - Provides synchronized pixel stream with coordinates
//   - Generates frame_start signal for color detector
//   - Integrates overlay for ROI visualization
//=============================================================================

module ImgMemReader_ColorDetect (
    input  logic        clk,
    input  logic        reset,
    
    // VGA timing inputs
    input  logic        DE,
    input  logic [9:0]  x_pixel,
    input  logic [9:0]  y_pixel,
    
    // Frame buffer interface
    output logic [16:0] addr,
    input  logic [15:0] imgData,  // RGB565 format
    
    // VGA output (4-bit per channel)
    output logic [3:0]  r_port,
    output logic [3:0]  g_port,
    output logic [3:0]  b_port,
    
    // Pixel stream for color detector (8-bit per channel)
    output logic        pixel_valid,
    output logic [9:0]  pixel_x,
    output logic [9:0]  pixel_y,
    output logic [7:0]  pixel_r8,
    output logic [7:0]  pixel_g8,
    output logic [7:0]  pixel_b8,
    
    // Frame synchronization
    output logic        frame_start
);

    //=========================================================================
    // Display enable and boundary check
    //=========================================================================
    logic img_display_en;
    assign img_display_en = DE && (x_pixel < 10'd320) && (y_pixel < 10'd240);
    
    //=========================================================================
    // Frame buffer address generation
    //=========================================================================
    assign addr = img_display_en ? (17'd320 * y_pixel + x_pixel) : 17'bz;
    
    //=========================================================================
    // RGB565 to RGB888 Conversion
    //=========================================================================
    // RGB565 format: [15:11]=R(5), [10:5]=G(6), [4:0]=B(5)
    // RGB888 format: [7:0]=R(8), [7:0]=G(8), [7:0]=B(8)
    
    logic [7:0] r8_full, g8_full, b8_full;
    logic [3:0] r4_vga, g4_vga, b4_vga;
    
    // Convert 5-bit R to 8-bit (replicate MSBs)
    assign r8_full = {imgData[15:11], imgData[15:13]};
    
    // Convert 6-bit G to 8-bit (replicate MSBs)
    assign g8_full = {imgData[10:5], imgData[10:9]};
    
    // Convert 5-bit B to 8-bit (replicate MSBs)
    assign b8_full = {imgData[4:0], imgData[4:2]};
    
    // Extract 4-bit for VGA (take upper 4 bits)
    assign r4_vga = imgData[15:12];
    assign g4_vga = imgData[10:7];
    assign b4_vga = imgData[4:1];
    
    //=========================================================================
    // Pipeline registers for timing
    //=========================================================================
    logic        pixel_valid_reg;
    logic [9:0]  pixel_x_reg;
    logic [9:0]  pixel_y_reg;
    logic [7:0]  pixel_r8_reg;
    logic [7:0]  pixel_g8_reg;
    logic [7:0]  pixel_b8_reg;
    logic [3:0]  r_port_reg;
    logic [3:0]  g_port_reg;
    logic [3:0]  b_port_reg;
    
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            pixel_valid_reg <= 1'b0;
            pixel_x_reg <= 10'd0;
            pixel_y_reg <= 10'd0;
            pixel_r8_reg <= 8'd0;
            pixel_g8_reg <= 8'd0;
            pixel_b8_reg <= 8'd0;
            r_port_reg <= 4'd0;
            g_port_reg <= 4'd0;
            b_port_reg <= 4'd0;
        end else begin
            pixel_valid_reg <= img_display_en;
            pixel_x_reg <= x_pixel;
            pixel_y_reg <= y_pixel;
            
            if (img_display_en) begin
                pixel_r8_reg <= r8_full;
                pixel_g8_reg <= g8_full;
                pixel_b8_reg <= b8_full;
                r_port_reg <= r4_vga;
                g_port_reg <= g4_vga;
                b_port_reg <= b4_vga;
            end else begin
                pixel_r8_reg <= 8'd0;
                pixel_g8_reg <= 8'd0;
                pixel_b8_reg <= 8'd0;
                r_port_reg <= 4'd0;
                g_port_reg <= 4'd0;
                b_port_reg <= 4'd0;
            end
        end
    end
    
    //=========================================================================
    // Frame start detection (vsync equivalent)
    //=========================================================================
    logic [9:0] prev_y_pixel;
    
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            prev_y_pixel <= 10'd0;
            frame_start <= 1'b0;
        end else begin
            prev_y_pixel <= y_pixel;
            // Detect transition from last line to first line
            frame_start <= (prev_y_pixel != 10'd0) && (y_pixel == 10'd0);
        end
    end
    
    //=========================================================================
    // Output assignments
    //=========================================================================
    assign pixel_valid = pixel_valid_reg;
    assign pixel_x = pixel_x_reg;
    assign pixel_y = pixel_y_reg;
    assign pixel_r8 = pixel_r8_reg;
    assign pixel_g8 = pixel_g8_reg;
    assign pixel_b8 = pixel_b8_reg;
    assign r_port = r_port_reg;
    assign g_port = g_port_reg;
    assign b_port = b_port_reg;
    
endmodule

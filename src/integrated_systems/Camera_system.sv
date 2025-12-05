`timescale 1ns / 1ps

module Camera_system #(
    parameter IMG_WIDTH  = 160,
    parameter IMG_HEIGHT = 120,
    parameter ADDR_WIDTH = $clog2(IMG_WIDTH * IMG_HEIGHT)
) (
    // Global signals
    input logic clk,
    input logic reset,

    // Camera 1 interface (Dice)
    input  logic [7:0] CAM1_data,
    input  logic       CAM1_href,
    input  logic       CAM1_pclk,
    input  logic       CAM1_vsync,

    output logic       CAM1_sioc,   // SCL, top module Camera output
    input  logic       CAM1_siod,   // SDA

    // Camera 2 interface (Face)
    input  logic [7:0] CAM2_data,
    input  logic       CAM2_href,
    input  logic       CAM2_pclk,
    input  logic       CAM2_vsync,

    output logic       CAM2_sioc,   // SCL, top module Camera output
    input  logic       CAM2_siod,   // SDA

    // Module outputs except Camera Control signals
    output logic        pclk,           // Pixel clock (25MHz) generated from system clock (to CAM1/2 xclk, Color_Detector, Display_Overlay, UI_Generator)
    output logic [11:0] dice_RGB_out,   // Dice Camera output, connected to Display_Overlay input
    output logic [15:0] CAM1_RGB_out,   // For Color Detector
    output logic [15:0] CAM2_RGB_out,   // Face Camera RGB565 output for filters
    output logic        DE,             // From VGA_Syncher, to ISP modules input (Internal Signal)
    output logic [9:0]  x_pixel,        // From VGA_Syncher, to ISP modules input (Internal Signal)
    output logic [9:0]  y_pixel,        // From VGA_Syncher, to ISP modules input (Internal Signal)
    output logic        h_sync,         // From VGA_Syncher, top module VGA output
    output logic        v_sync,         // From VGA_Syncher, top module VGA output
    
    // CAM2 Frame Buffer external interface for Img_Filter
    input  logic [ADDR_WIDTH-1:0] CAM2_ext_read_addr,  // External read address from Img_Filter
    input  logic                  CAM2_ext_read_en,    // External read enable from Img_Filter
    output logic [15:0]           CAM2_ext_read_data   // External read data to Img_Filter
);

    // RGB565 to RGB444 logic w/ dice_en and filter_en
    bit dice_en = x_pixel < 320 && y_pixel >= 240 && y_pixel < 480;
    bit filter_en = x_pixel >= 320 && y_pixel >= 240 && y_pixel < 480;

    assign dice_RGB_out   = dice_en ? {CAM1_RGB_out[15:12], CAM1_RGB_out[10:7], CAM1_RGB_out[4:1]} : 12'h0;
    // CAM2_RGB_out is already assigned from frame buffer, just output it

    ///////////////////////////// Clock /////////////////////////////

    pixel_clk_gen U_Pixel_Clk_Gen (
        .clk  (clk),
        .reset(reset),
        .pclk (pclk)
    );

    /////////////////////////// Input Path //////////////////////////
    logic                  CAM1_we;
    logic [ADDR_WIDTH-1:0] CAM1_wAddr;
    logic [          15:0] CAM1_wData;
    logic                  CAM2_we;
    logic [ADDR_WIDTH-1:0] CAM2_wAddr;
    logic [          15:0] CAM2_wData;

    OV7670_Controller #(
        .IMG_WIDTH (IMG_WIDTH),
        .IMG_HEIGHT(IMG_HEIGHT)
    ) U_CAM1_Controller (
        .clk  (clk),
        .reset(reset),
        .SCL  (CAM1_sioc),
        .SDA  (CAM1_siod),
        .pclk (CAM1_pclk),
        .href (CAM1_href),
        .vsync(CAM1_vsync),
        .data (CAM1_data),
        .we   (CAM1_we),
        .wAddr(CAM1_wAddr),
        .wData(CAM1_wData)
    );

    OV7670_Controller #(
        .IMG_WIDTH (IMG_WIDTH),
        .IMG_HEIGHT(IMG_HEIGHT)
    ) U_CAM2_Controller (
        .clk  (clk),
        .reset(reset),
        .SCL  (CAM2_sioc),
        .SDA  (CAM2_siod),
        .pclk (CAM2_pclk),
        .href (CAM2_href),
        .vsync(CAM2_vsync),
        .data (CAM2_data),
        .we   (CAM2_we),
        .wAddr(CAM2_wAddr),
        .wData(CAM2_wData)
    );

    //////////////////////////// Storage ////////////////////////////
    logic [ADDR_WIDTH-1:0] vga_read_addr;
    logic [ADDR_WIDTH-1:0] CAM2_read_addr_muxed;  // Muxed read address for CAM2 frame buffer
    logic                  CAM2_read_en_muxed;    // Muxed read enable for CAM2 frame buffer

    frame_buffer #(
        .IMG_WIDTH (IMG_WIDTH),
        .IMG_HEIGHT(IMG_HEIGHT)
    ) U_CAM1_Frame_Buffer (
        .wclk (CAM1_pclk),
        .we   (CAM1_we),
        .wAddr(CAM1_wAddr),
        .wData(CAM1_wData),
        .rclk (pclk),
        .oe   (1'b1),
        .rAddr(vga_read_addr),
        .rData(CAM1_RGB_out)
    );

    // Address multiplexing: external read has priority when enabled
    assign CAM2_read_addr_muxed = CAM2_ext_read_en ? CAM2_ext_read_addr : vga_read_addr;
    assign CAM2_read_en_muxed = CAM2_ext_read_en ? 1'b1 : 1'b1;  // Always enabled

    frame_buffer #(
        .IMG_WIDTH (IMG_WIDTH),
        .IMG_HEIGHT(IMG_HEIGHT)
    ) U_CAM2_Frame_Buffer (
        .wclk (CAM2_pclk),
        .we   (CAM2_we),
        .wAddr(CAM2_wAddr),
        .wData(CAM2_wData),
        .rclk (pclk),
        .oe   (CAM2_read_en_muxed),
        .rAddr(CAM2_read_addr_muxed),
        .rData(CAM2_RGB_out)
    );
    
    // External read data output (same as CAM2_RGB_out when external read is enabled)
    assign CAM2_ext_read_data = CAM2_RGB_out;
    /////////////////////////////////////////////////////////////////

    ////////////////////////// Output Path //////////////////////////

    VGA_Syncher U_VGA_Syncher (
        .clk    (pclk),
        .reset  (reset),
        .h_sync (h_sync),
        .v_sync (v_sync),
        .DE     (DE),
        .x_pixel(x_pixel),
        .y_pixel(y_pixel)
    );

    ImgMemReader #(
        .IMG_WIDTH (IMG_WIDTH),
        .IMG_HEIGHT(IMG_HEIGHT)
    ) U_ImgMemReader (
        .x_pixel(x_pixel),
        .y_pixel(y_pixel),
        .addr   (vga_read_addr)
    );

endmodule

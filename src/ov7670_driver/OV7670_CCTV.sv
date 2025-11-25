`timescale 1ns / 1ps

module OV7670_CCTV (
    input  logic       clk,
    input  logic       reset,
    // OV76710 side
    output logic       xclk,
    input  logic       pclk,
    input  logic       href,
    input  logic       vsync,
    input  logic [7:0] data,
    // vga port
    output logic       h_sync,
    output logic       v_sync,
    output logic [3:0] r_port,
    output logic [3:0] g_port,
    output logic [3:0] b_port,
    // I2C
    output tri         SCL,
    inout  tri         SDA
);
    logic        sys_clk;
    logic        DE;
    logic [ 9:0] x_pixel;
    logic [ 9:0] y_pixel;
    logic [16:0] rAddr;
    logic [15:0] rData;
    logic        we;
    logic [16:0] wAddr;
    logic [15:0] wData;

    assign xclk = sys_clk;

    SCCB_Interface U_SCCB (
        .clk  (clk),
        .reset(reset),
        .SCL  (SCL),
        .SDA  (SDA)
    );

    pixel_clk_gen U_PXL_CLK_GEN (
        .clk  (clk),
        .reset(reset),
        .pclk (sys_clk)
    );

    VGA_Syncher U_VGA_Syncher (
        .clk    (sys_clk),
        .reset  (reset),
        .h_sync (h_sync),
        .v_sync (v_sync),
        .DE     (DE),
        .x_pixel(x_pixel),
        .y_pixel(y_pixel)
    );

    ImgMemReader U_Img_Reader (
        .DE     (DE),
        .x_pixel(x_pixel),
        .y_pixel(y_pixel),
        .addr   (rAddr),
        .imgData(rData),
        .r_port (r_port),
        .g_port (g_port),
        .b_port (b_port)
    );

    frame_buffer U_Frame_Buffer (
        .wclk (pclk),
        .we   (we),
        .wAddr(wAddr),
        .wData(wData),
        .rclk (sys_clk),
        .oe   (1'b1),
        .rAddr(rAddr),
        .rData(rData)
    );

    OV7670_Mem_Controller U_OV7670_Mem_Controller (
        .clk  (pclk),
        .reset(reset),
        .href (href),
        .vsync(vsync),
        .data (data),
        .we   (we),
        .wAddr(wAddr),
        .wData(wData)
    );
endmodule

`timescale 1ns / 1ps

module OV7670_Controller #(
    parameter IMG_WIDTH  = 160,
    parameter IMG_HEIGHT = 120,
    parameter ADDR_WIDTH = $clog2(IMG_WIDTH * IMG_HEIGHT)
) (
    input  logic                  clk,
    input  logic                  reset,
    output tri                    SCL,
    inout  tri                    SDA,
    input  logic                  pclk,
    input  logic                  href,
    input  logic                  vsync,
    input  logic [           7:0] data,
    output logic                  we,
    output logic [ADDR_WIDTH-1:0] wAddr,
    output logic [          15:0] wData
);

    SCCB_Interface U_SCCB_Intf (
        .clk  (clk),
        .reset(reset),
        .SCL  (SCL),
        .SDA  (SDA)
    );

    OV7670_Mem_Controller #(
        .IMG_WIDTH (IMG_WIDTH),
        .IMG_HEIGHT(IMG_HEIGHT)
    ) U_OV7670_Mem_Ctrl (
        .pclk (pclk),
        .reset(reset),
        .href (href),
        .vsync(vsync),
        .data (data),
        .we   (we),
        .wAddr(wAddr),
        .wData(wData)
    );

endmodule

`timescale 1ns / 1ps

module OV7670_Mem_Controller #(
    parameter IMG_WIDTH  = 160,
    parameter IMG_HEIGHT = 120,
    parameter ADDR_WIDTH = $clog2(IMG_WIDTH * IMG_HEIGHT)
) (
    input  logic                  pclk,
    input  logic                  reset,
    // OV7670 side
    input  logic                  href,
    input  logic                  vsync,
    input  logic [           7:0] data,
    // memory side
    output logic                  we,
    output logic [ADDR_WIDTH-1:0] wAddr,
    output logic [          15:0] wData
);
    logic [15:0] pixelData;
    logic        byte_toggle;

    assign wData = pixelData;

    always_ff @(posedge pclk) begin
        if (reset) begin
            wAddr       <= 0;
            we          <= 0;
            pixelData   <= 0;
            byte_toggle <= 0;
        end else begin
            we <= 0;
            if (we) wAddr <= wAddr + 1;
            if (vsync) begin
                wAddr       <= 0;
                byte_toggle <= 0;
                we          <= 0;
            end else if (href) begin
                if (byte_toggle == 1'b0) begin
                    pixelData[15:8] <= data;
                    byte_toggle     <= 1'b1;
                end else begin
                    pixelData[7:0] <= data;
                    byte_toggle    <= 1'b0;
                    we             <= 1'b1;
                end
            end
        end
    end
endmodule

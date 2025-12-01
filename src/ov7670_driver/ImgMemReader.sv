`timescale 1ns / 1ps

module ImgMemReader #(
    parameter IMG_WIDTH  = 160,
    parameter IMG_HEIGHT = 120,
    parameter ADDR_WIDTH = $clog2(IMG_WIDTH * IMG_HEIGHT)
) (
    input  logic [           9:0] x_pixel,
    input  logic [           9:0] y_pixel,
    output logic [ADDR_WIDTH-1:0] addr
);

    logic img_display_en;
    assign img_display_en = (y_pixel >= 240) && (y_pixel < 480);

    logic [9:0] x_pixel_offset;
    logic [9:0] y_pixel_offset;

    assign y_pixel_offset = y_pixel - 240;
    assign x_pixel_offset = (x_pixel >= 320) ? (x_pixel - 320) : x_pixel;

    assign addr = img_display_en ? (IMG_WIDTH * y_pixel_offset[9:1] + x_pixel_offset[9:1]) : {ADDR_WIDTH{1'b0}};

endmodule

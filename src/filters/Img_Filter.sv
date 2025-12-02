`timescale 1ns / 1ps

module Img_Filter #(
    parameter IMG_WIDTH  = 160,
    parameter IMG_HEIGHT = 120
) (
    input  logic       clk,
    input  logic       reset,
    // 000: Pass, 001: Mosaic, 010: ASCII, 011~111: Reserved
    input  logic [2:0] filter_sel,
    // VGA Signals
    input  logic       DE,
    input  logic [9:0] x_pixel,
    input  logic [9:0] y_pixel,
    // Pixel Input
    input  logic [3:0] r_in,
    input  logic [3:0] g_in,
    input  logic [3:0] b_in,
    // Pixel Output
    output logic [3:0] r_out,
    output logic [3:0] g_out,
    output logic [3:0] b_out
);

    logic [9:0] local_x;
    logic [9:0] local_y;
    logic       filter_en;

    always_comb begin
        if (x_pixel >= 320 && y_pixel >= 240) begin
            local_x   = (x_pixel - 320) >> 1;
            local_y   = (y_pixel - 240) >> 1;
            filter_en = DE;
        end else begin
            local_x   = 0;
            local_y   = 0;
            filter_en = 1'b0;
        end
    end

    //=========================================================================
    // Mosaic Filter Instance
    //=========================================================================
    logic [3:0] mosaic_r, mosaic_g, mosaic_b;

    Mosaic_Filter #(
        .BLOCK_SIZE(8),
        .IMG_WIDTH (IMG_WIDTH),
        .IMG_HEIGHT(IMG_HEIGHT)
    ) U_Mosaic_Filter (
        .clk      (clk),
        .reset    (reset),
        .x_local  (local_x),
        .y_local  (local_y),
        .filter_en(filter_en),
        .r_in     (r_in),
        .g_in     (g_in),
        .b_in     (b_in),
        .r_out    (mosaic_r),
        .g_out    (mosaic_g),
        .b_out    (mosaic_b)
    );

    //=========================================================================
    // ASCII Filter Instance
    //=========================================================================
    logic [3:0] ascii_r, ascii_g, ascii_b;

    ASCII_Filter #(
        .CHAR_SIZE (8),
        .IMG_WIDTH (IMG_WIDTH),
        .IMG_HEIGHT(IMG_HEIGHT)
    ) U_ASCII_Filter (
        .clk      (clk),
        .reset    (reset),
        .x_local  (local_x),
        .y_local  (local_y),
        .filter_en(filter_en),
        .r_in     (r_in),
        .g_in     (g_in),
        .b_in     (b_in),
        .r_out    (ascii_r),
        .g_out    (ascii_g),
        .b_out    (ascii_b)
    );

    //=========================================================================
    // Filter Selection MUX
    //=========================================================================
    always_comb begin
        if (!filter_en) begin
            r_out = r_in;
            g_out = g_in;
            b_out = b_in;
        end else begin
            case (filter_sel)
                // [Mode 0] No Filter (Bypass)
                3'b000: begin
                    r_out = r_in; g_out = g_in; b_out = b_in;
                end
                // [Mode 1] Mosaic Filter
                3'b001: begin
                    r_out = mosaic_r; g_out = mosaic_g; b_out = mosaic_b;
                end
                // [Mode 2] ASCII Filter (Matrix Style)
                3'b010: begin
                    r_out = ascii_r; g_out = ascii_g; b_out = ascii_b;
                end
                // [Mode 3] Reserved
                3'b011: begin
                    r_out = r_in; g_out = g_in; b_out = b_in;
                end
                // [Mode 4] Reserved
                3'b100: begin
                    r_out = r_in; g_out = g_in; b_out = b_in;
                end
                // Default
                default: begin 
                    r_out = r_in; g_out = g_in; b_out = b_in;
                end
            endcase
        end
    end

endmodule

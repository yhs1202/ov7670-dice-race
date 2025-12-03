`timescale 1ns / 1ps

module Mosaic_Filter #(
    parameter BLOCK_SIZE = 8,
    parameter IMG_WIDTH  = 160,
    parameter IMG_HEIGHT = 120
) (
    input  logic       clk,
    input  logic       reset,
    input  logic [9:0] x_local,
    input  logic [9:0] y_local,
    input  logic       filter_en,
    input  logic [15:0] rgb565_in,  // RGB565: [15:11]=R, [10:5]=G, [4:0]=B
    output logic [15:0] rgb565_out
);

    logic [9:0] block_x;
    logic [9:0] block_y;
    assign block_x = x_local / BLOCK_SIZE;
    assign block_y = y_local / BLOCK_SIZE;

    logic is_sample_point;
    assign is_sample_point = ((x_local % BLOCK_SIZE) == 0) && ((y_local % BLOCK_SIZE) == 0);

    localparam BLOCKS_X = IMG_WIDTH / BLOCK_SIZE;
    localparam BLOCKS_Y = IMG_HEIGHT / BLOCK_SIZE;
    localparam ADDR_W = $clog2(BLOCKS_X * BLOCKS_Y);

    logic [ADDR_W-1:0] mem_addr;
    assign mem_addr = (block_y * BLOCKS_X) + block_x;

    logic [15:0] save_rgb565[0:(BLOCKS_X * BLOCKS_Y)-1];

    always_ff @(posedge clk) begin
        if (filter_en && is_sample_point) begin
            save_rgb565[mem_addr] <= rgb565_in;
        end
    end

    assign rgb565_out = (filter_en) ? ((is_sample_point) ? rgb565_in : save_rgb565[mem_addr]) : rgb565_in;

endmodule

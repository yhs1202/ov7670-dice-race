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
    input  logic [3:0] r_in,
    input  logic [3:0] g_in,
    input  logic [3:0] b_in,
    output logic [3:0] r_out,
    output logic [3:0] g_out,
    output logic [3:0] b_out
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

    logic [3:0] save_r[0:(BLOCKS_X * BLOCKS_Y)-1];
    logic [3:0] save_g[0:(BLOCKS_X * BLOCKS_Y)-1];
    logic [3:0] save_b[0:(BLOCKS_X * BLOCKS_Y)-1];

    always_ff @(posedge clk) begin
        if (filter_en && is_sample_point) begin
            save_r[mem_addr] <= r_in;
            save_g[mem_addr] <= g_in;
            save_b[mem_addr] <= b_in;
        end
    end

    assign r_out = (filter_en) ? ((is_sample_point) ? r_in : save_r[mem_addr]) : r_in;
    assign g_out = (filter_en) ? ((is_sample_point) ? g_in : save_g[mem_addr]) : g_in;
    assign b_out = (filter_en) ? ((is_sample_point) ? b_in : save_b[mem_addr]) : b_in;

endmodule

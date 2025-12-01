`timescale 1ns / 1ps

module frame_buffer #(
    parameter IMG_WIDTH  = 160,
    parameter IMG_HEIGHT = 120,
    parameter ADDR_WIDTH = $clog2(IMG_WIDTH * IMG_HEIGHT)
) (
    // write side
    input  logic                  wclk,
    input  logic                  we,
    input  logic [ADDR_WIDTH-1:0] wAddr,
    input  logic [          15:0] wData,
    // read side
    input  logic                  rclk,
    input  logic                  oe,
    input  logic [ADDR_WIDTH-1:0] rAddr,
    output logic [          15:0] rData
);
    localparam MEM_DEPTH = IMG_WIDTH * IMG_HEIGHT;

    logic [15:0] mem[0:MEM_DEPTH-1];

    // write side
    always_ff @(posedge wclk) begin
        if (we) mem[wAddr] <= wData;
    end

    // read side
    always_ff @(posedge rclk) begin
        if (oe) rData <= mem[rAddr];
    end

endmodule

`timescale 1ns / 1ps

module Img_Filter #(
    parameter IMG_WIDTH  = 160,
    parameter IMG_HEIGHT = 120,
    parameter ADDR_WIDTH = $clog2(IMG_WIDTH * IMG_HEIGHT)
) (
    input  logic        clk,
    input  logic        reset,
    input  logic [ 3:0] filter_sel,  // same with event_flag, Filter Selection
    // VGA Signals
    input  logic        DE,
    input  logic [ 9:0] x_pixel,
    input  logic [ 9:0] y_pixel,
    // Pixel Input (RGB565: 16-bit)
    input  logic [15:0] rgb565_in,
    // Pixel Output (RGB565: 16-bit)
    output logic [15:0] rgb565_out
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
    // Frame Buffer (shared by filters that need random access)
    //=========================================================================
    logic [ADDR_WIDTH-1:0] fb_write_addr;
    logic [ADDR_WIDTH-1:0] fb_read_addr;
    logic [ADDR_WIDTH-1:0] fb_read_addr_muxed;  // Muxed read address
    logic [15:0] fb_write_data;  // RGB565: 16 bits
    logic [15:0] fb_read_data;  // RGB565: 16 bits
    logic fb_we;
    logic fb_oe;

    // Calculate frame buffer address
    assign fb_write_addr = (IMG_WIDTH * local_y) + local_x;
    assign fb_read_addr  = (IMG_WIDTH * local_y) + local_x;

    // Direct RGB565 storage
    assign fb_write_data = rgb565_in;

    // Frame buffer instance (RGB565 format - reuse existing frame_buffer)
    frame_buffer #(
        .IMG_WIDTH (IMG_WIDTH),
        .IMG_HEIGHT(IMG_HEIGHT),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) U_Filter_Frame_Buffer (
        .wclk (clk),
        .we   (fb_we),
        .wAddr(fb_write_addr),
        .wData(fb_write_data),
        .rclk (clk),
        .oe   (fb_oe),
        .rAddr(fb_read_addr_muxed),
        .rData(fb_read_data)
    );

    //=========================================================================
    // ASCII Filter Instance
    //=========================================================================
    logic [15:0] ascii_rgb565;

    ASCII_Filter #(
        .CHAR_SIZE (8),
        .IMG_WIDTH (IMG_WIDTH),
        .IMG_HEIGHT(IMG_HEIGHT)
    ) U_ASCII_Filter (
        .clk       (clk),
        .reset     (reset),
        .x_local   (local_x),
        .y_local   (local_y),
        .filter_en (filter_en),
        .rgb565_in (rgb565_in),
        .rgb565_out(ascii_rgb565)
    );

    //=========================================================================
    // Mosaic Filter Instance
    //=========================================================================
    logic [15:0] mosaic_rgb565;

    Mosaic_Filter #(
        .BLOCK_SIZE(8),
        .IMG_WIDTH (IMG_WIDTH),
        .IMG_HEIGHT(IMG_HEIGHT)
    ) U_Mosaic_Filter (
        .clk       (clk),
        .reset     (reset),
        .x_local   (local_x),
        .y_local   (local_y),
        .filter_en (filter_en),
        .rgb565_in (rgb565_in),
        .rgb565_out(mosaic_rgb565)
    );

    //=========================================================================
    // Invert Filter Instance
    //=========================================================================
    logic [15:0] invert_rgb565;

    Invert_Filter #(
        .IMG_WIDTH (IMG_WIDTH),
        .IMG_HEIGHT(IMG_HEIGHT)
    ) U_Invert_Filter (
        .clk       (clk),
        .reset     (reset),
        .x_local   (local_x),
        .y_local   (local_y),
        .filter_en (filter_en),
        .rgb565_in (rgb565_in),
        .rgb565_out(invert_rgb565)
    );

    //=========================================================================
    // Kaleidoscope Filter Instance
    //=========================================================================
    logic kaleidoscope_selected;
    assign kaleidoscope_selected = (filter_sel == 4'd8);

    logic [ADDR_WIDTH-1:0] kaleido_read_addr;
    logic [15:0] kaleidoscope_rgb565;

    Kaleidoscope_Filter #(
        .IMG_WIDTH (IMG_WIDTH),
        .IMG_HEIGHT(IMG_HEIGHT),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) U_Kaleidoscope_Filter (
        .clk              (clk),
        .reset            (reset),
        .x_local          (local_x),
        .y_local          (local_y),
        .filter_en        (filter_en),
        .rgb565_in        (rgb565_in),
        .read_addr        (kaleido_read_addr),
        .frame_buffer_data(fb_read_data),
        .rgb565_out       (kaleidoscope_rgb565)
    );

    // Mux frame buffer read address: priority order
    // If multiple filters use frame buffer, priority: Fisheye > Mirror > Kaleidoscope
    assign fb_read_addr_muxed = kaleidoscope_selected ? kaleido_read_addr : 
                                fb_read_addr;

    // Update frame buffer write/read enable to include all filters that need it
    assign fb_we = filter_en && kaleidoscope_selected;
    assign fb_oe = filter_en && kaleidoscope_selected;

    //=========================================================================
    // Filter Selection MUX
    //=========================================================================
    always_comb begin
        if (!filter_en) begin
            rgb565_out = rgb565_in;
        end else begin
            case (filter_sel)
                4'd2: begin  // ASCII Filter
                    rgb565_out = ascii_rgb565;
                end
                4'd4: begin  // Mosaic Filter
                    rgb565_out = mosaic_rgb565;
                end
                4'd6: begin  // Invert Filter
                    rgb565_out = invert_rgb565;
                end
                4'd8: begin  // Kaleidoscope Filter
                    rgb565_out = kaleidoscope_rgb565;
                end
                // Default
                default: begin
                    rgb565_out = rgb565_in;
                end
            endcase
        end
    end

endmodule

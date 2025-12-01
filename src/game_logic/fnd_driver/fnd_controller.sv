`timescale 1ns / 1ps
module fnd_controller(
    input clk, rst,
    input [$clog2(10000)-1:0] count_reg,
    output [3:0] fnd_com,
    output [7:0] fnd_data
    );

    wire w_clk_div;
    wire [3:0] w_bcd;
    wire [1:0] w_sel;

    wire [3:0] w_digit_1, w_digit_10, w_digit_100, w_digit_1000;

    clk_div #(
        .DIV_VALUE(10_000)
    ) U_CLK_1KHZ (
        .clk (clk),
        .rst (rst),

        .clk_out (w_clk_div)
    );

    counter_n #(
        .N(4)
    ) U_COUNTER_4 (
        .clk (w_clk_div),
        .rst (rst),

        .count_reg (w_sel)
    );

    decoder_2x4 U_DECODER_2X4 (
        .in (w_sel),
        .out (fnd_com)
    );

    digit_spliter U_DIGIT_SPLITER (
        .count (count_reg),

        .digit_1 (w_digit_1),
        .digit_10 (w_digit_10),
        .digit_100 (w_digit_100),
        .digit_1000 (w_digit_1000)
    );

    mux_4x1 U_MUX_4X1 (  
    .digit_1 (w_digit_1),
    .digit_10 (w_digit_10),
    .digit_100 (w_digit_100),
    .digit_1000 (w_digit_1000),
    .sel (w_sel),

    .bcd (w_bcd)
    );

    bcd_decoder U_BCD_DECODER (
        .bcd_data (w_bcd),

        .fnd_data (fnd_data)
    );

endmodule
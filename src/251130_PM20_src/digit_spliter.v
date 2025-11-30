`timescale 1ns / 1ps
module digit_spliter (
    input [13:0] count,
    output [3:0] digit_1,
    output [3:0] digit_10,
    output [3:0] digit_100,
    output [3:0] digit_1000
);
    assign digit_1 = count % 10;
    assign digit_10 = count / 10 % 10;
    assign digit_100 = count / 100 % 10;
    assign digit_1000 = count / 1000 % 10;
    
endmodule
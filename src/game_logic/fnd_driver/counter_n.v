`timescale 1ns / 1ps
module counter_n #(
    parameter N = 10000
)(
    input clk, rst,
    output reg [$clog2(N)-1:0] count_reg
    );

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            count_reg <= 0;
        end
        else begin
            if (count_reg == N-1) begin
                count_reg <= 0;
            end else begin
                count_reg <= count_reg + 1;
            end
        end
    end
endmodule

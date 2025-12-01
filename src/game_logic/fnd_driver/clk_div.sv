`timescale 1ns / 1ps
module clk_div #(
    // Adjust this parameter to change the division factor
    // "10" -> 1ns*10 = 10ns -> 100MHz/10 = 10MHz -> 10_000_000 -> 10Hz
    parameter DIV_VALUE = 10_000_000
)(
    input clk, rst,
    output reg clk_out
    );

    // Calculate the width of the counter based on DIV_VALUE
    localparam WIDTH = $clog2(DIV_VALUE);
    reg [WIDTH-1:0] r_count;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            r_count <= 0;
            clk_out <= 0;
        end 
        else begin
            // counter
            if (r_count == DIV_VALUE - 1) begin
                r_count <= 0;
            end else begin
                r_count <= r_count + 1;
            end
            // clk_out w/ 50% duty cycle
            // r_count : 01234 -> 1, 56789 -> 0 (for DIV_VALUE = 10)
            if (r_count == DIV_VALUE/2 - 1) begin
                clk_out <= 1;
            end else if (r_count == DIV_VALUE - 1) begin
                clk_out <= 0;
            end else begin
                clk_out <= clk_out;
            end
        end
    end

endmodule

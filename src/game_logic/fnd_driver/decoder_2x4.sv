`timescale 1ns / 1ps
module decoder_2x4(
    input [1:0] in,
    output reg [3:0] out
    );

    always @(*) begin
        case (in)
            2'b00: out = 4'b1110;   // 1st digit on
            2'b01: out = 4'b1101;   // 2nd digit on
            2'b10: out = 4'b1011;   // 3rd digit on
            2'b11: out = 4'b0111;   // 4th digit on
            default: out = 4'b1111; // off
        endcase
    end
endmodule

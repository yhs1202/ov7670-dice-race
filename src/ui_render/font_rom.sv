`timescale 1ns/1ps

// 8x8 Pixel Font ROM
// Supports ASCII characters for retro game display
module font_rom (
    input  logic [7:0] char_code,   // ASCII character code
    input  logic [2:0] row,         // Row within character (0-7)
    output logic [7:0] font_line    // 8 pixels for this row
);

    always_comb begin
        font_line = 8'h00;  // Default: empty
        
        case (char_code)
            // ===== Special Characters =====
            // Arrow/Cursor (0x10)
            8'h10: case (row)
                3'd0: font_line = 8'b00100000;
                3'd1: font_line = 8'b00110000;
                3'd2: font_line = 8'b00111000;
                3'd3: font_line = 8'b00111100;
                3'd4: font_line = 8'b00111000;
                3'd5: font_line = 8'b00110000;
                3'd6: font_line = 8'b00100000;
                3'd7: font_line = 8'b00000000;
            endcase
            
            // Space (0x20)
            8'h20: font_line = 8'h00;
            
            // ! (0x21)
            8'h21: case (row)
                3'd0: font_line = 8'b00011000;
                3'd1: font_line = 8'b00011000;
                3'd2: font_line = 8'b00011000;
                3'd3: font_line = 8'b00011000;
                3'd4: font_line = 8'b00011000;
                3'd5: font_line = 8'b00000000;
                3'd6: font_line = 8'b00011000;
                3'd7: font_line = 8'b00000000;
            endcase
            
            // - (0x2D)
            8'h2D: case (row)
                3'd0: font_line = 8'b00000000;
                3'd1: font_line = 8'b00000000;
                3'd2: font_line = 8'b00000000;
                3'd3: font_line = 8'b01111110;
                3'd4: font_line = 8'b00000000;
                3'd5: font_line = 8'b00000000;
                3'd6: font_line = 8'b00000000;
                3'd7: font_line = 8'b00000000;
            endcase
            
            // ===== Numbers 0-9 =====
            // 0
            8'h30: case (row)
                3'd0: font_line = 8'b00111100;
                3'd1: font_line = 8'b01100110;
                3'd2: font_line = 8'b01101110;
                3'd3: font_line = 8'b01110110;
                3'd4: font_line = 8'b01100110;
                3'd5: font_line = 8'b01100110;
                3'd6: font_line = 8'b00111100;
                3'd7: font_line = 8'b00000000;
            endcase
            
            // 1
            8'h31: case (row)
                3'd0: font_line = 8'b00011000;
                3'd1: font_line = 8'b00111000;
                3'd2: font_line = 8'b00011000;
                3'd3: font_line = 8'b00011000;
                3'd4: font_line = 8'b00011000;
                3'd5: font_line = 8'b00011000;
                3'd6: font_line = 8'b01111110;
                3'd7: font_line = 8'b00000000;
            endcase
            
            // 2
            8'h32: case (row)
                3'd0: font_line = 8'b00111100;
                3'd1: font_line = 8'b01100110;
                3'd2: font_line = 8'b00000110;
                3'd3: font_line = 8'b00011100;
                3'd4: font_line = 8'b00110000;
                3'd5: font_line = 8'b01100000;
                3'd6: font_line = 8'b01111110;
                3'd7: font_line = 8'b00000000;
            endcase
            
            // 3
            8'h33: case (row)
                3'd0: font_line = 8'b00111100;
                3'd1: font_line = 8'b01100110;
                3'd2: font_line = 8'b00000110;
                3'd3: font_line = 8'b00011100;
                3'd4: font_line = 8'b00000110;
                3'd5: font_line = 8'b01100110;
                3'd6: font_line = 8'b00111100;
                3'd7: font_line = 8'b00000000;
            endcase
            
            // 4
            8'h34: case (row)
                3'd0: font_line = 8'b00001100;
                3'd1: font_line = 8'b00011100;
                3'd2: font_line = 8'b00101100;
                3'd3: font_line = 8'b01001100;
                3'd4: font_line = 8'b01111110;
                3'd5: font_line = 8'b00001100;
                3'd6: font_line = 8'b00001100;
                3'd7: font_line = 8'b00000000;
            endcase
            
            // 5
            8'h35: case (row)
                3'd0: font_line = 8'b01111110;
                3'd1: font_line = 8'b01100000;
                3'd2: font_line = 8'b01111100;
                3'd3: font_line = 8'b00000110;
                3'd4: font_line = 8'b00000110;
                3'd5: font_line = 8'b01100110;
                3'd6: font_line = 8'b00111100;
                3'd7: font_line = 8'b00000000;
            endcase
            
            // 6
            8'h36: case (row)
                3'd0: font_line = 8'b00111100;
                3'd1: font_line = 8'b01100000;
                3'd2: font_line = 8'b01111100;
                3'd3: font_line = 8'b01100110;
                3'd4: font_line = 8'b01100110;
                3'd5: font_line = 8'b01100110;
                3'd6: font_line = 8'b00111100;
                3'd7: font_line = 8'b00000000;
            endcase
            
            // 7
            8'h37: case (row)
                3'd0: font_line = 8'b01111110;
                3'd1: font_line = 8'b00000110;
                3'd2: font_line = 8'b00001100;
                3'd3: font_line = 8'b00011000;
                3'd4: font_line = 8'b00110000;
                3'd5: font_line = 8'b00110000;
                3'd6: font_line = 8'b00110000;
                3'd7: font_line = 8'b00000000;
            endcase
            
            // 8
            8'h38: case (row)
                3'd0: font_line = 8'b00111100;
                3'd1: font_line = 8'b01100110;
                3'd2: font_line = 8'b01100110;
                3'd3: font_line = 8'b00111100;
                3'd4: font_line = 8'b01100110;
                3'd5: font_line = 8'b01100110;
                3'd6: font_line = 8'b00111100;
                3'd7: font_line = 8'b00000000;
            endcase
            
            // 9
            8'h39: case (row)
                3'd0: font_line = 8'b00111100;
                3'd1: font_line = 8'b01100110;
                3'd2: font_line = 8'b01100110;
                3'd3: font_line = 8'b00111110;
                3'd4: font_line = 8'b00000110;
                3'd5: font_line = 8'b00001100;
                3'd6: font_line = 8'b00111000;
                3'd7: font_line = 8'b00000000;
            endcase
            
            // ===== Uppercase Letters A-Z =====
            // A
            8'h41: case (row)
                3'd0: font_line = 8'b00011000;
                3'd1: font_line = 8'b00111100;
                3'd2: font_line = 8'b01100110;
                3'd3: font_line = 8'b01100110;
                3'd4: font_line = 8'b01111110;
                3'd5: font_line = 8'b01100110;
                3'd6: font_line = 8'b01100110;
                3'd7: font_line = 8'b00000000;
            endcase
            
            // B
            8'h42: case (row)
                3'd0: font_line = 8'b01111100;
                3'd1: font_line = 8'b01100110;
                3'd2: font_line = 8'b01100110;
                3'd3: font_line = 8'b01111100;
                3'd4: font_line = 8'b01100110;
                3'd5: font_line = 8'b01100110;
                3'd6: font_line = 8'b01111100;
                3'd7: font_line = 8'b00000000;
            endcase
            
            // C
            8'h43: case (row)
                3'd0: font_line = 8'b00111100;
                3'd1: font_line = 8'b01100110;
                3'd2: font_line = 8'b01100000;
                3'd3: font_line = 8'b01100000;
                3'd4: font_line = 8'b01100000;
                3'd5: font_line = 8'b01100110;
                3'd6: font_line = 8'b00111100;
                3'd7: font_line = 8'b00000000;
            endcase
            
            // D
            8'h44: case (row)
                3'd0: font_line = 8'b01111000;
                3'd1: font_line = 8'b01101100;
                3'd2: font_line = 8'b01100110;
                3'd3: font_line = 8'b01100110;
                3'd4: font_line = 8'b01100110;
                3'd5: font_line = 8'b01101100;
                3'd6: font_line = 8'b01111000;
                3'd7: font_line = 8'b00000000;
            endcase
            
            // E
            8'h45: case (row)
                3'd0: font_line = 8'b01111110;
                3'd1: font_line = 8'b01100000;
                3'd2: font_line = 8'b01100000;
                3'd3: font_line = 8'b01111100;
                3'd4: font_line = 8'b01100000;
                3'd5: font_line = 8'b01100000;
                3'd6: font_line = 8'b01111110;
                3'd7: font_line = 8'b00000000;
            endcase
            
            // F
            8'h46: case (row)
                3'd0: font_line = 8'b01111110;
                3'd1: font_line = 8'b01100000;
                3'd2: font_line = 8'b01100000;
                3'd3: font_line = 8'b01111100;
                3'd4: font_line = 8'b01100000;
                3'd5: font_line = 8'b01100000;
                3'd6: font_line = 8'b01100000;
                3'd7: font_line = 8'b00000000;
            endcase
            
            // G
            8'h47: case (row)
                3'd0: font_line = 8'b00111100;
                3'd1: font_line = 8'b01100110;
                3'd2: font_line = 8'b01100000;
                3'd3: font_line = 8'b01101110;
                3'd4: font_line = 8'b01100110;
                3'd5: font_line = 8'b01100110;
                3'd6: font_line = 8'b00111110;
                3'd7: font_line = 8'b00000000;
            endcase
            
            // H
            8'h48: case (row)
                3'd0: font_line = 8'b01100110;
                3'd1: font_line = 8'b01100110;
                3'd2: font_line = 8'b01100110;
                3'd3: font_line = 8'b01111110;
                3'd4: font_line = 8'b01100110;
                3'd5: font_line = 8'b01100110;
                3'd6: font_line = 8'b01100110;
                3'd7: font_line = 8'b00000000;
            endcase
            
            // I
            8'h49: case (row)
                3'd0: font_line = 8'b01111110;
                3'd1: font_line = 8'b00011000;
                3'd2: font_line = 8'b00011000;
                3'd3: font_line = 8'b00011000;
                3'd4: font_line = 8'b00011000;
                3'd5: font_line = 8'b00011000;
                3'd6: font_line = 8'b01111110;
                3'd7: font_line = 8'b00000000;
            endcase
            
            // J
            8'h4A: case (row)
                3'd0: font_line = 8'b00011110;
                3'd1: font_line = 8'b00000110;
                3'd2: font_line = 8'b00000110;
                3'd3: font_line = 8'b00000110;
                3'd4: font_line = 8'b01100110;
                3'd5: font_line = 8'b01100110;
                3'd6: font_line = 8'b00111100;
                3'd7: font_line = 8'b00000000;
            endcase
            
            // K
            8'h4B: case (row)
                3'd0: font_line = 8'b01100110;
                3'd1: font_line = 8'b01101100;
                3'd2: font_line = 8'b01111000;
                3'd3: font_line = 8'b01110000;
                3'd4: font_line = 8'b01111000;
                3'd5: font_line = 8'b01101100;
                3'd6: font_line = 8'b01100110;
                3'd7: font_line = 8'b00000000;
            endcase
            
            // L
            8'h4C: case (row)
                3'd0: font_line = 8'b01100000;
                3'd1: font_line = 8'b01100000;
                3'd2: font_line = 8'b01100000;
                3'd3: font_line = 8'b01100000;
                3'd4: font_line = 8'b01100000;
                3'd5: font_line = 8'b01100000;
                3'd6: font_line = 8'b01111110;
                3'd7: font_line = 8'b00000000;
            endcase
            
            // M
            8'h4D: case (row)
                3'd0: font_line = 8'b01100011;
                3'd1: font_line = 8'b01110111;
                3'd2: font_line = 8'b01111111;
                3'd3: font_line = 8'b01101011;
                3'd4: font_line = 8'b01100011;
                3'd5: font_line = 8'b01100011;
                3'd6: font_line = 8'b01100011;
                3'd7: font_line = 8'b00000000;
            endcase
            
            // N
            8'h4E: case (row)
                3'd0: font_line = 8'b01100110;
                3'd1: font_line = 8'b01110110;
                3'd2: font_line = 8'b01111110;
                3'd3: font_line = 8'b01111110;
                3'd4: font_line = 8'b01101110;
                3'd5: font_line = 8'b01100110;
                3'd6: font_line = 8'b01100110;
                3'd7: font_line = 8'b00000000;
            endcase
            
            // O
            8'h4F: case (row)
                3'd0: font_line = 8'b00111100;
                3'd1: font_line = 8'b01100110;
                3'd2: font_line = 8'b01100110;
                3'd3: font_line = 8'b01100110;
                3'd4: font_line = 8'b01100110;
                3'd5: font_line = 8'b01100110;
                3'd6: font_line = 8'b00111100;
                3'd7: font_line = 8'b00000000;
            endcase
            
            // P
            8'h50: case (row)
                3'd0: font_line = 8'b01111100;
                3'd1: font_line = 8'b01100110;
                3'd2: font_line = 8'b01100110;
                3'd3: font_line = 8'b01111100;
                3'd4: font_line = 8'b01100000;
                3'd5: font_line = 8'b01100000;
                3'd6: font_line = 8'b01100000;
                3'd7: font_line = 8'b00000000;
            endcase
            
            // Q
            8'h51: case (row)
                3'd0: font_line = 8'b00111100;
                3'd1: font_line = 8'b01100110;
                3'd2: font_line = 8'b01100110;
                3'd3: font_line = 8'b01100110;
                3'd4: font_line = 8'b01101110;
                3'd5: font_line = 8'b00111100;
                3'd6: font_line = 8'b00000110;
                3'd7: font_line = 8'b00000000;
            endcase
            
            // R
            8'h52: case (row)
                3'd0: font_line = 8'b01111100;
                3'd1: font_line = 8'b01100110;
                3'd2: font_line = 8'b01100110;
                3'd3: font_line = 8'b01111100;
                3'd4: font_line = 8'b01101100;
                3'd5: font_line = 8'b01100110;
                3'd6: font_line = 8'b01100110;
                3'd7: font_line = 8'b00000000;
            endcase
            
            // S
            8'h53: case (row)
                3'd0: font_line = 8'b00111100;
                3'd1: font_line = 8'b01100110;
                3'd2: font_line = 8'b01100000;
                3'd3: font_line = 8'b00111100;
                3'd4: font_line = 8'b00000110;
                3'd5: font_line = 8'b01100110;
                3'd6: font_line = 8'b00111100;
                3'd7: font_line = 8'b00000000;
            endcase
            
            // T
            8'h54: case (row)
                3'd0: font_line = 8'b01111110;
                3'd1: font_line = 8'b00011000;
                3'd2: font_line = 8'b00011000;
                3'd3: font_line = 8'b00011000;
                3'd4: font_line = 8'b00011000;
                3'd5: font_line = 8'b00011000;
                3'd6: font_line = 8'b00011000;
                3'd7: font_line = 8'b00000000;
            endcase
            
            // U
            8'h55: case (row)
                3'd0: font_line = 8'b01100110;
                3'd1: font_line = 8'b01100110;
                3'd2: font_line = 8'b01100110;
                3'd3: font_line = 8'b01100110;
                3'd4: font_line = 8'b01100110;
                3'd5: font_line = 8'b01100110;
                3'd6: font_line = 8'b00111100;
                3'd7: font_line = 8'b00000000;
            endcase
            
            // V
            8'h56: case (row)
                3'd0: font_line = 8'b01100110;
                3'd1: font_line = 8'b01100110;
                3'd2: font_line = 8'b01100110;
                3'd3: font_line = 8'b01100110;
                3'd4: font_line = 8'b01100110;
                3'd5: font_line = 8'b00111100;
                3'd6: font_line = 8'b00011000;
                3'd7: font_line = 8'b00000000;
            endcase
            
            // W
            8'h57: case (row)
                3'd0: font_line = 8'b01100011;
                3'd1: font_line = 8'b01100011;
                3'd2: font_line = 8'b01100011;
                3'd3: font_line = 8'b01101011;
                3'd4: font_line = 8'b01111111;
                3'd5: font_line = 8'b01110111;
                3'd6: font_line = 8'b01100011;
                3'd7: font_line = 8'b00000000;
            endcase
            
            // X
            8'h58: case (row)
                3'd0: font_line = 8'b01100110;
                3'd1: font_line = 8'b01100110;
                3'd2: font_line = 8'b00111100;
                3'd3: font_line = 8'b00011000;
                3'd4: font_line = 8'b00111100;
                3'd5: font_line = 8'b01100110;
                3'd6: font_line = 8'b01100110;
                3'd7: font_line = 8'b00000000;
            endcase
            
            // Y
            8'h59: case (row)
                3'd0: font_line = 8'b01100110;
                3'd1: font_line = 8'b01100110;
                3'd2: font_line = 8'b01100110;
                3'd3: font_line = 8'b00111100;
                3'd4: font_line = 8'b00011000;
                3'd5: font_line = 8'b00011000;
                3'd6: font_line = 8'b00011000;
                3'd7: font_line = 8'b00000000;
            endcase
            
            // Z
            8'h5A: case (row)
                3'd0: font_line = 8'b01111110;
                3'd1: font_line = 8'b00000110;
                3'd2: font_line = 8'b00001100;
                3'd3: font_line = 8'b00011000;
                3'd4: font_line = 8'b00110000;
                3'd5: font_line = 8'b01100000;
                3'd6: font_line = 8'b01111110;
                3'd7: font_line = 8'b00000000;
            endcase
            
            default: font_line = 8'h00;
        endcase
    end

endmodule

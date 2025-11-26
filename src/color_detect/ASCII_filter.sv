`timescale 1ns / 1ps

//=============================================================================
// Module: ASCII_Filter
// Description: Real-time ASCII art filter for video stream
//              Converts camera image to ASCII characters based on brightness
//
// Features:
//   - Brightness-based character selection
//   - 8×8 character cell rendering
//   - Matrix-style green on black aesthetic
//   - Real-time processing at 25MHz
//
// Character Mapping (by brightness):
//   Darkest  → ' ' (space)
//   Dark     → '.' (period)
//   Medium   → '+', '*', '#'
//   Bright   → 'M', 'W', '@'
//=============================================================================

module ASCII_Filter #(
    parameter CHAR_WIDTH = 4'd8,      // Character cell width
    parameter CHAR_HEIGHT = 4'd8      // Character cell height
) (
    input  logic        clk,
    input  logic        reset,
    
    // VGA timing
    input  logic [9:0]  x_coord,
    input  logic [9:0]  y_coord,
    input  logic        display_enable,
    
    // Input pixel (RGB 4-bit per channel)
    input  logic [3:0]  pixel_r_in,
    input  logic [3:0]  pixel_g_in,
    input  logic [3:0]  pixel_b_in,
    
    // Frame buffer RGB888 (for better brightness calculation)
    input  logic [7:0]  pixel_r8,
    input  logic [7:0]  pixel_g8,
    input  logic [7:0]  pixel_b8,
    input  logic        pixel_valid,
    
    // ASCII filtered output
    output logic [3:0]  pixel_r_out,
    output logic [3:0]  pixel_g_out,
    output logic [3:0]  pixel_b_out
);

    //=========================================================================
    // Character cell position calculation
    //=========================================================================
    logic [5:0] char_x;  // Character column (0-39 for 320/8)
    logic [5:0] char_y;  // Character row (0-29 for 240/8)
    logic [2:0] cell_x;  // Position within character (0-7)
    logic [2:0] cell_y;  // Position within character (0-7)
    
    assign char_x = x_coord[9:3];  // Divide by 8
    assign char_y = y_coord[9:3];  // Divide by 8
    assign cell_x = x_coord[2:0];  // Modulo 8
    assign cell_y = y_coord[2:0];  // Modulo 8
    
    //=========================================================================
    // Brightness calculation (Y = 0.299*R + 0.587*G + 0.114*B)
    // Simplified: Y ≈ (R + 2*G + B) / 4
    //=========================================================================
    logic [9:0] brightness_sum;
    logic [7:0] brightness;
    
    assign brightness_sum = {2'b00, pixel_r8} + 
                           {1'b0, pixel_g8, 1'b0} +  // G * 2
                           {2'b00, pixel_b8};
    assign brightness = brightness_sum[9:2];  // Divide by 4
    
    //=========================================================================
    // Character selection based on brightness (8 levels)
    //=========================================================================
    logic [2:0] char_index;
    
    always_comb begin
        case (brightness[7:5])  // Use top 3 bits for 8 levels
            3'b000: char_index = 3'd0;  // ' ' space (darkest)
            3'b001: char_index = 3'd1;  // '.' period
            3'b010: char_index = 3'd2;  // ':' colon
            3'b011: char_index = 3'd3;  // '+' plus
            3'b100: char_index = 3'd4;  // '*' asterisk
            3'b101: char_index = 3'd5;  // '#' hash
            3'b110: char_index = 3'd6;  // 'M' letter M
            3'b111: char_index = 3'd7;  // '@' at symbol (brightest)
            default: char_index = 3'd0;
        endcase
    end
    
    //=========================================================================
    // 8×8 Character ROM (bitmap patterns)
    //=========================================================================
    logic [7:0] char_rom [0:7][0:7];  // [char_index][row]
    logic char_pixel;
    
    // Character bitmaps (1 = foreground, 0 = background)
    always_comb begin
        // Initialize all to 0
        for (int i = 0; i < 8; i++) begin
            for (int j = 0; j < 8; j++) begin
                char_rom[i][j] = 8'h00;
            end
        end
        
        // 0: ' ' (space) - all black
        char_rom[0][0] = 8'b00000000;
        char_rom[0][1] = 8'b00000000;
        char_rom[0][2] = 8'b00000000;
        char_rom[0][3] = 8'b00000000;
        char_rom[0][4] = 8'b00000000;
        char_rom[0][5] = 8'b00000000;
        char_rom[0][6] = 8'b00000000;
        char_rom[0][7] = 8'b00000000;
        
        // 1: '.' (period)
        char_rom[1][0] = 8'b00000000;
        char_rom[1][1] = 8'b00000000;
        char_rom[1][2] = 8'b00000000;
        char_rom[1][3] = 8'b00000000;
        char_rom[1][4] = 8'b00000000;
        char_rom[1][5] = 8'b00011000;
        char_rom[1][6] = 8'b00011000;
        char_rom[1][7] = 8'b00000000;
        
        // 2: ':' (colon)
        char_rom[2][0] = 8'b00000000;
        char_rom[2][1] = 8'b00011000;
        char_rom[2][2] = 8'b00011000;
        char_rom[2][3] = 8'b00000000;
        char_rom[2][4] = 8'b00000000;
        char_rom[2][5] = 8'b00011000;
        char_rom[2][6] = 8'b00011000;
        char_rom[2][7] = 8'b00000000;
        
        // 3: '+' (plus)
        char_rom[3][0] = 8'b00000000;
        char_rom[3][1] = 8'b00011000;
        char_rom[3][2] = 8'b00011000;
        char_rom[3][3] = 8'b01111110;
        char_rom[3][4] = 8'b01111110;
        char_rom[3][5] = 8'b00011000;
        char_rom[3][6] = 8'b00011000;
        char_rom[3][7] = 8'b00000000;
        
        // 4: '*' (asterisk)
        char_rom[4][0] = 8'b00000000;
        char_rom[4][1] = 8'b01000010;
        char_rom[4][2] = 8'b00100100;
        char_rom[4][3] = 8'b00011000;
        char_rom[4][4] = 8'b01111110;
        char_rom[4][5] = 8'b00011000;
        char_rom[4][6] = 8'b00100100;
        char_rom[4][7] = 8'b01000010;
        
        // 5: '#' (hash)
        char_rom[5][0] = 8'b00100100;
        char_rom[5][1] = 8'b00100100;
        char_rom[5][2] = 8'b01111110;
        char_rom[5][3] = 8'b00100100;
        char_rom[5][4] = 8'b00100100;
        char_rom[5][5] = 8'b01111110;
        char_rom[5][6] = 8'b00100100;
        char_rom[5][7] = 8'b00100100;
        
        // 6: 'M' (letter M)
        char_rom[6][0] = 8'b01000010;
        char_rom[6][1] = 8'b01100110;
        char_rom[6][2] = 8'b01011010;
        char_rom[6][3] = 8'b01000010;
        char_rom[6][4] = 8'b01000010;
        char_rom[6][5] = 8'b01000010;
        char_rom[6][6] = 8'b01000010;
        char_rom[6][7] = 8'b00000000;
        
        // 7: '@' (at symbol)
        char_rom[7][0] = 8'b00111100;
        char_rom[7][1] = 8'b01000010;
        char_rom[7][2] = 8'b01011010;
        char_rom[7][3] = 8'b01010110;
        char_rom[7][4] = 8'b01011110;
        char_rom[7][5] = 8'b01000000;
        char_rom[7][6] = 8'b00111100;
        char_rom[7][7] = 8'b00000000;
    end
    
    // Extract pixel from character bitmap
    assign char_pixel = char_rom[char_index][cell_y][7 - cell_x];
    
    //=========================================================================
    // Matrix-style color rendering (green on black)
    //=========================================================================
    logic [3:0] ascii_r, ascii_g, ascii_b;
    
    always_comb begin
        if (display_enable) begin
            if (char_pixel) begin
                // Foreground: bright green (Matrix style)
                ascii_r = 4'h0;
                ascii_g = 4'hF;
                ascii_b = 4'h0;
            end else begin
                // Background: dark green/black
                ascii_r = 4'h0;
                ascii_g = 4'h1;  // Slight green tint
                ascii_b = 4'h0;
            end
        end else begin
            ascii_r = 4'h0;
            ascii_g = 4'h0;
            ascii_b = 4'h0;
        end
    end
    
    //=========================================================================
    // Output assignment
    //=========================================================================
    assign pixel_r_out = ascii_r;
    assign pixel_g_out = ascii_g;
    assign pixel_b_out = ascii_b;
    
endmodule

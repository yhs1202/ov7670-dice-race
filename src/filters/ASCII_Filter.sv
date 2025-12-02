`timescale 1ns / 1ps

//=============================================================================
// Module: ASCII_Filter
// Description: Real-time ASCII art filter for video stream
//              Converts camera image to ASCII characters based on brightness
//
// Features:
//   - Brightness-based character selection (8 levels)
//   - 8×8 character cell rendering
//   - Matrix-style green on black aesthetic
//   - Real-time processing at 25MHz
//
// Character Mapping (by brightness):
//   Darkest  → ' ' (space)
//   Dark     → '.' (period)
//   Medium   → ':', '+', '*', '#'
//   Bright   → 'M', '@' (brightest)
//=============================================================================

module ASCII_Filter #(
    parameter CHAR_SIZE  = 8,         // Character cell size (8x8)
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

    //=========================================================================
    // Character cell position calculation
    //=========================================================================
    logic [5:0] char_x;   // Character column (0-19 for 160/8)
    logic [5:0] char_y;   // Character row (0-14 for 120/8)
    logic [2:0] cell_x;   // Position within character (0-7)
    logic [2:0] cell_y;   // Position within character (0-7)
    
    assign char_x = x_local[9:3];  // Divide by 8
    assign char_y = y_local[9:3];  // Divide by 8
    assign cell_x = x_local[2:0];  // Modulo 8
    assign cell_y = y_local[2:0];  // Modulo 8

    //=========================================================================
    // Brightness calculation (Y = 0.299*R + 0.587*G + 0.114*B)
    // Simplified: Y ≈ (R + 2*G + B) / 4
    // Using 4-bit RGB, scale to 8-bit for calculation
    //=========================================================================
    logic [7:0] r8, g8, b8;
    logic [9:0] brightness_sum;
    logic [7:0] brightness;
    
    assign r8 = {r_in, 4'b0000};  // Scale 4-bit to 8-bit
    assign g8 = {g_in, 4'b0000};
    assign b8 = {b_in, 4'b0000};
    
    assign brightness_sum = {2'b00, r8} + 
                           {1'b0, g8, 1'b0} +  // G * 2
                           {2'b00, b8};
    assign brightness = brightness_sum[9:2];   // Divide by 4

    //=========================================================================
    // Brightness storage for each character block
    // Sample brightness at top-left corner of each block
    //=========================================================================
    localparam CHARS_X = IMG_WIDTH / CHAR_SIZE;   // 20
    localparam CHARS_Y = IMG_HEIGHT / CHAR_SIZE;  // 15
    localparam ADDR_W  = $clog2(CHARS_X * CHARS_Y);

    logic [ADDR_W-1:0] mem_addr;
    assign mem_addr = (char_y * CHARS_X) + char_x;

    logic is_sample_point;
    assign is_sample_point = (cell_x == 3'd0) && (cell_y == 3'd0);

    logic [7:0] brightness_mem [0:(CHARS_X * CHARS_Y)-1];
    
    always_ff @(posedge clk) begin
        if (filter_en && is_sample_point) begin
            brightness_mem[mem_addr] <= brightness;
        end
    end

    // Get stored brightness for current block
    logic [7:0] block_brightness;
    assign block_brightness = is_sample_point ? brightness : brightness_mem[mem_addr];

    //=========================================================================
    // Character selection based on brightness (8 levels)
    //=========================================================================
    logic [2:0] char_index;
    
    always_comb begin
        case (block_brightness[7:5])  // Use top 3 bits for 8 levels
            3'b000:  char_index = 3'd0;  // ' ' space (darkest)
            3'b001:  char_index = 3'd1;  // '.' period
            3'b010:  char_index = 3'd2;  // ':' colon
            3'b011:  char_index = 3'd3;  // '+' plus
            3'b100:  char_index = 3'd4;  // '*' asterisk
            3'b101:  char_index = 3'd5;  // '#' hash
            3'b110:  char_index = 3'd6;  // 'M' letter M
            3'b111:  char_index = 3'd7;  // '@' at symbol (brightest)
            default: char_index = 3'd0;
        endcase
    end

    //=========================================================================
    // 8×8 Character ROM (bitmap patterns)
    //=========================================================================
    logic [7:0] char_row;
    
    always_comb begin
        case (char_index)
            // 0: ' ' (space) - all black
            3'd0: begin
                case (cell_y)
                    default: char_row = 8'b00000000;
                endcase
            end
            
            // 1: '.' (period)
            3'd1: begin
                case (cell_y)
                    3'd5:    char_row = 8'b00011000;
                    3'd6:    char_row = 8'b00011000;
                    default: char_row = 8'b00000000;
                endcase
            end
            
            // 2: ':' (colon)
            3'd2: begin
                case (cell_y)
                    3'd1:    char_row = 8'b00011000;
                    3'd2:    char_row = 8'b00011000;
                    3'd5:    char_row = 8'b00011000;
                    3'd6:    char_row = 8'b00011000;
                    default: char_row = 8'b00000000;
                endcase
            end
            
            // 3: '+' (plus)
            3'd3: begin
                case (cell_y)
                    3'd1:    char_row = 8'b00011000;
                    3'd2:    char_row = 8'b00011000;
                    3'd3:    char_row = 8'b01111110;
                    3'd4:    char_row = 8'b01111110;
                    3'd5:    char_row = 8'b00011000;
                    3'd6:    char_row = 8'b00011000;
                    default: char_row = 8'b00000000;
                endcase
            end
            
            // 4: '*' (asterisk)
            3'd4: begin
                case (cell_y)
                    3'd1:    char_row = 8'b01000010;
                    3'd2:    char_row = 8'b00100100;
                    3'd3:    char_row = 8'b00011000;
                    3'd4:    char_row = 8'b01111110;
                    3'd5:    char_row = 8'b00011000;
                    3'd6:    char_row = 8'b00100100;
                    3'd7:    char_row = 8'b01000010;
                    default: char_row = 8'b00000000;
                endcase
            end
            
            // 5: '#' (hash)
            3'd5: begin
                case (cell_y)
                    3'd0:    char_row = 8'b00100100;
                    3'd1:    char_row = 8'b00100100;
                    3'd2:    char_row = 8'b01111110;
                    3'd3:    char_row = 8'b00100100;
                    3'd4:    char_row = 8'b00100100;
                    3'd5:    char_row = 8'b01111110;
                    3'd6:    char_row = 8'b00100100;
                    3'd7:    char_row = 8'b00100100;
                    default: char_row = 8'b00000000;
                endcase
            end
            
            // 6: 'M' (letter M)
            3'd6: begin
                case (cell_y)
                    3'd0:    char_row = 8'b01000010;
                    3'd1:    char_row = 8'b01100110;
                    3'd2:    char_row = 8'b01011010;
                    3'd3:    char_row = 8'b01000010;
                    3'd4:    char_row = 8'b01000010;
                    3'd5:    char_row = 8'b01000010;
                    3'd6:    char_row = 8'b01000010;
                    default: char_row = 8'b00000000;
                endcase
            end
            
            // 7: '@' (at symbol)
            3'd7: begin
                case (cell_y)
                    3'd0:    char_row = 8'b00111100;
                    3'd1:    char_row = 8'b01000010;
                    3'd2:    char_row = 8'b01011010;
                    3'd3:    char_row = 8'b01010110;
                    3'd4:    char_row = 8'b01011110;
                    3'd5:    char_row = 8'b01000000;
                    3'd6:    char_row = 8'b00111100;
                    default: char_row = 8'b00000000;
                endcase
            end
            
            default: char_row = 8'b00000000;
        endcase
    end

    // Extract pixel from character bitmap (MSB first)
    logic char_pixel;
    assign char_pixel = char_row[7 - cell_x];

    //=========================================================================
    // Matrix-style color rendering (green on black)
    //=========================================================================
    always_comb begin
        if (filter_en) begin
            if (char_pixel) begin
                // Foreground: bright green (Matrix style)
                r_out = 4'h0;
                g_out = 4'hF;
                b_out = 4'h0;
            end else begin
                // Background: dark green/black
                r_out = 4'h0;
                g_out = 4'h1;  // Slight green tint
                b_out = 4'h0;
            end
        end else begin
            // Filter disabled: pass through
            r_out = r_in;
            g_out = g_in;
            b_out = b_in;
        end
    end

endmodule

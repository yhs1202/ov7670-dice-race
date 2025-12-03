`timescale 1ns/1ps

import color_pkg::*;

module finish_box_renderer (
    input  logic [9:0] pixel_x,
    input  logic [9:0] pixel_y,
    output rgb_t       color,
    output logic       enable
);

    // ===== Color Palette =====
    // Converted from 12-bit to 8-bit
    localparam rgb_t COLOR_BRICK = '{r: 8'hCC, g: 8'h44, b: 8'h00};
    localparam rgb_t COLOR_CREAM = '{r: 8'hFF, g: 8'hCC, b: 8'hBB};
    localparam rgb_t COLOR_BLACK = '{r: 8'h00, g: 8'h00, b: 8'h00};

    // ===== Layout Constants (in pixels) =====
    // Box centered on screen (640x480)
    localparam BOX_W      = 320;
    localparam BOX_H      = 160;
    localparam BOX_X      = (640 - BOX_W) / 2; // 160
    localparam BOX_Y      = (480 - BOX_H) / 2; // 160
    localparam BORDER     = 8;
    
    // Text "FINISH"
    // 6 chars. 
    // Scale 4x: 8x8 font -> 32x32 pixels per char.
    localparam CHAR_W_BASE = 8;
    localparam CHAR_H_BASE = 8;
    localparam SCALE       = 4;
    localparam CHAR_W      = CHAR_W_BASE * SCALE; // 32
    localparam CHAR_H      = CHAR_H_BASE * SCALE; // 32
    
    localparam TEXT_LEN    = 6;
    localparam TEXT_W      = TEXT_LEN * CHAR_W; // 192
    localparam TEXT_X      = BOX_X + (BOX_W - TEXT_W) / 2;
    localparam TEXT_Y      = BOX_Y + (BOX_H - CHAR_H) / 2;

    // ===== Font ROM Interface =====
    logic [7:0] char_code;
    logic [2:0] char_row;
    logic [7:0] font_line;
    
    font_rom U_FONT (
        .char_code(char_code),
        .row(char_row),
        .font_line(font_line)
    );

    // ===== Rendering Logic =====
    logic in_box, in_border;
    logic in_text_area;
    logic text_pixel;
    
    // Position calculations
    logic [9:0] rel_x, rel_y;
    logic [5:0] char_index;
    logic [2:0] char_col_in;

    // Box Detection
    assign in_border = (pixel_x >= BOX_X && pixel_x < BOX_X + BOX_W &&
                        pixel_y >= BOX_Y && pixel_y < BOX_Y + BOX_H) &&
                       (pixel_x < BOX_X + BORDER || 
                        pixel_x >= BOX_X + BOX_W - BORDER ||
                        pixel_y < BOX_Y + BORDER ||
                        pixel_y >= BOX_Y + BOX_H - BORDER);
                              
    assign in_box = (pixel_x >= BOX_X + BORDER && 
                     pixel_x < BOX_X + BOX_W - BORDER &&
                     pixel_y >= BOX_Y + BORDER && 
                     pixel_y < BOX_Y + BOX_H - BORDER);

    // Text Area Detection
    assign in_text_area = (pixel_x >= TEXT_X && pixel_x < TEXT_X + TEXT_W &&
                           pixel_y >= TEXT_Y && pixel_y < TEXT_Y + CHAR_H);

    // Text Rendering
    always_comb begin
        char_code = 8'h20;
        char_row = 3'd0;
        text_pixel = 1'b0;
        
        // Initialize rel_x/y to avoid latch inference or X propagation
        rel_x = 0;
        rel_y = 0;
        char_index = 0;
        char_col_in = 0;
        
        if (in_text_area) begin
            rel_x = pixel_x - TEXT_X;
            rel_y = pixel_y - TEXT_Y;
            char_index = rel_x / CHAR_W;
            char_col_in = (rel_x % CHAR_W) / SCALE;
            char_row = (rel_y % CHAR_H) / SCALE;
            
            case (char_index)
                0: char_code = "F";
                1: char_code = "I";
                2: char_code = "N";
                3: char_code = "I";
                4: char_code = "S";
                5: char_code = "H";
                default: char_code = 8'h20;
            endcase
            
            if (char_col_in < 8)
                text_pixel = font_line[7 - char_col_in];
        end
    end

    // Output Logic
    always_comb begin
        enable = 0;
        color = BLACK; // Default
        
        if (in_border) begin
            enable = 1;
            color = COLOR_BLACK;
        end else if (in_box) begin
            enable = 1;
            color = COLOR_BRICK;
            if (in_text_area && text_pixel) begin
                color = COLOR_CREAM;
            end
        end
    end

endmodule

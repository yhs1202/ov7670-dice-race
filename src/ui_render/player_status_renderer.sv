`timescale 1ns/1ps

import color_pkg::*;

module player_status_renderer (
    input  logic [9:0] pixel_x,
    input  logic [9:0] pixel_y,
    output rgb_t       color,
    output logic       enable
);

    // ===== Layout Constants =====
    localparam SCALE = 2;
    localparam CHAR_W = 8 * SCALE; // 16
    localparam CHAR_H = 8 * SCALE; // 16
    
    // Player 1 UI Position (Left)
    localparam P1_TEXT_X = 40;
    localparam P1_TEXT_Y = 32; // Moved up by 8px (40 -> 32)
    localparam P1_ICON_X = P1_TEXT_X + (10 * CHAR_W) + 8; // "PLAYER 1 :" is 10 chars
    localparam P1_ICON_Y = P1_TEXT_Y;

    // Player 2 UI Position (Right)
    localparam P2_TEXT_X = 360;
    localparam P2_TEXT_Y = 32; // Moved up by 8px (40 -> 32)
    localparam P2_ICON_X = P2_TEXT_X + (10 * CHAR_W) + 8; // "PLAYER 2 :" is 10 chars
    localparam P2_ICON_Y = P2_TEXT_Y;

    // ===== Font ROM Interface =====
    logic [7:0] char_code;
    logic [2:0] char_row;
    logic [7:0] font_line;
    
    font_rom U_FONT (
        .char_code(char_code),
        .row(char_row),
        .font_line(font_line)
    );

    // ===== Text Rendering Logic =====
    logic in_p1_text, in_p2_text;
    logic text_pixel;
    logic [9:0] rel_x, rel_y;
    logic [5:0] char_index;
    logic [2:0] char_col_in;

    assign in_p1_text = (pixel_x >= P1_TEXT_X && pixel_x < P1_TEXT_X + (10 * CHAR_W) &&
                         pixel_y >= P1_TEXT_Y && pixel_y < P1_TEXT_Y + CHAR_H);

    assign in_p2_text = (pixel_x >= P2_TEXT_X && pixel_x < P2_TEXT_X + (10 * CHAR_W) &&
                         pixel_y >= P2_TEXT_Y && pixel_y < P2_TEXT_Y + CHAR_H);

    always_comb begin
        char_code = 8'h20;
        char_row = 3'd0;
        text_pixel = 1'b0;
        
        rel_x = 0;
        rel_y = 0;
        char_index = 0;
        char_col_in = 0;

        if (in_p1_text) begin
            rel_x = pixel_x - P1_TEXT_X;
            rel_y = pixel_y - P1_TEXT_Y;
            char_index = rel_x / CHAR_W;
            char_col_in = (rel_x % CHAR_W) / SCALE;
            char_row = (rel_y % CHAR_H) / SCALE;
            
            case (char_index)
                0: char_code = "P";
                1: char_code = "L";
                2: char_code = "A";
                3: char_code = "Y";
                4: char_code = "E";
                5: char_code = "R";
                6: char_code = " ";
                7: char_code = "1";
                8: char_code = " ";
                9: char_code = ":";
                default: char_code = 8'h20;
            endcase
            
            if (char_col_in < 8)
                text_pixel = font_line[7 - char_col_in];

        end else if (in_p2_text) begin
            rel_x = pixel_x - P2_TEXT_X;
            rel_y = pixel_y - P2_TEXT_Y;
            char_index = rel_x / CHAR_W;
            char_col_in = (rel_x % CHAR_W) / SCALE;
            char_row = (rel_y % CHAR_H) / SCALE;
            
            case (char_index)
                0: char_code = "P";
                1: char_code = "L";
                2: char_code = "A";
                3: char_code = "Y";
                4: char_code = "E";
                5: char_code = "R";
                6: char_code = " ";
                7: char_code = "2";
                8: char_code = " ";
                9: char_code = ":";
                default: char_code = 8'h20;
            endcase

            if (char_col_in < 8)
                text_pixel = font_line[7 - char_col_in];
        end
    end

    // ===== Icon Rendering Logic =====
    rgb_t p1_icon_color, p2_icon_color;
    logic p1_icon_en, p2_icon_en;

    // Instantiate Player Renderer for P1 Icon (Kirby)
    player_renderer U_P1_ICON (
        .x(pixel_x),
        .y(pixel_y),
        .player_x(10'(P1_ICON_X)),
        .player_y(10'(P1_ICON_Y)),
        .player_id(1'b0), // Player 1
        .color(p1_icon_color),
        .enable(p1_icon_en)
    );

    // Instantiate Player Renderer for P2 Icon (Dee)
    player_renderer U_P2_ICON (
        .x(pixel_x),
        .y(pixel_y),
        .player_x(10'(P2_ICON_X)),
        .player_y(10'(P2_ICON_Y)),
        .player_id(1'b1), // Player 2
        .color(p2_icon_color),
        .enable(p2_icon_en)
    );

    // ===== Output Logic =====
    always_comb begin
        enable = 0;
        color = BLACK; // Default

        if (p1_icon_en) begin
            enable = 1;
            color = p1_icon_color;
        end else if (p2_icon_en) begin
            enable = 1;
            color = p2_icon_color;
        end else if ((in_p1_text || in_p2_text) && text_pixel) begin
            enable = 1;
            color = BLACK; // Text color
        end
    end

endmodule

`timescale 1ns / 1ps

import color_pkg::*;

module camera_label_renderer (
    input  logic [9:0] pixel_x,
    input  logic [9:0] pixel_y,
    output rgb_t       color,
    output logic       enable
);

    // ========================================
    // Layout Constants
    // ========================================
    localparam SCALE = 2;
    localparam CHAR_W = 8 * SCALE; // 16
    localparam CHAR_H = 8 * SCALE; // 16

    // "COLOR DETECT" (Left Side)
    // Camera starts at Y=240.
    // Centered horizontally in 0-320 range.
    // Text width = 12 * 16 = 192. Start X = (320 - 192) / 2 = 64.
    localparam L1_TEXT_X = 64;
    localparam L1_TEXT_Y = 257;
    localparam L1_LEN    = 12; // "COLOR DETECT" length

    // "PLAYER" (Right Side)
    // Right side starts at X=320.
    // Centered horizontally in 320-640 range. Center is 480.
    // Text width = 6 * 16 = 96. Start X = 480 - (96 / 2) = 432.
    localparam L2_TEXT_X = 432;
    localparam L2_TEXT_Y = 257;
    localparam L2_LEN    = 6;  // "PLAYER" length

    // ========================================
    // Font ROM Interface
    // ========================================
    logic [7:0] char_code;
    logic [2:0] char_row;
    logic [7:0] font_line;

    font_rom U_FONT (
        .char_code(char_code),
        .row(char_row),
        .font_line(font_line)
    );

    // ========================================
    // Text Rendering Logic
    // ========================================
    logic in_l1_text, in_l2_text;
    logic in_l1_box_area, in_l2_box_area; // Box area (Background + Border)
    logic in_l1_border, in_l2_border;     // Border area
    logic text_pixel;
    logic [9:0] rel_x, rel_y;
    logic [5:0] char_index;
    logic [2:0] char_col_in;

    localparam PADDING = 7; // 7px padding around text (Increased by 3px)
    localparam BORDER  = 2; // 2px black border

    // Text Area
    assign in_l1_text = (pixel_x >= L1_TEXT_X && pixel_x < L1_TEXT_X + (L1_LEN * CHAR_W) &&
                         pixel_y >= L1_TEXT_Y && pixel_y < L1_TEXT_Y + CHAR_H);

    assign in_l2_text = (pixel_x >= L2_TEXT_X && pixel_x < L2_TEXT_X + (L2_LEN * CHAR_W) &&
                         pixel_y >= L2_TEXT_Y && pixel_y < L2_TEXT_Y + CHAR_H);

    // Box Area (Text Area + Padding)
    assign in_l1_box_area = (pixel_x >= L1_TEXT_X - PADDING && pixel_x < L1_TEXT_X + (L1_LEN * CHAR_W) + PADDING &&
                             pixel_y >= L1_TEXT_Y - PADDING && pixel_y < L1_TEXT_Y + CHAR_H + PADDING);

    assign in_l2_box_area = (pixel_x >= L2_TEXT_X - PADDING && pixel_x < L2_TEXT_X + (L2_LEN * CHAR_W) + PADDING &&
                             pixel_y >= L2_TEXT_Y - PADDING && pixel_y < L2_TEXT_Y + CHAR_H + PADDING);

    // Border Logic (Outer edge of the box area)
    assign in_l1_border = in_l1_box_area && (
        pixel_x < L1_TEXT_X - PADDING + BORDER || 
        pixel_x >= L1_TEXT_X + (L1_LEN * CHAR_W) + PADDING - BORDER ||
        pixel_y < L1_TEXT_Y - PADDING + BORDER || 
        pixel_y >= L1_TEXT_Y + CHAR_H + PADDING - BORDER
    );

    assign in_l2_border = in_l2_box_area && (
        pixel_x < L2_TEXT_X - PADDING + BORDER || 
        pixel_x >= L2_TEXT_X + (L2_LEN * CHAR_W) + PADDING - BORDER ||
        pixel_y < L2_TEXT_Y - PADDING + BORDER || 
        pixel_y >= L2_TEXT_Y + CHAR_H + PADDING - BORDER
    );

    always_comb begin
        char_code = 8'h20;
        char_row = 3'd0;
        text_pixel = 1'b0;
        
        rel_x = 0;
        rel_y = 0;
        char_index = 0;
        char_col_in = 0;

        if (in_l1_text) begin
            rel_x = pixel_x - L1_TEXT_X;
            rel_y = pixel_y - L1_TEXT_Y;
            char_index = rel_x / CHAR_W;
            char_col_in = (rel_x % CHAR_W) / SCALE;
            char_row = (rel_y % CHAR_H) / SCALE;

            // "COLOR DETECT"
            case (char_index)
                0: char_code = "C";
                1: char_code = "O";
                2: char_code = "L";
                3: char_code = "O";
                4: char_code = "R";
                5: char_code = " ";
                6: char_code = "D";
                7: char_code = "E";
                8: char_code = "T";
                9: char_code = "E";
                10:char_code = "C";
                11:char_code = "T";
                default: char_code = 8'h20;
            endcase

            if (char_col_in < 8)
                text_pixel = font_line[7 - char_col_in];

        end else if (in_l2_text) begin
            rel_x = pixel_x - L2_TEXT_X;
            rel_y = pixel_y - L2_TEXT_Y;
            char_index = rel_x / CHAR_W;
            char_col_in = (rel_x % CHAR_W) / SCALE;
            char_row = (rel_y % CHAR_H) / SCALE;

            // "PLAYER"
            case (char_index)
                0: char_code = "P";
                1: char_code = "L";
                2: char_code = "A";
                3: char_code = "Y";
                4: char_code = "E";
                5: char_code = "R";
                default: char_code = 8'h20;
            endcase

            if (char_col_in < 8)
                text_pixel = font_line[7 - char_col_in];
        end
    end

    // ========================================
    // Output Logic
    // ========================================
    always_comb begin
        enable = 0;
        color = WHITE; // Default

        if (in_l1_box_area || in_l2_box_area) begin
            enable = 1;
            if (in_l1_border || in_l2_border) begin
                color = BLACK; // Border is Black
            end else if ((in_l1_text || in_l2_text) && text_pixel) begin
                color = BLACK; // Text is Black
            end else begin
                color = WHITE; // Box Background is White
            end
        end
    end

endmodule

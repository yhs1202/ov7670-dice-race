`timescale 1ns/1ps

module UI_Intro_Renderer #(
    // ===== CONFIGURABLE TEXT PARAMETERS =====
    parameter TITLE_LINE1   = "DICE",
    parameter TITLE_LINE2   = "RACE", 
    parameter SUBTITLE      = "2025 VGA PROJECT",
    parameter MENU_ITEM1    = "START GAME",
    parameter MENU_ITEM2    = "END GAME",
    parameter HEADER_LEFT   = "PLAYER",
    parameter HEADER_WORLD  = "1-1",
    parameter TOP_SCORE     = "TOP- 000000"
)(
    input  logic [9:0] pixel_x,
    input  logic [9:0] pixel_y,
    input  logic menu_select,    // 0=item1 selected, 1=item2 selected
    
    output logic [11:0] pixel_color
);

    // ===== Color Palette =====
    localparam COLOR_SKY        = 12'h5AF;
    localparam COLOR_BRICK      = 12'hC40;
    localparam COLOR_BRICK_LITE = 12'hE97;
    localparam COLOR_BRICK_DARK = 12'hA30;
    localparam COLOR_WHITE      = 12'hFFF;
    localparam COLOR_CREAM      = 12'hFCB;
    localparam COLOR_BLACK      = 12'h000;
    localparam COLOR_GREEN      = 12'h0A8;
    localparam COLOR_GREEN_DARK = 12'h068;
    localparam COLOR_ORANGE     = 12'hFA5;
    localparam COLOR_CURSOR     = 12'hC40;

    // ===== Layout Constants (in pixels) =====
    // Title Box
    localparam TITLE_BOX_X      = 160;
    localparam TITLE_BOX_Y      = 100;
    localparam TITLE_BOX_W      = 320;
    localparam TITLE_BOX_H      = 120;
    localparam TITLE_BORDER     = 8;
    
    // Title Text Position (inside box)
    localparam TITLE1_Y         = 120;
    localparam TITLE2_Y         = 160;
    localparam SUBTITLE_Y       = 200;
    
    // Menu Position
    localparam MENU_X           = 200;
    localparam MENU1_Y          = 280;
    localparam MENU2_Y          = 320;
    localparam CURSOR_OFFSET    = 30;
    
    // Top Score Position
    localparam SCORE_Y          = 380;
    
    // Header Position
    localparam HEADER_Y         = 20;
    
    // Ground
    localparam GROUND_Y         = 416;
    localparam BRICK_SIZE       = 32;
    
    // Character sizes (8x8 font scaled 2x = 16x16)
    localparam CHAR_W           = 16;
    localparam CHAR_H           = 16;
    localparam CHAR_SCALE       = 2;
    
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
    logic in_title_box, in_title_border;
    logic in_ground, in_brick_pattern;
    logic in_hill1, in_hill2;
    logic in_bush1, in_bush2;
    logic in_cloud1, in_cloud2;
    logic in_pipe_top, in_pipe_body;
    logic in_question_block;
    
    // Text rendering signals
    logic in_title1_area, in_title2_area, in_subtitle_area;
    logic in_menu1_area, in_menu2_area;
    logic in_cursor1_area, in_cursor2_area;
    logic in_score_area;
    logic in_header_area;
    logic text_pixel;
    
    // Position calculations
    logic [9:0] rel_x, rel_y;
    logic [5:0] char_index;
    logic [2:0] char_col_in;
    
    // ===== Title Box Detection =====
    assign in_title_border = (pixel_x >= TITLE_BOX_X && pixel_x < TITLE_BOX_X + TITLE_BOX_W &&
                              pixel_y >= TITLE_BOX_Y && pixel_y < TITLE_BOX_Y + TITLE_BOX_H) &&
                             (pixel_x < TITLE_BOX_X + TITLE_BORDER || 
                              pixel_x >= TITLE_BOX_X + TITLE_BOX_W - TITLE_BORDER ||
                              pixel_y < TITLE_BOX_Y + TITLE_BORDER ||
                              pixel_y >= TITLE_BOX_Y + TITLE_BOX_H - TITLE_BORDER);
                              
    assign in_title_box = (pixel_x >= TITLE_BOX_X + TITLE_BORDER && 
                           pixel_x < TITLE_BOX_X + TITLE_BOX_W - TITLE_BORDER &&
                           pixel_y >= TITLE_BOX_Y + TITLE_BORDER && 
                           pixel_y < TITLE_BOX_Y + TITLE_BOX_H - TITLE_BORDER);

    // ===== Ground Detection =====
    assign in_ground = (pixel_y >= GROUND_Y);
    
    // Brick pattern inside ground
    wire [4:0] brick_x = pixel_x[4:0];  // 0-31 within each brick
    wire [4:0] brick_y = (pixel_y - GROUND_Y);
    wire brick_row = (pixel_y - GROUND_Y) < 32 ? 0 : 1;
    
    assign in_brick_pattern = in_ground && (
        // Horizontal mortar lines
        (brick_y[4:0] == 0 || brick_y[4:0] == 31) ||
        // Vertical mortar lines (offset by row)
        ((brick_row == 0) ? (brick_x == 0 || brick_x == 31) : 
                           ((pixel_x + 16) % 32 == 0 || (pixel_x + 16) % 32 == 31))
    );

    // ===== Hill Detection =====
    // Hill 1 (large, right side)
    logic [9:0] hill1_cx, hill1_cy, hill1_r;
    assign hill1_cx = 520;
    assign hill1_cy = GROUND_Y;
    assign hill1_r = 80;
    assign in_hill1 = (pixel_y >= GROUND_Y - 60 && pixel_y < GROUND_Y) &&
                      ((pixel_x - hill1_cx) * (pixel_x - hill1_cx) + 
                       (pixel_y - hill1_cy) * (pixel_y - hill1_cy) < hill1_r * hill1_r);
    
    // Hill 2 (small, left side)
    logic [9:0] hill2_cx, hill2_cy, hill2_r;
    assign hill2_cx = 180;
    assign hill2_cy = GROUND_Y;
    assign hill2_r = 50;
    assign in_hill2 = (pixel_y >= GROUND_Y - 40 && pixel_y < GROUND_Y) &&
                      ((pixel_x - hill2_cx) * (pixel_x - hill2_cx) + 
                       (pixel_y - hill2_cy) * (pixel_y - hill2_cy) < hill2_r * hill2_r);

    // ===== Pipe Detection =====
    assign in_pipe_top = (pixel_x >= 80 && pixel_x < 136 &&
                          pixel_y >= GROUND_Y - 68 && pixel_y < GROUND_Y - 48);
    assign in_pipe_body = (pixel_x >= 88 && pixel_x < 128 &&
                           pixel_y >= GROUND_Y - 48 && pixel_y < GROUND_Y);

    // ===== Question Block Detection =====
    logic [5:0] qblock_phase;
    assign qblock_phase = pixel_y[5:0];  // Simple animation
    assign in_question_block = (pixel_x >= 400 && pixel_x < 432 &&
                                pixel_y >= 200 && pixel_y < 232);

    // ===== Cloud Detection (simplified circles) =====
    function automatic logic in_circle;
        input [9:0] px, py, cx, cy, r;
        logic [19:0] dx2, dy2, r2;
        begin
            dx2 = (px > cx) ? (px - cx) * (px - cx) : (cx - px) * (cx - px);
            dy2 = (py > cy) ? (py - cy) * (py - cy) : (cy - py) * (cy - py);
            r2 = r * r;
            in_circle = (dx2 + dy2) < r2;
        end
    endfunction
    
    assign in_cloud1 = in_circle(pixel_x, pixel_y, 100, 70, 20) ||
                       in_circle(pixel_x, pixel_y, 120, 60, 25) ||
                       in_circle(pixel_x, pixel_y, 145, 65, 22);
                       
    assign in_cloud2 = in_circle(pixel_x, pixel_y, 500, 90, 18) ||
                       in_circle(pixel_x, pixel_y, 520, 80, 22) ||
                       in_circle(pixel_x, pixel_y, 540, 88, 18);

    // ===== Bush Detection =====
    assign in_bush1 = (pixel_y >= GROUND_Y - 24 && pixel_y < GROUND_Y) &&
                      (in_circle(pixel_x, pixel_y, 260, GROUND_Y - 12, 16) ||
                       in_circle(pixel_x, pixel_y, 280, GROUND_Y - 16, 20) ||
                       in_circle(pixel_x, pixel_y, 300, GROUND_Y - 12, 16));
                       
    assign in_bush2 = (pixel_y >= GROUND_Y - 20 && pixel_y < GROUND_Y) &&
                      (in_circle(pixel_x, pixel_y, 560, GROUND_Y - 10, 14) ||
                       in_circle(pixel_x, pixel_y, 580, GROUND_Y - 14, 18) ||
                       in_circle(pixel_x, pixel_y, 600, GROUND_Y - 10, 14));

    // ===== Text Area Detection =====
    // Title Line 1
    localparam TITLE1_LEN = 10;
    localparam TITLE1_X = 320 - (TITLE1_LEN * CHAR_W / 2);
    assign in_title1_area = (pixel_x >= TITLE1_X && pixel_x < TITLE1_X + TITLE1_LEN * CHAR_W &&
                             pixel_y >= TITLE1_Y && pixel_y < TITLE1_Y + CHAR_H);
    
    // Title Line 2
    localparam TITLE2_LEN = 10;
    localparam TITLE2_X = 320 - (TITLE2_LEN * CHAR_W / 2);
    assign in_title2_area = (pixel_x >= TITLE2_X && pixel_x < TITLE2_X + TITLE2_LEN * CHAR_W &&
                             pixel_y >= TITLE2_Y && pixel_y < TITLE2_Y + CHAR_H);
    
    // Subtitle
    localparam SUBTITLE_LEN = 20;
    localparam SUBTITLE_X = 320 - (SUBTITLE_LEN * 8 / 2);  // Smaller font
    assign in_subtitle_area = (pixel_x >= SUBTITLE_X && pixel_x < SUBTITLE_X + SUBTITLE_LEN * 8 &&
                               pixel_y >= SUBTITLE_Y && pixel_y < SUBTITLE_Y + 8);
    
    // Menu Items
    localparam MENU_LEN = 12;
    assign in_menu1_area = (pixel_x >= MENU_X && pixel_x < MENU_X + MENU_LEN * CHAR_W &&
                            pixel_y >= MENU1_Y && pixel_y < MENU1_Y + CHAR_H);
    assign in_menu2_area = (pixel_x >= MENU_X && pixel_x < MENU_X + MENU_LEN * CHAR_W &&
                            pixel_y >= MENU2_Y && pixel_y < MENU2_Y + CHAR_H);
    
    // Cursor areas
    assign in_cursor1_area = (pixel_x >= MENU_X - CURSOR_OFFSET && pixel_x < MENU_X - CURSOR_OFFSET + CHAR_W &&
                              pixel_y >= MENU1_Y && pixel_y < MENU1_Y + CHAR_H);
    assign in_cursor2_area = (pixel_x >= MENU_X - CURSOR_OFFSET && pixel_x < MENU_X - CURSOR_OFFSET + CHAR_W &&
                              pixel_y >= MENU2_Y && pixel_y < MENU2_Y + CHAR_H);
    
    // Top Score
    localparam SCORE_LEN = 12;
    localparam SCORE_X = 320 - (SCORE_LEN * CHAR_W / 2);
    assign in_score_area = (pixel_x >= SCORE_X && pixel_x < SCORE_X + SCORE_LEN * CHAR_W &&
                            pixel_y >= SCORE_Y && pixel_y < SCORE_Y + CHAR_H);

    // ===== Text Rendering Logic =====
    // Get character from string based on position
    function automatic [7:0] get_char_from_string;
        input [8*20-1:0] str;  // Max 20 chars
        input [4:0] idx;
        input [4:0] max_len;
        reg [7:0] chars [0:19];
        integer i;
        begin
            // Unpack string (MSB first)
            for (i = 0; i < 20; i = i + 1) begin
                chars[i] = str[(19-i)*8 +: 8];
            end
            if (idx < max_len && chars[idx] != 0)
                get_char_from_string = chars[idx];
            else
                get_char_from_string = 8'h20;  // Space
        end
    endfunction

    // ===== Character Index and Font Lookup =====
    always_comb begin
        char_code = 8'h20;  // Default space
        char_row = 3'd0;
        text_pixel = 1'b0;
        
        if (in_title1_area) begin
            // Title Line 1 - 2x scale
            rel_x = pixel_x - TITLE1_X;
            rel_y = pixel_y - TITLE1_Y;
            char_index = rel_x / CHAR_W;
            char_col_in = (rel_x % CHAR_W) / CHAR_SCALE;
            char_row = (rel_y % CHAR_H) / CHAR_SCALE;
            
            case (char_index)
                0: char_code = TITLE_LINE1[8*4-1 -: 8];
                1: char_code = TITLE_LINE1[8*3-1 -: 8];
                2: char_code = TITLE_LINE1[8*2-1 -: 8];
                3: char_code = TITLE_LINE1[8*1-1 -: 8];
                default: char_code = 8'h20;
            endcase
            text_pixel = font_line[7 - char_col_in];
            
        end else if (in_title2_area) begin
            // Title Line 2 - 2x scale
            rel_x = pixel_x - TITLE2_X;
            rel_y = pixel_y - TITLE2_Y;
            char_index = rel_x / CHAR_W;
            char_col_in = (rel_x % CHAR_W) / CHAR_SCALE;
            char_row = (rel_y % CHAR_H) / CHAR_SCALE;
            
            case (char_index)
                0: char_code = TITLE_LINE2[8*4-1 -: 8];
                1: char_code = TITLE_LINE2[8*3-1 -: 8];
                2: char_code = TITLE_LINE2[8*2-1 -: 8];
                3: char_code = TITLE_LINE2[8*1-1 -: 8];
                default: char_code = 8'h20;
            endcase
            text_pixel = font_line[7 - char_col_in];
            
        end else if (in_subtitle_area) begin
            // Subtitle - 1x scale
            rel_x = pixel_x - SUBTITLE_X;
            rel_y = pixel_y - SUBTITLE_Y;
            char_index = rel_x / 8;
            char_col_in = rel_x % 8;
            char_row = rel_y % 8;
            
            case (char_index)
                0:  char_code = SUBTITLE[8*16-1 -: 8];
                1:  char_code = SUBTITLE[8*15-1 -: 8];
                2:  char_code = SUBTITLE[8*14-1 -: 8];
                3:  char_code = SUBTITLE[8*13-1 -: 8];
                4:  char_code = SUBTITLE[8*12-1 -: 8];
                5:  char_code = SUBTITLE[8*11-1 -: 8];
                6:  char_code = SUBTITLE[8*10-1 -: 8];
                7:  char_code = SUBTITLE[8*9-1 -: 8];
                8:  char_code = SUBTITLE[8*8-1 -: 8];
                9:  char_code = SUBTITLE[8*7-1 -: 8];
                10: char_code = SUBTITLE[8*6-1 -: 8];
                11: char_code = SUBTITLE[8*5-1 -: 8];
                12: char_code = SUBTITLE[8*4-1 -: 8];
                13: char_code = SUBTITLE[8*3-1 -: 8];
                14: char_code = SUBTITLE[8*2-1 -: 8];
                15: char_code = SUBTITLE[8*1-1 -: 8];
                default: char_code = 8'h20;
            endcase
            text_pixel = font_line[7 - char_col_in];
            
        end else if (in_menu1_area) begin
            // Menu Item 1 - 2x scale
            rel_x = pixel_x - MENU_X;
            rel_y = pixel_y - MENU1_Y;
            char_index = rel_x / CHAR_W;
            char_col_in = (rel_x % CHAR_W) / CHAR_SCALE;
            char_row = (rel_y % CHAR_H) / CHAR_SCALE;
            
            case (char_index)
                0:  char_code = MENU_ITEM1[8*10-1 -: 8];
                1:  char_code = MENU_ITEM1[8*9-1 -: 8];
                2:  char_code = MENU_ITEM1[8*8-1 -: 8];
                3:  char_code = MENU_ITEM1[8*7-1 -: 8];
                4:  char_code = MENU_ITEM1[8*6-1 -: 8];
                5:  char_code = MENU_ITEM1[8*5-1 -: 8];
                6:  char_code = MENU_ITEM1[8*4-1 -: 8];
                7:  char_code = MENU_ITEM1[8*3-1 -: 8];
                8:  char_code = MENU_ITEM1[8*2-1 -: 8];
                9:  char_code = MENU_ITEM1[8*1-1 -: 8];
                default: char_code = 8'h20;
            endcase
            text_pixel = font_line[7 - char_col_in];
            
        end else if (in_menu2_area) begin
            // Menu Item 2 - 2x scale
            rel_x = pixel_x - MENU_X;
            rel_y = pixel_y - MENU2_Y;
            char_index = rel_x / CHAR_W;
            char_col_in = (rel_x % CHAR_W) / CHAR_SCALE;
            char_row = (rel_y % CHAR_H) / CHAR_SCALE;
            
            case (char_index)
                0:  char_code = MENU_ITEM2[8*8-1 -: 8];
                1:  char_code = MENU_ITEM2[8*7-1 -: 8];
                2:  char_code = MENU_ITEM2[8*6-1 -: 8];
                3:  char_code = MENU_ITEM2[8*5-1 -: 8];
                4:  char_code = MENU_ITEM2[8*4-1 -: 8];
                5:  char_code = MENU_ITEM2[8*3-1 -: 8];
                6:  char_code = MENU_ITEM2[8*2-1 -: 8];
                7:  char_code = MENU_ITEM2[8*1-1 -: 8];
                default: char_code = 8'h20;
            endcase
            text_pixel = font_line[7 - char_col_in];
            
        end else if (in_cursor1_area && !menu_select) begin
            // Cursor for menu 1 (triangle/arrow)
            rel_x = pixel_x - (MENU_X - CURSOR_OFFSET);
            rel_y = pixel_y - MENU1_Y;
            char_col_in = (rel_x % CHAR_W) / CHAR_SCALE;
            char_row = (rel_y % CHAR_H) / CHAR_SCALE;
            char_code = 8'h10;  // Arrow character
            text_pixel = font_line[7 - char_col_in];
            
        end else if (in_cursor2_area && menu_select) begin
            // Cursor for menu 2
            rel_x = pixel_x - (MENU_X - CURSOR_OFFSET);
            rel_y = pixel_y - MENU2_Y;
            char_col_in = (rel_x % CHAR_W) / CHAR_SCALE;
            char_row = (rel_y % CHAR_H) / CHAR_SCALE;
            char_code = 8'h10;  // Arrow character
            text_pixel = font_line[7 - char_col_in];
            
        end else if (in_score_area) begin
            // Top Score - 2x scale
            rel_x = pixel_x - SCORE_X;
            rel_y = pixel_y - SCORE_Y;
            char_index = rel_x / CHAR_W;
            char_col_in = (rel_x % CHAR_W) / CHAR_SCALE;
            char_row = (rel_y % CHAR_H) / CHAR_SCALE;
            
            case (char_index)
                0:  char_code = TOP_SCORE[8*11-1 -: 8];
                1:  char_code = TOP_SCORE[8*10-1 -: 8];
                2:  char_code = TOP_SCORE[8*9-1 -: 8];
                3:  char_code = TOP_SCORE[8*8-1 -: 8];
                4:  char_code = TOP_SCORE[8*7-1 -: 8];
                5:  char_code = TOP_SCORE[8*6-1 -: 8];
                6:  char_code = TOP_SCORE[8*5-1 -: 8];
                7:  char_code = TOP_SCORE[8*4-1 -: 8];
                8:  char_code = TOP_SCORE[8*3-1 -: 8];
                9:  char_code = TOP_SCORE[8*2-1 -: 8];
                10: char_code = TOP_SCORE[8*1-1 -: 8];
                default: char_code = 8'h20;
            endcase
            text_pixel = font_line[7 - char_col_in];
        end
    end

    // ===== Final Color Output =====
    always_comb begin
        // Default: Sky blue
        pixel_color = COLOR_SKY;
        
        // Layer 0: Clouds (behind everything)
        if (in_cloud1 || in_cloud2) begin
            pixel_color = COLOR_WHITE;
        end
        
        // Layer 1: Hills
        if (in_hill1 || in_hill2) begin
            pixel_color = COLOR_GREEN;
        end
        
        // Layer 2: Bushes
        if (in_bush1 || in_bush2) begin
            pixel_color = COLOR_GREEN;
        end
        
        // Layer 3: Pipe
        if (in_pipe_top || in_pipe_body) begin
            pixel_color = COLOR_GREEN;
            // Add highlight
            if (in_pipe_top && pixel_x < 92) pixel_color = COLOR_GREEN_DARK;
            if (in_pipe_body && pixel_x < 96) pixel_color = COLOR_GREEN_DARK;
        end
        
        // Layer 4: Question Block
        if (in_question_block) begin
            pixel_color = COLOR_ORANGE;
            // Draw ? character inside
            if (pixel_x >= 408 && pixel_x < 424 && pixel_y >= 208 && pixel_y < 224) begin
                // Simple ? pattern
                logic [3:0] qx, qy;
                qx = pixel_x - 408;
                qy = pixel_y - 208;
                if ((qy < 4 && qx >= 4 && qx < 12) ||
                    (qy >= 4 && qy < 8 && qx >= 8 && qx < 12) ||
                    (qy >= 8 && qy < 12 && qx >= 6 && qx < 10) ||
                    (qy >= 14 && qx >= 6 && qx < 10)) begin
                    pixel_color = COLOR_BLACK;
                end
            end
        end
        
        // Layer 5: Title Box Border
        if (in_title_border) begin
            pixel_color = COLOR_BLACK;
        end
        
        // Layer 6: Title Box Interior
        if (in_title_box) begin
            pixel_color = COLOR_BRICK;
        end
        
        // Layer 7: Text on title box
        if ((in_title1_area || in_title2_area) && text_pixel) begin
            pixel_color = COLOR_CREAM;
        end
        
        // Layer 8: Subtitle
        if (in_subtitle_area && text_pixel) begin
            pixel_color = COLOR_CREAM;
        end
        
        // Layer 9: Menu text
        if ((in_menu1_area || in_menu2_area) && text_pixel) begin
            pixel_color = COLOR_WHITE;
        end
        
        // Layer 10: Cursor
        if ((in_cursor1_area && !menu_select) || (in_cursor2_area && menu_select)) begin
            if (text_pixel) begin
                pixel_color = COLOR_CURSOR;
            end
        end
        
        // Layer 11: Top Score
        if (in_score_area && text_pixel) begin
            pixel_color = COLOR_WHITE;
        end
        
        // Layer 12: Ground (on top of decorations at bottom)
        if (in_ground) begin
            if (in_brick_pattern) begin
                pixel_color = COLOR_BLACK;
            end else begin
                pixel_color = COLOR_BRICK;
            end
        end
    end

endmodule

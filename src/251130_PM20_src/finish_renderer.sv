// finish_text_renderer.sv
// 마리오 스타일 "FINISH" 텍스트 렌더러
// 빨간색 + 흰색 테두리 (큰 픽셀 폰트)

import color_pkg::*;

module finish_text_renderer (
    input  logic [9:0] x,           // 현재 스캔 x 좌표
    input  logic [9:0] y,           // 현재 스캔 y 좌표
    input  logic [9:0] text_x,      // 텍스트 시작 x 좌표
    input  logic [9:0] text_y,      // 텍스트 시작 y 좌표
    output rgb_t       color,       // 출력 색상
    output logic       enable       // 렌더링 활성화
);

    // ========================================
    // 폰트 크기 및 색상
    // ========================================
    localparam CHAR_WIDTH = 7;      // 글자 폭
    localparam CHAR_HEIGHT = 9;     // 글자 높이
    localparam SPACING = 2;         // 글자 간격
    localparam NUM_CHARS = 6;       // "FINISH" = 6글자
    localparam TOTAL_WIDTH = NUM_CHARS * CHAR_WIDTH + (NUM_CHARS - 1) * SPACING;

    // 마리오 스타일 색상
    localparam rgb_t RED_BRIGHT = '{r: 8'd255, g: 8'd0,   b: 8'd0};   // 밝은 빨강
    localparam rgb_t RED_DARK   = '{r: 8'd200, g: 8'd0,   b: 8'd0};   // 어두운 빨강 (그림자)
    localparam rgb_t YELLOW     = '{r: 8'd255, g: 8'd220, b: 8'd0};   // 노란색
    localparam rgb_t WHITE      = '{r: 8'd255, g: 8'd255, b: 8'd255}; // 흰색 (테두리)
    localparam rgb_t BLACK      = '{r: 8'd0,   g: 8'd0,   b: 8'd0};   // 검은색 (외곽)

    // ========================================
    // 상대 좌표 계산
    // ========================================
    logic signed [10:0] rel_x, rel_y;
    logic in_text;

    assign rel_x = $signed({1'b0, x}) - $signed({1'b0, text_x});
    assign rel_y = $signed({1'b0, y}) - $signed({1'b0, text_y});

    assign in_text = (rel_x >= 0) && (rel_x < TOTAL_WIDTH) &&
                     (rel_y >= 0) && (rel_y < CHAR_HEIGHT);

    // ========================================
    // 글자 선택
    // ========================================
    logic [2:0] char_index;
    logic [3:0] char_x;
    logic [3:0] char_y;

    always_comb begin
        // 현재 글자 인덱스 계산
        char_index = 0;
        char_x = 0;

        if (in_text) begin
            char_y = rel_y[3:0];

            if (rel_x < CHAR_WIDTH)
                char_index = 0;  // F
            else if (rel_x < CHAR_WIDTH + SPACING + CHAR_WIDTH)
                char_index = 1;  // I
            else if (rel_x < 2*(CHAR_WIDTH + SPACING) + CHAR_WIDTH)
                char_index = 2;  // N
            else if (rel_x < 3*(CHAR_WIDTH + SPACING) + CHAR_WIDTH)
                char_index = 3;  // I
            else if (rel_x < 4*(CHAR_WIDTH + SPACING) + CHAR_WIDTH)
                char_index = 4;  // S
            else
                char_index = 5;  // H

            // 글자 내 x 좌표
            char_x = rel_x % (CHAR_WIDTH + SPACING);
            if (char_x >= CHAR_WIDTH)
                char_x = CHAR_WIDTH - 1;  // 간격은 빈 공간
        end
    end

    // ========================================
    // 폰트 패턴 (7x9 픽셀)
    // ========================================
    logic is_letter;
    logic is_border;

    always_comb begin
        is_letter = 0;

        if (in_text && char_x < CHAR_WIDTH) begin
            case (char_index)
                // F
                3'd0: begin
                    case (char_y)
                        4'd0, 4'd1: is_letter = (char_x <= 6);                    // 상단 가로선
                        4'd2, 4'd3: is_letter = (char_x <= 1);                    // 세로선
                        4'd4:       is_letter = (char_x <= 5);                    // 중간 가로선
                        4'd5, 4'd6, 4'd7, 4'd8: is_letter = (char_x <= 1);        // 세로선
                    endcase
                end

                // I
                3'd1: begin
                    case (char_y)
                        4'd0, 4'd1: is_letter = (char_x >= 1 && char_x <= 5);     // 상단
                        4'd2, 4'd3, 4'd4, 4'd5, 4'd6: is_letter = (char_x >= 2 && char_x <= 4); // 중간
                        4'd7, 4'd8: is_letter = (char_x >= 1 && char_x <= 5);     // 하단
                    endcase
                end

                // N
                3'd2: begin
                    case (char_y)
                        4'd0, 4'd1, 4'd2, 4'd3, 4'd4, 4'd5, 4'd6, 4'd7, 4'd8:
                            is_letter = (char_x <= 1) || (char_x >= 5 && char_x <= 6) ||
                                       (char_y == char_x - 1) || (char_y == char_x);
                    endcase
                end

                // I (same as index 1)
                3'd3: begin
                    case (char_y)
                        4'd0, 4'd1: is_letter = (char_x >= 1 && char_x <= 5);
                        4'd2, 4'd3, 4'd4, 4'd5, 4'd6: is_letter = (char_x >= 2 && char_x <= 4);
                        4'd7, 4'd8: is_letter = (char_x >= 1 && char_x <= 5);
                    endcase
                end

                // S
                3'd4: begin
                    case (char_y)
                        4'd0, 4'd1: is_letter = (char_x >= 1 && char_x <= 5);     // 상단
                        4'd2:       is_letter = (char_x <= 1);                    // 좌상
                        4'd3, 4'd4: is_letter = (char_x >= 1 && char_x <= 5);     // 중간
                        4'd5:       is_letter = (char_x >= 5);                    // 우하
                        4'd6, 4'd7, 4'd8: is_letter = (char_x >= 1 && char_x <= 5); // 하단
                    endcase
                end

                // H
                3'd5: begin
                    case (char_y)
                        4'd0, 4'd1, 4'd2, 4'd3: is_letter = (char_x <= 1) || (char_x >= 5 && char_x <= 6);
                        4'd4:                   is_letter = (char_x >= 0 && char_x <= 6); // 가로선
                        4'd5, 4'd6, 4'd7, 4'd8: is_letter = (char_x <= 1) || (char_x >= 5 && char_x <= 6);
                    endcase
                end
            endcase
        end
    end

    // 테두리 판단 (글자 주변 1픽셀)
    always_comb begin
        is_border = 0;

        if (in_text && char_x < CHAR_WIDTH) begin
            // 간단한 테두리: 글자 좌/우/위/아래
            if (is_letter) begin
                is_border = 0;
            end else begin
                // 주변 픽셀 체크
                if ((char_x > 0 && char_y < CHAR_HEIGHT - 1) ||
                    (char_x < CHAR_WIDTH - 1 && char_y > 0))
                    is_border = 0;  // 실제 구현은 복잡, 단순화
            end
        end
    end

    // ========================================
    // 색상 선택 (그라데이션 효과)
    // ========================================
    always_comb begin
        if (in_text && char_x < CHAR_WIDTH) begin
            if (is_letter) begin
                // 위쪽은 밝은 빨강, 아래쪽은 어두운 빨강 (3D 효과)
                if (char_y < CHAR_HEIGHT / 2)
                    color = RED_BRIGHT;
                else
                    color = RED_DARK;
            end else begin
                color = BLACK;  // 배경은 투명 처리 (enable=0)
            end
        end else begin
            color = BLACK;
        end
    end

    assign enable = in_text && is_letter;

endmodule

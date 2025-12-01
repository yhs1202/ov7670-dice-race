// question_box_renderer.sv
// 마리오 스타일 물음표 박스 렌더러
// 노란색 박스 + 흰색 물음표 (16x16)

import color_pkg::*;

module question_box_renderer (
    input  logic [9:0] x,           // 현재 스캔 x 좌표
    input  logic [9:0] y,           // 현재 스캔 y 좌표
    input  logic [9:0] box_x,       // 박스 중심 x 좌표
    input  logic [9:0] box_y,       // 박스 중심 y 좌표
    output rgb_t       color,       // 출력 색상
    output logic       enable       // 렌더링 활성화
);

    // ========================================
    // 박스 크기 및 색상
    // ========================================
    localparam BOX_SIZE = 16;           // 16x16 박스
    localparam HALF_SIZE = BOX_SIZE / 2;

    // 색상 정의 (마리오 스타일)
    localparam rgb_t YELLOW_BRIGHT = '{r: 8'd255, g: 8'd204, b: 8'd0};   // 밝은 노란색
    localparam rgb_t YELLOW_DARK   = '{r: 8'd204, g: 8'd153, b: 8'd0};   // 어두운 노란색 (테두리)
    localparam rgb_t WHITE         = '{r: 8'd255, g: 8'd255, b: 8'd255}; // 흰색 (물음표)
    localparam rgb_t BROWN         = '{r: 8'd139, g: 8'd90,  b: 8'd43};  // 갈색 (외곽)

    // ========================================
    // 상대 좌표 계산
    // ========================================
    logic signed [10:0] rel_x, rel_y;
    logic [3:0] local_x, local_y;
    logic in_box;

    assign rel_x = $signed({1'b0, x}) - $signed({1'b0, box_x}) + HALF_SIZE;
    assign rel_y = $signed({1'b0, y}) - $signed({1'b0, box_y}) + HALF_SIZE;

    assign in_box = (rel_x >= 0) && (rel_x < BOX_SIZE) &&
                    (rel_y >= 0) && (rel_y < BOX_SIZE);

    assign local_x = rel_x[3:0];
    assign local_y = rel_y[3:0];

    // ========================================
    // 물음표 패턴 (16x16 그리드)
    // ========================================
    logic is_question_mark;

    always_comb begin
        is_question_mark = 0;

        if (in_box) begin
            case (local_y)
                // 상단 곡선 (y=3~5)
                4'd3: is_question_mark = (local_x >= 5 && local_x <= 10);
                4'd4: is_question_mark = (local_x >= 4 && local_x <= 11);
                4'd5: is_question_mark = (local_x == 4 || local_x == 11);

                // 우측 곡선 (y=6~7)
                4'd6: is_question_mark = (local_x == 10 || local_x == 11);
                4'd7: is_question_mark = (local_x == 9 || local_x == 10);

                // 중간 곡선 (y=8~9)
                4'd8: is_question_mark = (local_x == 8 || local_x == 9);
                4'd9: is_question_mark = (local_x == 7 || local_x == 8);

                // 세로 부분 (y=10)
                4'd10: is_question_mark = (local_x == 7 || local_x == 8);

                // 점 (y=12~13)
                4'd12: is_question_mark = (local_x == 7 || local_x == 8);
                4'd13: is_question_mark = (local_x == 7 || local_x == 8);

                default: is_question_mark = 0;
            endcase
        end
    end

    // ========================================
    // 테두리 판단
    // ========================================
    logic is_border, is_outer_border;

    assign is_outer_border = in_box && (local_x == 0 || local_x == BOX_SIZE-1 ||
                                         local_y == 0 || local_y == BOX_SIZE-1);

    assign is_border = in_box && ((local_x == 1 || local_x == BOX_SIZE-2 ||
                                   local_y == 1 || local_y == BOX_SIZE-2) &&
                                  !is_outer_border);

    // ========================================
    // 색상 선택
    // ========================================
    always_comb begin
        if (in_box) begin
            if (is_question_mark)
                color = WHITE;          // 물음표는 흰색
            else if (is_outer_border)
                color = BROWN;          // 외곽은 갈색
            else if (is_border)
                color = YELLOW_DARK;    // 테두리는 어두운 노란색
            else
                color = YELLOW_BRIGHT;  // 내부는 밝은 노란색
        end else begin
            color = BLACK;
        end
    end

    assign enable = in_box;

endmodule

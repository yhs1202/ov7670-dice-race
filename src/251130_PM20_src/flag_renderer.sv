// flag_renderer.sv
// 골인 지점 깃발 (체커보드 패턴)
// 위치: 타일 9 (마지막 칸)

import color_pkg::*;

module flag_renderer (
    input  logic [9:0] x,           // 화면 x 좌표
    input  logic [9:0] y,           // 화면 y 좌표
    output rgb_t       color,       // RGB 출력
    output logic       enable       // 이 픽셀 그릴지 여부
);

    // ========================================
    // 깃발 위치 (골인 지점 x=620)
    // ========================================
    localparam FLAG_X_BASE = 620;                  // 깃발 중앙

    localparam POLE_X_START = FLAG_X_BASE;
    localparam POLE_X_END   = FLAG_X_BASE + 1;     // 깃대 폭 2px
    localparam POLE_Y_TOP   = 80;                  // 깃대 위쪽
    localparam POLE_Y_BOTTOM = 150;                // 깃대 아래 (흙 위)

    localparam FLAG_X_START = FLAG_X_BASE + 2;     // 깃발 시작 (깃대 오른쪽)
    localparam FLAG_X_END   = FLAG_X_START + 15;   // 깃발 폭 16px
    localparam FLAG_Y_TOP   = 80;                  // 깃발 위쪽
    localparam FLAG_Y_BOTTOM = 95;                 // 깃발 높이 16px

    // 체커보드 패턴 크기 (4x4 칸)
    localparam CHECKER_SIZE = 4;

    // ========================================
    // 영역 체크
    // ========================================
    logic in_pole_area;
    logic in_flag_area;
    logic [3:0] flag_local_x;
    logic [3:0] flag_local_y;
    logic checker_pattern;

    assign in_pole_area = (x >= POLE_X_START && x <= POLE_X_END) &&
                          (y >= POLE_Y_TOP && y < POLE_Y_BOTTOM);

    assign in_flag_area = (x >= FLAG_X_START && x <= FLAG_X_END) &&
                          (y >= FLAG_Y_TOP && y < FLAG_Y_BOTTOM);

    // 깃발 내 로컬 좌표
    assign flag_local_x = x - FLAG_X_START;
    assign flag_local_y = y - FLAG_Y_TOP;

    // 체커보드 패턴 계산
    // (x/4 + y/4) % 2 = 0이면 흰색, 1이면 검은색
    assign checker_pattern = ((flag_local_x[3:2] + flag_local_y[3:2]) & 1'b1);

    // ========================================
    // 렌더링
    // ========================================
    always_comb begin
        if (in_pole_area) begin
            // 깃대: 밝은 회색
            color = '{r: 8'hE0, g: 8'hE0, b: 8'hE0};
            enable = 1'b1;
        end else if (in_flag_area) begin
            // 깃발: 체커보드 패턴
            if (checker_pattern) begin
                color = BLACK;  // 검은색
            end else begin
                color = WHITE;  // 흰색
            end
            enable = 1'b1;
        end else begin
            enable = 1'b0;
            color = TRANSPARENT;
        end
    end

endmodule

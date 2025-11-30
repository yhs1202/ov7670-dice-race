// dirt_renderer.sv
// 흙 렌더러 (150 ~ 180px, 높이 30px)
// Minecraft 스타일 흙 패턴

import color_pkg::*;

module dirt_renderer (
    input  logic [9:0] x,        // 0 ~ 639
    input  logic [9:0] y,        // 0 ~ 479
    output rgb_t       color,    // RGB 출력
    output logic       enable    // 이 영역에 그릴지 여부
);

    // 흙 영역: 150 <= y < 180
    logic [1:0] pattern_x;
    logic [1:0] pattern_y;
    logic [3:0] pattern_code;

    // 4x4 타일 패턴 생성 (x, y의 하위 2비트 사용)
    assign pattern_x = x[2:1];
    assign pattern_y = (y - 150) >> 1;  // y를 150 기준으로 정규화
    assign pattern_code = {pattern_x, pattern_y};

    always_comb begin
        if (y >= 150 && y < 180) begin
            enable = 1'b1;

            // 4x4 반복 패턴으로 Minecraft 흙 느낌
            case (pattern_code)
                4'b0000, 4'b0101, 4'b1010, 4'b1111: color = DIRT_DARK;   // 어두운 갈색
                4'b0001, 4'b0100, 4'b1001, 4'b1100: color = DIRT_MID;    // 중간 갈색
                4'b0010, 4'b0111, 4'b1000, 4'b1101: color = DIRT_LIGHT;  // 밝은 갈색
                4'b0011, 4'b0110, 4'b1011, 4'b1110: color = DIRT_GRAY;   // 회색 (돌)
                default: color = DIRT_MID;
            endcase
        end else begin
            enable = 1'b0;
            color = BLACK;  // don't care
        end
    end

endmodule

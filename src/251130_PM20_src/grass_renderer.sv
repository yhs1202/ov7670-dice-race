// grass_renderer.sv
// 잔디 렌더러 (140 ~ 150px, 높이 10px)

import color_pkg::*;

module grass_renderer (
    input  logic [9:0] x,        // 0 ~ 639
    input  logic [9:0] y,        // 0 ~ 479
    output rgb_t       color,    // RGB 출력
    output logic       enable    // 이 영역에 그릴지 여부
);

    // 잔디 영역: 140 <= y < 150
    always_comb begin
        if (y >= 140 && y < 150) begin
            enable = 1'b1;

            // 맨 윗줄(y=140)은 밝은 초록, 나머지는 진한 초록
            if (y == 140) begin
                color = GRASS_BRIGHT;  // 밝은 초록 (Minecraft 스타일)
            end else begin
                color = GRASS_GREEN;   // 진한 초록
            end
        end else begin
            enable = 1'b0;
            color = BLACK;  // don't care
        end
    end

endmodule

// sky_renderer.sv
// 하늘 배경 렌더러 (0 ~ 140px)

import color_pkg::*;

module sky_renderer (
    input  logic [9:0] x,        // 0 ~ 639
    input  logic [9:0] y,        // 0 ~ 479
    output rgb_t       color,    // RGB 출력
    output logic       enable    // 이 영역에 그릴지 여부
);

    // 하늘 영역: y < 140
    always_comb begin
        if (y < 140) begin
            enable = 1'b1;

            // 그라데이션 (위: 밝은 하늘, 아래: 진한 하늘)
            if (y < 70) begin
                color = SKY_LIGHT_BLUE;
            end else begin
                color = SKY_BLUE;
            end
        end else begin
            enable = 1'b0;
            color = BLACK;  // don't care
        end
    end

endmodule

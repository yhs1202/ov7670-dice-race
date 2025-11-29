// player_renderer.sv
// IC 칩 모양 플레이어 (16x16 픽셀, 좌우 핀)

import color_pkg::*;

module player_renderer (
    input  logic [9:0] x,           // 화면 x 좌표
    input  logic [9:0] y,           // 화면 y 좌표
    input  logic [9:0] player_x,    // 플레이어 x 위치
    input  logic [9:0] player_y,    // 플레이어 y 위치
    input  logic       player_id,   // 0=Player1(빨강), 1=Player2(파랑)
    output rgb_t       color,       // RGB 출력
    output logic       enable       // 이 픽셀 그릴지 여부
);

    // 플레이어 영역 체크 (16x16)
    logic in_player_area;
    logic [3:0] sprite_x;  // 0~15
    logic [3:0] sprite_y;  // 0~15

    assign in_player_area = (x >= player_x) && (x < player_x + 16) &&
                            (y >= player_y) && (y < player_y + 16);
    assign sprite_x = x - player_x;
    assign sprite_y = y - player_y;

    // IC 칩 스프라이트 (16x16, 좌우 핀)
    // . = 투명, S = 핀(은색), G = 테두리(회색), B = 몸체(검정), R = 빨간점
    always_comb begin
        if (in_player_area) begin
            case (sprite_y)
                // Row 0: 상단 테두리
                4'd0: begin
                    if (sprite_x >= 2 && sprite_x <= 13) begin
                        color = IC_GRAY;
                        enable = 1'b1;
                    end else begin
                        enable = 1'b0;
                        color = TRANSPARENT;
                    end
                end

                // Row 1: 테두리 + 몸체
                4'd1: begin
                    if (sprite_x == 1 || sprite_x == 14) begin
                        color = IC_GRAY;
                        enable = 1'b1;
                    end else if (sprite_x >= 2 && sprite_x <= 13) begin
                        color = IC_BLACK;
                        enable = 1'b1;
                    end else begin
                        enable = 1'b0;
                        color = TRANSPARENT;
                    end
                end

                // Row 2-3: 색상 점 (플레이어 구분)
                4'd2, 4'd3: begin
                    if (sprite_x == 1 || sprite_x == 14) begin
                        color = IC_GRAY;
                        enable = 1'b1;
                    end else if (sprite_x >= 6 && sprite_x <= 7) begin
                        // Player 1: 빨강, Player 2: 파랑
                        color = player_id ? '{r: 8'h00, g: 8'h00, b: 8'hFF} : IC_RED;
                        enable = 1'b1;
                    end else if (sprite_x >= 2 && sprite_x <= 13) begin
                        color = IC_BLACK;
                        enable = 1'b1;
                    end else begin
                        enable = 1'b0;
                        color = TRANSPARENT;
                    end
                end

                // Row 4-11: 좌우 핀 + 몸체
                4'd4, 4'd5, 4'd6, 4'd7, 4'd8, 4'd9, 4'd10, 4'd11: begin
                    if (sprite_x <= 1 || sprite_x >= 14) begin
                        color = IC_SILVER;  // 좌우 핀
                        enable = 1'b1;
                    end else if (sprite_x == 2 || sprite_x == 13) begin
                        color = IC_GRAY;    // 테두리
                        enable = 1'b1;
                    end else if (sprite_x >= 3 && sprite_x <= 12) begin
                        color = IC_BLACK;   // 몸체
                        enable = 1'b1;
                    end else begin
                        enable = 1'b0;
                        color = TRANSPARENT;
                    end
                end

                // Row 12-14: 테두리 + 몸체
                4'd12, 4'd13, 4'd14: begin
                    if (sprite_x == 1 || sprite_x == 14) begin
                        color = IC_GRAY;
                        enable = 1'b1;
                    end else if (sprite_x >= 2 && sprite_x <= 13) begin
                        color = IC_BLACK;
                        enable = 1'b1;
                    end else begin
                        enable = 1'b0;
                        color = TRANSPARENT;
                    end
                end

                // Row 15: 하단 테두리
                4'd15: begin
                    if (sprite_x >= 2 && sprite_x <= 13) begin
                        color = IC_GRAY;
                        enable = 1'b1;
                    end else begin
                        enable = 1'b0;
                        color = TRANSPARENT;
                    end
                end

                default: begin
                    enable = 1'b0;
                    color = TRANSPARENT;
                end
            endcase
        end else begin
            enable = 1'b0;
            color = TRANSPARENT;
        end
    end

endmodule


`timescale 1ns / 1ps
import color_pkg::*;


// ============================================
// UI 렌더러 (Top Module)
// ============================================
module ui_render (
    input  logic       clk,
    input  logic [9:0] x,          // 0 ~ 639
    input  logic [9:0] y,          // 0 ~ 479
    input  logic [9:0] player_x,   // 플레이어 x 위치
    input  logic [9:0] player_y,   // 플레이어 y 위치
    output logic [7:0] r,          // Red
    output logic [7:0] g,          // Green
    output logic [7:0] b           // Blue
);

    // 렌더러 신호
    rgb_t  sky_color, grass_color, dirt_color, player_color;
    logic  sky_en, grass_en, dirt_en, player_en;

    // 배경 렌더러
    sky_renderer sky_inst (
        .x(x), .y(y),
        .color(sky_color),
        .enable(sky_en)
    );

    grass_renderer grass_inst (
        .x(x), .y(y),
        .color(grass_color),
        .enable(grass_en)
    );

    dirt_renderer dirt_inst (
        .x(x), .y(y),
        .color(dirt_color),
        .enable(dirt_en)
    );

    // 플레이어 렌더러
    player_renderer player_inst (
        .x(x), .y(y),
        .player_x(player_x),
        .player_y(player_y),
        .color(player_color),
        .enable(player_en)
    );

    // 레이어 합성 (우선순위: player > dirt > grass > sky)
    rgb_t final_color;

    always_comb begin
        final_color = BLACK;  // 기본 배경

        if (sky_en) begin
            final_color = sky_color;
        end

        if (grass_en) begin
            final_color = grass_color;
        end

        if (dirt_en) begin
            final_color = dirt_color;
        end

        if (player_en) begin
            final_color = player_color;
        end
    end

    // 출력 (1 clock delay 통해서 출력) // 타이밍 맞추기 위해서 1clk 지연 했습니다.
    always_ff @(posedge clk) begin
        r <= final_color.r;
        g <= final_color.g;
        b <= final_color.b;
    end

endmodule

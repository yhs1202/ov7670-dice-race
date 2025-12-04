`timescale 1ns / 1ps

import color_pkg::*;

module UI_Generator (
    input logic       clk,
    input logic       reset,
    input logic [9:0] x_pixel,
    input logic [9:0] y_pixel,

    input logic is_intro_state,
    input logic menu_select,

    input  logic [3:0] p1_pos,
    input  logic [3:0] p2_pos,
    output logic       turn_done,
    input  logic       pos_valid,
    input  logic       winner_valid,
    input  logic       turn,

    // VGA 출력
    output logic [3:0] ui_r,
    output logic [3:0] ui_g,
    output logic [3:0] ui_b,
    output logic       ui_enable
);

    logic [9:0] p1_target_x, p1_target_y;
    logic [9:0] p2_target_x, p2_target_y;

    logic [11:0] intro_rgb_data;
    logic [7:0] game_r8, game_g8, game_b8;
    logic finish_pixel_en;

    // Camera Labels
    rgb_t label_color;
    logic label_enable;

    // Camera Border
    logic is_camera_border;
    // Border thickness: Horizontal 12px, Vertical 16px (12+4), Color Kirby Pink
    assign is_camera_border = (y_pixel >= 240) && (
        (y_pixel < 240 + 12) ||          // Top (12px)
        (y_pixel >= 480 - 12) ||         // Bottom (12px)
        (x_pixel < 12) ||                // Left (12px)
        (x_pixel >= 640 - 12) ||         // Right (12px)
        (x_pixel >= 312 && x_pixel < 328) // Middle separator (Center 320, Width 16)
    );

    tile_position_mapper U_Tile_Pos_Mapper_P1 (
        .tile_idx(p1_pos),
        .x       (p1_target_x),
        .y       (p1_target_y)
    );

    tile_position_mapper U_Tile_Pos_Mapper_P2 (
        .tile_idx(p2_pos),
        .x       (p2_target_x),
        .y       (p2_target_y)
    );

    UI_Intro_Renderer #(
        .TITLE_LINE1("DICE RACE"),
        .TITLE_LINE2(""),
        .SUBTITLE   ("2025 VGA PROJECT"),
        .MENU_ITEM1 ("START GAME"),
        .MENU_ITEM2 ("END GAME")
    ) U_UI_Intro_Renderer (
        .pixel_x    (x_pixel),
        .pixel_y    (y_pixel),
        .menu_select(menu_select),
        .pixel_color(intro_rgb_data)
    );

    UI_Game_Renderer U_UI_Game_Renderer (
        .clk          (clk),
        .rst          (reset),
        .x            (x_pixel),
        .y            (y_pixel),
        .player1_pos_x(p1_target_x),
        .player2_pos_x(p2_target_x),
        .turn_done    (turn_done),
        .pos_valid    (pos_valid),
        .winner_valid (winner_valid),
        .active_player(turn),
        .r            (game_r8),
        .g            (game_g8),
        .b            (game_b8),
        .finish_pixel_en(finish_pixel_en)
    );

    camera_label_renderer U_Camera_Labels (
        .pixel_x(x_pixel),
        .pixel_y(y_pixel),
        .color(label_color),
        .enable(label_enable)
    );

    //  최종 UI 출력 로직   -> ui_endable =1 일 때만 ui_r,ui_g,ui_b 값이 출력
    // 우선순위: Intro > Game > Camera Labels > Camera Border
    // 카메라 테두리는 최하위 우선순위로, 다른 UI가 없을 때만 표시하도록 함
    // 우선순위 구현 방법은 if else if else 구조로 가장 먼저 참이 되는 조건이 가장 높은 우선순위를 가짐
    always_comb begin
        ui_r = 0;
        ui_g = 0;
        ui_b = 0;
        ui_enable = 0;
        if (is_intro_state) begin
            ui_r      = intro_rgb_data[11:8];
            ui_g      = intro_rgb_data[7:4];
            ui_b      = intro_rgb_data[3:0];
            ui_enable = 1'b1;
        end else begin
            if (y_pixel < 240 || finish_pixel_en) begin
                ui_r      = game_r8[7:4];
                ui_g      = game_g8[7:4];
                ui_b      = game_b8[7:4];
                ui_enable = 1'b1;
            end else if (label_enable) begin
                ui_r      = label_color.r[7:4];
                ui_g      = label_color.g[7:4];
                ui_b      = label_color.b[7:4];
                ui_enable = 1'b1;
            end else if (is_camera_border) begin
                ui_r      = KIRBY_PINK.r[7:4];
                ui_g      = KIRBY_PINK.g[7:4];
                ui_b      = KIRBY_PINK.b[7:4];
                ui_enable = 1'b1;
            end else begin
                ui_r = 0;
                ui_g = 0;
                ui_b = 0;
                ui_enable = 1'b0;
            end
        end
    end
endmodule

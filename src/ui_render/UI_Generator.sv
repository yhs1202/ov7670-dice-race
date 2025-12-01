`timescale 1ns / 1ps

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
        .TITLE_LINE1("DICE"),
        .TITLE_LINE2("RACE"),
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
        .b            (game_b8)
    );

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
            if (y_pixel < 240) begin
                ui_r      = game_r8[7:4];
                ui_g      = game_g8[7:4];
                ui_b      = game_b8[7:4];
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

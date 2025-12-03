// ui_render.sv
// VGA UI 렌더러 (Top Module)
// 플레이어 2명, 턴제 게임 지원
// Game Logic 인터페이스: pos_x + pos_valid

import color_pkg::*;

module UI_Game_Renderer (
    input  logic       clk,
    input  logic       rst,
    input  logic [9:0] x, y,

    // Game Logic 인터페이스 (턴제 게임)
    input  logic [9:0] player1_pos_x,      // Player 1 목표 x 좌표
    input  logic [9:0] player2_pos_x,      // Player 2 목표 x 좌표
    output logic       turn_done,          // 턴 완료 (1 cycle pulse)
    input  logic       pos_valid,          // 위치 업데이트 (1 cycle pulse)
    input  logic       winner_valid,       // 승리자 발생 여부
    input  logic       active_player,      // 0=Player1, 1=Player2

    // VGA 출력
    output logic [7:0] r, g, b
);

    // ========================================
    // 내부 신호
    // ========================================
    logic [9:0] player1_x, player1_y, player2_x, player2_y;
    rgb_t sky_color, grass_color, dirt_color, flag_color, player1_color, player2_color;
    logic sky_en, grass_en, dirt_en, flag_en, player1_en, player2_en;
    
    // Finish Screen Signals
    rgb_t finish_color;
    logic finish_enable;

    // Question Box Signals
    rgb_t qbox2_color, qbox4_color, qbox6_color, qbox8_color;
    logic qbox2_en, qbox4_en, qbox6_en, qbox8_en;

    // ========================================
    // 플레이어 컨트롤러
    // ========================================
    player_controller ctrl (
        .clk(clk),
        .rst(rst),
        .player1_pos_x(player1_pos_x),
        .player2_pos_x(player2_pos_x),
        .pos_valid(pos_valid),
        .active_player(active_player),
        .player1_x(player1_x),
        .player1_y(player1_y),
        .player2_x(player2_x),
        .player2_y(player2_y),
        .turn_done(turn_done)
    );

    // ========================================
    // 배경 렌더러
    // ========================================
    sky_renderer sky_inst (
        .x(x),
        .y(y),
        .color(sky_color),
        .enable(sky_en)
    );

    grass_renderer grass_inst (
        .x(x),
        .y(y),
        .color(grass_color),
        .enable(grass_en)
    );

    dirt_renderer dirt_inst (
        .x(x),
        .y(y),
        .color(dirt_color),
        .enable(dirt_en)
    );

    // ========================================
    // 깃발 렌더러
    // ========================================
    flag_renderer flag_inst (
        .x(x),
        .y(y),
        .color(flag_color),
        .enable(flag_en)
    );

    // ========================================
    // 물음표 박스 렌더러 (2, 4, 6, 8번 타일)
    // Y 위치: 80 (점프 시 닿을 정도의 높이)
    // ========================================
    question_box_renderer qbox2_inst (
        .x(x), .y(y),
        .box_x(10'd140), .box_y(10'd80),
        .color(qbox2_color), .enable(qbox2_en)
    );

    question_box_renderer qbox4_inst (
        .x(x), .y(y),
        .box_x(10'd260), .box_y(10'd80),
        .color(qbox4_color), .enable(qbox4_en)
    );

    question_box_renderer qbox6_inst (
        .x(x), .y(y),
        .box_x(10'd380), .box_y(10'd80),
        .color(qbox6_color), .enable(qbox6_en)
    );

    question_box_renderer qbox8_inst (
        .x(x), .y(y),
        .box_x(10'd500), .box_y(10'd80),
        .color(qbox8_color), .enable(qbox8_en)
    );

    // ========================================
    // 플레이어 렌더러 (2명)
    // ========================================
    player_renderer player1_inst (
        .x(x),
        .y(y),
        .player_x(player1_x),
        .player_y(player1_y),
        .player_id(1'b0),           // Player 1 (빨강)
        .color(player1_color),
        .enable(player1_en)
    );

    player_renderer player2_inst (
        .x(x),
        .y(y),
        .player_x(player2_x),
        .player_y(player2_y),
        .player_id(1'b1),           // Player 2 (파랑)
        .color(player2_color),
        .enable(player2_en)
    );

    // ========================================
    // Finish Screen 렌더러
    // ========================================
    finish_text_renderer finish_inst (
        .x(x),
        .y(y),
        .text_x(10'd294),
        .text_y(10'd236),
        .color(finish_color),
        .enable(finish_enable)
    );

    // ========================================
    // 레이어 합성 (우선순위: finish > player1 > player2 > flag > dirt > grass > sky)
    // ========================================
    rgb_t final_color;

    always_comb begin
        final_color = BLACK;

        if (sky_en)     final_color = sky_color;
        if (grass_en)   final_color = grass_color;
        if (dirt_en)    final_color = dirt_color;
        
        // 물음표 박스 레이어 (배경 위, 플레이어 뒤)
        if (qbox2_en)   final_color = qbox2_color;
        if (qbox4_en)   final_color = qbox4_color;
        if (qbox6_en)   final_color = qbox6_color;
        if (qbox8_en)   final_color = qbox8_color;

        if (flag_en)    final_color = flag_color;
        if (player2_en) final_color = player2_color;
        if (player1_en) final_color = player1_color;
        
        // Finish 화면이 최상위 레이어
        if (winner_valid && finish_enable) begin
            final_color = finish_color;
        end
    end

    // ========================================
    // VGA 출력 (1 clock delay)
    // ========================================
    always_ff @(posedge clk) begin
        r <= final_color.r;
        g <= final_color.g;
        b <= final_color.b;
    end

endmodule

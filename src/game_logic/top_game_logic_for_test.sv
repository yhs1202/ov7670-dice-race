`timescale 1ns / 1ps
import color_pkg::*;

// appended game_logic to ui_render for testing
module top_game_logic_for_test (
    input logic clk,
    input logic reset,

    // drive with switches for test
    input logic start_btn,      // Test for Btn_U
    input logic event_end_tick, // Test for Btn_R
    input logic dice_valid,     // Test for Btn_L
    input logic [1:0] dice_value,

    output logic [3:0] r_port,
    output logic [3:0] g_port,
    output logic [3:0] b_port,
    output logic       h_sync,
    output logic       v_sync,

    output logic [15:0] led_output,

    output logic [3:0]  fnd_com,
    output logic [7:0]  fnd_data
);

    // Game Logic Signals
    logic [3:0] p1_pos;
    logic [3:0] p2_pos;
    logic [9:0] p1_target_x, p1_target_y;
    logic [9:0] p2_target_x, p2_target_y;
    logic winner_valid;
    logic winner_id;
    logic turn;
    logic pos_valid;
    logic turn_done;

    logic [3:0] event_flag;

    // Debounced Signals
    logic start_btn_db_out;
    logic dice_valid_db_out;
    logic event_end_tick_db_out;
    // logic [15:0] led_output;

    tile_position_mapper tile_pos_mapper_inst_p1 (
        .tile_idx (p1_pos),
        .x        (p1_target_x),
        .y        (p1_target_y)
    );

    tile_position_mapper tile_pos_mapper_inst_p2 (
        .tile_idx (p2_pos),
        .x        (p2_target_x),
        .y        (p2_target_y)
    );

    // Debounce for start_btn, (Btn_U)
    btn_debounce start_btn_db (
        .clk      (clk),
        .rst      (reset),
        .btn_in   (start_btn),
        .btn_out  (start_btn_db_out)
    );

    // Debounce for dice_valid, for test (Btn_L)
    btn_debounce dice_valid_db (
        .clk      (clk),
        .rst      (reset),
        .btn_in   (dice_valid),
        .btn_out  (dice_valid_db_out)
    );

    // Debounce for event_end_tick, for test (Btn_R)
    btn_debounce event_end_tick_db (
        .clk      (clk),
        .rst      (reset),
        .btn_in   (event_end_tick),
        .btn_out  (event_end_tick_db_out)
    );

    game_logic game_logic_inst (
        .clk        (clk),
        .reset      (reset),
        .start_btn  (start_btn_db_out),
        .event_end_tick (event_end_tick_db_out),
        .dice_valid (dice_valid_db_out),    // for test
        // .start_btn  (start_btn),
        // .dice_valid (dice_valid),
        // .event_end_tick (event_end_tick),
        .dice_value (dice_value),
        .turn_done  (turn_done),            // Connect turn_done
        .pos_valid  (pos_valid),            // Connect pos_valid

        .p1_pos     (p1_pos),
        .p2_pos     (p2_pos),
        .winner_valid(winner_valid),
        .winner_id  (winner_id),
        .turn       (turn),
        .led_output (led_output),
        .fnd_com    (fnd_com),
        .fnd_data   (fnd_data),
        .event_flag (event_flag)
    );

    ///////////////// UI Render Signals //////////////////////
    // 1) Pixel Clock 생성 (25MHz enable)
    logic pclk;

    clk_div #(.DIV_VALUE(4)) pixel_clk_inst (
        .clk     (clk),
        .rst     (reset),
        .clk_out (pclk)
    );

    
    // 2) VGA Sync (x,y,DE 생성)
    logic [9:0] x;
    logic [9:0] y;
    logic       DE;

    VGA_Syncher sync_inst (
        .clk     (pclk),
        .reset   (reset),
        .h_sync  (h_sync),
        .v_sync  (v_sync),
        .DE      (DE),
        .x_pixel (x),
        .y_pixel (y)
    );

    
    // 3) Player 좌표 (일단 테스트로 중앙에 했습니다)
    // logic [9:0] player1_x = 200;
    // logic [9:0] player1_y = 320;

    
    // 4) UI Render Core    
    logic [7:0] r8, g8, b8;

    ui_render ui_inst (
        .clk      (pclk),
        .rst      (reset),
        .x        (x),
        .y        (y),
        .player1_pos_x (p1_target_x),
        .player2_pos_x (p2_target_x),
        .pos_valid     (pos_valid),
        .active_player (turn),
        .winner_valid  (winner_valid),
        .turn_done     (turn_done),
        .r        (r8),
        .g        (g8),
        .b        (b8)
    );

    
    // 5) 8bit → 4bit VGA 출력 변환    
    always_comb begin
        if (DE) begin
            r_port = r8[7:4];
            g_port = g8[7:4];
            b_port = b8[7:4];
        end else begin
            r_port = 4'd0;
            g_port = 4'd0;
            b_port = 4'd0;
        end
    end

endmodule

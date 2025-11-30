`timescale 1ns / 1ps
import color_pkg::*;

// appended game_logic to ui_render for testing
module top_game_logic_for_test (
    input logic clk,
    input logic reset, // BtnC

    // Buttons
    input logic start_btn,      // BtnU (Intro: Up, Game: Start)
    input logic event_end_tick, // BtnR (Intro: Down, Game: Test Event)
    input logic dice_valid,     // BtnL (Intro: Confirm, Game: Dice)
    input logic [1:0] dice_value, // Switches

    output logic [3:0] r_port,
    output logic [3:0] g_port,
    output logic [3:0] b_port,
    output logic       h_sync,
    output logic       v_sync,

    output logic [15:0] led_output,
    output logic [3:0]  fnd_com,
    output logic [7:0]  fnd_data
);

    // =========================================================================
    // 1. Global Signals & Clock Generation
    // =========================================================================
    logic pclk;
    clk_div #(.DIV_VALUE(4)) pixel_clk_inst (
        .clk     (clk),
        .rst     (reset),
        .clk_out (pclk)
    );

    logic [9:0] x, y;
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

    // =========================================================================
    // 2. State Machine (Intro vs Game)
    // =========================================================================
    typedef enum logic { STATE_INTRO, STATE_GAME } sys_state_t;
    sys_state_t current_state;

    logic intro_start_game; // Signal from Intro Logic to start game

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            current_state <= STATE_INTRO;
        end else begin
            if (current_state == STATE_INTRO && intro_start_game) begin
                current_state <= STATE_GAME;
            end
        end
    end

    // =========================================================================
    // 3. Input Debouncing (Shared)
    // =========================================================================
    logic btn_u_db, btn_d_db, btn_c_db; // Mapped to U, R, L
    
    btn_debounce db_u (.clk(clk), .rst(reset), .btn_in(start_btn),      .btn_out(btn_u_db));
    btn_debounce db_d (.clk(clk), .rst(reset), .btn_in(event_end_tick), .btn_out(btn_d_db)); // Use BtnR as Down
    btn_debounce db_c (.clk(clk), .rst(reset), .btn_in(dice_valid),     .btn_out(btn_c_db)); // Use BtnL as Confirm

    // =========================================================================
    // 4. Intro UI Logic & Render
    // =========================================================================
    logic menu_select; // 0: Start, 1: End
    logic btn_u_prev, btn_d_prev, btn_c_prev;
    
    // Intro Logic (Running on system clk)
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            menu_select <= 0;
            intro_start_game <= 0;
            btn_u_prev <= 0;
            btn_d_prev <= 0;
            btn_c_prev <= 0;
        end else if (current_state == STATE_INTRO) begin
            btn_u_prev <= btn_u_db;
            btn_d_prev <= btn_d_db;
            btn_c_prev <= btn_c_db;

            if (btn_u_db && !btn_u_prev) menu_select <= 0; // Up -> Start
            if (btn_d_db && !btn_d_prev) menu_select <= 1; // Down -> End

            if (btn_c_db && !btn_c_prev) begin
                if (menu_select == 0) intro_start_game <= 1;
                // else: End Game (Do nothing or reset)
            end
        end
    end

    logic [11:0] intro_pixel_color;
    // Instantiate ui_renderer from intro_ui_src
    ui_renderer #(
        .TITLE_LINE1("DICE"), .TITLE_LINE2("RACE"), .SUBTITLE("2025 VGA PROJECT"),
        .MENU_ITEM1("START GAME"), .MENU_ITEM2("END GAME")
    ) intro_renderer_inst (
        .pixel_x(x),
        .pixel_y(y),
        .menu_select(menu_select),
        .pixel_color(intro_pixel_color)
    );

    // =========================================================================
    // 5. Game Logic & Render
    // =========================================================================
    // Game Logic Signals
    logic [3:0] p1_pos, p2_pos;
    logic [9:0] p1_target_x, p1_target_y, p2_target_x, p2_target_y;
    logic winner_valid, winner_id, turn, pos_valid, turn_done;
    logic [3:0] event_flag;
    logic [3:0] fnd_com_game;
    logic [7:0] fnd_data_game;
    logic [15:0] led_output_game;

    tile_position_mapper tile_pos_mapper_inst_p1 (.tile_idx(p1_pos), .x(p1_target_x), .y(p1_target_y));
    tile_position_mapper tile_pos_mapper_inst_p2 (.tile_idx(p2_pos), .x(p2_target_x), .y(p2_target_y));

    // Only pass buttons to game logic if in GAME state
    logic game_start_btn_in, game_dice_valid_in;
    assign game_start_btn_in = (current_state == STATE_GAME) ? btn_u_db : 1'b0;
    assign game_dice_valid_in = (current_state == STATE_GAME) ? btn_c_db : 1'b0;

    game_logic game_logic_inst (
        .clk(clk), .reset(reset),
        .start_btn(game_start_btn_in),
        .event_end_tick(1'b0), // Disable test button for now
        .dice_valid(game_dice_valid_in),
        .dice_value(dice_value),
        .turn_done(turn_done),
        .pos_valid(pos_valid),
        .p1_pos(p1_pos), .p2_pos(p2_pos),
        .winner_valid(winner_valid), .winner_id(winner_id),
        .turn(turn),
        .led_output(led_output_game),
        .fnd_com(fnd_com_game), .fnd_data(fnd_data_game),
        .event_flag(event_flag)
    );

    logic [7:0] game_r8, game_g8, game_b8;
    ui_render ui_inst (
        .clk(pclk), .rst(reset),
        .x(x), .y(y),
        .player1_pos_x(p1_target_x), .player2_pos_x(p2_target_x),
        .pos_valid(pos_valid), .active_player(turn),
        .winner_valid(winner_valid), .turn_done(turn_done),
        .r(game_r8), .g(game_g8), .b(game_b8)
    );

    // =========================================================================
    // 6. Output MUX
    // =========================================================================
    always_comb begin
        if (DE) begin
            if (current_state == STATE_INTRO) begin
                r_port = intro_pixel_color[11:8];
                g_port = intro_pixel_color[7:4];
                b_port = intro_pixel_color[3:0];
            end else begin
                r_port = game_r8[7:4];
                g_port = game_g8[7:4];
                b_port = game_b8[7:4];
            end
        end else begin
            r_port = 0; g_port = 0; b_port = 0;
        end
    end

    // Debugging LEDs
    // LED[0]: Current State (OFF=Intro, ON=Game)
    // LED[1]: DE Signal (Should be ON/Dim)
    // LED[2]: Intro Color Valid (Should be ON if Intro is rendering anything)
    // LED[15:12]: Event Flag (Game Mode)
    
    assign led_output[0] = (current_state == STATE_GAME);
    assign led_output[1] = DE; 
    assign led_output[2] = |intro_pixel_color; 

    assign led_output[15:12] = (current_state == STATE_GAME) ? event_flag : 4'h0;
    assign led_output[11:3]  = (current_state == STATE_GAME) ? led_output_game[11:3] : 9'h0;
    
    assign fnd_com = (current_state == STATE_GAME) ? fnd_com_game : 4'hF;
    assign fnd_data = (current_state == STATE_GAME) ? fnd_data_game : 8'hFF;

endmodule

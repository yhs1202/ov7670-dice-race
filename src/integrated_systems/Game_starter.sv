`timescale 1ns/1ps
module Game_starter (
    input  logic clk,
    input  logic reset,
    input  logic start_btn,
    input  logic select_option_btn,

    output logic menu_select,
    output logic is_intro,
    output logic is_game,
    output logic game_start_tick
);

    // Debounced button signals
    logic btn_start_db;
    logic btn_option_db;

    // Instantiate debouncers
    btn_debounce U_Btn_Start (
        .clk    (clk),
        .reset  (reset),
        .btn_in (start_btn),
        .btn_out(btn_start_db)
    );

    btn_debounce U_Btn_Option (
        .clk    (clk),
        .reset  (reset),
        .btn_in (select_option_btn),
        .btn_out(btn_option_db)
    );

    typedef enum logic [1:0] {
        STATE_INTRO,
        STATE_GAME
    } game_state_t;
    game_state_t current_state;


    // Generate menu_select and game_start_tick signals
    always_ff @(posedge clk) begin
        if (reset) begin
            current_state <= STATE_INTRO;
            menu_select <= 1'b0;
        end else begin
            if (current_state == STATE_INTRO && btn_start_db) begin
                current_state <= STATE_GAME;
            end
            if (is_intro) begin
                if (btn_option_db) menu_select <= ~menu_select;
            end
        end
    end

    assign game_start_tick = (current_state == STATE_GAME) ? btn_start_db : 1'b0;
    assign is_intro = (current_state == STATE_INTRO);
    assign is_game  = (current_state == STATE_GAME);

endmodule

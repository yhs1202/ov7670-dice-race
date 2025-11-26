`timescale 1ns/1ps

module game_logic (
    input  logic clk,
    input  logic reset,
    input  logic start_btn,

    // dice interface (from camera processor)
    input  logic        dice_valid,   // (../color_detect/Color_Result_Manager.sv: result_ready)
    input  logic [1:0]  dice_value,   // expected 1~3, (../color_detect/Color_Result_Manager.sv: stable_color)

    // game status output
    // output logic [$clog2(640)-1:0]  p1_x_pos,   // player 1 position for display (0~640)
    // output logic [$clog2(640)-1:0]  p2_x_pos,   // player 2 position for display (0~640)
    output logic [3:0]  p1_pos, // positions of players (0~10)
    output logic [3:0]  p2_pos, // positions of players (0~10)
    output logic        winner_valid,
    output logic        winner_id,      // p1=0, p2=1

    // LED timeout display (16 LEDs)
    output logic [15:0] led_output
);

    // Constants
    localparam int HALF_SEC_MAX = 50_000_000; // 0.5 sec (assuming 100 MHz clock)

    // FSM Declaration
    typedef enum logic [2:0] {
        S_IDLE,
        S_WAIT_DICE,
        S_UPDATE_POS,
        S_CHECK_EVENT,
        S_NEXT_TURN,
        S_WIN
    } state_t;

    state_t state, next_state;

    // Internal Registers
    logic turn;   // 0 = player1, 1 = player2
    logic [3:0] next_pos;

    // Timeout + LED
    logic [3:0]  led_count;      // 16 → 0
    logic [31:0] half_sec_cnt;   // 0.5 sec counter


    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            state        <= S_IDLE;
            p1_pos       <= 0;
            p2_pos       <= 0;
            winner_valid <= 0;
            winner_id    <= 0;
            turn         <= 0;

            // LED + timer init
            led_count    <= 16;
            half_sec_cnt <= 0;
            led_output   <= 16'hFFFF;   // all on
        end else begin
            state <= next_state;

            case (state)
                S_IDLE: begin
                    // reset all game status
                    p1_pos       <= 0;
                    p2_pos       <= 0;
                    winner_valid <= 0;
                    winner_id    <= 0;
                    turn         <= 0;

                    // LED + timer init
                    led_count    <= 16;
                    half_sec_cnt <= 0;
                    led_output   <= 16'hFFFF;   // all on
                end

                // WAIT_DICE: timer + LED countdown
                S_WAIT_DICE: begin
                    if (!dice_valid) begin
                        // run 0.5 sec counter
                        if (half_sec_cnt == HALF_SEC_MAX - 1) begin
                            half_sec_cnt <= 0;

                            if (led_count > 0) begin  // initial led_count: 16
                                led_count  <= led_count - 1;
                                led_output <= led_output << 1; // shift left = turn off one LED
                            end else begin
                                // do nothing, timeout will be handled in next_state logic
                            end
                        end else begin
                            half_sec_cnt <= half_sec_cnt + 1;
                        end
                    end else begin
                        // reset timer + LED when dice is valid
                        half_sec_cnt <= 0;
                        led_count    <= 16;
                        led_output   <= (turn == 0) ? 16'hFF00 : 16'h00FF;  // indicate player turn
                    end
                end

                // UPDATE_POS: apply movement to player
                S_UPDATE_POS: begin
                    if (turn == 0) p1_pos <= next_pos;
                    else p2_pos <= next_pos;

                    // reset LED + timer for next cycle
                    led_count    <= 16;
                    half_sec_cnt <= 0;
                    led_output   <= 16'hFFFF;
                end

                S_CHECK_EVENT: begin
                    if (next_pos == 4) begin
                        // FILTER EVENT NEEDED, will be implemented later
                        if (turn == 0)
                            p1_pos <= 0;
                        else
                            p2_pos <= 0;
                    end

                    if (next_pos >= 10) begin
                        winner_valid <= 1;
                        winner_id    <= (turn == 0) ? 1 : 2;
                    end
                end

                // NEXT_TURN: flip turn, reset LED + timer
                S_NEXT_TURN: begin
                    turn <= ~turn;
                    led_count    <= 16;
                    half_sec_cnt <= 0;
                    led_output   <= (turn == 0) ? 16'hFF00 : 16'h00FF;  // indicate player turn
                end

                // S_WIN: hold state
                S_WIN: begin
                    // Game over effects can be added here if needed
                end

            endcase
        end
    end

    // Next Position Calculation
    always_comb begin
        if (turn == 1'b0)
            next_pos = p1_pos + dice_value;
        else
            next_pos = p2_pos + dice_value;
    end

    // FSM Next-State Logic
    always_comb begin
        next_state = state;
        case (state)
            S_IDLE:
                if (start_btn)
                    next_state = S_WAIT_DICE;

            S_WAIT_DICE: begin
                if (dice_valid)
                    next_state = S_UPDATE_POS;
                else if (led_count == 0)
                    next_state = S_NEXT_TURN;   // timeout
                else
                    next_state = S_WAIT_DICE;
            end

            S_UPDATE_POS:
                next_state = S_CHECK_EVENT;

            S_CHECK_EVENT: begin
                if (next_pos == 4)
                    next_state = S_NEXT_TURN;
                else if (next_pos >= 10)
                    next_state = S_WIN;
                else
                    next_state = S_NEXT_TURN;
            end

            S_NEXT_TURN:
                next_state = S_WAIT_DICE;

            S_WIN:
                next_state = S_WIN;
        endcase
    end


endmodule

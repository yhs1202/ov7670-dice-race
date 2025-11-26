`timescale 1ns/1ps

module game_logic (
    input  logic clk,
    input  logic reset,
    input  logic start_btn,

    // dice interface (from camera processor)
    input  logic        dice_valid,   // (../color_detect/Color_Result_Manager.sv: result_ready)
    input  logic [1:0]  dice_value,   // expected 1~3, (../color_detect/Color_Result_Manager.sv: stable_color)

    // game status output
    output logic [3:0]  p1_pos,         // positions of players (0~10)
    output logic [3:0]  p2_pos,         // positions of players (0~10)
    // 
    output logic        winner_valid,
    output logic        winner_id,      // 0 = player1, 1 = player2
    output logic        turn,           // 0 = player1, 1 = player2

    // LED timeout display (16 LEDs)
    output logic [15:0] led_output,

    // FND display output
    output logic [3:0]  fnd_com,
    output logic [7:0]  fnd_data
);

    // Constants
    localparam int SEC = 100_000_000; // 1 sec (assuming 100 MHz clock)
    // localparam int SEC = 50_000; // tb


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
    logic [3:0] next_pos;
    logic pos_valid;
    logic [15:0] led_output_reg;

    // Timeout + LED
    logic [3:0] time_elapsed; // 0 -> 7
    logic [31:0] sec_cnt;  // 0.5 sec counter


    assign led_output = led_output_reg;

    // FND Controller Instance for displaying current position
    fnd_controller U_FND_CTRL (
        .clk      (clk),
        .rst      (reset),
        .count_reg (next_pos),
        .fnd_com  (fnd_com),
        .fnd_data (fnd_data)
    );

    // FSM Sequential Logic
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            state        <= S_IDLE;
            p1_pos       <= 0;
            p2_pos       <= 0;
            winner_valid <= 0;
            winner_id    <= 0;
            turn         <= 0;
            pos_valid    <= 0;

            // LED + timer init
            time_elapsed <= 0;
            sec_cnt <= 0;
            led_output_reg <= 16'hFFFF;   // all on
        end else begin
            state <= next_state;

            case (state)
                S_IDLE: begin
                    // reset all game status
                    
                    sec_cnt <= 0;
                    time_elapsed <= 0;
                    led_output_reg <= 16'hFFFF;   // all on
                    pos_valid <= 0;
                    if (start_btn) begin
                        led_output_reg <= 16'hFF00;   // Player 1 First
                    end
                end

                // WAIT_DICE: timer + LED countdown
                S_WAIT_DICE: begin
                    if (!dice_valid) begin
                        if (sec_cnt == SEC - 1) begin // 1 sec elapsed
                            sec_cnt <= 0;
                            led_output_reg <= (turn == 0) ? ((led_output_reg << 1) & 16'hFF00) : ((led_output_reg >> 1) & 16'h00FF);
                            time_elapsed <= time_elapsed + 1;
                        end else begin
                            sec_cnt <= sec_cnt + 1;
                        end
                    end else begin  // (WAIT_DICE -> UPDATE_POS) reset timer + LED when dice is valid
                        sec_cnt <= 0;
                        time_elapsed <= 0;
                        led_output_reg <= (turn == 0) ? 16'hFF00 : 16'h00FF;  // indicate player turn
                    end 
                end

                // UPDATE_POS: apply movement to player
                S_UPDATE_POS: begin
                    pos_valid <= 1;
                    if (turn == 0) p1_pos <= next_pos;
                    else p2_pos <= next_pos;
                end                 

                S_CHECK_EVENT: begin
                    if (next_pos == 3) begin
                        // FILTER EVENT NEEDED, will be implemented later
                        led_output_reg <= 16'hF0F0; // indicate event tile
                        if (turn == 0)
                            p1_pos <= 0;
                        else
                            p2_pos <= 0;
                    end

                    if (next_pos >= 10) begin
                        winner_valid <= 1;
                        winner_id    <= (turn == 0) ? 1 : 2;
                    end
                    pos_valid <= 0;
                end

                // NEXT_TURN: flip turn, reset LED + timer
                S_NEXT_TURN: begin
                    turn <= ~turn;
                    time_elapsed <= 0;
                    sec_cnt <= 0;
                    led_output_reg <= 16'hFFFF;
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
            S_IDLE: begin
                if (start_btn)
                    next_state = S_WAIT_DICE;
            end

            S_WAIT_DICE: begin
                if (dice_valid)
                    next_state = S_UPDATE_POS;
                else if (time_elapsed == 8)
                    next_state = S_NEXT_TURN;   // timeout
                else
                    next_state = S_WAIT_DICE;
            end

            S_UPDATE_POS: begin
                next_state = S_CHECK_EVENT;
            end

            S_CHECK_EVENT: begin
                if (next_pos == 3) begin
                    next_state = S_NEXT_TURN;
                end else if (next_pos >= 10)
                    next_state = S_WIN;
                else
                    next_state = S_NEXT_TURN;
            end

            S_NEXT_TURN: begin
                next_state = S_WAIT_DICE;
            end

            S_WIN: begin
                next_state = S_WIN;
            end
        endcase
    end


endmodule

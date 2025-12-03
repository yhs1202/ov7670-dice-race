`timescale 1ns / 1ps

module Game_Logic_Controller (
    input  logic clk,
    input  logic reset,
    input  logic start_btn,


    // dice interface (from camera processor)
    input  logic        dice_valid,   // (../color_detect/Color_Result_Manager.sv: result_ready)
    input  logic [1:0]  dice_value,   // detected color: 01=RED, 10=GREEN, 11=BLUE
    input  logic        white_stable, // Level signal: currently detecting WHITE (for turn separation)

    // UI synchronization (Added for integration)
    input  logic        turn_done,    // Signal from UI when animation is complete

    // game status output
    output logic [3:0]  p1_pos,         // positions of players (0~10)
    output logic [3:0]  p2_pos,         // positions of players (0~10)
    // 
    output logic        winner_valid,
    output logic        winner_id,      // 0 = player1, 1 = player2
    output logic        turn,           // 0 = player2, 1 = player2
    output logic        pos_valid,      // Position update signal (Added as output)

    // LED timeout display (16 LEDs)
    output logic [15:0] led_output,

    // FND display output
    output logic [3:0]  fnd_com,
    output logic [7:0]  fnd_data,

    // Filter event flags
    output logic [3:0]  event_flag,
    
    // Debug outputs
    output logic [2:0]  debug_state,
    output logic [3:0]  debug_dice_steps
);

    // Constants
    localparam int SEC = 100_000_000; // 1 sec (assuming 100 MHz clock)

    // FSM Declaration
    typedef enum logic [2:0] {
        S_IDLE,
        S_WAIT_DICE,
        S_UPDATE_POS,
        S_WAIT_ANIM,    // Added for UI integration
        S_CHECK_EVENT,
        S_START_EVENT,
        S_NEXT_TURN,
        S_WIN
    } state_t;

    state_t state, next_state;

    // Internal Registers
    logic [3:0] next_pos;
    logic turn_reg, turn_next;
    
    // Dice steps conversion (color to movement)
    logic [3:0] dice_steps;
    always_comb begin
        case (dice_value)
            2'b01:   dice_steps = 4'd1;  // RED   = 1칸
            2'b10:   dice_steps = 4'd2;  // GREEN = 2칸
            2'b11:   dice_steps = 4'd3;  // BLUE  = 3칸
            default: dice_steps = 4'd0;  // Invalid
        endcase
    end
    
    // Turn separation: must see WHITE before accepting dice
    logic white_seen_this_turn;

    // Timeout + LED
    logic [3:0] time_elapsed; // 0 -> 7
    logic [31:0] sec_cnt;  // 0.5 sec counter
    logic [15:0] led_output_reg;


    assign led_output = led_output_reg;
    assign turn = turn_reg; // Connect internal reg to output
    assign debug_state = state;
    assign debug_dice_steps = dice_steps;

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
            turn_reg     <= 0;
            pos_valid    <= 0;
            event_flag   <= 0;
            white_seen_this_turn <= 0;

            // LED + timer init
            time_elapsed <= 0;
            sec_cnt <= 0;
            led_output_reg <= 16'hFFFF;   // all on
        end else begin
            state <= next_state;
            turn_reg <= turn_next;
            // event_flag <= 1;

            case (state)
                S_IDLE: begin
                    // reset all game status
                    sec_cnt <= 0;
                    time_elapsed <= 0;
                    led_output_reg <= 16'hFFFF;   // all on
                    pos_valid <= 0;
                    white_seen_this_turn <= 1'b0;  // Reset for new game
                    if (start_btn) begin
                        led_output_reg <= 16'hFF00;   // Player 1 First
                    end
                end

                // WAIT_DICE: timer + LED countdown + turn separation
                S_WAIT_DICE: begin
                    // Track if WHITE was seen this turn (for turn separation)
                    if (white_stable) begin
                        white_seen_this_turn <= 1'b1;
                    end
                    
                    // Only accept dice if WHITE was seen first (turn separation)
                    if (!dice_valid || !white_seen_this_turn) begin
                        if (sec_cnt == SEC - 1) begin // 1 sec elapsed
                            sec_cnt <= 0;
                            led_output_reg <= (turn_reg == 0) ? ((led_output_reg << 1) & 16'hFF00) : ((led_output_reg >> 1) & 16'h00FF);
                            time_elapsed <= time_elapsed + 1;
                        end else begin
                            sec_cnt <= sec_cnt + 1;
                        end
                    end else begin  // (WAIT_DICE -> UPDATE_POS) reset timer + LED when dice is valid
                        sec_cnt <= 0;
                        time_elapsed <= 0;
                        led_output_reg <= (turn_reg == 0) ? 16'hFF00 : 16'h00FF;  // indicate player turn
                    end 
                end

                // UPDATE_POS: apply movement to player
                S_UPDATE_POS: begin
                    pos_valid <= 1;
                    if (turn_reg == 0) p1_pos <= (next_pos >= 10) ? 10 : next_pos;
                    else p2_pos <= (next_pos >= 10) ? 10 : next_pos;
                end

                // WAIT_ANIM: wait for UI to finish moving the player
                S_WAIT_ANIM: begin
                    pos_valid <= 1; // Keep high for CDC
                    // Just wait for turn_done signal
                end

                S_CHECK_EVENT: begin
                    pos_valid <= 0;
                    // Check event for CURRENT player only
                    if (turn_reg == 0) begin
                        // Player 1's turn - check p1_pos
                        if (p1_pos == 2) event_flag <= 4'd2;
                        else if (p1_pos == 3) begin
                            event_flag <= 4'd3;
                            p1_pos <= 0;  // Go back to start
                        end
                        else if (p1_pos == 4) event_flag <= 4'd4;
                        else if (p1_pos == 6) event_flag <= 4'd6;
                        else if (p1_pos == 8) event_flag <= 4'd8;
                        else if (p1_pos >= 10) begin
                            winner_valid <= 1;
                            winner_id <= 0;  // Player 1 wins
                        end
                        else event_flag <= 4'd1;
                    end else begin
                        // Player 2's turn - check p2_pos
                        if (p2_pos == 2) event_flag <= 4'd2;
                        else if (p2_pos == 3) begin
                            event_flag <= 4'd3;
                            p2_pos <= 0;  // Go back to start
                        end
                        else if (p2_pos == 4) event_flag <= 4'd4;
                        else if (p2_pos == 6) event_flag <= 4'd6;
                        else if (p2_pos == 8) event_flag <= 4'd8;
                        else if (p2_pos >= 10) begin
                            winner_valid <= 1;
                            winner_id <= 1;  // Player 2 wins
                        end
                        else event_flag <= 4'd1;
                    end
                end

                S_START_EVENT: begin
                    // Event handling can be added here if needed
                end

                // NEXT_TURN: flip turn, reset LED + timer
                S_NEXT_TURN: begin
                    time_elapsed <= 0;
                    sec_cnt <= 0;
                    led_output_reg <= (turn_reg == 0) ? 16'hFF00 : 16'h00FF;
                    white_seen_this_turn <= 1'b0;  // Reset for next turn
                end

                // S_WIN: hold state
                S_WIN: begin
                    // Game over effects can be added here if needed
                    led_output_reg <= (winner_id == 0) ? 16'hF0F0 : 16'h0F0F; // indicate winner
                    event_flag <= 4'd10; // win event
                end

            endcase
        end
    end

    // Next Position Calculation (using converted dice_steps)
    always_comb begin
        if (turn_reg == 1'b0)
            next_pos = p1_pos + dice_steps;
        else
            next_pos = p2_pos + dice_steps;
    end

    // FSM Next-State Logic
    always_comb begin
        next_state = state;
        turn_next = turn_reg;
        case (state)
            S_IDLE: begin
                if (start_btn) begin
                    next_state = S_WAIT_DICE;
                    turn_next = 0; // Player 1 starts first
                end
            end

            S_WAIT_DICE: begin
                // Only accept dice if WHITE was seen first (turn separation)
                if (dice_valid && white_seen_this_turn)
                    next_state = S_UPDATE_POS;
                else if (time_elapsed == 8) begin
                    turn_next = ~turn_reg;
                    next_state = S_NEXT_TURN;   // timeout
                end else
                    next_state = S_WAIT_DICE;
            end

            S_UPDATE_POS: begin
                next_state = S_WAIT_ANIM; // Go to wait anim
            end

            S_WAIT_ANIM: begin
                if (turn_done)
                    next_state = S_CHECK_EVENT;
                else
                    next_state = S_WAIT_ANIM;
            end

            S_CHECK_EVENT: begin
                if (p1_pos >= 10 || p2_pos >= 10)
                    next_state = S_WIN;
                else
                    next_state = S_START_EVENT;
            end

            S_START_EVENT: begin
                if (event_flag == 4'd1) begin
                    turn_next = ~turn_reg;
                    next_state = S_NEXT_TURN;
                end else if (turn_done) begin
                    // Wait for event animation (e.g. moving back) to finish
                    turn_next = ~turn_reg;
                    next_state = S_NEXT_TURN;
                end else
                    next_state = S_START_EVENT;
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

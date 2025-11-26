`timescale 1ns / 1ps

//=============================================================================
// Module: Game_FSM_Example
// Description: Example game state machine for future integration
//              Demonstrates how to connect color detection to game logic
//
// Game Rules (Example: Board Game):
//   - RED color → Move piece 1 step
//   - GREEN color → Move piece 2 steps
//   - BLUE color → Move piece 3 steps
//   - Piece position wraps around board (0-15)
//
// This is a TEMPLATE for future expansion. Not used in current system.
//=============================================================================

module Game_FSM_Example (
    input  logic        clk,
    input  logic        reset,
    
    // From Color_Result_Manager
    input  logic [1:0]  color_detected,      // Detected color
    input  logic [1:0]  movement_steps,      // 1/2/3 steps
    input  logic        color_result_ready,  // Pulse when new result
    input  logic [15:0] color_confidence,    // Confidence level
    
    // Game controls
    input  logic        game_start,          // Start button
    input  logic        game_reset,          // Reset button
    
    // Game state outputs
    output logic [3:0]  piece_position,      // Current position (0-15)
    output logic [2:0]  game_state,          // Current game state
    output logic        movement_in_progress,
    output logic        game_won             // Reached finish
);

    //=========================================================================
    // Color encoding (from Color_Result_Manager)
    //=========================================================================
    localparam [1:0] COLOR_NONE  = 2'b00;
    localparam [1:0] COLOR_RED   = 2'b01;
    localparam [1:0] COLOR_GREEN = 2'b10;
    localparam [1:0] COLOR_BLUE  = 2'b11;
    
    //=========================================================================
    // Game states
    //=========================================================================
    typedef enum logic [2:0] {
        IDLE          = 3'b000,   // Waiting for game start
        WAIT_COLOR    = 3'b001,   // Waiting for color detection
        MOVE_PIECE    = 3'b010,   // Animating piece movement
        CHECK_WIN     = 3'b011,   // Check if reached goal
        GAME_OVER     = 3'b100,   // Game finished
        DEBOUNCE      = 3'b101    // Debounce state (prevent rapid triggers)
    } game_state_t;
    
    game_state_t state, state_next;
    
    //=========================================================================
    // Game variables
    //=========================================================================
    logic [3:0]  piece_pos_reg;
    logic [3:0]  target_position;
    logic [1:0]  steps_to_move;
    logic [15:0] debounce_counter;
    logic [15:0] animation_counter;
    
    localparam FINISH_LINE = 4'd15;
    localparam DEBOUNCE_TIME = 16'd50000;  // ~2ms at 25MHz
    localparam ANIMATION_DELAY = 16'd25000; // Animation step delay
    
    //=========================================================================
    // State register
    //=========================================================================
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= IDLE;
        end else begin
            state <= state_next;
        end
    end
    
    //=========================================================================
    // Next state logic
    //=========================================================================
    always_comb begin
        state_next = state;
        
        case (state)
            IDLE: begin
                if (game_start)
                    state_next = WAIT_COLOR;
            end
            
            WAIT_COLOR: begin
                if (game_reset)
                    state_next = IDLE;
                else if (color_result_ready && movement_steps > 0)
                    state_next = MOVE_PIECE;
            end
            
            MOVE_PIECE: begin
                if (game_reset)
                    state_next = IDLE;
                else if (animation_counter == 0)
                    state_next = CHECK_WIN;
            end
            
            CHECK_WIN: begin
                if (game_reset)
                    state_next = IDLE;
                else if (piece_pos_reg >= FINISH_LINE)
                    state_next = GAME_OVER;
                else
                    state_next = DEBOUNCE;
            end
            
            DEBOUNCE: begin
                if (game_reset)
                    state_next = IDLE;
                else if (debounce_counter == 0)
                    state_next = WAIT_COLOR;
            end
            
            GAME_OVER: begin
                if (game_reset)
                    state_next = IDLE;
            end
            
            default: state_next = IDLE;
        endcase
    end
    
    //=========================================================================
    // Piece position logic
    //=========================================================================
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            piece_pos_reg <= 4'd0;
            target_position <= 4'd0;
            steps_to_move <= 2'd0;
            animation_counter <= 16'd0;
        end else begin
            case (state)
                IDLE: begin
                    piece_pos_reg <= 4'd0;
                    target_position <= 4'd0;
                end
                
                WAIT_COLOR: begin
                    if (color_result_ready && movement_steps > 0) begin
                        // Capture movement command
                        steps_to_move <= movement_steps;
                        target_position <= piece_pos_reg + movement_steps[1:0];
                        animation_counter <= ANIMATION_DELAY;
                    end
                end
                
                MOVE_PIECE: begin
                    // Simple animation: gradually move to target
                    if (animation_counter > 0) begin
                        animation_counter <= animation_counter - 1;
                    end else if (piece_pos_reg < target_position) begin
                        piece_pos_reg <= piece_pos_reg + 1;
                        animation_counter <= ANIMATION_DELAY;
                    end
                end
                
                CHECK_WIN: begin
                    // Position is finalized
                end
                
                DEBOUNCE: begin
                    if (debounce_counter == 0)
                        debounce_counter <= DEBOUNCE_TIME;
                    else
                        debounce_counter <= debounce_counter - 1;
                end
                
                default: begin
                end
            endcase
        end
    end
    
    //=========================================================================
    // Output assignments
    //=========================================================================
    assign piece_position = piece_pos_reg;
    assign game_state = state;
    assign movement_in_progress = (state == MOVE_PIECE);
    assign game_won = (state == GAME_OVER);
    
endmodule


//=============================================================================
// Module: Game_Board_Display
// Description: Visual representation of game board on VGA
//              Shows piece position and game state
//
// This module can be connected in parallel with Display_Overlay
//=============================================================================

module Game_Board_Display #(
    parameter BOARD_START_X = 10'd350,
    parameter BOARD_START_Y = 10'd50,
    parameter TILE_SIZE = 10'd20,
    parameter NUM_TILES = 16
) (
    input  logic       clk,
    input  logic [9:0] x_coord,
    input  logic [9:0] y_coord,
    input  logic       display_enable,
    
    // Game state
    input  logic [3:0] piece_position,
    input  logic [2:0] game_state,
    
    // Input pixel
    input  logic [3:0] pixel_r_in,
    input  logic [3:0] pixel_g_in,
    input  logic [3:0] pixel_b_in,
    
    // Output pixel
    output logic [3:0] pixel_r_out,
    output logic [3:0] pixel_g_out,
    output logic [3:0] pixel_b_out
);

    //=========================================================================
    // Board rendering
    //=========================================================================
    logic [3:0] tile_index;
    logic on_piece;
    logic on_board;
    
    // Calculate which tile we're on
    logic [9:0] rel_x, rel_y;
    assign rel_x = x_coord - BOARD_START_X;
    assign rel_y = y_coord - BOARD_START_Y;
    
    assign tile_index = rel_y / TILE_SIZE;  // Vertical board
    assign on_board = display_enable && 
                      (x_coord >= BOARD_START_X) && 
                      (x_coord < BOARD_START_X + TILE_SIZE) &&
                      (y_coord >= BOARD_START_Y) && 
                      (y_coord < BOARD_START_Y + (TILE_SIZE * NUM_TILES));
    
    assign on_piece = on_board && (tile_index == piece_position);
    
    //=========================================================================
    // Color assignment
    //=========================================================================
    always_comb begin
        if (on_piece) begin
            // Yellow piece
            pixel_r_out = 4'hF;
            pixel_g_out = 4'hF;
            pixel_b_out = 4'h0;
        end else if (on_board) begin
            // Checkered board pattern
            if (tile_index[0])
                {pixel_r_out, pixel_g_out, pixel_b_out} = 12'hCCC;
            else
                {pixel_r_out, pixel_g_out, pixel_b_out} = 12'h888;
        end else begin
            // Pass through
            pixel_r_out = pixel_r_in;
            pixel_g_out = pixel_g_in;
            pixel_b_out = pixel_b_in;
        end
    end
    
endmodule


//=============================================================================
// Module: OV7670_Game_System (Future Top-Level with Game Integration)
// Description: Complete system integrating camera, color detection, and game
//=============================================================================

module OV7670_Game_System (
    input  logic       clk,
    input  logic       reset,
    
    // OV7670 camera
    output logic       xclk,
    input  logic       pclk,
    input  logic       href,
    input  logic       vsync,
    input  logic [7:0] data,
    
    // VGA output
    output logic       h_sync,
    output logic       v_sync,
    output logic [3:0] r_port,
    output logic [3:0] g_port,
    output logic [3:0] b_port,
    
    // I2C
    output tri         SCL,
    inout  tri         SDA,
    
    // Game controls
    input  logic       game_start_btn,
    input  logic       game_reset_btn
);

    // Color detection outputs
    logic [1:0]  detected_color;
    logic [1:0]  movement_steps;
    logic        color_result_ready;
    logic [15:0] color_confidence;
    
    // Game state
    logic [3:0]  piece_position;
    logic [2:0]  game_state;
    logic        movement_in_progress;
    logic        game_won;
    
    // Intermediate video signals
    logic [3:0]  r_color_overlay;
    logic [3:0]  g_color_overlay;
    logic [3:0]  b_color_overlay;
    logic [9:0]  x_pixel;
    logic [9:0]  y_pixel;
    logic        DE;
    
    //=========================================================================
    // Camera + Color Detection System
    //=========================================================================
    OV7670_CCTV_ColorDetect U_Camera_ColorDetect (
        .clk                (clk),
        .reset              (reset),
        .xclk               (xclk),
        .pclk               (pclk),
        .href               (href),
        .vsync              (vsync),
        .data               (data),
        .h_sync             (h_sync),
        .v_sync             (v_sync),
        .r_port             (r_color_overlay),
        .g_port             (g_color_overlay),
        .b_port             (b_color_overlay),
        .SCL                (SCL),
        .SDA                (SDA),
        .detected_color     (detected_color),
        .movement_steps     (movement_steps),
        .color_result_ready (color_result_ready),
        .color_confidence   (color_confidence)
    );
    
    //=========================================================================
    // Game FSM
    //=========================================================================
    Game_FSM_Example U_Game_FSM (
        .clk                 (clk),
        .reset               (reset),
        .color_detected      (detected_color),
        .movement_steps      (movement_steps),
        .color_result_ready  (color_result_ready),
        .color_confidence    (color_confidence),
        .game_start          (game_start_btn),
        .game_reset          (game_reset_btn),
        .piece_position      (piece_position),
        .game_state          (game_state),
        .movement_in_progress(movement_in_progress),
        .game_won            (game_won)
    );
    
    //=========================================================================
    // Game Board Display Overlay (Future enhancement)
    //=========================================================================
    // Uncomment to enable game board visualization
    /*
    Game_Board_Display U_Game_Board (
        .clk           (clk),
        .x_coord       (x_pixel),
        .y_coord       (y_pixel),
        .display_enable(DE),
        .piece_position(piece_position),
        .game_state    (game_state),
        .pixel_r_in    (r_color_overlay),
        .pixel_g_in    (g_color_overlay),
        .pixel_b_in    (b_color_overlay),
        .pixel_r_out   (r_port),
        .pixel_g_out   (g_port),
        .pixel_b_out   (b_port)
    );
    */
    
    // For now, directly output color detection overlay
    assign r_port = r_color_overlay;
    assign g_port = g_color_overlay;
    assign b_port = b_color_overlay;
    
endmodule

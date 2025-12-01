`timescale 1ns / 1ps

//=============================================================================
// Module: Color_Result_Manager
// Description: Manages color detection results with voting mechanism
//              Provides clean interface for external Game FSM integration
//
// Game Flow:
//   1. Start with WHITE background (IDLE state)
//   2. Player places dice -> R/G/B detected -> color_detected pulse
//   3. Player removes dice -> WHITE detected -> turn_end pulse, return to IDLE
//   4. Repeat for next player
//
// Features:
//   - 3-frame voting for noise rejection (configurable)
//   - Stable output for FSM state transitions
//   - Confidence threshold filtering
//   - WHITE detection for turn transition
//
// Output Signals for Game Logic:
//   - stable_color:      Filtered dominant color (00=NONE, 01=RED, 10=GREEN, 11=BLUE)
//   - result_ready:      Pulse when valid R/G/B color detected
//   - turn_end:          Pulse when WHITE background detected (turn complete)
//   - current_state_white: Level signal - HIGH when currently in WHITE/IDLE state
//=============================================================================

module Color_Result_Manager #(
    parameter ENABLE_VOTING = 1,           // 1=use 3-frame voting, 0=direct output
    parameter MIN_CONFIDENCE = 16'd100,    // Minimum pixel count to accept result
    parameter WHITE_FRAME_COUNT = 3        // Consecutive WHITE frames required
) (
    input  logic        clk,
    input  logic        reset,
    
    // From ROI_Color_Detector
    input  logic [1:0]  detected_color,    // Raw detection result
    input  logic        color_valid,       // Pulse when new R/G/B result available
    input  logic [15:0] color_confidence,  // Confidence (pixel count)
    input  logic        white_detected,    // Pulse when white background detected
    
    // Output to Game Logic (directly connect these to your Game FSM)
    output logic [1:0]  stable_color,      // 00=NONE, 01=RED, 10=GREEN, 11=BLUE
    output logic        result_ready,      // Pulse: valid dice color detected
    output logic        turn_end,          // Pulse: white background (turn complete)
    output logic        current_state_white, // Level: currently detecting WHITE background
    
    // Debug outputs
    output logic [15:0] stable_confidence
);

    //=========================================================================
    // Color encoding (same as ROI_Color_Detector)
    //=========================================================================
    localparam [1:0] COLOR_NONE  = 2'b00;
    localparam [1:0] COLOR_RED   = 2'b01;
    localparam [1:0] COLOR_GREEN = 2'b10;
    localparam [1:0] COLOR_BLUE  = 2'b11;
    
    //=========================================================================
    // 3-Frame Voting Mechanism
    //=========================================================================
    logic [1:0] frame_history [0:2];  // Last 3 frame results
    logic [1:0] vote_count_none;
    logic [1:0] vote_count_red;
    logic [1:0] vote_count_green;
    logic [1:0] vote_count_blue;
    logic [1:0] voted_color;
    
    logic [15:0] confidence_history [0:2];
    logic [15:0] avg_confidence;
    
    integer i;
    
    // Signal to clear frame history when WHITE state is confirmed
    logic clear_frame_history;
    
    generate
        if (ENABLE_VOTING) begin : gen_voting
            //=================================================================
            // Voting Logic: Majority wins over 3 frames
            //=================================================================
            always_ff @(posedge clk or posedge reset) begin
                if (reset) begin
                    for (i = 0; i < 3; i = i + 1) begin
                        frame_history[i] <= COLOR_NONE;
                        confidence_history[i] <= 16'd0;
                    end
                end else if (clear_frame_history) begin
                    // *** FIX: Clear history when WHITE state is confirmed ***
                    for (i = 0; i < 3; i = i + 1) begin
                        frame_history[i] <= COLOR_NONE;
                        confidence_history[i] <= 16'd0;
                    end
                end else if (color_valid && color_confidence >= MIN_CONFIDENCE) begin
                    // Shift history (FIFO)
                    frame_history[2] <= frame_history[1];
                    frame_history[1] <= frame_history[0];
                    frame_history[0] <= detected_color;
                    
                    confidence_history[2] <= confidence_history[1];
                    confidence_history[1] <= confidence_history[0];
                    confidence_history[0] <= color_confidence;
                end
            end
            
            // Count votes for each color
            always_comb begin
                vote_count_none  = 2'd0;
                vote_count_red   = 2'd0;
                vote_count_green = 2'd0;
                vote_count_blue  = 2'd0;
                
                for (i = 0; i < 3; i = i + 1) begin
                    case (frame_history[i])
                        COLOR_NONE:  vote_count_none  = vote_count_none + 2'd1;
                        COLOR_RED:   vote_count_red   = vote_count_red + 2'd1;
                        COLOR_GREEN: vote_count_green = vote_count_green + 2'd1;
                        COLOR_BLUE:  vote_count_blue  = vote_count_blue + 2'd1;
                    endcase
                end
            end
            
            // Determine winner (majority or most recent if tie)
            always_comb begin
                if (vote_count_red >= 2'd2)
                    voted_color = COLOR_RED;
                else if (vote_count_green >= 2'd2)
                    voted_color = COLOR_GREEN;
                else if (vote_count_blue >= 2'd2)
                    voted_color = COLOR_BLUE;
                else
                    voted_color = COLOR_NONE;
            end
            
            // Average confidence
            assign avg_confidence = (confidence_history[0] + confidence_history[1] + confidence_history[2]) / 3;
            
        end else begin : gen_direct
            //=================================================================
            // Direct passthrough (no voting)
            //=================================================================
            assign voted_color = (color_confidence >= MIN_CONFIDENCE) ? detected_color : COLOR_NONE;
            assign avg_confidence = color_confidence;
        end
    endgenerate
    
    //=========================================================================
    // Stable Output Register with State Machine
    //=========================================================================
    logic [1:0] stable_color_reg;
    logic [15:0] stable_confidence_reg;
    logic result_ready_reg;
    logic turn_end_reg;
    logic current_state_white_reg;
    
    // Counter for consecutive WHITE frames
    logic [2:0] white_frame_counter;
    
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            stable_color_reg <= COLOR_NONE;
            stable_confidence_reg <= 16'd0;
            result_ready_reg <= 1'b0;
            turn_end_reg <= 1'b0;
            current_state_white_reg <= 1'b1;  // Start in WHITE/IDLE state
            white_frame_counter <= 3'd0;
            clear_frame_history <= 1'b0;
        end else begin
            result_ready_reg <= 1'b0;  // Pulse - default low
            turn_end_reg <= 1'b0;      // Pulse - default low
            clear_frame_history <= 1'b0;  // Pulse - default low
            
            // WHITE detection - transition to IDLE state
            if (white_detected) begin
                white_frame_counter <= white_frame_counter + 3'd1;
                
                // After consecutive WHITE frames, confirm WHITE state
                if (white_frame_counter >= WHITE_FRAME_COUNT - 1) begin
                    // Only generate turn_end pulse when transitioning FROM color TO white
                    if (!current_state_white_reg) begin
                        turn_end_reg <= 1'b1;
                        // *** FIX: Clear frame_history when entering WHITE state ***
                        // This ensures previous color doesn't affect next detection
                        clear_frame_history <= 1'b1;
                    end
                    current_state_white_reg <= 1'b1;
                    stable_color_reg <= COLOR_NONE;  // Clear previous color
                    stable_confidence_reg <= 16'd0;
                end
            end
            // Valid R/G/B color detection
            else if (color_valid && voted_color != COLOR_NONE) begin
                white_frame_counter <= 3'd0;  // Reset WHITE counter
                
                // Only generate result_ready pulse when new color detected
                if (current_state_white_reg || (stable_color_reg != voted_color)) begin
                    result_ready_reg <= 1'b1;
                end
                
                current_state_white_reg <= 1'b0;  // No longer in WHITE state
                stable_color_reg <= voted_color;
                stable_confidence_reg <= avg_confidence;
            end
            // No detection (neither WHITE nor valid color)
            else if (color_valid) begin
                // Keep current state, don't change
                // This prevents flickering during transition
            end
        end
    end
    
    //=========================================================================
    // Output Assignments
    //=========================================================================
    assign stable_color = stable_color_reg;
    assign result_ready = result_ready_reg;
    assign turn_end = turn_end_reg;
    assign current_state_white = current_state_white_reg;
    assign stable_confidence = stable_confidence_reg;
    
endmodule

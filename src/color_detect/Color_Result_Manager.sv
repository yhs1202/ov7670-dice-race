`timescale 1ns / 1ps

//=============================================================================
// Module: Color_Result_Manager
// Description: Manages color detection results with voting mechanism
//              Provides clean interface for game FSM integration
//
// Features:
//   - 3-frame voting for noise rejection (optional)
//   - Stable output for FSM state transitions
//   - Movement value mapping (1/2/3 steps)
//   - Confidence threshold filtering
//=============================================================================

module Color_Result_Manager #(
    parameter ENABLE_VOTING = 1,           // 1=use 3-frame voting, 0=direct output
    parameter MIN_CONFIDENCE = 16'd100     // Minimum pixel count to accept result
) (
    input  logic        clk,
    input  logic        reset,
    
    // From ROI_Color_Detector
    input  logic [1:0]  detected_color,    // Raw detection result
    input  logic        color_valid,       // Pulse when new result available
    input  logic [15:0] color_confidence,  // Confidence (pixel count)
    
    // Output to Game FSM (stable, filtered)
    output logic [1:0]  stable_color,      // Filtered color result
    //output logic [1:0]  movement_steps,    // 0=none, 1/2/3=steps
    output logic        result_ready,      // Pulse when stable result available
    
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
    // Stable Output Register
    //=========================================================================
    logic [1:0] stable_color_reg;
    logic [15:0] stable_confidence_reg;
    logic result_ready_reg;
    
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            stable_color_reg <= COLOR_NONE;
            stable_confidence_reg <= 16'd0;
            result_ready_reg <= 1'b0;
        end else begin
            result_ready_reg <= 1'b0;  // Pulse
            
            if (color_valid) begin
                stable_color_reg <= voted_color;
                stable_confidence_reg <= avg_confidence;
                result_ready_reg <= 1'b1;
            end
        end
    end
    
    //=========================================================================
    // Color to Movement Mapping (for future game FSM)
    //=========================================================================
    //logic [1:0] movement_steps_reg;
    //
    //always_comb begin
    //    case (stable_color_reg)
    //        COLOR_RED:   movement_steps_reg = 2'd1;  // Red = 1 step
    //        COLOR_GREEN: movement_steps_reg = 2'd2;  // Green = 2 steps
    //        COLOR_BLUE:  movement_steps_reg = 2'd3;  // Blue = 3 steps
    //        default:     movement_steps_reg = 2'd0;  // None = no movement
    //    endcase
    //end
    
    //=========================================================================
    // Output Assignments
    //=========================================================================
    assign stable_color = stable_color_reg;
    //assign movement_steps = movement_steps_reg;
    assign result_ready = result_ready_reg;
    assign stable_confidence = stable_confidence_reg;
    
endmodule

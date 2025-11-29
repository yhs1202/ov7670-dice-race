`timescale 1ns / 1ps

//=============================================================================
// Module: OV7670_CCTV_ColorDetect
// Description: Top-level integration of OV7670 camera with color detection
//              Enhanced version of OV7670_CCTV with color recognition capability
//
// Architecture:
//   OV7670 Camera Input (640x480)
//        ↓
//   OV7670_Mem_Controller (2x decimation to 320x240)
//        ↓
//   Frame Buffer (320x240 RGB565)
//        ↓
//   ImgMemReader_ColorDetect (RGB565→RGB888, pixel stream generation)
//        ↓         ↓
//        ↓    ROI_Color_Detector (R/G/B/WHITE detection)
//        ↓         ↓
//        ↓    Color_Result_Manager (voting, filtering)
//        ↓         ↓
//   Display_Overlay (ROI box + color visualization)
//        ↓
//   VGA Output (640x480)
//
//=============================================================================
// GAME LOGIC INTERFACE - Signals for external Game FSM connection
//=============================================================================
//
// Output signals to Game Logic:
//
//   [1:0] detected_color     - Detected dice color
//                              2'b00 = NONE (no valid color / white background)
//                              2'b01 = RED
//                              2'b10 = GREEN  
//                              2'b11 = BLUE
//
//        color_result_ready  - Single-cycle pulse when R/G/B color is detected
//                              Use this to trigger dice roll acceptance
//                              NOTE: Does NOT pulse for WHITE or NONE
//
//        turn_end            - Single-cycle pulse when WHITE background detected
//                              Use this to signal turn completion
//                              (Player removed dice from camera view)
//
//  [15:0] color_confidence   - Pixel count of detected color (for debugging)
//                              Higher value = more confident detection
//
// Game Logic 예제:
//   1. Game FSM은 WAIT_COLOR state에서 color_result_ready 대기
//   2. Player가 카메라에 주사위를 놓음(배경은 흰색)
//   3. color_result_ready 펄스 -> Game FSM이 detected_color 읽음
//   4. Game FSM이 주사위 색상에 따라 말 이동 (이동 칸 수는 Game Logic에서 결정)
//   5. Player가 주사위를 치워서 배경이 흰색이 되도록 함
//   6. turn_end 펄스 -> Game FSM이 턴 종료 처리
//   7. 다음 플레이어로 턴 전환
//
//=============================================================================

module OV7670_CCTV_ColorDetect (
    input  logic       clk,
    input  logic       reset,
    
    // OV7670 camera interface
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
    
    // I2C/SCCB interface
    output tri         SCL,
    inout  tri         SDA,
    
    //=========================================================================
    // Game Logic Interface Outputs
    //=========================================================================
    output logic [1:0] detected_color,     // 00=NONE, 01=RED, 10=GREEN, 11=BLUE
    output logic       color_result_ready, // R/G/B color detected 신호
    output logic       turn_end,           // 흰색 배경이 관찰되면, turn 종료임을 알리기 위한 신호
    output logic [15:0] color_confidence   // Detection confidence (pixel count)
);

    //=========================================================================
    // ROI Configuration (can be made external parameters)
    //=========================================================================
    localparam ROI_X_START = 10'd100;
    localparam ROI_X_END   = 10'd220;
    localparam ROI_Y_START = 10'd60;
    localparam ROI_Y_END   = 10'd180;
    
    //=========================================================================
    // Internal signals
    //=========================================================================
    logic        sys_clk;
    logic        DE;
    logic [9:0]  x_pixel;
    logic [9:0]  y_pixel;
    logic [16:0] rAddr;
    logic [15:0] rData;
    logic        we;
    logic [16:0] wAddr;
    logic [15:0] wData;
    
    // Pixel stream from memory reader
    logic        pixel_valid;
    logic [9:0]  pixel_x;
    logic [9:0]  pixel_y;
    logic [7:0]  pixel_r8;
    logic [7:0]  pixel_g8;
    logic [7:0]  pixel_b8;
    logic        frame_start;
    
    // RGB output from memory reader (before overlay)
    logic [3:0]  r_raw;
    logic [3:0]  g_raw;
    logic [3:0]  b_raw;
    
    // Color detection signals
    logic        in_roi;
    logic        is_red;
    logic        is_green;
    logic        is_blue;
    logic        is_white;
    logic [1:0]  dominant_color_raw;
    logic        color_valid_raw;
    logic        white_detected_raw;
    logic [15:0] confidence_raw;
    
    // Filtered color results
    logic [1:0]  stable_color;
    logic        result_ready_int;
    logic        turn_end_int;
    logic [15:0] stable_confidence;
    
    //=========================================================================
    // Camera clock generation
    //=========================================================================
    assign xclk = sys_clk;
    
    //=========================================================================
    // SCCB/I2C Configuration Interface
    //=========================================================================
    SCCB_Interface U_SCCB (
        .clk  (clk),
        .reset(reset),
        .SCL  (SCL),
        .SDA  (SDA)
    );
    
    //=========================================================================
    // Pixel Clock Generator (25MHz for VGA)
    //=========================================================================
    pixel_clk_gen U_PXL_CLK_GEN (
        .clk  (clk),
        .reset(reset),
        .pclk (sys_clk)
    );
    
    //=========================================================================
    // VGA Synchronization Generator
    //=========================================================================
    VGA_Syncher U_VGA_Syncher (
        .clk    (sys_clk),
        .reset  (reset),
        .h_sync (h_sync),
        .v_sync (v_sync),
        .DE     (DE),
        .x_pixel(x_pixel),
        .y_pixel(y_pixel)
    );
    
    //=========================================================================
    // Enhanced Image Memory Reader with Color Detection Interface
    //=========================================================================
    ImgMemReader_ColorDetect U_Img_Reader (
        .clk        (sys_clk),
        .reset      (reset),
        .DE         (DE),
        .x_pixel    (x_pixel),
        .y_pixel    (y_pixel),
        .addr       (rAddr),
        .imgData    (rData),
        .r_port     (r_raw),
        .g_port     (g_raw),
        .b_port     (b_raw),
        // Pixel stream outputs
        .pixel_valid(pixel_valid),
        .pixel_x    (pixel_x),
        .pixel_y    (pixel_y),
        .pixel_r8   (pixel_r8),
        .pixel_g8   (pixel_g8),
        .pixel_b8   (pixel_b8),
        .frame_start(frame_start)
    );
    
    //=========================================================================
    // ROI Color Detector
    // ROI size: 120x120 = 14,400 pixels
    //=========================================================================
    ROI_Color_Detector #(
        .ROI_X_START(ROI_X_START),
        .ROI_X_END  (ROI_X_END),
        .ROI_Y_START(ROI_Y_START),
        .ROI_Y_END  (ROI_Y_END),
        // Threshold tuning (adjusted for OV7670 camera characteristics)
        // More lenient thresholds for better detection
        .RED_R_MIN      (8'd140),    // Red detection
        .RED_G_MAX      (8'd130),
        .RED_B_MAX      (8'd130),
        .GREEN_R_MAX    (8'd130),    // Green detection
        .GREEN_G_MIN    (8'd140),
        .GREEN_B_MAX    (8'd130),
        .BLUE_R_MAX     (8'd130),    // Blue detection
        .BLUE_G_MAX     (8'd130),
        .BLUE_B_MIN     (8'd140),
        .WHITE_R_MIN    (8'd160),    // White detection (slightly lower for camera)
        .WHITE_G_MIN    (8'd160),
        .WHITE_B_MIN    (8'd160),
        .MIN_PIXEL_THRESHOLD   (16'd200),   // Min pixels to accept R/G/B color
        .WHITE_PIXEL_THRESHOLD (16'd5000)   // ~35% of ROI must be white for turn_end
    ) U_Color_Detector (
        .clk              (sys_clk),
        .reset            (reset),
        .pixel_valid      (pixel_valid),
        .frame_start      (frame_start),
        .x_coord          (pixel_x),
        .y_coord          (pixel_y),
        .pixel_r          (pixel_r8),
        .pixel_g          (pixel_g8),
        .pixel_b          (pixel_b8),
        .in_roi           (in_roi),
        .is_red           (is_red),
        .is_green         (is_green),
        .is_blue          (is_blue),
        .is_white         (is_white),
        .dominant_color   (dominant_color_raw),
        .color_valid      (color_valid_raw),
        .white_detected   (white_detected_raw),
        .color_confidence (confidence_raw)
    );
    
    //=========================================================================
    // Color Result Manager (with 3-frame voting for stability)
    //=========================================================================
    logic current_state_white;  // Level signal: currently in WHITE/IDLE state
    
    Color_Result_Manager #(
        .ENABLE_VOTING   (1),           // Enable 3-frame voting
        .MIN_CONFIDENCE  (16'd100),     // Minimum pixel count threshold
        .WHITE_FRAME_COUNT (3)          // Consecutive WHITE frames required
    ) U_Result_Manager (
        .clk               (sys_clk),
        .reset             (reset),
        .detected_color    (dominant_color_raw),
        .color_valid       (color_valid_raw),
        .color_confidence  (confidence_raw),
        .white_detected    (white_detected_raw),
        .stable_color      (stable_color),
        .result_ready      (result_ready_int),
        .turn_end          (turn_end_int),
        .current_state_white (current_state_white),
        .stable_confidence (stable_confidence)
    );
    
    //=========================================================================
    // Display Overlay (ROI box + color indicator)
    //=========================================================================
    Display_Overlay #(
        .ROI_X_START   (ROI_X_START),
        .ROI_X_END     (ROI_X_END),
        .ROI_Y_START   (ROI_Y_START),
        .ROI_Y_END     (ROI_Y_END),
        .BOX_THICKNESS (2'd2)
    ) U_Display_Overlay (
        .clk            (sys_clk),
        .reset          (reset),
        .x_coord        (x_pixel),
        .y_coord        (y_pixel),
        .display_enable (DE),
        .pixel_r_in     (r_raw),
        .pixel_g_in     (g_raw),
        .pixel_b_in     (b_raw),
        .dominant_color (stable_color),
        .white_detected (current_state_white),  // Level signal: currently in WHITE/IDLE state
        .pixel_r_out    (r_port),
        .pixel_g_out    (g_port),
        .pixel_b_out    (b_port)
    );
    
    //=========================================================================
    // Frame Buffer (320x240 RGB565)
    //=========================================================================
    frame_buffer U_Frame_Buffer (
        .wclk (pclk),
        .we   (we),
        .wAddr(wAddr),
        .wData(wData),
        .rclk (sys_clk),
        .oe   (1'b1),
        .rAddr(rAddr),
        .rData(rData)
    );
    
    //=========================================================================
    // OV7670 Memory Controller (640x480 → 320x240 decimation)
    //=========================================================================
    OV7670_Mem_Controller U_OV7670_Mem_Controller (
        .clk  (pclk),
        .reset(reset),
        .href (href),
        .vsync(vsync),
        .data (data),
        .we   (we),
        .wAddr(wAddr),
        .wData(wData)
    );
    
    //=========================================================================
    // Output assignments (for Game FSM connection)
    //=========================================================================
    assign detected_color = stable_color;
    assign color_result_ready = result_ready_int;
    assign turn_end = turn_end_int;
    assign color_confidence = stable_confidence;
    
endmodule

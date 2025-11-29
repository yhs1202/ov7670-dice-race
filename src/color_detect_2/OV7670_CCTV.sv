`timescale 1ns / 1ps

//=============================================================================
// Module: OV7670_CCTV (Enhanced with Color Detection Mode)
// Description: Dual-mode camera system with switch control
//
// Mode Control:
//   - mode_select = 0: Normal camera view (original functionality)
//   - mode_select = 1: Color detection mode with ROI overlay
//
// LED Indicators:
//   - led[0]: Mode (0=Normal, 1=Color Detection)
//   - led[1]: RED detected
//   - led[2]: GREEN detected
//   - led[3]: BLUE detected
//=============================================================================

module OV7670_CCTV (
    input  logic       clk,
    input  logic       reset,
    
    // Mode control
    input  logic       mode_select,  // 0=Normal, 1=Color Detection
    
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
    
    // I2C
    output tri         SCL,
    inout  tri         SDA,
    
    // LED indicators (color detection status)
    output logic [3:0] led
);
    //=========================================================================
    // Common signals
    //=========================================================================
    logic        sys_clk;
    logic        DE;
    logic [ 9:0] x_pixel;
    logic [ 9:0] y_pixel;
    logic [16:0] rAddr;
    logic [15:0] rData;
    logic        we;
    logic [16:0] wAddr;
    logic [15:0] wData;

    assign xclk = sys_clk;
    
    //=========================================================================
    // Normal mode signals (original path)
    //=========================================================================
    logic [3:0] r_normal;
    logic [3:0] g_normal;
    logic [3:0] b_normal;
    
    //=========================================================================
    // Color detection mode signals
    //=========================================================================
    logic        pixel_valid;
    logic [9:0]  pixel_x;
    logic [9:0]  pixel_y;
    logic [7:0]  pixel_r8;
    logic [7:0]  pixel_g8;
    logic [7:0]  pixel_b8;
    logic        frame_start;
    
    logic [3:0]  r_raw;
    logic [3:0]  g_raw;
    logic [3:0]  b_raw;
    
    logic        in_roi;
    logic        is_red;
    logic        is_green;
    logic        is_blue;
    logic [1:0]  dominant_color_raw;
    logic        color_valid_raw;
    logic [15:0] confidence_raw;
    
    logic [1:0]  stable_color;
    logic [1:0]  movement_steps;
    logic        result_ready;
    logic [15:0] stable_confidence;
    
    logic [3:0]  r_color_mode;
    logic [3:0]  g_color_mode;
    logic [3:0]  b_color_mode;
    
    //=========================================================================
    // ROI Configuration
    //=========================================================================
    localparam ROI_X_START = 10'd100;
    localparam ROI_X_END   = 10'd220;
    localparam ROI_Y_START = 10'd60;
    localparam ROI_Y_END   = 10'd180;

    SCCB_Interface U_SCCB (
        .clk  (clk),
        .reset(reset),
        .SCL  (SCL),
        .SDA  (SDA)
    );

    pixel_clk_gen U_PXL_CLK_GEN (
        .clk  (clk),
        .reset(reset),
        .pclk (sys_clk)
    );

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
    // Mode Selection: Normal or Color Detection
    //=========================================================================
    
    // Normal mode uses original ImgMemReader
    ImgMemReader U_Img_Reader_Normal (
        .DE     (DE),
        .x_pixel(x_pixel),
        .y_pixel(y_pixel),
        .addr   (rAddr),
        .imgData(rData),
        .r_port (r_normal),
        .g_port (g_normal),
        .b_port (b_normal)
    );
    
    // Color detection mode uses enhanced reader
    ImgMemReader_ColorDetect U_Img_Reader_Color (
        .clk        (sys_clk),
        .reset      (reset),
        .DE         (DE),
        .x_pixel    (x_pixel),
        .y_pixel    (y_pixel),
        .addr       (),  // Not used (shared with normal mode)
        .imgData    (rData),
        .r_port     (r_raw),
        .g_port     (g_raw),
        .b_port     (b_raw),
        .pixel_valid(pixel_valid),
        .pixel_x    (pixel_x),
        .pixel_y    (pixel_y),
        .pixel_r8   (pixel_r8),
        .pixel_g8   (pixel_g8),
        .pixel_b8   (pixel_b8),
        .frame_start(frame_start)
    );
    
    //=========================================================================
    // Color Detection Pipeline (only active in color mode)
    // ROI size: 120x120 = 14,400 pixels
    //=========================================================================
    
    // Additional signals for white detection
    logic is_white;
    logic white_detected_raw;
    
    ROI_Color_Detector #(
        .ROI_X_START(ROI_X_START),
        .ROI_X_END  (ROI_X_END),
        .ROI_Y_START(ROI_Y_START),
        .ROI_Y_END  (ROI_Y_END),
        // Adjusted thresholds for OV7670 camera
        .RED_R_MIN      (8'd140),
        .RED_G_MAX      (8'd130),
        .RED_B_MAX      (8'd130),
        .GREEN_R_MAX    (8'd130),
        .GREEN_G_MIN    (8'd140),
        .GREEN_B_MAX    (8'd130),
        .BLUE_R_MAX     (8'd130),
        .BLUE_G_MAX     (8'd130),
        .BLUE_B_MIN     (8'd140),
        .WHITE_R_MIN    (8'd160),
        .WHITE_G_MIN    (8'd160),
        .WHITE_B_MIN    (8'd160),
        .MIN_PIXEL_THRESHOLD   (16'd200),
        .WHITE_PIXEL_THRESHOLD (16'd5000)
    ) U_Color_Detector (
        .clk              (sys_clk),
        .reset            (reset),
        .pixel_valid      (pixel_valid & mode_select),  // Only active in color mode
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
    
    // Additional signals for turn_end and current_state_white
    logic turn_end;
    logic current_state_white;  // Level signal: currently in WHITE/IDLE state
    
    Color_Result_Manager #(
        .ENABLE_VOTING   (1),
        .MIN_CONFIDENCE  (16'd100),
        .WHITE_FRAME_COUNT (3)          // Consecutive WHITE frames required
    ) U_Result_Manager (
        .clk               (sys_clk),
        .reset             (reset),
        .detected_color    (dominant_color_raw),
        .color_valid       (color_valid_raw),
        .color_confidence  (confidence_raw),
        .white_detected    (white_detected_raw),
        .stable_color      (stable_color),
        .movement_steps    (movement_steps),
        .result_ready      (result_ready),
        .turn_end          (turn_end),
        .current_state_white (current_state_white),
        .stable_confidence (stable_confidence)
    );
    
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
        .pixel_r_out    (r_color_mode),
        .pixel_g_out    (g_color_mode),
        .pixel_b_out    (b_color_mode)
    );
    
    //=========================================================================
    // Output Multiplexer: Switch between modes
    //=========================================================================
    assign r_port = mode_select ? r_color_mode : r_normal;
    assign g_port = mode_select ? g_color_mode : g_normal;
    assign b_port = mode_select ? b_color_mode : b_normal;
    
    //=========================================================================
    // LED Indicators
    //=========================================================================
    assign led[0] = mode_select;  // Mode indicator
    assign led[1] = mode_select && (stable_color == 2'b01);  // RED
    assign led[2] = mode_select && (stable_color == 2'b10);  // GREEN
    assign led[3] = mode_select && (stable_color == 2'b11);  // BLUE

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
endmodule

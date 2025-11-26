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
//        ↓    ROI_Color_Detector
//        ↓         ↓
//        ↓    Color_Result_Manager
//        ↓         ↓
//   Display_Overlay (ROI box + color visualization)
//        ↓
//   VGA Output (640x480)
//
// Future Extension Point:
//   Color_Result_Manager → Game_FSM → Piece_Movement_Logic
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
    
    // Color detection outputs (for future game FSM)
    output logic [1:0] detected_color,     // Current dominant color
    output logic [1:0] movement_steps,     // Movement command (1/2/3)
    output logic       color_result_ready, // Pulse when new result available
    output logic [15:0] color_confidence   // Confidence level (for debugging)
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
    logic [1:0]  dominant_color_raw;
    logic        color_valid_raw;
    logic [15:0] confidence_raw;
    
    // Filtered color results
    logic [1:0]  stable_color;
    logic [1:0]  movement_steps_int;
    logic        result_ready_int;
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
    //=========================================================================
    ROI_Color_Detector #(
        .ROI_X_START(ROI_X_START),
        .ROI_X_END  (ROI_X_END),
        .ROI_Y_START(ROI_Y_START),
        .ROI_Y_END  (ROI_Y_END),
        // Threshold tuning (adjust based on lighting conditions)
        .RED_R_MIN      (8'd180),
        .RED_G_MAX      (8'd100),
        .RED_B_MAX      (8'd100),
        .GREEN_R_MAX    (8'd100),
        .GREEN_G_MIN    (8'd180),
        .GREEN_B_MAX    (8'd100),
        .BLUE_R_MAX     (8'd100),
        .BLUE_G_MAX     (8'd100),
        .BLUE_B_MIN     (8'd180)
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
        .dominant_color   (dominant_color_raw),
        .color_valid      (color_valid_raw),
        .color_confidence (confidence_raw)
    );
    
    //=========================================================================
    // Color Result Manager (with 3-frame voting for stability)
    //=========================================================================
    Color_Result_Manager #(
        .ENABLE_VOTING   (1),           // Enable 3-frame voting
        .MIN_CONFIDENCE  (16'd100)      // Minimum pixel count threshold
    ) U_Result_Manager (
        .clk               (sys_clk),
        .reset             (reset),
        .detected_color    (dominant_color_raw),
        .color_valid       (color_valid_raw),
        .color_confidence  (confidence_raw),
        .stable_color      (stable_color),
        .movement_steps    (movement_steps_int),
        .result_ready      (result_ready_int),
        .stable_confidence (stable_confidence)
    );
    
    //=========================================================================
    // Display Overlay (ROI box + color visualization)
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
        .in_roi         (in_roi),
        .dominant_color (stable_color),
        .is_red         (is_red),
        .is_green       (is_green),
        .is_blue        (is_blue),
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
    // Output assignments (for future game FSM connection)
    //=========================================================================
    assign detected_color = stable_color;
    assign movement_steps = movement_steps_int;
    assign color_result_ready = result_ready_int;
    assign color_confidence = stable_confidence;
    
endmodule

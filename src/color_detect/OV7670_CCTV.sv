`timescale 1ns / 1ps

//=============================================================================
// Module: OV7670_CCTV (Triple-Mode Camera System)
// Description: Advanced camera system with three operational modes
//
// Mode Control (SW[1:0]):
//   - 2'b00 (SW off): Normal camera view
//   - 2'b01 (SW[0] on): Color detection mode with ROI overlay
//   - 2'b10 (SW[1] on): ASCII art filter (Matrix style)
//   - 2'b11 (both on): Reserved (defaults to ASCII mode)
//
// LED Indicators:
//   Mode 0: LED[0]=OFF, LED[1-3]=OFF
//   Mode 1: LED[0]=ON, LED[1]=RED, LED[2]=GREEN, LED[3]=BLUE
//   Mode 2: LED[0]=OFF, LED[1]=ON (ASCII mode indicator)
//=============================================================================

module OV7670_CCTV (
    input  logic       clk,
    input  logic       reset,
    
    // Mode control (2-bit for 3 modes)
    input  logic [1:0] mode_select,  // SW[1:0]: 00=Normal, 01=Color, 10=ASCII
    
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
    
    // LED indicators
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
    // Mode decoding
    //=========================================================================
    localparam MODE_NORMAL = 2'b00;
    localparam MODE_COLOR  = 2'b01;
    localparam MODE_ASCII  = 2'b10;
    
    logic is_normal_mode;
    logic is_color_mode;
    logic is_ascii_mode;
    
    assign is_normal_mode = (mode_select == MODE_NORMAL);
    assign is_color_mode  = (mode_select == MODE_COLOR);
    assign is_ascii_mode  = (mode_select == MODE_ASCII) || (mode_select == 2'b11);
    
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
    // ASCII filter mode signals
    //=========================================================================
    logic [3:0]  r_ascii_mode;
    logic [3:0]  g_ascii_mode;
    logic [3:0]  b_ascii_mode;
    
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
    // Mode Selection: Normal, Color Detection, or ASCII Filter
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
    
    // Color detection & ASCII modes use enhanced reader (for RGB888)
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
    //=========================================================================
    ROI_Color_Detector #(
        .ROI_X_START(ROI_X_START),
        .ROI_X_END  (ROI_X_END),
        .ROI_Y_START(ROI_Y_START),
        .ROI_Y_END  (ROI_Y_END),
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
        .pixel_valid      (pixel_valid & is_color_mode),  // Only active in color mode
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
    
    Color_Result_Manager #(
        .ENABLE_VOTING   (1),
        .MIN_CONFIDENCE  (16'd100)
    ) U_Result_Manager (
        .clk               (sys_clk),
        .reset             (reset),
        .detected_color    (dominant_color_raw),
        .color_valid       (color_valid_raw),
        .color_confidence  (confidence_raw),
        .stable_color      (stable_color),
        .movement_steps    (movement_steps),
        .result_ready      (result_ready),
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
        .in_roi         (in_roi),
        .dominant_color (stable_color),
        .is_red         (is_red),
        .is_green       (is_green),
        .is_blue        (is_blue),
        .pixel_r_out    (r_color_mode),
        .pixel_g_out    (g_color_mode),
        .pixel_b_out    (b_color_mode)
    );
    
    //=========================================================================
    // ASCII Filter Pipeline (only active in ASCII mode)
    //=========================================================================
    ASCII_Filter #(
        .CHAR_WIDTH  (4'd8),
        .CHAR_HEIGHT (4'd8)
    ) U_ASCII_Filter (
        .clk            (sys_clk),
        .reset          (reset),
        .x_coord        (x_pixel),
        .y_coord        (y_pixel),
        .display_enable (DE),
        .pixel_r_in     (r_raw),
        .pixel_g_in     (g_raw),
        .pixel_b_in     (b_raw),
        .pixel_r8       (pixel_r8),
        .pixel_g8       (pixel_g8),
        .pixel_b8       (pixel_b8),
        .pixel_valid    (pixel_valid),
        .pixel_r_out    (r_ascii_mode),
        .pixel_g_out    (g_ascii_mode),
        .pixel_b_out    (b_ascii_mode)
    );
    
    //=========================================================================
    // Output Multiplexer: Switch between 3 modes
    //=========================================================================
    always_comb begin
        case (mode_select)
            MODE_NORMAL: begin
                r_port = r_normal;
                g_port = g_normal;
                b_port = b_normal;
            end
            MODE_COLOR: begin
                r_port = r_color_mode;
                g_port = g_color_mode;
                b_port = b_color_mode;
            end
            MODE_ASCII: begin
                r_port = r_ascii_mode;
                g_port = g_ascii_mode;
                b_port = b_ascii_mode;
            end
            default: begin  // 2'b11 also goes to ASCII
                r_port = r_ascii_mode;
                g_port = g_ascii_mode;
                b_port = b_ascii_mode;
            end
        endcase
    end
    
    //=========================================================================
    // LED Indicators (mode-dependent)
    //=========================================================================
    always_comb begin
        case (mode_select)
            MODE_NORMAL: begin
                led[0] = 1'b0;  // All LEDs off in normal mode
                led[1] = 1'b0;
                led[2] = 1'b0;
                led[3] = 1'b0;
            end
            MODE_COLOR: begin
                led[0] = 1'b1;  // Mode indicator
                led[1] = (stable_color == 2'b01);  // RED
                led[2] = (stable_color == 2'b10);  // GREEN
                led[3] = (stable_color == 2'b11);  // BLUE
            end
            MODE_ASCII: begin
                led[0] = 1'b0;
                led[1] = 1'b1;  // ASCII mode indicator
                led[2] = 1'b0;
                led[3] = 1'b0;
            end
            default: begin  // 2'b11
                led[0] = 1'b0;
                led[1] = 1'b1;
                led[2] = 1'b0;
                led[3] = 1'b0;
            end
        endcase
    end

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

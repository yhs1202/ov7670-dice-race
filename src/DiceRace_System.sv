`timescale 1ns / 1ps

module DiceRace_System (
    input logic clk,
    input logic reset, // BtnC

    // Buttons
    input logic start_btn,      // BtnU (Intro: Up, Game: Start)
    input logic event_end_tick, // BtnR (Intro: Down, Game: Test Event)

    // Camera Interface (OV7670) - Camera 1 (Dice)
    output logic       CAM1_sioc,   // SCL
    inout  wire        CAM1_siod,   // SDA
    output logic       CAM1_xclk,
    input  logic       CAM1_pclk,
    input  logic       CAM1_href,
    input  logic       CAM1_vsync,
    input  logic [7:0] CAM1_data,

    // Camera Interface (OV7670) - Camera 2 (Face)
    output logic       CAM2_sioc,   // SCL
    inout  wire        CAM2_siod,   // SDA
    output logic       CAM2_xclk,
    input  logic       CAM2_pclk,
    input  logic       CAM2_href,
    input  logic       CAM2_vsync,
    input  logic [7:0] CAM2_data,

    output logic [3:0] r_port,
    output logic [3:0] g_port,
    output logic [3:0] b_port,
    output logic       h_sync,
    output logic       v_sync,

    output logic [15:0] led_output,
    output logic [ 3:0] fnd_com,
    output logic [ 7:0] fnd_data,

    input logic [2:0] filter_sel
);

    /////////////////////////// Parameter ///////////////////////////
    localparam IMG_WIDTH = 160;
    localparam IMG_HEIGHT = 120;
    localparam ADDR_WIDTH = $clog2(IMG_WIDTH * IMG_HEIGHT);
    /////////////////////////////////////////////////////////////////

    ///////////////////////////// Clock /////////////////////////////
    logic sys_clk;

    assign CAM1_xclk = sys_clk;
    assign CAM2_xclk = sys_clk;

    pixel_clk_gen U_Pixel_Clk_Gen (
        .clk  (clk),
        .reset(reset),
        .pclk (sys_clk)
    );
    /////////////////////////////////////////////////////////////////

    ////////////////////////// Button Driver /////////////////////////
    logic btn_start_db, btn_event_db;

    btn_debounce U_Btn_Start (
        .clk    (clk),
        .rst    (reset),
        .btn_in (start_btn),
        .btn_out(btn_start_db)
    );

    btn_debounce U_Btn_Event (
        .clk    (clk),
        .rst    (reset),
        .btn_in (event_end_tick),
        .btn_out(btn_event_db)
    );
    /////////////////////////////////////////////////////////////////

    /////////////////////////// Input Path //////////////////////////
    logic                  CAM1_we;
    logic [ADDR_WIDTH-1:0] CAM1_wAddr;
    logic [          15:0] CAM1_wData;
    OV7670_Controller #(
        .IMG_WIDTH (IMG_WIDTH),
        .IMG_HEIGHT(IMG_HEIGHT)
    ) U_CAM1_Controller (
        .clk  (clk),
        .reset(reset),
        .SCL  (CAM1_sioc),
        .SDA  (CAM1_siod),
        .pclk (CAM1_pclk),
        .href (CAM1_href),
        .vsync(CAM1_vsync),
        .data (CAM1_data),
        .we   (CAM1_we),
        .wAddr(CAM1_wAddr),
        .wData(CAM1_wData)
    );

    logic                  CAM2_we;
    logic [ADDR_WIDTH-1:0] CAM2_wAddr;
    logic [          15:0] CAM2_wData;
    OV7670_Controller #(
        .IMG_WIDTH (IMG_WIDTH),
        .IMG_HEIGHT(IMG_HEIGHT)
    ) U_CAM2_Controller (
        .clk  (clk),
        .reset(reset),
        .SCL  (CAM2_sioc),
        .SDA  (CAM2_siod),
        .pclk (CAM2_pclk),
        .href (CAM2_href),
        .vsync(CAM2_vsync),
        .data (CAM2_data),
        .we   (CAM2_we),
        .wAddr(CAM2_wAddr),
        .wData(CAM2_wData)
    );

    //////////////////////////// Storage ////////////////////////////
    logic [15:0] cam1_read_data;
    logic [15:0] cam2_read_data;
    logic [ADDR_WIDTH-1:0] vga_read_addr;

    frame_buffer #(
        .IMG_WIDTH (IMG_WIDTH),
        .IMG_HEIGHT(IMG_HEIGHT)
    ) U_CAM1_Frame_Buffer (
        .wclk (CAM1_pclk),
        .we   (CAM1_we),
        .wAddr(CAM1_wAddr),
        .wData(CAM1_wData),
        .rclk (sys_clk),
        .oe   (1'b1),
        .rAddr(vga_read_addr),
        .rData(cam1_read_data)
    );

    frame_buffer #(
        .IMG_WIDTH (IMG_WIDTH),
        .IMG_HEIGHT(IMG_HEIGHT)
    ) U_CAM2_Frame_Buffer (
        .wclk (CAM2_pclk),
        .we   (CAM2_we),
        .wAddr(CAM2_wAddr),
        .wData(CAM2_wData),
        .rclk (sys_clk),
        .oe   (1'b1),
        .rAddr(vga_read_addr),
        .rData(cam2_read_data)
    );
    /////////////////////////////////////////////////////////////////

    ////////////////////////// Output Path //////////////////////////
    logic DE;
    logic [9:0] x_pixel;
    logic [9:0] y_pixel;

    VGA_Syncher U_VGA_Syncher (
        .clk    (sys_clk),
        .reset  (reset),
        .h_sync (h_sync),
        .v_sync (v_sync),
        .DE     (DE),
        .x_pixel(x_pixel),
        .y_pixel(y_pixel)
    );

    ImgMemReader #(
        .IMG_WIDTH (IMG_WIDTH),
        .IMG_HEIGHT(IMG_HEIGHT)
    ) U_ImgMemReader (
        .x_pixel(x_pixel),
        .y_pixel(y_pixel),
        .addr   (vga_read_addr)
    );
    /////////////////////////////////////////////////////////////////

    ////////////////////////// Color Detection ///////////////////////
    logic [ 1:0] stable_color;
    logic        result_ready;
    logic        turn_end;
    logic        current_state_white;
    logic [15:0] stable_confidence;
    
    Color_Detector U_Color_Detector (
        .clk                (sys_clk),
        .reset              (reset),
        .DE                 (DE),
        .x_pixel            (x_pixel),
        .y_pixel            (y_pixel),
        .pixel_rgb_data     (cam1_read_data),
        .stable_color       (stable_color),
        .result_ready       (result_ready),
        .turn_end           (turn_end),
        .current_state_white(current_state_white),
        .stable_confidence  (stable_confidence)
    );
    /////////////////////////////////////////////////////////////////

    ///////////////////////////// Logic /////////////////////////////
    logic [ 3:0] p1_pos;
    logic [ 3:0] p2_pos;
    logic        turn_done;
    logic        pos_valid;
    logic        winner_valid;
    logic        winner_id;
    logic        turn;
    // logic [15:0] led_output_game;
    // logic [ 3:0] fnd_com_game;
    // logic [ 7:0] fnd_data_game;
    logic [ 3:0] event_flag;


    // [System State Machine]
    typedef enum logic {
        STATE_INTRO,
        STATE_GAME
    } sys_state_t;
    sys_state_t current_state;

    logic       is_intro;
    logic       game_start_btn_in;
    logic       menu_select;  // 0: Start, 1: End

    assign game_start_btn_in = (current_state == STATE_GAME) ? btn_start_db : 1'b0;
    assign is_intro = (current_state == STATE_INTRO);

    always_ff @(posedge clk) begin
        if (reset) current_state <= STATE_INTRO;
        else begin
            if (current_state == STATE_INTRO && btn_start_db)
                current_state <= STATE_GAME;
        end
    end

    always_ff @(posedge clk) begin
        if (reset) menu_select <= 0;
        else if (is_intro) begin
            if (btn_event_db) menu_select <= ~menu_select;
        end
    end

    Game_Logic_Controller U_Game_Logic_Controller (
        .clk         (clk),
        .reset       (reset),
        .start_btn   (game_start_btn_in),
        .dice_valid  (result_ready),       // Color detection result ready
        .dice_value  (stable_color),         // Detected color (1=RED, 2=GREEN, 3=BLUE)
        .p1_pos      (p1_pos),
        .p2_pos      (p2_pos),
        .turn_done   (turn_done),
        .pos_valid   (pos_valid),
        .winner_valid(winner_valid),
        .winner_id   (winner_id),
        .turn        (turn),
        .led_output  (led_output),
        .fnd_com     (fnd_com),
        .fnd_data    (fnd_data),
        .event_flag  (event_flag)
    );
    /////////////////////////////////////////////////////////////////

    // logic [ 2:0] filter_sel;
    logic [3:0] filter_r, filter_g, filter_b;
    logic [3:0] dice_r, dice_g, dice_b;
    logic [3:0] ui_r, ui_g, ui_b;
    logic ui_en;
    
    // Pixel data for Display_Overlay (only valid in left bottom region: x<320, y>=240)
    logic [3:0] dice_r_raw, dice_g_raw, dice_b_raw;
    assign dice_r_raw = (x_pixel < 320 && y_pixel >= 240 && y_pixel < 480) ? cam1_read_data[15:12] : 4'h0;
    assign dice_g_raw = (x_pixel < 320 && y_pixel >= 240 && y_pixel < 480) ? cam1_read_data[10:7] : 4'h0;
    assign dice_b_raw = (x_pixel < 320 && y_pixel >= 240 && y_pixel < 480) ? cam1_read_data[4:1] : 4'h0;
    
    Display_Overlay #(
        .ROI_X_START  (10'd100),
        .ROI_X_END    (10'd220),
        .ROI_Y_START  (10'd60),
        .ROI_Y_END    (10'd180),
        .BOX_THICKNESS(2'd2)
    ) U_Dice_Display_Overlay (
        .clk           (sys_clk),
        .reset         (reset),
        .x_coord       (x_pixel),
        .y_coord       (y_pixel),
        .display_enable(DE),
        .pixel_r_in    (dice_r_raw),
        .pixel_g_in    (dice_g_raw),
        .pixel_b_in    (dice_b_raw),
        .dominant_color(stable_color),
        .white_detected(current_state_white),
        .pixel_r_out   (dice_r),
        .pixel_g_out   (dice_g),
        .pixel_b_out   (dice_b)
    );

    // Pixel data for Img_Filter (only valid in right bottom region: x>=320, y>=240)
    logic [3:0] filter_r_raw, filter_g_raw, filter_b_raw;
    assign filter_r_raw = (x_pixel >= 320 && y_pixel >= 240 && y_pixel < 480) ? cam2_read_data[15:12] : 4'h0;
    assign filter_g_raw = (x_pixel >= 320 && y_pixel >= 240 && y_pixel < 480) ? cam2_read_data[10:7] : 4'h0;
    assign filter_b_raw = (x_pixel >= 320 && y_pixel >= 240 && y_pixel < 480) ? cam2_read_data[4:1] : 4'h0;
    
    Img_Filter #(
        .IMG_WIDTH (IMG_WIDTH),
        .IMG_HEIGHT(IMG_HEIGHT)
    ) U_Img_Filter (
        .clk       (clk),
        .reset     (reset),
        .filter_sel(filter_sel),
        .DE        (DE),
        .x_pixel   (x_pixel),
        .y_pixel   (y_pixel),
        .r_in      (filter_r_raw),
        .g_in      (filter_g_raw),
        .b_in      (filter_b_raw),
        .r_out     (filter_r),
        .g_out     (filter_g),
        .b_out     (filter_b)
    );

    UI_Generator U_UI_Generator (
        .clk           (sys_clk),
        .reset         (reset),
        .x_pixel       (x_pixel),
        .y_pixel       (y_pixel),
        .is_intro_state(is_intro),
        .menu_select   (menu_select),
        .p1_pos        (p1_pos),
        .p2_pos        (p2_pos),
        .turn_done     (turn_done),
        .pos_valid     (pos_valid),
        .winner_valid  (winner_valid),
        .turn          (turn),
        .ui_r          (ui_r),
        .ui_g          (ui_g),
        .ui_b          (ui_b),
        .ui_enable     (ui_en)
    );
    /////////////////////////////////////////////////////////////////

    // Final output multiplexer
    always_comb begin
        if (!DE) begin
            r_port = 0;
            g_port = 0;
            b_port = 0;
        end else begin
            if (ui_en) begin
                r_port = ui_r;
                g_port = ui_g;
                b_port = ui_b;
            end else begin
                if (x_pixel < 320) begin
                    // Left side: Dice camera with overlay
                    r_port = dice_r;
                    g_port = dice_g;
                    b_port = dice_b;
                end else begin
                    // Right side: Face camera with filter
                    r_port = filter_r;
                    g_port = filter_g;
                    b_port = filter_b;
                end
            end
        end
    end

endmodule

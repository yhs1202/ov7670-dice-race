`timescale 1ns / 1ps

module DiceRace_System (
    input logic clk,
    input logic reset, // BtnC

    // Buttons
    input logic start_btn,      // BtnU (Intro: Up, Game: Start)
    input logic select_option,  // BtnD (Intro: Down, Game: Test Event)

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

    // VGA Output (RGB444)
    output logic [3:0] r_port,
    output logic [3:0] g_port,
    output logic [3:0] b_port,
    output logic       h_sync,
    output logic       v_sync,

    // FND + LED Output
    output logic [15:0] led_output,
    output logic [ 3:0] fnd_com,
    output logic [ 7:0] fnd_data

    // Test Input for Image Filter
    // input logic [3:0] filter_sel
);
    /////////////////////////// Parameter ///////////////////////////
    localparam IMG_WIDTH = 160;
    localparam IMG_HEIGHT = 120;
    localparam ADDR_WIDTH = $clog2(IMG_WIDTH * IMG_HEIGHT);
    /////////////////////////////////////////////////////////////////


    /////////// Camera System (CAM1: Dice, CAM2: Face) //////////////
    logic pclk;
    assign CAM1_xclk = pclk;
    assign CAM2_xclk = pclk;
    logic [15:0] CAM1_RGB_out;
    logic [15:0] CAM2_RGB_out;  // RGB565 for filter
    logic [11:0] dice_RGB_out;
    logic        DE;
    logic [ 9:0] x_pixel;
    logic [ 9:0] y_pixel;

    Camera_system U_Camera_System (
        .clk        (clk),
        .reset      (reset),

        .CAM1_data  (CAM1_data),
        .CAM1_href  (CAM1_href),
        .CAM1_pclk  (CAM1_pclk),
        .CAM1_vsync (CAM1_vsync),

        .CAM1_sioc  (CAM1_sioc),
        .CAM1_siod  (CAM1_siod),

        .CAM2_data  (CAM2_data),
        .CAM2_href  (CAM2_href),
        .CAM2_pclk  (CAM2_pclk),
        .CAM2_vsync (CAM2_vsync),

        .CAM2_sioc  (CAM2_sioc),
        .CAM2_siod  (CAM2_siod),

        .pclk           (pclk),             // !! RENAMED from sys_clk to pclk !!
        .dice_RGB_out   (dice_RGB_out),
        .CAM1_RGB_out   (CAM1_RGB_out),     // RGB565 for Color Detector
        .CAM2_RGB_out   (CAM2_RGB_out),     // RGB565 for filter

        .DE         (DE),
        .x_pixel    (x_pixel),
        .y_pixel    (y_pixel),
        .h_sync     (h_sync),
        .v_sync     (v_sync)
    );
    

/*  Not Completed yet: Refer to Game_starter.sv
    //////////////////////// Game Starter ///////////////////////////

    logic menu_select;  // 0: Start, 1: End
    logic is_intro;
    logic is_game;
    logic game_start_tick;

    Game_starter U_Game_Starter (
        .clk               (clk),
        .reset             (reset),
        .start_btn         (start_btn),
        .select_option_btn (select_option),

        .menu_select       (menu_select),
        .is_intro          (is_intro),
        .is_game           (is_game),
        .game_start_tick   (game_start_tick)
    );
*/

    ////////////////////////// Game Starter /////////////////////////
    logic btn_start_db, btn_event_db;

    btn_debounce U_Btn_Start (
        .clk    (clk),
        .reset  (reset),
        .btn_in (start_btn),
        .btn_out(btn_start_db)
    );

    btn_debounce U_Btn_Option_Select (
        .clk    (clk),
        .reset  (reset),
        .btn_in (select_option),
        .btn_out(btn_event_db)
    );

    // System FSM
    typedef enum logic {
        STATE_INTRO,
        STATE_GAME
    } sys_state_t;
    sys_state_t current_state;

    logic is_intro;
    logic is_game;
    logic game_start_btn_in;
    logic menu_select;  // 0: Start, 1: End

    assign is_intro = (current_state == STATE_INTRO);
    assign is_game  = (current_state == STATE_GAME);
    assign game_start_btn_in = is_game ? btn_start_db : 1'b0;

    always_ff @(posedge clk) begin
        if (reset) begin
            current_state <= STATE_INTRO;
            menu_select <= 1'b0;
        end else begin
            if (current_state == STATE_INTRO && btn_start_db)
                current_state <= STATE_GAME;
            if (is_intro) begin
                if (btn_event_db) menu_select <= ~menu_select;
            end
        end
    end

    ////////////////////////// Color Detection ////////////////////////
    logic [1:0] stable_color;
    logic       result_ready;
    logic       current_state_white;

    Color_Detector U_Color_Detector (
        .clk                (pclk), // Changed to pclk
        .reset              (reset),
        .DE                 (DE),
        .x_pixel            (x_pixel),
        .y_pixel            (y_pixel),
        .pixel_rgb_data     (CAM1_RGB_out),
        .stable_color       (stable_color),
        .result_ready       (result_ready),
        .current_state_white(current_state_white)
    );


    /////////////////////// Dice Display Overlay //////////////////////
    logic [3:0] dice_r, dice_g, dice_b;

    Display_Overlay #(
        .ROI_X_START  (10'd100),
        .ROI_X_END    (10'd220),
        .ROI_Y_START  (10'd60),
        .ROI_Y_END    (10'd180),
        .BOX_THICKNESS(2'd2)
    ) U_Dice_Display_Overlay (
        .clk           (pclk),  // Changed to pclk
        .reset         (reset),
        .x_coord       (x_pixel),
        .y_coord       (y_pixel),
        .display_enable(DE),
        .pixel_r_in    (dice_RGB_out[11:8]),
        .pixel_g_in    (dice_RGB_out[7:4]),
        .pixel_b_in    (dice_RGB_out[3:0]),
        .dominant_color(stable_color),
        .white_detected(current_state_white),
        .pixel_r_out   (dice_r),
        .pixel_g_out   (dice_g),
        .pixel_b_out   (dice_b)
    );


    ////////////////////////// Game Logic ///////////////////////////
    logic [ 3:0] p1_pos;
    logic [ 3:0] p2_pos;
    logic        turn_done;
    logic        pos_valid;
    logic        winner_valid;
    logic        winner_id;
    logic        turn;
    logic [15:0] led_output_game;
    logic [ 3:0] fnd_com_game;
    logic [ 7:0] fnd_data_game;
    logic [ 3:0] event_flag;

    // Debug outputs
    logic [2:0] debug_state;
    logic [3:0] debug_dice_steps;

    assign led_output = (is_game) ? led_output_game : 16'h0;
    assign fnd_com = (is_game) ? fnd_com_game : 4'hF;
    assign fnd_data = (is_game) ? fnd_data_game : 8'hFF;

    Game_Logic_Controller U_Game_Logic_Controller (
        .clk             (clk),
        .reset           (reset),
        .start_btn       (game_start_btn_in),
        // .start_btn       (game_start_tick),
        .dice_valid      (result_ready),
        .dice_value      (stable_color),
        .white_stable    (current_state_white), // Changed white_stable to current_state_white
        .p1_pos          (p1_pos),
        .p2_pos          (p2_pos),
        .turn_done       (turn_done),
        .pos_valid       (pos_valid),
        .winner_valid    (winner_valid),
        .winner_id       (winner_id),
        .turn            (turn),
        .led_output      (led_output_game),
        .fnd_com         (fnd_com_game),
        .fnd_data        (fnd_data_game),
        .event_flag      (event_flag),
        .debug_state     (debug_state),
        .debug_dice_steps(debug_dice_steps)
    );

    ///////////////////////// Image Filter ///////////////////////////
    // Convert RGB565 to RGB444 for final output
    logic [15:0] filter_rgb565_out;  // RGB565 output from filter
    logic [ 3:0] filter_r, filter_g, filter_b;
    assign filter_r = filter_rgb565_out[15:12];
    assign filter_g = filter_rgb565_out[10:7];
    assign filter_b = filter_rgb565_out[4:1];

    Img_Filter #(
        .IMG_WIDTH (IMG_WIDTH),
        .IMG_HEIGHT(IMG_HEIGHT)
    ) U_Img_Filter (
        .clk       (clk),
        .reset     (reset),
        .filter_sel(event_flag),
        .DE        (DE),
        .x_pixel   (x_pixel),
        .y_pixel   (y_pixel),
        .rgb565_in (CAM2_RGB_out),      // Direct RGB565 input
        .rgb565_out(filter_rgb565_out)  // RGB565 output
    );

    ///////////////////////// UI Generator ////////////////////////////
    logic ui_en;
    logic [3:0] ui_r, ui_g, ui_b;

    UI_Generator U_UI_Generator (
        .clk           (pclk),  // Changed to pclk
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

    ////////////////// Final RGB Output Selector ////////////////////
    RGB_selector U_RGB_Selector (
        .DE               (DE),
        .ui_en            (ui_en),
        .x_pixel          (x_pixel),
        .y_pixel          (y_pixel),
        .ui_generator_out ({ui_r, ui_g, ui_b}),
        .dice_out         ({dice_r, dice_g, dice_b}),
        .img_filter_out   ({filter_r, filter_g, filter_b}),
        .RGB_out          ({r_port, g_port, b_port})
    );

endmodule

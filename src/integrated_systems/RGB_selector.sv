`timescale 1ns/1ps
// RGB Selector Module
// Description: Selects between Display Overlay, Img Filter, and UI Generator RGB 444 outputs based on x, y pixel coordinates.

module RGB_selector (
    input  logic        DE,                 // Data Enable signal
    input  logic        ui_en,              // UI Enable signal
    input  logic [9:0]  x_pixel,            // Current x pixel coordinate
    input  logic [9:0]  y_pixel,            // Current y pixel coordinate
    input  logic [11:0] ui_generator_out,   // from UI Generator Module
    input  logic [11:0] dice_out,           // from Display Overlay Module
    input  logic [11:0] img_filter_out,     // from Image Filter Module  
    input  logic [11:0] CAM2_RGB_out,
    output logic [11:0] RGB_out
);

    always_comb begin
        if (!DE) begin
            RGB_out = 12'h000;           // 0. 화면 표시 구간이 아니면 검정색
        end else if (ui_en) begin
            RGB_out = ui_generator_out;  // 1. UI가 켜져 있으면 무조건 UI 출력
        end else if ((x_pixel < 320) && (y_pixel < 480)) begin
            RGB_out = dice_out;          // 2. UI가 없고 왼쪽 화면이면 주사위 카메라 출력
        end else begin
            RGB_out = img_filter_out;    // 3. 그 외 우측 화면이면 필터링된 카메라 출력
        end
    end
endmodule
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
            RGB_out = 12'h000;  // Black when DE is low
        end else if (ui_en) begin
            RGB_out = ui_generator_out;  // UI Generator has highest priority
        end else if ((x_pixel < 320) && (y_pixel < 480)) begin
            RGB_out = dice_out;          // Dice Camera output in designated area
        end else begin
            RGB_out = img_filter_out;    // Image Filter output in designated area
        end
    end
endmodule
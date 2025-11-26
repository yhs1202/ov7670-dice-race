`timescale 1ns / 1ps
import color_pkg::*;

// =============================================
//  TOP — VGA + UI Renderer
// =============================================
module top_ui_render (
    input  logic clk,
    input  logic reset,

    output logic [3:0] r_port,
    output logic [3:0] g_port,
    output logic [3:0] b_port,
    output logic       h_sync,
    output logic       v_sync
);

    // =============================================
    // 1) Pixel Clock 생성 (25MHz enable)
    // =============================================
    logic pclk;

    pixel_clk_gen pixel_clk_inst (
        .clk   (clk),
        .reset (reset),
        .pclk  (pclk)
    );

    // =============================================
    // 2) VGA Sync (x,y,DE 생성)
    // =============================================
    logic [9:0] x;
    logic [9:0] y;
    logic       DE;

    VGA_Syncher sync_inst (
        .clk     (pclk),
        .reset   (reset),
        .h_sync  (h_sync),
        .v_sync  (v_sync),
        .DE      (DE),
        .x_pixel (x),
        .y_pixel (y)
    );

    // =============================================
    // 3) Player 좌표 (일단 테스트로 중앙에 했습니다)
    // =============================================
    logic [9:0] player_x = 200;
    logic [9:0] player_y = 320;

    // =============================================
    // 4) UI Render Core
    // =============================================
    logic [7:0] r8, g8, b8;

    ui_render ui_inst (
        .clk      (pclk),
        .x        (x),
        .y        (y),
        .player_x (player_x),
        .player_y (player_y),
        .r        (r8),
        .g        (g8),
        .b        (b8)
    );

    // =============================================
    // 5) 8bit → 4bit VGA 출력 변환
    // =============================================
    always_comb begin
        if (DE) begin
            r_port = r8[7:4];
            g_port = g8[7:4];
            b_port = b8[7:4];
        end else begin
            r_port = 4'd0;
            g_port = 4'd0;
            b_port = 4'd0;
        end
    end

endmodule

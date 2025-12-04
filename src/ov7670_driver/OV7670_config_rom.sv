`timescale 1ns / 1ps

module OV7670_config_rom (
    input  logic        clk,
    input  logic [ 7:0] rom_addr,
    output logic [15:0] rom_data
);

    // ROM end marker: 0xFFFF, Delay marker: 0xFFF0
    always @(posedge clk) begin
        case (rom_addr)
            // Reset and delay
            0:  rom_data <= 16'h12_80;  // COM7: Reset all registers
            1:  rom_data <= 16'hFF_F0;  // Delay for reset to complete
            
            // Basic format settings
            2:  rom_data <= 16'h12_0C;  // COM7: RGB output, QVGA format
            3:  rom_data <= 16'h11_80;  // CLKRC: Internal PLL matches input clock
            4:  rom_data <= 16'h0C_04;  // COM3: Enable scaling
            5:  rom_data <= 16'h3E_1A;  // COM14: DCW/PCLK divider settings
            6:  rom_data <= 16'h04_00;  // COM1: Disable CCIR656
            7:  rom_data <= 16'h40_D0;  // COM15: RGB565, full output range
            8:  rom_data <= 16'h3A_04;  // TSLB: Auto output window
            
            // Color matrix coefficients for RGB
            10: rom_data <= 16'h4F_B3;  // MTX1
            11: rom_data <= 16'h50_B3;  // MTX2
            12: rom_data <= 16'h51_00;  // MTX3
            13: rom_data <= 16'h52_3D;  // MTX4
            14: rom_data <= 16'h53_A7;  // MTX5
            15: rom_data <= 16'h54_E4;  // MTX6
            16: rom_data <= 16'h58_9E;  // MTXS: Matrix sign
            17: rom_data <= 16'h3D_C0;  // COM13: Gamma enable, UV saturation auto adjust
            
            // Window settings (fixes odd colored lines)
            18: rom_data <= 16'h17_15;  // HSTART: Horizontal frame start high 8 bits
            19: rom_data <= 16'h18_03;  // HSTOP: Horizontal frame end high 8 bits
            20: rom_data <= 16'h32_36;  // HREF: Edge offset and LSBs
            21: rom_data <= 16'h19_03;  // VSTART: Vertical frame start high 8 bits
            22: rom_data <= 16'h1A_7B;  // VSTOP: Vertical frame end high 8 bits
            23: rom_data <= 16'h03_00;  // VREF: Vertical frame control
            24: rom_data <= 16'h0F_41;  // COM6: Reset timing when format changes
            25: rom_data <= 16'h1E_00;  // MVFP: No mirror/flip
            
            // Additional settings
            26: rom_data <= 16'h33_0B;  // CHLF: Array current control
            27: rom_data <= 16'h3C_78;  // COM12: No HREF when VSYNC low
            28: rom_data <= 16'h74_00;  // REG74: Digital gain control
            
            // Color enhancement (required for good color)
            29: rom_data <= 16'hB0_84;  // RSVD: Automatic black level calibration
            30: rom_data <= 16'hB1_0C;  // ABLC1
            31: rom_data <= 16'hB2_0E;  // RSVD: Auto frame rate adjustment
            32: rom_data <= 16'hB3_80;  // THL_ST: ABLC target
            
            // Scaling settings for QQVGA (160x120)
            33: rom_data <= 16'h70_3A;  // SCALING_XSC: Horizontal scale factor
            34: rom_data <= 16'h71_35;  // SCALING_YSC: Vertical scale factor
            35: rom_data <= 16'h72_22;  // SCALING_DCWCTR: Downsample by 4
            36: rom_data <= 16'h73_F2;  // SCALING_PCLK_DIV: Pixel clock divider
            37: rom_data <= 16'hA2_02;  // SCALING_PCLK_DELAY: Pixel clock delay
            
            // Gamma curve (improves contrast and brightness)
            38: rom_data <= 16'h7A_20;  // GAMMA curve 0
            39: rom_data <= 16'h7B_10;  // GAMMA curve 1
            40: rom_data <= 16'h7C_1E;  // GAMMA curve 2
            41: rom_data <= 16'h7D_35;  // GAMMA curve 3
            42: rom_data <= 16'h7E_5A;  // GAMMA curve 4
            43: rom_data <= 16'h7F_69;  // GAMMA curve 5
            44: rom_data <= 16'h80_76;  // GAMMA curve 6
            45: rom_data <= 16'h81_80;  // GAMMA curve 7
            46: rom_data <= 16'h82_88;  // GAMMA curve 8
            47: rom_data <= 16'h83_8F;  // GAMMA curve 9
            48: rom_data <= 16'h84_96;  // GAMMA curve 10
            49: rom_data <= 16'h85_A3;  // GAMMA curve 11
            50: rom_data <= 16'h86_AF;  // GAMMA curve 12
            51: rom_data <= 16'h87_C4;  // GAMMA curve 13
            52: rom_data <= 16'h88_D7;  // GAMMA curve 14
            53: rom_data <= 16'h89_E8;  // GAMMA curve 15
            
            // AGC/AEC parameters
            54: rom_data <= 16'h00_00;  // GAIN: AGC gain control
            55: rom_data <= 16'h10_00;  // AECH: Exposure value (high bits)
            56: rom_data <= 16'h0D_40;  // COM4: Reserved bit setting
            57: rom_data <= 16'h14_18;  // COM9: AGC ceiling 4x, freeze AGC/AEC
            58: rom_data <= 16'hA5_05;  // BD50MAX: 50Hz banding step limit
            59: rom_data <= 16'hAB_07;  // BD60MAX: 60Hz banding step limit
            60: rom_data <= 16'h24_95;  // AGC: AGC upper limit
            61: rom_data <= 16'h25_33;  // AEW: AGC lower limit
            62: rom_data <= 16'h26_E3;  // VPT: AGC/AEC fast mode region
            63: rom_data <= 16'h9F_78;  // HAECC1: Histogram-based AEC/AGC control 1
            64: rom_data <= 16'hA0_68;  // HAECC2: Histogram-based AEC/AGC control 2
            65: rom_data <= 16'hA1_03;  // HAECC3: Histogram-based AEC/AGC control 3
            66: rom_data <= 16'hA6_D8;  // HAECC4: Histogram-based AEC/AGC control 4
            67: rom_data <= 16'hA7_D8;  // HAECC5: Histogram-based AEC/AGC control 5
            68: rom_data <= 16'hA8_F0;  // HAECC6: Histogram-based AEC/AGC control 6
            69: rom_data <= 16'hA9_90;  // HAECC7: Histogram-based AEC/AGC control 7
            70: rom_data <= 16'hAA_94;  // HAECCAVG: Histogram-based AEC/AGC average
            
            // Enable AGC/AEC
            71: rom_data <= 16'h13_E7;  // COM8: Enable fast AGC/AEC, AWB, AEC, AGC
            72: rom_data <= 16'h69_07;  // GFIX: Fix gain
            
            default: rom_data <= 16'hFF_FF;  // End of configuration
        endcase
    end

endmodule
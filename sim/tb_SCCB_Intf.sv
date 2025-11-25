`timescale 1ns / 1ps

module tb_SCCB_Intf ();

    // Parameters
    parameter CLK_PERIOD = 10;  // 100MHz clock (10ns period)

    // Signals
    logic clk;
    logic reset;
    wire  SCL;
    wire  SDA;

    pullup (SCL);
    pullup (SDA);

    // DUT instantiation
    SCCB_Interface DUT (
        .clk  (clk),
        .reset(reset),
        .SCL  (SCL),
        .SDA  (SDA)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD / 2) clk = ~clk;
    end

    // Test sequence
    initial begin
        // Initialize
        reset = 1;
        #(CLK_PERIOD * 10);

        // Release reset
        reset = 0;
        #(CLK_PERIOD * 10);

        $display("=== SCCB Interface Testbench Started ===");
        $display("Time: %0t - Reset released", $time);

        // Monitor key signals periodically (not every clock to reduce output)
        fork
            begin
                forever begin
                    @(posedge clk);
                    if (DUT.I2C_start) begin
                        $display(
                            "Time: %0t - I2C_START asserted, rom_addr: %0d",
                            $time, DUT.rom_addr);
                    end
                    if (DUT.I2C_stop) begin
                        $display("Time: %0t - I2C_STOP asserted, rom_addr: %0d",
                                 $time, DUT.rom_addr);
                    end
                    if (DUT.tx_done) begin
                        $display(
                            "Time: %0t - TX_DONE, tx_data: 0x%02h, rom_addr: %0d",
                            $time, DUT.tx_data, DUT.rom_addr);
                    end
                end
            end
            begin
                // Check state transitions
                automatic integer prev_rom_addr = -1;
                forever begin
                    @(posedge clk);
                    if (DUT.rom_addr != prev_rom_addr) begin
                        $display(
                            "Time: %0t - rom_addr changed: %0d -> %0d, rom_data: 0x%04h",
                            $time, prev_rom_addr, DUT.rom_addr, DUT.rom_data);
                        prev_rom_addr = DUT.rom_addr;
                    end
                end
            end
        join_none

        // Wait for completion (adjust time based on number of ROM entries)
        // Each transaction takes multiple I2C clock cycles
        // With 100kHz I2C clock and 100MHz system clock, each I2C bit takes ~1000 system clocks
        // Each byte (8 bits + ACK) takes ~9000 system clocks
        // Each transaction (slv_addr + reg_addr + reg_data) = 3 bytes = ~27000 clocks
        // Plus start/stop overhead, so ~30000 clocks per transaction
        // For 75 transactions: 75 * 30000 = 2,250,000 clocks = 22.5ms
        #(25_000_000);  // 25ms should be enough

        // Wait a bit more to ensure completion
        #(CLK_PERIOD * 1000);

        $display("=== Testbench Completed ===");
        $display("Final rom_addr: %0d (expected: 75 or 76)", DUT.rom_addr);
        $display("Final I2C_en: %b (expected: 0)", DUT.I2C_en);

        // Basic checks
        if (DUT.rom_addr >= 75) begin
            $display("PASS: rom_addr reached end condition");
        end else begin
            $display("WARNING: rom_addr (%0d) is less than expected (75)",
                     DUT.rom_addr);
        end

        if (DUT.I2C_en == 0) begin
            $display("PASS: I2C_en is deasserted (IDLE state)");
        end else begin
            $display("WARNING: I2C_en is still asserted");
        end

        $finish;
    end

    // Waveform dump (for debugging)
    initial begin
        $dumpfile("tb_SCCB_Interface.vcd");
        $dumpvars(0, tb_SCCB_Intf);
    end

    // Timeout check
    initial begin
        #(50_000_000);  // 50ms timeout
        $display("ERROR: Testbench timeout!");
        $finish;
    end

endmodule


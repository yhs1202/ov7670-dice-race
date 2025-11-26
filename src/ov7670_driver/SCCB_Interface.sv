`timescale 1ns / 1ps

module SCCB_Interface (
    input  logic clk,
    input  logic reset,
    output tri   SCL,
    inout  tri   SDA
);

    logic [ 7:0] rom_addr;
    logic [15:0] rom_data;
    logic        I2C_en;
    logic        I2C_start;
    logic        I2C_stop;
    logic [ 7:0] tx_data;
    logic        tx_done;
    logic        ack_error;

    OV7670_config_rom U_OV7670_config_rom (
        .clk     (clk),
        .rom_addr(rom_addr),
        .rom_data(rom_data)
    );

    SCCB_ControlUnit U_SCCB_CU (
        .clk      (clk),
        .reset    (reset),
        .rom_addr (rom_addr),
        .rom_data (rom_data),
        .I2C_en   (I2C_en),
        .I2C_start(I2C_start),
        .I2C_stop (I2C_stop),
        .tx_data  (tx_data),
        .tx_done  (tx_done),
        .ack_error(ack_error)
    );

    I2C_Master #(
        .SYS_CLOCK_FREQ   (100_000_000),  // 100MHz
        .TARGET_CLOCK_FREQ(100_000),      // 100kHz
        .DIV_SCALE        (4)
    ) U_I2C_Master (
        .clk          (clk),
        .reset        (reset),
        .I2C_en       (I2C_en),
        .I2C_start    (I2C_start),
        .I2C_stop     (I2C_stop),
        .I2C_Last_Byte(1'b0),
        .tx_data      (tx_data),
        .rx_data      (),
        .tx_done      (tx_done),
        .tx_ready     (),
        .rx_done      (),
        .ack_error    (ack_error),
        .SCL          (SCL),
        .SDA          (SDA)
    );

endmodule

module SCCB_ControlUnit (
    input  logic        clk,
    input  logic        reset,
    output logic [ 7:0] rom_addr,
    input  logic [15:0] rom_data,
    output logic        I2C_en,
    output logic        I2C_start,
    output logic        I2C_stop,
    output logic [ 7:0] tx_data,
    input  logic        tx_done,
    input  logic        ack_error
);

    wire [7:0] slv_addr = 8'h42;
    wire [7:0] reg_addr = rom_data[15:8];
    wire [7:0] reg_data = rom_data[7:0];

    typedef enum {
        IDLE,
        START,
        SLV_ADDR,
        REG_ADDR,
        REG_DATA,
        STOP
    } state_e;

    state_e state, state_next;

    // State register
    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            state    <= IDLE;
            rom_addr <= 8'd0;
        end else begin
            state <= state_next;
            if (state == STOP) rom_addr <= rom_addr + 1'b1;
        end
    end

    // Next state logic and output
    always_comb begin
        state_next = state;
        I2C_en     = 1'b1;
        I2C_start  = 1'b0;
        I2C_stop   = 1'b0;
        tx_data    = 8'h00;
        case (state)
            IDLE: begin
                I2C_en = 1'b0;
                if (rom_addr <= 8'd75 && rom_data != 16'hFF_FF) begin
                    I2C_en = 1'b1;
                    state_next = START;
                end
            end
            START: begin
                I2C_start = 1'b1;
                tx_data = slv_addr;
                state_next = SLV_ADDR;
            end
            SLV_ADDR: begin
                tx_data = slv_addr;
                if (ack_error) begin
                    state_next = STOP;
                end else if (tx_done) begin
                    tx_data    = reg_addr;
                    state_next = REG_ADDR;
                end
            end
            REG_ADDR: begin
                tx_data = reg_addr;
                if (ack_error) begin
                    state_next = STOP;
                end else if (tx_done) begin
                    tx_data    = reg_data;
                    state_next = REG_DATA;
                end
            end
            REG_DATA: begin
                I2C_stop = 1'b1;
                tx_data  = reg_data;
                if (ack_error) begin
                    state_next = STOP;
                end else if (tx_done) begin
                    state_next = STOP;
                end
            end
            STOP: begin
                if (rom_addr < 8'd75 && rom_data != 16'hFF_FF) begin
                    state_next = START;
                end else begin
                    I2C_en     = 1'b0;
                    state_next = IDLE;
                end
            end
        endcase
    end

endmodule

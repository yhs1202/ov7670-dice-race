`timescale 1ns / 1ps

module I2C_Master #(
    parameter SYS_CLOCK_FREQ = 100_000_000,
    parameter TARGET_CLOCK_FREQ = 100_000,
    parameter DIV_SCALE = 4
) (
    // global signals
    input  logic       clk,
    input  logic       reset,
    // internal signals
    /// AXI4-Lite CR
    input  logic       I2C_en,
    input  logic       I2C_start,
    input  logic       I2C_stop,
    input  logic       I2C_Last_Byte,
    /// AXI4-Lite ODR
    input  logic [7:0] tx_data,
    /// AXI4-Lite IDR
    output logic [7:0] rx_data,
    /// AXI4-Lite STR
    output logic       tx_done,
    output logic       tx_ready,
    output logic       rx_done,
    output logic       ack_error,
    // external ports
    output tri         SCL,
    inout  tri         SDA
);

    logic sclk_tick;

    Clock_Divider #(
        .SYS_CLOCK_FREQ   (SYS_CLOCK_FREQ),
        .TARGET_CLOCK_FREQ(TARGET_CLOCK_FREQ),
        .DIV_SCALE        (DIV_SCALE)
    ) U_I2C_CLK_DIV (
        .clk   (clk),
        .reset (reset),
        .en    (I2C_en),
        .o_tick(sclk_tick)
    );

    typedef enum {
        IDLE,
        START,
        ADDR,
        ACK_ADDR,
        WRITE,
        ACK_W,
        READ,
        ACK_R,
        STOP
    } state_e;

    typedef enum {
        PHASE1,
        PHASE2,
        PHASE3,
        PHASE4
    } p_state_e;

    state_e state, state_next;
    p_state_e p_state, p_state_next;

    logic [3:0] bit_cnt_reg, bit_cnt_next;

    // SCL
    logic pul_scl;
    assign SCL = (pul_scl) ? 1'bz : 1'b0;

    // SDA
    logic pul_sda;
    assign SDA = (pul_sda) ? 1'bz : 1'b0;

    // DATA
    logic ReStart_reg, ReStart_next;  // Repeat Start
    logic Stop_reg, Stop_next;  // Stop
    logic LB_reg, LB_next;  // Last Byte
    logic rw_reg, rw_next;  // Read Write
    logic [7:0] tx_data_reg, tx_data_next;
    logic [7:0] rx_data_reg, rx_data_next;
    logic ack_error_reg, ack_error_next;  // NAK detected flag

    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            state         <= IDLE;
            p_state       <= PHASE1;
            bit_cnt_reg   <= 0;
            tx_data_reg   <= 0;
            rx_data_reg   <= 0;
            ReStart_reg   <= 0;
            Stop_reg      <= 0;
            LB_reg        <= 0;
            rw_reg        <= 0;
            ack_error_reg <= 0;
        end else begin
            state         <= state_next;
            p_state       <= p_state_next;
            bit_cnt_reg   <= bit_cnt_next;
            tx_data_reg   <= tx_data_next;
            ReStart_reg   <= ReStart_next;
            Stop_reg      <= Stop_next;
            LB_reg        <= LB_next;
            rw_reg        <= rw_next;
            rx_data_reg   <= rx_data_next;
            ack_error_reg <= ack_error_next;
            if (state == ACK_R && p_state == PHASE4) rx_data <= rx_data_reg;
        end
    end

    always_comb begin
        state_next     = state;
        p_state_next   = p_state;
        bit_cnt_next   = bit_cnt_reg;
        pul_scl        = 1'b1;
        pul_sda        = 1'b1;
        ReStart_next   = ReStart_reg;
        Stop_next      = Stop_reg;
        LB_next        = LB_reg;
        rw_next        = rw_reg;
        tx_data_next   = tx_data_reg;
        tx_done        = 1'b0;
        tx_ready       = 1'b0;
        rx_data_next   = rx_data_reg;
        rx_done        = 1'b0;
        ack_error_next = ack_error_reg;
        ack_error      = 1'b0;
        if (!I2C_en) Stop_next = 1'b1;
        case (state)
            IDLE: begin
                p_state_next   = PHASE1;
                bit_cnt_next   = 0;
                pul_scl        = 1'b1;
                pul_sda        = 1'b1;
                tx_ready       = 1'b1;
                ReStart_next   = 1'b0;
                Stop_next      = 1'b0;
                LB_next        = 1'b0;
                ack_error_next = 1'b0;
                if (I2C_en && I2C_start) begin
                    tx_data_next = tx_data;
                    LB_next      = I2C_Last_Byte;
                    state_next   = START;
                end
            end
            START: begin
                tx_ready = 1'b0;
                case (p_state)
                    PHASE1: begin
                        pul_scl = 1'b1;
                        pul_sda = 1'b0;
                        rw_next = tx_data_reg[0];
                        if (sclk_tick) p_state_next = PHASE2;
                    end
                    PHASE2: begin
                        pul_scl = 1'b1;
                        pul_sda = 1'b0;
                        if (sclk_tick) p_state_next = PHASE3;
                    end
                    PHASE3: begin
                        pul_scl = 1'b0;
                        pul_sda = 1'b0;
                        if (sclk_tick) p_state_next = PHASE4;
                    end
                    PHASE4: begin
                        pul_scl = 1'b0;
                        pul_sda = 1'b0;
                        if (sclk_tick) begin
                            p_state_next = PHASE1;
                            state_next   = ADDR;
                        end
                    end
                endcase
            end
            ADDR: begin
                pul_sda = tx_data_reg[7];
                case (p_state)
                    PHASE1: begin
                        pul_scl = 1'b0;
                        if (sclk_tick) p_state_next = PHASE2;
                    end
                    PHASE2: begin
                        pul_scl = 1'b1;
                        if (sclk_tick) p_state_next = PHASE3;
                    end
                    PHASE3: begin
                        pul_scl = 1'b1;
                        if (sclk_tick) p_state_next = PHASE4;
                    end
                    PHASE4: begin
                        pul_scl = 1'b0;
                        if (sclk_tick) begin
                            p_state_next = PHASE1;
                            tx_data_next = {tx_data_reg[6:0], 1'b0};
                            if (bit_cnt_reg == 7) begin
                                bit_cnt_next = 0;
                                state_next   = ACK_ADDR;
                            end else bit_cnt_next = bit_cnt_reg + 1;
                        end
                    end
                endcase
            end
            ACK_ADDR: begin
                case (p_state)
                    PHASE1: begin
                        pul_scl = 1'b0;
                        if (sclk_tick) p_state_next = PHASE2;
                    end
                    PHASE2: begin
                        pul_scl = 1'b1;
                        if (sclk_tick) begin
                            p_state_next = PHASE3;
                            if (SDA) ack_error_next = 1'b1;
                        end
                    end
                    PHASE3: begin
                        pul_scl = 1'b1;
                        if (sclk_tick) p_state_next = PHASE4;
                    end
                    PHASE4: begin
                        pul_scl = 1'b0;
                        if (sclk_tick) begin
                            p_state_next = PHASE1;
                            if (Stop_reg) begin
                                Stop_next  = 1'b0;
                                state_next = STOP;
                            end else if (ack_error_reg) begin
                                // NAK received: assert tx_done and go to STOP sequence
                                tx_ready = 1'b1;
                                tx_done = 1'b1;
                                state_next = STOP;
                            end else begin
                                tx_ready = 1'b1;
                                tx_done  = 1'b1;
                                if (rw_reg) state_next = READ;
                                else begin
                                    tx_data_next = tx_data;
                                    state_next   = WRITE;
                                end
                            end
                        end
                    end
                endcase
            end
            WRITE: begin
                pul_sda = tx_data_reg[7];
                case (p_state)
                    PHASE1: begin
                        pul_scl = 1'b0;
                        if (bit_cnt_reg == 0) begin
                            if (I2C_stop) Stop_next = 1'b1;
                            else if (I2C_start) ReStart_next = 1'b1;
                        end
                        if (sclk_tick) begin
                            p_state_next = PHASE2;
                        end
                    end
                    PHASE2: begin
                        pul_scl = 1'b1;
                        if (sclk_tick) p_state_next = PHASE3;
                    end
                    PHASE3: begin
                        pul_scl = 1'b1;
                        if (sclk_tick) p_state_next = PHASE4;
                    end
                    PHASE4: begin
                        pul_scl = 1'b0;
                        if (sclk_tick) begin
                            p_state_next = PHASE1;
                            tx_data_next = {tx_data_reg[6:0], 1'b0};
                            if (bit_cnt_reg == 7) begin
                                bit_cnt_next = 0;
                                state_next   = ACK_W;
                            end else bit_cnt_next = bit_cnt_reg + 1;
                        end
                    end
                endcase
            end
            ACK_W: begin
                case (p_state)
                    PHASE1: begin
                        pul_scl = 1'b0;
                        if (sclk_tick) p_state_next = PHASE2;
                    end
                    PHASE2: begin
                        pul_scl = 1'b1;
                        if (sclk_tick) begin
                            p_state_next = PHASE3;
                            if (SDA) ack_error_next = 1'b1;
                        end
                    end
                    PHASE3: begin
                        pul_scl = 1'b1;
                        if (sclk_tick) p_state_next = PHASE4;
                    end
                    PHASE4: begin
                        pul_scl = 1'b0;
                        if (sclk_tick) begin
                            p_state_next = PHASE1;
                            if (Stop_reg) begin
                                Stop_next  = 1'b0;
                                state_next = STOP;
                            end else if (ack_error_reg) begin
                                tx_done    = 1'b1;
                                tx_ready   = 1'b1;
                                state_next = STOP;
                            end else if (ReStart_reg) begin
                                tx_data_next = tx_data;
                                LB_next      = I2C_Last_Byte;
                                state_next   = STOP;
                            end else begin
                                tx_done      = 1'b1;
                                tx_ready     = 1'b1;
                                tx_data_next = tx_data;
                                state_next   = WRITE;
                            end
                        end
                    end
                endcase
            end
            READ: begin
                pul_sda = 1'b1;
                case (p_state)
                    PHASE1: begin
                        pul_scl = 1'b0;
                        if (bit_cnt_reg == 0) begin
                            if (I2C_stop) Stop_next = 1'b1;
                            else if (I2C_start) ReStart_next = 1'b1;
                            LB_next = I2C_Last_Byte;
                        end
                        if (sclk_tick) begin
                            p_state_next = PHASE2;
                        end
                    end
                    PHASE2: begin
                        pul_scl = 1'b1;
                        if (sclk_tick) begin
                            rx_data_next = {rx_data_reg[6:0], SDA};
                            p_state_next = PHASE3;
                        end
                    end
                    PHASE3: begin
                        pul_scl = 1'b1;
                        if (sclk_tick) p_state_next = PHASE4;
                    end
                    PHASE4: begin
                        pul_scl = 1'b0;
                        if (sclk_tick) begin
                            p_state_next = PHASE1;
                            if (bit_cnt_reg == 7) begin
                                bit_cnt_next = 0;
                                state_next   = ACK_R;
                            end else bit_cnt_next = bit_cnt_reg + 1;
                        end
                    end
                endcase
            end
            ACK_R: begin
                pul_sda = (LB_reg || ReStart_reg || Stop_reg) ? 1'b1 : 1'b0;
                case (p_state)
                    PHASE1: begin
                        pul_scl = 1'b0;
                        if (sclk_tick) p_state_next = PHASE2;
                    end
                    PHASE2: begin
                        pul_scl = 1'b1;
                        if (sclk_tick) p_state_next = PHASE3;
                    end
                    PHASE3: begin
                        pul_scl = 1'b1;
                        if (sclk_tick) p_state_next = PHASE4;
                    end
                    PHASE4: begin
                        pul_scl = 1'b0;
                        if (sclk_tick) begin
                            tx_ready = 1'b1;
                            rx_done = 1'b1;
                            p_state_next = PHASE1;
                            if (LB_reg) begin
                                LB_next = 1'b0;
                                state_next = STOP;
                            end else if (Stop_reg) begin
                                Stop_next  = 1'b0;
                                state_next = STOP;
                            end else if (ReStart_reg) begin
                                tx_data_next = tx_data;
                                LB_next      = I2C_Last_Byte;
                                state_next   = STOP;
                            end else state_next = READ;
                        end
                    end
                endcase
            end
            STOP: begin
                case (p_state)
                    PHASE1: begin
                        pul_scl = 1'b1;
                        pul_sda = 1'b0;
                        if (sclk_tick) p_state_next = PHASE2;
                    end
                    PHASE2: begin
                        pul_scl = 1'b1;
                        pul_sda = 1'b0;
                        if (sclk_tick) p_state_next = PHASE3;
                    end
                    PHASE3: begin
                        pul_scl = 1'b1;
                        pul_sda = 1'b1;
                        if (sclk_tick) p_state_next = PHASE4;
                    end
                    PHASE4: begin
                        pul_scl = 1'b1;
                        pul_sda = 1'b1;
                        if (sclk_tick) begin
                            tx_done = 1'b1;
                            tx_ready = 1'b1;
                            p_state_next = PHASE1;
                            if (ack_error_reg) begin
                                ack_error  = 1'b1;
                                state_next = IDLE;
                            end else if (ReStart_reg) begin
                                ReStart_next = 1'b0;
                                state_next   = START;
                            end else state_next = IDLE;
                        end
                    end
                endcase
            end
        endcase
    end
endmodule

module Clock_Divider #(
    parameter SYS_CLOCK_FREQ = 100_000_000,
    parameter TARGET_CLOCK_FREQ = 100_000,
    parameter DIV_SCALE = 4
) (
    input  logic clk,
    input  logic reset,
    input  logic en,
    output logic o_tick
);

    parameter CLOCK_DIV = SYS_CLOCK_FREQ / TARGET_CLOCK_FREQ;
    parameter F_COUNT = CLOCK_DIV / DIV_SCALE;

    logic [$clog2(F_COUNT)-1:0] counter = 0;

    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            counter <= 0;
            o_tick  <= 0;
        end else begin
            if (en) begin
                if (counter == F_COUNT - 1) begin
                    counter <= 0;
                    o_tick  <= 1;
                end else begin
                    counter <= counter + 1;
                    o_tick  <= 0;
                end
            end
        end
    end
endmodule

`timescale 1ns/1ps
module tb_game_logic ();

    // Parameters
    parameter CLK_PERIOD = 10;  // 100MHz clock (10ns period)

    // Signals
    logic clk;
    logic reset;
    logic start_btn;

    logic dice_valid;
    logic [1:0] dice_value;

    logic [3:0] p1_pos;
    logic [3:0] p2_pos;
    logic winner_valid;
    logic winner_id;
    logic [15:0] led_test;
    logic [15:0] led_output;


    // DUT instantiation
    game_logic dut (
        .clk        (clk),
        .reset      (reset),
        .start_btn  (start_btn),
        .dice_valid (dice_valid),
        .dice_value (dice_value),
        .p1_pos     (p1_pos),
        .p2_pos     (p2_pos),
        .winner_valid(winner_valid),
        .winner_id  (winner_id),
        .led_test   (led_test),
        .led_output (led_output)
    );


    always #5 clk = ~clk;  // 100MHz clock
    initial begin
        // Initialize
        #0
        clk = 0;
        reset = 1;
        start_btn = 0;
        dice_valid = 0;
        dice_value = 0;

        #(CLK_PERIOD * 20);

        // Release reset
        reset = 0;
        #(CLK_PERIOD * 20);

        // Test sequence
        start_btn = 1; // Press start button
        #(CLK_PERIOD * 20);
        start_btn = 0; // Release start button

        // Simulate dice rolls and game progression
        // repeat (10) begin
            // #(CLK_PERIOD * 100);
            // dice_value = $urandom_range(1, 3); // Random dice value between 1 and 3
            // dice_valid = 1; // Indicate valid dice roll
            // #(CLK_PERIOD * 20);
            // dice_valid = 0; // Clear valid signal
        // end
    end

endmodule
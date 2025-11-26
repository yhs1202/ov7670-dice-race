// Description: Maps tile index (0~9) to x,y coordinates for display

module tile_position_mapper (
    input  logic [3:0] tile_idx, // 0~9
    output logic [9:0] x,
    output logic [9:0] y
);
    always_comb begin
        case(tile_idx)
            4'd0: x = 20;   // starting position
            4'd1: x = 80;
            4'd2: x = 140;
            4'd3: x = 200;
            4'd4: x = 260;
            4'd5: x = 320;
            4'd6: x = 380;
            4'd7: x = 440;
            4'd8: x = 500;
            4'd9: x = 560;
            default: x = 0;
        endcase
        y = 120;
    end
endmodule

// =============================================
// FINISH 텍스트 렌더러 (for 10th tile reached)
// =============================================
module finish_renderer #(
    parameter SCREEN_CENTER_X = 320, // 화면 중앙 X
    parameter SCREEN_CENTER_Y = 240  // 화면 중앙 Y
)(
    input  logic [9:0] x,
    input  logic [9:0] y,
    input  logic       finish_en,   // 플레이어가 10칸 도착했을 때 1

    output logic       finish_on,
    output logic [7:0] r,
    output logic [7:0] g,
    output logic [7:0] b
);

    // ---------------------------------------------------------
    // FINISH 문자열은 6 글자(F I N I S H)
    // 글자 하나는 40x60 크기로 구성
    // ---------------------------------------------------------
    localparam CHAR_W = 40;
    localparam CHAR_H = 60;
    localparam TOTAL_W = CHAR_W * 6;

    // FINISH 출력 시작 좌표 (중앙 정렬)
    localparam FINISH_X_START = SCREEN_CENTER_X - (TOTAL_W / 2);
    localparam FINISH_Y_START = SCREEN_CENTER_Y - (CHAR_H / 2);

    // 좌표를 FINISH 영역으로 이동
    logic [9:0] lx = x - FINISH_X_START;
    logic [9:0] ly = y - FINISH_Y_START;

    // FINISH 전체 영역 활성화
    wire in_finish_area =
          (lx < TOTAL_W) &&
          (ly < CHAR_H);

    // ---------------------------------------------------------
    // 문자 bitmap 대신 간단한 shape 기반 stroke 폰트
    // ---------------------------------------------------------

    function logic is_F(input int xx, input int yy);
        return (yy < 10) ||                  // 상단 바
               (xx < 8)  ||                  // 좌측 바
               (yy > 20 && yy < 28);         // 중간 바
    endfunction

    function logic is_I(input int xx, input int yy);
        return (yy < 10) ||
               (yy > CHAR_H-10) ||
               (xx > CHAR_W/2 - 4 && xx < CHAR_W/2 + 4);
    endfunction

    function logic is_N(input int xx, input int yy);
        return (xx < 8) ||
               (xx > CHAR_W-8) ||
               (xx > yy/2 && xx < yy/2 + 10);
    endfunction

    function logic is_S(input int xx, input int yy);
        return (yy < 10) ||
               (yy > CHAR_H-10) ||
               (yy > 20 && yy < 28) ||
               (xx < 10 && yy < CHAR_H/2) ||
               (xx > CHAR_W-10 && yy > CHAR_H/2);
    endfunction

    function logic is_H(input int xx, input int yy);
        return (xx < 8) ||
               (xx > CHAR_W-8) ||
               (yy > CHAR_H/2 - 4 && yy < CHAR_H/2 + 4);
    endfunction

    // ---------------------------------------------------------
    // FINISH 문자 판별
    // ---------------------------------------------------------
    logic pixel_on;
    
    // Optimization: Use logic vectors instead of int to prevent 32-bit inference
    logic [2:0] char_idx;
    logic [9:0] char_x;
    logic [9:0] char_y;

    always_comb begin
        pixel_on = 0;
        char_idx = 0;
        char_x = 0;
        char_y = 0;

        if (finish_en && in_finish_area) begin
            /* 
            // Original Code: Uses expensive division and modulo operators
            int char_idx = lx / CHAR_W;
            int char_x   = lx % CHAR_W;
            int char_y   = ly;

            case (char_idx)
                0: pixel_on = is_F(char_x, char_y);
                1: pixel_on = is_I(char_x, char_y);
                2: pixel_on = is_N(char_x, char_y);
                3: pixel_on = is_I(char_x, char_y);
                4: pixel_on = is_S(char_x, char_y);
                5: pixel_on = is_H(char_x, char_y);
                default: pixel_on = 0;
            endcase
            */

            // Optimized Code: Replaces division with comparators and subtraction
            // This significantly reduces LUT usage (logic resources)
            char_y = ly;
            
            if (lx < CHAR_W) begin 
                char_idx = 0; 
                char_x = lx; 
            end else if (lx < CHAR_W * 2) begin 
                char_idx = 1; 
                char_x = lx - CHAR_W; 
            end else if (lx < CHAR_W * 3) begin 
                char_idx = 2; 
                char_x = lx - CHAR_W * 2; 
            end else if (lx < CHAR_W * 4) begin 
                char_idx = 3; 
                char_x = lx - CHAR_W * 3; 
            end else if (lx < CHAR_W * 5) begin 
                char_idx = 4; 
                char_x = lx - CHAR_W * 4; 
            end else begin 
                char_idx = 5; 
                char_x = lx - CHAR_W * 5; 
            end

            case (char_idx)
                0: pixel_on = is_F(char_x, char_y);
                1: pixel_on = is_I(char_x, char_y);
                2: pixel_on = is_N(char_x, char_y);
                3: pixel_on = is_I(char_x, char_y);
                4: pixel_on = is_S(char_x, char_y);
                5: pixel_on = is_H(char_x, char_y);
                default: pixel_on = 0;
            endcase
        end
    end

    // ---------------------------------------------------------
    // Colors (Mario-style bold pixel art)
    // ---------------------------------------------------------
    localparam [7:0] BG_R = 255;
    localparam [7:0] BG_G = 220;
    localparam [7:0] BG_B = 0;       // Yellow Mario coin style

    localparam [7:0] FG_R = 255;
    localparam [7:0] FG_G = 255;
    localparam [7:0] FG_B = 255;     // WHITE text

    // Out
    always_comb begin
        if (finish_en && in_finish_area) begin
            finish_on = 1;
            if (pixel_on)
                {r, g, b} = {FG_R, FG_G, FG_B};
            else
                {r, g, b} = {BG_R, BG_G, BG_B};
        end else begin
            finish_on = 0;
            {r, g, b} = 24'h000000;
        end
    end

endmodule

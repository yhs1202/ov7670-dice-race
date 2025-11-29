// player_controller.sv
// 플레이어 이동 + 점프 제어 (2명, 턴제)
// 동작: 수평 이동 → 점프 (깃발 도착 시 FLAG_SLIDING)
// Game Logic 인터페이스: pos_x + pos_valid

module player_controller (
    input  logic       clk,
    input  logic       rst,

    // Game Logic 인터페이스 (턴제 게임)
    input  logic [9:0] player1_pos_x,      // Player 1 목표 x 좌표
    input  logic [9:0] player2_pos_x,      // Player 2 목표 x 좌표
    input  logic       pos_valid,          // 위치 업데이트 (1 cycle pulse)
    input  logic       active_player,      // 0=Player1, 1=Player2

    // 플레이어 위치 출력
    output logic [9:0] player1_x,          // Player 1 현재 x 좌표
    output logic [9:0] player1_y,          // Player 1 현재 y 좌표
    output logic [9:0] player2_x,          // Player 2 현재 x 좌표
    output logic [9:0] player2_y,          // Player 2 현재 y 좌표

    // 턴 완료 신호
    output logic       turn_done           // 턴 완료 (1 cycle pulse)
);

    // ========================================
    // 파라미터
    // ========================================
    localparam START_X = 20;             // 시작 위치
    localparam FLAG_X = 620;             // 깃발 위치
    localparam BASE_Y = 124;             // 플레이어 기본 y 위치 (잔디 위)

    localparam MOVE_FRAMES = 24;         // 수평 이동 프레임 수
    localparam JUMP_FRAMES = 16;         // 점프 프레임 수
    localparam FLAG_SLIDE_FRAMES = 20;   // 깃발 슬라이딩 프레임 수
    localparam FLAG_TOP_Y = 90;          // 깃발 꼭대기 y 위치

    // ========================================
    // 상태 정의
    // ========================================
    typedef enum logic [2:0] {
        IDLE         = 3'b000,
        MOVING       = 3'b001,
        JUMPING      = 3'b010,
        FLAG_SLIDING = 3'b011
    } state_t;

    state_t state, next_state;

    // ========================================
    // 내부 신호
    // ========================================
    logic current_player;                // 0=Player1, 1=Player2
    logic [9:0] start_x, target_x;       // 이동 시작/목표 x 좌표
    logic [9:0] current_x;               // 현재 x 좌표 (이동 중)
    logic [9:0] current_y;               // 현재 y 좌표 (점프/슬라이딩 중)
    logic [4:0] counter;                 // 애니메이션 카운터

    // 각 플레이어의 현재 위치 저장
    logic [9:0] player1_x_reg, player1_y_reg;
    logic [9:0] player2_x_reg, player2_y_reg;

    // Edge detection for pos_valid
    logic pos_valid_prev;
    logic pos_pulse;

    // Animation Speed Control
    // 25MHz clock. 60Hz frame rate is approx 416,666 cycles.
    // Let's update animation every ~16ms (60Hz)
    localparam REFRESH_TICK = 416666; 
    logic [18:0] tick_counter;
    logic frame_tick;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            tick_counter <= 0;
            frame_tick <= 0;
        end else begin
            if (tick_counter == REFRESH_TICK - 1) begin
                tick_counter <= 0;
                frame_tick <= 1;
            end else begin
                tick_counter <= tick_counter + 1;
                frame_tick <= 0;
            end
        end
    end

    // 점프 높이 LUT (삼각형 커브) - localparam array
    localparam logic [5:0] JUMP_LUT [0:15] = '{
        6'd0,  6'd4,  6'd8,  6'd12, 6'd16, 6'd20, 6'd24, 6'd28,
        6'd30, 6'd28, 6'd24, 6'd20, 6'd16, 6'd12, 6'd8,  6'd4
    };

    // ========================================
    // Edge detection (Rising edge만 감지)
    // ========================================
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            pos_valid_prev <= 1'b0;
        end else begin
            pos_valid_prev <= pos_valid;
        end
    end

    assign pos_pulse = pos_valid && !pos_valid_prev;

    // ========================================
    // 상태 머신
    // ========================================
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            counter <= 5'd0;
            current_player <= 1'b0;
            start_x <= START_X;
            target_x <= START_X;
            player1_x_reg <= START_X;
            player1_y_reg <= BASE_Y;
            player2_x_reg <= START_X;
            player2_y_reg <= BASE_Y;
        end else begin
            state <= next_state;

            case (state)
                IDLE: begin
                    counter <= 5'd0;

                    // pos_valid rising edge 감지 시
                    if (pos_pulse) begin
                        current_player <= active_player;  // active_player로 현재 플레이어 결정

                        if (active_player == 1'b0) begin
                            // Player 1 이동
                            start_x <= player1_x_reg;
                            target_x <= player1_pos_x;
                        end else begin
                            // Player 2 이동
                            start_x <= player2_x_reg;
                            target_x <= player2_pos_x;
                        end
                    end
                end

                MOVING: begin
                    if (frame_tick) begin
                        counter <= counter + 1;
                        if (counter == MOVE_FRAMES - 1) begin
                            // 이동 완료, 위치 업데이트
                            if (current_player == 1'b0)
                                player1_x_reg <= target_x;
                            else
                                player2_x_reg <= target_x;
                            counter <= 5'd0;
                        end
                    end
                end

                JUMPING: begin
                    if (frame_tick) begin
                        counter <= counter + 1;
                        if (counter == JUMP_FRAMES - 1) begin
                            counter <= 5'd0;
                        end
                    end
                end

                FLAG_SLIDING: begin
                    if (frame_tick) begin
                        counter <= counter + 1;
                        if (counter == FLAG_SLIDE_FRAMES - 1) begin
                            // 슬라이딩 완료, y 좌표 복귀
                            if (current_player == 1'b0)
                                player1_y_reg <= BASE_Y;
                            else
                                player2_y_reg <= BASE_Y;
                            counter <= 5'd0;
                        end
                    end
                end
            endcase
        end
    end

    // 다음 상태 로직
    always_comb begin
        case (state)
            IDLE: begin
                if (pos_pulse)
                    next_state = MOVING;
                else
                    next_state = IDLE;
            end

            MOVING: begin
                if (frame_tick && counter == MOVE_FRAMES - 1)
                    next_state = JUMPING;
                else
                    next_state = MOVING;
            end

            JUMPING: begin
                if (frame_tick && counter == JUMP_FRAMES - 1) begin
                    // 깃발 도착 (x=620)이면 FLAG_SLIDING, 아니면 IDLE
                    if (target_x == FLAG_X)
                        next_state = FLAG_SLIDING;
                    else
                        next_state = IDLE;
                end else begin
                    next_state = JUMPING;
                end
            end

            FLAG_SLIDING: begin
                if (frame_tick && counter == FLAG_SLIDE_FRAMES - 1)
                    next_state = IDLE;
                else
                    next_state = FLAG_SLIDING;
            end

            default: next_state = IDLE;
        endcase
    end

    // ========================================
    // X 좌표 계산 (수평 이동)
    // ========================================
    always_comb begin
        if (state == MOVING) begin
            // 선형 보간 (start_x → target_x)
            current_x = start_x + ((target_x - start_x) * counter) / MOVE_FRAMES;
        end else begin
            // 이동 중이 아니면 현재 플레이어의 저장된 위치
            if (current_player == 1'b0)
                current_x = player1_x_reg;
            else
                current_x = player2_x_reg;
        end
    end

    // ========================================
    // Y 좌표 계산 (점프 + 깃발 슬라이딩)
    // ========================================
    logic [9:0] jump_offset;
    logic [9:0] slide_y;

    always_comb begin
        // 점프 오프셋 (LUT 사용)
        if (state == JUMPING) begin
            jump_offset = JUMP_LUT[counter[3:0]];
        end else begin
            jump_offset = 0;
        end

        // 깃발 슬라이딩 y 좌표 (선형 감소)
        if (state == FLAG_SLIDING) begin
            slide_y = FLAG_TOP_Y + ((BASE_Y - FLAG_TOP_Y) * counter) / FLAG_SLIDE_FRAMES;
        end else begin
            slide_y = BASE_Y;
        end

        // 최종 y 좌표
        if (state == FLAG_SLIDING) begin
            current_y = slide_y;
        end else begin
            current_y = BASE_Y - jump_offset;
        end
    end

    // ========================================
    // turn_done 신호 생성 (1 cycle pulse)
    // ========================================
    logic turn_done_reg;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            turn_done_reg <= 1'b0;
        end else begin
            // JUMPING → IDLE 또는 FLAG_SLIDING → IDLE 전환 시
            if ((state == JUMPING && next_state == IDLE && target_x != FLAG_X) ||
                (state == FLAG_SLIDING && next_state == IDLE)) begin
                turn_done_reg <= 1'b1;
            end else begin
                turn_done_reg <= 1'b0;
            end
        end
    end

    // ========================================
    // 출력
    // ========================================
    // Player 1 출력
    assign player1_x = (state != IDLE && current_player == 1'b0) ? current_x : player1_x_reg;
    assign player1_y = (state != IDLE && current_player == 1'b0) ? current_y : player1_y_reg;

    // Player 2 출력
    assign player2_x = (state != IDLE && current_player == 1'b1) ? current_x : player2_x_reg;
    assign player2_y = (state != IDLE && current_player == 1'b1) ? current_y : player2_y_reg;

    // 턴 완료 신호
    assign turn_done = turn_done_reg;

endmodule

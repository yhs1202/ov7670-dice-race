// color_pkg.sv
// 색상 정의 패키지 (VGA RGB 24-bit)

package color_pkg;

    // RGB 구조체 타입 정의
    typedef struct packed {
        logic [7:0] r;
        logic [7:0] g;
        logic [7:0] b;
    } rgb_t;

    // ========================================
    // 하늘 색상
    // ========================================
    parameter rgb_t SKY_LIGHT_BLUE = '{r: 8'h87, g: 8'hCE, b: 8'hEB};  // 밝은 하늘색
    parameter rgb_t SKY_BLUE       = '{r: 8'h5D, g: 8'hAD, b: 8'hE2};  // 기본 하늘색

    // ========================================
    // 잔디 색상 (Minecraft 스타일)
    // ========================================
    parameter rgb_t GRASS_BRIGHT   = '{r: 8'h7F, g: 8'hC8, b: 8'h3F};  // 밝은 초록 (윗줄)
    parameter rgb_t GRASS_GREEN    = '{r: 8'h55, g: 8'hA0, b: 8'h2F};  // 진한 초록

    // ========================================
    // 흙 색상 (Minecraft 스타일)
    // ========================================
    parameter rgb_t DIRT_DARK      = '{r: 8'h6B, g: 8'h4A, b: 8'h2F};  // 어두운 갈색
    parameter rgb_t DIRT_MID       = '{r: 8'h8B, g: 8'h65, b: 8'h3F};  // 중간 갈색
    parameter rgb_t DIRT_LIGHT     = '{r: 8'hA0, g: 8'h7A, b: 8'h50};  // 밝은 갈색
    parameter rgb_t DIRT_GRAY      = '{r: 8'h70, g: 8'h70, b: 8'h70};  // 회색 (돌 느낌)

    // ========================================
    // 게임 오브젝트 색상 - IC 칩 캐릭터
    // ========================================
    parameter rgb_t IC_BLACK       = '{r: 8'h20, g: 8'h20, b: 8'h20};  // IC 몸체 (검정)
    parameter rgb_t IC_GRAY        = '{r: 8'h50, g: 8'h50, b: 8'h50};  // IC 테두리 (다크 그레이)
    parameter rgb_t IC_SILVER      = '{r: 8'hC0, g: 8'hC0, b: 8'hC0};  // 메탈 핀 (은색)
    parameter rgb_t IC_RED         = '{r: 8'hFF, g: 8'h00, b: 8'h00};  // 방향 표시 (빨강)

    parameter rgb_t BOX_YELLOW     = '{r: 8'hFF, g: 8'hCC, b: 8'h00};  // 노란색 (? 박스)
    parameter rgb_t BOX_ORANGE     = '{r: 8'hFF, g: 8'h99, b: 8'h00};  // 주황색 (테두리)
    parameter rgb_t BOX_BROWN      = '{r: 8'h8B, g: 8'h4F, b: 8'h13};  // 갈색 (그림자)

    // ========================================
    // UI 색상
    // ========================================
    parameter rgb_t WHITE          = '{r: 8'hFF, g: 8'hFF, b: 8'hFF};  // 흰색
    parameter rgb_t BLACK          = '{r: 8'h00, g: 8'h00, b: 8'h00};  // 검정
    parameter rgb_t TRANSPARENT    = '{r: 8'hFF, g: 8'h00, b: 8'hFF};  // 투명 (마젠타)

    // ========================================
    // 주사위 색상 (나중에 사용)
    // ========================================
    parameter rgb_t DICE_RED       = '{r: 8'hFF, g: 8'h00, b: 8'h00};
    parameter rgb_t DICE_GREEN     = '{r: 8'h00, g: 8'hFF, b: 8'h00};
    parameter rgb_t DICE_BLUE      = '{r: 8'h00, g: 8'h00, b: 8'hFF};

endpackage


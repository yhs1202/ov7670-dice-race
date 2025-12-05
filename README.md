# ov7670-dice-race (FPGA-Based RGB Dice Race Game)

Real-time hardware-accelerated dice game using dual OV7670 cameras on a Basys-3 FPGA.

This system detects the color of a custom dice to control player movement, renders live video with visual effects, and features smooth animation, noise-resistant color detection, and a fully pipelined hardware architecture.


![image.png](/docs/readme_imgs/image.png)

## 1. Introduction

This project implements a real-time racing game driven by RGB dice detection.

A custom-pattern dice is captured by an OV7670 camera, and its color determines the number of steps a player moves. A second camera provides a live video feed, where visual filters are applied on special tiles.

**Game Summary:**

- Throw the dice into a capture zone.
- Detect dice color → Red(1), Green(2), Blue(3) steps.
- Animate player movement across a 10-tile board.
- Apply video filters at tiles {2, 4, 6, 8}.
- If the player lands on tile 3, they are sent back to the starting point. (0)
- First player reaching tile 10 wins.

## 2. Directory Structure

```
ov7670-dice-race/
├── constr/
│   └── Basys-3-Master.xdc              # Board pin constraints
│
├── scripts/
│   ├── bit.tcl                         # Project build + Generate bitstream Script
│   ├── build.tcl                       # Project build Script
│   └── sim.tcl                         # Project build + Simulation Script
│
├── sim/
│
├── src/                                # All RTL modules (SystemVerilog)
│   ├── DiceRace_System.sv              # Top-level module (full integration)
│   │
│   ├── color_detect/                   # Dice color detection pipeline
│   │   ├── Color_Result_Manager.sv     # 3-frame voting (anti-noise)
│   │   ├── Display_Overlay.sv          # Draws ROI/detection boundaries
│   │   └── ROI_Color_Detector.sv       # ROI-based dice region classifier
│   │
│   ├── filters/                        # Video filter modules
│   │   └── ...                         # (ASCII, Invert, Kaleidoscope, Mosaic)
│   │
│   ├── game_logic/                     # Core game FSM + FND display
│   │   ├── fnd_driver/                 # 7-segment display modules
│   │   ├── btn_debounce.v              # Start Button Debouncer
│   │   └── Game_Logic_Controller.sv    # Main Logic FSM
│   │
│   ├── integrated_systems/             # System-level components
│   │   ├── Camera_system.sv            # OV7670 capture -> buffer -> VGA pipeline
│   │   ├── Color_Detector.sv           # ROI + voting algorithm integrated system
│   │   ├── Img_Filter.sv               # CAM2 filter
│   │   ├── RGB_selector.sv             # Selects Output RGB layers based on priority
│   │   └── UI_Generator.sv             # Player animation targets + UI control signals
│   │
│   ├── ov7670_driver/                  # OV7670 low-level capture pipeline
│   │   ├── Frame_Buffer.sv             # Dual-port BRAM frame buffer
│   │   ├── OV7670_capture.sv           # Captures OV7670 PCLK stream -> RGB565 format
│   │   ├── OV7670_config_rom.sv        # OV7670 register initialization
│   │   ├── pixel_clk_gen.sv            # pclk generator
│   │   ├── SCCB_Interface.sv           # SCCB interface to configure OV7670
│   │   └── VGA_Syncher.sv              # Syncs camera output to VGA timing
│   │
│   ├── player_img/                     # Sprite player memory assets
│   │   └── ...
│   │
│   └── ui_render/                      # Rendering pipeline & HUD/label
│       ├── camera_label_renderer.sv    # Renders small camera-source labels
│       ├── color_pkg.sv                # color definitions
│       ├── player_controller.sv        # Calculates smooth player movement
│       ├── player_renderer.sv          # Draws the player sprite at the given (x, y) pos
│       ├── player_status_renderer.sv   # Renders player status
│       ├── tile_position_mapper.sv     # Converts board tile index into actual VGA coordinates
│       ├── UI_Intro_Renderer.sv        # Handles Intro screen graphics
│       └── UI_Game_renderer.sv         # Main UI compositor (merges background, camera views, sprites, filter-layout outputs)
├── Makefile
└── README.md
```

## 3. How to Build & Run

### Requirements

- Vivado 2020.2+
- Basys-3 FPGA (Artix-7)
- Two OV7670 cameras
- Monitor with VGA Connection

### Build (Generate Bitstream)

You can use:

```
make bit
```

### Hardware Connections

| Component | Description |
| --- | --- |
| CAM1 | Dice detection camera |
| CAM2 | User video capture |
| BtnU | Start Button |
| BtnD | Intro Select Button |
| BtnC | System reset |
| VGA | Display output |

Once programmed, the Dice System enters STATE_INTRO and waits for user input.

## 4. System Architecture

The full system consists of four modular subsystems: 

- Camera System
- Color Detector
- Game Logic Controller
- UI Renderer

This modular structure enables deterministic game flow and stable real-time image processing.

![image.png](/docs/readme_imgs/image%201.png)

### 4.1. Camera System
**SCCB configuration, frame buffering, VGA output**

![image.png](/docs/readme_imgs/image%202.png)

### 4.2. Color Detector
**RGB565 to RGB888 conversion, ROI analysis, thresholding, anti-noise voting**

![image.png](/docs/readme_imgs/image%203.png)

### 4.3. Game Logic Controller
**FSM-driven turn management, movement, events, win detection**

![image.png](/docs/readme_imgs/image%204.png)

### 4.4. UI Renderer
**Tile mapping, animation, sprite rendering, filter effects**
![image.png](/docs/readme_imgs/image%205.png)

## 5. Architecture Details

### 5.1. Hardware Interface: Camera System

---

### OV7670 Initialization

The SCCB controller configures OV7670 into **QQVGA (160×120)** mode to prevent BRAM overflow when handling two cameras.

### Frame Buffering

- Incoming 8-bit pixel stream → assembled into RGB565
- Stored into dual-port BRAM
- Read by VGA pipeline at 25 MHz

### VGA Output

The system performs nearest-neighbor upscaling (QQVGA → QVGA) and renders at **640×480** resolution.

### 5.2. Vision Processing: Dice Color Detection

---

### RGB565 → RGB888 Conversion

Enables more accurate threshold-based classification.

### ROI-Based Color Extraction

Only the dice capture zone is analyzed for color determination.

### Threshold Classification

Compares RGB values with calibrated R/G/B ranges.

### 3-Frame Voting

Buffers three consecutive frames and outputs the majority color as **stable_color**, eliminating flicker and noise spikes.

### 5.3. Game Logic Design

---

The Game Logic module coordinates the entire game flow based on the dice-color detection results and UI synchronization signals.

![2ca6939a-e101-47f8-844c-be339ca090e2.png](/docs/readme_imgs/image%209.png)

### Key Signals

Through these signals, the Game Logic governs movement updates, event handling, filter activation timing, win conditions, and UI synchronization, ensuring that the entire system progresses deterministically frame by frame.

#### Inputs

1. **Game triggers**
    - **start_btn**: Start signal from the board
    - **turn_done**: **Animation-complete signal** from the UI Renderer
2. **Dice detection signals (from the Color Detector)**
    - **dice_value[1:0]**: Detected dice color mapped to movement steps
    - **dice_valid**: Indicates a stable detection result
    - **white_stable**: Used to confirm background state for turn transitions

#### Outputs

- **p1_pos, p2_pos, pos_valid**: Player positions for UI rendering
- **turn**: forward to UI renderer for on-screen turn indication
- **event_flag[3:0]**: to request filter activation when a player lands on a special tile
- **winner_valid, winner_id:** Winner information for displaying the “FINISH” screen
- **led_output, fnd_data, fnd_com**: Board state outputs such as remaining time and turn status

### FSM States

The FSM ensures timing alignment between detection, UI animation, and turn transitions.

![image.png](/docs/readme_imgs/image%206.png)

### 5.4. UI & Visualization

---

### Screen Layout (Split Screen)

1. Top (Game World)
    - Purely generated graphics (Sky, Grass, Characters) rendering the race progress.
2. Bottom (Real-world Interaction)
    - Live camera feeds (Dice & Face) with UI overlays.

### Tile Mapper

Converts logical tile index (0~10) → Physical VGA coordinates.
Defines the U-shaped track path on the screen.

### Player Controller (Animation Engine)

Implements an FSM (Idle → Move → Jump → Slide) to manage character states.
Movement is interpolated using frame_tick @ 60Hz, ensuring smooth animation independent of the 25MHz pixel clock.

### Parabolic Jump Logic

Calculates Y-axis offsets for realistic jumping effects.

### Sprite Renderer

Fetches pixel data from Block RAM (.mem files) based on current coordinates.
Handles Transparency to composite characters naturally over the background.

### Layering & Priority

The final output is determined by following priority, and handled by RGB_Selector in top module.

1. UI Overlay (Finish Screen, Labels, Borders)
2. Game Objects (Players, Items)
3. Game Background (Sky, Grass)
4. Camera Feed (Live Video)

### 5.5. Filter Processing

---

![image.png](/docs/readme_imgs/image%207.png)

- When the player reaches a **special tile (2, 4, 6, 8)**, the Game Logic sets a corresponding filter_sel value.
- The Img_Filter module applies the effect **only to the CAM2 display region** of the VGA screen (the lower-right 320×240 area where x_pixel >= 320 && y_pixel >= 240).
- For pixels inside this region, the selected effect is applied:
    2 → ASCII, 4 → Mosaic, 6 → Invert, 8 → Kaleidoscope.
    All other regions simply pass through the original video.
- When the event ends (e.g., after turn transition), the Game Logic clears filter_sel, and CAM2 returns to its normal, unfiltered output.

## 6. Troubleshooting & Key Insights

### 1) BRAM Resource Overflow

- two QVGA mode (320x240) frame buffers exceeded available BRAM. (Both Camera)
- **Solution:** Force OV7670 to operate QQVGA mode (160x120) via config ROM + implement hardware upscaler.

**Summary**

- BRAM usage dropped from **73% → 57%**,
- Excessive LUT/LUTRAM overflow (200%/275%) was entirely removed,
- Resource headroom was restored, allowing filter and UI renderer modules to be integrated without additional pressure on BRAM or LUT resources.

![image.png](/docs/readme_imgs/image%208.png)

### 2) Player Animation Too Fast

- Animation tied to 25 MHz pixel clock.
- **Solution:** Add a dedicated **60 Hz frame tick** with per-frame interpolation.

### 3) Turn Timing Mismatch

- Color detection and game FSM sampling were misaligned.
- **Solution:** Introduce a “white background detection frame” to synchronize state transitions.

### 4) Noise in Color Detection

- Random glitches triggered repeated unwanted moves.
- **Solution:** Implement 3-frame majority voting (Color_Result_Manager).

## 7. Demonstration

### Intro Screen


![intro.gif](/docs/readme_imgs/intro.gif)

---

### Filter activation

**NOTE:**
To demonstrate all filter effects, we forced the system to recognize only the **green dice (2 steps)** so that a single player would advance **two tiles per turn**, allowing us to record the full sequence smoothly.

![filter_demo.gif](/docs/readme_imgs/filter_demo.gif)

---

### Winning screen

![finish.gif](/docs/readme_imgs/finish.gif)

## 8. Team Roles

### ![kerby.png](/docs/readme_imgs/kerby.png) Junhoe Kim ([@junhoe99](/docs/readme_imgs/https://github.com/junhoe99)**)**


Color Detector Design, ASCII filter Design, voting algorithm, presentation

### ![player2.png](/docs/readme_imgs/player2.png) Jiin Byeon ([@JIIN-BYEON](/docs/readme_imgs/https://github.com/JIIN-BYEON)**)**

SCCB Interface and Dual-Camera VGA controller Implementation, Invert, Mosaic, and Kaleidoscope filter Design

### ![kerby.png](/docs/readme_imgs/kerby.png) Hoseung Yoon ([@yhs1202](/docs/readme_imgs/https://github.com/yhs1202))
Game logic Design, top-level module integration, automation scripts, Git workflow environment setup

### ![player2.png](/docs/readme_imgs/player2.png) Junwoo Jang ([@Junu18](/docs/readme_imgs/https://github.com/Junu18))

Sprite rendering, intro/game UI Design, player controller, visualization

## 9. Conclusion
This project provided us comprehensive experience in FPGA-based image processing, hardware animation pipelines, modular RTL design and System Integration. In addition, optimizing the system to reliably support two simultaneous camera pipelines under strict BRAM and timing constraints offered valuable insight into practical FPGA resource management.

Also, Through Git-based collaboration and scripted automation, the team established a scalable and reproducible development environment that enabled efficient iteration and debugging.
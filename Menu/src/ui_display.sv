module ui_display (
    input logic       clk,
    input logic       rst_n,
    input logic [9:0] vga_x,   // 來自 VGA 控制器 (0~639)
    input logic [9:0] vga_y,   // 來自 VGA 控制器 (已經是修正過的 0~359)
    input logic       playing, // 狀態機訊號：決定畫 Play 還是 Pause

    // 輸出 12-bit RGB (給 VGA DAC)
    output logic [3:0] vga_r,
    output logic [3:0] vga_g,
    output logic [3:0] vga_b
);

  // ==========================================
  // 1. 座標與排版設定 (UI Layout 藍圖)
  // 你可以在這裡自由調整每個部件的 X, Y 座標
  // ==========================================
  localparam int POS_RHYTHM_X = 150;
  localparam int POS_RHYTHM_Y = 77;
  localparam int POS_PLAY_X = 267;
  localparam int POS_PLAY_Y = 164;
  localparam int POS_PAUSE_X = 344;
  localparam int POS_PAUSE_Y = 164;

  // 按鈕框與內部
  localparam int POS_BTN_BASE_X = 251;
  localparam int POS_BTN_BASE_Y = 244;
  localparam int POS_BTN_TOP_X = 252;
  localparam int POS_BTN_TOP_Y = 242;

  // 字型與音量條
  localparam int POS_CHAR_L_X = 276;
  localparam int POS_CHAR_L_Y = 212;
  localparam int POS_CHAR_U_X = 306;
  localparam int POS_CHAR_U_Y = 249;
  localparam int POS_SND_BAR_X = 273;
  localparam int POS_SND_BAR_Y = 314;

  // ==========================================
  // 2. 宣告並載入 8 個圖形 ROM
  // ==========================================
  logic [29:0] rom_play[0:31];
  initial $readmemb("play_button.mem", rom_play);
  logic [29:0] rom_pause[0:31];
  initial $readmemb("pause_button.mem", rom_pause);
  logic [339:0] rom_rhythm[0:77];
  initial $readmemb("rhythm.mem", rom_rhythm);
  logic [137:0] rom_btn_base[0:23];
  initial $readmemb("btn_base.mem", rom_btn_base);
  logic [135:0] rom_btn_top[0:23];
  initial $readmemb("btn_top.mem", rom_btn_top);
  logic [154:0] rom_char_lower[0:7];
  initial $readmemb("char_lower.mem", rom_char_lower);
  logic [154:0] rom_char_upper[0:6];
  initial $readmemb("char_upper.mem", rom_char_upper);
  logic [93:0] rom_sound_bar[0:9];
  initial $readmemb("sound_bar.mem", rom_sound_bar);

  // ==========================================
  // 3. 圖層訊號提取 (直接使用 vga_y)
  // ==========================================
  logic px_rhythm, px_play, px_pause;
  logic px_btn_base, px_btn_top, px_char_l, px_char_u, px_snd_bar;

  always_comb begin
    // 預設皆為透明 (0)
    px_rhythm = 0;
    px_play = 0;
    px_pause = 0;
    px_btn_base = 0;
    px_btn_top = 0;
    px_char_l = 0;
    px_char_u = 0;
    px_snd_bar = 0;

    // 大標題 Rhythm
    if (vga_x >= POS_RHYTHM_X && vga_x < POS_RHYTHM_X + 340 && vga_y >= POS_RHYTHM_Y && vga_y < POS_RHYTHM_Y + 78)
      px_rhythm = rom_rhythm[vga_y-POS_RHYTHM_Y][339-(vga_x-POS_RHYTHM_X)];

    // Play 按鈕
    if (vga_x >= POS_PLAY_X && vga_x < POS_PLAY_X + 30 && vga_y >= POS_PLAY_Y && vga_y < POS_PLAY_Y + 32)
      px_play = rom_play[vga_y-POS_PLAY_Y][29-(vga_x-POS_PLAY_X)];

    // Pause 按鈕
    if (vga_x >= POS_PAUSE_X && vga_x < POS_PAUSE_X + 30 && vga_y >= POS_PAUSE_Y && vga_y < POS_PAUSE_Y + 32)
      px_pause = rom_pause[vga_y-POS_PAUSE_Y][29-(vga_x-POS_PAUSE_X)];

    // 按鈕陰影底框
    if (vga_x >= POS_BTN_BASE_X && vga_x < POS_BTN_BASE_X + 138 && vga_y >= POS_BTN_BASE_Y && vga_y < POS_BTN_BASE_Y + 24)
      px_btn_base = rom_btn_base[vga_y-POS_BTN_BASE_Y][137-(vga_x-POS_BTN_BASE_X)];

    // 按鈕本體
    if (vga_x >= POS_BTN_TOP_X && vga_x < POS_BTN_TOP_X + 136 && vga_y >= POS_BTN_TOP_Y && vga_y < POS_BTN_TOP_Y + 24)
      px_btn_top = rom_btn_top[vga_y-POS_BTN_TOP_Y][135-(vga_x-POS_BTN_TOP_X)];

    // 小寫字庫
    if (vga_x >= POS_CHAR_L_X && vga_x < POS_CHAR_L_X + 155 && vga_y >= POS_CHAR_L_Y && vga_y < POS_CHAR_L_Y + 8)
      px_char_l = rom_char_lower[vga_y-POS_CHAR_L_Y][154-(vga_x-POS_CHAR_L_X)];

    // 大寫字庫
    if (vga_x >= POS_CHAR_U_X && vga_x < POS_CHAR_U_X + 155 && vga_y >= POS_CHAR_U_Y && vga_y < POS_CHAR_U_Y + 7)
      px_char_u = rom_char_upper[vga_y-POS_CHAR_U_Y][154-(vga_x-POS_CHAR_U_X)];

    // 音量條
    if (vga_x >= POS_SND_BAR_X && vga_x < POS_SND_BAR_X + 94 && vga_y >= POS_SND_BAR_Y && vga_y < POS_SND_BAR_Y + 10)
      px_snd_bar = rom_sound_bar[vga_y-POS_SND_BAR_Y][93-(vga_x-POS_SND_BAR_X)];
  end

  // ==========================================
  // 4. 畫面圖層疊加與輸出 (Painter's Algorithm)
  // ==========================================
  logic final_pixel;

  always_comb begin
    final_pixel = 1'b0;  // 預設背景黑色

    // 用 OR 邏輯將所有物件畫上去 (誰是 1 就顯示白色)
    final_pixel = px_rhythm | px_btn_base | px_btn_top | px_char_l | px_char_u | px_snd_bar;

    // 根據狀態決定畫 Play 還是 Pause
    if (playing) begin
      final_pixel = final_pixel | px_pause;
    end else begin
      final_pixel = final_pixel | px_play;
    end
  end

  // 最終輸出到 12-bit VGA 色彩 (1 -> 白, 0 -> 黑)
  assign vga_r = final_pixel ? 4'hF : 4'h0;
  assign vga_g = final_pixel ? 4'hF : 4'h0;
  assign vga_b = final_pixel ? 4'hF : 4'h0;

endmodule

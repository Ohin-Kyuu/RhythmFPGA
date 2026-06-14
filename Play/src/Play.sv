// =============================================================================
// Play.sv
// -----------------------------------------------------------------------------
// 音樂節奏遊戲畫面（PLAYING 狀態）。輸出 4-bit RGB。
//
//   軌道五線（含邊界）：
//     x=130 / 510  -> 白 0xFFFF
//     x=225/320/415 -> 灰 0x73AE
//     y 範圍 1..359
//
//   座標來自頂層 VGACtrl（640x360）。
//   play_en : PLAYING 且未暫停（推進+判定）
//   play_rst: SELECT 時拉高，重置 playfield（暫停續玩時請勿拉高）
// =============================================================================
module Play (
    input  logic       clk,
    input  logic       rst_n,

    // 來自頂層 VGACtrl
    input  logic [9:0] vga_x,
    input  logic [9:0] vga_y,
    input  logic       video_valid,
    input  logic       frame_tick,
    input  logic       beat,         // 來自 Music/beatGen（同步音樂節拍）

    // 控制
    input  logic       play_en,
    input  logic       play_rst,
    input  logic [2:0] sel_song,   // 001:mario 010:zelda 100:pokemon
    input  logic [3:0] p_key,      // D,F,J,K pulse

    // VGA 輸出
    output logic [3:0] vga_r,
    output logic [3:0] vga_g,
    output logic [3:0] vga_b,

    // 給 game_fsm / Finish
    output logic [11:0] score,
    output logic        song_finish
);

  // ---- 顏色 ----
  localparam logic [11:0] C_BLACK = 12'h000;
  localparam logic [11:0] C_WHITE = 12'hFFF;            // 0xFFFF
  localparam logic [11:0] C_GRAY  = 12'h777;            // 0x73AE ≈ (7,7,7)
  // 每軌音符顏色（D/F/J/K），可自行調整
  localparam logic [11:0] C_NOTE0 = 12'hF44;  // D 紅
  localparam logic [11:0] C_NOTE1 = 12'h4F6;  // F 綠
  localparam logic [11:0] C_NOTE2 = 12'h4AF;  // J 藍
  localparam logic [11:0] C_NOTE3 = 12'hFD2;  // K 黃

  // ---------------------------------------------------------------------------
  // 節奏引擎
  // ---------------------------------------------------------------------------
  logic        note_on;
  logic [1:0]  note_lane;
  logic [3:0]  lane_pressed, lane_show_valid, lane_show_text;
  logic [11:0] lane_rating;

  play_track U_track (
      .clk            (clk),
      .rst_n          (rst_n),
      .frame_tick     (frame_tick),
      .beat           (beat),
      .play_en        (play_en),
      .play_rst       (play_rst),
      .sel_song       (sel_song),
      .p_key          (p_key),
      .vga_x          (vga_x),
      .vga_y          (vga_y),
      .note_on        (note_on),
      .note_lane      (note_lane),
      .lane_pressed   (lane_pressed),
      .lane_show_valid(lane_show_valid),
      .lane_show_text (lane_show_text),
      .lane_rating    (lane_rating),
      .score          (score),
      .song_finish    (song_finish)
  );

  // ---------------------------------------------------------------------------
  // 接收器 + 評語字
  // ---------------------------------------------------------------------------
  logic rec_on, text_on;

  play_receptors U_rec (
      .vga_x          (vga_x),
      .vga_y          (vga_y),
      .lane_pressed   (lane_pressed),
      .lane_show_valid(lane_show_valid),
      .lane_show_text (lane_show_text),
      .lane_rating    (lane_rating),
      .rec_on         (rec_on),
      .text_on        (text_on)
  );

  // ---------------------------------------------------------------------------
  // 軌道線（五條）
  // ---------------------------------------------------------------------------
  logic on_line_w, on_line_g;
  always_comb begin
    on_line_w = (vga_y >= 10'd1 && vga_y <= 10'd359) &&
                (vga_x == 10'd130 || vga_x == 10'd510);
    on_line_g = (vga_y >= 10'd1 && vga_y <= 10'd359) &&
                (vga_x == 10'd225 || vga_x == 10'd320 || vga_x == 10'd415);
  end

  // ---------------------------------------------------------------------------
  // 合成（後者覆蓋前者）：黑 -> 音符 -> 線 -> 接收器 -> 評語字
  // ---------------------------------------------------------------------------
  logic [11:0] note_color;
  always_comb begin
    unique case (note_lane)
      2'd0:    note_color = C_NOTE0;
      2'd1:    note_color = C_NOTE1;
      2'd2:    note_color = C_NOTE2;
      default: note_color = C_NOTE3;
    endcase
  end

  logic [11:0] color;
  always_comb begin
    color = C_BLACK;
    if (note_on)   color = note_color;
    if (on_line_w) color = C_WHITE;
    if (on_line_g) color = C_GRAY;
    if (rec_on)    color = C_WHITE;
    if (text_on)   color = C_WHITE;
  end

  always_comb begin
    if (video_valid) begin
      vga_r = color[11:8];
      vga_g = color[7:4];
      vga_b = color[3:0];
    end else begin
      vga_r = 4'h0;
      vga_g = 4'h0;
      vga_b = 4'h0;
    end
  end

endmodule

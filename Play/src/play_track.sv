// =============================================================================
// play_track.sv  (beat-index 基準版)
// -----------------------------------------------------------------------------
// 核心定理：
//   note_center_y(r) = RECEPTOR_C + (beat_cnt - r) * ROW_PX + sub_px
//
//   r == beat_cnt 時，note 中心剛好落在 RECEPTOR_C（Perfect 帶中心），
//   不論 beatGen 是何 BPM、三首歌節拍不同，判定線和音符永遠對齊。
//
//   sub_px：拍間插值。每 frame_tick 累積，每個 beat_p 歸零。
//   量測上一拍的 frame 數(fpb)，用來決定每 frame 前進幾 sub_px。
//   ROW_PX 為「每拍像素」= 音符列距（只影響視覺提前量，不影響對齊）。
//
//   scroll_y = beat_cnt * ROW_PX + sub_px
//   (與原公式等價，但 snap 只在每拍明確設定 beat_cnt，不動 scroll_y 當做
//    絕對捲動量，改為純計算導出，徹底避免累積誤差。)
// =============================================================================
module play_track #(
    parameter int ROW_PX      = 64,
    parameter int NOTE_H      = 28,
    parameter int FPB_DEFAULT = 30,
    parameter int LEN_MARIO   = 590,
    parameter int LEN_ZELDA   = 769,
    parameter int LEN_POKEMON = 2177,
    parameter int PERFECT_TOP = 312,
    parameter int PERFECT_BOT = 340,
    parameter int RECEPTOR_C  = 326,
    parameter int PRESS_FLASH = 6,
    parameter int VALID_SHOW  = 24
) (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        frame_tick,
    input  logic        beat,
    input  logic        play_en,
    input  logic        play_rst,
    input  logic [ 2:0] sel_song,
    input  logic [ 3:0] p_key,
    input  logic [ 3:0] key_hold,
    input  logic [ 9:0] vga_x,
    input  logic [ 9:0] vga_y,
    output logic        note_on,
    output logic [ 1:0] note_lane,
    output logic [ 3:0] lane_pressed,
    output logic [ 3:0] lane_show_valid,
    output logic [ 3:0] lane_show_text,
    output logic [11:0] lane_rating,
    output logic [11:0] score,
    output logic        song_finish
);

  // ---- 評級碼 ----
  localparam logic [2:0] R_NONE  = 3'd0;
  localparam logic [2:0] R_PERF  = 3'd1;
  localparam logic [2:0] R_GREAT = 3'd2;
  localparam logic [2:0] R_GOOD  = 3'd3;
  localparam logic [2:0] R_BAD   = 3'd4;
  localparam logic [2:0] R_MISS  = 3'd5;

  localparam int HALF_H = NOTE_H / 2;
  localparam int WIN_LO = PERFECT_TOP - 16;   // 296
  localparam int WIN_HI = PERFECT_BOT + 16;   // 356

  // ---------------------------------------------------------------------------
  // Track ROM
  // ---------------------------------------------------------------------------
  localparam int NMAX = 2200;
  logic [3:0] rom_mario  [0:NMAX-1];
  logic [3:0] rom_zelda  [0:NMAX-1];
  logic [3:0] rom_pokemon[0:NMAX-1];

  initial begin
    $readmemh("mario_key_track.mem",   rom_mario);
    $readmemh("zelda_key_track.mem",   rom_zelda);
    $readmemh("pokemon_key_track.mem", rom_pokemon);
  end

  logic [11:0] cur_len;
  always_comb begin
    unique case (sel_song)
      3'b001:  cur_len = LEN_MARIO[11:0];
      3'b010:  cur_len = LEN_ZELDA[11:0];
      3'b100:  cur_len = LEN_POKEMON[11:0];
      default: cur_len = LEN_MARIO[11:0];
    endcase
  end

  function automatic logic [3:0] rom_at(input logic [11:0] row);
    if (row >= cur_len) rom_at = 4'b0000;
    else begin
      unique case (sel_song)
        3'b001:  rom_at = rom_mario[row];
        3'b010:  rom_at = rom_zelda[row];
        3'b100:  rom_at = rom_pokemon[row];
        default: rom_at = 4'b0000;
      endcase
    end
  endfunction

  // ---------------------------------------------------------------------------
  // beat 同步（2-FF）+ 邊緣偵測
  // ---------------------------------------------------------------------------
  logic beat_m, beat_s, beat_s2, beat_p;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin beat_m<=1'b0; beat_s<=1'b0; beat_s2<=1'b0; end
    else        begin beat_m<=beat; beat_s<=beat_m; beat_s2<=beat_s; end
  end
  assign beat_p = beat_s & ~beat_s2;

  // ---------------------------------------------------------------------------
  // 狀態寄存器
  // ---------------------------------------------------------------------------
  logic [11:0] beat_cnt;    // 已過拍數；beat_cnt 拍對應 row beat_cnt
  logic [7:0]  frame_cnt;   // 這一拍已經經過幾個 frame，用來量測 frames/beat
  logic [7:0]  fpb;         // 量測到的 frames/beat
  logic [8:0]  sub_acc;     // 拍內像素插值累加器餘數
  logic        beat_pending; // beat_p 先暫存，等 frame_tick 才更新畫面，避免一幀中途跳動/閃爍

  localparam logic [8:0] ROW_PX_9       = ROW_PX;
  localparam logic [7:0] ROW_PX_8       = ROW_PX;
  localparam logic [9:0] ROW_PX_10      = ROW_PX;
  localparam logic [7:0] FPB_DEFAULT_8  = FPB_DEFAULT;
  localparam logic [7:0] PRESS_FLASH_8  = PRESS_FLASH;
  localparam logic [7:0] VALID_SHOW_8   = VALID_SHOW;

  logic [11:0] last_row   [0:3];
  logic [ 7:0] press_tmr  [0:3];
  logic [ 7:0] valid_tmr  [0:3];
  logic [ 2:0] rating_rg  [0:3];
  logic        hold_active[0:3];

  // ---------------------------------------------------------------------------
  // 組合：由 beat_cnt + sub_px 算出 scroll_y（相當於下落位置）
  // scroll_y = beat_cnt * ROW_PX + sub_acc_px
  //
  // 為避免除法，改成：
  //   scroll_px  = beat_cnt * ROW_PX        (整拍)
  //   scroll_sub = sub_px * ROW_PX / fpb    (拍內小數)
  // 用累加器近似：scroll_sub ≈ (sub_px * ROW_PX) / fpb
  // 但最簡潔的方式：每 frame 把 sub_px 直接換算成像素偏移：
  //   delta_px = ROW_PX * sub_px / fpb
  // 這裡用 8-bit 精度的整數除法近似：
  //   delta_px = (sub_px * ROW_PX) >> log2(fpb_rounded_pow2)
  // → 改用「每 frame 加 ROW_PX 個 sub_unit，每 fpb sub_unit 進一個 px」的累加器。
  //
  // 實際實作：以兩個計數器分開：
  //   beat_cnt         → 整拍偏移
  //   sub_px (0..fpb-1)→ 進到 vga 的 sub-pixel 透過累加器 sub_acc 換算
  //
  // 渲染時用到的 scroll_y（組合）：
  //   scroll_y = beat_cnt * ROW_PX + sub_acc_px
  //
  // sub_acc_px 在 frame_tick 時用 sub_acc 累加器計算。
  // ---------------------------------------------------------------------------
  logic [7:0]  sub_acc_px; // 0 .. ROW_PX-1，由 sub_px / fpb * ROW_PX 近似

  // scroll_y 以 18-bit 表示：
  //   scroll_y[17:6] = 整拍 beat_cnt（ROW_PX=64=2^6）
  //   scroll_y[5:0]  = sub_acc_px[5:0]
  // 因為 ROW_PX=64=2^6，整拍偏移就是 beat_cnt << 6。
  logic [17:0] scroll_y;
  assign scroll_y = ({6'd0, beat_cnt} << 6) | {12'd0, sub_acc_px[5:0]};

  // ---------------------------------------------------------------------------
  // 渲染：把 vga 像素反推到哪一列
  //   note_center_y(r) = RECEPTOR_C + (beat_cnt - r) * ROW_PX + sub_acc_px
  //   給定 vga_y，要找 r 使得 |note_center_y(r) - vga_y| <= HALF_H
  //   等價於：scroll_y + RECEPTOR_C - vga_y 對 ROW_PX 取商/餘
  // ---------------------------------------------------------------------------
  logic [1:0] px_lane;
  logic       px_in_lane;
  always_comb begin
    px_in_lane = 1'b0; px_lane = 2'd0;
    if      (vga_x >= 10'd131 && vga_x <= 10'd224) begin px_lane=2'd0; px_in_lane=1'b1; end
    else if (vga_x >= 10'd226 && vga_x <= 10'd319) begin px_lane=2'd1; px_in_lane=1'b1; end
    else if (vga_x >= 10'd321 && vga_x <= 10'd414) begin px_lane=2'd2; px_in_lane=1'b1; end
    else if (vga_x >= 10'd416 && vga_x <= 10'd509) begin px_lane=2'd3; px_in_lane=1'b1; end
  end

  logic [17:0] num;
  logic [11:0] r_lo;
  logic [5:0]  res;        // 像素在 row r_lo 內的偏移
  logic        valid_num;
  logic [3:0]  m_lo, m_hi;

  always_comb begin
    note_on   = 1'b0;
    note_lane = px_lane;

    // num = scroll_y + RECEPTOR_C - vga_y
    valid_num = (scroll_y + RECEPTOR_C[17:0]) >= {8'd0, vga_y};
    num       = scroll_y + RECEPTOR_C[17:0] - {8'd0, vga_y};
    r_lo      = num[17:6];    // num / 64
    res       = num[5:0];     // num % 64

    m_lo = rom_at(r_lo);
    m_hi = rom_at(r_lo + 12'd1);

    if (px_in_lane && valid_num && (vga_y >= 10'd1) && (vga_y <= 10'd359)) begin
      // row r_lo 上半部 (res <= HALF_H)
      if (m_lo[px_lane] && (res <= HALF_H[5:0])) note_on = 1'b1;
      // row r_lo+1 下半部 (64-res < HALF_H)
      if (m_hi[px_lane] && ((6'd63 - res) < HALF_H[5:0])) note_on = 1'b1;
      // 連續 row：長按視覺補全
      if (m_lo[px_lane] && m_hi[px_lane]) note_on = 1'b1;
    end
  end

  // ---------------------------------------------------------------------------
  // 判定：以 beat_cnt 和 sub_acc_px 算出兩個候選 row 的中心 y
  //   row rbase 的中心：RECEPTOR_C + sub_acc_px（因為 rbase = beat_cnt）
  //   row rbase+1    ：RECEPTOR_C + sub_acc_px - ROW_PX（下一拍還沒到）
  //   row rbase-1    ：RECEPTOR_C + sub_acc_px + ROW_PX（上一拍已過）
  //
  // 判定兩個候選：rbase（目前拍）和 rbase+1（下一拍，快到判定線時同時進窗）。
  // ---------------------------------------------------------------------------
  logic [11:0] rbase;
  assign rbase = beat_cnt;

  // rbase 的音符中心 y（fixed formula）
  logic [9:0] c0, c1;
  assign c0 = RECEPTOR_C[9:0] + {2'd0, sub_acc_px};              // row rbase
  assign c1 = (RECEPTOR_C[9:0] + {2'd0, sub_acc_px}) - ROW_PX_10; // row rbase+1

  function automatic logic [2:0] rate_of(input logic [9:0] c);
    int d;
    begin
      if (c >= PERFECT_TOP[9:0] && c <= PERFECT_BOT[9:0]) rate_of = R_PERF;
      else begin
        d = (c < PERFECT_TOP[9:0]) ? (PERFECT_TOP - int'(c)) : (int'(c) - PERFECT_BOT);
        if      (d <= 4)  rate_of = R_GREAT;
        else if (d <= 8)  rate_of = R_GOOD;
        else if (d <= 12) rate_of = R_BAD;
        else if (d <= 16) rate_of = R_MISS;
        else              rate_of = R_NONE;
      end
    end
  endfunction

  function automatic logic [3:0] score_of(input logic [2:0] r);
    unique case (r)
      R_PERF:  score_of = 4'd10;
      R_GREAT: score_of = 4'd8;
      R_GOOD:  score_of = 4'd5;
      R_BAD:   score_of = 4'd2;
      default: score_of = 4'd0;
    endcase
  endfunction

  function automatic logic in_win(input logic [9:0] c);
    in_win = (c >= WIN_LO[9:0]) && (c <= WIN_HI[9:0]);
  endfunction

  // 長按輔助函式
  function automatic logic row_has_note(input logic [11:0] row, input int l);
    logic [3:0] m;
    begin m = rom_at(row); row_has_note = (row < cur_len) && m[l]; end
  endfunction

  function automatic logic row_is_hold_start(input logic [11:0] row, input int l);
    begin
      row_is_hold_start = row_has_note(row, l) &&
          !((row > 12'd0) && row_has_note(row-12'd1, l)) &&
          row_has_note(row+12'd1, l);
    end
  endfunction

  function automatic logic row_is_hold_body_or_end(input logic [11:0] row, input int l);
    begin
      row_is_hold_body_or_end = row_has_note(row, l) &&
          (row > 12'd0) && row_has_note(row-12'd1, l);
    end
  endfunction

  function automatic logic row_is_hold_end(input logic [11:0] row, input int l);
    begin
      row_is_hold_end = row_is_hold_body_or_end(row, l) && !row_has_note(row+12'd1, l);
    end
  endfunction

  logic [3:0] mask0, mask1;
  assign mask0 = rom_at(rbase);
  assign mask1 = rom_at(rbase + 12'd1);

  logic        j_hit  [0:3];
  logic [11:0] j_row  [0:3];
  logic [ 2:0] j_rate [0:3];
  logic [ 3:0] j_score[0:3];

  always_comb begin
    for (int l = 0; l < 4; l++) begin
      logic v0, v1;
      logic [2:0] rt0, rt1;
      // rbase 候選（目前拍）
      v0  = mask0[l] && (rbase       < cur_len) && (rbase       > last_row[l]) && in_win(c0);
      // rbase+1 候選（下一拍進窗）
      v1  = mask1[l] && (rbase+12'd1 < cur_len) && (rbase+12'd1 > last_row[l]) && in_win(c1);
      rt0 = rate_of(c0);
      rt1 = rate_of(c1);

      j_hit[l]=1'b0; j_row[l]=rbase; j_rate[l]=R_NONE; j_score[l]=4'd0;
      if (v0 && v1) begin
        if (rt0 <= rt1) begin j_hit[l]=1'b1; j_row[l]=rbase;       j_rate[l]=rt0; j_score[l]=score_of(rt0); end
        else            begin j_hit[l]=1'b1; j_row[l]=rbase+12'd1; j_rate[l]=rt1; j_score[l]=score_of(rt1); end
      end else if (v0) begin j_hit[l]=1'b1; j_row[l]=rbase;       j_rate[l]=rt0; j_score[l]=score_of(rt0);
      end else if (v1) begin j_hit[l]=1'b1; j_row[l]=rbase+12'd1; j_rate[l]=rt1; j_score[l]=score_of(rt1); end
    end
  end

  // ---------------------------------------------------------------------------
  // 自動 Miss：beat_cnt 已推進但玩家沒按 → row (beat_cnt - 1) 要結算
  // 判斷邏輯：每次 beat_p 時，把上一拍 (beat_cnt) 的音符列做結算。
  // ---------------------------------------------------------------------------
  // miss_row = beat_cnt（beat_p 前的值，即剛要過去的那一拍的 row）
  // 在 beat_p 發生時，beat_cnt 尚未更新，所以 beat_cnt 就是剛結束的 row。

  // ---------------------------------------------------------------------------
  // 時序
  // ---------------------------------------------------------------------------
  integer i;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n || play_rst) begin
      beat_cnt     <= '0;
      frame_cnt    <= '0;
      sub_acc      <= '0;
      sub_acc_px   <= '0;
      beat_pending <= 1'b0;
      fpb          <= FPB_DEFAULT_8;
      score        <= '0;
      song_finish  <= 1'b0;
      for (i=0;i<4;i++) begin
        last_row[i]    <= '0;
        press_tmr[i]   <= '0;
        valid_tmr[i]   <= '0;
        rating_rg[i]   <= R_NONE;
        hold_active[i] <= 1'b0;
      end
    end else if (play_en && !song_finish) begin
      // score_acc 用 blocking 累加，避免同一個 clock 多軌同時得分時只留下最後一筆。
      logic [11:0] score_acc;
      score_acc = score;

      // beat 可能發生在 VGA 掃描中的任意時間。
      // 先暫存，等 frame_tick 再更新 beat_cnt/sub_acc_px，避免畫面一幀中途改位置造成閃爍。
      if (beat_p)
        beat_pending <= 1'b1;

      // ---- 每 frame：更新畫面位置 / 處理 beat 邊界 / 計時器 ----
      if (frame_tick) begin
        logic        do_beat;
        logic [8:0]  a;
        logic [7:0]  px_next;

        do_beat = beat_pending || beat_p;

        // UI 計時器固定只在 frame_tick 遞減
        for (i=0;i<4;i++) begin
          if (press_tmr[i]!=0) press_tmr[i] <= press_tmr[i]-8'd1;
          if (valid_tmr[i]!=0) valid_tmr[i] <= valid_tmr[i]-8'd1;
        end

        if (do_beat) begin
          // 量測 fpb：只更新為合理值，避免異常短 beat 造成速度爆衝。
          if (frame_cnt >= 8'd4)
            fpb <= frame_cnt;

          // beat 邊界：整拍 +1，拍內像素歸零。
          // 由於只在 frame_tick 做，因此整個 VGA frame 的位置是穩定的。
          frame_cnt    <= '0;
          sub_acc      <= '0;
          sub_acc_px   <= '0;
          beat_pending <= 1'b0;

          // 結算剛過去的 row = beat_cnt（Miss 掃描）
          for (i=0;i<4;i++) begin
            if (row_has_note(beat_cnt, i) && !(last_row[i] >= beat_cnt)) begin
              if (row_is_hold_body_or_end(beat_cnt, i)) begin
                // 長按 body/end：按住得 GOOD，沒按住 MISS 並中斷
                if (hold_active[i] && key_hold[i]) begin
                  rating_rg[i] <= R_GOOD;
                  valid_tmr[i] <= VALID_SHOW_8;
                  score_acc    = score_acc + 12'd5;
                  if (row_is_hold_end(beat_cnt, i))
                    hold_active[i] <= 1'b0;
                end else begin
                  rating_rg[i]   <= R_MISS;
                  valid_tmr[i]   <= VALID_SHOW_8;
                  hold_active[i] <= 1'b0;
                end
              end else begin
                // 短 note miss
                rating_rg[i] <= R_MISS;
                valid_tmr[i] <= VALID_SHOW_8;
              end
              last_row[i] <= beat_cnt;
            end
          end

          beat_cnt <= beat_cnt + 12'd1;
          if ((beat_cnt + 12'd1) >= cur_len)
            song_finish <= 1'b1;

        end else begin
          // frame_cnt：只負責量測這一拍有幾個 frame，beat 邊界時拿來更新 fpb
          if (frame_cnt != 8'hFF)
            frame_cnt <= frame_cnt + 8'd1;

          // sub_acc/sub_acc_px：把一拍 ROW_PX 像素平均分配到 fpb 個 frame。
          // 注意：px_next 必須用 blocking temp 累加；不能在 for 裡多次寫 sub_acc_px <= sub_acc_px + 1，
          // 否則 nonblocking 只會保留最後一次「原值+1」，每 frame 最多只動 1px，beat 邊界就會用跳的。
          a       = sub_acc + ROW_PX_9;
          px_next = sub_acc_px;

          for (int k = 0; k < 16; k++) begin
            if (a >= {1'b0, fpb}) begin
              a = a - {1'b0, fpb};
              if (px_next < (ROW_PX_8 - 8'd1))
                px_next = px_next + 8'd1;
            end
          end

          sub_acc    <= a;
          sub_acc_px <= px_next;

          if (beat_cnt >= cur_len)
            song_finish <= 1'b1;
        end
      end

      // ---- 按鍵判定（每 clk 都看）----
      for (i=0;i<4;i++) begin
        if (p_key[i]) begin
          press_tmr[i] <= PRESS_FLASH_8;
          if (j_hit[i]) begin
            last_row[i]  <= j_row[i];
            rating_rg[i] <= j_rate[i];
            valid_tmr[i] <= VALID_SHOW_8;
            score_acc    = score_acc + {8'd0, j_score[i]};
            if (row_is_hold_start(j_row[i], i))
              hold_active[i] <= 1'b1;
            else if (!row_is_hold_body_or_end(j_row[i], i))
              hold_active[i] <= 1'b0;
          end
        end
      end

      score <= score_acc;
    end
  end

  // ---------------------------------------------------------------------------
  // 輸出
  // ---------------------------------------------------------------------------
  always_comb begin
    for (int l = 0; l < 4; l++) begin
      // key_hold 讓 DFJK 長按時 receptor 立即保持按下狀態；
      // press_tmr 保留 p_key 的短暫 flash。
      lane_pressed[l]       = key_hold[l] || (press_tmr[l] != 0);
      lane_show_text[l]     = (valid_tmr[l] != 0);
      lane_show_valid[l]    = (valid_tmr[l] != 0) && (rating_rg[l]!=R_MISS) && (rating_rg[l]!=R_NONE);
      lane_rating[l*3 +: 3] = rating_rg[l];
    end
  end

endmodule

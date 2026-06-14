// =============================================================================
// play_track.sv  (beat 驅動版)
// =============================================================================
module play_track #(
    parameter int ROW_PX      = 64,    // 每拍前進像素(=音符列距)，2 的次方
    parameter int NOTE_H      = 28,
    parameter int FPB_DEFAULT = 30,    // 首拍前的預設 frames/beat
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

  localparam logic [2:0] R_NONE = 3'd0;
  localparam logic [2:0] R_PERF = 3'd1;
  localparam logic [2:0] R_GREAT = 3'd2;
  localparam logic [2:0] R_GOOD = 3'd3;
  localparam logic [2:0] R_BAD = 3'd4;
  localparam logic [2:0] R_MISS = 3'd5;

  localparam int HALF_H = NOTE_H / 2;
  localparam int WIN_LO = PERFECT_TOP - 16;
  localparam int WIN_HI = PERFECT_BOT + 16;

  localparam int NMAX = 2200;
  logic [3:0] rom_mario  [0:NMAX-1];
  logic [3:0] rom_zelda  [0:NMAX-1];
  logic [3:0] rom_pokemon[0:NMAX-1];

  initial begin
    $readmemh("mario_key_track.mem", rom_mario);
    $readmemh("zelda_key_track.mem", rom_zelda);
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
    if (row >= cur_len) begin
      rom_at = 4'b0000;
    end else begin
      unique case (sel_song)
        3'b001:  rom_at = rom_mario[row];
        3'b010:  rom_at = rom_zelda[row];
        3'b100:  rom_at = rom_pokemon[row];
        default: rom_at = 4'b0000;
      endcase
    end
  endfunction

  // beat 同步 + 邊緣偵測
  logic beat_m, beat_s, beat_s2, beat_p;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      beat_m  <= 1'b0;
      beat_s  <= 1'b0;
      beat_s2 <= 1'b0;
    end else begin
      beat_m  <= beat;
      beat_s  <= beat_m;
      beat_s2 <= beat_s;
    end
  end
  assign beat_p = beat_s & ~beat_s2;

  logic [17:0] scroll_y;
  logic [11:0] beat_cnt;
  logic [ 9:0] acc;
  logic [ 7:0] fpb;
  logic [ 7:0] fcnt;
  logic [11:0] last_row   [0:3];
  logic [ 7:0] press_tmr  [0:3];
  logic [ 7:0] valid_tmr  [0:3];
  logic [ 2:0] rating_rg  [0:3];

  // 渲染
  logic [ 1:0] px_lane;
  logic        px_in_lane;
  always_comb begin
    px_in_lane = 1'b0;
    px_lane = 2'd0;
    if (vga_x >= 10'd131 && vga_x <= 10'd224) begin
      px_lane = 2'd0;
      px_in_lane = 1'b1;
    end else if (vga_x >= 10'd226 && vga_x <= 10'd319) begin
      px_lane = 2'd1;
      px_in_lane = 1'b1;
    end else if (vga_x >= 10'd321 && vga_x <= 10'd414) begin
      px_lane = 2'd2;
      px_in_lane = 1'b1;
    end else if (vga_x >= 10'd416 && vga_x <= 10'd509) begin
      px_lane = 2'd3;
      px_in_lane = 1'b1;
    end
  end

  logic [17:0] num;
  logic [11:0] r_lo;
  logic [ 5:0] res;
  logic        valid_num;
  logic [3:0] m_lo, m_hi;
  always_comb begin
    note_on   = 1'b0;
    note_lane = px_lane;
    valid_num = ({1'b0, scroll_y} + 19'd326) >= {9'd0, vga_y};
    num       = scroll_y + 18'd326 - {8'd0, vga_y};
    r_lo      = num[17:6];
    res       = num[5:0];
    m_lo      = rom_at(r_lo);
    m_hi      = rom_at(r_lo + 12'd1);
    if (px_in_lane && valid_num && (vga_y >= 10'd1) && (vga_y <= 10'd359)) begin
      if (m_lo[px_lane] && (res <= HALF_H[5:0])) note_on = 1'b1;

      if (m_hi[px_lane] && ((6'd63 - res) < HALF_H[5:0])) note_on = 1'b1;

      // Long Key
      if (m_lo[px_lane] && m_hi[px_lane]) note_on = 1'b1;
    end
  end

  // 判定
  logic [11:0] rbase;
  logic [ 5:0] off;
  assign rbase = scroll_y[17:6];
  assign off   = scroll_y[5:0];
  logic [9:0] c0, c1;
  assign c0 = 10'd326 + {4'd0, off};
  assign c1 = 10'd262 + {4'd0, off};

  function automatic logic [2:0] rate_of(input logic [9:0] c);
    int d;
    begin
      if (c >= PERFECT_TOP[9:0] && c <= PERFECT_BOT[9:0]) rate_of = R_PERF;
      else begin
        d = (c < PERFECT_TOP[9:0]) ? (PERFECT_TOP - int'(c)) : (int'(c) - PERFECT_BOT);
        if (d <= 4) rate_of = R_GREAT;
        else if (d <= 8) rate_of = R_GOOD;
        else if (d <= 12) rate_of = R_BAD;
        else if (d <= 16) rate_of = R_MISS;
        else rate_of = R_NONE;
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

  logic        j_hit  [0:3];
  logic [11:0] j_row  [0:3];
  logic [ 2:0] j_rate [0:3];
  logic [ 3:0] j_score[0:3];
  logic [3:0] mask0, mask1;
  assign mask0 = rom_at(rbase);
  assign mask1 = rom_at(rbase + 12'd1);

  always_comb begin
    for (int l = 0; l < 4; l++) begin
      logic v0, v1;
      logic [2:0] rt0, rt1;
      v0 = mask0[l] && (rbase < cur_len) && (rbase > last_row[l]) && in_win(c0);
      v1 = mask1[l] && (rbase + 12'd1 < cur_len) && (rbase + 12'd1 > last_row[l]) && in_win(c1);
      rt0 = rate_of(c0);
      rt1 = rate_of(c1);
      j_hit[l] = 1'b0;
      j_row[l] = rbase;
      j_rate[l] = R_NONE;
      j_score[l] = 4'd0;
      if (v0 && v1) begin
        if (rt0 <= rt1) begin
          j_hit[l]   = 1'b1;
          j_row[l]   = rbase;
          j_rate[l]  = rt0;
          j_score[l] = score_of(rt0);
        end else begin
          j_hit[l]   = 1'b1;
          j_row[l]   = rbase + 12'd1;
          j_rate[l]  = rt1;
          j_score[l] = score_of(rt1);
        end
      end else if (v0) begin
        j_hit[l]   = 1'b1;
        j_row[l]   = rbase;
        j_rate[l]  = rt0;
        j_score[l] = score_of(rt0);
      end else if (v1) begin
        j_hit[l]   = 1'b1;
        j_row[l]   = rbase + 12'd1;
        j_rate[l]  = rt1;
        j_score[l] = score_of(rt1);
      end
    end
  end

  logic [17:0] miss_thr[0:3];
  logic [11:0] next_row[0:3];
  always_comb begin
    for (int l = 0; l < 4; l++) begin
      next_row[l] = last_row[l] + 12'd1;
      miss_thr[l] = {next_row[l], 6'd0} + 18'd31;
    end
  end

  integer i;
  logic [3:0] nm_miss;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n || play_rst) begin
      scroll_y <= '0;
      beat_cnt <= '0;
      acc <= '0;
      fpb <= FPB_DEFAULT[7:0];
      fcnt <= '0;
      score <= '0;
      song_finish <= 1'b0;
      for (i = 0; i < 4; i++) begin
        last_row[i]  <= '0;
        press_tmr[i] <= '0;
        valid_tmr[i] <= '0;
        rating_rg[i] <= R_NONE;
      end
    end else begin
      if (play_en && !song_finish) begin
        // 每 frame：平滑插值 + 計時
        if (frame_tick) begin
          begin
            logic [9:0] a;
            logic [17:0] s;
            int k;
            a = acc + ROW_PX[9:0];
            s = scroll_y;
            for (k = 0; k < 8; k++) begin
              if (a >= {2'd0, fpb}) begin
                a = a - {2'd0, fpb};
                s = s + 18'd1;
              end
            end
            acc <= a;
            scroll_y <= s;
          end
          if (fcnt != 8'hFF) fcnt <= fcnt + 8'd1;
          for (i = 0; i < 4; i++) begin
            if (press_tmr[i] != 0) press_tmr[i] <= press_tmr[i] - 8'd1;
            if (valid_tmr[i] != 0) valid_tmr[i] <= valid_tmr[i] - 8'd1;
            if ((next_row[i] < cur_len) && (scroll_y >= miss_thr[i])) begin
              nm_miss = rom_at(next_row[i]);
              if (nm_miss[i]) begin
                rating_rg[i] <= R_MISS;
                valid_tmr[i] <= VALID_SHOW[7:0];
              end
              last_row[i] <= next_row[i];
            end
          end
          if (scroll_y >= {cur_len, 6'd0}) song_finish <= 1'b1;
        end
        // 每 beat：對齊 + 量測 fpb（蓋過插值）
        if (beat_p) begin
          beat_cnt <= beat_cnt + 12'd1;
          scroll_y <= {(beat_cnt + 12'd1), 6'd0};
          acc      <= '0;
          if (fcnt >= 8'd4 && fcnt != 8'hFF) fpb <= fcnt;
          fcnt <= '0;
        end
        // 按鍵判定（覆寫）
        for (i = 0; i < 4; i++) begin
          if (p_key[i]) begin
            press_tmr[i] <= PRESS_FLASH[7:0];
            if (j_hit[i]) begin
              last_row[i]  <= j_row[i];
              rating_rg[i] <= j_rate[i];
              valid_tmr[i] <= VALID_SHOW[7:0];
              score        <= score + {8'd0, j_score[i]};
            end
          end
        end
      end
    end
  end

  always_comb begin
    for (int l = 0; l < 4; l++) begin
      lane_pressed[l] = (press_tmr[l] != 0);
      lane_show_text[l] = (valid_tmr[l] != 0);
      lane_show_valid[l]    = (valid_tmr[l] != 0) && (rating_rg[l] != R_MISS) && (rating_rg[l] != R_NONE);
      lane_rating[l*3+:3] = rating_rg[l];
    end
  end

endmodule

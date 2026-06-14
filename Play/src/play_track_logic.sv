module play_track_logic #(
    parameter int ROW_PX      = 64,
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
    input logic       clk,
    input logic       rst_n,
    input logic       frame_tick,
    input logic       beat,
    input logic       play_en,
    input logic       play_rst,
    input logic [2:0] sel_song,
    input logic [3:0] p_key,
    input logic [3:0] key_hold,

    output logic [11:0] beat_cnt,
    output logic [ 7:0] sub_acc_px,
    output logic [ 3:0] lane_pressed,
    output logic [ 3:0] lane_show_valid,
    output logic [ 3:0] lane_show_text,
    output logic [11:0] lane_rating,
    output logic [15:0] score,
    output logic        song_finish
);

  localparam logic [2:0] R_NONE = 3'd0, R_PERF = 3'd1, R_GREAT = 3'd2, R_GOOD = 3'd3, R_BAD = 3'd4, R_MISS = 3'd5;
  localparam int WIN_LO = PERFECT_TOP - 16;
  localparam int WIN_HI = PERFECT_BOT + 16;

  localparam logic [9:0] ROW_PX_10 = ROW_PX;
  localparam logic [8:0] ROW_PX_9 = ROW_PX;
  localparam logic [7:0] ROW_PX_8 = ROW_PX;

  localparam int NMAX = 2200;
  localparam logic [16:0] SCORE_MAX = 17'd9999;
  logic [3:0] rom_mario[0:NMAX-1], rom_zelda[0:NMAX-1], rom_pokemon[0:NMAX-1];
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

  logic beat_p;
  assign beat_p = play_en && beat;

  // 狀態寄存器
  logic [7:0] frame_cnt, fpb;
  logic [8:0] sub_acc;
  logic beat_pending;
  logic [11:0] last_row[0:3];
  logic [7:0] press_tmr[0:3], valid_tmr[0:3];
  logic [2:0] rating_rg[0:3];
  logic hold_active[0:3];

  logic [9:0] c0, c1;
  assign c0 = RECEPTOR_C[9:0] + {2'd0, sub_acc_px};
  assign c1 = (RECEPTOR_C[9:0] + {2'd0, sub_acc_px}) - ROW_PX_10;

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

  function automatic logic row_has_note(input logic [11:0] row, input logic [1:0] l);
    logic [3:0] m;
    begin
      m = rom_at(row);
      row_has_note = (row < cur_len) && m[l];
    end
  endfunction

  logic [3:0] mask0, mask1;
  assign mask0 = rom_at(beat_cnt);
  assign mask1 = rom_at(beat_cnt + 12'd1);

  logic j_hit[0:3];
  logic [11:0] j_row[0:3];
  logic [2:0] j_rate[0:3];
  logic [3:0] j_score[0:3];

  always_comb begin
    for (int l = 0; l < 4; l++) begin
      logic v0, v1;
      logic [2:0] rt0, rt1;
      v0  = mask0[l] && (beat_cnt < cur_len) && (last_row[l] == 12'hFFF || beat_cnt > last_row[l]) && in_win(
          c0);
      v1  = mask1[l] && (beat_cnt+12'd1 < cur_len) && (last_row[l] == 12'hFFF || beat_cnt+12'd1 > last_row[l]) && in_win(
          c1);
      rt0 = rate_of(c0);
      rt1 = rate_of(c1);

      j_hit[l] = 0;
      j_row[l] = beat_cnt;
      j_rate[l] = R_NONE;
      j_score[l] = 0;
      if (v0 && v1) begin
        if (rt0 <= rt1) begin
          j_hit[l]   = 1;
          j_row[l]   = beat_cnt;
          j_rate[l]  = rt0;
          j_score[l] = score_of(rt0);
        end else begin
          j_hit[l]   = 1;
          j_row[l]   = beat_cnt + 1;
          j_rate[l]  = rt1;
          j_score[l] = score_of(rt1);
        end
      end else if (v0) begin
        j_hit[l]   = 1;
        j_row[l]   = beat_cnt;
        j_rate[l]  = rt0;
        j_score[l] = score_of(rt0);
      end else if (v1) begin
        j_hit[l]   = 1;
        j_row[l]   = beat_cnt + 1;
        j_rate[l]  = rt1;
        j_score[l] = score_of(rt1);
      end
    end
  end

  // ===========================================================================
  // 核心主邏輯：完全分離 rst_n 與 play_rst，確保合成器生成乾淨的 Reset 電路
  // ===========================================================================
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // 硬體全域重置
      beat_cnt <= '0;
      frame_cnt <= '0;
      sub_acc <= '0;
      sub_acc_px <= '0;
      beat_pending <= 0;
      fpb <= FPB_DEFAULT[7:0];
      score <= '0;
      song_finish <= 0;
      for (int i = 0; i < 4; i++) begin
        last_row[i] <= 12'hFFF;
        press_tmr[i] <= '0;
        valid_tmr[i] <= '0;
        rating_rg[i] <= R_NONE;
        hold_active[i] <= 0;
      end
    end else if (play_rst) begin
      // 新遊戲重置 (軟體重置)
      beat_cnt <= '0;
      frame_cnt <= '0;
      sub_acc <= '0;
      sub_acc_px <= '0;
      beat_pending <= 0;
      fpb <= FPB_DEFAULT[7:0];
      score <= '0;
      song_finish <= 0;
      for (int i = 0; i < 4; i++) begin
        last_row[i] <= 12'hFFF;
        press_tmr[i] <= '0;
        valid_tmr[i] <= '0;
        rating_rg[i] <= R_NONE;
        hold_active[i] <= 0;
      end
    end else if (play_en && !song_finish) begin
      logic [16:0] next_score;
      next_score = {1'b0, score};

      if (beat_p) beat_pending <= 1'b1;

      for (int i = 0; i < 4; i++) begin
        if (p_key[i]) begin
          press_tmr[i] <= PRESS_FLASH[7:0];
          if (j_hit[i]) begin
            last_row[i]  <= j_row[i];
            rating_rg[i] <= j_rate[i];
            valid_tmr[i] <= VALID_SHOW[7:0];
            next_score += {13'd0, j_score[i]};
            if (row_has_note(
                    j_row[i], i[1:0]
                ) && row_has_note(
                    j_row[i] + 1, i[1:0]
                ) && !(j_row[i] > 0 && row_has_note(
                    j_row[i] - 1, i[1:0]
                )))
              hold_active[i] <= 1;
            else if (!(row_has_note(
                    j_row[i], i[1:0]
                ) && j_row[i] > 0 && row_has_note(
                    j_row[i] - 1, i[1:0]
                )))
              hold_active[i] <= 0;
          end
        end
      end

      if (frame_tick) begin
        logic do_beat;
        do_beat = beat_pending || beat_p;

        for (int i = 0; i < 4; i++) begin
          if (press_tmr[i] != 0 && !p_key[i]) press_tmr[i] <= press_tmr[i] - 1;
          if (valid_tmr[i] != 0 && !p_key[i]) valid_tmr[i] <= valid_tmr[i] - 1;
        end

        // 長按加分邏輯
        if (do_beat) begin
          for (int i = 0; i < 4; i++) begin
            if (hold_active[i] && key_hold[i] && (beat_cnt > 0 && row_has_note(
                    beat_cnt - 1, i[1:0]
                ))) begin
              rating_rg[i] <= R_GOOD;
              valid_tmr[i] <= VALID_SHOW[7:0];
              next_score += 17'd5;
            end else if (hold_active[i] && !key_hold[i]) begin
              hold_active[i] <= 0;
            end
          end
        end

        // 獨立且精確的 Miss 掃描：只有當音符真正「掉出」Late Hit 判定區外，才標記為 Miss
        for (int i = 0; i < 4; i++) begin
          if (row_has_note(
                  beat_cnt, i[1:0]
              ) && (last_row[i] == 12'hFFF || beat_cnt > last_row[i])) begin
            if (c0 > WIN_HI[9:0]) begin  // c0 大於判定下緣 (代表來不及按了)
              rating_rg[i]   <= R_MISS;
              valid_tmr[i]   <= VALID_SHOW[7:0];
              hold_active[i] <= 0;
              last_row[i]    <= beat_cnt;
            end
          end
        end

        // 拍子與像素推進
        if (do_beat) begin
          if (frame_cnt >= 8'd4) fpb <= frame_cnt;
          frame_cnt <= '0;
          sub_acc <= '0;
          sub_acc_px <= '0;
          beat_pending <= 0;
          beat_cnt <= beat_cnt + 1;
          if (beat_cnt + 1 >= cur_len) song_finish <= 1;
        end else begin
          logic [8:0] temp_a;
          logic [7:0] temp_px;
          if (frame_cnt != 8'hFF) frame_cnt <= frame_cnt + 1;

          temp_a  = sub_acc + ROW_PX_9;
          temp_px = sub_acc_px;
          if (temp_a >= {1'b0, fpb} * 16) begin
            temp_a -= {1'b0, fpb} * 16;
            temp_px += 16;
          end
          if (temp_a >= {1'b0, fpb} * 8) begin
            temp_a -= {1'b0, fpb} * 8;
            temp_px += 8;
          end
          if (temp_a >= {1'b0, fpb} * 4) begin
            temp_a -= {1'b0, fpb} * 4;
            temp_px += 4;
          end
          if (temp_a >= {1'b0, fpb} * 2) begin
            temp_a -= {1'b0, fpb} * 2;
            temp_px += 2;
          end
          if (temp_a >= {1'b0, fpb}) begin
            temp_a -= {1'b0, fpb};
            temp_px += 1;
          end

          if (temp_px > ROW_PX_8 - 1) temp_px = ROW_PX_8 - 1;
          sub_acc <= temp_a;
          sub_acc_px <= temp_px;

          if (beat_cnt >= cur_len) song_finish <= 1;
        end
      end

      // 分數安全寫入（防溢位）
      if (next_score > SCORE_MAX) score <= SCORE_MAX[15:0];
      else score <= next_score[15:0];
    end
  end

  always_comb begin
    for (int l = 0; l < 4; l++) begin
      lane_pressed[l] = key_hold[l] || (press_tmr[l] != 0);
      lane_show_text[l] = (valid_tmr[l] != 0);
      lane_show_valid[l] = (valid_tmr[l] != 0) && (rating_rg[l]!=R_MISS) && (rating_rg[l]!=R_NONE);
      lane_rating[l*3+:3] = rating_rg[l];
    end
  end
endmodule

// =============================================================================
// play_track.sv  (BRAM-friendly cache + fixed-point scroll version)
// -----------------------------------------------------------------------------
// Fixes applied:
//   1. Score expanded to 16-bit.
//   2. Score is accumulated once per clock with score_next.
//   3. Original 2200-depth track ROM is no longer read from pixel combinational
//      logic.  A small cache around beat_cnt is loaded sequentially; rendering
//      and judgment only read this small cache combinationally.
//   4. Dropping motion uses a Q8 fixed-point accumulator.  No 16-stage
//      compare/subtract loop is used in the frame path.
//   5. ROW spacing is intentionally fixed to a power-of-two: ROW_PX = 2^ROW_SHIFT.
//      Default ROW_SHIFT=5 => 32 px per beat, visually smoother than 64 px.
// =============================================================================
module play_track #(
    parameter int ROW_SHIFT   = 5,   // ROW_PX = 2^ROW_SHIFT. 5 => 32 px/beat.
    parameter int NOTE_H      = 28,
    parameter int FPB_DEFAULT = 8,
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
    output logic [15:0] score,
    output logic        song_finish
);

  // ---- Rating code ----
  localparam logic [2:0] R_NONE  = 3'd0;
  localparam logic [2:0] R_PERF  = 3'd1;
  localparam logic [2:0] R_GREAT = 3'd2;
  localparam logic [2:0] R_GOOD  = 3'd3;
  localparam logic [2:0] R_BAD   = 3'd4;
  localparam logic [2:0] R_MISS  = 3'd5;

  localparam int ROW_PX  = (1 << ROW_SHIFT);
  localparam int CACHE_N = 16;
  localparam int HALF_H  = NOTE_H / 2;
  localparam int WIN_LO = PERFECT_TOP - 16;
  localparam int WIN_HI = PERFECT_BOT + 16;

  localparam logic [11:0] LEN_MARIO_12   = LEN_MARIO;
  localparam logic [11:0] LEN_ZELDA_12   = LEN_ZELDA;
  localparam logic [11:0] LEN_POKEMON_12 = LEN_POKEMON;
  localparam logic [7:0]  PRESS_FLASH_8  = PRESS_FLASH;
  localparam logic [7:0]  VALID_SHOW_8   = VALID_SHOW;
  localparam logic [7:0]  FPB_DEFAULT_8  = FPB_DEFAULT;
  localparam logic [7:0]  HALF_H_8       = HALF_H;
  localparam logic [7:0]  ROW_PX_8       = ROW_PX;
  localparam logic [9:0]  ROW_PX_10      = ROW_PX;
  localparam logic [9:0]  RECEPTOR_C_10  = RECEPTOR_C;
  localparam logic [17:0] RECEPTOR_C_18  = RECEPTOR_C;
  localparam logic [9:0]  PERFECT_TOP_10 = PERFECT_TOP;
  localparam logic [9:0]  PERFECT_BOT_10 = PERFECT_BOT;
  localparam logic [9:0]  WIN_LO_10      = WIN_LO;
  localparam logic [9:0]  WIN_HI_10      = WIN_HI;
  localparam logic [11:0] CACHE_N_12     = CACHE_N;
  localparam logic [15:0] ROW_Q8         = (ROW_PX << 8);

  // ---------------------------------------------------------------------------
  // Track ROMs.  These arrays are read only from clocked cache-loader logic.
  // This is much friendlier to BRAM inference than using them in always_comb.
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
      3'b001:  cur_len = LEN_MARIO_12;
      3'b010:  cur_len = LEN_ZELDA_12;
      3'b100:  cur_len = LEN_POKEMON_12;
      default: cur_len = LEN_MARIO_12;
    endcase
  end

  // ---------------------------------------------------------------------------
  // Small visible/judgment cache.
  //   cache_base = beat_cnt - 1, so the cache covers:
  //   beat_cnt-1, beat_cnt, beat_cnt+1, ... beat_cnt+14.
  // This covers rendering from top to receptor and hold checks row-1/row/row+1.
  // ---------------------------------------------------------------------------
  logic [3:0]  cache_mem [0:CACHE_N-1];
  logic [11:0] cache_base;
  logic [11:0] cache_base_target;
  logic [4:0]  cache_load_idx;
  logic        cache_valid;
  logic        cache_loading;

  function automatic logic [3:0] cache_at(input logic [11:0] row);
    logic [11:0] idx;
    begin
      cache_at = 4'b0000;
      if (cache_valid && row >= cache_base && row < (cache_base + CACHE_N_12)) begin
        idx = row - cache_base;
        cache_at = cache_mem[idx[3:0]];
      end
    end
  endfunction

  function automatic logic [11:0] target_base_for(input logic [11:0] bcnt);
    begin
      target_base_for = (bcnt == 12'd0) ? 12'd0 : (bcnt - 12'd1);
    end
  endfunction

  // ---------------------------------------------------------------------------
  // Beat sync and edge detect
  // ---------------------------------------------------------------------------
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

  // ---------------------------------------------------------------------------
  // Scroll and game-state registers
  // ---------------------------------------------------------------------------
  logic [11:0] beat_cnt;
  logic        beat_pending;
  logic [7:0]  frame_cnt;
  logic [7:0]  fpb;
  logic [15:0] sub_q8;
  logic [15:0] step_q8;

  logic [11:0] last_row       [0:3];
  logic        last_row_valid [0:3];
  logic [7:0]  press_tmr      [0:3];
  logic [7:0]  valid_tmr      [0:3];
  logic [2:0]  rating_rg      [0:3];
  logic        hold_active    [0:3];

  function automatic logic [15:0] calc_step_q8(input logic [7:0] frames_per_beat);
    logic [7:0] f;
    begin
      f = (frames_per_beat < 8'd1) ? FPB_DEFAULT_8 : frames_per_beat;
      calc_step_q8 = ROW_Q8 / f;
    end
  endfunction

  // beat_cnt * ROW_PX + sub_px.  ROW_PX is power-of-two by construction.
  logic [7:0]  sub_px;
  logic [17:0] scroll_y;
  assign sub_px   = sub_q8[15:8];
  assign scroll_y = ({6'd0, beat_cnt} << ROW_SHIFT) + {10'd0, sub_px};

  // ---------------------------------------------------------------------------
  // Rendering: derive track row from current pixel.
  // ---------------------------------------------------------------------------
  logic [1:0] px_lane;
  logic       px_in_lane;
  always_comb begin
    px_in_lane = 1'b0;
    px_lane    = 2'd0;
    if      (vga_x >= 10'd131 && vga_x <= 10'd224) begin px_lane = 2'd0; px_in_lane = 1'b1; end
    else if (vga_x >= 10'd226 && vga_x <= 10'd319) begin px_lane = 2'd1; px_in_lane = 1'b1; end
    else if (vga_x >= 10'd321 && vga_x <= 10'd414) begin px_lane = 2'd2; px_in_lane = 1'b1; end
    else if (vga_x >= 10'd416 && vga_x <= 10'd509) begin px_lane = 2'd3; px_in_lane = 1'b1; end
  end

  logic [17:0] num;
  logic [11:0] r_lo;
  logic [7:0]  res;
  logic        valid_num;
  logic [3:0]  m_lo, m_hi;

  always_comb begin
    note_on   = 1'b0;
    note_lane = px_lane;

    valid_num = (scroll_y + RECEPTOR_C_18) >= {8'd0, vga_y};
    num       = scroll_y + RECEPTOR_C_18 - {8'd0, vga_y};
    r_lo      = num[17:ROW_SHIFT];
    res       = {2'b00, num[ROW_SHIFT-1:0]};

    m_lo = cache_at(r_lo);
    m_hi = cache_at(r_lo + 12'd1);

    if (px_in_lane && valid_num && (vga_y >= 10'd1) && (vga_y <= 10'd359)) begin
      if (m_lo[px_lane] && (res <= HALF_H_8)) note_on = 1'b1;
      if (m_hi[px_lane] && (((ROW_PX_8 - 8'd1) - res) < HALF_H_8)) note_on = 1'b1;
      if (m_lo[px_lane] && m_hi[px_lane]) note_on = 1'b1;  // visual hold body
    end
  end

  // ---------------------------------------------------------------------------
  // Judgment helpers
  // ---------------------------------------------------------------------------
  logic [11:0] rbase;
  logic [9:0]  c0, c1;
  logic [3:0]  mask0, mask1;

  assign rbase = beat_cnt;
  assign c0    = RECEPTOR_C_10 + {2'd0, sub_px};
  assign c1    = (RECEPTOR_C_10 + {2'd0, sub_px}) - ROW_PX_10;
  assign mask0 = cache_at(rbase);
  assign mask1 = cache_at(rbase + 12'd1);

  function automatic logic row_unjudged(input logic [11:0] row, input int l);
    row_unjudged = !last_row_valid[l] || (row > last_row[l]);
  endfunction

  function automatic logic [2:0] rate_of(input logic [9:0] c);
    int d;
    begin
      if (c >= PERFECT_TOP_10 && c <= PERFECT_BOT_10) rate_of = R_PERF;
      else begin
        d = (c < PERFECT_TOP_10) ? (PERFECT_TOP - int'(c)) : (int'(c) - PERFECT_BOT);
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
    in_win = (c >= WIN_LO_10) && (c <= WIN_HI_10);
  endfunction

  function automatic logic row_has_note(input logic [11:0] row, input int l);
    logic [3:0] m;
    begin
      m = cache_at(row);
      row_has_note = (row < cur_len) && m[l];
    end
  endfunction

  function automatic logic row_is_hold_start(input logic [11:0] row, input int l);
    row_is_hold_start = row_has_note(row, l) &&
                        !((row > 12'd0) && row_has_note(row - 12'd1, l)) &&
                        row_has_note(row + 12'd1, l);
  endfunction

  function automatic logic row_is_hold_body_or_end(input logic [11:0] row, input int l);
    row_is_hold_body_or_end = row_has_note(row, l) &&
                              (row > 12'd0) && row_has_note(row - 12'd1, l);
  endfunction

  function automatic logic row_is_hold_end(input logic [11:0] row, input int l);
    row_is_hold_end = row_is_hold_body_or_end(row, l) && !row_has_note(row + 12'd1, l);
  endfunction

  logic        j_hit  [0:3];
  logic [11:0] j_row  [0:3];
  logic [2:0]  j_rate [0:3];
  logic [3:0]  j_score[0:3];

  always_comb begin
    for (int l = 0; l < 4; l++) begin
      logic v0, v1;
      logic [2:0] rt0, rt1;

      v0  = cache_valid && mask0[l] && (rbase < cur_len) && row_unjudged(rbase, l) && in_win(c0);
      v1  = cache_valid && mask1[l] && (rbase + 12'd1 < cur_len) && row_unjudged(rbase + 12'd1, l) && in_win(c1);
      rt0 = rate_of(c0);
      rt1 = rate_of(c1);

      j_hit[l]   = 1'b0;
      j_row[l]   = rbase;
      j_rate[l]  = R_NONE;
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

  // ---------------------------------------------------------------------------
  // Sequential logic
  // ---------------------------------------------------------------------------
  integer i;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n || play_rst) begin
      beat_cnt     <= 12'd0;
      beat_pending <= 1'b0;
      frame_cnt    <= 8'd0;
      fpb          <= FPB_DEFAULT_8;
      sub_q8       <= 16'd0;
      step_q8      <= calc_step_q8(FPB_DEFAULT_8);
      score        <= 16'd0;
      song_finish  <= 1'b0;

      cache_base        <= 12'd0;
      cache_base_target <= 12'd0;
      cache_load_idx    <= 5'd0;
      cache_valid       <= 1'b0;
      cache_loading     <= 1'b1;

      for (i = 0; i < 4; i++) begin
        last_row[i]       <= 12'd0;
        last_row_valid[i] <= 1'b0;
        press_tmr[i]      <= 8'd0;
        valid_tmr[i]      <= 8'd0;
        rating_rg[i]      <= R_NONE;
        hold_active[i]    <= 1'b0;
      end
    end else begin
      // ---- sequential cache loader ----
      if (cache_loading) begin
        unique case (sel_song)
          3'b001:  cache_mem[cache_load_idx[3:0]] <= (cache_base_target + {7'd0, cache_load_idx} < LEN_MARIO_12)   ? rom_mario  [cache_base_target + {7'd0, cache_load_idx}] : 4'b0000;
          3'b010:  cache_mem[cache_load_idx[3:0]] <= (cache_base_target + {7'd0, cache_load_idx} < LEN_ZELDA_12)   ? rom_zelda  [cache_base_target + {7'd0, cache_load_idx}] : 4'b0000;
          3'b100:  cache_mem[cache_load_idx[3:0]] <= (cache_base_target + {7'd0, cache_load_idx} < LEN_POKEMON_12) ? rom_pokemon[cache_base_target + {7'd0, cache_load_idx}] : 4'b0000;
          default: cache_mem[cache_load_idx[3:0]] <= 4'b0000;
        endcase

        if (cache_load_idx == CACHE_N - 1) begin
          cache_loading <= 1'b0;
          cache_valid   <= 1'b1;
          cache_base    <= cache_base_target;
        end else begin
          cache_load_idx <= cache_load_idx + 5'd1;
        end
      end

      if (play_en && !song_finish) begin
        logic [15:0] score_next;
        logic [15:0] sub_next;
        logic [11:0] next_beat;
        logic        do_beat;

        score_next = score;
        do_beat    = frame_tick && (beat_pending || beat_p);

        if (beat_p && !do_beat) begin
          beat_pending <= 1'b1;
        end

        if (frame_tick) begin
          // UI timers
          for (i = 0; i < 4; i++) begin
            if (press_tmr[i] != 8'd0) press_tmr[i] <= press_tmr[i] - 8'd1;
            if (valid_tmr[i] != 8'd0) valid_tmr[i] <= valid_tmr[i] - 8'd1;
          end

          if (do_beat) begin
            // Finish/advance the just-passed row = beat_cnt.
            for (i = 0; i < 4; i++) begin
              if (cache_valid && row_has_note(beat_cnt, i) && row_unjudged(beat_cnt, i)) begin
                if (row_is_hold_body_or_end(beat_cnt, i)) begin
                  if (hold_active[i] && key_hold[i]) begin
                    rating_rg[i] <= R_GOOD;
                    valid_tmr[i] <= VALID_SHOW_8;
                    score_next   = score_next + 16'd5;
                    if (row_is_hold_end(beat_cnt, i)) hold_active[i] <= 1'b0;
                  end else begin
                    rating_rg[i]   <= R_MISS;
                    valid_tmr[i]   <= VALID_SHOW_8;
                    hold_active[i] <= 1'b0;
                  end
                end else begin
                  rating_rg[i] <= R_MISS;
                  valid_tmr[i] <= VALID_SHOW_8;
                end
                last_row[i]       <= beat_cnt;
                last_row_valid[i] <= 1'b1;
              end
            end

            if (frame_cnt >= 8'd1) begin
              fpb     <= frame_cnt;
              step_q8 <= calc_step_q8(frame_cnt);
            end
            frame_cnt    <= 8'd0;
            sub_q8       <= 16'd0;
            beat_pending <= 1'b0;

            next_beat = beat_cnt + 12'd1;
            beat_cnt  <= next_beat;

            cache_base_target <= target_base_for(next_beat);
            cache_load_idx    <= 5'd0;
            cache_loading     <= 1'b1;
            cache_valid       <= 1'b0;

            if (next_beat >= cur_len) song_finish <= 1'b1;
          end else begin
            if (frame_cnt != 8'hFF) frame_cnt <= frame_cnt + 8'd1;
            sub_next = sub_q8 + step_q8;
            if (sub_next >= ROW_Q8) sub_q8 <= ROW_Q8 - 16'd1;
            else                    sub_q8 <= sub_next;
          end
        end

        // Key press judgment.  This is intentionally after miss handling so a
        // key in the same frame can still update the current lane display.
        for (i = 0; i < 4; i++) begin
          if (p_key[i]) begin
            press_tmr[i] <= PRESS_FLASH_8;
            if (j_hit[i]) begin
              last_row[i]       <= j_row[i];
              last_row_valid[i] <= 1'b1;
              rating_rg[i]      <= j_rate[i];
              valid_tmr[i]      <= VALID_SHOW_8;
              score_next        = score_next + {12'd0, j_score[i]};

              if (row_is_hold_start(j_row[i], i)) begin
                hold_active[i] <= 1'b1;
              end else if (!row_is_hold_body_or_end(j_row[i], i)) begin
                hold_active[i] <= 1'b0;
              end
            end
          end
        end

        score <= score_next;
      end
    end
  end

  // ---------------------------------------------------------------------------
  // Outputs
  // ---------------------------------------------------------------------------
  always_comb begin
    for (int l = 0; l < 4; l++) begin
      lane_pressed[l]       = (press_tmr[l] != 8'd0);
      lane_show_text[l]     = (valid_tmr[l] != 8'd0);
      lane_show_valid[l]    = (valid_tmr[l] != 8'd0) && (rating_rg[l] != R_MISS) && (rating_rg[l] != R_NONE);
      lane_rating[l*3 +: 3] = rating_rg[l];
    end
  end

endmodule

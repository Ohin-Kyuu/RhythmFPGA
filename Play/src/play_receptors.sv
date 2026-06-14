// =============================================================================
// play_receptors.sv
// -----------------------------------------------------------------------------
// 四軌底部的接收器（receptor）渲染：
//   key_base : 一直存在（94x21）
//   key_top  : 一直存在（92x22）；該軌 pressed 時下移 3px 對齊 base
//   key_valid: Bad 以上命中時，取代 key_top（按下態，下移 3px）（92x22）
//   評語字   : 命中時於框上顯示 PERFECT/GREAT/GOOD/BAD/MISS（沿用 char_upper.mem）
//
// 位元順序與 ui_button_bitmap 一致：mem 每列最左字元 = bitmap[width-1]（MSB）。
// =============================================================================
module play_receptors (
    input  logic [9:0]  vga_x,
    input  logic [9:0]  vga_y,

    input  logic [3:0]  lane_pressed,
    input  logic [3:0]  lane_show_valid,
    input  logic [3:0]  lane_show_text,
    input  logic [11:0] lane_rating,     // 4 x 3-bit

    output logic        rec_on,   // 接收器白色像素
    output logic        text_on   // 評語字白色像素
);

  // ---- 評級碼（需與 play_track 一致）----
  localparam logic [2:0] R_PERF = 3'd1;
  localparam logic [2:0] R_GREAT= 3'd2;
  localparam logic [2:0] R_GOOD = 3'd3;
  localparam logic [2:0] R_BAD  = 3'd4;
  localparam logic [2:0] R_MISS = 3'd5;

  // ---- 幾何 ----
  localparam int BASE_TOP_Y = 316;
  localparam int BASE_W = 94, BASE_H = 21;
  localparam int TOP_W  = 92, TOP_H  = 22;
  localparam int TEXT_TOP_Y = 322;        // 評語字基準 y（框內）

  // 每軌 base 左緣 x（top/valid 再 +1 置中）
  function automatic int base_left(input int l);
    unique case (l)
      0: base_left = 131;
      1: base_left = 226;
      2: base_left = 321;
      default: base_left = 416;
    endcase
  endfunction

  // ---------------------------------------------------------------------------
  // Bitmap ROM
  // ---------------------------------------------------------------------------
  logic [BASE_W-1:0] rom_base [0:BASE_H-1];
  logic [TOP_W-1:0]  rom_top  [0:TOP_H-1];
  logic [TOP_W-1:0]  rom_valid[0:TOP_H-1];

  initial begin
    $readmemb("key_base.mem",  rom_base);
    $readmemb("key_top.mem",   rom_top);
    $readmemb("key_valid.mem", rom_valid);
  end

  // ---------------------------------------------------------------------------
  // 字型 ROM（沿用 menu 的大寫字型 5x7，cell 6px）
  // ---------------------------------------------------------------------------
  localparam int CHAR_W = 6, CHAR_PIX_W = 5, CHAR_H = 7;
  logic [154:0] rom_char_upper[0:6];
  initial begin
    $readmemb("char_upper.mem", rom_char_upper);
  end

  function automatic logic glyph_at(input logic [7:0] ch, input int px, input int py);
    int offset;
    begin
      glyph_at = 1'b0;
      if (px >= 0 && px < CHAR_PIX_W && py >= 0 && py < CHAR_H &&
          ch >= "A" && ch <= "Z") begin
        offset   = (ch - "A") * CHAR_W;
        glyph_at = rom_char_upper[py[2:0]][154 - (offset + px)];
      end
    end
  endfunction

  // 評語字串（最長 7：PERFECT）
  function automatic int rate_len(input logic [2:0] r);
    unique case (r)
      R_PERF:  rate_len = 7;
      R_GREAT: rate_len = 5;
      R_GOOD:  rate_len = 4;
      R_BAD:   rate_len = 3;
      R_MISS:  rate_len = 4;
      default: rate_len = 0;
    endcase
  endfunction

  function automatic logic [7:0] rate_char(input logic [2:0] r, input int idx);
    logic [8*7-1:0] s;
    begin
      unique case (r)
        R_PERF:  s = "PERFECT";
        R_GREAT: s = {"GREAT", 16'h2020};   // 右補空白到 7
        R_GOOD:  s = {"GOOD",  24'h202020};
        R_BAD:   s = {"BAD",   32'h20202020};
        R_MISS:  s = {"MISS",  24'h202020};
        default: s = {7{8'h20}};
      endcase
      // s 為 7 字元，最左 = index0
      rate_char = s[(6-idx)*8 +: 8];
    end
  endfunction

  // ---------------------------------------------------------------------------
  // 找出目前像素所屬軌道
  // ---------------------------------------------------------------------------
  logic       in_lane;
  logic [1:0] lane;
  always_comb begin
    in_lane = 1'b0; lane = 2'd0;
    if      (vga_x >= 10'd131 && vga_x < 10'd225) begin lane = 2'd0; in_lane = 1'b1; end
    else if (vga_x >= 10'd226 && vga_x < 10'd320) begin lane = 2'd1; in_lane = 1'b1; end
    else if (vga_x >= 10'd321 && vga_x < 10'd415) begin lane = 2'd2; in_lane = 1'b1; end
    else if (vga_x >= 10'd416 && vga_x < 10'd510) begin lane = 2'd3; in_lane = 1'b1; end
  end

  // ---------------------------------------------------------------------------
  // 渲染
  // ---------------------------------------------------------------------------
  int bl, tl;
  int dx_b, dy_b, dx_t, dy_t;
  int top_y;
  logic pressed, show_valid, show_text;
  logic [2:0] rating;
  logic base_bit, top_bit, valid_bit;

  always_comb begin
    rec_on  = 1'b0;
    text_on = 1'b0;

    if (in_lane) begin
      pressed    = lane_pressed[lane];
      show_valid = lane_show_valid[lane];
      show_text  = lane_show_text[lane];
      rating     = lane_rating[lane*3 +: 3];

      bl = base_left(lane);
      tl = bl + 1;                                // top/valid 置中
      top_y = (show_valid || pressed) ? BASE_TOP_Y : (BASE_TOP_Y - 3);

      // --- key_base（恆在）---
      base_bit = 1'b0;
      if (vga_x >= bl && vga_x < bl + BASE_W &&
          vga_y >= BASE_TOP_Y && vga_y < BASE_TOP_Y + BASE_H) begin
        dx_b = int'(vga_x) - bl;
        dy_b = int'(vga_y) - BASE_TOP_Y;
        base_bit = rom_base[dy_b[4:0]][BASE_W-1 - dx_b];
      end

      // --- key_top / key_valid ---
      top_bit = 1'b0; valid_bit = 1'b0;
      if (vga_x >= tl && vga_x < tl + TOP_W &&
          vga_y >= top_y && vga_y < top_y + TOP_H) begin
        dx_t = int'(vga_x) - tl;
        dy_t = int'(vga_y) - top_y;
        if (show_valid)
          valid_bit = rom_valid[dy_t[4:0]][TOP_W-1 - dx_t];
        else
          top_bit   = rom_top[dy_t[4:0]][TOP_W-1 - dx_t];
      end

      rec_on = base_bit | top_bit | valid_bit;

      // --- 評語字 ---
      if (show_text && rating != 3'd0) begin
        int n, x_start, rel, cidx, cpx, cpy;
        n = rate_len(rating);
        x_start = bl + (BASE_W - n*CHAR_W) / 2;     // 軌內置中
        if (vga_x >= x_start && vga_x < x_start + n*CHAR_W &&
            vga_y >= TEXT_TOP_Y && vga_y < TEXT_TOP_Y + CHAR_H) begin
          rel  = int'(vga_x) - x_start;
          cidx = rel / CHAR_W;
          cpx  = rel % CHAR_W;
          cpy  = int'(vga_y) - TEXT_TOP_Y;
          text_on = glyph_at(rate_char(rating, cidx), cpx, cpy);
        end
      end
    end
  end

endmodule

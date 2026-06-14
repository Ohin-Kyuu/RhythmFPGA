module Finish (
    input logic clk,
    input logic rst_n,

    input logic [9:0] vga_x,
    input logic [9:0] vga_y,

    input logic [15:0] score,

    input logic db_back,
    input logic p_back,

    output logic back_to_menu,
    output logic ui_pixel
);

  localparam int SCORE_TEXT_X = 306;
  localparam int SCORE_TEXT_Y = 177;

  localparam int SCORE_BOX_X = 251;
  localparam int SCORE_BOX_Y = 194;
  localparam int SCORE_BOX_W = 139;
  localparam int SCORE_BOX_H = 24;

  localparam int SCORE_NUM_X = 309;
  localparam int SCORE_NUM_Y = 203;

  localparam logic [9:0] BACK_BASE_X = 10'd251;
  localparam logic [9:0] BACK_BASE_Y = 10'd280;
  localparam logic [9:0] BACK_TOP_X = 10'd252;
  localparam logic [9:0] BACK_TOP_Y = 10'd277;
  localparam logic [9:0] BACK_TEXT_X = 10'd284;
  localparam logic [9:0] BACK_TEXT_Y = 10'd282;

  localparam logic [9:0] ARROW_X = 10'd316;
  localparam logic [9:0] ARROW_Y = 10'd291;

  localparam logic [3:0] CHAR_W = 4'd6;
  localparam logic [2:0] CHAR_PIX_W = 3'd5;
  localparam logic [3:0] UPPER_CHAR_H = 4'd7;
  localparam logic [3:0] LOWER_CHAR_H = 4'd8;
  localparam logic [2:0] NUM_H = 3'd7;
  localparam logic [2:0] NUM_PIX_W = 3'd5;

  localparam logic [8*5-1:0] STR_SCORE = "SCORE";
  localparam logic [8*12-1:0] STR_BACK = "Back to MENU";

  assign back_to_menu = p_back;

  logic [154:0] rom_char_lower[0:7];
  logic [154:0] rom_char_upper[0:6];
  logic [ 58:0] rom_number    [0:6];
  logic [  7:0] rom_arrow     [0:4];

  initial begin
    $readmemb("char_lower.mem", rom_char_lower);
    $readmemb("char_upper.mem", rom_char_upper);
    $readmemb("char_number.mem", rom_number);
    $readmemb("arrow.mem", rom_arrow);
  end

  function automatic logic in_rect(input logic [9:0] x, input logic [9:0] y, input int left,
                                   input int top, input int width, input int height);
    return (x >= left) && (x < left + width) && (y >= top) && (y < top + height);
  endfunction

  function automatic logic on_rect_border(input logic [9:0] x, input logic [9:0] y, input int left,
                                          input int top, input int width, input int height);
    return in_rect(x, y, left, top, width, height) &&
        ((x == left) || (x == left + width - 1) || (y == top) || (y == top + height - 1));
  endfunction

  function automatic logic font_pixel_at(input logic [7:0] ch, input logic [2:0] pixel_x,
                                         input logic [3:0] pixel_y);
    logic [9:0] offset;
    begin
      font_pixel_at = 1'b0;

      if (pixel_x < CHAR_PIX_W) begin
        if (ch >= "A" && ch <= "Z" && pixel_y < UPPER_CHAR_H) begin
          offset = (ch - "A") * CHAR_W;
          font_pixel_at = rom_char_upper[pixel_y[2:0]][154-(offset+pixel_x)];
        end else if (ch >= "a" && ch <= "z" && pixel_y < LOWER_CHAR_H) begin
          offset = (ch - "a") * CHAR_W;
          font_pixel_at = rom_char_lower[pixel_y[2:0]][154-(offset+pixel_x)];
        end
      end
    end
  endfunction

  function automatic logic number_pixel_at(input logic [3:0] digit, input logic [2:0] pixel_x,
                                           input logic [2:0] pixel_y);
    logic [6:0] offset;
    begin
      number_pixel_at = 1'b0;
      if (digit <= 4'd9 && pixel_x < NUM_PIX_W && pixel_y < NUM_H) begin
        offset = digit * 7'd6 + {4'd0, pixel_x};
        number_pixel_at = rom_number[pixel_y][58-offset];
      end
    end
  endfunction

  logic back_btn_active;
  logic back_btn_pixel;

  ui_button_bitmap #(
      .BASE_X(BACK_BASE_X),
      .BASE_Y(BACK_BASE_Y),
      .TOP_X (BACK_TOP_X),
      .TOP_Y (BACK_TOP_Y)
  ) U_back_button (
      .visible(1'b1),
      .pressed(db_back),
      .vga_x  (vga_x),
      .vga_y  (vga_y),
      .active (back_btn_active),
      .pixel  (back_btn_pixel)
  );

  logic [9:0] back_text_y_now;
  logic [9:0] arrow_y_now;

  assign back_text_y_now = BACK_TEXT_Y + (db_back ? 10'd2 : 10'd0);
  assign arrow_y_now     = ARROW_Y + (db_back ? 10'd2 : 10'd0);

  logic [13:0] score_sat;
  logic [3:0] score_d3, score_d2, score_d1, score_d0;
  logic [13:0] rem0, rem1, rem2;

  always_comb begin
    score_sat = (score > 16'd9999) ? 14'd9999 : score[13:0];

    if (score_sat >= 14'd9000) score_d3 = 4'd9;
    else if (score_sat >= 14'd8000) score_d3 = 4'd8;
    else if (score_sat >= 14'd7000) score_d3 = 4'd7;
    else if (score_sat >= 14'd6000) score_d3 = 4'd6;
    else if (score_sat >= 14'd5000) score_d3 = 4'd5;
    else if (score_sat >= 14'd4000) score_d3 = 4'd4;
    else if (score_sat >= 14'd3000) score_d3 = 4'd3;
    else if (score_sat >= 14'd2000) score_d3 = 4'd2;
    else if (score_sat >= 14'd1000) score_d3 = 4'd1;
    else score_d3 = 4'd0;

    rem0 = score_sat - ({10'd0, score_d3} * 14'd1000);

    if (rem0 >= 14'd900) score_d2 = 4'd9;
    else if (rem0 >= 14'd800) score_d2 = 4'd8;
    else if (rem0 >= 14'd700) score_d2 = 4'd7;
    else if (rem0 >= 14'd600) score_d2 = 4'd6;
    else if (rem0 >= 14'd500) score_d2 = 4'd5;
    else if (rem0 >= 14'd400) score_d2 = 4'd4;
    else if (rem0 >= 14'd300) score_d2 = 4'd3;
    else if (rem0 >= 14'd200) score_d2 = 4'd2;
    else if (rem0 >= 14'd100) score_d2 = 4'd1;
    else score_d2 = 4'd0;

    rem1 = rem0 - ({10'd0, score_d2} * 14'd100);

    if (rem1 >= 14'd90) score_d1 = 4'd9;
    else if (rem1 >= 14'd80) score_d1 = 4'd8;
    else if (rem1 >= 14'd70) score_d1 = 4'd7;
    else if (rem1 >= 14'd60) score_d1 = 4'd6;
    else if (rem1 >= 14'd50) score_d1 = 4'd5;
    else if (rem1 >= 14'd40) score_d1 = 4'd4;
    else if (rem1 >= 14'd30) score_d1 = 4'd3;
    else if (rem1 >= 14'd20) score_d1 = 4'd2;
    else if (rem1 >= 14'd10) score_d1 = 4'd1;
    else score_d1 = 4'd0;

    rem2 = rem1 - ({10'd0, score_d1} * 14'd10);
    score_d0 = rem2[3:0];
  end

  logic score_text_on;
  logic score_num_on;
  logic back_text_on;
  logic arrow_on;

  logic [7:0] target_char;
  logic [3:0] digit_sel;
  logic [3:0] char_index;
  logic [2:0] char_pixel_x;
  logic [3:0] char_pixel_y;
  logic [2:0] num_pixel_x;
  logic [2:0] num_pixel_y;

  always_comb begin
    score_text_on = 1'b0;
    score_num_on  = 1'b0;
    back_text_on  = 1'b0;
    arrow_on      = 1'b0;

    target_char   = " ";
    digit_sel     = 4'd0;
    char_index    = '0;
    char_pixel_x  = '0;
    char_pixel_y  = '0;
    num_pixel_x   = '0;
    num_pixel_y   = '0;

    // drawString("SCORE", 306, 177)
    if (in_rect(vga_x, vga_y, SCORE_TEXT_X, SCORE_TEXT_Y, 5 * CHAR_W, UPPER_CHAR_H)) begin
      char_index = (vga_x - SCORE_TEXT_X) / CHAR_W;
      target_char = STR_SCORE[(4-char_index)*8+:8];
      char_pixel_x = (vga_x - SCORE_TEXT_X) % CHAR_W;
      char_pixel_y = vga_y - SCORE_TEXT_Y;
      score_text_on = font_pixel_at(target_char, char_pixel_x, char_pixel_y);
    end

    // 4-digit score, zero-padded: 0000 ~ 9999
    if (in_rect(vga_x, vga_y, SCORE_NUM_X, SCORE_NUM_Y, 4 * CHAR_W, NUM_H)) begin
      char_index  = (vga_x - SCORE_NUM_X) / CHAR_W;
      num_pixel_x = (vga_x - SCORE_NUM_X) % CHAR_W;
      num_pixel_y = vga_y - SCORE_NUM_Y;

      unique case (char_index[1:0])
        2'd0: digit_sel = score_d3;
        2'd1: digit_sel = score_d2;
        2'd2: digit_sel = score_d1;
        default: digit_sel = score_d0;
      endcase

      score_num_on = number_pixel_at(digit_sel, num_pixel_x, num_pixel_y);
    end

    // "Back to MENU" centered on reused button
    if (in_rect(vga_x, vga_y, BACK_TEXT_X, back_text_y_now, 12 * CHAR_W, LOWER_CHAR_H)) begin
      char_index   = (vga_x - BACK_TEXT_X) / CHAR_W;
      target_char  = STR_BACK[(11-char_index)*8+:8];
      char_pixel_x = (vga_x - BACK_TEXT_X) % CHAR_W;
      char_pixel_y = vga_y - back_text_y_now;
      back_text_on = font_pixel_at(target_char, char_pixel_x, char_pixel_y);
    end

    // arrow.mem, width=8, height=5, placed at (316, 291)
    if (in_rect(vga_x, vga_y, ARROW_X, arrow_y_now, 8, 5)) begin
      arrow_on = rom_arrow[vga_y-arrow_y_now][7-(vga_x-ARROW_X)];
    end
  end

  // ---------------------------------------------------------------------------
  // Pixel composition.  The Back button text and arrow are black on the button.
  // ---------------------------------------------------------------------------
  always_comb begin
    ui_pixel = 1'b0;

    if (on_rect_border(vga_x, vga_y, SCORE_BOX_X, SCORE_BOX_Y, SCORE_BOX_W, SCORE_BOX_H)) begin
      ui_pixel = 1'b1;
    end

    if (score_text_on || score_num_on) begin
      ui_pixel = 1'b1;
    end

    if (back_btn_active) begin
      ui_pixel = back_btn_pixel;
    end

    if (back_text_on || arrow_on) begin
      ui_pixel = 1'b0;
    end
  end

endmodule

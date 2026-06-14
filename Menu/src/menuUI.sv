module menuUI (
    input logic       clk,
    input logic       rst_n,
    input logic [9:0] vga_x,
    input logic [9:0] vga_y,
    input logic       frame_tick,

    input logic       btn_start,
    input logic       btn_vol,
    input logic [2:0] sw,
    input logic [3:0] current_vol,

    output logic vol_is_open,
    output logic ui_pixel
);

  localparam int SONG_BOX_X = 251;
  localparam int SONG_BOX_Y = 218;
  localparam int SONG_BOX_W = 139;
  localparam int SONG_BOX_H = 25;

  localparam int START_BASE_X = 251;
  localparam int START_BASE_Y = 262;
  localparam int START_TOP_X = 252;
  localparam int START_TOP_Y = 259;
  localparam int START_TEXT_Y = 268;

  localparam int VOL_BASE_X = 251;
  localparam int VOL_BASE_Y = 303;
  localparam int VOL_TOP_X = 252;
  localparam int VOL_TOP_Y = 300;
  localparam int VOL_TEXT_Y = 309;

  localparam logic [9:0] VOL_BAR_Y_OPEN = 10'd343;
  localparam logic [5:0] VOL_BAR_SLIDE = 6'd10;

  logic [9:0] vol_bar_y;
  logic       vol_bar_visible;

  always_comb begin
    vol_bar_y       = VOL_BAR_Y_OPEN + {4'd0, vol_slide_y} - {4'd0, VOL_BAR_SLIDE};
    vol_bar_visible = (vol_slide_y != 6'd0);
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

  logic valid_song;
  assign valid_song = (sw == 3'b001) || (sw == 3'b010) || (sw == 3'b100);

  logic start_pressed;
  logic vol_pressed;
  logic vol_toggle_pulse;

  ui_button_controller U_button_ctrl (
      .clk             (clk),
      .rst_n           (rst_n),
      .valid_song      (valid_song),
      .btn_start_level (btn_start),
      .btn_vol_level   (btn_vol),
      .start_pressed   (start_pressed),
      .vol_pressed     (vol_pressed),
      .vol_toggle_pulse(vol_toggle_pulse)
  );

  logic [5:0] vol_slide_y;
  logic [8:0] scroll_offset;

  ui_menu_fsm #(
      .BAR_SLIDE(VOL_BAR_SLIDE)
  ) U_fsm (
      .clk             (clk),
      .rst_n           (rst_n),
      .valid_song      (valid_song),
      .vol_toggle_pulse(vol_toggle_pulse),
      .frame_tick      (frame_tick),
      .vol_is_open     (vol_is_open),
      .vol_slide_y     (vol_slide_y),
      .scroll_offset   (scroll_offset)
  );

  logic start_btn_active;
  logic start_btn_pixel;
  logic vol_btn_active;
  logic vol_btn_pixel;

  ui_button_bitmap #(
      .BASE_X(START_BASE_X),
      .BASE_Y(START_BASE_Y),
      .TOP_X (START_TOP_X),
      .TOP_Y (START_TOP_Y)
  ) U_start_button (
      .visible(valid_song),
      .pressed(start_pressed),
      .vga_x  (vga_x),
      .vga_y  (vga_y),
      .active (start_btn_active),
      .pixel  (start_btn_pixel)
  );

  logic rhythm_active;
  logic rhythm_pixel;

  ui_rhythm_bitmap U_rhythm (
      .vga_x (vga_x),
      .vga_y (vga_y),
      .active(rhythm_active),
      .pixel (rhythm_pixel)
  );

  ui_button_bitmap #(
      .BASE_X(VOL_BASE_X),
      .BASE_Y(VOL_BASE_Y),
      .TOP_X (VOL_TOP_X),
      .TOP_Y (VOL_TOP_Y)
  ) U_volume_button (
      .visible(1'b1),
      .pressed(vol_pressed),
      .vga_x  (vga_x),
      .vga_y  (vga_y),
      .active (vol_btn_active),
      .pixel  (vol_btn_pixel)
  );

  logic bar_active;
  logic bar_pixel;

  ui_volume_bar U_volume_bar (
      .visible    (vol_bar_visible),
      .bar_y      (vol_bar_y),
      .vga_x      (vga_x),
      .vga_y      (vga_y),
      .current_vol(current_vol),
      .active     (bar_active),
      .pixel      (bar_pixel)
  );

  logic glyph_on;
  logic glyph_black;
  logic text_bg_active;
  logic [9:0] start_text_y_now;
  logic [9:0] vol_text_y_now;

  assign start_text_y_now = START_TEXT_Y + (start_pressed ? 10'd2 : 10'd0);
  assign vol_text_y_now   = VOL_TEXT_Y + (vol_pressed ? 10'd2 : 10'd0);

  ui_text_layer U_text (
      .vga_x         (vga_x),
      .vga_y         (vga_y),
      .valid_song    (valid_song),
      .sw            (sw),
      .scroll_offset (scroll_offset),
      .start_text_y  (start_text_y_now),
      .vol_text_y    (vol_text_y_now),
      .glyph_on      (glyph_on),
      .glyph_black   (glyph_black),
      .text_bg_active(text_bg_active)
  );

  always_comb begin
    ui_pixel = 1'b0;

    if (rhythm_active) begin
      ui_pixel = rhythm_pixel;
    end

    if (on_rect_border(vga_x, vga_y, SONG_BOX_X, SONG_BOX_Y, SONG_BOX_W, SONG_BOX_H)) begin
      ui_pixel = 1'b1;
    end

    if (start_btn_active) begin
      ui_pixel = start_btn_pixel;
    end

    if (vol_btn_active) begin
      ui_pixel = vol_btn_pixel;
    end

    if (bar_active) begin
      ui_pixel = bar_pixel;
    end

    if (text_bg_active) begin
      ui_pixel = 1'b0;
    end

    if (glyph_on) begin
      ui_pixel = glyph_black ? 1'b0 : 1'b1;
    end
  end

endmodule

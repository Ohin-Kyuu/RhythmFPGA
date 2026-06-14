module Play (
    input logic       clk,
    input logic       rst_n,
    input logic [9:0] vga_x,
    input logic [9:0] vga_y,
    input logic       video_valid,
    input logic       frame_tick,
    input logic       beat,
    input logic       play_en,
    input logic       play_rst,
    input logic [2:0] sel_song,
    input logic [3:0] p_key,
    input logic [3:0] key_hold,

    output logic [ 3:0] vga_r,
    output logic [ 3:0] vga_g,
    output logic [ 3:0] vga_b,
    output logic [15:0] score,
    output logic        song_finish
);

  // -- 模組間通訊信號 --
  logic [11:0] beat_cnt;
  logic [ 7:0] sub_acc_px;
  logic        note_on;
  logic [ 1:0] note_lane;
  logic [3:0] lane_pressed, lane_show_valid, lane_show_text;
  logic [11:0] lane_rating;

  // 1. 遊戲核心邏輯 (MVC: Model/Controller)
  play_track_logic U_logic (
      .clk(clk),
      .rst_n(rst_n),
      .frame_tick(frame_tick),
      .beat(beat),
      .play_en(play_en),
      .play_rst(play_rst),
      .sel_song(sel_song),
      .p_key(p_key),
      .key_hold(key_hold),
      .beat_cnt(beat_cnt),
      .sub_acc_px(sub_acc_px),
      .lane_pressed(lane_pressed),
      .lane_show_valid(lane_show_valid),
      .lane_show_text(lane_show_text),
      .lane_rating(lane_rating),
      .score(score),
      .song_finish(song_finish)
  );

  // 2. 音符軌道渲染 (MVC: View)
  play_track_render U_render (
      .vga_x(vga_x),
      .vga_y(vga_y),
      .sel_song(sel_song),
      .beat_cnt(beat_cnt),
      .sub_acc_px(sub_acc_px),
      .note_on(note_on),
      .note_lane(note_lane)
  );

  // 3. 接收器與文字渲染
  logic rec_on, text_on;
  logic [3:0] lane_pressed_ui;
  assign lane_pressed_ui = lane_pressed | key_hold;

  play_receptors U_rec (
      .vga_x(vga_x),
      .vga_y(vga_y),
      .lane_pressed(lane_pressed_ui),
      .lane_show_valid(lane_show_valid),
      .lane_show_text(lane_show_text),
      .lane_rating(lane_rating),
      .rec_on(rec_on),
      .text_on(text_on)
  );

  // 4. 背景軌道線與顏色合成
  localparam logic [11:0] C_BLACK = 12'h000, C_WHITE = 12'hFFF, C_GRAY = 12'h777;
  localparam logic [11:0] C_NOTE0 = 12'hF44, C_NOTE1 = 12'h4F6, C_NOTE2 = 12'h4AF, C_NOTE3 = 12'hFD2;


  logic on_line_w, on_line_g;
  always_comb begin
    on_line_w = (vga_y >= 10'd1 && vga_y <= 10'd359) && (vga_x == 10'd130 || vga_x == 10'd510);
    on_line_g = (vga_y >= 10'd1 && vga_y <= 10'd359) && (vga_x == 10'd225 || vga_x == 10'd320 || vga_x == 10'd415);
  end

  logic [11:0] note_color, color;
  always_comb begin
    unique case (note_lane)
      2'd0: note_color = C_NOTE0;
      2'd1: note_color = C_NOTE1;
      2'd2: note_color = C_NOTE2;
      default: note_color = C_NOTE3;
    endcase
  end

  always_comb begin
    color = C_BLACK;
    if (note_on) color = note_color;
    if (on_line_w) color = C_WHITE;
    if (on_line_g) color = C_GRAY;
    if (rec_on) color = C_WHITE;
    if (text_on) color = C_WHITE;
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

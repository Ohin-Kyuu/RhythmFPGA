module Music (
    input logic clk,
    input logic rst_n,

    input logic [2:0] song_sel,
    input logic [3:0] volume,
    input logic       music_playing,
    input logic       music_reset,

    output logic beat,
    output logic song_finish,

    output logic mclk,
    output logic lrck,
    output logic sck,
    output logic sdin
);

  beatGen U_bG (
      .clk  (clk),
      .rst_n(rst_n),
      .clr  (music_reset),
      .sel  (song_sel),
      .beat (beat)
  );

  logic [65:0] line_out;

  linegen U_lg_rom (
      .clk    (clk),
      .rst_n  (rst_n),
      .restart(music_reset),
      .sel    (song_sel),
      .playing(music_playing),
      .beat   (beat),
      .line   (line_out),
      .finish (song_finish)
  );

  logic signed [15:0] mix_l, mix_r;

  trackMix U_tM (
      .clk    (clk),
      .rst_n  (rst_n),
      .playing(music_playing),
      .volume (volume),
      .beat   (beat),
      .line   (line_out),
      .mix_l  (mix_l),
      .mix_r  (mix_r)
  );

  speakCtrl U_sc (
      .clk    (clk),
      .rst_n  (rst_n),
      .audio_l(mix_l),
      .audio_r(mix_r),
      .mclk   (mclk),
      .lrck   (lrck),
      .sck    (sck),
      .sdin   (sdin)
  );

endmodule

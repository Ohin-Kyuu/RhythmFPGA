module Music (
    input logic clk,
    input logic rst_n,
    input logic [2:0] btn,
    input logic [2:0] sw,  // 001: mario, 010: zelda, 100: pokemon

    // Audio
    output logic mclk,
    output logic lrck,
    output logic sck,
    output logic sdin,
    output logic [3:0] leds
);

  logic [2:0] sel_song;
  assign sel_song = sw;

  logic clk_100;
  clk_IC U_clk_100 (
      .clk    (clk),
      .rst_n  (rst_n),
      .clk_100(clk_100)
  );

  logic [2:0] db;
  logic db_play;
  logic [1:0] db_vol;
  debAll #(
      .NUM(3)
  ) U_db (
      .clk(clk_100),
      .rst_n(rst_n),
      .in(btn),
      .db_out(db)
  );
  assign {db_play, db_vol} = db;

  logic p_play;
  pulsegen U_pg_play (
      .clk(clk),
      .rst_n(rst_n),
      .in(db_play),
      .pulse(p_play)
  );

  logic [1:0] p_vol;
  pulAll #(
      .NUM(2)
  ) U_pg (
      .clk(clk_100),
      .rst_n(rst_n),
      .in(db_vol),
      .p_out(p_vol)
  );

  logic beat;
  beatGen U_bG (
      .clk  (clk),
      .rst_n(rst_n),
      .sel  (sel_song),
      .beat (beat)
  );

  logic playing;
  logic finish;
  logic [65:0] line_out;

  fsm U_fsm (
      .clk      (clk),
      .rst_n    (rst_n),
      .p_play   (p_play),
      .finish   (finish),
      // output
      .playing  (playing),
      .clear_n  (),
      .state_out()
  );

  linegen U_lg_rom (
      .clk    (clk),
      .rst_n  (rst_n),
      .sel    (sel_song),
      .playing(playing),
      .beat   (beat),
      // output
      .line   (line_out),
      .finish (finish)
  );

  logic [3:0] volume;
  logic signed [15:0] mix_l, mix_r;

  volctrl U_vc (
      .clk(clk_100),
      .rst_n(rst_n),
      .up(p_vol[1]),
      .down(p_vol[0]),
      .volume(volume)
  );

  assign leds = volume;

  trackMix U_tM (
      .clk(clk),
      .rst_n(rst_n),
      .volume(volume),
      .beat(beat),
      .line(line_out),
      .mix_l(mix_l),
      .mix_r(mix_r)
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

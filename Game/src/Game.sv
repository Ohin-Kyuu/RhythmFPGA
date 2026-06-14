module Game (
    input logic       clk,
    input logic       rst_n,
    input logic [2:0] sw,
    input logic [3:0] btn,

    // Keyboard
    inout wire PS2_CLK,
    inout wire PS2_DATA,

    // VGA
    output logic [3:0] vga_r,
    output logic [3:0] vga_g,
    output logic [3:0] vga_b,
    output logic       hsync,
    output logic       vsync,

    // Music
    output logic mclk,
    output logic lrck,
    output logic sck,
    output logic sdin,

    output logic [3:0] leds
);

  // ---------------------------------------------------------------------------
  // VGA timing
  // ---------------------------------------------------------------------------
  logic [9:0] vga_x;
  logic [9:0] vga_y;
  logic       video_valid;
  logic       frame_tick;

  VGACtrl U_vg (
      .clk(clk),
      .rst_n(rst_n),
      .vga_x(vga_x),
      .vga_y(vga_y),
      .hsync(hsync),
      .vsync(vsync),
      .valid(video_valid),
      .frame_tick(frame_tick)
  );

  // ---------------------------------------------------------------------------
  // Buttons
  // btn[0] start / back, btn[1] volume up, btn[2] volume menu, btn[3] volume down
  // ---------------------------------------------------------------------------
  logic [3:0] db_btn;
  logic [3:0] p_btn;

  debAll #(
      .NUM(4)
  ) U_db_btn (
      .clk(clk),
      .rst_n(rst_n),
      .in(btn),
      .db_out(db_btn)
  );

  pulAll #(
      .NUM(4)
  ) U_pulse_btn (
      .clk(clk),
      .rst_n(rst_n),
      .in(db_btn),
      .p_out(p_btn)
  );

  logic db_start, db_vol;
  logic p_start, p_vol, p_up, p_down;

  assign db_start = db_btn[0];
  assign db_vol   = db_btn[2];
  assign p_start  = p_btn[0];
  assign p_vol    = p_btn[2];
  assign p_up     = p_btn[1];
  assign p_down   = p_btn[3];

  // ---------------------------------------------------------------------------
  // Keyboard: p_key[0]=D, p_key[1]=F, p_key[2]=J, p_key[3]=K
  // ---------------------------------------------------------------------------
  logic       p_space;
  logic [3:0] p_key;
  logic [3:0] key_hold;

  KeyPulse Ukp (
      .clk(clk),
      .rst_n(rst_n),
      .PS2_CLK(PS2_CLK),
      .PS2_DATA(PS2_DATA),
      .p_space(p_space),
      .p_key(p_key),
      .key_hold(key_hold)
  );

  // ---------------------------------------------------------------------------
  // FSM control
  // ---------------------------------------------------------------------------
  logic [2:0] state_out;
  logic [1:0] countdown_num;

  logic music_song_finish;
  logic play_song_finish;
  logic song_finish;

  // 目前先以 Music 結束作為真正遊戲結束條件；Play 的 finish 可當 debug。
  assign song_finish = music_song_finish;

  localparam logic [2:0] S_SELECT = 3'd0;
  localparam logic [2:0] S_COUNTDOWN = 3'd1;
  localparam logic [2:0] S_PLAYING = 3'd2;
  localparam logic [2:0] S_PAUSE = 3'd3;
  localparam logic [2:0] S_RESUME_WAIT = 3'd4;
  localparam logic [2:0] S_FINISH = 3'd5;

  logic in_select, in_countdown, in_playing, in_pause, in_resume_wait, in_finish;

  assign in_select      = (state_out == S_SELECT);
  assign in_countdown   = (state_out == S_COUNTDOWN);
  assign in_playing     = (state_out == S_PLAYING);
  assign in_pause       = (state_out == S_PAUSE);
  assign in_resume_wait = (state_out == S_RESUME_WAIT);
  assign in_finish      = (state_out == S_FINISH);

  logic music_play_en;
  logic music_reset;
  logic play_en;
  logic play_rst;

  assign music_play_en = in_playing;
  assign play_en       = in_playing;

  assign music_reset   = in_select;
  assign play_rst      = in_select;

  game_fsm U_g_fsm (
      .clk          (clk),
      .rst_n        (rst_n),
      .frame_tick   (frame_tick),
      .p_start      (p_start),
      .p_space      (p_space),
      .song_finish  (song_finish),
      .state_out    (state_out),
      .countdown_num(countdown_num)
  );

  // ---------------------------------------------------------------------------
  // Menu
  // ---------------------------------------------------------------------------
  logic       menu_pixel;
  logic       menu_start;
  logic [2:0] menu_song_sel;
  logic [3:0] menu_volume;
  logic       menu_vol_is_open;

  Menu Um (
      .clk        (clk),
      .rst_n      (rst_n),
      .vga_x      (vga_x),
      .vga_y      (vga_y),
      .frame_tick (frame_tick),
      .sw         (sw),
      .db_start   (db_start),
      .db_vol     (db_vol),
      .p_up       (p_up),
      .p_down     (p_down),
      .start      (menu_start),
      .song_sel   (menu_song_sel),
      .volume     (menu_volume),
      .vol_is_open(menu_vol_is_open),
      .ui_pixel   (menu_pixel)
  );

  // ---------------------------------------------------------------------------
  // Music. Music beat 同時提供 Play 軌道對齊。
  // ---------------------------------------------------------------------------
  logic music_beat;

  Music Ums (
      .clk          (clk),
      .rst_n        (rst_n),
      .song_sel     (menu_song_sel),
      .volume       (menu_volume),
      .music_playing(music_play_en),
      .music_reset  (music_reset),
      .beat         (music_beat),
      .song_finish  (music_song_finish),
      .mclk         (mclk),
      .lrck         (lrck),
      .sck          (sck),
      .sdin         (sdin)
  );
  // ---------------------------------------------------------------------------
  // Play screen / scoring
  // ---------------------------------------------------------------------------
  logic [3:0] play_r, play_g, play_b;
  logic [15:0] play_score;

  Play Upy (
      .clk        (clk),
      .rst_n      (rst_n),
      // vga in 
      .vga_x      (vga_x),
      .vga_y      (vga_y),
      .video_valid(video_valid),
      .frame_tick (frame_tick),
      .beat       (music_beat),
      // FSM
      .play_en    (play_en),
      .play_rst   (play_rst),
      .sel_song   (menu_song_sel),
      // Keyboard
      .p_key      (p_key),
      .key_hold   (key_hold),
      // vga out
      .vga_r      (play_r),
      .vga_g      (play_g),
      .vga_b      (play_b),
      .score      (play_score),
      .song_finish(play_song_finish)
  );


  // ---------------------------------------------------------------------------
  // Finish screen
  // ---------------------------------------------------------------------------
  logic finish_pixel;
  logic finish_back_to_menu;

  Finish Uf (
      .clk         (clk),
      .rst_n       (rst_n),
      .vga_x       (vga_x),
      .vga_y       (vga_y),
      .score       (play_score),
      .db_back     (db_start),
      .p_back      (p_start),
      .back_to_menu(finish_back_to_menu),
      .ui_pixel    (finish_pixel)
  );

  // Debug LEDs：state。想看分數低 4 bit 可以改成 play_score[3:0]
  assign leds = {1'b0, state_out};

  // ---------------------------------------------------------------------------
  // VGA mux
  // ---------------------------------------------------------------------------
  always_comb begin
    vga_r = 4'h0;
    vga_g = 4'h0;
    vga_b = 4'h0;

    if (video_valid) begin
      if (in_select) begin
        vga_r = menu_pixel ? 4'hF : 4'h0;
        vga_g = menu_pixel ? 4'hF : 4'h0;
        vga_b = menu_pixel ? 4'hF : 4'h0;
      end else if (in_countdown || in_playing || in_pause || in_resume_wait) begin
        vga_r = play_r;
        vga_g = play_g;
        vga_b = play_b;
      end else if (in_finish) begin
        vga_r = finish_pixel ? 4'hF : 4'h0;
        vga_g = finish_pixel ? 4'hF : 4'h0;
        vga_b = finish_pixel ? 4'hF : 4'h0;
      end
    end
  end

endmodule

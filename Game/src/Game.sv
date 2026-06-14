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

    output logic [ 3:0] ssd_ctl,
    output logic [ 7:0] ssd_out,
    output logic [15:0] leds
);

  // VGA timing
  logic [9:0] vga_x;
  logic [9:0] vga_y;
  logic       video_valid;
  logic       frame_tick_raw;  // generated in the 25 MHz pixel-clock domain
  logic       frame_tick;  // clean single 100 MHz-cycle pulse, 1 per frame

  VGACtrl U_vg (
      .clk(clk),
      .rst_n(rst_n),
      .vga_x(vga_x),
      .vga_y(vga_y),
      .hsync(hsync),
      .vsync(vsync),
      .valid(video_valid),
      .frame_tick(frame_tick_raw)
  );

  logic ft_s0, ft_s1, ft_s2;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      ft_s0 <= 1'b0;
      ft_s1 <= 1'b0;
      ft_s2 <= 1'b0;
    end else begin
      ft_s0 <= frame_tick_raw;  // synchronizer FF 1
      ft_s1 <= ft_s0;  // synchronizer FF 2
      ft_s2 <= ft_s1;  // delayed copy for edge detect
    end
  end
  assign frame_tick = ft_s1 & ~ft_s2;  // one clean pulse per frame

  // Buttons
  // btn[0] start / back 
  // btn[1] volume up 
  // btn[2] volume menu 
  // btn[3] volume down
  logic [3:0] db_btn;
  logic [3:0] p_btn;
  logic clk_100;

  clk_IC Uclk (
      .clk(clk),
      .rst_n(rst_n),
      .clk_100(clk_100)
  );

  debAll #(
      .NUM(4)
  ) U_db_btn (
      .clk(clk_100),
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

  // Keyboard: p_key[0]=D, p_key[1]=F, p_key[2]=J, p_key[3]=K
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

  // FSM
  logic [2:0] state_out;
  logic [1:0] countdown_num;

  logic music_song_finish;
  logic play_song_finish;
  logic song_finish;

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

  logic countdown_is_new_game;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      countdown_is_new_game <= 1'b1;
    end else if (in_select) begin
      countdown_is_new_game <= 1'b1;  // any countdown reached from the menu is a new game
    end else if (in_resume_wait) begin
      countdown_is_new_game <= 1'b0;  // resume from pause -> keep score/progress
    end else if (in_playing || in_pause || in_finish) begin
      countdown_is_new_game <= 1'b0;
    end
  end

  logic round_rst;
  assign round_rst = in_select || (in_countdown && countdown_is_new_game);

  logic song_selected;
  logic fsm_start;

  assign song_selected =
    (menu_song_sel == 3'b001) ||
    (menu_song_sel == 3'b010) ||
    (menu_song_sel == 3'b100);

  assign fsm_start = p_start & song_selected;

  game_fsm #(
      .CLK_HZ(100_000_000)
  ) U_g_fsm (
      .clk          (clk),
      .rst_n        (rst_n),
      .p_start      (fsm_start),
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

  logic music_play_en;
  logic music_reset;
  logic play_en;
  logic play_rst;

  assign music_play_en = in_playing;
  assign play_en       = in_playing;

  assign music_reset   = round_rst;
  assign play_rst      = round_rst;

  // Music
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

  // Play screen / scoring
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

  // Finish
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


  logic [3:0] bcd_out[0:3];
  logic [3:0][3:0] ssd_num;

  Bin2BCD U_B2BCD (
      .bin_in(play_score),
      .bcd3  (bcd_out[3]),
      .bcd2  (bcd_out[2]),
      .bcd1  (bcd_out[1]),
      .bcd0  (bcd_out[0])
  );

  localparam logic [3:0] OFF = 4'd15;
  always_comb begin
    ssd_num[3] = OFF;
    ssd_num[2] = OFF;
    ssd_num[1] = OFF;
    ssd_num[0] = OFF;

    if (in_countdown || in_playing || in_pause || in_resume_wait || in_finish) begin
      ssd_num[3] = (bcd_out[3] == 4'd0) ? OFF : bcd_out[3];

      ssd_num[2] = ((bcd_out[3] == 4'd0) && (bcd_out[2] == 4'd0)) ? OFF : bcd_out[2];

      ssd_num[1] = ((bcd_out[3] == 4'd0) &&
                  (bcd_out[2] == 4'd0) &&
                  (bcd_out[1] == 4'd0)) ? OFF : bcd_out[1];

      ssd_num[0] = bcd_out[0];
    end
  end

  SSD #(
      .NUM(4),
      .BIT(4)
  ) U_SSD (
      .clk    (clk),
      .rst_n  (rst_n),
      .num    (ssd_num),
      .ssd_ctl(ssd_ctl),
      .ssd_out(ssd_out)
  );

  // Pause / resume / countdown overlay
  logic game_overlay_pixel;

  game_overlay U_game_overlay (
      .vga_x         (vga_x),
      .vga_y         (vga_y),
      .in_countdown  (in_countdown),
      .in_pause      (in_pause),
      .in_resume_wait(in_resume_wait),
      .countdown_num (countdown_num),
      .overlay_pixel (game_overlay_pixel)
  );

  // Debug LEDs：state
  ledbar U_ledbar (
      .clk                   (clk),
      .rst_n                 (rst_n),
      .song_sel              (menu_song_sel),
      .beat                  (music_beat),
      .in_select             (in_select),
      .new_game_countdown_rst(round_rst),
      .in_countdown          (in_countdown),
      .in_playing            (in_playing),
      .in_pause              (in_pause),
      .in_resume_wait        (in_resume_wait),
      .led_out               (leds)
  );

  // VGA mux
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

        // Overlay priority: countdown number / pause icon / resume play icon.
        if (game_overlay_pixel) begin
          vga_r = 4'hF;
          vga_g = 4'hF;
          vga_b = 4'hF;
        end
      end else if (in_finish) begin
        vga_r = finish_pixel ? 4'hF : 4'h0;
        vga_g = finish_pixel ? 4'hF : 4'h0;
        vga_b = finish_pixel ? 4'hF : 4'h0;
      end
    end
  end

endmodule

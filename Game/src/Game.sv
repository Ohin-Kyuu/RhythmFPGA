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

  logic [9:0] vga_x;
  logic [9:0] vga_y;
  logic video_valid;
  logic frame_tick;
  VGACtrl U_vg (
      .clk(clk),
      .rst_n(rst_n),
      // output 
      .vga_x(vga_x),
      .vga_y(vga_y),
      .hsync(hsync),
      .vsync(vsync),
      .valid(video_valid),
      .frame_tick(frame_tick)
  );

  // Button
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

  logic db_start;
  logic db_vol;
  logic p_up;
  logic p_down;
  logic p_start;
  logic p_vol;

  assign db_start = db_btn[0];
  assign db_vol   = db_btn[2];
  assign p_start  = p_btn[0];
  assign p_vol    = p_btn[2];

  assign p_up     = p_btn[1];
  assign p_down   = p_btn[3];


  // Keyboard
  logic p_space;
  logic [3:0] p_key;
  KeyPulse Ukp (
      .clk(clk),
      .rst_n(rst_n),
      .PS2_CLK(PS2_CLK),
      .PS2_DATA(PS2_DATA),
      // output
      .p_space(p_space),
      .p_key(p_key)  // D, F, J, K pulse
  );

  // FSM state / control signals
  logic [2:0] state_out;
  logic [1:0] countdown_num;
  logic       song_finish;

  logic       in_select;
  logic       in_countdown;
  logic       in_playing;
  logic       in_pause;
  logic       in_resume_wait;
  logic       in_finish;

  logic       music_play_en;
  logic       music_reset;

  localparam logic [2:0] SELECT = 3'd0;
  localparam logic [2:0] COUNTDOWN = 3'd1;
  localparam logic [2:0] PLAYING = 3'd2;
  localparam logic [2:0] PAUSE = 3'd3;
  localparam logic [2:0] RESUME_WAIT = 3'd4;
  localparam logic [2:0] FINISH = 3'd5;

  assign in_select      = (state_out == SELECT);
  assign in_countdown   = (state_out == COUNTDOWN);
  assign in_playing     = (state_out == PLAYING);
  assign in_pause       = (state_out == PAUSE);
  assign in_resume_wait = (state_out == RESUME_WAIT);
  assign in_finish      = (state_out == FINISH);

  assign music_play_en  = in_playing;
  assign music_reset    = in_select;

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

  logic       menu_pixel;
  logic       menu_start;
  logic [2:0] menu_song_sel;
  logic [3:0] menu_volume;
  logic       menu_vol_is_open;
  Menu Um (
      .clk  (clk),
      .rst_n(rst_n),

      .vga_x     (vga_x),
      .vga_y     (vga_y),
      .frame_tick(frame_tick),

      .sw      (sw),
      .db_start(db_start),
      .db_vol  (db_vol),
      .p_up    (p_up),
      .p_down  (p_down),

      .start      (menu_start),
      .song_sel   (menu_song_sel),
      .volume     (menu_volume),
      .vol_is_open(menu_vol_is_open),
      .ui_pixel   (menu_pixel)
  );


  // Play Upy ();

  Music Ums (
      .clk          (clk),
      .rst_n        (rst_n),
      .song_sel     (menu_song_sel),
      .volume       (menu_volume),
      .music_playing(music_play_en),
      .music_reset  (music_reset),
      .song_finish  (song_finish),
      .mclk         (mclk),
      .lrck         (lrck),
      .sck          (sck),
      .sdin         (sdin)
  );


  // Finish Uf ();

  always_comb begin
    if (!video_valid) begin
      vga_r = 4'h0;
      vga_g = 4'h0;
      vga_b = 4'h0;
    end else begin
      vga_r = 4'h0;
      vga_g = 4'h0;
      vga_b = 4'h0;

      if (in_select) begin
        vga_r = menu_pixel ? 4'hF : 4'h0;
        vga_g = menu_pixel ? 4'hF : 4'h0;
        vga_b = menu_pixel ? 4'hF : 4'h0;
      end else if (in_countdown) begin
        vga_r = 4'hF;
        vga_g = 4'hF;
        vga_b = 4'h0;
      end else if (in_playing) begin
        vga_r = 4'h0;
        vga_g = 4'hF;
        vga_b = 4'h0;
      end else if (in_pause) begin
        vga_r = 4'hF;
        vga_g = 4'h0;
        vga_b = 4'h0;
      end else if (in_finish) begin
        vga_r = 4'h0;
        vga_g = 4'h0;
        vga_b = 4'hF;
      end
    end
  end

  assign leds = {1'b0, state_out};
endmodule

module Menu (
    input logic clk,
    input logic rst_n,
    input logic [2:0] sw,
    input logic [3:0] btn,

    output logic [3:0] vga_r,
    output logic [3:0] vga_g,
    output logic [3:0] vga_b,
    output logic       hsync,
    output logic       vsync,
    output logic [3:0] leds
);

  logic clk_25M;
  freqdiv #(
      .BIT(9)
  ) Ufd (
      .clk(clk),
      .rst_n(rst_n),
      // output
      .clk_25(clk_25M),
      .clk_25d4(),
      .clk_25d128(),
      .cnt()
  );

  logic frame_tick;
  vga_tick U_vga_tick (
      .clk       (clk_25M),
      .rst_n     (rst_n),
      .vga_valid (video_valid),
      .vga_x     (vga_x),
      .vga_y     (vga_y),
      // output 
      .frame_tick(frame_tick)
  );

  logic [9:0] vga_x;
  logic [9:0] vga_y;
  logic       video_valid;

  vga U_vga_ctrl (
      .pclk (clk_25M),
      .reset(~rst_n),
      .hsync(hsync),
      .vsync(vsync),
      .valid(video_valid),
      .h_cnt(vga_x),
      .v_cnt(vga_y)
  );

  logic clk_100;
  clk_IC U_clk_100 (
      .clk    (clk),
      .rst_n  (rst_n),
      .clk_100(clk_100)
  );

  logic [3:0] db_btn;
  debAll #(
      .NUM(4)
  ) U_db (
      .clk   (clk_100),
      .rst_n (rst_n),
      .in    (btn),
      .db_out(db_btn)
  );

  logic [3:0] p_btn;
  pulAll #(
      .NUM(4)
  ) U_pg (
      .clk  (clk_100),
      .rst_n(rst_n),
      .in   (db_btn),
      .p_out(p_btn)
  );

  logic db_start;
  logic db_vol;
  assign db_start = db_btn[0];
  assign db_vol   = db_btn[2];

  logic p_up;
  logic p_down;
  assign p_up   = p_btn[1];
  assign p_down = p_btn[3];

  logic       ui_pixel;
  logic [3:0] current_vol;
  logic       vol_is_open;

  volctrl U_vc (
      .clk   (clk_100),
      .rst_n (rst_n),
      .up    (p_up & vol_is_open),
      .down  (p_down & vol_is_open),
      .volume(current_vol)
  );

  assign leds = current_vol;

  menuUI U_Menu_UI (
      .clk        (clk_25M),
      .rst_n      (rst_n),
      .vga_x      (vga_x),
      .vga_y      (vga_y),
      .frame_tick (frame_tick),
      .btn_start  (db_start),
      .btn_vol    (db_vol),
      .sw         (sw),
      .current_vol(current_vol),
      .vol_is_open(vol_is_open),
      .ui_pixel   (ui_pixel)
  );

  always_comb begin
    if (video_valid) begin
      vga_r = ui_pixel ? 4'hF : 4'h0;
      vga_g = ui_pixel ? 4'hF : 4'h0;
      vga_b = ui_pixel ? 4'hF : 4'h0;
    end else begin
      vga_r = 4'h0;
      vga_g = 4'h0;
      vga_b = 4'h0;
    end
  end

endmodule

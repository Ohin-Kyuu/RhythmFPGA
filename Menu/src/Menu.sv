module Menu (
    input logic clk,
    input logic rst_n,

    input logic [9:0] vga_x,
    input logic [9:0] vga_y,
    input logic       frame_tick,

    input logic [2:0] sw,
    input logic       db_start,
    input logic       db_vol,
    input logic       p_up,
    input logic       p_down,

    output logic       start,
    output logic [2:0] song_sel,
    output logic [3:0] volume,
    output logic       vol_is_open,
    output logic       ui_pixel
);

  assign start    = db_start;
  assign song_sel = sw;

  volctrl U_vc (
      .clk   (clk),
      .rst_n (rst_n),
      .up    (p_up & vol_is_open),
      .down  (p_down & vol_is_open),
      .volume(volume)
  );

  menuUI U_Menu_UI (
      .clk        (clk),
      .rst_n      (rst_n),
      .vga_x      (vga_x),
      .vga_y      (vga_y),
      .frame_tick (frame_tick),
      .btn_start  (db_start),
      .btn_vol    (db_vol),
      .sw         (sw),
      .current_vol(volume),
      .vol_is_open(vol_is_open),
      .ui_pixel   (ui_pixel)
  );

endmodule

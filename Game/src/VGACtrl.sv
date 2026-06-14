module VGACtrl (
    input logic clk,
    input logic rst_n,

    output logic [9:0] vga_x,
    output logic [9:0] vga_y,
    output logic hsync,
    output logic vsync,
    output logic valid,
    output logic frame_tick
);

  logic clk_25M;
  freqdiv #(
      .BIT(9)
  ) Ufd (
      .clk(clk),
      .rst_n(rst_n),
      .clk_25(clk_25M),
      .clk_25d4(),
      .clk_25d128(),
      .cnt()
  );

  vga U_vga_ctrl (
      .pclk (clk_25M),
      .reset(~rst_n),
      // output 
      .hsync(hsync),
      .vsync(vsync),
      .valid(valid),
      .h_cnt(vga_x),
      .v_cnt(vga_y)
  );

  vga_tick U_vga_tick (
      .clk(clk_25M),
      .rst_n(rst_n),
      .vga_valid(valid),
      .vga_x(vga_x),
      .vga_y(vga_y),
      // output 
      .frame_tick(frame_tick)
  );

endmodule

module speakCtrl (
    input logic clk,
    input logic rst_n,
    input logic [15:0] audio_l,
    input logic [15:0] audio_r,
    output logic mclk,
    output logic lrck,
    output logic sck,
    output logic sdin
);

  logic [8:0] cnt;
  logic load_l, load_r;
  // assign sck = 1'b1;  // use internal clock mode

  freqdiv #(
      .BIT(9)
  ) Ufd (
      .clk(clk),
      .rst_n(rst_n),
      .clk_25(mclk),
      .clk_25d4(sck),
      .clk_25d128(lrck),
      .cnt(cnt)
  );

  assign load_l = (cnt == 9'b1_1111_1111);
  assign load_r = (cnt == 9'b0_1111_1111);

  shiftreg Usr (
      .clk(clk),
      .rst_n(rst_n),
      .load_l(load_l),
      .load_r(load_r),
      .en_shift(cnt[3:0] == 4'b1111),  // sync with sck
      .audio_l(audio_l),
      .audio_r(audio_r),
      .sdin(sdin)
  );

endmodule

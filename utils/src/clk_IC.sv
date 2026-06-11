module clk_IC (
    input  logic clk,
    input  logic rst_n,
    output logic clk_100
);

  clkgen #(
      .BIT(19),
      .CNT_MAX(500_000)
  ) Uclk100 (
      .clk(clk),
      .rst_n(rst_n),
      .clk_out(clk_100)
  );

endmodule

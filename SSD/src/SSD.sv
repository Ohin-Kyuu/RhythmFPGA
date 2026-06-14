module SSD #(
    parameter NUM = 4,
    parameter BIT = 5
) (
    input logic clk,
    input logic rst_n,
    input logic [NUM-1:0][BIT-1:0] num,
    output logic [3:0] ssd_ctl,
    output logic [7:0] ssd_out
);

  logic [1:0] clk_scan;
  logic [BIT-1:0] ssd_in;

  ssd_freqdiv U_fd (
      // input
      .clk(clk),
      .rst_n(rst_n),
      // output
      .clk_ctl(clk_scan)
  );

  ssd_scan #(
      .NUM(NUM),
      .BIT(BIT)
  ) U_sc (
      // input
      .clk_scan(clk_scan),
      .in(num),
      // output
      .ssd_in(ssd_in),
      .ssd_ctl(ssd_ctl)
  );

  ssd_display #(
      .BIT(BIT)
  ) U_dis (
      .bin(ssd_in),
      .ssd_out(ssd_out)
  );

endmodule

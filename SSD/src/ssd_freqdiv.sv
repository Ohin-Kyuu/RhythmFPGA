`define BIT 27

module ssd_freqdiv (
    input logic clk,
    input logic rst_n,
    // output logic clk_out,
    output logic [1:0] clk_ctl
);

  logic clk_out;
  // logic [1:0] clk_ctl;
  logic [14:0] cnt_l;
  logic [8:0] cnt_h;
  logic [`BIT-1:0] cnt_tmp;

  always_comb begin
    cnt_tmp = {clk_out, cnt_h, clk_ctl, cnt_l} + 1'b1;
  end

  always_ff @(posedge clk, negedge rst_n) begin
    if (~rst_n) begin
      {clk_out, cnt_h, clk_ctl, cnt_l} <= `BIT'd0;
    end else begin
      {clk_out, cnt_h, clk_ctl, cnt_l} <= cnt_tmp;
    end
  end

endmodule

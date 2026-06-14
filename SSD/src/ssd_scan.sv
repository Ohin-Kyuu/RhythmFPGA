`define SCAN_CTRL_BIT 2

module ssd_scan #(
    parameter BIT = 4,
    parameter NUM = 4
) (
    input logic [`SCAN_CTRL_BIT-1:0] clk_scan,
    input logic [NUM-1:0][BIT-1:0] in,
    output logic [BIT-1:0] ssd_in,
    output logic [NUM-1:0] ssd_ctl
);

  always_comb begin
    ssd_in  = in[clk_scan];
    ssd_ctl = ~(NUM'(1'b1) << clk_scan);
  end

endmodule

module freqdiv #(
    parameter BIT = 9
) (
    input logic clk,
    input logic rst_n,
    output logic clk_25,     // 25 MHz
    output logic clk_25d4,   // 25 MHz /4 
    output logic clk_25d128,  // 25 MHz /128
    output logic [BIT-1:0] cnt
);

  logic [BIT-1:0] cnt_n;

  assign clk_25 = cnt[1];
  assign clk_25d4 = cnt[3];
  assign clk_25d128 = cnt[8];

  always_comb begin
    cnt_n = cnt + 1'b1;
  end

  always_ff @(posedge clk, negedge rst_n) begin
    if (~rst_n) cnt <= {BIT{1'b0}};
    else cnt <= cnt_n;
  end

endmodule

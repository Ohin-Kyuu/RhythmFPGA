module clkgen #(
    parameter BIT = 26,
    parameter CNT_MAX = 50_000_000
) (
    input  logic clk,
    input  logic rst_n,
    input  logic clr,
    output logic clk_out
);

  logic [BIT-1:0] cnt;
  logic [BIT-1:0] cnt_next;
  logic clk_out_next;

  always_comb begin
    if (cnt == CNT_MAX - 1) begin
      cnt_next = '0;
      clk_out_next = ~clk_out;
    end else begin
      cnt_next = cnt + 1'b1;
      clk_out_next = clk_out;
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
      cnt <= '0;
      clk_out <= 1'b0;
    end else if (clr) begin
      cnt <= '0;
      clk_out <= 1'b0;
    end else begin
      cnt <= cnt_next;
      clk_out <= clk_out_next;
    end
  end

endmodule

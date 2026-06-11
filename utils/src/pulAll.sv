module pulAll #(
    parameter NUM = 4
) (
    input logic clk,
    input logic rst_n,
    input logic [NUM-1:0] in,
    output logic [NUM-1:0] p_out
);

  genvar i;
  generate
    for (i = 0; i < NUM; i = i + 1) begin
      pulsegen Upg (
          .clk(clk),
          .rst_n(rst_n),
          .in(in[i]),
          .pulse(p_out[i])
      );
    end
  endgenerate

endmodule

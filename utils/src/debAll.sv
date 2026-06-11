module debAll #(
    parameter NUM = 4
) (
    input logic clk,
    input logic rst_n,
    input logic [NUM-1:0] in,
    output logic [NUM-1:0] db_out
);

  genvar i;
  generate
    for (i = 0; i < NUM; i = i + 1) begin
      debounce Udb (
          .clk(clk),
          .rst_n(rst_n),
          .in(in[i]),
          .out(db_out[i])
      );
    end
  endgenerate

endmodule

module debounce (
    input  logic clk,
    input  logic rst_n,
    input  logic in,
    output logic out
);

  logic [3:0] db_win;
  logic out_next;

  always_ff @(posedge clk, negedge rst_n) begin : shift_reg
    if (~rst_n) begin
      db_win <= 4'd0;
    end else begin
      db_win <= {db_win[2:0], in};
    end
  end

  assign out_next = &db_win;  // db_win[] Bitwise AND

  always_ff @(posedge clk, negedge rst_n) begin : out_reg
    if (~rst_n) begin
      out <= 1'b0;
    end else begin
      out <= out_next;
    end
  end

endmodule

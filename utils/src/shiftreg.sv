module shiftreg (
    input logic clk,
    input logic rst_n,
    input logic en_shift,
    input logic load_l,
    input logic load_r,
    input logic [15:0] audio_l,
    input logic [15:0] audio_r,
    output logic sdin
);

  logic [15:0] q;
  logic sdin_n;

  assign sdin_n = q[15];

  always_ff @(posedge clk, negedge rst_n) begin
    if (~rst_n) begin
      q    <= 16'd0;
      sdin <= 1'b0;
    end else begin
      if (en_shift) begin
        sdin <= sdin_n;
      end

      if (load_l) begin
        q <= audio_l;
      end else if (load_r) begin
        q <= audio_r;
      end else if (en_shift) begin
        q <= {q[14:0], 1'b0};
      end
    end
  end
endmodule

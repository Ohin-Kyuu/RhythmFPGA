module volctrl (
    input logic clk,
    input logic rst_n,
    input logic up,
    input logic down,
    output logic [3:0] volume
);

  logic [3:0] volume_n;

  always_comb begin
    if (up && (volume != 4'd15)) begin
      volume_n = volume + 4'd1;
    end else if (down && (volume != 4'd0)) begin
      volume_n = volume + 4'hF;
    end else begin
      volume_n = volume;
    end
  end

  always_ff @(posedge clk, negedge rst_n) begin
    if (~rst_n) volume <= 4'd8;
    else volume <= volume_n;
  end

endmodule

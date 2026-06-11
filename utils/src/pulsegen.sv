module pulsegen (
    input  logic clk,
    input  logic rst_n,
    input  logic in,
    output logic pulse
);

  logic in_delay;
  logic pulse_next;

  always_ff @(posedge clk, negedge rst_n) begin
    if (~rst_n) begin
      in_delay <= 1'b0;
    end else begin
      in_delay <= in;
    end
  end

  assign pulse_next = in & (~in_delay);

  always_ff @(posedge clk, negedge rst_n) begin
    if (~rst_n) begin
      pulse <= 1'b0;
    end else begin
      pulse <= pulse_next;
    end
  end

endmodule

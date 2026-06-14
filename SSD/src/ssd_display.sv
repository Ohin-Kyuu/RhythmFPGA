`include "ssd_code.svh"

module ssd_display #(
    parameter int BIT = 4
) (
    input  logic [BIT-1:0] bin,
    output logic [    7:0] ssd_out
);

  import ssd_code::*;

  always_comb begin
    automatic int idx = int'(bin);
    ssd_out = (idx < NUM) ? 8'(LUT[idx]) : 8'(OFF);
  end

endmodule

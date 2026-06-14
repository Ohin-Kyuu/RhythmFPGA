module Bin2BCD (
    input  logic [15:0] bin_in,
    output logic [ 3:0] bcd3,
    output logic [ 3:0] bcd2,
    output logic [ 3:0] bcd1,
    output logic [ 3:0] bcd0
);

  integer i;

  logic [15:0] bin_limited;
  logic [31:0] shift_reg;

  always_comb begin
    if (bin_in > 16'd9999) bin_limited = 16'd9999;
    else bin_limited = bin_in;

    shift_reg = {16'd0, bin_limited};

    for (i = 0; i < 16; i = i + 1) begin
      if (shift_reg[19:16] >= 4'd5) shift_reg[19:16] = shift_reg[19:16] + 4'd3;

      if (shift_reg[23:20] >= 4'd5) shift_reg[23:20] = shift_reg[23:20] + 4'd3;

      if (shift_reg[27:24] >= 4'd5) shift_reg[27:24] = shift_reg[27:24] + 4'd3;

      if (shift_reg[31:28] >= 4'd5) shift_reg[31:28] = shift_reg[31:28] + 4'd3;

      shift_reg = shift_reg << 1;
    end

    bcd3 = shift_reg[31:28];
    bcd2 = shift_reg[27:24];
    bcd1 = shift_reg[23:20];
    bcd0 = shift_reg[19:16];
  end

endmodule

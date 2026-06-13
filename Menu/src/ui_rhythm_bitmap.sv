module ui_rhythm_bitmap #(
    parameter logic [9:0] RHYTHM_X = 10'd150,
    parameter logic [9:0] RHYTHM_Y = 10'd77
) (
    input logic [9:0] vga_x,
    input logic [9:0] vga_y,

    output logic active,
    output logic pixel
);

  localparam logic [9:0] RHYTHM_W = 10'd340;
  localparam logic [9:0] RHYTHM_H = 10'd78;

  logic [RHYTHM_W-1:0] rom_rhythm[0:RHYTHM_H-1];

  initial begin
    $readmemb("rhythm.mem", rom_rhythm);
  end

  function automatic logic in_rect(input logic [9:0] x, input logic [9:0] y, input logic [9:0] left,
                                   input logic [9:0] top, input logic [9:0] width,
                                   input logic [9:0] height);
    logic [10:0] right;
    logic [10:0] bottom;
    begin
      right  = {1'b0, left} + {1'b0, width};
      bottom = {1'b0, top} + {1'b0, height};

      return ({1'b0, x} >= {1'b0, left}) &&
             ({1'b0, x} <  right) &&
             ({1'b0, y} >= {1'b0, top}) &&
             ({1'b0, y} <  bottom);
    end
  endfunction

  logic [8:0] dx;
  logic [6:0] dy;
  logic [8:0] col;

  always_comb begin
    active = in_rect(vga_x, vga_y, RHYTHM_X, RHYTHM_Y, RHYTHM_W, RHYTHM_H);

    dx = vga_x[8:0] - RHYTHM_X[8:0];
    dy = vga_y[6:0] - RHYTHM_Y[6:0];
    col = 9'd339 - dx;

    pixel = 1'b0;

    if (active) begin
      pixel = rom_rhythm[dy][col];
    end
  end

endmodule

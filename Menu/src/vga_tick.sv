module vga_tick (
    input logic clk,
    input logic rst_n,

    input logic       vga_valid,
    input logic [9:0] vga_x,
    input logic [9:0] vga_y,

    output logic frame_tick
);

  logic at_origin;
  logic at_origin_d;

  assign at_origin  = vga_valid && (vga_x == 10'd0) && (vga_y == 10'd0);
  assign frame_tick = at_origin & ~at_origin_d;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      at_origin_d <= 1'b0;
    end else begin
      at_origin_d <= at_origin;
    end
  end

endmodule

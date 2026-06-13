module ui_button_bitmap #(
    parameter logic [9:0] BASE_X = 10'd0,
    parameter logic [9:0] BASE_Y = 10'd0,
    parameter logic [9:0] TOP_X  = 10'd0,
    parameter logic [9:0] TOP_Y  = 10'd0
) (
    input logic       visible,
    input logic       pressed,
    input logic [9:0] vga_x,
    input logic [9:0] vga_y,

    output logic active,
    output logic pixel
);

  localparam logic [9:0] BASE_W = 10'd138;
  localparam logic [9:0] BASE_H = 10'd24;
  localparam logic [9:0] TOP_W = 10'd136;
  localparam logic [9:0] TOP_H = 10'd22;

  logic [137:0] rom_btn_base[0:23];
  logic [135:0] rom_btn_top [0:21];

  initial begin
    $readmemb("btn_base.mem", rom_btn_base);
    $readmemb("btn_top.mem", rom_btn_top);
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

  logic [9:0] top_y;
  logic       in_base;
  logic       in_top;
  logic       base_bit;
  logic       top_bit;

  logic [7:0] base_dx;
  logic [7:0] top_dx;

  logic [4:0] base_row;
  logic [4:0] top_row;

  logic [7:0] base_col;
  logic [7:0] top_col;

  always_comb begin
    top_y = TOP_Y + (pressed ? 10'd3 : 10'd0);

    in_base = in_rect(vga_x, vga_y, BASE_X, BASE_Y, BASE_W, BASE_H);
    in_top = visible && in_rect(vga_x, vga_y, TOP_X, top_y, TOP_W, TOP_H);

    base_dx = vga_x[7:0] - BASE_X[7:0];
    top_dx = vga_x[7:0] - TOP_X[7:0];

    base_row = vga_y[4:0] - BASE_Y[4:0];
    top_row = vga_y[4:0] - top_y[4:0];

    base_col = 8'd137 - base_dx;
    top_col = 8'd135 - top_dx;

    base_bit = 1'b0;
    top_bit = 1'b0;

    if (in_base) begin
      base_bit = rom_btn_base[base_row][base_col];
    end

    if (in_top) begin
      top_bit = rom_btn_top[top_row][top_col];
    end

    active = in_base || in_top;
    pixel  = in_top ? top_bit : in_base ? base_bit : 1'b0;
  end

endmodule

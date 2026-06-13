module ui_volume_bar #(
    parameter int BAR_X      = 273,
    parameter int BAR_W      = 94,
    parameter int BAR_H      = 10,
    parameter int VOL_AREA_X = 15,
    parameter int VOL_SLOT_W = 4,
    parameter int VOL_SLOTS  = 16
) (
    input logic       visible,
    input logic [9:0] bar_y,
    input logic [9:0] vga_x,
    input logic [9:0] vga_y,
    input logic [3:0] current_vol,

    output logic active,
    output logic pixel
);

  localparam int VOL_AREA_W = VOL_SLOT_W * VOL_SLOTS;  // 64
  localparam int VOL_AREA_R = VOL_AREA_X + VOL_AREA_W;  // 79, exclusive

  logic [BAR_W-1:0] rom_sound_bar[0:BAR_H-1];

  initial begin
    $readmemb("sound_bar.mem", rom_sound_bar);
  end

  function automatic logic in_rect(input logic [9:0] x, input logic [9:0] y, input int left,
                                   input int top, input int width, input int height);
    return (x >= left) && (x < left + width) && (y >= top) && (y < top + height);
  endfunction

  logic [9:0] rel_x;
  logic [9:0] rel_y;
  logic [4:0] slot_idx;
  logic [4:0] visible_slots;
  logic       in_volume_area;
  logic       slot_is_visible;
  logic       rom_pixel;

  always_comb begin
    active          = 1'b0;
    pixel           = 1'b0;

    rel_x           = vga_x - BAR_X;
    rel_y           = vga_y - bar_y;

    visible_slots   = {1'b0, current_vol} + 5'd1;

    in_volume_area  = (rel_x >= VOL_AREA_X) && (rel_x < VOL_AREA_R);
    slot_idx        = (rel_x - VOL_AREA_X) >> 2;
    slot_is_visible = (!in_volume_area) || (slot_idx < visible_slots);

    if (visible && in_rect(vga_x, vga_y, BAR_X, bar_y, BAR_W, BAR_H)) begin
      active    = 1'b1;
      rom_pixel = rom_sound_bar[rel_y][BAR_W-1-rel_x];
      pixel     = slot_is_visible ? rom_pixel : 1'b0;
    end
  end

endmodule

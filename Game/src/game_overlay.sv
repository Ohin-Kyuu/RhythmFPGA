module game_overlay #(
    parameter logic [9:0] COUNT_X = 10'd315,
    parameter logic [9:0] COUNT_Y = 10'd170,
    parameter logic [9:0] ICON_X  = 10'd305,
    parameter logic [9:0] ICON_Y  = 10'd198
) (
    input  logic [9:0] vga_x,
    input  logic [9:0] vga_y,

    input  logic       in_countdown,
    input  logic       in_pause,
    input  logic       in_resume_wait,
    input  logic [1:0] countdown_num,

    output logic       overlay_pixel
);

  // ---------------------------------------------------------------------------
  // Number font: char_number.mem is 10 digits, each digit uses a 6-column cell.
  // Actual visible pixels are 5x7.  Scale = 2 => 10x14 pixels on screen.
  // ---------------------------------------------------------------------------
  localparam int NUM_CELL_W = 6;
  localparam int NUM_PIX_W  = 5;
  localparam int NUM_H      = 7;
  localparam int NUM_SCALE  = 2;

  logic [58:0] rom_number [0:NUM_H-1];

  // pause_button.mem / play_button.mem are 30 x 32 bitmaps.
  localparam int ICON_W = 30;
  localparam int ICON_H = 32;
  logic [ICON_W-1:0] rom_pause [0:ICON_H-1];
  logic [ICON_W-1:0] rom_play  [0:ICON_H-1];

  initial begin
    $readmemb("char_number.mem", rom_number);
    $readmemb("pause_button.mem", rom_pause);
    $readmemb("play_button.mem",  rom_play);
  end

  function automatic logic in_rect(
      input logic [9:0] x,
      input logic [9:0] y,
      input int left,
      input int top,
      input int width,
      input int height
  );
    return (x >= left) && (x < left + width) &&
           (y >= top)  && (y < top + height);
  endfunction

  function automatic logic number_pixel_at(
      input logic [3:0] digit,
      input logic [2:0] pixel_x,
      input logic [2:0] pixel_y
  );
    logic [6:0] offset;
    begin
      number_pixel_at = 1'b0;
      if (digit <= 4'd9 && pixel_x < NUM_PIX_W && pixel_y < NUM_H) begin
        offset = digit * 7'd6 + {4'd0, pixel_x};
        number_pixel_at = rom_number[pixel_y][58-offset];
      end
    end
  endfunction

  logic count_on;
  logic pause_on;
  logic play_on;

  always_comb begin
    count_on = 1'b0;
    pause_on = 1'b0;
    play_on  = 1'b0;

    if (in_countdown && in_rect(vga_x, vga_y, COUNT_X, COUNT_Y,
                                NUM_PIX_W * NUM_SCALE, NUM_H * NUM_SCALE)) begin
      logic [3:0] digit;
      logic [9:0] rel_x;
      logic [9:0] rel_y;
      logic [2:0] pix_x;
      logic [2:0] pix_y;

      digit = {2'b00, countdown_num};
      rel_x = vga_x - COUNT_X;
      rel_y = vga_y - COUNT_Y;
      pix_x = rel_x / NUM_SCALE;
      pix_y = rel_y / NUM_SCALE;
      count_on = number_pixel_at(digit, pix_x, pix_y);
    end

    if (in_pause && in_rect(vga_x, vga_y, ICON_X, ICON_Y, ICON_W, ICON_H)) begin
      logic [5:0] dx;
      logic [5:0] dy;
      dx = vga_x - ICON_X;
      dy = vga_y - ICON_Y;
      pause_on = rom_pause[dy][ICON_W-1-dx];
    end

    if (in_resume_wait && in_rect(vga_x, vga_y, ICON_X, ICON_Y, ICON_W, ICON_H)) begin
      logic [5:0] dx;
      logic [5:0] dy;
      dx = vga_x - ICON_X;
      dy = vga_y - ICON_Y;
      play_on = rom_play[dy][ICON_W-1-dx];
    end

    overlay_pixel = count_on | pause_on | play_on;
  end

endmodule

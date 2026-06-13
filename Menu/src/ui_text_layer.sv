module ui_text_layer (
    input logic [9:0] vga_x,
    input logic [9:0] vga_y,
    input logic       valid_song,
    input logic [2:0] sw,
    input logic [7:0] scroll_offset,
    input logic [9:0] start_text_y,
    input logic [9:0] vol_text_y,

    output logic glyph_on,
    output logic glyph_black
);

  localparam int CHAR_W = 6;
  localparam int CHAR_PIX_W = 5;
  localparam int UPPER_CHAR_H = 7;
  localparam int LOWER_CHAR_H = 8;

  localparam int TEXT_AREA_X = 256;
  localparam int TEXT_AREA_Y = 226;
  localparam int TEXT_AREA_W = 129;
  localparam int TEXT_AREA_H = 8;

  localparam int SCROLL_TEXT_W = 144;
  localparam int SCROLL_GAP_W = 30;
  localparam int SCROLL_LOOP_W = SCROLL_TEXT_W + SCROLL_GAP_W;  // 174

  localparam logic [8*4-1:0] STR_SONG = "SONG";
  localparam logic [8*5-1:0] STR_START = "START";
  localparam logic [8*6-1:0] STR_VOL = "VOLUME";
  localparam logic [8*15-1:0] STR_CHOOSE = "Choosing Switch";

  localparam logic [8*24-1:0] STR_MARIO = "Super Mario Ground Theme";
  localparam logic [8*24-1:0] STR_ZELDA = "Zelda Overworld Theme   ";
  localparam logic [8*24-1:0] STR_POKE = "Pokemon Trainer Battle  ";

  logic [154:0] rom_char_lower[0:7];
  logic [154:0] rom_char_upper[0:6];

  initial begin
    $readmemb("char_lower.mem", rom_char_lower);
    $readmemb("char_upper.mem", rom_char_upper);
  end

  function automatic logic in_rect(input logic [9:0] x, input logic [9:0] y, input int left,
                                   input int top, input int width, input int height);
    return (x >= left) && (x < left + width) && (y >= top) && (y < top + height);
  endfunction

  function automatic logic font_pixel_at(input logic [7:0] ch, input logic [2:0] pixel_x,
                                         input logic [3:0] pixel_y);
    logic [9:0] offset;
    begin
      font_pixel_at = 1'b0;

      if (pixel_x < CHAR_PIX_W) begin
        if (ch >= "A" && ch <= "Z" && pixel_y < UPPER_CHAR_H) begin
          offset = (ch - "A") * CHAR_W;
          font_pixel_at = rom_char_upper[pixel_y[2:0]][154-(offset+pixel_x)];
        end else if (ch >= "a" && ch <= "z" && pixel_y < LOWER_CHAR_H) begin
          offset = (ch - "a") * CHAR_W;
          font_pixel_at = rom_char_lower[pixel_y[2:0]][154-(offset+pixel_x)];
        end
      end
    end
  endfunction

  function automatic logic [7:0] song_char_at(input logic [2:0] song_sw, input logic [4:0] idx);
    begin
      unique case (song_sw)
        3'b001:  song_char_at = STR_MARIO[(23-idx)*8+:8];
        3'b010:  song_char_at = STR_ZELDA[(23-idx)*8+:8];
        3'b100:  song_char_at = STR_POKE[(23-idx)*8+:8];
        default: song_char_at = " ";
      endcase
    end
  endfunction

  logic       render_text;
  logic [7:0] target_char;
  logic [2:0] char_pixel_x;
  logic [3:0] char_pixel_y;

  logic [9:0] text_x;
  logic [4:0] char_index;
  logic [9:0] area_x;
  logic [9:0] loop_x;

  always_comb begin
    render_text  = 1'b0;
    glyph_black  = 1'b0;
    target_char  = " ";
    char_pixel_x = '0;
    char_pixel_y = '0;

    text_x       = '0;
    char_index   = '0;
    area_x       = '0;
    loop_x       = '0;

    // SONG title
    if (in_rect(vga_x, vga_y, 309, 206, 4 * CHAR_W, UPPER_CHAR_H)) begin
      char_index   = (vga_x - 309) / CHAR_W;

      target_char  = STR_SONG[(3-char_index)*8+:8];
      char_pixel_x = (vga_x - 309) % CHAR_W;
      char_pixel_y = vga_y - 206;
      render_text  = 1'b1;
      glyph_black  = 1'b0;

      // START text
    end else if (in_rect(
            vga_x, vga_y, 306, valid_song ? start_text_y : 10'd270, 5 * CHAR_W, UPPER_CHAR_H
        )) begin
      char_index   = (vga_x - 306) / CHAR_W;

      target_char  = STR_START[(4-char_index)*8+:8];
      char_pixel_x = (vga_x - 306) % CHAR_W;
      char_pixel_y = vga_y - (valid_song ? start_text_y : 10'd270);
      render_text  = 1'b1;
      glyph_black  = valid_song;

      // VOLUME text
    end else if (in_rect(vga_x, vga_y, 303, vol_text_y, 6 * CHAR_W, UPPER_CHAR_H)) begin
      char_index   = (vga_x - 303) / CHAR_W;

      target_char  = STR_VOL[(5-char_index)*8+:8];
      char_pixel_x = (vga_x - 303) % CHAR_W;
      char_pixel_y = vga_y - vol_text_y;
      render_text  = 1'b1;
      glyph_black  = 1'b1;

      // Text area
    end else if (in_rect(vga_x, vga_y, TEXT_AREA_X, TEXT_AREA_Y, TEXT_AREA_W, TEXT_AREA_H)) begin

      // No song selected: show "Choosing Switch"
      if (!valid_song) begin
        if (in_rect(vga_x, vga_y, 276, TEXT_AREA_Y, 15 * CHAR_W, LOWER_CHAR_H)) begin
          char_index   = (vga_x - 276) / CHAR_W;

          target_char  = STR_CHOOSE[(14-char_index)*8+:8];
          char_pixel_x = (vga_x - 276) % CHAR_W;
          char_pixel_y = vga_y - TEXT_AREA_Y;
          render_text  = 1'b1;
          glyph_black  = 1'b0;
        end

        // Song selected: seamless marquee
      end else begin
        area_x = vga_x - TEXT_AREA_X;
        loop_x = area_x + {2'd0, scroll_offset};

        if (loop_x >= SCROLL_LOOP_W) begin
          loop_x = loop_x - SCROLL_LOOP_W;
        end

        if (loop_x < SCROLL_TEXT_W) begin
          text_x       = loop_x;
          char_index   = text_x / CHAR_W;

          target_char  = song_char_at(sw, char_index);
          char_pixel_x = text_x % CHAR_W;
          char_pixel_y = vga_y - TEXT_AREA_Y;
          render_text  = 1'b1;
          glyph_black  = 1'b0;
        end
      end
    end

    glyph_on = render_text && font_pixel_at(target_char, char_pixel_x, char_pixel_y);
  end

endmodule

module play_track_render #(
    parameter int ROW_PX      = 64,
    parameter int NOTE_H      = 28,
    parameter int RECEPTOR_C  = 326,
    parameter int LEN_MARIO   = 590,
    parameter int LEN_ZELDA   = 769,
    parameter int LEN_POKEMON = 2177
) (
    input logic [ 9:0] vga_x,
    input logic [ 9:0] vga_y,
    input logic [ 2:0] sel_song,
    input logic [11:0] beat_cnt,
    input logic [ 7:0] sub_acc_px,

    output logic       note_on,
    output logic [1:0] note_lane
);

  localparam int ROW_SHIFT = $clog2(ROW_PX);
  localparam int NMAX = 2200;
  logic [3:0] rom_mario[0:NMAX-1], rom_zelda[0:NMAX-1], rom_pokemon[0:NMAX-1];
  initial begin
    $readmemh("mario_key_track.mem", rom_mario);
    $readmemh("zelda_key_track.mem", rom_zelda);
    $readmemh("pokemon_key_track.mem", rom_pokemon);
  end

  logic [11:0] cur_len;
  always_comb begin
    unique case (sel_song)
      3'b001:  cur_len = LEN_MARIO[11:0];
      3'b010:  cur_len = LEN_ZELDA[11:0];
      3'b100:  cur_len = LEN_POKEMON[11:0];
      default: cur_len = LEN_MARIO[11:0];
    endcase
  end

  function automatic logic [3:0] rom_at(input logic [11:0] row);
    if (row >= cur_len) rom_at = 4'b0000;
    else begin
      unique case (sel_song)
        3'b001:  rom_at = rom_mario[row];
        3'b010:  rom_at = rom_zelda[row];
        3'b100:  rom_at = rom_pokemon[row];
        default: rom_at = 4'b0000;
      endcase
    end
  endfunction

  localparam int HALF_H = NOTE_H / 2;

  logic [17:0] scroll_y;
  assign scroll_y = ({6'd0, beat_cnt} << ROW_SHIFT) + {12'd0, sub_acc_px[5:0]};

  logic [1:0] px_lane;
  logic px_in_lane;
  always_comb begin
    px_in_lane = 0;
    px_lane = 2'd0;
    if (vga_x >= 10'd131 && vga_x <= 10'd224) begin
      px_lane = 2'd0;
      px_in_lane = 1;
    end else if (vga_x >= 10'd226 && vga_x <= 10'd319) begin
      px_lane = 2'd1;
      px_in_lane = 1;
    end else if (vga_x >= 10'd321 && vga_x <= 10'd414) begin
      px_lane = 2'd2;
      px_in_lane = 1;
    end else if (vga_x >= 10'd416 && vga_x <= 10'd509) begin
      px_lane = 2'd3;
      px_in_lane = 1;
    end
  end

  logic [17:0] num;
  logic [11:0] r_lo;
  logic [ROW_SHIFT-1:0] res;
  logic valid_num;
  logic [3:0] m_lo, m_hi;

  always_comb begin
    note_on   = 1'b0;
    note_lane = px_lane;
    valid_num = (scroll_y + RECEPTOR_C[17:0]) >= {8'd0, vga_y};
    num       = scroll_y + RECEPTOR_C[17:0] - {8'd0, vga_y};
    // ROW_PX = 64
    r_lo      = num[17:ROW_SHIFT];
    res       = num[ROW_SHIFT-1:0];

    m_lo      = rom_at(r_lo);
    m_hi      = rom_at(r_lo + 12'd1);

    if (px_in_lane && valid_num && (vga_y >= 10'd1) && (vga_y <= 10'd359)) begin
      if (m_lo[px_lane] && (res <= HALF_H[5:0])) note_on = 1'b1;
      if (m_hi[px_lane] && ((6'd63 - res) < HALF_H[5:0])) note_on = 1'b1;
      if (m_lo[px_lane] && m_hi[px_lane]) note_on = 1'b1;
    end
  end
endmodule

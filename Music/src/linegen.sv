module linegen #(
    parameter logic [11:0] LEN_MARIO   = 12'd590,
    parameter logic [11:0] LEN_ZELDA   = 12'd769,
    parameter logic [11:0] LEN_POKEMON = 12'd2177
) (
    input  logic        clk,
    input  logic        rst_n,
    input  logic [ 2:0] sel,
    input  logic        beat,
    input  logic        playing,
    output logic [65:0] line,
    output logic        finish
);

  // logic [65:0] mario_rom  [  0:LEN_MARIO-1];
  // logic [65:0] zelda_rom  [  0:LEN_ZELDA-1];
  // logic [65:0] pokemon_rom[0:LEN_POKEMON-1];

  logic [65:0] mario_rom  [0:4095];
  logic [65:0] zelda_rom  [0:4095];
  logic [65:0] pokemon_rom[0:4095];

  initial begin
    $readmemh("mario_rom.mem", mario_rom);
    $readmemh("zelda_rom.mem", zelda_rom);
    $readmemh("pokemon_rom.mem", pokemon_rom);
  end

  logic [11:0] max_len;
  logic [11:0] rom_addr;

  always_comb begin
    case (sel)
      3'b001:  max_len = LEN_MARIO;
      3'b010:  max_len = LEN_ZELDA;
      3'b100:  max_len = LEN_POKEMON;
      default: max_len = LEN_MARIO;
    endcase
  end

  assign finish = playing && beat && (rom_addr >= max_len - 12'd1);

  always_ff @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
      rom_addr <= 12'd0;
    end else if (finish) begin
      rom_addr <= 12'd0;
    end else if (playing && beat) begin
      rom_addr <= rom_addr + 12'd1;
    end
  end

  always_comb begin
    if (!playing) begin
      line = 66'd0;
    end else begin
      case (sel)
        3'b001:  line = mario_rom[rom_addr];
        3'b010:  line = zelda_rom[rom_addr];
        3'b100:  line = pokemon_rom[rom_addr];
        default: line = 66'd0;
      endcase
    end
  end

endmodule

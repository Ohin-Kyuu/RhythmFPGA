module beatGen (
    input logic clk,
    input logic rst_n,
    input logic [2:0] sel,
    output logic beat
);

  parameter BEAT_MAX_MARIO = 24'd14285700;
  parameter BEAT_MAX_ZELDA = 24'd10135125;
  parameter BEAT_MAX_POKEMON = 24'd8792475;

  logic clk_mario;
  logic clk_zelda;
  logic clk_pokemon;

  clkgen #(
      .BIT(24),
      .CNT_MAX(BEAT_MAX_MARIO / 2)
  ) U_clk_mario (
      .clk(clk),
      .rst_n(rst_n),
      .clk_out(clk_mario)
  );

  clkgen #(
      .BIT(24),
      .CNT_MAX(BEAT_MAX_ZELDA / 2)
  ) U_clk_zelda (
      .clk(clk),
      .rst_n(rst_n),
      .clk_out(clk_zelda)
  );

  clkgen #(
      .BIT(24),
      .CNT_MAX(BEAT_MAX_POKEMON / 2)
  ) U_clk_poke (
      .clk(clk),
      .rst_n(rst_n),
      .clk_out(clk_pokemon)
  );

  logic beat_clk;

  // Gengerate Beat(tick) from cur clk
  always_comb begin
    case (sel)
      3'b001:  beat_clk = clk_mario;
      3'b010:  beat_clk = clk_zelda;
      3'b100:  beat_clk = clk_pokemon;
      default: beat_clk = clk_mario;
    endcase
  end

  pulsegen U_pg_beat (
      .clk(clk),
      .rst_n(rst_n),
      .in(beat_clk),
      .pulse(beat)
  );

endmodule

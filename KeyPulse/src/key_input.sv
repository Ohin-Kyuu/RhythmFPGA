module key_input (
    input  logic         clk,
    input  logic         rst_n,
    input  logic [511:0] key_down,
    output logic         p_space,
    output logic [  3:0] p_key
);
  localparam int SC_D = 8'h23;
  localparam int SC_F = 8'h2B;
  localparam int SC_J = 8'h3B;
  localparam int SC_K = 8'h42;
  localparam int SC_SPACE = 8'h29;

  logic [3:0] key_now, key_prev;
  logic space_now, space_prev;

  assign key_now   = {key_down[SC_K], key_down[SC_J], key_down[SC_F], key_down[SC_D]};
  assign space_now = key_down[SC_SPACE];

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      key_prev   <= 4'b0000;
      space_prev <= 1'b0;
    end else begin
      key_prev   <= key_now;
      space_prev <= space_now;
    end
  end

  assign p_key   = key_now & ~key_prev;
  assign p_space = space_now & ~space_prev;
endmodule

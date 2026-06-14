module KeyPulse (
    input logic clk,
    input logic rst_n,
    inout wire PS2_CLK,
    inout wire PS2_DATA,
    output logic p_space,
    output logic [3:0] p_key
);

  logic [511:0] key_down;
  logic [  8:0] last_change;
  logic         key_valid;
  KeyboardDecoder U_kbd (
      .clk(clk),
      .rst(~rst_n),
      .PS2_DATA(PS2_DATA),
      .PS2_CLK(PS2_CLK),
      // output
      .key_down(key_down),
      .last_change(last_change),
      .key_valid(key_valid)
  );

  key_input U_key_input (
      .clk(clk),
      .rst_n(rst_n),
      .key_down(key_down),
      // output 
      .p_space(p_space),
      .p_key(p_key)
  );

endmodule

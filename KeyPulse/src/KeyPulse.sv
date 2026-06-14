module KeyPulse (
    input  logic clk,
    input  logic rst_n,
    inout  wire  PS2_CLK,
    inout  wire  PS2_DATA,

    output logic       p_space,
    output logic [3:0] p_key,     // one-pulse: D,F,J,K
    output logic [3:0] key_hold   // level:     D,F,J,K
);

  logic [511:0] key_down_all;
  logic [8:0]   last_change;
  logic         key_valid;

  KeyboardDecoder U_kbd (
      .key_down   (key_down_all),
      .last_change(last_change),
      .key_valid  (key_valid),
      .PS2_DATA   (PS2_DATA),
      .PS2_CLK    (PS2_CLK),
      .rst        (~rst_n),
      .clk        (clk)
  );

  logic space_hold;
  logic space_hold_d;
  logic [3:0] key_hold_d;

  always_comb begin
    key_hold[0] = key_down_all[8'h23]; // D
    key_hold[1] = key_down_all[8'h2B]; // F
    key_hold[2] = key_down_all[8'h3B]; // J
    key_hold[3] = key_down_all[8'h42]; // K
    space_hold  = key_down_all[8'h29]; // Space
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      key_hold_d   <= 4'b0000;
      space_hold_d <= 1'b0;
    end else begin
      key_hold_d   <= key_hold;
      space_hold_d <= space_hold;
    end
  end

  assign p_key   = key_hold & ~key_hold_d;
  assign p_space = space_hold & ~space_hold_d;

endmodule

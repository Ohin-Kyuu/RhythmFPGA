module ui_button_controller (
    input logic clk,
    input logic rst_n,
    input logic valid_song,
    input logic btn_start_level,
    input logic btn_vol_level,

    output logic start_pressed,
    output logic vol_pressed,
    output logic vol_toggle_pulse
);

  logic btn_vol_d;

  always_ff @(posedge clk, negedge rst_n) begin
    if (~rst_n) begin
      btn_vol_d <= 1'b0;
    end else begin
      btn_vol_d <= btn_vol_level;
    end
  end

  assign start_pressed    = valid_song & btn_start_level;
  assign vol_pressed      = btn_vol_level;
  assign vol_toggle_pulse = btn_vol_level & ~btn_vol_d;

endmodule

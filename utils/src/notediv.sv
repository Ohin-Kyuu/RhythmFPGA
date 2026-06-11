module notediv #(
    parameter BIT = 22
) (
    input logic clk,
    input logic rst_n,
    input logic clear,
    input logic [BIT-1:0] note_div,
    input logic [3:0] volume,
    output logic [15:0] audio_l,
    output logic [15:0] audio_r
);

  logic [BIT-1:0] cnt, cnt_n;
  logic bclk, bclk_n;
  logic signed [15:0] max_volume, cur_volume;

  assign max_volume = (bclk == 1'b0) ? 16'sh6000 : 16'shA000;
  assign cur_volume = (max_volume >>> (4'd15 - volume));
  assign audio_l = (volume == 4'd0 || note_div == '0) ? 16'sh0000 : cur_volume;
  assign audio_r = (volume == 4'd0 || note_div == '0) ? 16'sh0000 : cur_volume;

  always_comb begin
    if (note_div == '0) begin
      cnt_n  = '0;
      bclk_n = 1'b0;
    end else if (cnt == note_div - 1) begin
      cnt_n  = '0;
      bclk_n = ~bclk;
    end else begin
      cnt_n  = cnt + 1'b1;
      bclk_n = bclk;
    end

  end

  always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n) begin
      cnt  <= '0;
      bclk <= 1'b0;
    end else if (clear) begin
      cnt  <= '0;
      bclk <= 1'b0;
    end else begin
      cnt  <= cnt_n;
      bclk <= bclk_n;
    end
  end

endmodule

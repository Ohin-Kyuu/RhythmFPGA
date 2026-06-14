module trackMix (
    input logic clk,
    input logic rst_n,
    input logic playing,
    input logic [3:0] volume,
    input logic beat,
    input logic [65:0] line,
    output logic signed [15:0] mix_l,
    output logic signed [15:0] mix_r
);

  logic [21:0] track1, track2, track3;
  logic [21:0] track1_prev, track2_prev, track3_prev;
  logic clear1, clear2, clear3;

  assign {track1, track2, track3} = line;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      track1_prev <= 22'd0;
      track2_prev <= 22'd0;
      track3_prev <= 22'd0;
    end else if (playing && beat) begin
      track1_prev <= track1;
      track2_prev <= track2;
      track3_prev <= track3;
    end
  end

  assign clear1 = playing && beat && (track1 != track1_prev);
  assign clear2 = playing && beat && (track2 != track2_prev);
  assign clear3 = playing && beat && (track3 != track3_prev);

  logic signed [15:0] t1_l, t1_r;
  logic signed [15:0] t2_l, t2_r;
  logic signed [15:0] t3_l, t3_r;
  logic signed [17:0] sum_l, sum_r;

  notediv U_nd1 (
      .clk     (clk),
      .rst_n   (rst_n),
      .clear   (clear1),
      .note_div(track1),
      .volume  (volume),
      .audio_l (t1_l),
      .audio_r (t1_r)
  );

  notediv U_nd2 (
      .clk(clk),
      .rst_n(rst_n),
      .clear   (clear2),
      .note_div(track2),
      .volume(volume),
      .audio_l(t2_l),
      .audio_r(t2_r)
  );

  notediv U_nd3 (
      .clk(clk),
      .rst_n(rst_n),
      .clear   (clear3),
      .note_div(track3),
      .volume(volume),
      .audio_l(t3_l),
      .audio_r(t3_r)
  );

  assign sum_l = 18'(t1_l) + 18'(t2_l) + 18'(t3_l);
  assign sum_r = 18'(t1_r) + 18'(t2_r) + 18'(t3_r);

  // Volume Down when sum up
  assign mix_l = 16'(sum_l >>> 2);
  assign mix_r = 16'(sum_r >>> 2);

endmodule

module vga (
    input wire pclk,
    input wire reset,
    output wire hsync,
    output wire vsync,
    output wire valid,
    output wire [9:0] h_cnt,
    output wire [9:0] v_cnt
);

  reg [9:0] pixel_cnt;
  reg [9:0] line_cnt;
  reg hsync_i, vsync_i;

  wire hsync_default = 1'b1;
  wire vsync_default = 1'b1;

  wire [9:0] HD = 640;
  wire [9:0] HF = 16;
  wire [9:0] HS = 96;
  wire [9:0] HT = 800;
  wire [9:0] VD = 480;
  wire [9:0] VF = 10;
  wire [9:0] VS = 2;
  wire [9:0] VT = 525;

  // Set to 640x360 range
  wire [9:0] LOGICAL_H = 640;
  wire [9:0] LOGICAL_V = 360;
  wire [9:0] Y_OFFSET = (VD - LOGICAL_V) / 2;  // (480 - 360) / 2 = 60

  always @(posedge pclk) begin
    if (reset) pixel_cnt <= 0;
    else if (pixel_cnt < (HT - 1)) pixel_cnt <= pixel_cnt + 1;
    else pixel_cnt <= 0;
  end

  always @(posedge pclk) begin
    if (reset) hsync_i <= hsync_default;
    else if ((pixel_cnt >= (HD + HF - 1)) && (pixel_cnt < (HD + HF + HS - 1)))
      hsync_i <= ~hsync_default;
    else hsync_i <= hsync_default;
  end

  always @(posedge pclk) begin
    if (reset) line_cnt <= 0;
    else if (pixel_cnt == (HT - 1)) begin
      if (line_cnt < (VT - 1)) line_cnt <= line_cnt + 1;
      else line_cnt <= 0;
    end
  end

  always @(posedge pclk) begin
    if (reset) vsync_i <= vsync_default;
    else if ((line_cnt >= (VD + VF - 1)) && (line_cnt < (VD + VF + VS - 1)))
      vsync_i <= ~vsync_default;
    else vsync_i <= vsync_default;
  end

  assign hsync = hsync_i;
  assign vsync = vsync_i;

  assign valid = (pixel_cnt < HD) && (line_cnt >= Y_OFFSET) && (line_cnt < Y_OFFSET + LOGICAL_V);

  assign h_cnt = valid ? pixel_cnt : 10'd0;
  assign v_cnt = valid ? (line_cnt - Y_OFFSET) : 10'd0;

endmodule

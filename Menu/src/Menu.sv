module Menu (
    input logic clk,
    input logic rst_n,
    input logic [2:0] sw,
    input logic [3:0] btn,

    // VGA
    output logic [3:0] vga_r,
    output logic [3:0] vga_g,
    output logic [3:0] vga_b,
    output logic       hsync,
    output logic       vsync
);

  logic clk_25M;
  freqdiv #(
      .BIT(9)
  ) Ufd (
      .clk(clk),
      .rst_n(rst_n),
      .clk_25(clk_25M),
      .clk_25d4(),
      .clk_25d128(),
      .cnt()
  );

  logic [9:0] vga_x;
  logic [9:0] vga_y;
  logic       video_valid;
  vga U_vga_ctrl (
      .pclk (clk_25M),
      .reset(~rst_n),
      .hsync(hsync),
      .vsync(vsync),
      .valid(video_valid),
      .h_cnt(vga_x),
      .v_cnt(vga_y)
  );

  logic clk_100;
  clk_IC U_clk_100 (
      .clk    (clk),
      .rst_n  (rst_n),
      .clk_100(clk_100)
  );

  logic [3:0] db_btn;
  debAll #(
      .NUM(4)
  ) U_db (
      .clk   (clk_100),
      .rst_n (rst_n),
      .in    (btn),
      .db_out(db_btn)
  );

  logic [3:0] p_btn;
  pulAll #(
      .NUM(4)
  ) U_pg (
      .clk  (clk),
      .rst_n(rst_n),
      .in   (db_btn),
      .p_out(p_btn)
  );

  logic p_start;
  logic p_vol;
  logic p_up;
  logic p_down;
  assign {p_start, p_up, p_vol, p_down} = p_btn;

  // ==========================================
  // 4. 實例化 動態選單介面 (Menu_UI.sv)
  // ==========================================
  logic       ui_pixel;  // 介面輸出 (1:有圖案, 0:黑底)
  logic [3:0] current_vol;  // 目前音量 (準備未來餵給 Music.sv)
  logic       vol_is_open;  // 由 menuUI 輸出，告訴我們音量條是否已展開

  // 實體化 volctrl (使用 clk_100Hz)
  // 條件：只有在 vol_is_open 為 1 (展開) 時，按鍵訊號才會送進 volctrl
  volctrl U_vc (
      .clk   (clk_100),
      .rst_n (rst_n),
      .up    (p_up & vol_is_open),
      .down  (p_down & vol_is_open),
      .volume(current_vol)
  );

  menuUI U_Menu_UI (
      .clk        (clk),
      .rst_n      (rst_n),
      .vga_x      (vga_x),
      .vga_y      (vga_y),
      .btn_start  (p_start),
      .btn_vol    (p_vol),
      .sw         (sw),
      .current_vol(current_vol),
      .vol_is_open(vol_is_open),  // 輸出狀態給外面的 volctrl 用
      .ui_pixel   (ui_pixel)
  );

  always_comb begin
    if (video_valid) begin
      vga_r = ui_pixel ? 4'hF : 4'h0;
      vga_g = ui_pixel ? 4'hF : 4'h0;
      vga_b = ui_pixel ? 4'hF : 4'h0;
    end else begin
      vga_r = 4'h0;
      vga_g = 4'h0;
      vga_b = 4'h0;
    end
  end

endmodule

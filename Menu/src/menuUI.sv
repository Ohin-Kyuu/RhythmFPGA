module menuUI (
    input logic       clk,
    input logic       rst_n,
    input logic [9:0] vga_x,
    input logic [9:0] vga_y,

    input logic       btn_start,
    input logic       btn_vol,
    input logic [2:0] sw,

    input logic [3:0] current_vol,

    output logic vol_is_open,
    output logic ui_pixel
);

  // ==========================================
  // 1. 載入 ROM 與字串參數
  // ==========================================
  logic [137:0] rom_btn_base[0:23];
  initial $readmemb("btn_base.mem", rom_btn_base);

  logic [135:0] rom_btn_top[0:23];
  initial $readmemb("btn_top.mem", rom_btn_top);

  logic [93:0] rom_sound_bar[0:9];
  initial $readmemb("sound_bar.mem", rom_sound_bar);

  // 字庫 ROM (5x7 與 5x8 的字母表，字母間隔 1 pixel，每個字母佔寬 6 pixel)
  logic [154:0] rom_char_lower[0:7];
  initial $readmemb("char_lower.mem", rom_char_lower);

  logic [154:0] rom_char_upper[0:6];
  initial $readmemb("char_upper.mem", rom_char_upper);

  // 定義要顯示的字串 (自動轉為 Byte Array)
  localparam logic [8*4-1:0] STR_SONG = "SONG";  // 4 chars
  localparam logic [8*5-1:0] STR_START = "START";  // 5 chars
  localparam logic [8*6-1:0] STR_VOL = "VOLUME";  // 6 chars
  localparam logic [8*15-1:0] STR_CHOOSE = "Choosing Switch";  // 15 chars
  // 統一補齊空白到 24 字元，方便跑馬燈計算
  localparam logic [8*24-1:0] STR_MARIO = "Super Mario Ground Theme";
  localparam logic [8*24-1:0] STR_ZELDA = "Zelda Overworld Theme   ";
  localparam logic [8*24-1:0] STR_POKE = "Pokemon Trainer Battle  ";


  // ==========================================
  // 2. 狀態與數值控制器
  // ==========================================
  logic valid_song;
  assign valid_song = (sw == 3'b001) || (sw == 3'b010) || (sw == 3'b100);

  logic [21:0] scroll_timer;  // 加大 bit 數，以容納更大的延遲
  logic [ 7:0] scroll_offset;

  always_ff @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
      scroll_timer  <= 0;
      scroll_offset <= 0;
    end else if (valid_song) begin
      // 將 500_000 提高到 2_500_000 (速度慢 5 倍，可依喜好自行加減)
      if (scroll_timer == 22'd2_500_000) begin
        scroll_timer  <= 0;
        // 將 200 視為一個完整的捲動週期 (144 的字串長度 + 56 像素的空白間隔)
        scroll_offset <= (scroll_offset == 8'd199) ? 8'd0 : scroll_offset + 1;
      end else begin
        scroll_timer <= scroll_timer + 1;
      end
    end else begin
      scroll_offset <= 0;
    end
  end
  // 音量條動畫
  logic vol_menu_open;
  assign vol_is_open = vol_menu_open;

  always_ff @(posedge clk or negedge rst_n) begin
    if (~rst_n) vol_menu_open <= 1'b0;
    else if (btn_vol) vol_menu_open <= ~vol_menu_open;
  end

  logic [5:0] vol_slide_y;
  always_ff @(posedge clk or negedge rst_n) begin
    if (~rst_n) vol_slide_y <= 6'd0;
    else if (vga_x == 0 && vga_y == 0) begin
      if (vol_menu_open && vol_slide_y < 6'd30) vol_slide_y <= vol_slide_y + 1;
      else if (!vol_menu_open && vol_slide_y > 6'd0) vol_slide_y <= vol_slide_y - 1;
    end
  end

  logic start_pressed, vol_pressed;
  assign start_pressed = valid_song && btn_start;
  assign vol_pressed   = btn_vol;

  // ==========================================
  // 3. 幾何繪圖與字體渲染引擎
  // ==========================================
  // 基本 UI 變數
  logic [9:0] start_top_y, start_txt_y;
  logic [9:0] vol_top_y, vol_txt_y;
  logic [9:0] bar_base_y, allowed_max_x;
  logic       px_sound_bar_raw;

  // 字體渲染專用變數
  logic [9:0] text_x;
  logic [4:0] c_idx;
  logic [7:0] target_char;
  logic [2:0] char_pixel_x;
  logic [3:0] char_pixel_y;
  logic [9:0] font_offset;
  logic       render_text;end else begin
        // 跑馬燈 (加上 scroll_offset 向左捲，並從右邊無縫接軌)
        
        // 1. 先算出絕對偏移量
        shifted_x = (vga_x - 10'd256) + 10'(scroll_offset);
        
        // 2. 模擬 modulo 200 的效果 (當超過週期長度 200 時，強制減去 200 讓它歸零重算)
        // 這樣右邊的像素就會去讀取字串最開頭的字元！
        text_x = (shifted_x >= 10'd200) ? (shifted_x - 10'd200) : shifted_x;

        if (text_x < 10'd144) begin  // 24 字元 * 6 = 144 像素寬
          c_idx        = 5'(text_x / 6);
          char_pixel_x = 3'(text_x % 6);
          char_pixel_y = 4'(vga_y - 10'd226);
          render_text  = 1'b1;

          case (sw)
            3'b001:  target_char = STR_MARIO[(23-c_idx)*8+:8];
            3'b010:  target_char = STR_ZELDA[(23-c_idx)*8+:8];
            3'b100:  target_char = STR_POKE[(23-c_idx)*8+:8];
            default: target_char = 8'd32;
          endcase
        end
      end
  logic       is_black_text;
  logic       font_pixel;

  always_comb begin
    // 初始化所有變數 (消除 Latch)
    ui_pixel         = 1'b0;
    start_top_y      = 10'd0;
    start_txt_y      = 10'd0;
    vol_top_y        = 10'd0;
    vol_txt_y        = 10'd0;
    bar_base_y       = 10'd0;
    allowed_max_x    = 10'd0;
    px_sound_bar_raw = 1'b0;

    text_x           = 10'd0;
    c_idx            = 5'd0;
    target_char      = 8'd32;  // 預設為 Space (空白)
    char_pixel_x     = 3'd0;
    char_pixel_y     = 4'd0;
    font_offset      = 10'd0;
    render_text      = 1'b0;
    is_black_text    = 1'b0;
    font_pixel       = 1'b0;


    // --------------------------------------------------
    // 【底層圖形繪製】 (按鈕框、音量條、歌曲外框)
    // --------------------------------------------------
    // 1. 歌曲顯示方框
    if (vga_x >= 251 && vga_x <= 389 && vga_y >= 218 && vga_y <= 242) begin
      if (vga_x == 251 || vga_x == 389 || vga_y == 218 || vga_y == 242) ui_pixel = 1'b1;
    end
    // 2. START 按鈕底與頂
    if (valid_song) begin
      // 底層陰影 (Base) - 只畫白色的部分
      if (vga_x >= 251 && vga_x < 251 + 138 && vga_y >= 262 && vga_y < 262 + 24) begin
        if (rom_btn_base[5'(vga_y-10'd262)][8'(137-(vga_x-10'd251))]) ui_pixel = 1'b1;
      end

      // 頂層按鈕 (Top) - 直接賦值，用 0 蓋掉底下的白色陰影
      start_top_y = start_pressed ? 10'd262 : 10'd260;
      if (vga_x >= 252 && vga_x < 252 + 136 && vga_y >= start_top_y && vga_y < start_top_y + 24) begin
        ui_pixel = rom_btn_top[5'(vga_y-start_top_y)][8'(135-(vga_x-10'd252))];
      end
    end

    // --------------------------------------------------
    // [區塊 D] VOLUME 按鈕
    // --------------------------------------------------
    // 底層陰影 (Base)
    if (vga_x >= 251 && vga_x < 251 + 138 && vga_y >= 303 && vga_y < 303 + 24) begin
      if (rom_btn_base[5'(vga_y-10'd303)][8'(137-(vga_x-10'd251))]) ui_pixel = 1'b1;
    end

    // 頂層按鈕 (Top) - 直接賦值
    vol_top_y = vol_pressed ? 10'd303 : 10'd301;
    if (vga_x >= 252 && vga_x < 252 + 136 && vga_y >= vol_top_y && vga_y < vol_top_y + 24) begin
      ui_pixel = rom_btn_top[5'(vga_y-vol_top_y)][8'(135-(vga_x-10'd252))];
    end  // 4. 動態滑出音量條

    if (vol_slide_y > 0) begin
      bar_base_y = 10'd327 + 10'(vol_slide_y) - 10'd30;
      if (vga_x >= 273 && vga_x < 273 + 94 && vga_y >= bar_base_y && vga_y < bar_base_y + 10) begin
        px_sound_bar_raw = rom_sound_bar[4'(vga_y-bar_base_y)][7'(93-(vga_x-10'd273))];
        allowed_max_x = 10'd273 + 10'd7 + (10'(current_vol) * 10'd5);
        if (vga_x > allowed_max_x) ui_pixel = 1'b0;
        else ui_pixel = px_sound_bar_raw;
      end
    end

    // --------------------------------------------------
    // 【字體渲染器】 (攔截 vga 座標，抓取應顯示的字元)
    // --------------------------------------------------
    start_txt_y = start_pressed ? 10'd270 : 10'd268;
    vol_txt_y   = vol_pressed ? 10'd311 : 10'd309;

    // 1. SONG 標題
    if (vga_y >= 206 && vga_y < 206 + 7 && vga_x >= 309 && vga_x < 309 + 24) begin
      target_char  = STR_SONG[(3-((vga_x-10'd309)/6))*8+:8];
      char_pixel_x = 3'((vga_x - 10'd309) % 6);
      char_pixel_y = 4'(vga_y - 10'd206);
      render_text  = 1'b1;
    end  // 2. START 文字
    else if ((valid_song || vga_y >= 270) && vga_y >= (valid_song ? start_txt_y : 10'd270) && vga_y < (valid_song ? start_txt_y : 10'd270) + 7 && vga_x >= 306 && vga_x < 306 + 30) begin
      target_char   = STR_START[(4-((vga_x-10'd306)/6))*8+:8];
      char_pixel_x  = 3'((vga_x - 10'd306) % 6);
      char_pixel_y  = 4'(vga_y - (valid_song ? start_txt_y : 10'd270));
      render_text   = 1'b1;
      is_black_text = valid_song;  // 按鈕出現時變黑字
    end  // 3. VOLUME 文字
    else if (vga_y >= vol_txt_y && vga_y < vol_txt_y + 7 && vga_x >= 303 && vga_x < 303 + 36) begin
      target_char   = STR_VOL[(5-((vga_x-10'd303)/6))*8+:8];
      char_pixel_x  = 3'((vga_x - 10'd303) % 6);
      char_pixel_y  = 4'(vga_y - vol_txt_y);
      render_text   = 1'b1;
      is_black_text = 1'b1;
    end  // 4. 方框內文字 (Choosing Switch 或 跑馬燈)
    else if (vga_y >= 226 && vga_y < 226 + 8 && vga_x >= 256 && vga_x <= 384) begin
      if (!valid_song) begin
        // 固定顯示 Choosing Switch (15 字元寬 90)
        if (vga_x >= 276 && vga_x < 276 + 90) begin
          target_char  = STR_CHOOSE[(14-((vga_x-10'd276)/6))*8+:8];
          char_pixel_x = 3'((vga_x - 10'd276) % 6);
          char_pixel_y = 4'(vga_y - 10'd226);
          render_text  = 1'b1;
        end
      end else begin
        // 跑馬燈 (加上 scroll_offset 向左捲，並從右邊無縫接軌)

        // 1. 先算出絕對偏移量
        shifted_x = (vga_x - 10'd256) + 10'(scroll_offset);

        // 2. 模擬 modulo 200 的效果 (當超過週期長度 200 時，強制減去 200 讓它歸零重算)
        // 這樣右邊的像素就會去讀取字串最開頭的字元！
        text_x = (shifted_x >= 10'd200) ? (shifted_x - 10'd200) : shifted_x;

        if (text_x < 10'd144) begin  // 24 字元 * 6 = 144 像素寬
          c_idx        = 5'(text_x / 6);
          char_pixel_x = 3'(text_x % 6);
          char_pixel_y = 4'(vga_y - 10'd226);
          render_text  = 1'b1;

          case (sw)
            3'b001:  target_char = STR_MARIO[(23-c_idx)*8+:8];
            3'b010:  target_char = STR_ZELDA[(23-c_idx)*8+:8];
            3'b100:  target_char = STR_POKE[(23-c_idx)*8+:8];
            default: target_char = 8'd32;
          endcase
        end
      end
    end

    // --------------------------------------------------
    // 【字庫查表與輸出】
    // --------------------------------------------------
    if (render_text && char_pixel_x < 5) begin  // 每個字元實際寬 5，間隔 1
      if (target_char >= 8'h41 && target_char <= 8'h5A) begin
        // 查大寫表 'A'-'Z'
        font_offset = 10'((target_char - 8'h41) * 6);
        if (char_pixel_y < 7)
          font_pixel = rom_char_upper[3'(char_pixel_y)][8'(154-(font_offset+10'(char_pixel_x)))];
      end else if (target_char >= 8'h61 && target_char <= 8'h7A) begin
        // 查小寫表 'a'-'z'
        font_offset = 10'((target_char - 8'h61) * 6);
        if (char_pixel_y < 8)
          font_pixel = rom_char_lower[3'(char_pixel_y)][8'(154-(font_offset+10'(char_pixel_x)))];
      end
      // 若遇到空白字元 (8'd32)，font_pixel 會維持 0，達到透明效果
    end

    // 將字型覆蓋到畫面上
    if (render_text && font_pixel) begin
      ui_pixel = is_black_text ? 1'b0 : 1'b1;
    end

  end

endmodule

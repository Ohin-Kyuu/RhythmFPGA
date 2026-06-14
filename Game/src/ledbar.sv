module ledbar (
    input logic clk,
    input logic rst_n,

    input logic [2:0] song_sel,  // 選擇的歌曲
    input logic       beat,      // 音樂節拍

    input logic in_select,
    input logic new_game_countdown_rst,  // 遊戲重置準備倒數
    input logic in_countdown,
    input logic in_playing,
    input logic in_pause,
    input logic in_resume_wait,

    output logic [15:0] led_out
);

  logic [11:0] total_beats;
  logic [11:0] beats_per_led;
  logic [11:0] led_beat_acc;
  logic [15:0] led_reg;

  always_comb begin
    unique case (song_sel)
      3'b001:  total_beats = 12'd590;  // Mario
      3'b010:  total_beats = 12'd769;  // Zelda
      3'b100:  total_beats = 12'd2177;  // Pokemon
      default: total_beats = 12'd590;
    endcase
  end

  assign beats_per_led = total_beats >> 4;

  logic beat_d1, beat_d2, beat_p;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      beat_d1 <= 0;
      beat_d2 <= 0;
    end else begin
      beat_d1 <= beat;
      beat_d2 <= beat_d1;
    end
  end
  assign beat_p = beat_d1 & ~beat_d2;

  // 4. LED 狀態機與計數器
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      led_reg      <= 16'hFFFF;
      led_beat_acc <= '0;
    end else if (in_select || new_game_countdown_rst) begin
      // 回到選單或準備進入倒數時，重置為 16 顆全亮
      led_reg      <= 16'hFFFF;
      led_beat_acc <= '0;
    end else if (in_playing && beat_p) begin
      // 在遊戲進行中，每累積到達指定的拍數，就將 LED 右移一位 (熄滅一顆)
      if (led_beat_acc >= beats_per_led) begin
        led_beat_acc <= '0;
        led_reg      <= led_reg >> 1;
      end else begin
        led_beat_acc <= led_beat_acc + 1'b1;
      end
    end
  end

  always_comb begin
    if (in_playing || in_pause || in_resume_wait) begin
      led_out = led_reg;  // 遊戲中/暫停中 顯示剩餘進度
    end else if (in_countdown) begin
      led_out = 16'hFFFF;  // 倒數時保持全亮準備
    end else begin
      led_out = 16'h0000;  // 選單與結算畫面全暗
    end
  end

endmodule

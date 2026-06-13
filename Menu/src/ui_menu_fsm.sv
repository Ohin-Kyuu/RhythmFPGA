module ui_menu_fsm #(
    parameter int SCROLL_PERIOD_TICK = 1_500_000,
    parameter int SCROLL_PERIOD_PX   = 174,
    parameter int BAR_SLIDE          = 10
) (
    input logic clk,
    input logic rst_n,
    input logic valid_song,
    input logic vol_toggle_pulse,
    input logic frame_tick,

    output logic vol_is_open,
    output logic [5:0] vol_slide_y,
    output logic [7:0] scroll_offset
);

  logic [21:0] scroll_timer;
  localparam logic [21:0] SCROLL_PERIOD_TICK_22 = SCROLL_PERIOD_TICK[21:0];

  always_ff @(posedge clk, negedge rst_n) begin
    if (~rst_n) begin
      vol_is_open <= 1'b0;
    end else if (vol_toggle_pulse) begin
      vol_is_open <= ~vol_is_open;
    end
  end

  always_ff @(posedge clk, negedge rst_n) begin
    if (~rst_n) begin
      vol_slide_y <= '0;
    end else if (frame_tick) begin
      if (vol_is_open && vol_slide_y < BAR_SLIDE) begin
        vol_slide_y <= vol_slide_y + 1'b1;
      end else if (!vol_is_open && vol_slide_y > 0) begin
        vol_slide_y <= vol_slide_y - 1'b1;
      end
    end
  end

  always_ff @(posedge clk, negedge rst_n) begin
    if (~rst_n) begin
      scroll_timer  <= '0;
      scroll_offset <= '0;
    end else if (valid_song) begin
      if (scroll_timer == SCROLL_PERIOD_TICK_22) begin
        scroll_timer  <= '0;
        scroll_offset <= (scroll_offset == SCROLL_PERIOD_PX - 1) ? '0 : scroll_offset + 1'b1;
      end else begin
        scroll_timer <= scroll_timer + 1'b1;
      end
    end else begin
      scroll_timer  <= '0;
      scroll_offset <= '0;
    end
  end

endmodule

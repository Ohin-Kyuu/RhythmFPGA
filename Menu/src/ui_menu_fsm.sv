module ui_menu_fsm #(
    parameter int SCROLL_FRAME_DIV = 3,
    parameter int SCROLL_PERIOD_PX = 174,
    parameter int BAR_SLIDE        = 10
) (
    input logic clk,
    input logic rst_n,
    input logic valid_song,
    input logic vol_toggle_pulse,
    input logic frame_tick,

    output logic       vol_is_open,
    output logic [5:0] vol_slide_y,
    output logic [8:0] scroll_offset
);

  localparam logic [8:0] SCROLL_PERIOD_PX_9 = SCROLL_PERIOD_PX[8:0];

  logic [$clog2(SCROLL_FRAME_DIV)-1:0] scroll_frame_cnt;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      vol_is_open <= 1'b0;
    end else if (vol_toggle_pulse) begin
      vol_is_open <= ~vol_is_open;
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      vol_slide_y <= '0;
    end else if (frame_tick) begin
      if (vol_is_open && vol_slide_y < BAR_SLIDE[5:0]) begin
        vol_slide_y <= vol_slide_y + 6'd1;
      end else if (!vol_is_open && vol_slide_y > 6'd0) begin
        vol_slide_y <= vol_slide_y - 6'd1;
      end
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      scroll_frame_cnt <= '0;
      scroll_offset    <= '0;
    end else if (!valid_song) begin
      scroll_frame_cnt <= '0;
      scroll_offset    <= '0;
    end else if (frame_tick) begin
      if (scroll_frame_cnt == SCROLL_FRAME_DIV - 1) begin
        scroll_frame_cnt <= '0;

        if (scroll_offset == SCROLL_PERIOD_PX_9 - 9'd1) begin
          scroll_offset <= '0;
        end else begin
          scroll_offset <= scroll_offset + 9'd1;
        end

      end else begin
        scroll_frame_cnt <= scroll_frame_cnt + 1'b1;
      end
    end
  end

endmodule

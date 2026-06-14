module game_fsm #(
    parameter int FPS = 60
) (
    input logic clk,
    input logic rst_n,

    input logic frame_tick,

    input logic p_start,
    input logic p_space,
    input logic song_finish,

    output logic [2:0] state_out,
    output logic [1:0] countdown_num
);

  typedef enum logic [2:0] {
    SELECT    = 3'd0,
    COUNTDOWN = 3'd1,
    PLAYING   = 3'd2,
    PAUSE     = 3'd3,
    FINISH    = 3'd4
  } state_t;

  state_t state, next_state;

  localparam int FRAME_CNT_W = $clog2(FPS);
  localparam int FRAME_CNT_MAX = FPS - 1;
  localparam logic [FRAME_CNT_W-1:0] FRAME_CNT_MAX_W = FRAME_CNT_MAX[FRAME_CNT_W-1:0];

  logic [FRAME_CNT_W-1:0] frame_cnt;
  logic [1:0] countdown_cnt;
  logic countdown_done;

  assign countdown_done = frame_tick && (countdown_cnt == 2'd1) && (frame_cnt == FRAME_CNT_MAX_W);

  always_comb begin
    next_state = state;

    unique case (state)
      SELECT: begin
        if (p_start) begin
          next_state = COUNTDOWN;
        end
      end

      COUNTDOWN: begin
        if (countdown_done) begin
          next_state = PLAYING;
        end
      end

      PLAYING: begin
        if (song_finish) begin
          next_state = FINISH;
        end else if (p_space) begin
          next_state = PAUSE;
        end
      end

      PAUSE: begin
        if (p_space) begin
          next_state = COUNTDOWN;
        end
      end

      FINISH: begin
        if (p_start) begin
          next_state = SELECT;
        end
      end

      default: begin
        next_state = SELECT;
      end
    endcase
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= SELECT;
    end else begin
      state <= next_state;
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      countdown_cnt <= 2'd3;
      frame_cnt     <= '0;
    end else begin
      if (state != COUNTDOWN && next_state == COUNTDOWN) begin
        countdown_cnt <= 2'd3;
        frame_cnt     <= '0;
      end else if (state == COUNTDOWN && frame_tick) begin
        if (frame_cnt == FRAME_CNT_MAX_W) begin
          frame_cnt <= '0;

          if (countdown_cnt > 2'd1) begin
            countdown_cnt <= countdown_cnt - 2'd1;
          end
        end else begin
          frame_cnt <= frame_cnt + 1'b1;
        end
      end else if (state != COUNTDOWN) begin
        frame_cnt <= '0;
      end
    end
  end

  assign state_out     = state;
  assign countdown_num = countdown_cnt;

endmodule

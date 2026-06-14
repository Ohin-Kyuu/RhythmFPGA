module game_fsm #(
    parameter int CLK_HZ = 100_000_000
) (
    input logic clk,
    input logic rst_n,
    input logic p_start,
    input logic p_space,
    input logic song_finish,

    output logic [2:0] state_out,
    output logic [1:0] countdown_num
);

  typedef enum logic [2:0] {
    SELECT      = 3'd0,
    COUNTDOWN   = 3'd1,
    PLAYING     = 3'd2,
    PAUSE       = 3'd3,
    RESUME_WAIT = 3'd4,
    FINISH      = 3'd5
  } state_t;

  state_t state, next_state;

  // --------------------------------------------------------------------------
  // 1-second timer
  // --------------------------------------------------------------------------
  localparam int SEC_CNT_W = $clog2(CLK_HZ);
  localparam logic [SEC_CNT_W-1:0] SEC_MAX = CLK_HZ - 1;

  logic [SEC_CNT_W-1:0] sec_cnt;
  logic one_sec_tick;

  assign one_sec_tick = (sec_cnt >= SEC_MAX);

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      sec_cnt <= '0;
    end else begin
      if (state == COUNTDOWN || state == RESUME_WAIT) begin
        if (one_sec_tick) sec_cnt <= '0;
        else sec_cnt <= sec_cnt + 1'b1;
      end else begin
        sec_cnt <= '0;
      end
    end
  end

  // --------------------------------------------------------------------------
  // Next-state logic
  // --------------------------------------------------------------------------
  always_comb begin
    next_state = state;

    unique case (state)
      SELECT: begin
        if (p_start) next_state = COUNTDOWN;
      end

      COUNTDOWN: begin
        if (one_sec_tick && (countdown_cnt == 2'd1)) next_state = PLAYING;
      end

      PLAYING: begin
        if (song_finish) next_state = FINISH;
        else if (p_space) next_state = PAUSE;
      end

      PAUSE: begin
        if (p_space) next_state = RESUME_WAIT;
      end

      RESUME_WAIT: begin
        if (one_sec_tick) next_state = COUNTDOWN;
      end

      FINISH: begin
        if (p_start) next_state = SELECT;
      end

      default: begin
        next_state = SELECT;
      end
    endcase
  end

  // --------------------------------------------------------------------------
  // State register
  // --------------------------------------------------------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) state <= SELECT;
    else state <= next_state;
  end

  // --------------------------------------------------------------------------
  // Countdown number: 3 -> 2 -> 1
  // --------------------------------------------------------------------------
  logic [1:0] countdown_cnt;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      countdown_cnt <= 2'd3;
    end else begin
      if (state != COUNTDOWN && next_state == COUNTDOWN) begin
        countdown_cnt <= 2'd3;
      end else if (state == COUNTDOWN && one_sec_tick) begin
        if (countdown_cnt > 2'd1) countdown_cnt <= countdown_cnt - 2'd1;
      end
    end
  end

  assign state_out     = state;
  assign countdown_num = countdown_cnt;

endmodule

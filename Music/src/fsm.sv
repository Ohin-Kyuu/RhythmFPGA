module fsm (
    input logic clk,
    input logic rst_n,
    input logic p_play,
    input logic finish,

    output logic       playing,
    output logic       clear_n,
    output logic [1:0] state_out
);

  typedef enum logic [1:0] {
    SELECT = 2'b00,
    PLAY   = 2'b01,
    PAUSE  = 2'b10,
    FINISH = 2'b11
  } state_t;

  state_t state, next_state;

  always_comb begin
    next_state = state;

    unique case (state)
      SELECT: begin
        if (p_play) next_state = PLAY;
      end

      PLAY: begin
        if (finish) next_state = FINISH;
        else if (p_play) next_state = PAUSE;
      end

      PAUSE: begin
        if (p_play) next_state = PLAY;
      end

      FINISH: begin
        if (p_play) next_state = SELECT;
      end

      default: next_state = SELECT;
    endcase
  end

  always_ff @(posedge clk, negedge rst_n) begin
    if (~rst_n) state <= SELECT;
    else state <= next_state;
  end

  assign playing   = (state == PLAY);
  assign clear_n   = (state == PLAY) || (state == PAUSE);
  assign state_out = state;

endmodule

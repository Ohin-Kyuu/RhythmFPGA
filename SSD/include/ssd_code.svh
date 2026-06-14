`ifndef SSD_CODE
`define SSD_CODE

package ssd_code;

  // SSD decode 
  typedef enum logic [7:0] {
    SSD_0 = 8'b00000011,
    SSD_1 = 8'b10011111,
    SSD_2 = 8'b00100101,
    SSD_3 = 8'b00001101,
    SSD_4 = 8'b10011001,
    SSD_5 = 8'b01001001,
    SSD_6 = 8'b01000001,
    SSD_7 = 8'b00011111,
    SSD_8 = 8'b00000001,
    SSD_9 = 8'b00001001,
    SSD_A = 8'b00010001,
    SSD_B = 8'b11000001,
    SSD_C = 8'b01100011,
    SSD_D = 8'b10000101,
    SSD_E = 8'b01100001,
    SSD_F = 8'b01110001,
    SSD_G = 8'b01000011,
    SSD_S = 8'b11111101,
    SSD_M = 8'b10010011,
    OFF   = 8'b11111111
  } ssd_t;

  // LUT
  localparam int NUM = 16;
  localparam ssd_t LUT[0:NUM-1] = '{
      SSD_0,
      SSD_1,
      SSD_2,
      SSD_3,
      SSD_4,
      SSD_5,
      SSD_6,
      SSD_7,
      SSD_8,
      SSD_9,
      SSD_A,
      SSD_S,
      SSD_M,
      SSD_F,
      SSD_G,
      OFF
  };

endpackage

`endif

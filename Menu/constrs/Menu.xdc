# Clock
set_property -dict { PACKAGE_PIN W5 IOSTANDARD LVCMOS33 } [get_ports {clk}]

# RST Active Low
set_property -dict { PACKAGE_PIN V17 IOSTANDARD LVCMOS33 } [get_ports {rst_n}]

# LEDs
# set_property -dict { PACKAGE_PIN U16 IOSTANDARD LVCMOS33 } [get_ports {leds[0]}]
# set_property -dict { PACKAGE_PIN E19 IOSTANDARD LVCMOS33 } [get_ports {leds[1]}]
# set_property -dict { PACKAGE_PIN U19 IOSTANDARD LVCMOS33 } [get_ports {leds[2]}]
# set_property -dict { PACKAGE_PIN V19 IOSTANDARD LVCMOS33 } [get_ports {leds[3]}]

# Buttons 
set_property -dict { PACKAGE_PIN W19 IOSTANDARD LVCMOS33 } [get_ports {btn[0]}]
set_property -dict { PACKAGE_PIN T18 IOSTANDARD LVCMOS33 } [get_ports {btn[1]}]
set_property -dict { PACKAGE_PIN U18 IOSTANDARD LVCMOS33 } [get_ports {btn[2]}]
set_property -dict { PACKAGE_PIN U17 IOSTANDARD LVCMOS33 } [get_ports {btn[3]}]
# set_property -dict { PACKAGE_PIN T17 IOSTANDARD LVCMOS33 } [get_ports {but[4]}]

# Switch 
# set_property -dict { PACKAGE_PIN R2 IOSTANDARD LVCMOS33 } [get_ports {sw[14]}]
# set_property -dict { PACKAGE_PIN T1 IOSTANDARD LVCMOS33 } [get_ports {sw[13]}]
# set_property -dict { PACKAGE_PIN U1 IOSTANDARD LVCMOS33 } [get_ports {sw[12]}]
# set_property -dict { PACKAGE_PIN W2 IOSTANDARD LVCMOS33 } [get_ports {sw[11]}]
# set_property -dict { PACKAGE_PIN R3 IOSTANDARD LVCMOS33 } [get_ports {sw[10]}]
# set_property -dict { PACKAGE_PIN T2 IOSTANDARD LVCMOS33 } [get_ports {sw[9]}]
# set_property -dict { PACKAGE_PIN T3 IOSTANDARD LVCMOS33 } [get_ports {sw[8]}]
# set_property -dict { PACKAGE_PIN V2  IOSTANDARD LVCMOS33 } [get_ports {sw[7]}]
# set_property -dict { PACKAGE_PIN W13 IOSTANDARD LVCMOS33 } [get_ports {sw[6]}]
# set_property -dict { PACKAGE_PIN W14 IOSTANDARD LVCMOS33 } [get_ports {sw[5]}]
# set_property -dict { PACKAGE_PIN V15 IOSTANDARD LVCMOS33 } [get_ports {sw[4]}]
# set_property -dict { PACKAGE_PIN W15 IOSTANDARD LVCMOS33 } [get_ports {sw[3]}]
set_property -dict { PACKAGE_PIN W17 IOSTANDARD LVCMOS33 } [get_ports {sw[2]}]
set_property -dict { PACKAGE_PIN W16 IOSTANDARD LVCMOS33 } [get_ports {sw[1]}]
set_property -dict { PACKAGE_PIN V16 IOSTANDARD LVCMOS33 } [get_ports {sw[0]}]

# Pmod I2S 
# set_property PACKAGE_PIN A14 [get_ports {mclk}]
# set_property IOSTANDARD LVCMOS33 [get_ports {mclk}]
# set_property PACKAGE_PIN A16 [get_ports {lrck}]
# set_property IOSTANDARD LVCMOS33 [get_ports {lrck}]
# set_property PACKAGE_PIN B15 [get_ports {sck}]
# set_property IOSTANDARD LVCMOS33 [get_ports {sck}]
# set_property PACKAGE_PIN B16 [get_ports {sdin}]
# set_property IOSTANDARD LVCMOS33 [get_ports {sdin}]


# PS2
# set_property -dict { PACKAGE_PIN C17 IOSTANDARD LVCMOS33 } [get_ports {PS2_CLK}]
# set_property -dict { PACKAGE_PIN B17 IOSTANDARD LVCMOS33 } [get_ports {PS2_DATA}]


# VGA
set_property PACKAGE_PIN G19 [get_ports {vga_r[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vga_r[0]}]
set_property PACKAGE_PIN H19 [get_ports {vga_r[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vga_r[1]}]
set_property PACKAGE_PIN J19 [get_ports {vga_r[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vga_r[2]}]
set_property PACKAGE_PIN N19 [get_ports {vga_r[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vga_r[3]}]
set_property PACKAGE_PIN N18 [get_ports {vga_b[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vga_b[0]}]
set_property PACKAGE_PIN L18 [get_ports {vga_b[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vga_b[1]}]
set_property PACKAGE_PIN K18 [get_ports {vga_b[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vga_b[2]}]
set_property PACKAGE_PIN J18 [get_ports {vga_b[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vga_b[3]}]
set_property PACKAGE_PIN J17 [get_ports {vga_g[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vga_g[0]}]
set_property PACKAGE_PIN H17 [get_ports {vga_g[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vga_g[1]}]
set_property PACKAGE_PIN G17 [get_ports {vga_g[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vga_g[2]}]
set_property PACKAGE_PIN D17 [get_ports {vga_g[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vga_g[3]}]
set_property PACKAGE_PIN P19 [get_ports hsync]
set_property IOSTANDARD LVCMOS33 [get_ports hsync]
set_property PACKAGE_PIN R19 [get_ports vsync]
set_property IOSTANDARD LVCMOS33 [get_ports vsync]


# SSD
# 4 SSD anode control
# set_property PACKAGE_PIN W4 [get_ports {ssd_ctl[3]}]
# set_property PACKAGE_PIN V4 [get_ports {ssd_ctl[2]}]
# set_property PACKAGE_PIN U4 [get_ports {ssd_ctl[1]}]
# set_property PACKAGE_PIN U2 [get_ports {ssd_ctl[0]}]
# set_property IOSTANDARD LVCMOS33 [get_ports {ssd_ctl[3]}]
# set_property IOSTANDARD LVCMOS33 [get_ports {ssd_ctl[2]}]
# set_property IOSTANDARD LVCMOS33 [get_ports {ssd_ctl[1]}]
# set_property IOSTANDARD LVCMOS33 [get_ports {ssd_ctl[0]}]
#
# # SSD control signal
# set_property PACKAGE_PIN W7 [get_ports {ssd_out[7]}]
# set_property PACKAGE_PIN W6 [get_ports {ssd_out[6]}]
# set_property PACKAGE_PIN U8 [get_ports {ssd_out[5]}]
# set_property PACKAGE_PIN V8 [get_ports {ssd_out[4]}]
# set_property PACKAGE_PIN U5 [get_ports {ssd_out[3]}]
# set_property PACKAGE_PIN V5 [get_ports {ssd_out[2]}]
# set_property PACKAGE_PIN U7 [get_ports {ssd_out[1]}]
# set_property PACKAGE_PIN V7 [get_ports {ssd_out[0]}]
# set_property IOSTANDARD LVCMOS33 [get_ports {ssd_out[7]}]
# set_property IOSTANDARD LVCMOS33 [get_ports {ssd_out[6]}]
# set_property IOSTANDARD LVCMOS33 [get_ports {ssd_out[5]}]
# set_property IOSTANDARD LVCMOS33 [get_ports {ssd_out[4]}]
# set_property IOSTANDARD LVCMOS33 [get_ports {ssd_out[3]}]
# set_property IOSTANDARD LVCMOS33 [get_ports {ssd_out[2]}]
# set_property IOSTANDARD LVCMOS33 [get_ports {ssd_out[1]}]
# set_property IOSTANDARD LVCMOS33 [get_ports {ssd_out[0]}]


set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
set_property CONFIG_MODE SPIx4 [current_design]

set_property BITSTREAM.CONFIG.CONFIGRATE 33 [current_design]

set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]

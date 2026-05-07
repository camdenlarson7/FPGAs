# demo_top.xdc — PYNQ-Z2 constraints for Swin Transformer board demo
# Matches fpga_top.v port names

# 50 MHz — relaxed clock for functional demo (baseline has negative slack at 100/125 MHz)
set_property -dict {PACKAGE_PIN H16 IOSTANDARD LVCMOS33} [get_ports clk]
create_clock -period 20.000 -name clk -waveform {0.000 10.000} [get_ports clk]

# Pushbuttons
set_property -dict {PACKAGE_PIN D19 IOSTANDARD LVCMOS33} [get_ports btn]
set_property -dict {PACKAGE_PIN D20 IOSTANDARD LVCMOS33} [get_ports btn_rst]

# LEDs
set_property -dict {PACKAGE_PIN R14 IOSTANDARD LVCMOS33} [get_ports {leds[0]}]
set_property -dict {PACKAGE_PIN P14 IOSTANDARD LVCMOS33} [get_ports {leds[1]}]
set_property -dict {PACKAGE_PIN N16 IOSTANDARD LVCMOS33} [get_ports {leds[2]}]
set_property -dict {PACKAGE_PIN M14 IOSTANDARD LVCMOS33} [get_ports {leds[3]}]

# ============================================================================
# YaRab.sdc - Fixed Syntax
# Target: Cyclone IV EP4CE6E22C8 @ 50MHz
# ============================================================================

# 1. Clock - 50MHz (20ns period)
create_clock -name clk_50m -period 20.000 [get_ports {clk}]

# 2. Clock uncertainty
derive_clock_uncertainty

# 3. Input delays - SEPARATE COMMANDS for max and min
# Reset
set_input_delay -clock clk_50m -max 15.000 [get_ports {reset}]
set_input_delay -clock clk_50m -min 0.100 [get_ports {reset}]

# Keypad rows
set_input_delay -clock clk_50m -max 15.000 [get_ports {rows[*]}]
set_input_delay -clock clk_50m -min 0.100 [get_ports {rows[*]}]

# 4. Output delays - SEPARATE COMMANDS for max and min
# Keypad columns
set_output_delay -clock clk_50m -max 10.000 [get_ports {cols[*]}]
set_output_delay -clock clk_50m -min 0.100 [get_ports {cols[*]}]

# 7-segment segments
set_output_delay -clock clk_50m -max 10.000 [get_ports {seg[*]}]
set_output_delay -clock clk_50m -min 0.100 [get_ports {seg[*]}]

# Digit enables
set_output_delay -clock clk_50m -max 10.000 [get_ports {an[*]}]
set_output_delay -clock clk_50m -min 0.100 [get_ports {an[*]}]

# 5. False paths
set_false_path -from [get_ports {reset rows[*]}]
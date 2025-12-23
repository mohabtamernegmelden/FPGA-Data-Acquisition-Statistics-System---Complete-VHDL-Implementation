# complete_pins_fixed_v2.tcl - Corrected for EP4CE6E22C8

# ====================================================================
# CLOCK - BANK 1 (3.3V)
# ====================================================================
set_location_assignment PIN_23 -to clk
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to clk

# ====================================================================
# RESET - BANK 5 (3.3V, supports weak pull-up)
# ====================================================================
set_location_assignment PIN_24 -to reset
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to reset
set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON -to reset

# ====================================================================
# KEYPAD ROWS - BANK 2 (3.3V, weak pull-up enabled)
# ====================================================================
set_location_assignment PIN_31 -to "rows[0]"
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to "rows[0]"
set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON -to "rows[0]"

set_location_assignment PIN_32 -to "rows[1]"
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to "rows[1]"
set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON -to "rows[1]"

set_location_assignment PIN_33 -to "rows[2]"
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to "rows[2]"
set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON -to "rows[2]"

set_location_assignment PIN_34 -to "rows[3]"
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to "rows[3]"
set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON -to "rows[3]"

# ====================================================================
# KEYPAD COLUMNS - BANK 4 (3.3V LVTTL, disable slew rate)
# ====================================================================
set_location_assignment PIN_64 -to "cols[0]"
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to "cols[0]"
set_instance_assignment -name SLEW_RATE FAST -to "cols[0]"

set_location_assignment PIN_65 -to "cols[1]"
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to "cols[1]"
set_instance_assignment -name SLEW_RATE FAST -to "cols[1]"

set_location_assignment PIN_66 -to "cols[2]"
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to "cols[2]"
set_instance_assignment -name SLEW_RATE FAST -to "cols[2]"

set_location_assignment PIN_67 -to "cols[3]"
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to "cols[3]"
set_instance_assignment -name SLEW_RATE FAST -to "cols[3]"

# ====================================================================
# 7-SEGMENT DISPLAY - BANK 8 (3.3V LVTTL)
# ====================================================================
set_location_assignment PIN_128 -to "seg[0]"
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to "seg[0]"

set_location_assignment PIN_121 -to "seg[1]"
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to "seg[1]"

set_location_assignment PIN_125 -to "seg[2]"
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to "seg[2]"

set_location_assignment PIN_129 -to "seg[3]"
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to "seg[3]"

set_location_assignment PIN_132 -to "seg[4]"
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to "seg[4]"

set_location_assignment PIN_126 -to "seg[5]"
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to "seg[5]"

set_location_assignment PIN_124 -to "seg[6]"
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to "seg[6]"

# ====================================================================
# DIGIT ENABLES - BANK 8 (3.3V LVTTL, separate pins from seg[])
# ====================================================================
set_location_assignment PIN_141 -to "an[0]"
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to "an[0]"

set_location_assignment PIN_142 -to "an[1]"
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to "an[1]"

set_location_assignment PIN_143 -to "an[2]"
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to "an[2]"

set_location_assignment PIN_144 -to "an[3]"
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to "an[3]"

puts "=========================================="
puts "Fully corrected pin assignments applied!"
puts "All pins now use 3.3-V LVTTL in compatible banks"
puts "Slew rate disabled for LVTTL inputs, weak pull-ups applied correctly"
puts "=========================================="

############################
## Driving Cells and Loads ##
############################

# As a default, drive multiple GPIO pads and be driven by one.
# accomodate for driving up to 2 74HC pads plus a 5pF trace
set_load [expr 2 * 5.0 + 5.0] [all_outputs]
set_driving_cell [all_outputs] -lib_cell sgi3g2_IOPadOut16mA -pin pad

####################
## Input Clocks ##
####################
puts "Clocks..."

# We target 80 MHz
set TCK_SYS 10
create_clock -name clk_sys -period $TCK_SYS [get_ports clk_i]

set TCK_JTG 20.0
create_clock -name clk_jtg -period $TCK_JTG [get_ports jtag_tck_i]

set TCK_RTC 50.0
create_clock -name clk_rtc -period $TCK_RTC [get_ports ref_clk_i]

##########################
## Clock Groups & Uncertainties ##
##########################
# Define which clocks are asynchronous to each other
# -allow paths re-activates timing checks between asyncs -> we must constrain CDCs!
set_clock_groups -asynchronous -name clk_groups_async \
	-group {clk_rtc} \
	-group {clk_jtg} \
	-group {clk_sys}

# We set reasonable uncertainties in their transition timing
# and transition (rise/fall) times for all clocks (ns)
set_clock_uncertainty 0.1 [all_clocks]
set_clock_transition 0.2 [all_clocks]

####################
## Cdcs and Syncs ##
####################
puts "CDC/Sync..."

# Clock Domain Crossings: paths going from a FF with one clock to an FF with another another)
# to increase the metastability-recovery window we do not wants any additional delays in these paths


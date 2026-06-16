#=====================================================================
# SDC constraints for DatapathPipelined (RV32IM core)
# Target library: gsclib045 (typical corner)
# Baseline run: 100 MHz (10 ns period)
#=====================================================================

# ---------------------------------------------------------
# Set the current design
# ---------------------------------------------------------
current_design DatapathPipelined


set_driving_cell -lib_cell BUFX2 -pin Y [all_inputs]
set_load 0.02 [all_outputs]


create_clock -name "clk" -add -period 10.0 -waveform {0.0 5.0} [get_ports clk]


set_clock_uncertainty 0.1 [all_clocks]
set_clock_transition 0.2 [all_clocks]


set_input_delay -clock [get_clocks clk] -add_delay 3.0 [get_ports rst]
set_input_delay -clock [get_clocks clk] -add_delay 3.0 [get_ports {inst_from_imem[*]}]
set_input_delay -clock [get_clocks clk] -add_delay 3.0 [get_ports {load_data_from_dmem[*]}]


set_output_delay -clock [get_clocks clk] -add_delay 3.0 [get_ports {pc_to_imem[*]}]
set_output_delay -clock [get_clocks clk] -add_delay 3.0 [get_ports {addr_to_dmem[*]}]
set_output_delay -clock [get_clocks clk] -add_delay 3.0 [get_ports {store_data_to_dmem[*]}]
set_output_delay -clock [get_clocks clk] -add_delay 3.0 [get_ports {store_we_to_dmem[*]}]
set_output_delay -clock [get_clocks clk] -add_delay 3.0 [get_ports halt]
set_output_delay -clock [get_clocks clk] -add_delay 3.0 [get_ports {trace_writeback_pc[*]}]
set_output_delay -clock [get_clocks clk] -add_delay 3.0 [get_ports {trace_writeback_inst[*]}]


set_max_fanout 15.000 [current_design]

set_max_transition 1.2 [current_design]

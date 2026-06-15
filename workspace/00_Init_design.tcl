set STAGE 00_init_design

source lefs.tcl

set init_verilog DataPipelined.v
set init_design_uniquify 1
set init_design_settop 1
set init_top_cell RV32
set init_lef_file $init_lef_files
set init_pwr_net {VDD}
set init_gnd_net {VSS}

init_design

saveDesign SAVED/${STAGE}_init.invs


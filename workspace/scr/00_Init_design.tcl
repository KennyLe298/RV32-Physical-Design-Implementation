set STAGE 00_init_design

exec mkdir -p rpt SAVED

set init_verilog    "../RTL/DatapathPipelined_m.v"

set init_design_uniquify 1
set init_design_settop 1
set init_top_cell   "DatapathPipelined"

set init_lef_file   "../LEF/gsclib045_tech.lef ../LEF/gsclib045_macro.lef"
set init_pwr_net {VDD}
set init_gnd_net {VSS}

set init_mmmc_file  "./mmmc.tcl"

init_design

setDesignMode -process 45


setDontUse NAND2X4 true
setDontUse NAND2X6 true
setDontUse NAND2X8 true

saveDesign -mmmc2 SAVED/${STAGE}_init.invs
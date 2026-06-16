set STAGE 01_floorplan

set aspect_ratio 1.0
set core_util    0.60
set core2io      4.0

floorPlan -r $aspect_ratio $core_util $core2io $core2io $core2io $core2io

#! Place hard macros
# placeInstance
# (no macros in DatapathPipelined - nothing to place here)

#! Assign I/O pins
# Done here, right after the floorplan exists and before placement,
# so place_opt_design (in 02_Placement.tcl) optimizes cell positions
# against real pin locations instead of guessing. M3 keeps pins below
# the CTS trunk layer (M6) and well below the M9/M10 power mesh.
editPin -pin {clk rst inst_from_imem[*]} -side Left -layer M3 -spreadType SIDE -fixedPin
editPin -pin {load_data_from_dmem[*]} -side Bottom -layer M3 -spreadType SIDE -fixedPin
editPin -pin {pc_to_imem[*] addr_to_dmem[*]} -side Right -layer M3 -spreadType SIDE -fixedPin
editPin -pin {store_data_to_dmem[*] store_we_to_dmem[*] trace_writeback_pc[*] trace_writeback_inst[*] halt} -side Top -layer M3 -spreadType SIDE -fixedPin

#! Create row
deleteRow -all
initCoreRow
cutRow

#! Create track
# Removed: floorPlan already auto-generates default tracks on every
# routing layer (see the "Start create_tracks" lines in the log from
# our earlier floorplan run) - an explicit add_tracks call here is not
# needed, and the original line used "Metal1"/"Metal 2" which don't
# exist in gsclib045 (layers are named M1, M2, ... M11). Uncomment and
# fix layer names below only if you need a custom track pitch on a
# specific layer that differs from the LEF default:
# add_tracks -offset {M1 vert 0 M2 horiz 0}

#* Report utilization
checkFPlan -reportUtil > rpt/${STAGE}_utilization.rpt

#! Global Connect
clearGlobalNets
globalNetConnect VDD -type pgpin -pin VDD -all
globalNetConnect VSS -type pgpin -pin VSS -all

#? Boundary rings - built inside create_pg.tcl below (addRing on M9/M10)
# addRing

#! Add endcap
# Skipped: grep across gsclib045_macro.lef shows every macro is
# CLASS CORE - this library kit does not include dedicated endcap
# (boundary) cells, so there is no real cell name to put here.
# setEndCapMode -prefix ENDCAP -leftEdge <end cap name> -rightEdge <end cap name>
# addEndCap
# verifyEndCap

#! PG connect
source ./scr/create_pg.tcl
verifyPowerVia

verify_connectivity -nets {VDD VSS}

saveDesign -mmmc2 SAVED/${STAGE}_PG.invs

#! Add Well Tap
# Skipped: grep for "*TAP*" across gsclib045_macro.lef returned no
# matches - this library kit has no separate well-tap cell, so there
# is no real cell name to put here either.
# addWellTap -cell <inst name> -cellInterval 40 -inRowOffset 25 -prefix WELLTAP

saveDesign -mmmc2 SAVED/${STAGE}.invs

#* report timing
timeDesign -prePlace -pathReports -slackReports -prefix ${STAGE}_prePlace -outDir ./rpt/${STAGE}_prePlace
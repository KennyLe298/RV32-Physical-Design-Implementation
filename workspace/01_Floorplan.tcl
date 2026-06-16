set STAGE 01_floorplan

set aspect_ratio 1.0
set core_util    0.60
set core2io      4.0

floorPlan -r $aspect_ratio $core_util $core2io $core2io $core2io $core2io

#! Place hard macros
# placeInstance
# (no macros in DatapathPipelined - nothing to place here)

#! Create row
deleteRow -all
initCoreRow
cutRow

#! Create track

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
# setEndCapMode -prefix ENDCAP -leftEdge <end cap name> -rightEdge <end cap name>
# addEndCap
# verifyEndCap

#! PG connect
source ./create_pg.tcl
verifyPowerVia

verify_connectivity -nets {VDD VSS}

saveDesign -mmmc2 SAVED/${STAGE}_PG.invs

#! Add Well Tap

# addWellTap -cell <inst name> -cellInterval 40 -inRowOffset 25 -prefix WELLTAP

saveDesign -mmmc2 SAVED/${STAGE}.invs

#* report timing
timeDesign -prePlace -pathReports -slackReports -prefix ${STAGE}_prePlace -outDir ./rpt/${STAGE}_prePlace
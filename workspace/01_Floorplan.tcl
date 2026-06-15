
#! Place hard macros

# placeInstance 

#! Create row

deleteRow -all
initCoreRow
cutRow

#! Create track
add_tracks -offset {Metal1 vert 0 Metal 2 horiz 0}

#* Report utilization
checkFPlan -reportUtil > rpt/${STAGE}_utilization.rpt

#! Global Connect
clearGlobalNets
globalNetConnect VDD -type pgpin -pin VDD -inst * -override
globalNetConnect VSS -type pgpin -pin VSS -inst * -override

#? Boudary rings
# addRing

#! Add endcap 
setEndCapMode -prefix ENDCAP -leftEdge <end cap name> -rightEdge <end cap name>
addEndCap

verifyEndCap

#! PG connect
source -e -v create_pg.tcl
verifyPowerVia

verify_connectivity -nets {VDD VSS}

saveDesign SAVED/${STAGE}_PG.invs

#! Add Well Tap
addWellTap -cell <inst name> -cellInterval 40 -inRowOffset 25 -prefix WELLTAP 


saveDesign SAVED/${STAGE}.invs

#* report timing

timeDesign -prePlace -pathReports -slackReports -prefix ${STAGE}_prePlace -outDir ./rpt/${STAGE}_prePlace




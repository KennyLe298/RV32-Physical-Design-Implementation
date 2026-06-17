set STAGE 05_routing

exec mkdir -p ./rpt/${STAGE}

############################
## Detailed routing
############################
# (Optional, version-specific) For timing/SI-aware routing you can set
# modes before route_design, e.g.:
#       man setNanoRouteMode
#   setNanoRouteMode -routeWithTimingDriven true
# Defaults are fine for the trial; left out so nothing unverified runs.
route_design

saveDesign -mmmc2 SAVED/${STAGE}.invs


setOptMode -fixCap true -fixTran true -fixFanoutLoad true

# fix setup
setOptMode -addInstancePrefix dpPipelined_postRoute_setup
optDesign -postRoute -expandedViews -timingDebugReport -outDir ./rpt/${STAGE}_setup
saveDesign -mmmc2 SAVED/${STAGE}_setup.invs

# fix hold

setOptMode -addInstancePrefix dpPipelined_postRoute_hold
optDesign -postRoute -hold -expandedViews -timingDebugReport -outDir ./rpt/${STAGE}_hold
saveDesign -mmmc2 SAVED/${STAGE}_hold.invs

############################
## Filler / decap insertion   <-- VERIFY THE 3 ITEMS BELOW, THEN UNCOMMENT
############################
# This is placed AFTER the last optDesign on purpose (optDesign can add/
# resize cells, which would invalidate earlier fillers). Confident part:
# the *position in the flow* and "re-run verify_drc/connectivity after".
# Unverified-on-your-build parts (do not run until checked):
#
#   1. Filler cell names. gsclib045 names them in the macro LEF. Find them:
#         grep -iE "MACRO +(FILL|FILLER|DCAP|DECAP)" ../LEF/gsclib045_macro.lef
#      (You already used this technique to confirm there were no TAP/
#       ENDCAP cells, so the same grep applies.) Put the real names in
#       the -cell list below, largest-to-smallest is conventional.
#
#   2. addFiller option/flag names:    man addFiller
#   3. setFillerMode option names:     man setFillerMode
#      (Some builds want the cell list on setFillerMode -core {...} and
#       a bare addFiller; others take -cell directly on addFiller. Your
#       man pages decide which form is valid - this is exactly the kind
#       of thing that differs by license/version.)
#
# Template once confirmed (adjust to whatever your man pages show):
#   setFillerMode -fitGap true
#   addFiller -cell { <FILL_largest> ... <FILL_smallest> } -prefix FILLER
#   verify_drc          -report ./rpt/${STAGE}/postFiller.viols.drc
#   verify_connectivity -type all -report ./rpt/${STAGE}/postFiller.conn.rpt
#   saveDesign -mmmc2 SAVED/${STAGE}_filled.invs
############################

############################
## Signoff checks
############################
verify_drc -report ./rpt/${STAGE}/DatapathPipelined.viols.drc
verify_connectivity -type all -report ./rpt/${STAGE}/connectivity.rpt

checkFPlan -reportUtil > rpt/${STAGE}/check_util.rpt
checkDesign -all       > rpt/${STAGE}/check_design.rpt
reportCongestion -overflow -includeBlockage -hotSpot > rpt/${STAGE}/reportCongestion.rpt

############################
## Post-route timing/area reports
############################
timeDesign -postRoute -pathReports -slackReports -numPaths 1000 -prefix dpPipelined_postRoute -outDir ./rpt/${STAGE}/${STAGE}_setup_final
timeDesign -postRoute -hold -pathReports -slackReports -numPaths 1000 -prefix dpPipelined_postRoute -outDir ./rpt/${STAGE}/${STAGE}_hold_final
report_area > ./rpt/${STAGE}/reports_routing_area.rpt

# save final database
saveDesign -mmmc2 SAVED/${STAGE}.invs
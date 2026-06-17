set STAGE 05_routing

exec mkdir -p ./rpt/${STAGE}

############################
## Detailed routing
############################

setNanoRouteMode -reset
setNanoRouteMode -route_use_auto_via true
routeDesign

saveDesign -mmmc2 SAVED/05_routing.invs

setOptMode -fixCap true -fixTran true -fixFanoutLoad true

setOptMode -addInstancePrefix dpPipelined_postRoute_setup
optDesign -postRoute -expandedViews -timingDebugReport -outDir ./rpt/05_routing_setup
saveDesign -mmmc2 SAVED/05_routing_setup.invs

setOptMode -addInstancePrefix dpPipelined_postRoute_hold
optDesign -postRoute -hold -expandedViews -timingDebugReport -outDir ./rpt/05_routing_hold
saveDesign -mmmc2 SAVED/05_routing_hold.invs

############################
## Filler / decap insertion
############################

#setFillerMode -core {FILL64 FILL32 FILL16 FILL8 FILL4 FILL2 FILL1} -fitGap true
#addFiller -prefix FILLER

# re-verify after filler (fillers connect to rails by abutment; this
# confirms no new DRC/opens were introduced)
verify_drc          -report ./rpt/${STAGE}/postFiller.viols.drc
verify_connectivity -type all -report ./rpt/${STAGE}/postFiller.conn.rpt
saveDesign -mmmc2 SAVED/${STAGE}_filled.invs

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
saveDesign -mmmc2 SAVED/${STAGE}_final.invs
set STAGE 05_routing

exec mkdir -p ./rpt/${STAGE}

############################
## Detailed routing
############################
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
## Signoff checks
############################
verify_drc -report ./rpt/${STAGE}/DatapathPipelined.viols.drc
verify_connectivity -type all -report ./rpt/${STAGE}/connectivity.rpt

checkFPlan -reportUtil > rpt/${STAGE}/check_util.rpt
checkDesign -all > rpt/${STAGE}/check_design.rpt
reportCongestion -overflow -includeBlockage -hotSpot > rpt/${STAGE}/reportCongestion.rpt

############################
## Post-route timing/area reports
############################
timeDesign -postRoute -pathReports -slackReports -numPaths 1000 -prefix dpPipelined_postRoute -outDir ./rpt/${STAGE}/${STAGE}_setup_final
timeDesign -postRoute -hold -pathReports -slackReports -numPaths 1000 -prefix dpPipelined_postRoute -outDir ./rpt/${STAGE}/${STAGE}_hold_final
report_area > ./rpt/${STAGE}/reports_routing_area.rpt

# save final database
saveDesign -mmmc2 SAVED/${STAGE}.invs
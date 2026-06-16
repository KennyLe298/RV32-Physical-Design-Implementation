############################
## Setup
############################
set STAGE 04_CTS_opt

exec mkdir -p ./rpt/${STAGE}

setAnalysisMode -cppr both -clockGatingCheck 1 -timeBorrowing 1 -useOutputPinCap 1 -sequentialConstProp 1 -timingSelfLoopsNoSkew 0 -enableMultipleDriveNet 1 -clkSrcPath 1 -warn 1 -usefulSkew 1 -analysisType onChipVariation -skew true -clockPropagation sdcControl -log 1
set_analysis_view -setup [all_setup_analysis_views] -hold [all_hold_analysis_views]
set_interactive_constraint_modes [all_constraint_modes -active]

set_propagated_clock [all_clocks]
redirect -quiet {set honorDomain [getAnalysisMode -honorClockDomains]} > /dev/null

#report path group options
reportPathGroupOptions

setOptMode -fixCap true -fixTran true -fixFanoutLoad true

# fix setup
setOptMode -addInstancePrefix dpPipelined_postCTS_setup
optDesign -postCTS -expandedViews -timingDebugReport -outDir ./rpt/${STAGE}_setup
saveDesign -mmmc2 SAVED/${STAGE}_setup.invs

timeDesign -postCTS -hold -pathReports -slackReports -numPaths 1000 -prefix dpPipelined_postCTS -outDir ./rpt/${STAGE}/${STAGE}_hold

# fix hold
setOptMode -addInstancePrefix dpPipelined_postCTS_hold
optDesign -postCTS -hold -expandedViews -timingDebugReport -outDir ./rpt/${STAGE}_hold

saveDesign -mmmc2 SAVED/${STAGE}_hold.invs

timeDesign -postCTS -pathReports -slackReports -numPaths 1000 -prefix dpPipelined_postCTS -outDir ./rpt/${STAGE}/${STAGE}_Opt_setup
timeDesign -postCTS -hold -pathReports -slackReports -numPaths 1000 -prefix dpPipelined_postCTS -outDir ./rpt/${STAGE}/${STAGE}_Opt_hold

# save final dbs
saveDesign -mmmc2 SAVED/${STAGE}.invs

checkFPlan -reportUtil > rpt/${STAGE}/check_util.rpt
checkDesign -all > rpt/${STAGE}/check_design.rpt
checkPlace > rpt/${STAGE}/checkPlace.rpt
reportCongestion -overflow -includeBlockage -hotSpot > rpt/${STAGE}/reportCongestion.rpt
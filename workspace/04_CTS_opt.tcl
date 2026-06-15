############################
## Setup
############################
set STAGE 04_CTS_opt
# limitations under the License.
set central_path /ictc/student_data/share/pd/data
source ${central_path}/scripts/common/common_settings.tcl
source ${central_path}/scripts/common/user_settings.tcl
source ${central_path}/scripts/common/config.tcl
exec mkdir -p ./rpt/${STAGE}

############################
## set dont use
############################
#set dont_use_cells sgi3g2_IOPad*
#set_dont_use $dont_use_cells

setAnalysisMode -cppr both -clockGatingCheck 1 -timeBorrowing 1 -useOutputPinCap 1 -sequentialConstProp 1 -timingSelfLoopsNoSkew 0 -enableMultipleDriveNet 1 -clkSrcPath 1 -warn 1 -usefulSkew 1 -analysisType onChipVariation -skew true -clockPropagation sdcControl -log 1
# update_analysis_view -name func_view_wc -constraint_mode func_mode_prop
# update_analysis_view -name func_view_bc -constraint_mode func_mode_prop
# set_analysis_view -update_timing
set_analysis_view -setup [all_setup_analysis_views ] -hold [all_hold_analysis_views ]
set_interactive_constraint_modes [all_constraint_modes -active]

#clearClockDomains
#setClockDomains -all
#set_interactive_constraint_modes {func_mode_prop}
set_propagated_clock [all_clocks]
redirect -quiet {set honorDomain [getAnalysisMode -honorClockDomains]} > /dev/null

#report path group options
reportPathGroupOptions

setOptMode -fixCap true -fixTran true -fixFanoutLoad true
setOptMode -addInstancePrefix ictc_postCTS_setup
# fix setup
optDesign -postCTS -expandedViews -timingDebugReport -outDir ./rpt/${STAGE}_setup
saveDesign SAVED/${STAGE}_setup.invs
#return
timeDesign -postCTS -hold -pathReports -slackReports -numPaths 1000 -prefix croc_postCTS -outDir ./rpt/${STAGE}/${STAGE}_hold

# fix hold
setOptMode -addInstancePrefix ictc_postCTS_hold
optDesign -postCTS -hold -expandedViews -timingDebugReport -outDir ./rpt/${STAGE}_hold

saveDesign SAVED/${STAGE}_hold.invs


timeDesign -postCTS -pathReports -slackReports -numPaths 1000 -prefix croc_postCTS -outDir ./rpt/${STAGE}/${STAGE}_Opt_setup
timeDesign -postCTS -hold -pathReports -slackReports -numPaths 1000 -prefix croc_postCTS -outDir ./rpt/${STAGE}/${STAGE}_Opt_hold
# save final dbs
saveDesign SAVED/${STAGE}.invs

checkPlan -reportUtil > rpt/${STAGE}/check_util.rpt
checkDesign -all > rpt/${STAGE}/check_design.rpt
checkPlace > rpt/${STAGE}/checkPlace.rpt
reportCongestion -overflow -includeBlockage -hotSpot > rpt/${STAGE}/reportCongestion.rpt

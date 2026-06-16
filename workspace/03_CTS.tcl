set STAGE 03_cts

create_ccopt_clock_tree_spec -file ccopt_native.spec
source ccopt_native.spec

# M2 keeps local leaf-level clock routing low and out of the way of signal nets; M6 gives the
# trunk a mid-stack layer that sits below the M9/M10 power ring/mesh
# built in create_pg.tcl, avoiding overlap with the power network.
setCTSMode -obs_routeBottomPreferredLayer M2
setCTSMode -obs_routeTopPreferredLayer M6

set_ccopt_property target_max_trans 0.8
set_ccopt_property -max_fanout 32
set_ccopt_property -target_skew 0.15

# (Template only) If a future project has a hard macro or specific
# register with a clock pin that needs an explicit insertion delay or
# to be excluded from CTS balancing, the pattern is:
#   set_ccopt_property insertion_delay -pin <hier_pin_path> <value>
#   set_ccopt_property sink_type -pin <hier_pin_path> ignore


ccopt_design -cts

saveDesign -mmmc2 SAVED/${STAGE}.invs
exec mkdir -p ./rpt/${STAGE}
report_ccopt_skew_groups -file ./rpt/${STAGE}/ccopt_skew_groups.rpt
report_ccopt_clock_trees -file ./rpt/${STAGE}/ccopt_clock_trees.rpt
#report_ccopt_worst_chain -file ./rpt/${STAGE}/ccopt_worst_chain.rpt

# run checkers
checkFPlan -reportUtil > rpt/${STAGE}/check_util.rpt
checkDesign -all > rpt/${STAGE}/check_design.rpt
checkPlace > rpt/${STAGE}/checkPlace.rpt
reportCongestion -overflow -includeBlockage -hotSpot > rpt/${STAGE}/reportCongestion.rpt

# report timing
timeDesign -postCTS -pathReports -slackReports -numPaths 1000 -prefix dpPipelined_postCTS -outDir ./rpt/${STAGE}/${STAGE}_setup
timeDesign -postCTS -hold -pathReports -slackReports -numPaths 1000 -prefix dpPipelined_postCTS -outDir ./rpt/${STAGE}/${STAGE}_hold
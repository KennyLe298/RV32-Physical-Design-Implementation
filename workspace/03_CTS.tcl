set STAGE 03_cts


create_ccopt_clock_tree_spec -file ccopt_native.spec
source ccopt_native.spec


set_ccopt_property target_max_trans 0.8
set_ccopt_property max_fanout       32
set_ccopt_property target_skew      0.15


create_route_type -name clk_route -bottom_preferred_layer M2 -top_preferred_layer M6
set_ccopt_property route_type -net_type trunk clk_route
set_ccopt_property route_type -net_type leaf  clk_route

# (Template only) per-pin overrides, if a future design needs them:
#   set_ccopt_property insertion_delay -pin <hier_pin_path> <value>
#   set_ccopt_property sink_type       -pin <hier_pin_path> ignore

# Build the clock tree (CTS only; post-CTS optimization lives in 04).
ccopt_design -cts

saveDesign -mmmc2 SAVED/${STAGE}.invs

exec mkdir -p ./rpt/${STAGE}
report_ccopt_skew_groups  -file ./rpt/${STAGE}/ccopt_skew_groups.rpt
report_ccopt_clock_trees  -file ./rpt/${STAGE}/ccopt_clock_trees.rpt
#report_ccopt_worst_chain -file ./rpt/${STAGE}/ccopt_worst_chain.rpt

# run checkers
checkFPlan -reportUtil > rpt/${STAGE}/check_util.rpt
checkDesign -all       > rpt/${STAGE}/check_design.rpt
checkPlace             > rpt/${STAGE}/checkPlace.rpt
reportCongestion -overflow -includeBlockage -hotSpot > rpt/${STAGE}/reportCongestion.rpt

# report timing
timeDesign -postCTS       -pathReports -slackReports -numPaths 1000 -prefix dpPipelined_postCTS -outDir ./rpt/${STAGE}/${STAGE}_setup
timeDesign -postCTS -hold -pathReports -slackReports -numPaths 1000 -prefix dpPipelined_postCTS -outDir ./rpt/${STAGE}/${STAGE}_hold
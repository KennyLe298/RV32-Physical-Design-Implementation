## set dont use
#######################
#set dont_use_cells sgi3g2_IOPad*
#set_dont_use $dont_use_cells

create_ccopt_clock_tree_spec -file ccopt_native.spec
source ccopt_native.spec

setCTSMode -bottomPreferredLayer Metal2
setCTSMode -routeTopPreferredLayer Metal5
#set_ccopt_property target_max_trans 2.223
#set_ccopt_property target_max_trans 2.083
#set_ccopt_property target_max_trans 1.083
#set_ccopt_property target_max_capacitance
set_ccopt_property target_max_trans 0.8
set_ccopt_property -max_fanout 32
set_ccopt_property -target_skew 0.15

#set_ccopt_property insertion_delay -pin i_croc_soc/i_croc/gen_sram_bank_1_1_sram/gen_512x32Bx1_i_cut/A_CLK 0.500
#set_ccopt_property insertion_delay -pin i_croc_soc/i_croc/gen_sram_bank_0_1_sram/gen_512x32Bx1_i_cut/A_CLK 0.500
#set_ccopt_property insertion_delay -pin i_croc_soc/i_croc/i_gpio/i_reg_file_reg_188_reg/CLK 0.150
set_ccopt_property sink_type -pin i_croc_soc/i_croc/i_gpio/i_reg_file_new_reg_251_reg/CLK ignore

ccopt_design -cts

saveDesign SAVED/${STAGE}.invs
exec mkdir -p ./rpt/${STAGE}
report_ccopt_skew_groups -file ./rpt/${STAGE}/ccopt_skew_groups.rpt
report_ccopt_clock_trees -file ./rpt/${STAGE}/ccopt_clock_trees.rpt
#report_ccopt_worst_chain -file ./rpt/${STAGE}/ccopt_worst_chain.rpt
# run checkers
checkPlan -reportUtil > rpt/${STAGE}/check_util.rpt
checkDesign -all > rpt/${STAGE}/check_design.rpt
checkPlace > rpt/${STAGE}/checkPlace.rpt
reportCongestion -overflow -includeBlockage -hotSpot > rpt/${STAGE}/reportCongestion.rpt
# report timing
timeDesign -postCTS -pathReports -slackReports -numPaths 1000 -prefix croc_postCTS -outDir ./rpt/${STAGE}/${STAGE}_setup
timeDesign -postCTS -hold -pathReports -slackReports -numPaths 1000 -prefix croc_postCTS -outDir ./rpt/${STAGE}/${STAGE}_hold


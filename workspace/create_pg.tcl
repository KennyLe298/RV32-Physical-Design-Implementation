editDelete -type Special -use POWER

### pg connection for sram ###
globalNetConnect VDD -type pgpin -pin VDDARRAY -inst * -override
globalNetConnect VDD -type pgpin -pin VDDARRAY! -inst * -override
globalNetConnect VDD -type pgpin -pin VDD! -inst * -override
globalNetConnect VSS -type pgpin -pin VSS! -inst * -override
# refer for IOPAD pg connection /ictc/teacher_data/ictc_thenhyen/croc/openroad/scripts/power_connect.tcl
set box [dbShape -output rect [dbget top.insts.cell.baseClass block -p2].box ] SIZE 1.0
createRouteBlk -name sram_rblk -layer Metal5 -box $box

sroute -connect { blockPin corePin floatingStripe } -layerChangeRange { Metal1 TopMetal2 } -blockPinTarget { nearestRingStripe nearestTarget } -corePinTarget { firstAfterRowEnd } -floatingStripeTarget { blocking ring stripe ringpin blockpin followpin } -allowJogging 1 -crossoverViaLayerRange { Metal1 TopMetal2 } -nets {VDD VSS} -allowLayerChange 1 -blockPin useLeft -targetViaLayerRange { Metal1 TopMetal2 }

setAddStripeMode -reset
setAddStripeMode -stacked_via_top_layer Metal3 -stacked_via_bottom_layer Metal1 -stapling_nets_style side_to_side
addStripe -layer Metal3 -direction vertical -nets {VDD VSS} -width 1 -set_to_set_distance 15 -spacing 2 -start 0.5

setAddStripeMode -reset
setAddStripeMode -stacked_via_top_layer Metal4 -stacked_via_bottom_layer Metal3 -stapling_nets_style side_to_side
addStripe -layer Metal4 -direction horizontal -nets {VDD VSS} -width 1 -set_to_set_distance 15 -spacing 2 -start 0.5

setAddStripeMode -reset
setAddStripeMode -stacked_via_top_layer Metal5 -stacked_via_bottom_layer Metal4 -stapling_nets_style side_to_side
addStripe -layer Metal5 -direction vertical -nets {VDD VSS} -width 1 -set_to_set_distance 15 -spacing 2 -start 0.5

# editDelete -type Special -use POWER -layer {TopMetal1 TopMetal2}
setAddStripeMode -stacked_via_top_layer TopMetal1 -stacked_via_bottom_layer Metal5 -stapling_nets_style side_to_side
addStripe -layer TopMetal1 -direction horizontal -nets {VDD VSS} -width 4 -set_to_set_distance 30 -spacing 4 -start 0.5

setAddStripeMode -reset
setAddStripeMode -stacked_via_top_layer TopMetal2 -stacked_via_bottom_layer TopMetal1 -stapling_nets_style side_to_side
addStripe -layer TopMetal2 -direction vertical -nets {VDD VSS} -width 4 -set_to_set_distance 30 -spacing 4

#deleteRouteBlk for sram
deleteRouteBlk -name sram_rblk
#editPowerVia -nets VDD VSS -add_vias true -top_layer TopMetal1 -area {609.6 191.94 1412.16 464.52} -uda -orthogonal_only
#editPowerVia -nets VDD VSS -add_vias true -top_layer TopMetal1 -area {609.6 191.94 1412.16 464.52} -uda -orthogonal_only
editPowerVia -nets VDD -add_vias true -top_layer TopMetal1 -area $box -uda -orthogonal_only
editPowerVia -nets VDD -add_vias true -top_layer TopMetal1 -area $box -uda -orthogonal_only

#* verifyPowerVia
editDelete -type Special -use POWER


addRing -nets {VDD VSS} \
    -type core_rings \
    -follow core \
    -layer {top M9 bottom M9 left M10 right M10} \
    -width  {top 0.5 bottom 0.5 left 0.5 right 0.5} \
    -spacing {top 0.5 bottom 0.5 left 0.5 right 0.5} \
    -offset {top 0.5 bottom 0.5 left 0.5 right 0.5}

puts "Power ring added."


setAddStripeMode -reset
setAddStripeMode -stacked_via_top_layer M4 -stacked_via_bottom_layer M1 \
    -stapling_nets_style side_to_side
addStripe -nets {VDD VSS} -layer M4 -direction vertical \
    -width 0.4 -spacing 2 -set_to_set_distance 30 -start_offset 5

puts "Stripe mesh tier 1 (M4) added."


setAddStripeMode -reset
setAddStripeMode -stacked_via_top_layer M7 -stacked_via_bottom_layer M4 \
    -stapling_nets_style side_to_side
addStripe -nets {VDD VSS} -layer M7 -direction horizontal \
    -width 0.6 -spacing 2 -set_to_set_distance 35 -start_offset 5

puts "Stripe mesh tier 2 (M7) added."

setAddStripeMode -reset
setAddStripeMode -stacked_via_top_layer M10 -stacked_via_bottom_layer M7 \
    -stapling_nets_style side_to_side
addStripe -nets {VDD VSS} -layer M10 -direction vertical \
    -width 1 -spacing 2 -set_to_set_distance 40 \
    -start_offset 10 -stop_offset 10 -extend_to design_boundary

setAddStripeMode -reset
puts "Stripe mesh tier 3 (M10, merged with ring) added."

sroute -connect { blockPin padPin padRing corePin floatingStripe } \
    -layerChangeRange { M1 M10 } \
    -blockPinTarget { nearestTarget } \
    -corePinTarget { firstAfterRowEnd } \
    -floatingStripeTarget { blockring ring stripe padring ringpin blockpin followpin } \
    -allowJogging 1 \
    -allowLayerChange 1 \
    -crossoverViaBottomLayer M1 \
    -crossoverViaTopLayer M10 \
    -targetViaLayerRange { M1 M10 } \
    -nets { VDD VSS }

puts "sroute (pin-to-rail connection) complete."

editPowerVia -nets {VDD VSS} -add_vias true -top_layer M10 -bottom_layer M1


saveDesign post_power_plan -mmmc2
puts "Checkpoint 'post_power_plan' saved."
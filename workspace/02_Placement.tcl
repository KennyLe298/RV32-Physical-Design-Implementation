set STAGE 02_place_opt

set report_dir rpt 
set stage_rpt ${report_dir}/${STAGE}

if {[glob -nocomplain $stage_rpt] ==""} { exec mkdir $stage_rpt }

place_design

timeDesign -preCTS -pathReports -slackReports -numPaths 1000 -prefix placeOnly -outDir ./rpt/${STAGE}

saveDesign SAVED/${STAGE}.invs

#* Check legality
checkPlace 

#! Tie-cells
setTieHiLoMode -reset 
setTieHiLoMode -cell {tie cell name} -maxFanout 10 -honorDontTouch false -createHierPort false
addTieHiLo -cell {< tie cell name > } -prefix TIE

timeDesign -preCTS -pathReports -slackReports -numPaths 1000 -prefix placeOnly -outDir ./rpt/${STAGE}_setup

saveDesign SAVED/${STAGE}.invs
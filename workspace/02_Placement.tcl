set STAGE 02_place_opt

set report_dir rpt
set stage_rpt ${report_dir}/${STAGE}

if {[glob -nocomplain $stage_rpt] == ""} { exec mkdir -p $stage_rpt }

place_opt_design

timeDesign -preCTS -pathReports -slackReports -numPaths 1000 -prefix placeOnly -outDir ./rpt/${STAGE}

saveDesign -mmmc2 SAVED/${STAGE}.invs

#* Check legality
checkPlace

#! Tie-cells

setTieHiLoMode -reset
setTieHiLoMode -cell {TIEHI TIELO} -maxFanout 10 -honorDontTouch false -createHierPort false
addTieHiLo -cell {TIEHI TIELO} -prefix TIE


timeDesign -preCTS -pathReports -slackReports -numPaths 1000 -prefix postTie -outDir ./rpt/${STAGE}

report_area > ./rpt/${STAGE}/reports_placement_area.rpt

saveDesign -mmmc2 SAVED/${STAGE}.invs

set DESIGN DatapathPipelined

read_libs "../LIB/typical.lib"

read_physical -lef "../LEF/gsclib045_tech.lef ../LEF/gsclib045_macro.lef"

read_hdl "./outputs_Jun13-16:33:46/DatapathPipelined_m.v"

elaborate $DESIGN

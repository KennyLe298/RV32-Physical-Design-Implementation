#=====================================================================
# MMMC view definition - minimal single-corner setup
# DatapathPipelined (RV32IM core) - gsclib045, typical corner
#=====================================================================

# ---------------------------------------------------------
# Library set: which Liberty file(s) define cell timing
# ---------------------------------------------------------
create_library_set -name typical_lib_set \
    -timing { ../LIB/typical.lib }

# ---------------------------------------------------------
# RC corner: parasitic/wire-delay characterization
# No cap table / QRC tech file available yet, so Innovus
# will fall back to LEF-based estimates. This is fine for
# a first floorplan/place/route pass.
# ---------------------------------------------------------
create_rc_corner -name typical_rc \
    -temperature 25

# ---------------------------------------------------------
# Delay corner: combines library set + RC corner
# ---------------------------------------------------------
create_delay_corner -name typical_delay_corner \
    -library_set typical_lib_set \
    -rc_corner typical_rc

# ---------------------------------------------------------
# Constraint mode: which SDC defines functional constraints
# ---------------------------------------------------------
create_constraint_mode -name func_mode \
    -sdc_files { ../constraints/RV32.sdc }

# ---------------------------------------------------------
# Analysis view: ties mode + delay corner + constraint mode
# together, and is used for both setup and hold analysis
# ---------------------------------------------------------
create_analysis_view -name func_view \
    -constraint_mode func_mode \
    -delay_corner typical_delay_corner

set_analysis_view -setup { func_view } -hold { func_view }

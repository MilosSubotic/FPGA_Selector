#!/usr/bin/env julia
###############################################################################

using Tables

###############################################################################

families = read_tables()

#TODO Read offers with params from XLS. If no XLS exists, run get_offers.jl.

###############################################################################

#TODO Make super table with all kind of params needed for check bellow.
# Save it just for documentation.

#TODO Check:
# - cost per pin
# - cost per pin bandwidth
# - cost per SO-DIMM badwidth (sharing common pins or not)
# - compare price with and without stock
# - cost with and without PCIe
# - without PCIe and user rest of SO-DIMM pins for parallel bus.

###############################################################################

println("End")

###############################################################################

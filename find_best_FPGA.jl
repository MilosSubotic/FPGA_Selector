#!/usr/bin/env julia
###############################################################################

using Tables

###############################################################################

families = read_families()

#Read offers with params from XLS.
if !isfile("tmp/offers.xls")
	include("get_offers.jl")
end

offers = read_table("tmp/offers.xls", "offers")

###############################################################################

# Super table with all kind of params needed for check bellow.
supertable = deepcopy(offers)
# Save it just for documentation.


###############################################################################

sort(df, cols = :B)

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

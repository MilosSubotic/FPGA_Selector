#!/usr/bin/env julia
###############################################################################

using Tables
using DataFrames

###############################################################################

@time families = read_families()

#Read offers with params from XLS.
if !isfile("tmp/offers.xls")
	include("get_offers.jl")
end

@time offers = read_table("tmp/offers.xls", "offers")

###############################################################################

# Super table with all kind of params needed for check bellow.
super_table = deepcopy(offers)

function pins(r)
	dpc_t = families[r[:family]]["dev_pack_combs"]
	dp = (r[:device], r[:package])
	i = findfirst(dpc_t[:dev_pack], dp)
	@assert(i != 0)
	dpc_r = dpc_t[i, :]

	c = 0
	if haskey(dpc_r, :HR)
		c += dpc_r[:HR][1]
	end
	
	return c
end
super_table[:pins] = [ pins(r) for r in eachrow(super_table) ]

#TODO More columns.

# Save it just for documentation.
write_table("tmp/super_table.xls", "super_table", super_table)

###############################################################################

# cost per pin
t = deepcopy(super_table)

sort!(t, cols = :price)

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

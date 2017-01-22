#!/usr/bin/env julia
###############################################################################

using Tables
using DataFrames

###############################################################################

families = read_families()

#Read offers with params from XLS.
if !isfile("tmp/offers.xls")
	include("get_offers.jl")
end

offers = read_table("tmp/offers.xls", "offers")

###############################################################################

# Super table with all kind of params needed for check bellow.
uber_table = offers

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
uber_table[:pins] = [ pins(r) for r in eachrow(uber_table) ]
uber_table[:cost_per_pin] = uber_table[:price]./uber_table[:pins]

#TODO More columns.

# Save it just for documentation.
write_table("tmp/uber_table.xls", "uber_table", uber_table)

###############################################################################

# Select those who have needed stock.
uber_table = uber_table[uber_table[:stock_vs_need] .>= 0, :]

# Cost per pin:
sort!(uber_table, cols = :cost_per_pin)
write_table("tmp/cost_per_pin.xls", "cost_per_pin", uber_table)


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

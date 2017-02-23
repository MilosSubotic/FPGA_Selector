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
	# Make device-package pair.
	dp = (r[:device], r[:package])
	
	# Search for offers with such package.
	i = findfirst(dpc_t[:dev_pack], dp)

	# No such device-package pair.
	if i == 0
		return 0
	end
	
	# Extract row for device-package pair, to harvest pins data.
	dpc_r = dpc_t[i, :]

	c = 0
	if haskey(dpc_r, :HR)
		c += dpc_r[:HR][1]
	end
	if haskey(dpc_r, :HP)
		c += dpc_r[:HP][1]
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
sort!(uber_table, cols = :cost_per_pin)

# Cheapest from family:
println("Cheapest Artix-7:")
println(
	sort(
		uber_table[uber_table[:family] .== "Artix-7", :],
		cols = :price
	)[1, :]
)
println("Cheapest Kintex-7:")
println(
	sort(
		uber_table[uber_table[:family] .== "Kintex-7", :],
		cols = :price
	)[1, :]
)
println("Cheapest Virtex-7:")
println(
	sort(
		uber_table[uber_table[:family] .== "Virtex-7", :],
		cols = :price
	)[1, :]
)


# Cost per pin:
cost_per_pin = deepcopy(uber_table)
write_table("tmp/cost_per_pin.xls", "cost_per_pin", cost_per_pin)
println("Cheapers per pin:")
best = cost_per_pin[1, :]
println(best)

# Same package, same pin number.
same_package = uber_table[
	(uber_table[:family] .== best[:family]) .*
	(uber_table[:package] .== best[:package]), :]
p = same_package[:pins]
same_pin_num = all(p .== p[1])
@show same_pin_num

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

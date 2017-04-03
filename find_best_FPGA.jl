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
	dpp_t = families[r[:family]]["dev_pack_pins"]
	# Make device-package pair.
	dp = (r[:device], r[:package])
	
	# Search for pins info with such device-package pair.
	i = findfirst(dpp_t[:dev_pack], dp)

	# No such device-package pair.
	if i == 0
		return 0
	end
	
	# Extract row for device-package pair, to harvest pins data.
	dpp_r = dpp_t[i, :]

	c = 0
	if haskey(dpp_r, :HR)
		c += dpp_r[:HR][1]
	end
	if haskey(dpp_r, :HP)
		c += dpp_r[:HP][1]
	end

	return c
end
uber_table[:pins] = [ pins(r) for r in eachrow(uber_table) ]
uber_table[:cost_per_pin] = uber_table[:price]./uber_table[:pins]

pins_for_byte = 10
function DDR_bytes_per_cols(pin_type, col)
	counts = Int[]
	for r in eachrow(uber_table)
		dpb = families[r[:family]]["dev_pack_banks"]
		# Make device-package pair.
		dp = (r[:device], r[:package])

		count = 0

		# No such device-package pair.
		if !haskey(dpb, dp)	
			warn("No bank data for ", dp)
		else
			# Bank table.
			bt = dpb[dp]

			pin_type = string(pin_type)
	
			for r in eachrow(bt)
				bank = r[:bank]
				if bank != "NA" && length(bank) == 2 && r[:pin_type] == pin_type &&
					parse(Int, bank[1]) == col

					if r[:byte_group_0_pin_num] >= pins_for_byte &&
						r[:byte_group_1_pin_num] >= pins_for_byte &&
						r[:byte_group_2_pin_num] >= pins_for_byte &&
						r[:byte_group_3_pin_num] >= pins_for_byte
						count += 1
					end
				end
			end
		end

		push!(counts, count)
	end

	return counts
end
uber_table[:HR_DDR_B_c1] = DDR_bytes_per_cols(:HR, 1)
uber_table[:HR_DDR_B_c2] = DDR_bytes_per_cols(:HR, 2)
uber_table[:HR_DDR_B_c3] = DDR_bytes_per_cols(:HR, 3)
uber_table[:HR_DDR_B_c4] = DDR_bytes_per_cols(:HR, 4)
uber_table[:HP_DDR_B_c1] = DDR_bytes_per_cols(:HP, 1)
uber_table[:HP_DDR_B_c2] = DDR_bytes_per_cols(:HP, 2)
uber_table[:HP_DDR_B_c3] = DDR_bytes_per_cols(:HP, 3)
uber_table[:HP_DDR_B_c4] = DDR_bytes_per_cols(:HP, 4)

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

# DDR bytes.

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

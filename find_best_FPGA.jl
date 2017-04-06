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

N_rows = size(uber_table)[1]

###############################################################################

uber_table[:pins] = Vector{Float64}(N_rows)
for r in eachrow(uber_table)
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

	r[:pins] = c
end

uber_table[:cost_per_pin] = uber_table[:price]./uber_table[:pins]

###############################################################################


uber_table[:HR_DDR_MTps] = Vector{Int}(N_rows)
uber_table[:HP_DDR_MTps] = Vector{Int}(N_rows)
for r in eachrow(uber_table)
	ds = families[r[:family]]["ddr_speeds"]
	r[:HR_DDR_MTps] = ds["HR"][r[:speed_grade]]
	if haskey(ds, "HP")
		r[:HP_DDR_MTps] = ds["HP"][r[:speed_grade]]
	else
		r[:HP_DDR_MTps] = 0
	end
end

###############################################################################

pins_for_byte_group = 12 #TODO Could it be lower?

function DDR_bytes_groups_per_cols(pin_type, col)
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
				if bank != "NA" && length(bank) == 2 &&
					r[:pin_type] == pin_type &&	parse(Int, bank[1]) == col

					# All 4 byte groups needed.
					if r[:byte_group_0_pin_num] >= pins_for_byte_group &&
						r[:byte_group_1_pin_num] >= pins_for_byte_group &&
						r[:byte_group_2_pin_num] >= pins_for_byte_group &&
						r[:byte_group_3_pin_num] >= pins_for_byte_group
						count += 4
					end
				end
			end
		end

		push!(counts, count)
	end

	return counts
end
uber_table[:HR_DDR_BG_c1] = DDR_bytes_groups_per_cols(:HR, 1)
uber_table[:HR_DDR_BG_c2] = DDR_bytes_groups_per_cols(:HR, 2)
uber_table[:HR_DDR_BG_c3] = DDR_bytes_groups_per_cols(:HR, 3)
uber_table[:HR_DDR_BG_c4] = DDR_bytes_groups_per_cols(:HR, 4)
uber_table[:HP_DDR_BG_c1] = DDR_bytes_groups_per_cols(:HP, 1)
uber_table[:HP_DDR_BG_c2] = DDR_bytes_groups_per_cols(:HP, 2)
uber_table[:HP_DDR_BG_c3] = DDR_bytes_groups_per_cols(:HP, 3)
uber_table[:HP_DDR_BG_c4] = DDR_bytes_groups_per_cols(:HP, 4)
@assert sum(DDR_bytes_groups_per_cols(:HP, 5)) == 0

###############################################################################

function BG_to_B(BG)
	#TODO What if could make 6 bytes?
	if BG >= 11*4
		warn("Could set 4 DIMMs on one column?")
		return 8*4
	elseif BG >= 11*3
		return 8*3
	elseif BG >= 11*2
		return 8*2
	elseif BG >= 11
		return 8
	elseif BG >= 7
		return 4
	elseif BG >= 5
		return 2
	elseif BG >= 4
		return 1
	else
		return 0
	end
end

uber_table[:HR_DDR_B] = Vector{Int}(N_rows)
uber_table[:HP_DDR_B] = Vector{Int}(N_rows)
for r in eachrow(uber_table)
	r[:HR_DDR_B] = 
		BG_to_B(r[:HR_DDR_BG_c1]) +
		BG_to_B(r[:HR_DDR_BG_c2]) +
		BG_to_B(r[:HR_DDR_BG_c3]) +
		BG_to_B(r[:HR_DDR_BG_c4])
	r[:HP_DDR_B] = 
		BG_to_B(r[:HP_DDR_BG_c1]) +
		BG_to_B(r[:HP_DDR_BG_c2]) +
		BG_to_B(r[:HP_DDR_BG_c3]) +
		BG_to_B(r[:HP_DDR_BG_c4])
end
uber_table[:DDR_B] = uber_table[:HR_DDR_B] + uber_table[:HP_DDR_B]

###############################################################################

function BG_to_DIMM(BG)
	if BG >= 11*4
		warn("Could set 4 DIMMs on one column?")
		return 4
	elseif BG >= 11*3
		return 3
	elseif BG >= 11*2
		return 2
	elseif BG >= 11
		return 1
	else
		return 0
	end
end

N = size(uber_table)[1]
uber_table[:HR_DIMM] = Vector{Int}(N)
uber_table[:HP_DIMM] = Vector{Int}(N)
for r in eachrow(uber_table)
	r[:HR_DIMM] = 
		BG_to_DIMM(r[:HR_DDR_BG_c1]) +
		BG_to_DIMM(r[:HR_DDR_BG_c2]) +
		BG_to_DIMM(r[:HR_DDR_BG_c3]) +
		BG_to_DIMM(r[:HR_DDR_BG_c4])
	r[:HP_DIMM] = 
		BG_to_DIMM(r[:HP_DDR_BG_c1]) +
		BG_to_DIMM(r[:HP_DDR_BG_c2]) +
		BG_to_DIMM(r[:HP_DDR_BG_c3]) +
		BG_to_DIMM(r[:HP_DDR_BG_c4])
end
uber_table[:DIMM] = uber_table[:HR_DIMM] + uber_table[:HP_DIMM]

###############################################################################

uber_table[:cost_per_DDR_B] = uber_table[:price]./uber_table[:DDR_B]
uber_table[:cost_per_DIMM] = uber_table[:price]./uber_table[:DIMM]

###############################################################################

uber_table[:HR_DDR_MBps] = uber_table[:HR_DDR_B] .* uber_table[:HR_DDR_MTps]
uber_table[:HP_DDR_MBps] = uber_table[:HP_DDR_B] .* uber_table[:HP_DDR_MTps]
uber_table[:HR_DIMM_MBps] = 8*uber_table[:HR_DIMM] .* uber_table[:HR_DDR_MTps]
uber_table[:HP_DIMM_MBps] = 8*uber_table[:HP_DIMM] .* uber_table[:HP_DDR_MTps]

uber_table[:DDR_MBps] = uber_table[:HR_DDR_MBps] + uber_table[:HP_DDR_MBps]
uber_table[:DIMM_MBps] = uber_table[:HR_DIMM_MBps] + uber_table[:HP_DIMM_MBps]

###############################################################################

uber_table[:cost_per_DDR_MBps] = uber_table[:price]./uber_table[:DDR_MBps]
uber_table[:cost_per_DIMM_MBps] = uber_table[:price]./uber_table[:DIMM_MBps]

###############################################################################

# Save it just for documentation.
write_table("tmp/uber_table.xls", "uber_table", uber_table)

###############################################################################

# Select those who have needed stock.
uber_table = uber_table[uber_table[:stock_vs_need] .>= 0, :]

###############################################################################
# Cost per pin.

cost_per_pin = deepcopy(uber_table)
sort!(cost_per_pin, cols = :cost_per_pin)

if false
	# Cheapest from family:
	println("Cheapest Artix-7:")
	println(
		sort(
			cost_per_pin[cost_per_pin[:family] .== "Artix-7", :],
			cols = :price
		)[1, :]
	)
	println("Cheapest Kintex-7:")
	println(
		sort(
			cost_per_pin[cost_per_pin[:family] .== "Kintex-7", :],
			cols = :price
		)[1, :]
	)
	println("Cheapest Virtex-7:")
	println(
		sort(
			cost_per_pin[cost_per_pin[:family] .== "Virtex-7", :],
			cols = :price
		)[1, :]
	)

	write_table("tmp/cost_per_pin.xls", "cost_per_pin", cost_per_pin)
	println("Cheapers per pin:")
	best = cost_per_pin[1, :]
	println(best)
end

###############################################################################
# Cost per memory width.

cost_per_DDR_B = deepcopy(uber_table)
sort!(cost_per_DDR_B, cols = :cost_per_DDR_B)

cost_per_DIMM = deepcopy(uber_table[uber_table[:DIMM] .!= 0, :])
sort!(cost_per_DIMM, cols = :cost_per_DIMM)

###############################################################################
# Cost per memory bandwidth.

cost_per_DDR_MBps = deepcopy(uber_table)
sort!(cost_per_DDR_MBps, cols = :cost_per_DDR_MBps)

cost_per_DIMM_MBps = deepcopy(uber_table[uber_table[:DIMM] .!= 0, :])
sort!(cost_per_DIMM_MBps, cols = :cost_per_DIMM_MBps)

best_for_DDR_is_best_for_DIMM = 
	cost_per_DDR_MBps[1, :] == cost_per_DIMM_MBps[1, :]
	
@show best_for_DDR_is_best_for_DIMM

println("Best (cost per bandwidth):")
println(cost_per_DIMM_MBps[1, :])

###############################################################################

#TODO Check DSP performance and bandwidth with Wang ratio.

#TODO Check:
# + cost per pin
# + cost per pin bandwidth
# + cost per SO-DIMM badwidth (sharing common pins or not)
# - compare price with and without stock
# - cost with and without PCIe
# - without PCIe and user rest of SO-DIMM pins for parallel bus.

###############################################################################

println("End")

###############################################################################

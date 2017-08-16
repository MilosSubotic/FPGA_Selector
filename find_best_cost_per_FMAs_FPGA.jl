#!/usr/bin/env julia
###############################################################################

using Tables
using DataFrames

###############################################################################
# Config.

on_stock = true
#known_moq = false
#all_in_one_FPGA = true
known_moq = true
all_in_one_FPGA = false
# PCB, PSU...
fixed_cost = 0

LUTs_per_FMA = 835
DSPs_per_FMA = 2
needed_GFLOPS = 180

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

# Hack for having some FPGAs in pinout zips.
a = families["Artix-7"]["dev_pack_banks"]
a[("XC7A12T", "CPG236")] = a[("XC7A15T", "CPG236")]
a[("XC7A12T", "CSG325")] = a[("XC7A15T", "CSG325")]
a[("XC7A25T", "CPG236")] = a[("XC7A35T", "CPG236")]
a[("XC7A25T", "CSG325")] = a[("XC7A35T", "CSG325")]

N_rows = size(uber_table)[1]

#TODO Should make metric for PCB price depending on package.
# Then little larger FPGAs will be better.
cost = uber_table[:price] .+ fixed_cost

###############################################################################

uber_table[:Slices] = Vector{Int32}(N_rows)
uber_table[:DSPs] = Vector{Int32}(N_rows)
for r in eachrow(uber_table)
	sum_t = families[r[:family]]["summary"]
	i = findfirst(sum_t[:Device], r[:device])
	@assert i != 0
	r[:Slices] = sum_t[i, :Slices]
	r[:DSPs] = sum_t[i, :DSP]
end

uber_table[:LUTs] = uber_table[:Slices]*4

uber_table[:FMAs] = floor(
	min(
		uber_table[:LUTs]/LUTs_per_FMA,
		uber_table[:DSPs]/DSPs_per_FMA
	)
)

uber_table[:cost_per_FMA] = cost./uber_table[:FMAs]

uber_table[:GFLOPS] = Vector{Float64}(N_rows)
for r in eachrow(uber_table)
	#TODO Better
	if r[:family] == "Artix-7"
		FMA_GHz = 0.35
	else
		FMA_GHz = 0.4
	end
	r[:GFLOPS] = r[:FMAs]*FMA_GHz
end

###############################################################################

macro save(table)
	quote
		n = $(string(table))
		write_table("tmp/" * n * ".xlsx", n, $table)
	end
end

# Save it just for documentation.
@save uber_table

###############################################################################

# Select those who have needed stock.
if on_stock
	uber_table = uber_table[uber_table[:stock_vs_need] .>= 0, :]
end

# Select those who have known minimum order quantity.
if known_moq
	uber_table = uber_table[uber_table[:moq] .!= -1, :]
end

if all_in_one_FPGA
	uber_table = uber_table[uber_table[:GFLOPS] .>= needed_GFLOPS, :]
end

###############################################################################
# Cost per FMA.

cost_per_FMA = deepcopy(uber_table)
sort!(cost_per_FMA, cols = :cost_per_FMA)

if true
	# Cheapest from family:
	a = sort(
		cost_per_FMA[cost_per_FMA[:family] .== "Artix-7", :],
		cols = :price
	)
	if size(a)[1] > 0
		println("Cheapest Artix-7:")
		println(
			a[1, :]
		)
	end
	k = sort(
		cost_per_FMA[cost_per_FMA[:family] .== "Kintex-7", :],
		cols = :price
	)
	if size(k)[1] > 0
		println("Cheapest Kintex-7:")
		println(
			k[1, :]
		)
	end
	v = sort(
		cost_per_FMA[cost_per_FMA[:family] .== "Virtex-7", :],
		cols = :price
	)
	if size(v)[1] > 0
		println("Cheapest Virtex-7:")
		println(
			v[1, :]
		)
	end

	@save cost_per_FMA
	
	if size(cost_per_FMA)[1] > 0
		println("Cheapers per FMA:")
		best = cost_per_FMA[1, :]
		println(best)
	else
		println("No results!")
	end
end

###############################################################################

println("End")

###############################################################################

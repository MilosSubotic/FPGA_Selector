#!/usr/bin/env julia
###############################################################################

###############################################################################

const needed_quantity = 10

currencies_to_eur = Dict(
	"EUR" => 1,
	"GBP" => 1.1845,
	"USD" => 0.9576
)

###############################################################################

using Tables
using Octopart
using Iterators

###############################################################################

families = read_tables()

MPNs = []
for f in values(families)
	# Cartesian product.
	cp = product(f["devices"], f["speed_grades"], f["packages"])
	# Concat to MPN and collect.
	m = collect(map(prod, cp))
	append!(MPNs, m)
end



###############################################################################

println("End")

###############################################################################

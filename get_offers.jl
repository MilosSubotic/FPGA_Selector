#!/usr/bin/env julia
###############################################################################

needed_quantity = 10

currencies_to_eur = Dict(
	"EUR" => 1,
	"GBP" => 1.1845,
	"USD" => 0.9576
)

simple_speed_grades = true

###############################################################################

using Tables
using Octopart
using Iterators

###############################################################################

families = read_tables()

search_mpns = []
dev_speed_pack = []
for f in values(families)
	dpc = f["dev_pack_combs"][:dev_pack]
	if simple_speed_grades
		sg = f["simple_speed_grades"]
	else
		sg = f["speed_grades"]
	end
	# Cartesian product.
	cp = product(dpc, sg)
	# Concat to MPN and collect.
	m = collect(map((t) -> t[1][1] * t[2] * t[1][2] * "*", cp))
	append!(search_mpns, m)
	
	a = collect(map((t) -> (t[1][1], t[2], t[1][2]), cp))
	append!(dev_speed_pack, a)
end

offers = get_offers(
	search_mpns,
	needed_quantity,
	currencies_to_eur
)


###############################################################################

println("End")

###############################################################################

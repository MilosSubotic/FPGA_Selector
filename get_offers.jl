#!/usr/bin/env julia
###############################################################################
# Params.

needed_quantity = 10

#TODO Get from the internet.
currencies_to_eur = Dict(
	"EUR" => 1,
	"GBP" => 1.1845,
	"USD" => 0.9576
)

simple_speed_grades = false

###############################################################################

using Tables
using Octopart

###############################################################################

families = read_families()

println("Getting offers from Octopart...")

@time offers = get_offers_for_FPGAs(
	families,
	needed_quantity,
	currencies_to_eur,
	simple_speed_grades
)

println("Done!")

# Save offers with params to XLS.
write_table("tmp/offers.xls", "offers", offers)

###############################################################################

println("End")

###############################################################################

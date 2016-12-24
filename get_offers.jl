#!/usr/bin/env julia
###############################################################################

needed_quantity = 10

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

FPGA_families = read_tables()

offers = get_offers_for_FPGAs(
	FPGA_families,	
	needed_quantity,
	currencies_to_eur,
	simple_speed_grades
)

#TODO Save offers with params.

###############################################################################

println("End")

###############################################################################

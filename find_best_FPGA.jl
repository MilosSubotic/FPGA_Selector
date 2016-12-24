#!/usr/bin/env julia
###############################################################################

using Tables

###############################################################################

families = read_tables()

display(families["Artix-7"]["summary"])
display(families["Artix-7"]["devices"])
display(families["Artix-7"]["speed_grades"])
display(families["Artix-7"]["packages"])

###############################################################################

println("End")

###############################################################################

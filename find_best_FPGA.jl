#!/usr/bin/env julia
###############################################################################

using Tables

###############################################################################

families = read_tables()

display(families["Artix-7"]["summary"])
display(families["Artix-7"]["devices"])
display(families["Artix-7"]["speed_grades"])
display(families["Artix-7"]["packages"])
display(families["Artix-7"]["grouped_packages"])
display(families["Artix-7"]["pin_types"])
display(families["Artix-7"]["dev_pack_combs"])

###############################################################################

println("End")

###############################################################################

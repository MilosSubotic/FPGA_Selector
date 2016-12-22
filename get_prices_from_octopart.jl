#!/usr/bin/env julia
###############################################################################

const API_KEY="48a64d25"

###############################################################################

using Requests
using JSON

###############################################################################

mpn = "SN74S74N"
mpn = "XC7A200T-L1FB676I"
mpn = "XC7A*"

res = Requests.get(
	"http://octopart.com/api/v3/parts/match";
	query = Dict(
		"apikey" => API_KEY,
		"pretty_print" => true,
		#"queries" => JSON.json([Dict("mpn" => mpn)])
		"queries" => JSON.json([Dict("mpn" => "XC7A15*", "limit" => 20)])
	)
)
if res.status != 200
	critical_error_response = JSON.parse(String(res.data))
	println(critical_error_response["message"])
else
	part_match_response = JSON.parse(String(res.data))

	@show part_match_response["msec"]

	results = part_match_response["results"]
	@show length(results)

	for result in results
		@show length(result["items"])
	    for item in result["items"]
	        println(item["mpn"])
		end
	end
end

###############################################################################

println("End")

###############################################################################

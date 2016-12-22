#!/usr/bin/env julia
###############################################################################

const API_KEY="48a64d25"

###############################################################################

const quantity = 10

currencies_to_eur = Dict(
	"EUR" => 1,
	"GBP" => 1.1845,
	"USD" => 0.9576
)

###############################################################################

using Requests
using JSON

###############################################################################

mpn = "SN74S74N"
mpn = "XC7A200T-L1FB676I"
mpn = "XC7A*"

queries = [
	#Dict("mpn" => "XC7A12T*", "limit" => 20),
	#Dict("mpn" => "XC7A15T*", "limit" => 20),
	Dict("mpn" => "XC7A15T-1FTG256C", "limit" => 20)
]

res = Requests.get(
	"http://octopart.com/api/v3/parts/match";
	query = Dict(
		"apikey" => API_KEY,
		"pretty_print" => true,
		#"queries" => JSON.json([Dict("mpn" => mpn)])
		#"queries" => JSON.json([Dict("mpn" => "XC7A15*", "limit" => 20)])
		"queries" => JSON.json(queries)
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
	    	mpn = item["mpn"]
	        println(mpn)
	        
	        offers = item["offers"]
	        @show length(offers)
	        for offer in offers
	        	
	        	prices = offer["prices"]
	        	
	        	if length(prices) == 0
	        		continue
	        	end
	        	
	        	if !("EUR" in keys(prices))
		        	currency = first(keys(prices))
	        	else
		        	currency = "EUR"
	        	end
	        	cur_mul = currencies_to_eur[currency]
	        	

				om = offer["order_multiple"]
	        	if om != nothing && om != 1
	        		if om > quantity
	        			continue
	        		else
        				warn(
        					"One offer for ", mpn, 
        					" have order multiple of ", om
        				)
	        		end
	        	end
	        	
	        	if offer["moq"] > quantity
	        		continue
	        	end
	        	
        		q = offer["in_stock_quantity"]
        		if q != 0 && q < quantity
        			if q*2 >= quantity
        				warn(
        					"One offer for ", mpn, 
        					" have half of needed quantity."
        				)
        			else
        				continue
        			end
        		end
		    	
		    	p = nothing
		    	for bq_price in prices[currency]
			    	if bq_price[1] > quantity
			    		break
			    	end
			    	
			    	p = bq_price[2]
		    	end
		    	if p == nothing
		    		continue
		    	end
		    	price = parse(Float64, p) * cur_mul
		    	
	        	@show offer["sku"]
	        	@show offer["seller"]["name"]
		    	@show price
	        end
		end
	end
end

###############################################################################

println("End")

###############################################################################

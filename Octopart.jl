
module Octopart

	export get_offers

	###########################################################################

	const API_KEY="48a64d25"

	###########################################################################

	using Requests
	using JSON

	###########################################################################
	
	function get_offers(
		MPNs::Vector,
		needed_quantity::Integer,
		currencies_to_eur::Dict
	)

		queries = map(
			(s) -> Dict("mpn" => s, "limit" => 20),
			MPNs
			
		)
		#TODO Chunked requests.
		queries = queries[1:20]

		res = Requests.get(
			"http://octopart.com/api/v3/parts/match";
			query = Dict(
				"apikey" => API_KEY,
				"pretty_print" => true,
				"queries" => JSON.json(queries)
			)
		)
		if res.status != 200
			critical_error_response = JSON.parse(String(res.data))
			error(
				"Failed to obtain offers from octopart: ",
				critical_error_response["message"]
			)
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
							if om > needed_quantity
								continue
							else
								warn(
									"One offer for ", mpn, 
									" have order multiple of ", om
								)
							end
						end
						
						if offer["moq"] > needed_quantity
							continue
						end
					
						p = nothing
						for bq_price in prices[currency]
							if bq_price[1] > needed_quantity
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
						@show offer["in_stock_quantity"]
						@show price
					end
				end
			end
		end
	end

	###########################################################################

end # Octopart

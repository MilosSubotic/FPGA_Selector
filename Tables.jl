
module Tables

	export read_tables

	using Taro
	Taro.init()
	
	using DataArrays
	using DataFrames
	
	#TODO Make some max i.e. end for range coding, like small x or whatever.
	function read_and_clean_table(file_name, sheet, range)
		t = DataArray(Taro.readxl(file_name, sheet, range, header=false));
		t = t[Bool[!all(isna(t[r, :])) for r in 1:size(t)[1]], :]
		t = t[:, Bool[!all(isna(t[:, c])) for c in 1:size(t)[2]]]
		return t
	end

	function read_tables()
		xls_files = []
		for (r, d, f) in walkdir("tables/")
			for ff in f
				push!(xls_files, joinpath(r, ff))
			end
		end
		
		families = Dict{}()
		
		for fn in xls_files
			name = basename(fn)[1:end-length(".xls")]
						
			s = read_and_clean_table(fn, "Summary", "A3:N30")
			devices = s[:, 1][:] # Remove NAs.
			
			p = read_and_clean_table(fn, "Pins", "B1:ZZ2")
			packages = p[!isna(p[:])]
			# Grouped by compatibility.
			grouped_packages = []
			for c in 1:size(p)[2]
				gp = p[:, c][:]
				gp = gp[!isna(gp)] # Remove NAs.
				push!(grouped_packages, gp)
			end
			
			ms = read_and_clean_table(fn, "Memory_Speed", "B1:ZZ2")
			speed_grades = ms[!isna(ms[:])]
			simple_speed_grades = speed_grades[
				Bool[length(s) == 2 for s in speed_grades]
			]
			
			pt = read_and_clean_table(fn, "Pins", "B5:ZZ5")
			pt_per_p = Int(length(pt)/length(grouped_packages))
			pin_types = pt[1:pt_per_p]
			
			combs = read_and_clean_table(fn, "Pins", "B7:ZZ30")
			
			# First column is device-package combination.
			# Others columns are pin count for pin_types, respectively.
			dev_pack_combs = DataFrame()
			dev_pack_combs[:dev_pack] = []
			for pt in pin_types
				dev_pack_combs[Symbol(pt)] = []
			end
			for (c, gp) in enumerate(grouped_packages)
				for (r, d) in enumerate(devices)
					pc = combs[r, (c-1)*pt_per_p+1:c*pt_per_p]
					pc[isna(pc)] = 0
					if sum(pc) > 0
						for p in gp
							dp = (d, p)
							push!(dev_pack_combs, [dp; pc])
						end
					end
				end
			end
					
			tables = Dict(
				"summary" => s,
				"devices" => devices,
				"speed_grades" => speed_grades,
				"simple_speed_grades" => simple_speed_grades,
				"packages" => packages,
				"grouped_packages" => grouped_packages,
				"pin_types" => pin_types,
				"dev_pack_combs" => dev_pack_combs
			)
			
			families[name] = tables
			
		end
		
		families
	end
	
	#TODO Reading and writing prices.

end # Tables

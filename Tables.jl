
module Tables

	export read_tables

	using Taro
	Taro.init()
	
	using DataArrays
	
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
			devices = s[:, 1][:]
			p = read_and_clean_table(fn, "Pins", "B1:ZZ2")
			packages = p[!isna(p[:])]
			ms = read_and_clean_table(fn, "Memory_Speed", "B1:ZZ2")
			speed_grades = ms[!isna(ms[:])]
			tables = Dict(
				"summary" => s,
				"devices" => devices,
				"speed_grades" => speed_grades,
				"packages" => packages,
			)
			
			families[name] = tables
			
		end
		
		families
	end
	
	#TODO Reading and writing prices.

end # Tables

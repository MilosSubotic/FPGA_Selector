
module Tables

	export
		read_families,
		write_table,
		read_table


	using Taro
	Taro.init()

	using DataArrays
	using DataFrames
	using ZipFile


	#TODO Make some max i.e. end for range coding, like small x or whatever.
	function read_and_clean_table(file_name, sheet, range)
		t = DataArray(Taro.readxl(file_name, sheet, range, header=false));
		t = t[Bool[!all(isna(t[r, :])) for r in 1:size(t)[1]], :]
		t = t[:, Bool[!all(isna(t[:, c])) for c in 1:size(t)[2]]]
		return t
	end

	function parse_csv_file(f)
		# Bank table.
		bt = DataFrame(
			bank = [],
			pin_type = [],
			pin_num = [],
			byte_group_0_pin_num = [],
			byte_group_1_pin_num = [],
			byte_group_2_pin_num = [],
			byte_group_3_pin_num = [],
		)

		# Read pin stuff.
		ls = readlines(f)
		for l in ls[4:end-2]
			r = split(l, ',')
			bank = r[4]
			byte_group = r[3]
			pin_type = r[7]

			if !(bank in bt[:bank])
				push!(bt, [bank; pin_type; 0; 0;0;0;0])
			end
			i = findfirst(bt[:bank], bank)
			@assert i != 0

			if pin_type != "NA"
				bt[i, :pin_type] = pin_type
			end
			bt[i, :pin_num] += 1

			if byte_group != "NA"
				byte_group = parse(Int, byte_group)
			end
			if byte_group == 0
				bt[i, :byte_group_0_pin_num] += 1
			elseif byte_group == 1
				bt[i, :byte_group_1_pin_num] += 1
			elseif byte_group == 2
				bt[i, :byte_group_2_pin_num] += 1
			elseif byte_group == 3
				bt[i, :byte_group_3_pin_num] += 1
			end
		end

		return f.name, bt
	end

	function read_families()
		xls_files = []
		for (r, d, f) in walkdir("families/")
			for ff in f
				if endswith(ff, ".xls")
					push!(xls_files, joinpath(r, ff))
				end
			end
		end

		families = Dict{}()

		for xls_fn in xls_files
			name = basename(xls_fn)[1:end-length(".xls")]

			#TODO Headers.
			hs = read_and_clean_table(xls_fn, "Summary", "A1:Z100")
			h = hs[1, :][:]
			s = hs[2:end, :]

			c = size(s)[2]
			summary = DataFrame(Dict(zip(1:c, [s[:, i] for i in 1:c])))
			function prepare(s)
				s = replace(s, " ", "_")
				s = replace(s, "(", "_")
				s = replace(s, ")", "")
				s = replace(s, "/", "")
				if isnumber(s[1])
					s = "_" * s
				end
				return s
			end
			n = map(prepare, Vector(h))
			sn = Symbol[parse(nn) for nn in n]
			names!(summary.colindex, sn)

			devices = s[:, 1][:]

			p = read_and_clean_table(xls_fn, "Pins", "B1:AZ2")
			packages = p[!isna(p[:])]
			# Grouped by compatibility.
			grouped_packages = []
			for c in 1:size(p)[2]
				gp = p[:, c][:]
				gp = gp[!isna(gp)] # Remove NAs.
				push!(grouped_packages, gp)
			end

			sg = read_and_clean_table(xls_fn, "Memory_Speed", "C1:Z2")
			speed_grades = sg[!isna(sg[:])]
			simple_speed_grades = speed_grades[
				Bool[length(s) == 2 for s in speed_grades]
			]
			
			ds = read_and_clean_table(xls_fn, "Memory_Speed", "B5:Z10")
			# pin_type -> speed_grade -> ddr_speed
			ddr_speeds = Dict{String, Dict{String, Int}}()
			for r in 1:size(ds)[1]
				pin_type = ds[r, 1]
				d = Dict{String, Int}()
				@assert size(sg)[2] == size(ds)[2]-1
				for c2 in 1:size(sg)[2]
					s = Int(ds[r, c2+1])
					for r2 in 1:size(sg)[1]
						speed_grade = sg[r2, c2]
						if !isna(speed_grade)
							d[speed_grade] = s
						end
					end
				end
				ddr_speeds[pin_type] = d
			end


			pt = read_and_clean_table(xls_fn, "Pins", "B5:AZ5")
			pt_per_p = Int(length(pt)/length(grouped_packages))
			pin_types = pt[1:pt_per_p]

			combs = read_and_clean_table(xls_fn, "Pins", "B7:AZ30")

			# First column is device-package combination.
			# Others columns are pin count for pin_types, respectively.
			dev_pack_pins = DataFrame()
			dev_pack_pins[:dev_pack] = []
			for pt in pin_types
				dev_pack_pins[Symbol(pt)] = []
			end
			for (c, gp) in enumerate(grouped_packages)
				for (r, d) in enumerate(devices)
					pc = combs[r, (c-1)*pt_per_p+1:c*pt_per_p]
					pc[isna(pc)] = 0
					if sum(pc) > 0
						for p in gp
							dp = (d, p)
							push!(dev_pack_pins, [dp; pc])
						end
					end
				end
			end
		 	
			# Key is device-package combination, value is table of banks.
			zip_fn = xls_fn[1:end-length(".xls")] * ".zip"
			fn_banks = Dict()
			if isfile(zip_fn)
				z = ZipFile.Reader(zip_fn)
					for f in z.files
						if endswith(f.name, ".csv")
							fn, bt = parse_csv_file(f)
							fn_banks[fn] = bt
						end
					end
				close(z)
			end
			dev_pack_banks = Dict()
			for d in devices
				for gp in grouped_packages
					found = true

					for p in gp
						dp = (d, p)
						if dp in dev_pack_pins[:dev_pack]
							# If there is combination,
							# then need to have csv file.
							found = false
							fn = lowercase(dp[1] * dp[2] * "pkg.csv")
							if haskey(fn_banks, fn)
								for p in gp
									dp = (d, p)
									dev_pack_banks[dp] = fn_banks[fn]
								end
								delete!(fn_banks, fn)
								found = true
								break # Next gp
							end
						end
					end
					
					if !found
						warn("Do not have banks info for device: ", d, 
							" packages: ", gp)
					end
				end
			end
			if length(fn_banks) != 0
				println("Not added dev-pack to bank data: ", keys(fn_banks))
			end


			tables = Dict(
				"summary" => summary,
				"devices" => devices,
				"speed_grades" => speed_grades,
				"simple_speed_grades" => simple_speed_grades,
				"ddr_speeds" => ddr_speeds,
				"packages" => packages,
				"grouped_packages" => grouped_packages,
				"pin_types" => pin_types,
				"dev_pack_pins" => dev_pack_pins,
				"dev_pack_banks" => dev_pack_banks
			)

			families[name] = tables

		end

		families
	end


	# Reading DataFrame per sheets to XLS with header as first row.
	function write_table(file_name, sheet, data_frame::DataFrame)
		w = Workbook()
		s = createSheet(w, sheet)

		r = createRow(s, 0)
		for ci in 1:size(data_frame)[2]
			c = createCell(r, ci-1)
			setCellValue(c, string(names(data_frame)[ci]))
		end

		for ri in 1:size(data_frame)[1]
			r = createRow(s, ri)
			for ci in 1:size(data_frame)[2]
				c = createCell(r, ci-1)
				setCellValue(c, data_frame[ri, ci])
			end
		end

		mkpath(dirname(file_name))

		write(file_name, w)
	end


	# Reading DataFrame per sheets to XLS with header as first row.
	function read_table(file_name, sheet)
		hf = read_and_clean_table(file_name, sheet, "A1:Z3000")
		h = hf[1, :][:]
		f = hf[2:end, :]

		c = size(f)[2]
		t = DataFrame(Dict(zip(1:c, [f[:, i] for i in 1:c])))
		n = Symbol[parse(hh) for hh in h]
		names!(t.colindex, n)

		return t
	end

end # Tables

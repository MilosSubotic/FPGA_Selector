
module Tables

	export
		read_families,
		write_table,
		read_table


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

		for fn in xls_files
			name = basename(fn)[1:end-length(".xls")]

			#TODO Headers.
			hs = read_and_clean_table(fn, "Summary", "A1:Z100")
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

			p = read_and_clean_table(fn, "Pins", "B1:AZ2")
			packages = p[!isna(p[:])]
			# Grouped by compatibility.
			grouped_packages = []
			for c in 1:size(p)[2]
				gp = p[:, c][:]
				gp = gp[!isna(gp)] # Remove NAs.
				push!(grouped_packages, gp)
			end

			ms = read_and_clean_table(fn, "Memory_Speed", "B1:Z2")
			speed_grades = ms[!isna(ms[:])]
			simple_speed_grades = speed_grades[
				Bool[length(s) == 2 for s in speed_grades]
			]

			pt = read_and_clean_table(fn, "Pins", "B5:AZ5")
			pt_per_p = Int(length(pt)/length(grouped_packages))
			pin_types = pt[1:pt_per_p]

			combs = read_and_clean_table(fn, "Pins", "B7:AZ30")

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
			dev_pack_banks = Dict()
			#TODO Iterate over dev_pack_pins to obtain device-package combination 
			# and push them as keys.
			# dev_pack_banks[dp] = DataFrame(:bank = [], :pin_type = [], :pin_num = [])
			# Open zip with ZipFile, iterater over files, parse all csv files, fill table.


			tables = Dict(
				"summary" => summary,
				"devices" => devices,
				"speed_grades" => speed_grades,
				"simple_speed_grades" => simple_speed_grades,
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

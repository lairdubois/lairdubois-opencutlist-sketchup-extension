module Ladb::OpenCutList
module BinPacking1D

	class Reader
	
	  attr_reader :saw_kerf, :trim_size, :std_bar_length, :parts, :leftovers

    def initialize(filename, debug=false)
    	
    	@filename = filename
    	@saw_kerf = 0
    	@trim_size = 0
    	@std_bar_length = 0
    	@parts = Hash.new
    	@leftovers = Array.new
    	@debug = debug
    end
    
    def readMM()
    	@part_count = 1
			File.open(@filename).each do |line|
				if matches = line.match(/^\s*\#.*$/) or matches = line.match(/^\s*$/)
					 next # glob line and go to next
				# matches saw_kerf, trimsize, std_bar_length
				# 3.2, 10, 13000
				elsif matches = line.match(/^==(.*)$/)
					break # from here on, nothing
				elsif matches = line.match(/^b\s*([0-9]*\.?[0-9]+)\s*$/)
					@leftovers << matches[1].to_f
				elsif matches = line.match(/^\s*([0-9]*\.?[0-9]+)\s*,\s*([0-9]*\.?[0-9]+)\s*,\s*([0-9]*\.?[0-9]+)\s*$/)
					@saw_kerf = matches[1].to_f
					@trimsize = matches[2].to_f
					@std_bar_length = matches[3].to_f
				# matches 
				# 2500 1250
				else matches = line.match(/^\s*([0-9]*\.?[0-9]+)\s*([0-9]*\.?[0-9]+)?\s*$/)
					l = matches[1].to_f
					c = matches[2].to_i
					c = 1 if c == 0
					(1..c).each do |i|
						@parts[@part_count] = l
						@part_count += 1
					end
				end
			end
			if @debug
				prt()
			end
		end
		
		def readJena()
			line_count = 0
			part_count = 1
			File.open(@filename).each do |line|
				if matches = line.match(/^\s*\#.*$/) or matches = line.match(/^\s*$/)
					next # glob line and go to next
				elsif matches = line.match(/^==(.*)$/)
					break # from here on, nothing
				end
				line_count += 1
				if line_count == 1
					# nothing
				elsif line_count == 2
					matches = line.match(/^\s*([0-9]*\.?[0-9]+)\s*$/)
					@std_bar_length = matches[1].to_f
				else
					matches = line.match(/^\s*([0-9]*\.?[0-9]+)\s*$/)
					l = matches[1].to_f
					@parts[part_count] = l
					part_count += 1
				end
			end
			if @debug
				prt()
			end
		end
		
		def prt()
			puts()
			print("filename       : #{'%12s' % @filename}\n")
			print("saw_kerf       : #{'%12.0f' % @saw_kerf}\n")
			print("trimming size  : #{'%12.0f' % @trim_size}\n")
			print("std bar length : #{'%12.0f' % @std_bar_length}\n")
			print("leftovers      : ", @leftovers.to_s, "\n")
			print("parts          : ", @parts.to_s, "\n")
			puts()
		end
	end

end
end
module Ladb
module OpenCutList

require_relative "packing1d"
require_relative "reader"

if !ARGV[0].empty?

	e = BinPacking1D::Packer.new(debug=true)
	
	r = BinPacking1D::Reader.new(ARGV[0],debug=false)
	r.readMM()
	
	e.saw_kerf = r.saw_kerf
	e.trim_size = r.trim_size
	e.std_bar_length = r.std_bar_length
	e.leftovers = r.leftovers
	e.bar_width = 100
	e.bar_height = 100
	max_time = 3 # if time exceeds this, abort computation

	err, nb_bars = e.pack(r.parts, max_time)
	case err
		when BinPacking1D::ERROR_NONE
			msg = "optimal solution found"
			e.result(msg, with_id=false)
		when BinPacking1D::ERROR_SUBOPT
			msg = "suboptimal solution maybe"
			e.result(msg,with_id=false)
		when BinPacking1D::ERROR_NO_BINS
			puts("no bins available")
		when BinPacking1D::ERROR_NO_PARTS
			puts("no parts to pack")
		when BinPacking1D::ERROR_TIME_EXCEEDED
			puts("time exceeded and no solution found")
		else
			puts("funky error", err)
		end
	end

end
end

module Ladb::OpenCutList::BinPacking1D

  class Bar

    attr_accessor :ids, :parts, :type
    
    def initialize(type, length, trimming_size, saw_kerf)

  		@length = length                   # raw length of bar
  		@trimming_size = trimming_size     # trimsize on both ends
  		@saw_kerf = saw_kerf               # width of saw kerf
  		@type = type                       # NEW, LEFTOVER, UNFIT
  		@ids = []                          # ids of placed parts
  		@parts = []                        # lengths of placed parts
    end
    
    def result(with_id=false)
    	tot_raw, tot_net, leftover = self.length()
    	case @type
    	when BT_NEW
				print(" NEW   [#{'%8.2f' % @length}]")
				print("#{'%8.2f' % tot_raw} /#{'%8.2f' % tot_net} /#{'%8.2f' % leftover} = ")
			when BT_LO
				print(" LO    [#{'%8.2f' % @length}]")
				print("#{'%8.2f' % tot_raw} /#{'%8.2f' % tot_net} /#{'%8.2f' % leftover} = ")
			when BT_UNFIT
				print(" UN [#{'%8.2f' % @length}]")
			end
			
			@parts.each_with_index do |l, i|
				if with_id then
					print("#{'%9.2f' % l} (#{'%3s' % @ids[i]})")
				else
					print("#{'%9.2f' % l}")
				end
			end
			print("\n")
			return @length, tot_raw, tot_net, leftover
    end
    
    def add(id, part)
    	@parts << part
    	@ids << id
    end
    
    def length()
    	if @type == BT_UNFIT
    		return @length
    	else
				net = 0
				used = 0
				if @trimming_size > 0
					used = 0 #@trimming_size + @saw_kerf
				end
				@parts.each do |l|
					net += l
				end
				used += (@parts.length()-1)*@saw_kerf + net
				if used > @length
					print("DANGER _ ERROR!\n")
					used = @length
				end
				leftover = @length - used
				return used, net, leftover
			end
    end
    
    def to_s()
    	print(@parts.to_s)
    end
      	    
  end
end
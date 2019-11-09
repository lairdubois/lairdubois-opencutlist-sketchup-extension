module Ladb::OpenCutList::BinPacking1D
  class Bar
    attr_accessor :ids, :length, :parts, :type

    def initialize(type, length, trim_size, saw_kerf)
      @length = length                   # raw length of bar
      @trim_size = trim_size             # trimsize on both ends
      @saw_kerf = saw_kerf               # width of saw kerf
      @type = type                       # NEW, LEFTOVER, UNFIT
      @ids = []                          # ids of placed parts
      @parts = []                        # lengths of placed parts
    end

    def result(with_id = false)
      tot_raw, tot_net, leftover = length
      case @type
      when BAR_TYPE_NEW
        print(" NEW   [#{format('%8.2f', @length)}]")
        print("#{format('%8s',tot_raw.to_l.to_s)} /#{format('%8s', tot_net.to_l.to_s)} /#{format('%8s', leftover.to_l.to_s)} = ")
      when BAR_TYPE_LO
        print(" LO    [#{format('%8.2f', @length)}]")
        print("#{format('%8s', tot_raw.to_l.to_s)} /#{format('%8s', tot_net.to_l.to_s)} /#{format('%8s',leftover.to_l.to_s)} = ")
      when BAR_TYPE_UNFIT
        print(" UN [#{format('%8.2f', @length)}]")
      end

      @parts.each_with_index do |l, i|
        if with_id
          print("#{format('%9s', l.to_l.to_s)} (#{format('%3s', @ids[i])})")
        else
          print("#{format('%9s', l.to_l.to_s)}")
        end
      end
      print("\n")
      [@length, tot_raw, tot_net, leftover]
    end

    def add(id, part)
      @parts << part
      @ids << id
    end

    def length
      if @type == BAR_TYPE_UNFIT
        @length
      else
        net = 0
        raw = 0
        raw = @trim_size + @saw_kerf if @trim_size > 0
        @parts.each do |l|
          net += l
        end
        raw += (@parts.length - 1) * @saw_kerf + net
        if raw > @length
          print('DANGER _ ERROR!\n')
          raw = @length
        end
        leftover = @length - raw
        [raw, net, leftover]
      end
    end

    def to_s
      print(@parts.to_s)
    end
  end
end

module Ladb::OpenCutList::BinPacking1D
  
  N_BYTES = [42].pack('i').size
  N_BITS = N_BYTES * 16
  MAX_INT = 2**(N_BITS - 2) - 1

  # Used by Timer for execution of algorithm
  class TimeoutError < StandardError
  end

  class Packer < Packing1D
    attr_accessor :boxes, :leftovers, :bins,
                  :unplaced_boxes, :total_nb_parts, :efficiency

    def initialize(options)
      super(options)

      @boxes = {}
      @leftovers = []

      @smallest = 0
      @total_nb_parts = 0
      @count = 0
      @nb_over_fiftypercent = 0
      @opt_nb_bars = MAX_PARTS

      @bins = []
      @unplaced_boxes = []

      @efficiency = 0
    end

    def run
      err = ERROR_NONE

      start_time = Time.now if @options.max_time

      remove_unfit()
      estimate_optimal()
      
      # split into chunks never larger than MAX_PARTS
      # otherwise computation may take forever or be interrupted by timer
      q = @boxes.each_slice(MAX_PARTS)

      best_bins = []
      best_bins_length = MAX_INT
      leftover_bars_length = 9999
      opt_found = false
      #
      # compute this t times with different epsilon's, keep the best
      #
      begin
        dbg("-> pack start")
        count = 1
        tuning = get_tuning(@options.tuning_level)
        tuning.each do |factor|
          # do not run with this factor if too large
          if @smallest*factor > @options.base_bin_length and @smallest*factor > @leftovers[0].length
            dbg("   factor leads to nonsense")
            next
          end
          dbg("\n   pass #{count} factor #{factor}\n")
          if @options.max_time && (Time.now - start_time > @options.max_time)
            dbg('BIG PROBLEM: hitting timeout... why?')
            raise(TimeoutError, 'timeout expired')
          end
          
          lclone = @leftovers.clone()
          qclone = q.clone()

          # attempt to use leftovers first
          if not lclone.empty?
            dbg("   using leftover #{lclone.length}")
            bins, err = pack_single(qclone, lclone, factor)
          else
            dbg("   cannot use leftover")
            bins, err = pack_single(qclone, [], factor)
          end
          dbg("-> after single packing, nb bins #{bins.length}, error #{err}")
          dbg("   optimal would be #{@opt_nb_bars}")
          if err == ERROR_NONE
            if bins.length <= @opt_nb_bars
              dbg("     [#{count}]: optimal solution, nb bins = #{bins.length}")
              opt_found = true
            else
              dbg("     [#{count}]: suboptimal solution, bars = #{bins.length}")
            end
            
            # after cutting we have some leftovers, pick the largest one
            # among the bins we have cut so far
            lo_bars = get_largest_leftover(bins)
            dbg("   max leftover size is #{lo_bars}")
            if bins.length < best_bins_length
              best_bins = bins
              best_bins_length = bins.length
              leftover_bars_length = lo_bars
              dbg("     [#{count}]: best bars #{bins.length}, max leftover size #{to_ls(leftover_bars_length)}")
            elsif (bins.length == best_bins_length) && (lo_bars > leftover_bars_length)
              best_bins = bins
              best_bins_length = bins.length
              leftover_bars_length = lo_bars
              dbg("     [#{count}]: equal best bars #{bins.length}, larger leftover #{lo_bars}")
            else
              dbg("     [#{count}]: not getting better\n")
            end
            count += 1
          elsif err == ERROR_NO_BIN
            dbg("   no more bins available #{err}")
            best_bins = bins
            #@boxes.each do |box|
            #  @unplaced_boxes << box
            #end
            #@boxes = []
          end
        end
      rescue StandardError
        err = ERROR_TIME_EXCEEDED if best_bins.empty?
      end
      @bins = best_bins
      dbg("-> total time = #{Time.now - start_time}")
      @bins.each do |bin|
        bin.boxes.each do |box|
          dbg("   should be removed #{box.length}")
          @boxes.delete(box)
        end
      end
      @unplaced_boxes = @boxes
      @boxes = []
      # check_optimality
      # check_leftover

      err = ERROR_SUBOPT if !opt_found && (err != ERROR_TIME_EXCEEDED)
      err
    end
    
    def remove_unfit()
      #
      # check if @boxes fit within either bins in @leftovers
      # or @options.base_bin_length
      #
      dbg("-> removing boxes too small to fit")
      good_parts = []
      available_lengths = []
      @leftovers.each do |bin|
        available_lengths << bin.length
      end
      available_lengths << @options.base_bin_length
      
      @boxes.each do |b|
        fits = false
        available_lengths.each do |l|
          if b.length <= (l - 2 * @options.trimsize - 2 * @options.saw_kerf)
            fits = true
            break
          end
        end
        if fits
          good_parts << b
        else
          @unplaced_boxes << b
        end
      end
      @boxes = good_parts
    end

    def estimate_optimal()
      #
      # compute basic statistics to estimate the number 
      # of bins needed
      #
      dbg("-> estimating optimal result")
      net_length = 0
      @smallest =  (MAX_INT*1.0)
      @nb_over_fiftypercent = 0
      @count = 0
      
      @boxes.each do |p|
        @total_nb_parts += 1
        net_length += p.length
        @count += 1
        @smallest = p.length if p.length < @smallest
        if p.length > 0.5 * (@options.base_bin_length - 2 * @options.trimsize - 2 * @options.saw_kerf)
          @nb_over_fiftypercent += 1
        end
      end

      # we may slightly overestimate the number of kerfs
      net_length += @options.saw_kerf * @count
      # optimal number of bars is computed from net length
      if @options.base_bin_length < EPS
        @opt_nb_bars = @total_nb_parts
      else
        @opt_nb_bars = (net_length / (@options.base_bin_length \
          - 2 * (@options.trimsize+ @options.saw_kerf))).ceil
        # the minimum number of bars will also be larger than the number of bars
        # that are longer than 50% of the base_bin_length
        @opt_nb_bars = [@nb_over_fiftypercent, @opt_nb_bars].max
      end

      dbg("   smallest box = #{to_ls(@smallest)}")
      dbg("   net length = #{to_ls(net_length)} in #{@opt_nb_bars} bars")
      dbg("   boxes over 50\% length: #{@nb_over_fiftypercent}")
    end

    # pack_single takes a single chunk q (of parts MAX_PARTS long)
    # a list of s and a factor
    def pack_single(q, lo, f)
      dbg("-> pack_single")
      bins = []

      # q are chunks of boxes, normally we only have one unless
      # we have more than MAX_PARTS
      q.each_with_index do |boxes, i|
        dbg(" > q loop #{i}, nb boxes #{boxes.length}")
        # remove all parts assigned to the last bin so far
        # and add them to the current group
        # this is only used when the input is split into at most
        # MAX_PARTS chunks. 
        if (i > 0) && !bars.empty?
          bin = bins.pop
          tmp = []
          #bar.parts.each_with_index do |_e, j|
          #  tmp << [bar.ids[j], bar.parts[j]]
          #end
          bin.boxes.each do |b|
            tmp << [b[:id], b[:length]]
          end
          p += tmp
        end
        # getting all the lengths of the boxes
        # from here on we work only with the lengths, not the 
        # boxes themselves
        lengths = []
        boxes.each do |b|
          lengths << b.length
        end
        dbg("   lengths = #{lengths}")
        
        until lengths.empty?
          dbg("-> parts placement loop")
          if lo.empty?
            dbg("   leftovers are empty")
            if @options.base_bin_length > EPS
              dbg("   making new bin")
              bin = Bin.new(@options.base_bin_length, BIN_TYPE_NEW , @options)
              s = bin.netlength()
              dbg("   making new bin with netlength = #{s}")
            else
              dbg("   no base_bin_length, running out of bins")
              return [bins, ERROR_NO_BIN]
            end
          else
            bin = lo.shift
            s = bin.netlength()
            dbg("   using leftover bin with netlength = #{s}")
          end
          
          # this is the core algorithm, finding subsetsums
          # of lengths that best match the target size s 
          y, y_list = allsubsetsums(lengths, s, f)

          # no fitting found
          if y.zero?
            lengths << bar if bin.type == BIN_TYPE_LO
            lengths = [] if lo.empty? && (@options.base_bin_length <= s)
          else
            # remove objects from p having the adequate lengths
            # and add them to the bin
            dbg("-> subsetsum found")
            dbg("   #{y_list}")
            y_list.each do |val|
              i = boxes.index { |x| x.length == val}
              if !i.nil?
                dbg("   found box at #{i} #{boxes[i].length}, #{boxes[i].data}")
                bin.add(boxes[i])
                d = boxes.delete_at(i)
                if d == nil
                  dbg("BIG PROBLEM: box is gone")
                end
                dbg("   boxes now has #{boxes.length} elements")
                lengths.delete_at(lengths.index(val) || lengths.length)
              end
            end
            bins << bin
          end
        end
      end
      [bins, ERROR_NONE]
    end

    def get_tuning(level)
      dbg("-> get_tuning #{level}")
      case level
      when 1
        [@smallest / 10, @smallest / 5, @smallest / 2,
         0, @smallest, @smallest * 2, @smallest * 5, @smallest * 10]
      when 2
        [@smallest / 10, 0]
      else
        [0]
      end
    end

    def check_optimality
      dbg("-> check optimality")
      bars = @bars.sort_by { |b| -b.parts.length }
      bars.each do |b|
        dbg(b.parts.to_s)
        b.result(false)
      end
    end

    # check a posteriori if leftovers can be used
    def check_leftover
      dbg("-> check leftover")
      return if @leftovers.empty?

      return if @options.base_bin_length < EPS

      raw, _net, _leftover = @bars[-1].all_lengths
      if !@leftovers.empty? && (raw <= @leftovers[0])
        @bars[-1].length = @leftovers[0]
        @bars[-1].type = BIN_TYPE_LO
        dbg("leftover can be used")
      end
    end

    # get the size of the largest leftover
    def get_largest_leftover(bins)
      dbg("-> get_largest_leftover from nb bins #{bins.length}")
      max_length = 0
      bins.each do |b|
        dbg("   checking bin for potential leftover")
        leftover = b.current_leftover
        max_length = [leftover, max_length].max
      end
      max_length
    end

    def prep_results
      dbg("-> preping results")
      length = 0
      waste = 0
      @bins.each do |b|
        length += b.length
        waste += b.current_leftover
      end
      @efficiency = (length - waste)/length.to_f
    end
    
    def allsubsetsums(x_list, target, epsilon)
      se = { 0 => [] }
      # sorting or not sorting here? let's not do it
      # x_list = x_list.sort_by {|e| -e}
      max = 0
      x_list.each do |x|
        te = {}
        se.sort.each do |y, y_list|
          next unless y + @options.saw_kerf + x <= target

          sk = @options.saw_kerf
          sk = 0 if y_list.empty?
          te.store(y + x + sk, y_list + [x])
          max = y + x + sk if y + x + sk > max
        end
        # merge te with se, resolve conflicts by
        # keeping the key with the least number of parts
        se.merge!(te) { |_k, v1, v2| v1.length < v2.length ? v1 : v2 }

        # the first max to reach the sum within a term of epsilon
        # (depending on the size of the smallest element) will
        # be returned. this avoids being too greedy!
        next unless max >= target - epsilon

        se = se.sort.to_h
        y = se.keys.last
        y_list = se.values.last
        return y, y_list
      end

      se = se.sort.to_h
      y = se.keys.last
      y_list = se.values.last

      [y, y_list]
    end
  end
end

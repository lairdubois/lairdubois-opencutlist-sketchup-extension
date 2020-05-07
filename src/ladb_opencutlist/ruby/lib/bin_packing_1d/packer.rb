module Ladb::OpenCutList::BinPacking1D
  
  N_BYTES = [42].pack('i').size
  N_BITS = N_BYTES * 16
  MAX_INT = 2**(N_BITS - 2) - 1

  # Used by Timer for execution of algorithm
  class TimeoutError < StandardError
  end

  class Packer < Packing1D
    attr_accessor :boxes, :leftovers, :bins, :unplaced_boxes, 
                  :total_nb_parts, :overall_efficiency

    def initialize(options)
      super(options)

      @boxes = []                   # boxes to pack
      @leftovers = []               # leftover bins to use first 

      @smallest = 0                 # the smallest box to pack
      @total_nb_boxes = 0           # total number of boxes to pack
      @nb_over_fiftypercent = 0     # proportion of boxes larger than 50% of net length
      @opt_nb_bins = MAX_PARTS      # optimal number of bins

      @bins = []                    # resulting bins containing boxes
      @unplaced_boxes = []          # boxes that could not be placed, lack of bins
      @unfit_boxes = []             # boxes that are rejected because too large!

      @overall_efficiency = 0       # proportion box lengths/total waste
    end
    
    def clone_split(boxes, leftovers)
      # TODO: fix for more than MAX_PARTS
      length = boxes.length
      boxes_clone = []
      if length < MAX_PARTS
        boxes_clone = boxes.clone()
      end
      leftovers_clone = []
      leftovers.each do |leftover|
        leftovers_clone << Bin.new(leftover.length, BIN_TYPE_LO, @options)
      end
      [[boxes_clone], leftovers_clone]
    end

    def run
      err = ERROR_NONE

      start_time = Time.now if @options.max_time

      remove_unfit()
      estimate_optimal()
      
      # split into chunks never larger than MAX_PARTS
      # otherwise computation may take forever or be interrupted by timer
      #q = @boxes.each_slice(MAX_PARTS)

      best_bins = []
      best_leftovers = []
      best_bins_count = MAX_INT            # best number of bins achieved so far
      leftover_box_length = MAX_INT        # leftover in a single box
      opt_found = false
      #
      # compute this t times with different epsilon's, keep the best
      #
      begin
        dbg("-> pack start")
        count = 0
        tuning = get_tuning(@options.tuning_level)
        tuning.each do |epsilon|
          dbg("-- pass using epsilons #{tuning}")
          count += 1  # keep nb of times we do this loop
          # get our copies of leftovers and boxes
          qclone, lclone = clone_split(@boxes, @leftovers)
          dbg("   data cloned")
          #
          # do not run with this epsilon if too large
          # epsilon determines how much waste we
          # are willing to leave at the end of a bin
          # this avoids that the algorithm becomes too greedy
          # and gets stuck with a less than optimal solution
          # The factors depend on the tuning level (very empirical!)
          # . a factor of 0 (zero) makes it greedy
          # . a factor much larger than the smallest box will miss placing small boxes
          #
          if epsilon > @options.base_bin_length
            if lclone.empty?
              dbg("   epsilon #{epsilon} leads to certain nonsense, larger than base bin")
              next
            elsif epsilon > lclone[0].length
              dbg("   epsilon #{epsilon} leads to certain nonsense, larger than leftover")
              next
            end
          end
          #
          # watchdog for excessive computation
          #
          if @options.max_time && (Time.now - start_time > @options.max_time)
            dbg('BIG PROBLEM: hitting timeout... why?')
            raise(TimeoutError, 'timeout expired')
          end
          
          # attempt to use leftovers first
          if not lclone.empty?
            dbg("   using leftover #{lclone.length}")
            bins, err = pack_single(qclone, lclone, epsilon)
          else
            dbg("   no leftovers to use")
            bins, err = pack_single(qclone, [], epsilon)
          end
          dbg("-> after single packing, nb bins #{bins.length}, error #{err}")
          dbg("   optimal nb of bins would be #{@opt_nb_bins}")
          if err == ERROR_NONE
            #
            # found a packing that fits, must now
            # compare to others
            #
            if bins.length <= @opt_nb_bins
              # not certain that this condition is sufficient
              dbg("     [#{count}]: optimal solution, nb bins = #{bins.length}")
              opt_found = true
            else
              dbg("     [#{count}]: suboptimal solution, bars = #{bins.length}")
            end
            
            # after cutting we have some leftovers, pick the largest one
            # among the bins we have cut so far
            lo_in_bin = get_largest_leftover(bins)
            dbg("   max leftover size is #{lo_in_bin}")

            if bins.length < best_bins_count
              # the best pick is the one with the least number of bins
              best_bins = bins
              best_leftovers = lclone
              best_bins_count = bins.length
              leftover_box_length = lo_in_bin
              dbg("     [#{count}]: best bars #{bins.length}, max leftover size #{to_ls(leftover_box_length)}")
            elsif (bins.length == best_bins_count) && (lo_in_bin > leftover_box_length)
              # second best choice is the one with the largest leftover
              best_bins = bins
              best_leftovers = lclone
              best_bins_count = bins.length
              leftover_box_length = lo_in_bin
              dbg("     [#{count}]: equal best bars #{bins.length}, larger leftover #{lo_in_bin}")
            else
              dbg("     [#{count}]: not getting better\n")
            end
          elsif err == ERROR_NO_BIN
            dbg("   no more bins available error=#{err}")
            best_bins = bins
            #@boxes.each do |box|
            #  @unplaced_boxes << box
            #end
            #@boxes = []
          end
        end
      rescue TimeoutError
        err = ERROR_TIME_EXCEEDED if best_bins.empty?
      end
      @bins = best_bins
      @leftovers = best_leftovers
      dbg("-> total time = #{Time.now - start_time}")
      @bins.each do |bin|
        bin.boxes.each do |box|
          #dbg("   should be removed #{box.length}")
          @boxes.delete(box)
        end
      end

      @unplaced_boxes = @boxes + @unfit_boxes
      @boxes = []

      err = ERROR_SUBOPT if !opt_found && (err != ERROR_TIME_EXCEEDED)
      if err == ERROR_NONE or err == ERROR_SUBOPT 
        prep_results()
      end

      err
    end
    
    def remove_unfit()
      #
      # check if @boxes fit within either bins in @leftovers
      # or @options.base_bin_length
      #
      dbg("-> removing boxes too small to fit")
      good_parts = []
      # compute all lengths available
      available_lengths = []
      @leftovers.each do |bin|
        available_lengths << bin.length
      end
      available_lengths << @options.base_bin_length
      
      @boxes.each do |box|
        fits = false
        available_lengths.each do |len|
          # boxes need to fit into this!
          if box.length <= (len - 2 * @options.trimsize - 2 * @options.saw_kerf)
            fits = true
            break
          end
        end
        if fits
          good_parts << box
        else
          dbg("   unfit #{box.length}")
          @unfit_boxes << box
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
      nb_cuts = 0
      @boxes.each do |p|
        @total_nb_boxes += 1
        net_length += p.length
        nb_cuts += 1
        @smallest = p.length if p.length < @smallest
        if p.length > 0.5 * (@options.base_bin_length - 2 * @options.trimsize - 2 * @options.saw_kerf)
          @nb_over_fiftypercent += 1
        end
      end

      # we may slightly overestimate the number of kerfs
      net_length += @options.saw_kerf * nb_cuts
      # optimal number of bars is computed from net length
      if @options.base_bin_length < EPS
        @opt_nb_bins = @total_nb_boxes
      else
        @opt_nb_bins = (net_length / (@options.base_bin_length \
          - 2 * (@options.trimsize+ @options.saw_kerf))).ceil
        # the minimum number of bars will also be larger than the number of bars
        # that are longer than 50% of the base_bin_length
        @opt_nb_bins = [@nb_over_fiftypercent, @opt_nb_bins].max
      end

      dbg("   smallest box = #{to_ls(@smallest)}")
      dbg("   net length = #{to_ls(net_length)} in #{@opt_nb_bins} bins")
      dbg("   boxes over 50\% length: #{@nb_over_fiftypercent}")
    end

    def pack_single(q, lo, epsilon)
      #
      # pack_single takes a single chunk q (of parts MAX_PARTS long)
      # a list of s and a factor
      #
      dbg("-> pack_single")
      bins = []

      # q are chunks of boxes, normally we only have one unless
      # we have more than MAX_PARTS
      #dbg("**** #{q.length}")
      q.each_with_index do |boxes, i|
      
        dbg(" > q loop #{i}, nb boxes #{boxes.length}")
        #
        # remove all boxes assigned to the last bin so far
        # and add them to the current group
        # this is only used when the input is split into
        # more than one chunk of at most MAX_PARTS boxes 
        # we do this to prevent an almost empty last bin
        # of the first chunk.
        #
        if (i > 0) && !bins.empty?
          bin = bins.pop
          boxes += bin.boxes
        end
        # getting all the lengths of the boxes
        # from here on we work only with the lengths, not the 
        # boxes themselves
        lengths = []
        boxes.each do |box|
          lengths << box.length
        end
        dbg("   lengths to fit in this chunk = #{lengths}")
        
        until lengths.empty?
          dbg("-> parts placement loop")
          if lo.empty?
            dbg("   leftovers are empty")
            if @options.base_bin_length > EPS
              bin = Bin.new(@options.base_bin_length, BIN_TYPE_NEW , @options)
              s = bin.netlength()
              dbg("   making new standard bin with netlength = #{s}")
            else
              dbg("   no base_bin_length, running out of bins")
              #
              # returning what we have found so far
              # all placed boxes are in the bins
              return [bins, ERROR_NO_BIN]
            end
          else
            # 
            # take the next leftover bin and clone it!
            #
            bin = lo.shift
            bin = bin.clone()
            s = bin.netlength()
            dbg("   using leftover bin with netlength = #{s}")
          end
          
          # this is the core algorithm, finding subsetsums
          # of lengths that best match the target size s 
          y, y_list = allsubsetsums(lengths, s, epsilon)

          if y.zero?
            #
            # no fitting found FIX ME!
            #
            lengths << bar if bin.type == BIN_TYPE_LO
            lengths = [] if lo.empty? && (@options.base_bin_length <= s)
          else
            # 
            # remove objects from p having the adequate lengths
            # and add them to the bin
            dbg("-> subsetsum found #{y_list}")
            y_list.each do |found_length|
              # 
              # get index of first element having a matching lengths
              # TODO: precision definition, make sure we are not missing
              # a box because of precision
              #
              i = boxes.index { |x| (x.length - found_length).abs < EPS}
              if !i.nil?
                dbg("   found box at #{i} #{boxes[i].length}, #{boxes[i].data}")
                bin.add(boxes[i])
                d = boxes.delete_at(i)
                if d == nil
                  dbg("BIG PROBLEM: box is gone")
                end
                dbg("   to be placed boxes has #{boxes.length} elements")
                #
                # remove this length (found_length) from the ones we
                # are looking for
                #
                lengths.delete_at(lengths.index(found_length) || lengths.length)
              end
            end
            #
            # add this completed bin to the bins
            #
            bins << bin
          end
        end
      end
      #
      # we now have bins, but what about the boxes that could not be
      # placed
      #
      [bins, ERROR_NONE]
    end

    def get_tuning(level)
      #
      # almost completely arbitrary factors to avoid
      # subset sum to be too greedy
      #
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

    def check_leftover
      # check a posteriori if leftovers can be used
      # TODO remove because unused
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

    def get_largest_leftover(bins)
      #
      # get the length of the largest leftover among all bins
      #
      dbg("-> get_largest_leftover from nb bins #{bins.length}")
      max_length = 0
      bins.each do |b|
        leftover = b.current_leftover
        max_length = [leftover, max_length].max
      end
      max_length
    end

    def prep_results
      #
      # called from packengine to finish preparing results
      #
      dbg("-> preping results")
      length = 0
      waste = 0
      @bins.each do |bin|
        length += bin.length
        waste += bin.current_leftover
        start = bin.trimsize
        bin.boxes.each do |box|
          box.x = start
          start = start + box.length + bin.saw_kerf
        end
      end
      @overall_efficiency = (length - waste)/length.to_f
      
      dbg("-> done preping results")
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

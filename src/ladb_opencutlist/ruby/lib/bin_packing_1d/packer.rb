module Ladb::OpenCutList::BinPacking1D
  
  # number of bytes of computer running code
  # from https://gist.github.com/pithyless/9738125
  N_BYTES = [42].pack('i').size
  
  # number of bits
  N_BITS = N_BYTES * 16
  
  # largest integer on this platform
  MAX_INT = 2**(N_BITS - 2) - 1

  # 
  # Error used by Timer when execution of algorithm
  # takes too long (defined in Option).
  #
  class TimeoutError < StandardError
  end

  #
  # Core computing for 1D Bin Packing.
  #
  class Packer < Packing1D
  
    # boxes to be packed.
    attr_reader :boxes
    
    # leftover bins to use first. These are used first
    # even if this does not lead to an optimal solution.
    attr_reader :leftovers
    
    # resulting bins containing boxes.
    attr_reader :bins
    
    # boxes that could not be packed into bins, because
    # of a lack of bins/leftovers.
    attr_reader :unplaced_boxes
    
    #attr_accessor :total_nb_boxes
    
    # proportion box lengths/total waste
    attr_reader :overall_efficiency

    #
    # initialize a Packer object with options.
    #
    def initialize(options)
      super(options)

      @boxes = []
      @leftovers = []
      @bins = []
      
      @unplaced_boxes = []
      @overall_efficiency = 0
      @total_nb_boxes = 0           # total number of boxes to pack

      @unfit_boxes = []             # boxes that are rejected because too large!
      @smallest = 0                 # the smallest box to pack
      @nb_over_fiftypercent = 0     # proportion of boxes larger than 50% of net length
      @opt_nb_bins = MAX_PARTS      # optimal number of bins

    end
    
    #
    # add boxes to be packed. Should not be empty, but
    # no verification made here.
    #
    def add_boxes(boxes)
      @boxes = boxes
    end
    
    #
    # add leftovers/scrap bins. Possibly empty, in that
    # case @options.base_bin_length should be positive.
    #
    def add_leftovers(leftovers)
      @leftovers = leftovers
      if @leftovers.empty? and @options.base_bin_length < EPS
        raise(Packing1DError, "No leftovers and base_bin_length too small")
      end
    end
    
    # 
    # clones the boxes and leftovers for a single run.
    # Splits up boxes if contains more than MAX_PARTS,
    # in which case bin packing may take too much time.
    # 
    def clone_split(boxes, leftovers)
      length = boxes.length
      boxes_clone = []
      #
      # we don't need a deep clone of boxes, because they
      # will receive their position once the best packing
      # has be found.
      #
      if length < MAX_PARTS
        boxes_clone = [boxes.clone()]
      else
        boxes_clone = boxes.each_slice(MAX_PARTS).to_a
      end
      #
      # we absolutely need deep clones of leftovers!
      # because they will be changed during bin packing.
      #
      leftovers_clone = []
      leftovers.each do |leftover|
        leftovers_clone << Bin.new(leftover.length, BIN_TYPE_LO, @options)
      end
      [boxes_clone, leftovers_clone]
    end

    #
    # run the bin packing optimization.
    #
    def run
      err = ERROR_NONE

      # not a super precise way of measuring compute time.
      start_time = Time.now

      remove_unfit()
      estimate_optimal()
      
      best_bins = []
      best_leftovers = []
      best_bins_count = MAX_INT            # best number of bins achieved so far
      best_bin_leftover_length = 0         # largest leftover in a single bin
      opt_found = false                    # only a hint, did we reach optimality?
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
          bclone, lclone = clone_split(@boxes, @leftovers)
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
          # watchdog for excessive computation time
          #
          if @options.max_time && (Time.now - start_time > @options.max_time)
            raise(TimeoutError, 'Timeout expired ...')
          end
          
          dbg("   using leftover #{lclone.length}")
          bins, err = pack(bclone, lclone, epsilon)

          dbg("-> after single packing, nb bins #{bins.length}, error #{err}")
          dbg("   optimal nb of bins would be #{@opt_nb_bins}")
          if err == ERROR_NONE
            #
            # found a packing that fits, must now compare to others.
            #
            if bins.length <= @opt_nb_bins
              # not certain that this condition is sufficient
              dbg("     [#{count}]: optimal solution, nb bins = #{bins.length}")
              opt_found = true
            else
              dbg("     [#{count}]: suboptimal solution, nb bins = #{bins.length}")
            end
            
            # after cutting we have some leftovers, pick the largest one
            # among the bins we have cut so far
            lo_in_bin = get_largest_leftover(bins)
            dbg("   max leftover size is #{lo_in_bin}")

            if bins.length < best_bins_count
              # using less than best_bins_count so far
              # this is the new best solution, keep a trace of it.
              best_bins = bins
              best_bins_count = bins.length
              best_leftovers = lclone
              best_bin_leftover_length = lo_in_bin
              dbg("     [#{count}]: best bins #{bins.length}, max leftover size #{to_ls(best_bin_leftover_length)}")
            elsif (bins.length == best_bins_count) && (lo_in_bin > best_bin_leftover_length)
              # second best choice is the one with the largest leftover in a bin.
              best_bins = bins
              best_bins_count = bins.length
              best_leftovers = lclone
              best_bin_leftover_length = lo_in_bin
              dbg("     [#{count}]: equal best bins #{bins.length}, larger leftover #{lo_in_bin}")
            else
              # no improvement, no need to remember this one.
              dbg("     [#{count}]: not getting better\n")
            end
          elsif err == ERROR_NO_BIN
            dbg("   no more bins available error=#{err}")
          end
        end
      rescue TimeoutError => err
        puts ("Rescued in Packer: #{err.inspect}")
        err = ERROR_TIME_EXCEEDED if best_bins.empty?
      rescue Packing1DError => err
        puts ("Rescued in Packer: #{err.inspect}")
        return ERROR_BAD_ERROR
      end
      
      # tidy up the best result so far
      @bins = best_bins
      @leftovers = best_leftovers
      dbg("-> total time = #{Time.now - start_time}")
      
      # remove from boxes all elements that have been
      # packed into bins.
      @bins.each do |bin|
        bin.boxes.each do |box|
          #dbg("   should be removed #{box.length}")
          @boxes.delete(box)
        end
      end

      # the remaining boxes and those which were not
      # considered in the first place.
      @unplaced_boxes = @boxes + @unfit_boxes
      
      @boxes = []

      if err < ERROR_SUBOPT
        prepare_results()
      else
        raise(Packing1DError, "Should never see this error = #{err} here!")
      end

      err
    end
    
    #
    # removes boxes that cannot possibly fit into a
    # leftover or base_bin_length.
    #
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
        available_lengths << bin.netlength
      end
      available_lengths << (@options.base_bin_length - 2 * @options.trimsize)
      
      @boxes.each do |box|
        fits = false
        available_lengths.each do |len|
          # boxes need to fit into this!
          if box.length <= len
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

    #
    # estimate the optimal number of bins, finds
    # the smallest box.
    # TODO: most of the computation is not necessary
    #
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
      # optimal number of bins is computed from net length
      if @options.base_bin_length < EPS
        @opt_nb_bins = @total_nb_boxes
      else
        @opt_nb_bins = (net_length / (@options.base_bin_length \
          - 2 * (@options.trimsize+ @options.saw_kerf))).ceil
        # the minimum number of bins will also be larger than the number of bins
        # that are longer than 50% of the base_bin_length
        @opt_nb_bins = [@nb_over_fiftypercent, @opt_nb_bins].max
      end

      dbg("   smallest box = #{to_ls(@smallest)}")
      dbg("   net length = #{to_ls(net_length)} in #{@opt_nb_bins} bins")
      dbg("   boxes over 50\% length: #{@nb_over_fiftypercent}")
    end

    #
    # takes a single chunk q (of parts MAX_PARTS long)
    # a list of s and a tuning level epsilon.
    #
    def pack(chunk, leftovers, epsilon)
      dbg("-> pack")
      bins = []

      # q are chunks of boxes, normally we only have one unless
      # we have more than MAX_PARTS
      #dbg("**** #{q.length}")
      chunk.each_with_index do |boxes, i|
      
        dbg(" > chunk loop #{i}, nb boxes #{boxes.length}")
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
        # getting all the lengths of the boxes.
        # from here on we work only with the lengths, not the 
        # boxes themselves.
        lengths = []
        boxes.each do |box|
          lengths << box.length
        end
        dbg("   lengths to fit in this chunk = #{lengths}")
        
        until lengths.empty?
          dbg("-> parts placement loop")
          if leftovers.empty?
            dbg("   leftovers are empty")
            if @options.base_bin_length > EPS
              bin = Bin.new(@options.base_bin_length, BIN_TYPE_NEW , @options)
              target_length = bin.netlength()
              dbg("   making new standard bin with netlength = #{target_length}")
            else
              dbg("   no base_bin_length, running out of bins")
              #
              # returning what we have found so far
              # all placed boxes are in the bins
              return [bins, ERROR_NO_BIN]
            end
          else
            # 
            # take the next leftover bin
            #
            bin = leftovers.shift
            target_length = bin.netlength()
            dbg("   using leftover bin with netlength = #{target_length}")
          end
          
          # this is the core algorithm, finding subsetsums
          # of lengths that best match the target size s 
          y, y_list = allsubsetsums(lengths, target_length, epsilon)

          if y.zero?
            #
            # should only happen if we have lenghths (boxes)
            # that cannot fit leftovers or base_bin_length.
            # but those were already removed prior to calling
            # this.
            #
            raise(Packing1DError, "Funky error in pack! please inspect")
          else
            # 
            # remove objects from bins having the adequate lengths
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
      # we now have bins, q still contains all boxes,
      # gets fixed by the receiver.
      #
      [bins, ERROR_NONE]
    end

    #
    # almost completely arbitrary sizes to avoid
    # subset sum to be too greedy!
    # case 2 gives quite good results.
    #
    def get_tuning(level)
      dbg("-> get_tuning #{level}")
      case level
      when 1
        [@smallest / 10, 0]
      when 2
        [@smallest / 10, @smallest / 5, @smallest / 2,
         0, @smallest, @smallest * 2, @smallest * 5, @smallest * 10]
      else
        [0]
      end
    end

    #
    # get the length of the largest leftover among bins.
    #
    def get_largest_leftover(bins)
      #
      # get the length of the largest leftover among all bins
      #
      dbg("-> get_largest_leftover from nb bins #{bins.length}")
      max_length = 0
      bins.each do |b|
        max_length = [b.current_leftover, max_length].max
      end
      max_length
    end

    #
    # prepare final results once solution found.
    #
    # TODO: sort the boxes inside the bins.
    #
    def prepare_results
      dbg("-> preping results")
      length = 0
      waste = 0
      @bins.each do |bin|
        length += bin.length
        waste += bin.current_leftover
        start = @options.trimsize
        bin.boxes.each do |box|
          box.x = start
          start = start + box.length + @options.saw_kerf
        end
      end
      @overall_efficiency = (length - waste)/length.to_f
      
      dbg("-> done preping results")
    end
    
    #
    # compute all subset sums given a list of 
    # lengths (x_list), a sum (target) and a 
    # positive epsilon which helps not being 
    # too greedy.
    #
    def allsubsetsums(x_list, target, epsilon)
      dbg("-> subsetsums target=#{target}, epsilon=#{epsilon}")
      se = { 0 => [] }
      # sorting or not sorting here? let's not do it
      # x_list = x_list.sort_by {|e| -e}
      max = 0
      x_list.each do |x|
        te = {}
        se.sort.each do |y, y_list|
          next unless y + @options.saw_kerf + x <= target
          if y_list.empty?
            sk = 0
          else
            sk = @options.saw_kerf
          end
          te.store(y + x + sk, y_list + [x])
          if y + x + sk > max and y + x + sk <= target
            max = y + x + sk
          end
        end
        # merge te with se, resolve conflicts by
        # keeping the key with the least number of parts
        se.merge!(te) { |_k, v1, v2| v1.length < v2.length ? v1 : v2 }

        # the first max to reach the sum within a term of epsilon
        # (depending on the size of the smallest element) will
        # be returned. this avoids being too greedy!
        if not(max >= target - epsilon)
          dbg("subsetsum found max = #{max}")
          next
        end
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

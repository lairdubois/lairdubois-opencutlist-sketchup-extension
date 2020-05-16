module Ladb::OpenCutList::BinPacking1D
  
  # Number of bytes of computer running code
  # from https://gist.github.com/pithyless/9738125
  N_BYTES = [42].pack('i').size
  
  # Number of bits
  N_BITS = N_BYTES * 16
  
  # Largest integer on this platform
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
  
    # Boxes to be packed.
    attr_reader :boxes
    
    # Leftover bins to use first. These are used first
    # even if this does not lead to an optimal solution.
    attr_reader :leftovers
    
    # Resulting bins containing boxes.
    attr_reader :bins
    
    # Boxes that could not be packed into bins, because
    # of a lack of bins/leftovers.
    attr_reader :unplaced_boxes
    
    # Leftover bins which have nave not been used
    attr_reader :unused_bins
    
    # Proportion box lengths/total waste
    attr_reader :overall_efficiency
    
    # Start time of the packing.
    attr_reader :start_time
    
    # Using algorithm
    attr_reader :algorithm

    #
    # Initialize a Packer object with options.
    #
    def initialize(options)
      super(options)

      @boxes = []
      @leftovers = []
      @bins = []
      
      @unplaced_boxes = []
      @unused_bins = []
      @overall_efficiency = 0
      @total_nb_boxes = 0           # total number of boxes to pack

      @unfit_boxes = []             # boxes that are rejected because too large!
      @smallest = 0                 # the smallest box to pack
      @algorithm = ALG_SUBSET_SUM
    end
    
    #
    # Add a box to be packed. Should not be empty, but
    # no verification made here.
    #
    def add_boxes(boxes)
      @boxes = boxes
      @total_nb_boxes = @boxes.length
    end
    
    #
    # Add leftovers/scrap bins. Possibly empty, in that
    # case @options.base_bin_length should be positive.
    #
    def add_leftovers(leftovers)
      @leftovers = leftovers
      if @leftovers.empty? and @options.base_bin_length < EPS
        raise(Packing1DError, "No leftovers and base_bin_length too small")
      end
    end
    
    # 
    # Clones the boxes and leftovers for a single run.
    # Splits up boxes if containing more than MAX_PARTS,
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
        # try to avoid having only small or only large parts
        # in the slices.
        index_half = (boxes.length/2).round + 1
        boxes = boxes.each_slice(index_half).to_a
        boxes.each do |slice|
          slice.reject!{|item| item.nil?}
        end
        boxes = boxes[0].zip(boxes[1]).flatten
        boxes_clone = boxes.each_slice(MAX_PARTS).to_a
        dbg("boxes clone length: #{boxes_clone.length}")
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
      @start_time = Time.now
      remove_unfit()
      best_bins = []
      #
      # compute this t times with different epsilon's, keep the best
      #
      if @boxes.length > MAX_PARTS
        dbg("-> First Fit Decreasing because more than #{MAX_PARTS}")
        err = first_fit_decreasing()
      else
        begin
          dbg("-> pack start")
          #sleep(15) # for tc_3
          dbg("-- pass using epsilons")
          # get our copies of leftovers and boxes
          bclone, lclone = clone_split(@boxes, @leftovers)
          dbg("   data cloned")
          #
          # watchdog for excessive computation time
          #
          if @options.max_time && (Time.now - @start_time > @options.max_time)
            raise(TimeoutError, 'Timeout expired ...')
          end

          dbg("   using leftover #{lclone.length}")
          bins, err = pack(bclone, lclone)

          dbg("-> after single packing, nb bins #{bins.length}, error #{err}")
          dbg("   optimal nb of bins would be #{@opt_nb_bins}")
          if err == ERROR_NONE
            dbg("   packed everything error=#{err}")
            # tidy up the best result so far
            @bins = bins
            @leftovers = lclone            
            # remove from boxes all elements that have been
            # packed into bins.
            #
            @bins.each do |bin|
              bin.boxes.each do |box|
                @boxes.delete(box)
              end
            end
            @unplaced_boxes = @boxes + @unfit_boxes
            @boxes = []
          elsif err == ERROR_NO_BIN
            if !bins.empty?
              dbg("   found some, but no more bins available error=#{err}")
              err = ERROR_SUBOPT
              @bins = bins
              @leftovers = lclone            
              @bins.each do |bin|
                bin.boxes.each do |box|
                  @boxes.delete(box)
                end
              end
              @unplaced_boxes = @boxes + @unfit_boxes
              @boxes = []              
            end
          end
        rescue TimeoutError => err
          puts ("Rescued in Packer: #{err.inspect}")
          err = first_fit_decreasing()
        rescue Packing1DError => err
          puts ("Rescued in Packer: #{err.inspect}")
          return ERROR_BAD_ERROR
        end
      end
      
      dbg("-> total time = #{Time.now - start_time}")
      prepare_results() if err <= ERROR_SUBOPT
      err
    end
    
    #
    # First Fit Decreasing algorithm for large number of boxes
    # or when hitting Timeout
    #
    def first_fit_decreasing()
      @algorithm = ALG_FFD
      @bins += @leftovers
      if @bins.empty?
        bin = Bin.new(@options.base_bin_length, BIN_TYPE_NEW , @options)
        @bins << bin
      end
      @boxes.each do |box|
        packed = false
        # box can be packed into one of the existing bins, first fit wins
        @bins.each do |bin|
          if box.length <= bin.current_leftover
            bin.add(box)
            packed = true
            break
          end
        end
        # box could not be packed, create new bin if allowed to
        if not packed
          if @options.base_bin_length > EPS
            dbg("creating new bin")
            bin = Bin.new(@options.base_bin_length, BIN_TYPE_NEW , @options)
            if box.length <= bin.current_leftover
              bin.add(box)
            else
              @unplaced_boxes << box
            end
            @bins << bin
          else
            @unplaced_boxes << box
          end
        end
      end
      nbins = []
      @bins.each do |bin|
        if bin.type == BIN_TYPE_LO and bin.boxes.length == 0
          @unused_bins << bin 
        else
          nbins << bin
        end
      end
      # make sure these two are empty
      @boxes = []
      @leftovers = []
      # remove bins that have not been used
      @bins = nbins
      if @unplaced_boxes.empty?
        return ERROR_SUBOPT
      else
        return ERROR_NO_BIN
      end
    end
    
    #
    # Removes boxes that cannot possibly fit into a
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
    # Takes a list of chunk (of parts MAX_PARTS long)
    # a list of leftovers and prepares packing.
    #
    def pack(chunk, leftovers)
      dbg("-> pack")
      bins = []

      # chunks of boxes, normally we only have one unless
      # we have more than MAX_PARTS.
      #
      chunk.each_with_index do |boxes, idx|
        using_std_bin = leftovers.empty?
        # slicing may add nil objects, remove them
        boxes.reject!{|item| item.nil?}
      
        dbg(" > chunk loop #{idx}, nb boxes #{boxes.length}")
        #
        # remove all boxes assigned to the last bin so far
        # and add them to the current group
        # this is only used when the input is split into
        # more than one chunk of at most MAX_PARTS boxes 
        # we do this to prevent an almost empty last bin
        # of the first chunk.
        #
        if (idx > 0) && !bins.empty?
          bin = bins.pop
          boxes += bin.boxes
        end
        #
        # getting all the lengths of the boxes.
        # from here on we work only with the lengths, not the 
        # boxes themselves.
        #
        lengths = []
        boxes.each do |box|
          lengths << box.length
        end
        dbg("   lengths to fit in this chunk = #{lengths}")
        #
        # run this loop until 
        # . lengths is empty
        # . or running out of bins
        #
        until lengths.empty?
          dbg("-> parts placement loop")
          if leftovers.empty?
            dbg("   leftovers are empty")
            if @options.base_bin_length > EPS
              bin = Bin.new(@options.base_bin_length, BIN_TYPE_NEW , @options)
              using_std_bin = true
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
          
          # filter lengths to match and sort by decreasing length
          valid_lengths = lengths.select{|el| el <= target_length}
          valid_lengths = valid_lengths.sort_by {|e| -e}

          if valid_lengths.empty? 
            if not using_std_bin
              @unused_bins << bin
              next
            else
              return [bins, ERROR_NONE]
            end
          end

          # this is the core algorithm, finding subsetsums
          # of lengths that best match the target size
          dbg("   valid length #{valid_lengths.length} smallest = #{valid_lengths.last}")
          
          if @total_nb_boxes > MAX_PARTS
            epsilon = 0.95*valid_lengths.last
          else
            epsilon = 0 
          end
          y, y_list = allsubsetsums(valid_lengths, target_length, @options.saw_kerf, epsilon)
          if y.zero?
            #
            # should only happen if we have a very wide
            # saw kerf and we cannot fit any box.
            # see tc_4.txt
            # returning whatever was found, not sure this really works!
            #
            dbg("   boxes, but no fit found")
            if using_std_bin
              return [bins, ERROR_NONE]
            end
            dbg("   using leftover #{bin.length}")
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
              #i = boxes.index { |x| (x.length - found_length).abs < EPS}
              i = boxes.index { |x| x.length == found_length}
              if !i.nil?
                dbg("   found box at #{i} #{boxes[i].length}, #{boxes[i].data}")
                bin.add(boxes[i])
                d = boxes.delete_at(i)
                if d == nil
                  raise(Packing1DError, "packer.pack box is gone")
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
    # Prepare final results once solution found.
    #
    def prepare_results
      dbg("-> preping results")
      
      net_used = 0
      length = 0
      @bins.each do |bin|
        bin.sort_boxes()
        net_used += bin.net_used
        length += bin.length
      end
      @bins = @bins.sort_by {|bin| -bin.efficiency}
      @overall_efficiency = net_used/length*100.0 if length != 0
      
      if @leftovers.length > 0
        @unused_bins += @leftovers
        puts("must fix non-empty leftovers")
      end
      dbg("-> done preping results")
    end
    
    #
    # Compute all subset sums given a list of 
    # lengths (x_list), a sum (target) and a 
    # positive epsilon which helps not being 
    # too greedy.
    #
    def allsubsetsums(x_list, target, saw_kerf, epsilon)
      dbg("-> subsetsums target=#{target}, epsilon=#{epsilon}")
      se = { 0 => [] }
      # sorting or not sorting here? let's dot it
      # tc_12 says yes!
      # x_list = x_list.sort_by {|e| -e}
      # moved to pack
      max = 0
      x_list.each do |x|
        te = {}
        dbg("   add #{x} to se = #{se}")
        se.each do |y, y_list|
          length = y_list.reduce(&:+).to_f + x + y_list.length*saw_kerf
          if length > target
            dbg("  #{y} rejected")
            next
          else
            dbg("   add y = #{y} length=#{length}")
            if y + x > max
              max = y + x
              dbg("   new max = #{max}")
            end
          end
          # new target that can be reached
          te.store(y + x, y_list + [x])
          dbg("   + #{te}")
          if @options.max_time && (Time.now - @start_time > @options.max_time)
            raise(TimeoutError, 'Timeout expired ...')
          end
        end
        # merge te with se, resolve conflicts by
        # keeping the key with the least number of parts
        se.merge!(te) { |_k, v1, v2| v1.length < v2.length ? v1 : v2 }
        dbg("   se merged = #{se}")
        # the first max to reach the sum within a term of epsilon
        # (depending on the size of the smallest element) will
        # be returned. this avoids being too greedy and doing
        # too much computation
        if max <= target and max >= target - epsilon
          return se.max_by{|k, v| k}
        end
      end
      
      dbg("   - solution -")
      return se.max_by{|k, v| k}
    end
  end
end

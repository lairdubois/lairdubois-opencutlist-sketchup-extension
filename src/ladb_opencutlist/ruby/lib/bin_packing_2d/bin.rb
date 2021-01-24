module Ladb::OpenCutList::BinPacking2D

  #
  # Implements a Bin for packing Boxes.
  #
  class Bin < Packing2D

    # Length and width of this bin.
    attr_reader :length, :width

    # Index of this bin, type (see packing2d).
    attr_reader :index, :type

    # List of leftovers.
    attr_reader :leftovers

    # Placeholder for all boxes placed into this bin.
    attr_reader :boxes

    # Placeholder for all guillotine cuts.
    #attr_reader :cuts

    # Statistics about this bin's packing.
    attr_reader :stat

    # Max. points for the bounding box of all packed boxes.
    # The lowest point is @options.trimsize, @options.trimsize.
    attr_reader :max_x, :max_y

    def initialize(length, width, type, options)
      super(options)

      @length = length
      @width = width
      @type = type

      # Index will be assigned later by set_index.
      @index = nil

      @leftovers = nil

      @boxes = []
      @cuts_h = []
      @cuts_v = []

      # Max. length and width of a box inside this bin.
      # Used for finding through cuts.
      @max_length = 0
      @max_width = 0

      @max_x = 0
      @max_y = 0

      @bounding_box_done = false

      @stat = {}
      @stat[:net_area] = 0
      @stat[:used_area] = 0
      @stat[:bbox_area] = 0
      @stat[:compactness] = 0
      @stat[:nb_placed_boxes] = 0
      @stat[:l_measure] = 0
      @stat[:nb_cuts] = 0
      @stat[:largest_leftover_area] = 0
      @stat[:longest_leftover] = 0
      @stat[:widest_leftover] = 0
      @stat[:total_length_cuts] = 0
      @stat[:efficiency] = 0
      @stat[:signature] = "not packed"
      @stat[:rank] = 0
    end

    #
    # Sets the index of this bin, increments and returns index.
    #
    def set_index(index)
      @index = index
      return index + 1
    end

    #
    # Remembers signature for packing.
    #
    def keep_signature(signature)
      @stat[:signature] = "[#{@length},#{@width}]-" + signature
    end

    def signature_to_readable
      if matches = @stat[:signature].match(/^(\[.*\])-(\d)\/(\d)\/(\d)\/(\d)\/(.*)$/)
        return "#{PRESORT[matches[2].to_i]} - #{SCORE[matches[3].to_i]} - #{SPLIT[matches[4].to_i]} - #{STACKING[matches[5].to_i]}"
      else
        return "no match found"
      end
    end

    #
    # Returns the efficiency of this bin's packing in [0, 100].
    #
    def efficiency
      return @stat[:efficiency]
    end

    #
    # Returns the total length of all cuts, excluding trimming cuts.
    #
    def total_length_cuts
      return @stat[:total_length_cuts]
    end

    #
    # Returns all horizontal and vertical cuts.
    #
    def cuts
      return @cuts_h + @cuts_v
    end

    #
    # Computes the scores in free leftovers for a given box.
    #
    def best_ranked_score(box)
      # Create a first leftover if none exists.
      if @leftovers.nil?
        @leftovers = []
        l = Leftover.new(@options.trimsize,
          @options.trimsize, @length - 2 * @options.trimsize,
          @width - 2 * @options.trimsize, 1, @options)
        @leftovers << l
        @max_length = l.length
        @max_width = l.width
        @stat[:net_area] = l.area
      end

      #dbg("   using bin id=#{@index}: length=#{@length}, width=#{@width}")

      # Loop over all leftovers and compute score for placing box.
      score = []
      i = 0
      while i < @leftovers.size
        score += @leftovers[i].score(@index, i, box)
        i += 1
      end

      # Sort by score, leftover_id ASC
      # scores have already been filtered in leftovers!
      # [leftover_index, s2, ROTATED, @level]
      # put in lowest score, lowest level
      if @options.stacking == STACKING_LENGTH
        return score.min_by { |s| [s[1], -s[2], s[3]]}
      else
        return score.min_by { |s| [s[1], s[2], s[3]]}
      end
    end

    #
    # Adds a cut to this bin.
    # TODO should we really check here in add_cut if two cuts are identical?
    #
    def add_cut(cut)
      if !cut.nil? && cut.valid?
        if cut.is_horizontal
          @cuts_h << cut
        else
          @cuts_v << cut
        end
      end
    end

    #
    # Adds a leftover to this bin.
    #
    def add_leftover(leftover)
      @leftovers << leftover if !leftover.nil? && leftover.valid?
    end

    #
    # Adds a box to this bin into leftover at position leftover_index.
    #
    def add_box(box, leftover_index, min_length, min_width)

      #dbg("   best bin=#{@index}, leftover_id=#{leftover_index} <= box #{box.length}, #{box.width}", true)

      # Consume leftover.
      selected_leftover = @leftovers.delete_at(leftover_index)

      # Split heuristic.
      box.set_position(selected_leftover.x, selected_leftover.y)
      if selected_leftover.split_horizontally_first?(box, min_length, min_width)
        new_leftovers, new_cuts, new_boxes =
          selected_leftover.split_horizontal_first(box.x + box.length, box.y + box.width, box)
      else
        new_leftovers, new_cuts, new_boxes =
          selected_leftover.split_vertical_first(box.x + box.length, box.y + box.width, box)
      end

      # Keep leftovers, add cuts and add boxes (may be unpacked superbox!)
      new_leftovers.each { |leftover| add_leftover(leftover) }
      new_cuts.each { |cut| add_cut(cut) }

      new_boxes.each do |new_box|
        @stat[:used_area] += new_box.area
        if @max_x < new_box.x + new_box.length
          @max_x = new_box.x + new_box.length
          @bounding_box_done = false
        end
        if @max_y < new_box.y + new_box.width
          @max_y = new_box.y + new_box.width
          @bounding_box_done = false
        end
        @boxes << new_box
      end
    end

    #
    # Collects information about this box's packing.
    #
    def summarize
      # Compute additional through cuts

      h_cuts = @cuts_h.select { |cut| (cut.x - @options.trimsize).abs <= EPS &&
        (@options.trimsize + cut.length - @max_x).abs <= EPS }
      h_cuts.map(&:mark_through)
      v_cuts = @cuts_v.select { |cut| (cut.y - @options.trimsize).abs <= EPS &&
        (@options.trimsize + cut.length - @max_y).abs <= EPS }
      v_cuts.map(&:mark_through)

      @stat[:nb_cuts] = @cuts_h.size + @cuts_v.size

      @stat[:nb_placed_boxes] = @boxes.size
      @stat[:total_length_cuts] = @cuts_h.inject(0) { |sum, cut| sum + cut.length } +
        @cuts_v.inject(0) { |sum, cut| sum + cut.length }
      @stat[:nb_leftovers] = @leftovers.size

      @stat[:bbox_area] = (@max_x - @options.trimsize)*(@max_y - @options.trimsize)

      if @stat[:bbox_area].abs > EPS
        @stat[:compactness] = @stat[:used_area]*100/@stat[:bbox_area]
      else
        @stat[:compactness] = MAX_INT
      end

      @leftovers.each do |leftover|
        #@stat[:l_measure] += Math.sqrt((leftover.x + leftover.length/2.0)**2 + (leftover.y + leftover.width/2.0)**2)*leftover.area
        # TODO check which measure is best
        #@stat[:l_measure] += (leftover.x + leftover.length + leftover.y + leftover.width)
        #@stat[:l_measure] += (leftover.x + leftover.length/2.0)/@max_length + (leftover.y + leftover.width/2.0)/@max_width
        #@stat[:l_measure] += (leftover.x + leftover.length/2.0)/@max_x + (leftover.y + leftover.width/2.0)/@max_y
        @stat[:longest_leftover] = [@stat[:longest_leftover], leftover.length].max
        @stat[:widest_leftover] = [@stat[:widest_leftover], leftover.width].max
        if leftover.x + leftover.length <= @max_x &&
          leftover.y + leftover.width <= @max_y
          @stat[:l_measure] += (leftover.x + leftover.length + leftover.y + leftover.width)
        #@stat[:l_measure] += (leftover.x)/@max_x + (leftover.y)/@max_y
          #@stat[:l_measure] += leftover.area * ((leftover.x + leftover.length/2) + (leftover.y + leftover.width/2))

        end
        @stat[:largest_leftover_area] = [@stat[:largest_leftover_area], leftover.area].max
      end

      @stat[:efficiency] = 100*@stat[:used_area]/@stat[:net_area]
    end

    #
    # Runs bounding box to find a possible spot to place box.
    # Returns true if a spot was found, false otherwise.
    #
    def bounding_box(box, finalbb)
      return if box.nil?
      return if @bounding_box_done

      # Make a dummy leftovers.
      lo = Leftover.new(0, 0, @length, @width, 1, @options)
      lo.trim

      # Split it two ways.
      leftovers_h, cuts_h = lo.split_horizontal_first(@max_x, @max_y)
      new_leftovers = []
      new_cuts = []

      # If box fits into this, do it!
      if box.fits_into_leftover?(leftovers_h[0]) || box.fits_into_leftover?(leftovers_h[1])
        new_leftovers = leftovers_h
        new_cuts = cuts_h
      else
        # Alternatively, try splitting vertically.
        leftovers_v, cuts_v = lo.split_vertical_first(@max_x, @max_y)
        if box.fits_into_leftover?(leftovers_v[0]) || box.fits_into_leftover?(leftovers_v[1])
          new_leftovers = leftovers_v
          new_cuts = cuts_v
        else
          return false
        end
      end

      new_cuts.map(&:mark_final) if finalbb

      # Shortens all cuts that go beyond the @max_x and @max_y point.
      # @max_x and @max_y are always updated when a box is added.
      # All cuts going through bounding box will be deleted.
      @cuts_h, _ = @cuts_h.partition { |cut| cut.resize_to(@max_x, @max_y) }
      @cuts_v, _ = @cuts_v.partition { |cut| cut.resize_to(@max_x, @max_y) }

      # Shortens all leftovers that go beyond @max_x and @max_y.
      # Drop some if they are outside the bounding box, they
      # have been produced by the bounding box cuts.
      @leftovers, _ = @leftovers.partition { |leftover| leftover.resize_to(@max_x, @max_y) }

      new_leftovers.each { |leftover| add_leftover(leftover) }
      new_cuts.each { |cut| add_cut(cut) }

      @bounding_box_done = true
      return true
    end

    #
    # Computes the bounding box of this bin, shortens the cuts
    # and the leftovers, adds new leftovers and new cuts.
    # At the same time, measure compactness
    # https://repository.asu.edu/attachments/111230/content/Li_Goodchild_Church_CompactnessIndex.pdf
    #
    def final_bounding_box
      # If we are stacking length, then we want the leftover to
      # be maximal in length first
      #if @options.stacking == STACKING_LENGTH
      @bounding_box_done = false
      if @max_length*(@max_width - @max_y) >= (@max_length - @max_x)*@max_width
        dummy1 = Box.new(@max_length, EPS, false, nil)
        dummy2 = Box.new(EPS, @max_width, false, nil)
      else
        dummy1 = Box.new(EPS, @max_width, false, nil)
        dummy2 = Box.new(@max_length, EPS, false, nil)
      end
      if !bounding_box(dummy1, true)
        if !bounding_box(dummy2, true)
          # Not a problem!
          # puts("can't make a bounding box!")
        end
      end
    end

    def to_str
      s = "bin : #{'%5d' % object_id} id = #{'%3d' % @index} [#{'%9.2f' % @length}, #{'%9.2f' % @width}], "
      s += "type = #{'%2d' % @type}, signature=#{@stat[:signature]}"
      return s
    end

    def to_term
      # Cannot use dbg, since previous bins have a different options object.
      puts("    " + to_str)
      @boxes.each do |box|
        puts("      " + box.to_str)
      end
      @cuts_h.each do |cut|
        puts("      " + cut.to_str)
      end
      @cuts_v.each do |cut|
        puts("      " + cut.to_str)
      end
      @leftovers.each do |leftover|
        puts("      " + leftover.to_str)
      end
    end

    def octave(f)
      f.puts("figure(#{@index+1});")
      f.puts("clf(#{@index+1});")
      f.puts("grey = [0.9, 0.9, 0.9];")
      f.puts("red = [0.82, 0.1, 0.26];")
      f.puts("blue = [0.36, 0.54, 0.66];")

      f.puts("rectangle(\"Position\", [0, 0, #{@length}, #{@width}], \"Facecolor\", green); # bin id #{@index}")
      @boxes.each do |box|
        f.puts(box.to_octave)
      end
      @cuts_h.each do |cut|
        f.puts(cut.to_octave)
      end
      @cuts_v.each do |cut|
        f.puts(cut.to_octave)
      end
      @leftovers.each do |leftover|
        f.puts(leftover.to_octave)
      end

      f.puts("hold on; plot(#{@max_x}, #{@max_y}, \"d\", \"color\", black, \"linewidth\", 2);")
      f.puts("axis(\"ij\");")
      f.puts("axis(\"image\");")
      s = "bin index=#{@index}"
      f.puts("title(\"#{s}\");")
      f.close
    end
  end
end

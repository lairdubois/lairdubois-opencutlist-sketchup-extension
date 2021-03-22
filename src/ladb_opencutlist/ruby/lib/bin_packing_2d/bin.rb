module Ladb::OpenCutList::BinPacking2D

  #
  # Implements a Bin for packing Boxes.
  #
  class Bin < Packing2D

    # Length and width of this Bin.
    attr_reader :length, :width

    # Index of this Bin, type (see packing2d).
    attr_reader :index, :type

    # List of Leftover s.
    attr_reader :leftovers

    # Placeholder for all Boxes placed into this Bin.
    attr_reader :boxes

    # Statistics about this Bin's packing.
    attr_reader :stat

    # Max. points for the bounding box of all packed Box es.
    # The lowest point is @options.trimsize, @options.trimsize.
    attr_reader :max_x, :max_y

    def initialize(length, width, type, options, index = 0)
      super(options)

      @length = length
      @width = width
      @type = type
      # Index gets assigned by packengine or packer.
      @index = index

      @leftovers = nil
      @boxes = []

      # Horizontal cuts
      @cuts_h = []
      # Vertical cuts
      @cuts_v = []

      # Max. length and width of a box inside this bin.
      # Used for finding through cuts.
      @max_length = 0
      @max_width = 0

      @max_x = 0
      @max_y = 0

      @bounding_box_done = false

      @stat = {}
      @stat[:net_area] = 0                   # area of the bin minus trimming
      @stat[:used_area] = 0                  # area of all packed boxes
      @stat[:bbox_area] = 0                  # area of the bounding box
      @stat[:efficiency] = 0                 # used_area/net_area

      @stat[:nb_packed_boxes] = 0            # nb of packed boxes in this bin
      @stat[:nb_leftovers] = 0               # nb of leftovers excluding outer leftovers
      @stat[:outer_leftover_area] = 0        # area of leftover outside of bounding box
      @stat[:largest_leftover_area] = 0      # area of largest leftover outside bounding box
      @stat[:largest_bottom_part] = 0        # largest full length bottom leftover

      @stat[:nb_cuts] = 0
      @stat[:nb_h_through_cuts] = 0
      @stat[:nb_v_through_cuts] = 0

      @stat[:length_cuts] = 0

      @stat[:l_measure] = 0
      @stat[:signature] = "not packed"
      @stat[:rank] = 0
    end

    #
    # Sets the index of this Bin, increments and returns index.
    #
    def set_index(index)
      @index = index
      index + 1
    end

    #
    # Remembers signature for packing.
    #
    def keep_signature(signature)
      @stat[:signature] = signature
    end

    #
    # Returns a readable string for our signature.
    #
    def signature_to_readable
      if matches = @stat[:signature].match(/^(\d)\/(\d)\/(\d)\/(\d)\/(.*)$/)
        "#{PRESORT[matches[1].to_i]} - #{SCORE[matches[2].to_i]} - " \
        "#{SPLIT[matches[3].to_i]} - #{STACKING[matches[4].to_i]}"
      else
        "no match found"
      end
    end

    #
    # Returns the efficiency of this Bin's packing in [0, 100].
    #
    def efficiency
      @stat[:efficiency]
    end

    #
    # Returns the total length of all Cuts, excluding trimming cuts.
    #
    def total_length_cuts
      @stat[:length_cuts]
    end

    #
    # Returns all horizontal and vertical cuts.
    #
    def cuts
      @cuts_h + @cuts_v
    end

    #
    # Computes the scores in free Leftovers for a given Box.
    #
    def best_ranked_score(box)
      # Create a first Leftover if none exists.
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

      # Loop over all Leftovers and compute score for placing Box.
      score = []
      i = 0
      while i < @leftovers.size
        score += @leftovers[i].score(i, box)
        i += 1
      end

      # Sort by score returned as [leftover_index, score, ROTATED/NOT, level]
      # . score ASC
      # . leftover_id ASC
      # . level of cut ASC
      # . rotated = false, then true
      score.min_by { |s| [s[1], s[0], s[3], s[2]] }
    end

    #
    # Adds a Cut to this Bin.
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
    # Adds a Leftover to this Bin.
    #
    def add_leftover(leftover)
      @leftovers << leftover if !leftover.nil? && leftover.useable?
    end

    #
    # Adds a box to this bin into leftover at position leftover_index.
    #
    def add_box(box, leftover_index)
      # Consume leftover.
      selected_leftover = @leftovers.delete_at(leftover_index)

      # Split heuristic.
      box.set_position(selected_leftover.x, selected_leftover.y)
      if selected_leftover.split_horizontally_first?(box)
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
    # Collects information about this Bin's packing.
    #
    def summarize
      # Compute additional through cuts (primary cuts into the bounding box).
      h_cuts = @cuts_h.select { |cut|
        (cut.x - @options.trimsize).abs <= EPS &&
          (@options.trimsize + cut.length - @max_x).abs <= EPS &&
          cut.y < @max_y
      }
      h_cuts.map(&:mark_through)
      v_cuts = @cuts_v.select { |cut|
        (cut.y - @options.trimsize).abs <= EPS &&
          (@options.trimsize + cut.length - @max_y).abs <= EPS &&
          cut.x < @max_x
      }
      v_cuts.map(&:mark_through)

      @stat[:nb_h_through_cuts] = h_cuts.size unless h_cuts.nil?
      @stat[:nb_v_through_cuts] = v_cuts.size unless v_cuts.nil?

      @stat[:nb_cuts] = @cuts_h.size + @cuts_v.size
      @stat[:length_cuts] = @cuts_h.inject(0) { |sum, cut| sum + cut.length } +
                            @cuts_v.inject(0) { |sum, cut| sum + cut.length }

      @stat[:nb_packed_boxes] = @boxes.size
      @stat[:nb_leftovers] = @leftovers.size
      @stat[:bbox_area] = (@max_x - @options.trimsize) * (@max_y - @options.trimsize)


      @leftovers.each do |leftover|
        # Compute l_measure over Leftovers inside the bounding box only!
        if leftover.x + leftover.length < @max_x + EPS && leftover.y + leftover.width < @max_y + EPS
          @stat[:l_measure] += (@max_x - leftover.x + leftover.length / 2.0 + @max_y - leftover.y + leftover.width / 2.0) * leftover.area
        else
          @stat[:largest_leftover_area] = [@stat[:largest_leftover_area], leftover.area].max
          if (leftover.length - @max_length).abs < EPS
            @stat[:largest_bottom_part] = leftover.area
          end
        end
      end
      # Normalize the l_measure
      @stat[:l_measure] = @stat[:l_measure] / (@stat[:bbox_area] * (@max_x + @max_y))

      @stat[:efficiency] = ((@stat[:used_area] * 100) / @stat[:net_area]).round(3)
    end

    #
    # Runs bounding box to find a possible spot to place Box.
    # Returns true if a spot was found, false otherwise.
    #
    def bounding_box(box, finalbb)
      return if box.nil?
      return if @bounding_box_done

      # Make a dummy Leftover.
      lo = Leftover.new(0, 0, @length, @width, 1, @options)
      lo.trim

      # Split it two ways.
      leftovers_h, cuts_h = lo.split_horizontal_first(@max_x, @max_y)
      new_leftovers = []
      new_cuts = []

      # If Box fits into this, do it!
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
      # All cuts going through the bounding box will be deleted.
      @cuts_h, _ = @cuts_h.partition { |cut| cut.resize_to(@max_x, @max_y) }
      @cuts_v, _ = @cuts_v.partition { |cut| cut.resize_to(@max_x, @max_y) }

      # Shortens all leftovers that go beyond @max_x and @max_y.
      # Drop some if they are outside the bounding box, they
      # have been produced by the bounding box cuts.
      @leftovers, _ = @leftovers.partition { |leftover| leftover.resize_to(@max_x, @max_y) }

      new_leftovers.each do |leftover|
        add_leftover(leftover)
        if finalbb && leftover.useable?
          @stat[:outer_leftover_area] += leftover.area
        end
      end
      new_cuts.each { |cut| add_cut(cut) }

      @bounding_box_done = true
      true
    end

    #
    # Computes the bounding box of this Bin, shortens the Cut s
    # and the Leftover s, adds new Leftover s and new Cut s.
    #
    def final_bounding_box
      very_small_dim = 0.000001
      @bounding_box_done = false
      # Make two dummy boxes that represent the leftovers after the bounding
      # box has been done. Select the combination giving the largest leftover area.
#      if @max_length * (@max_width - @max_y) >= (@max_length - @max_x) * @max_width
        dummy1 = Box.new(@max_length, very_small_dim, false, nil)
        dummy2 = Box.new(very_small_dim, @max_width, false, nil)
#      else
#        dummy1 = Box.new(very_small_dim, @max_width, false, nil)
#        dummy2 = Box.new(@max_length, very_small_dim, false, nil)
#      end

      if !bounding_box(dummy1, true)
        if !bounding_box(dummy2, true)
          # Not a problem!
          # puts("can't make a bounding box!")
        end
      end
    end

    #
    # Debugging!
    #
    def to_str
      "bin : #{"%5d" % object_id} id = #{"%3d" % @index} [#{"%9.2f" % @length}," \
      " #{"%9.2f" % @width}], type = #{"%2d" % @type}, signature=#{@stat[:signature]}"
    end

    #
    # Debugging!
    #
    def to_term
      # Cannot use dbg, since previous Bins have a different Options object.
      puts("    #{to_str}")
      @boxes.each do |box|
        puts("      #{box.to_str}")
      end
      @cuts_h.each do |cut|
        puts("      #{cut.to_str}")
      end
      @cuts_v.each do |cut|
        puts("      #{cut.to_str}")
      end
      @leftovers.each do |leftover|
        puts("      #{leftover.to_str}")
      end
    end

    #
    # Debugging!
    #
    def octave(f)
      f.puts("figure(#{@index + 1});")
      f.puts("clf(#{@index + 1});")
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

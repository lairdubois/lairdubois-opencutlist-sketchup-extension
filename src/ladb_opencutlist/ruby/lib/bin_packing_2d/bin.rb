# frozen_string_literal: true

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
      @cut_index = 0

      # Trimming cuts
      if @options.trimsize > 0
        c_h = Cut.new(0, @options.trimsize - @options.saw_kerf, @length, true, 0, 1)
        c_h.mark_trimming
        @cuts_h.push(c_h)
        c_v = Cut.new(@options.trimsize - @options.saw_kerf, @options.trimsize, @width - @options.trimsize, false, 0, 1)
        c_v.mark_trimming
        @cuts_v.push(c_v)
      end

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
      @stat[:longest_right_part] = 0         # longest full width right leftover

      @stat[:nb_cuts] = 0
      @stat[:nb_h_through_cuts] = 0
      @stat[:nb_v_through_cuts] = 0
      @stat[:h_together] = 0
      @stat[:v_together] = 0

      @stat[:length_cuts] = 0                # total length of cuts, excl. trimming cut

      @stat[:l_measure] = 0
      @stat[:signature] = 'not packed'
      @stat[:rank] = 0
    end

    #
    # Sets the index of this Bin, increments and returns index.
    #
    def update_index(index)
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
      if (matches = @stat[:signature].match(%r{^(\d)/(\d)/(\d)/(\d)/(.*)$}))
        "#{PRESORT[matches[1].to_i]} - #{SCORE[matches[2].to_i]} - " \
          "#{SPLIT[matches[3].to_i]} - #{STACKING[matches[4].to_i]}"
      else
        'no match found'
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
      all_cuts = @cuts_h + @cuts_v
      tcuts = all_cuts.select {|cut| cut.cut_type == TRIMMING_CUT }

      bcuts = all_cuts.select {|cut| cut.cut_type == BOUNDING_CUT }.sort_by!(&:index)
      i = 1
      bcuts.each do |cut|
        cut.set_index(i)
        i += 1
      end

      icuts = all_cuts.select {|cut| [INTERNAL_THROUGH_CUT, INTERNAL_CUT].include?(cut.cut_type) }.sort_by!(&:index)
      i = 1
      icuts.each do |cut|
        cut.set_index(i)
        i += 1
      end

      tcuts + bcuts + icuts
    end

    #
    # Checks whether at least one box would fit into a leftover
    #
    def any_fit_into_leftovers(boxes)
      boxes.each do |box|
        # This should probably never happen since superboxes have been
        # destroyed in the main loop, but one never knows!
        if box.is_a?(SuperBox)
          box.sboxes.each do |sbox|
            @leftovers.each do |leftover|
              return true if sbox.fits_into?(leftover.length, leftover.width)
            end
          end
        else
          @leftovers.each do |leftover|
            return true if box.fits_into?(leftover.length, leftover.width)
          end
        end
      end
      false
    end

    #
    # Computes the scores in free Leftovers for a given Box.
    #
    def best_ranked_score(box)
      # Create a first Leftover if none exists.
      if @leftovers.nil?
        @leftovers = []
        l = Leftover.new(@options.trimsize,
                         @options.trimsize, @length - (2 * @options.trimsize),
                         @width - (2 * @options.trimsize), 1, true, @options)
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
      return unless !cut.nil? && cut.valid?

      cut.set_index(@cut_index)
      @cut_index += 1

      if cut.is_horizontal
        @cuts_h << cut
      else
        @cuts_v << cut
      end
    end

    #
    # Adds a Leftover to this Bin.
    #
    def add_leftover(leftover)
      @leftovers << leftover if !leftover.nil? && leftover.usable?
    end

    #
    # Adds a box to this bin into leftover at position leftover_index.
    #
    def add_box(box, leftover_index)
      # Consume leftover.
      selected_leftover = @leftovers.delete_at(leftover_index)

      # Split heuristic.
      box.set_position(selected_leftover.x_pos, selected_leftover.y_pos)
      if selected_leftover.split_horizontally_first?(box)
        new_leftovers, new_cuts, new_boxes =
          selected_leftover.split_horizontal_first(box.x_pos + box.length, box.y_pos + box.width, box)
      else
        new_leftovers, new_cuts, new_boxes =
          selected_leftover.split_vertical_first(box.x_pos + box.length, box.y_pos + box.width, box)
      end

      # Keep leftovers, add cuts and add boxes (may be an unpacked superbox!)
      new_leftovers.each { |leftover| add_leftover(leftover) }
      new_cuts.each { |cut| add_cut(cut) }

      new_boxes.each do |new_box|
        @stat[:used_area] += new_box.area
        if @max_x < new_box.x_pos + new_box.length
          @max_x = new_box.x_pos + new_box.length
          @bounding_box_done = false
        end
        if @max_y < new_box.y_pos + new_box.width
          @max_y = new_box.y_pos + new_box.width
          @bounding_box_done = false
        end
        @boxes << new_box
      end
    end

    #
    # Merge cuts to produce through cuts
    #
    def merge_cuts
      cuts = @cuts_h.sort_by { |cut| [cut.y_pos, cut.x_pos] }
      new_cuts = []
      c1 = cuts.shift
      until c1.nil?
        c2 = cuts.shift
        if c2.nil?
          new_cuts << c1
          c1 = nil
        elsif (c1.y_pos - c2.y_pos).abs <= EPS && (c1.x_pos + c1.length - c2.x_pos).abs <= @options.saw_kerf + EPS
          c1.update_length(c1.length + @options.saw_kerf + c2.length)
        else
          new_cuts << c1
          c1 = c2
        end
      end
      @cuts_h = new_cuts

      cuts = @cuts_v.sort_by { |cut| [cut.x_pos, cut.y_pos] }
      new_cuts = []
      c1 = cuts.shift
      until c1.nil?
        c2 = cuts.shift
        if c2.nil?
          new_cuts << c1
          c1 = nil
        elsif (c1.x_pos - c2.x_pos).abs <= EPS && (c1.y_pos + c1.length - c2.y_pos).abs <= @options.saw_kerf + EPS
          c1.update_length(c1.length + @options.saw_kerf + c2.length)
        else
          new_cuts << c1
          c1 = c2
        end
      end
      @cuts_v = new_cuts
    end

    #
    # Return 1 if through cuts are together, 0 if they are not
    #
    def qualify_cuts(h_or_v_cuts, width)
      together = h_or_v_cuts.length
      if width
        cuts = h_or_v_cuts.map(&:y_pos)
        cuts.unshift(@options.trimsize)
        cuts.push(@max_y)
      else
        cuts = h_or_v_cuts.map(&:x_pos)
        cuts.unshift(@options.trimsize)
        cuts.push(@max_x)
      end
      cuts = cuts.each_cons(2).map { |a, b| b - a }
      seen = {}
      prev = 0
      cuts.each do |e|
        if seen.key?(e)
          if e != prev
            together = 0
            break
          end
        else
          seen[e] = 1
          prev = e
        end
      end
      together
    end

    #
    # Collects information about this Bin's packing.
    #
    def summarize
      # Compute additional through cuts (primary cuts into the bounding box).
      merge_cuts
      h_cuts = @cuts_h.select do |cut|
        (cut.x_pos - @options.trimsize).abs <= EPS &&
          (@options.trimsize + cut.length - @max_x).abs <= EPS &&
          cut.y_pos < @max_y
      end
      h_cuts.map(&:mark_through)
      @stat[:h_together] += qualify_cuts(h_cuts, true)

      v_cuts = @cuts_v.select do |cut|
        (cut.y_pos - @options.trimsize).abs <= EPS &&
          (@options.trimsize + cut.length - @max_y).abs <= EPS &&
          cut.x_pos < @max_x
      end
      v_cuts.map(&:mark_through)
      @stat[:v_together] += qualify_cuts(v_cuts, false)

      @stat[:nb_h_through_cuts] = h_cuts.size unless h_cuts.nil?
      @stat[:nb_v_through_cuts] = v_cuts.size unless v_cuts.nil?

      @stat[:nb_cuts] = @cuts_h.size + @cuts_v.size
      @stat[:length_cuts] = @cuts_h.inject(0) { |sum, cut| sum + cut.length } +
                            @cuts_v.inject(0) { |sum, cut| sum + cut.length }

      @stat[:nb_packed_boxes] = @boxes.size
      @stat[:nb_leftovers] = @leftovers.size
      @stat[:bbox_area] = (@max_x - @options.trimsize) * (@max_y - @options.trimsize)

      @leftovers.each do |leftover|
        @stat[:largest_leftover_area] = [@stat[:largest_leftover_area], leftover.area].max
        # Compute l_measure over Leftovers inside the bounding box only!
        if leftover.x_pos + leftover.length < @max_x + EPS && leftover.y_pos + leftover.width < @max_y + EPS
          @stat[:l_measure] += (@max_x - leftover.x_pos + (leftover.length / 2.0) +
            @max_y - leftover.y_pos + (leftover.width / 2.0)) * leftover.area
        else
          @stat[:largest_bottom_part] = leftover.area if (leftover.length - @max_length).abs < EPS
          @stat[:longest_right_part] = leftover.area if (leftover.width - @max_width).abs < EPS
        end
      end
      # Normalize the l_measure
      @stat[:l_measure] = @stat[:l_measure] / (@stat[:bbox_area] * (@max_x + @max_y))
      @stat[:efficiency] = ((@stat[:used_area] * 100) / @stat[:net_area]).round(4)
    end

    #
    # Runs bounding box to find a possible spot to place Box.
    # Returns true if a spot was found, false otherwise.
    #
    def bounding_box(box, finalbb)
      return if box.nil?
      return if @bounding_box_done

      # Make a dummy Leftover.
      lo = Leftover.new(0, 0, @length, @width, 1, true, @options)
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
        elsif !finalbb
          return false
        end
      end
      new_cuts.map(&:mark_final) if finalbb

      # Shortens all cuts that go beyond the @max_x and @max_y point.
      # @max_x and @max_y are always updated when a box is added.
      # All cuts going through the bounding box will be deleted.
      @cuts_h, = @cuts_h.partition { |cut| cut.resize_to(@max_x, @max_y) }
      @cuts_v, = @cuts_v.partition { |cut| cut.resize_to(@max_x, @max_y) }

      # Shortens all leftovers that go beyond @max_x and @max_y.
      # Drop some if they are outside the bounding box, they
      # have been produced by the bounding box cuts.
      @leftovers, = @leftovers.partition { |leftover| leftover.resize_to(@max_x, @max_y) }

      new_leftovers.each do |leftover|
        add_leftover(leftover)
        @stat[:outer_leftover_area] += leftover.area if finalbb && leftover.usable?
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
      if @max_length * (@max_width - @max_y) >= (@max_length - @max_x) * @max_width
        dummy1 = Box.new(@max_length, very_small_dim, false, nil, nil)
        dummy2 = Box.new(very_small_dim, @max_width, false, nil, nil)
      else
        dummy1 = Box.new(very_small_dim, @max_width, false, nil, nil)
        dummy2 = Box.new(@max_length, very_small_dim, false, nil, nil)
      end

      return if bounding_box(dummy1, true)

      bounding_box(dummy2, true)
      # Not a problem!
      # puts("can't make a bounding box!")
    end

    #
    # Mark leftovers to keep on bins.
    #
    def mark_keep
      @leftovers.each(&:mark_keep)
    end

    #
    # Debugging!
    #
    def to_str
      s = "bin: #{format('%5d', object_id)} , id = #{format('%3d', @index)}"
      s += "[#{format('%9.2f', @length)}, #{format('%9.2f', @width)}], "
      s + "type = #{format('%2d', @type)}, signature=#{@stat[:signature]}"
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
  end
end

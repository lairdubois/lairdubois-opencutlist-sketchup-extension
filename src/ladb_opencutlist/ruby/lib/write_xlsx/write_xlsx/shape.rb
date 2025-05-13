# -*- coding: utf-8 -*-
# frozen_string_literal: true

module Ladb::OpenCutList
module Writexlsx
  ###############################################################################
  #
  # Shape - A class for writing Excel shapes.
  #
  # Used in conjunction with WriteXLSX.
  #
  # Copyright 2000-2012, John McNamara, jmcnamara@cpan.org
  # Converted to ruby by Hideo NAKAMURA, nakamura.hideo@gmail.com
  #
  class Shape
    include Writexlsx::Utility

    attr_reader :edit_as, :drawing
    attr_reader :tx_box, :fill, :line, :format
    attr_reader :align, :valign, :anchor, :adjustments
    attr_accessor :name, :connect, :type, :id, :start, :end, :rotation
    attr_accessor :flip_h, :flip_v, :palette, :text, :stencil
    attr_accessor :row_start, :row_end, :column_start, :column_end
    attr_accessor :x1, :x2, :y1, :y2, :x_abs, :y_abs, :start_index, :end_index
    attr_accessor :x_offset, :y_offset, :width, :height, :scale_x, :scale_y
    attr_accessor :width_emu, :height_emu, :element, :line_weight, :line_type
    attr_accessor :start_side, :end_side

    def initialize(properties = {})
      @writer = Package::XMLWriterSimple.new
      @name   = nil
      @type   = 'rect'

      # Is a Connector shape. 1/0 Value is a hash lookup from type.
      @connect = 0

      # Is a Drawing. Always 0, since a single shape never fills an entire sheet.
      @drawing = 0

      # OneCell or Absolute: options to move and/or size with cells.
      @edit_as = nil

      # Auto-incremented, unless supplied by user.
      @id = 0

      # Shape text (usually centered on shape geometry).
      @text = 0

      # Shape stencil mode.  A copy (child) is created when inserted.
      # The link to parent is broken.
      @stencil = 1

      # Index to _shapes array when inserted.
      @element = -1

      # Shape ID of starting connection, if any.
      @start = nil

      # Shape vertex, starts at 0, numbered clockwise from 12 o'clock.
      @start_index = nil

      @end       = nil
      @end_index = nil

      # Number and size of adjustments for shapes (usually connectors).
      @adjustments = []

      # Start and end sides. t)op, b)ottom, l)eft, or r)ight.
      @start_side = ''
      @end_side   = ''

      # Flip shape Horizontally. eg. arrow left to arrow right.
      @flip_h = 0

      # Flip shape Vertically. eg. up arrow to down arrow.
      @flip_v = 0

      # shape rotation (in degrees 0-360).
      @rotation = 0

      # An alternate way to create a text box, because Excel allows it.
      # It is just a rectangle with text.
      @tx_box = false

      # Shape outline colour, or 0 for noFill (default black).
      @line = '000000'

      # Line type: dash, sysDot, dashDot, lgDash, lgDashDot, lgDashDotDot.
      @line_type = ''

      # Line weight (integer).
      @line_weight = 1

      # Shape fill colour, or 0 for noFill (default noFill).
      @fill = 0

      # Formatting for shape text, if any.
      @format = {}

      # copy of colour palette table from Workbook.pm.
      @palette = []

      # Vertical alignment: t, ctr, b.
      @valign = 'ctr'

      # Alignment: l, ctr, r, just
      @align = 'ctr'

      @x_offset = 0
      @y_offset = 0

      # Scale factors, which also may be set when the shape is inserted.
      @scale_x = 1
      @scale_y = 1

      # Default size, which can be modified and/or scaled.
      @width  = 50
      @height = 50

      # Initial assignment. May be modified when prepared.
      @column_start = 0
      @row_start    = 0
      @x1           = 0
      @y1           = 0
      @column_end   = 0
      @row_end      = 0
      @x2           = 0
      @y2           = 0
      @x_abs        = 0
      @y_abs        = 0

      set_properties(properties)
    end

    def set_properties(properties)
      # Override default properties with passed arguments
      properties.each do |key, value|
        # Strip leading "-" from Tk style properties e.g. -color => 'red'.
        instance_variable_set("@#{key}", value)
      end
    end

    #
    # Set the shape adjustments array (as a reference).
    #
    def adjustments=(args)
      @adjustments = *args
    end

    #
    # Calculate the vertices that define the position of a shape object within
    # the worksheet in EMUs.  Save the vertices with the object.
    #
    # The vertices are expressed as English Metric Units (EMUs).
    # There are 12,700 EMUs per point. Therefore, 12,700 * 3 /4 = 9,525
    # EMUs per pixel.
    #
    def calc_position_emus(worksheet)
      c_start, r_start,
      xx1, yy1, c_end, r_end,
      xx2, yy2, x_abslt, y_abslt =
        worksheet.position_object_pixels(
          @column_start,
          @row_start,
          @x_offset,
          @y_offset,
          @width  * @scale_x,
          @height * @scale_y
        )

      # Now that x2/y2 have been calculated with a potentially negative
      # width/height we use the absolute value and convert to EMUs.
      @width_emu  = (@width  * 9_525).abs.to_i
      @height_emu = (@height * 9_525).abs.to_i

      @column_start = c_start.to_i
      @row_start    = r_start.to_i
      @column_end   = c_end.to_i
      @row_end      = r_end.to_i

      # Convert the pixel values to EMUs. See above.
      @x1    = (xx1 * 9_525).to_i
      @y1    = (yy1 * 9_525).to_i
      @x2    = (xx2 * 9_525).to_i
      @y2    = (yy2 * 9_525).to_i
      @x_abs = (x_abslt * 9_525).to_i
      @y_abs = (y_abslt * 9_525).to_i
    end

    def set_position(row_start, column_start, x_offset, y_offset, x_scale, y_scale, anchor)
      @row_start    = row_start
      @column_start = column_start
      @x_offset     = x_offset || 0
      @y_offset     = y_offset || 0
      @anchor       = anchor   || 1

      # Override shape scale if supplied as an argument. Otherwise, use the
      # existing shape scale factors.
      @scale_x = x_scale if x_scale
      @scale_y = y_scale if y_scale
    end

    #
    # Re-size connector shapes if they are connected to other shapes.
    #
    def auto_locate_connectors(shapes, shape_hash)
      # Valid connector shapes.
      connector_shapes = {
        straightConnector: 1,
        Connector:         1,
        bentConnector:     1,
        curvedConnector:   1,
        line:              1
      }

      shape_base = @type.chop.to_sym # Remove the number of segments from end of type.
      @connect = connector_shapes[shape_base] ? 1 : 0
      return if @connect == 0

      # Both ends have to be connected to size it.
      return if @start == 0 && @end == 0

      # Both ends need to provide info about where to connect.
      return if @start_side == 0 && @end_side == 0

      sid = @start
      eid = @end

      slink_id = shape_hash[sid] || 0
      sls      = shapes.fetch(slink_id, Shape.new)
      elink_id = shape_hash[eid] || 0
      els      = shapes.fetch(elink_id, Shape.new)

      # Assume shape connections are to the middle of an object, and
      # not a corner (for now).
      connect_type = @start_side + @end_side
      smidx        = sls.x_offset + (sls.width / 2)
      emidx        = els.x_offset + (els.width / 2)
      smidy        = sls.y_offset + (sls.height / 2)
      emidy        = els.y_offset + (els.height / 2)

      if connect_type == 'bt'
        sy = sls.y_offset + sls.height
        ey = els.y_offset

        @width = (emidx - smidx).to_i.abs
        @x_offset = [smidx, emidx].min.to_i
        @height =
          (els.y_offset - (sls.y_offset + sls.height)).to_i.abs
        @y_offset =
          [sls.y_offset + sls.height, els.y_offset].min.to_i
        @flip_h = smidx < emidx ? 1 : 0
        @rotation = 90

        if sy > ey
          @flip_v = 1

          # Create 3 adjustments for an end shape vertically above a
          # start @ Adjustments count from the upper left object.
          @adjustments = [-10, 50, 110] if @adjustments.empty?
          @type = 'bentConnector5'
        end
      elsif connect_type == 'rl'
        @width =
          (els.x_offset - (sls.x_offset + sls.width)).to_i.abs
        @height = (emidy - smidy).to_i.abs
        @x_offset =
          [sls.x_offset + sls.width, els.x_offset].min
        @y_offset = [smidy, emidy].min

        @flip_h = 1 if smidx < emidx && smidy > emidy
        @flip_h = 1 if smidx > emidx && smidy < emidy

        if smidx > emidx
          # Create 3 adjustments for an end shape to the left of a
          # start @
          @adjustments = [-10, 50, 110] if @adjustments.empty?
          @type = 'bentConnector5'
        end
      end
    end

    #
    # Check shape attributes to ensure they are valid.
    #
    def validate(index)
      raise "Shape #{index} (#{@type}) alignment (#{@align}) not in ['l', 'ctr', 'r', 'just']\n" unless %w[l ctr r just].include?(@align)

      raise "Shape #{index} (#{@type}) vertical alignment (#{@valign}) not in ['t', 'ctr', 'v']\n" unless %w[t ctr b].include?(@valign)
    end

    def dimensions
      [
        @column_start, @row_start,
        @x1,           @y1,
        @column_end,   @row_end,
        @x2,           @y2,
        @x_abs,        @y_abs,
        @width_emu,    @height_emu
      ]
    end
  end
end
end

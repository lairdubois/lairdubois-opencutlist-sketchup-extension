# -*- coding: utf-8 -*-
# frozen_string_literal: true

require_relative 'utility'

module Ladb::OpenCutList
module Writexlsx
  class Format
    include Writexlsx::Utility

    attr_reader :xf_index, :dxf_index, :num_format                                                 # :nodoc:
    attr_reader :underline, :font_script, :size, :theme, :font, :font_family, :hyperlink, :xf_id   # :nodoc:
    attr_reader :diag_type, :diag_color, :font_only, :color_indexed                                # :nodoc:
    attr_reader :left, :left_color, :right, :right_color, :top, :top_color, :bottom, :bottom_color # :nodoc:
    attr_reader :font_scheme                                                                       # :nodoc:
    attr_accessor :quote_prefix, :num_format_index, :border_index, :font_index                     # :nodoc:
    attr_accessor :fill_index, :font_condense, :font_extend, :diag_border                          # :nodoc:
    attr_accessor :bg_color, :fg_color, :pattern                                                   # :nodoc:

    attr_accessor :dxf_bg_color, :dxf_fg_color                                                     # :nodoc:
    attr_reader :rotation, :bold, :italic, :font_strikeout                                         # :nodoc:

    def initialize(formats, params = {})   # :nodoc:
      @formats = formats

      @xf_index       = nil
      @dxf_index      = nil

      @num_format = 'General'
      @num_format_index = 0
      @font_index     = 0
      @font           = 'Calibri'
      @size           = 11
      @bold           = 0
      @italic         = 0
      @color          = 0x0
      @underline      = 0
      @font_strikeout = 0
      @font_outline   = 0
      @font_shadow    = 0
      @font_script    = 0
      @font_family    = 2
      @font_charset   = 0
      @font_scheme    = 'minor'
      @font_condense  = 0
      @font_extend    = 0
      @theme          = 0
      @hyperlink      = 0
      @xf_id          = 0

      @hidden         = 0
      @locked         = 1

      @text_h_align   = 0
      @text_wrap      = 0
      @text_v_align   = 0
      @text_justlast  = 0
      @rotation       = 0

      @fg_color       = 0x00
      @bg_color       = 0x00
      @pattern        = 0
      @fill_index     = 0
      @fill_count     = 0

      @border_index   = 0
      @border_count   = 0

      @bottom         = 0
      @bottom_color   = 0x0
      @diag_border    = 0
      @diag_color     = 0x0
      @diag_type      = 0
      @left           = 0
      @left_color     = 0x0
      @right          = 0
      @right_color    = 0x0
      @top            = 0
      @top_color      = 0x0

      @indent         = 0
      @shrink         = 0
      @merge_range    = 0
      @reading_order  = 0
      @just_distrib   = 0
      @color_indexed  = 0
      @font_only      = 0
      @quote_prefix   = 0

      set_format_properties(params) unless params.empty?
    end

    #
    # Copy the attributes of another Format object.
    #
    def copy(other)
      reserve = %i[
        xf_index
        dxf_index
        xdf_format_indices
        palette
      ]
      (instance_variables - reserve).each do |v|
        instance_variable_set(v, other.instance_variable_get(v))
      end
    end

    #
    # :call-seq:
    #    set_format_properties( :bold => 1 [, :color => 'red'..] )
    #    set_format_properties( font [, shade, ..])
    #    set_format_properties( :bold => 1, font, ...)
    #      *) font  = { :color => 'red', :bold => 1 }
    #         shade = { :bg_color => 'green', :pattern => 1 }
    #
    # Convert hashes of properties to method calls.
    #
    def set_format_properties(*properties)   # :nodoc:
      return if properties.empty?

      properties.each do |property|
        property.each do |key, value|
          # Strip leading "-" from Tk style properties e.g. "-color" => 'red'.
          key = key.sub(/^-/, '') if key.respond_to?(:to_str)

          # Create a sub to set the property.
          if value.respond_to?(:to_str) || !value.respond_to?(:+)
            send("set_#{key}", value.to_s)
          else
            send("set_#{key}", value)
          end
        end
      end
    end

    #
    # Return properties for an Style xf <alignment> sub-element.
    #
    def get_align_properties
      align = []    # Attributes to return

      # Check if any alignment options in the format have been changed.
      if @text_h_align != 0 || @text_v_align != 0 || @indent != 0 ||
         @rotation != 0 || @text_wrap != 0 || @shrink != 0 || @reading_order != 0
        changed = 1
      else
        return
      end

      # Indent is only allowed for some alignment properties. If it is defined
      # for any other alignment or no alignment has been set then default to
      # left alignment.
      @text_h_align = 1 if @indent != 0 && ![1, 3, 7].include?(@text_h_align) && ![1, 3, 5].include?(@text_v_align)

      # Check for properties that are mutually exclusive.
      @shrink       = 0 if @text_wrap != 0
      @shrink       = 0 if @text_h_align == 4    # Fill
      @shrink       = 0 if @text_h_align == 5    # Justify
      @shrink       = 0 if @text_h_align == 7    # Distributed
      @just_distrib = 0 if @text_h_align != 7    # Distributed
      @just_distrib = 0 if @indent != 0

      continuous = 'centerContinuous'

      align << %w[horizontal left]        if @text_h_align == 1
      align << %w[horizontal center]      if @text_h_align == 2
      align << %w[horizontal right]       if @text_h_align == 3
      align << %w[horizontal fill]        if @text_h_align == 4
      align << %w[horizontal justify]     if @text_h_align == 5
      align << ['horizontal', continuous] if @text_h_align == 6
      align << %w[horizontal distributed] if @text_h_align == 7

      align << ['justifyLastLine', 1] if @just_distrib != 0

      # Property 'vertical' => 'bottom' is a default. It sets applyAlignment
      # without an alignment sub-element.
      align << %w[vertical top]         if @text_v_align == 1
      align << %w[vertical center]      if @text_v_align == 2
      align << %w[vertical justify]     if @text_v_align == 4
      align << %w[vertical distributed] if @text_v_align == 5

      align << ['textRotation', @rotation] if @rotation != 0
      align << ['indent',       @indent]   if @indent   != 0

      align << ['wrapText',     1] if @text_wrap != 0
      align << ['shrinkToFit',  1] if @shrink    != 0

      align << ['readingOrder', 1] if @reading_order == 1
      align << ['readingOrder', 2] if @reading_order == 2

      [changed, align]
    end

    #
    # Return properties for an Excel XML <Protection> element.
    #
    def get_protection_properties
      attributes = []

      attributes << ['locked', 0] unless ptrue?(@locked)
      attributes << ['hidden', 1] if     ptrue?(@hidden)

      attributes.empty? ? nil : attributes
    end

    def set_bold(bold = 1)
      @bold = ptrue?(bold) ? 1 : 0
    end

    def inspect
      to_s
    end

    #
    # Returns a unique hash key for the Format object.
    #
    def get_format_key
      [get_font_key, get_border_key, get_fill_key, get_alignment_key, @num_format, @locked, @hidden, @quote_prefix].join(':')
    end

    #
    # Returns a unique hash key for a font. Used by Workbook.
    #
    def get_font_key
      [
        @bold,
        @color,
        @font_charset,
        @font_family,
        @font_outline,
        @font_script,
        @font_shadow,
        @font_strikeout,
        @font,
        @italic,
        @size,
        @underline,
        @theme
      ].join(':')
    end

    #
    # Returns a unique hash key for a border style. Used by Workbook.
    #
    def get_border_key
      [
        @bottom,
        @bottom_color,
        @diag_border,
        @diag_color,
        @diag_type,
        @left,
        @left_color,
        @right,
        @right_color,
        @top,
        @top_color
      ].join(':')
    end

    #
    # Returns a unique hash key for a fill style. Used by Workbook.
    #
    def get_fill_key
      [
        @pattern,
        @bg_color,
        @fg_color
      ].join(':')
    end

    #
    # Returns a unique hash key for alignment formats.
    #
    def get_alignment_key
      [@text_h_align, @text_v_align, @indent, @rotation, @text_wrap, @shrink, @reading_order].join(':')
    end

    #
    # Returns the index used by Worksheet->_XF()
    #
    def get_xf_index
      if @xf_index
        @xf_index
      elsif @formats.xf_index_by_key(get_format_key)
        @formats.xf_index_by_key(get_format_key)
      else
        @xf_index = @formats.set_xf_index_by_key(get_format_key)
      end
    end

    #
    # Returns the index used by Worksheet->_XF()
    #
    def get_dxf_index
      if @dxf_index
        @dxf_index
      elsif @formats.dxf_index_by_key(get_format_key)
        @formats.dxf_index_by_key(get_format_key)
      else
        @dxf_index = @formats.set_dxf_index_by_key(get_format_key)
      end
    end

    def color(color_code)
      Format.color(color_code)
    end

    #
    # Used in conjunction with the set_xxx_color methods to convert a color
    # string into a number. Color range is 0..63 but we will restrict it
    # to 8..63 to comply with Gnumeric. Colors 0..7 are repeated in 8..15.
    #
    def self.color(color_code)
      colors = Colors::COLORS

      # Return the default color if nil,
      return 0x00 unless color_code

      if color_code.respond_to?(:to_str)
        # Return RGB style colors for processing later.
        return color_code if color_code =~ /^#[0-9A-F]{6}$/i

        # or the color string converted to an integer,
        return colors[color_code.downcase.to_sym] if colors[color_code.downcase.to_sym]

        # or the default color if string is unrecognised,
        0x00 if color_code =~ /\D/
      else
        # or an index < 8 mapped into the correct range,
        return color_code + 8 if color_code < 8

        # or the default color if arg is outside range,
        return 0x00 if color_code > 63

        # or an integer in the valid range
        color_code
      end
    end

    #
    # Set cell alignment.
    #
    def set_align(location)
      return unless location             # No default

      location = location.downcase

      case location
      when 'left'                         then set_text_h_align(1)
      when 'centre', 'center'             then set_text_h_align(2)
      when 'right'                        then set_text_h_align(3)
      when 'fill'                         then set_text_h_align(4)
      when 'justify'                      then set_text_h_align(5)
      when 'center_across', 'centre_across', 'merge'
        set_text_h_align(6)
      when 'distributed', 'equal_space', 'justify_distributed'
        set_text_h_align(7)
      when 'top'                          then set_text_v_align(1)
      when 'vcentre', 'vcenter'           then set_text_v_align(2)
      when 'bottom'                       then set_text_v_align(3)
      when 'vjustify'                     then set_text_v_align(4)
      when 'vdistributed', 'vequal_space' then set_text_v_align(5)
      end

      @just_distrib = 1 if location == 'justify_distributed'
    end

    #
    # Set vertical cell alignment. This is required by the set_properties() method
    # to differentiate between the vertical and horizontal properties.
    #
    def set_valign(location)
      set_align(location)
    end

    #
    # Implements the Excel5 style "merge".
    #
    def set_center_across(_flag = 1)
      set_text_h_align(6)
    end

    #
    # This was the way to implement a merge in Excel5. However it should have been
    # called "center_across" and not "merge".
    # This is now deprecated. Use set_center_across() or better merge_range().
    #
    def set_merge(_merge = 1)
      set_text_h_align(6)
    end

    #
    # Set cells borders to the same style
    #
    def set_border(style)
      set_bottom(style)
      set_top(style)
      set_left(style)
      set_right(style)
    end

    #
    # Set cells border to the same color
    #
    def set_border_color(color)
      set_bottom_color(color)
      set_top_color(color)
      set_left_color(color)
      set_right_color(color)
    end

    #
    # Set the rotation angle of the text. An alignment property.
    #
    def set_rotation(rotation)
      if rotation == 270
        rotation = 255
      elsif rotation >= -90 && rotation <= 90
        rotation = -rotation + 90 if rotation < 0
      else
        raise "Rotation #{rotation} outside range: -90 <= angle <= 90"
        rotation = 0
      end

      @rotation = rotation
    end

    #
    # Set the properties for the hyperlink style. This isn't a public method. To
    # be fixed when styles are supported.
    #
    def set_hyperlink(hyperlink)
      @xf_id = 1

      set_underline(1)
      set_theme(10)
      @hyperlink = hyperlink
    end

    def set_font_info(fonts)
      key = get_font_key

      if fonts[key]
        # Font has already been used.
        @font_index = fonts[key]
        @has_font   = false
      else
        # This is a new font.
        @font_index = fonts.size
        fonts[key]  = fonts.size
        @has_font   = true
      end
    end

    def set_border_info(borders)
      key = get_border_key

      if borders[key]
        # Border has already been used.
        @border_index = borders[key]
        @has_border   = false
      else
        # This is a new border.
        @border_index = borders.size
        borders[key]  = borders.size
        @has_border   = true
      end
    end

    def method_missing(name, *args)  # :nodoc:
      method = "#{name}"

      # Check for a valid method names, i.e. "set_xxx_yyy".
      method =~ /set_(\w+)/ or raise "Unknown method: #{method}\n"

      # Match the attribute, i.e. "@xxx_yyy".
      attribute = "@#{::Regexp.last_match(1)}"

      # Check that the attribute exists
      # ........
      value = if method =~ /set\w+color$/    # for "set_property_color" methods
                color(args[0])
              else                            # for "set_xxx" methods
                args[0] || 1
              end

      instance_variable_set(attribute, value)
    end

    def color?
      ptrue?(@color)
    end

    def bold?
      ptrue?(@bold)
    end

    def italic?
      ptrue?(@italic)
    end

    def strikeout?
      ptrue?(@font_strikeout)
    end

    def outline?
      ptrue?(@font_outline)
    end

    def shadow?
      ptrue?(@font_shadow)
    end

    def underline?
      ptrue?(@underline)
    end

    def has_border(flag)
      @has_border = flag
    end

    def has_border? # :nodoc:
      @has_border
    end

    def has_dxf_border(flag)
      @has_dxf_border = flag
    end

    def has_dxf_border?
      @has_dxf_border
    end

    def has_font(flag)
      @has_font = flag
    end

    def has_font?
      @has_font
    end

    def has_dxf_font(flag)
      @has_dxf_font = flag
    end

    def has_dxf_font?
      @has_dxf_font
    end

    def has_fill(flag)
      @has_fill = flag
    end

    def has_fill?
      @has_fill
    end

    def has_dxf_fill(flag)
      @has_dxf_fill = flag
    end

    def has_dxf_fill?
      @has_dxf_fill
    end

    def [](attr)
      instance_variable_get("@#{attr}")
    end

    def write_font(writer, worksheet, dxf_format = nil) # :nodoc:
      writer.tag_elements('font') do
        # The condense and extend elements are mainly used in dxf formats.
        write_condense(writer) if ptrue?(@font_condense)
        write_extend(writer)   if ptrue?(@font_extend)

        write_font_shapes(writer)

        writer.empty_tag('sz', [['val', size]]) unless dxf_format

        if theme == -1
        # Ignore for excel2003_style
        elsif ptrue?(theme)
          write_color('theme', theme, writer)
        elsif ptrue?(@color_indexed)
          write_color('indexed', @color_indexed, writer)
        elsif ptrue?(@color)
          color = worksheet.palette_color(@color)
          if color != 'Automatic'
            write_color('rgb', color, writer)
          end
        elsif !ptrue?(dxf_format)
          write_color('theme', 1, writer)
        end

        unless ptrue?(dxf_format)
          writer.empty_tag('name', [['val', @font]])
          write_font_family_scheme(writer)
        end
      end
    end

    def write_font_rpr(writer, worksheet) # :nodoc:
      writer.tag_elements('rPr') do
        write_font_shapes(writer)
        writer.empty_tag('sz', [['val', size]])

        if ptrue?(theme)
          write_color('theme', theme, writer)
        elsif ptrue?(@color)
          color = worksheet.palette_color(@color)
          write_color('rgb', color, writer)
        else
          write_color('theme', 1, writer)
        end

        writer.empty_tag('rFont', [['val', @font]])
        write_font_family_scheme(writer)
      end
    end

    def border_attributes
      attributes = []

      # Diagonal borders add attributes to the <border> element.
      if diag_type == 1
        attributes << ['diagonalUp',   1]
      elsif diag_type == 2
        attributes << ['diagonalDown', 1]
      elsif diag_type == 3
        attributes << ['diagonalUp',   1]
        attributes << ['diagonalDown', 1]
      end
      attributes
    end

    def xf_attributes
      attributes = [
        ['numFmtId', num_format_index],
        ['fontId', font_index],
        ['fillId', fill_index],
        ['borderId', border_index],
        ['xfId', xf_id]
      ]
      attributes << ['quotePrefix', 1] if ptrue?(quote_prefix)
      attributes << ['applyNumberFormat', 1] if num_format_index > 0
      # Add applyFont attribute if XF format uses a font element.
      attributes << ['applyFont', 1] if font_index > 0 && !ptrue?(@hyperlink)
      # Add applyFill attribute if XF format uses a fill element.
      attributes << ['applyFill', 1] if fill_index > 0
      # Add applyBorder attribute if XF format uses a border element.
      attributes << ['applyBorder', 1] if border_index > 0

      # Check if XF format has alignment properties set.
      apply_align, _align = get_align_properties
      # We can also have applyAlignment without a sub-element.
      attributes << ['applyAlignment', 1] if apply_align || ptrue?(@hyperlink)
      attributes << ['applyProtection', 1] if get_protection_properties || ptrue?(hyperlink)

      attributes
    end

    def force_text_format?
      @num_format == 49 # Text format ('@')
    end

    private

    def write_font_shapes(writer)
      writer.empty_tag('b')       if bold?
      writer.empty_tag('i')       if italic?
      writer.empty_tag('strike')  if strikeout?
      writer.empty_tag('outline') if outline?
      writer.empty_tag('shadow')  if shadow?

      # Handle the underline variants.
      write_underline(writer, underline) if underline?

      write_vert_align(writer, 'superscript') if font_script == 1
      write_vert_align(writer, 'subscript')   if font_script == 2
    end

    def write_font_family_scheme(writer)
      writer.empty_tag('family', [['val', @font_family]]) if ptrue?(@font_family)

      writer.empty_tag('charset', [['val', @font_charset]]) if ptrue?(@font_charset)

      writer.empty_tag('scheme', [['val', @font_scheme]]) if @font == 'Calibri' && !ptrue?(@hyperlink)
    end

    #
    # Write the underline font element.
    #
    def write_underline(writer, underline)
      writer.empty_tag('u', write_underline_attributes(underline))
    end

    #
    # Write the underline font element.
    #
    def write_underline_attributes(underline)
      val = 'val'
      # Handle the underline variants.
      case underline
      when 2
        [[val, 'double']]
      when 33
        [[val, 'singleAccounting']]
      when 34
        [[val, 'doubleAccounting']]
      else
        []
      end
    end

    #
    # Write the <vertAlign> font sub-element.
    #
    def write_vert_align(writer, val) # :nodoc:
      writer.empty_tag('vertAlign', [['val', val]])
    end

    #
    # Write the <condense> element.
    #
    def write_condense(writer)
      writer.empty_tag('condense', [['val', 0]])
    end

    #
    # Write the <extend> element.
    #
    def write_extend(writer)
      writer.empty_tag('extend', [['val', 0]])
    end
  end
end
end

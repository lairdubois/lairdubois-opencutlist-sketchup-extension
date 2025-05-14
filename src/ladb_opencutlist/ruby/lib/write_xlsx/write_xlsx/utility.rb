# -*- coding: utf-8 -*-
# frozen_string_literal: true

require_relative 'col_name'

module Ladb::OpenCutList
module Writexlsx
  module Utility
    ROW_MAX       = 1048576  # :nodoc:
    COL_MAX       = 16384    # :nodoc:
    STR_MAX       = 32767    # :nodoc:
    SHEETNAME_MAX = 31  # :nodoc:
    CHAR_WIDTHS   = {
      ' '  =>  3, '!' =>  5, '"' =>  6, '#' =>  7, '$' =>  7, '%' => 11,
      '&'  => 10, "'" =>  3, '(' =>  5, ')' =>  5, '*' =>  7, '+' =>  7,
      ','  =>  4, '-' =>  5, '.' =>  4, '/' =>  6, '0' =>  7, '1' =>  7,
      '2'  =>  7, '3' =>  7, '4' =>  7, '5' =>  7, '6' =>  7, '7' =>  7,
      '8'  =>  7, '9' =>  7, ':' =>  4, ';' =>  4, '<' =>  7, '=' =>  7,
      '>'  =>  7, '?' =>  7, '@' => 13, 'A' =>  9, 'B' =>  8, 'C' =>  8,
      'D'  =>  9, 'E' =>  7, 'F' =>  7, 'G' =>  9, 'H' =>  9, 'I' =>  4,
      'J'  =>  5, 'K' =>  8, 'L' =>  6, 'M' => 12, 'N' => 10, 'O' => 10,
      'P'  =>  8, 'Q' => 10, 'R' =>  8, 'S' =>  7, 'T' =>  7, 'U' =>  9,
      'V'  =>  9, 'W' => 13, 'X' =>  8, 'Y' =>  7, 'Z' =>  7, '[' =>  5,
      '\\' =>  6, ']' =>  5, '^' =>  7, '_' =>  7, '`' =>  4, 'a' =>  7,
      'b'  =>  8, 'c' =>  6, 'd' =>  8, 'e' =>  8, 'f' =>  5, 'g' =>  7,
      'h'  =>  8, 'i' =>  4, 'j' =>  4, 'k' =>  7, 'l' =>  4, 'm' => 12,
      'n'  =>  8, 'o' =>  8, 'p' =>  8, 'q' =>  8, 'r' =>  5, 's' =>  6,
      't'  =>  5, 'u' =>  8, 'v' =>  7, 'w' => 11, 'x' =>  7, 'y' =>  7,
      'z'  =>  6, '{' =>  5, '|' =>  7, '}' =>  5, '~' =>  7
    }.freeze
    MAX_DIGIT_WIDTH    = 7    # For Calabri 11.  # :nodoc:
    PADDING            = 5                       # :nodoc:
    DEFAULT_COL_PIXELS = 64

    #
    # xl_rowcol_to_cell($row, col, row_absolute, col_absolute)
    #
    def xl_rowcol_to_cell(row_or_name, col, row_absolute = false, col_absolute = false)
      if row_or_name.is_a?(Integer)
        row_or_name += 1      # Change from 0-indexed to 1 indexed.
      end
      col_str = xl_col_to_name(col, col_absolute)
      "#{col_str}#{absolute_char(row_absolute)}#{row_or_name}"
    end

    #
    # Returns: [row, col, row_absolute, col_absolute]
    #
    # The row_absolute and col_absolute parameters aren't documented because they
    # mainly used internally and aren't very useful to the user.
    #
    def xl_cell_to_rowcol(cell)
      cell =~ /(\$?)([A-Z]{1,3})(\$?)(\d+)/

      col_abs = ::Regexp.last_match(1) != ""
      col     = ::Regexp.last_match(2)
      row_abs = ::Regexp.last_match(3) != ""
      row     = ::Regexp.last_match(4).to_i

      # Convert base26 column string to number
      # All your Base are belong to us.
      chars = col.split("")
      expn = 0
      col = 0

      chars.reverse.each do |char|
        col += (char.ord - 'A'.ord + 1) * (26**expn)
        expn += 1
      end

      # Convert 1-index to zero-index
      row -= 1
      col -= 1

      [row, col, row_abs, col_abs]
    end

    def xl_col_to_name(col, col_absolute)
      col_str = ColName.instance.col_str(col)
      if col_absolute
        "#{absolute_char(col_absolute)}#{col_str}"
      else
        # Do not allocate new string
        col_str
      end
    end

    def xl_range(row_1, row_2, col_1, col_2,
                 row_abs_1 = false, row_abs_2 = false, col_abs_1 = false, col_abs_2 = false)
      range1 = xl_rowcol_to_cell(row_1, col_1, row_abs_1, col_abs_1)
      range2 = xl_rowcol_to_cell(row_2, col_2, row_abs_2, col_abs_2)

      if range1 == range2
        range1
      else
        "#{range1}:#{range2}"
      end
    end

    def xl_range_formula(sheetname, row_1, row_2, col_1, col_2)
      # Use Excel's conventions and quote the sheet name if it contains any
      # non-word character or if it isn't already quoted.
      sheetname = "'#{sheetname}'" if sheetname =~ /\W/ && !(sheetname =~ /^'/)

      range1 = xl_rowcol_to_cell(row_1, col_1, 1, 1)
      range2 = xl_rowcol_to_cell(row_2, col_2, 1, 1)

      "=#{sheetname}!#{range1}:#{range2}"
    end

    #
    # xl_string_pixel_width($string)
    #
    # Get the pixel width of a string based on individual character widths taken
    # from Excel. UTF8 characters are given a default width of 8.
    #
    # Note, Excel adds an additional 7 pixels padding to a cell.
    #
    def xl_string_pixel_width(string)
      length = 0
      string.to_s.split("").each { |char| length += CHAR_WIDTHS[char] || 8 }

      length
    end

    #
    # Sheetnames used in references should be quoted if they contain any spaces,
    # special characters or if the look like something that isn't a sheet name.
    # TODO. We need to handle more special cases.
    #
    def quote_sheetname(sheetname) # :nodoc:
      # Use Excel's conventions and quote the sheet name if it comtains any
      # non-word character or if it isn't already quoted.
      name = sheetname.dup
      if name =~ /\W/ && !(name =~ /^'/)
        # Double quote and single quoted strings.
        name = name.gsub("'", "''")
        name = "'#{name}'"
      end
      name
    end

    def check_dimensions(row, col)
      raise WriteXLSXDimensionError if !row || row >= ROW_MAX || !col || col >= COL_MAX

      0
    end

    #
    # convert_date_time(date_time_string)
    #
    # The function takes a date and time in ISO8601 "yyyy-mm-ddThh:mm:ss.ss" format
    # and converts it to a decimal number representing a valid Excel date.
    #
    def convert_date_time(date_time_string)       # :nodoc:
      date_time = date_time_string.to_s.sub(/^\s+/, '').sub(/\s+$/, '').sub(/Z$/, '')

      # Check for invalid date char.
      return nil if date_time =~ /[^0-9T:\-.Z]/

      # Check for "T" after date or before time.
      return nil unless date_time =~ /\dT|T\d/

      days      = 0 # Number of days since epoch
      seconds   = 0 # Time expressed as fraction of 24h hours in seconds

      # Split into date and time.
      date, time = date_time.split("T")

      # We allow the time portion of the input DateTime to be optional.
      if time
        # Match hh:mm:ss.sss+ where the seconds are optional
        if time =~ /^(\d\d):(\d\d)(:(\d\d(\.\d+)?))?/
          hour   = ::Regexp.last_match(1).to_i
          min    = ::Regexp.last_match(2).to_i
          sec    = ::Regexp.last_match(4).to_f || 0
        else
          return nil # Not a valid time format.
        end

        # Some boundary checks
        return nil if hour >= 24
        return nil if min  >= 60
        return nil if sec  >= 60

        # Excel expresses seconds as a fraction of the number in 24 hours.
        seconds = ((hour * 60 * 60) + (min * 60) + sec) / (24.0 * 60 * 60)
      end

      # We allow the date portion of the input DateTime to be optional.
      return seconds if date == ''

      # Match date as yyyy-mm-dd.
      if date =~ /^(\d\d\d\d)-(\d\d)-(\d\d)$/
        year   = ::Regexp.last_match(1).to_i
        month  = ::Regexp.last_match(2).to_i
        day    = ::Regexp.last_match(3).to_i
      else
        return nil  # Not a valid date format.
      end

      # Set the epoch as 1900 or 1904. Defaults to 1900.
      # Special cases for Excel.
      unless date_1904?
        return      seconds if date == '1899-12-31' # Excel 1900 epoch
        return      seconds if date == '1900-01-00' # Excel 1900 epoch
        return 60 + seconds if date == '1900-02-29' # Excel false leapday
      end

      # We calculate the date by calculating the number of days since the epoch
      # and adjust for the number of leap days. We calculate the number of leap
      # days by normalising the year in relation to the epoch. Thus the year 2000
      # becomes 100 for 4 and 100 year leapdays and 400 for 400 year leapdays.
      #
      epoch   = date_1904? ? 1904 : 1900
      offset  = date_1904? ? 4 : 0
      norm    = 300
      range   = year - epoch

      # Set month days and check for leap year.
      mdays   = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
      leap    = 0
      leap    = 1  if (year % 4 == 0 && year % 100 != 0) || year % 400 == 0
      mdays[1] = 29 if leap != 0

      # Some boundary checks
      return nil if year  < epoch or year  > 9999
      return nil if month < 1     or month > 12
      return nil if day   < 1     or day   > mdays[month - 1]

      # Accumulate the number of days since the epoch.
      days = day                               # Add days for current month
      (0..month - 2).each do |m|
        days += mdays[m]                      # Add days for past months
      end
      days += range * 365                      # Add days for past years
      days += (range / 4)    # Add leapdays
      days -= ((range + offset) / 100)    # Subtract 100 year leapdays
      days += ((range + offset + norm) / 400)    # Add 400 year leapdays
      days -= leap                             # Already counted above

      # Adjust for Excel erroneously treating 1900 as a leap year.
      days += 1 if !date_1904? and days > 59

      date_time = sprintf("%0.10f", days + seconds)
      date_time = date_time.sub(/\.?0+$/, '') if date_time =~ /\./
      if date_time =~ /\./
        date_time.to_f
      else
        date_time.to_i
      end
    end

    def escape_url(url)
      unless url =~ /%[0-9a-fA-F]{2}/
        # Escape the URL escape symbol.
        url = url.gsub("%", "%25")

        # Escape whitespae in URL.
        url = url.gsub(/[\s\x00]/, '%20')

        # Escape other special characters in URL.
        re = /(["<>\[\]`^{}])/
        while re =~ url
          match = $~[1]
          url = url.sub(re, sprintf("%%%x", match.ord))
        end
      end

      url
    end

    def absolute_char(absolute)
      absolute ? '$' : ''
    end

    def xml_str
      @writer.string
    end

    def self.delete_files(path)
      if FileTest.file?(path)
        File.delete(path)
      elsif FileTest.directory?(path)
        Dir.foreach(path) do |file|
          next if file =~ /^\.\.?$/  # '.' or '..'

          delete_files(path.sub(%r{/+$}, "") + '/' + file)
        end
        Dir.rmdir(path)
      end
    end

    def put_deprecate_message(method)
      warn("Warning: calling deprecated method #{method}. This method will be removed in a future release.")
    end

    # Check for a cell reference in A1 notation and substitute row and column
    def row_col_notation(row_or_a1)   # :nodoc:
      substitute_cellref(row_or_a1) if row_or_a1.respond_to?(:match) && row_or_a1.to_s =~ /^\D/
    end

    #
    # Substitute an Excel cell reference in A1 notation for  zero based row and
    # column values in an argument list.
    #
    # Ex: ("A4", "Hello") is converted to (3, 0, "Hello").
    #
    def substitute_cellref(cell, *args)       # :nodoc:
      #      return [*args] if cell.respond_to?(:coerce) # Numeric

      normalized_cell = cell.upcase

      case normalized_cell
      # Convert a column range: 'A:A' or 'B:G'.
      # A range such as A:A is equivalent to A1:65536, so add rows as required
      when /\$?([A-Z]{1,3}):\$?([A-Z]{1,3})/
        row1, col1 =  xl_cell_to_rowcol(::Regexp.last_match(1) + '1')
        row2, col2 =  xl_cell_to_rowcol(::Regexp.last_match(2) + ROW_MAX.to_s)
        [row1, col1, row2, col2, *args]
      # Convert a cell range: 'A1:B7'
      when /\$?([A-Z]{1,3}\$?\d+):\$?([A-Z]{1,3}\$?\d+)/
        row1, col1 =  xl_cell_to_rowcol(::Regexp.last_match(1))
        row2, col2 =  xl_cell_to_rowcol(::Regexp.last_match(2))
        [row1, col1, row2, col2, *args]
      # Convert a cell reference: 'A1' or 'AD2000'
      when /\$?([A-Z]{1,3}\$?\d+)/
        row1, col1 = xl_cell_to_rowcol(::Regexp.last_match(1))
        [row1, col1, *args]
      else
        raise("Unknown cell reference #{normalized_cell}")
      end
    end

    def underline_attributes(underline)
      if underline == 2
        [%w[val double]]
      elsif underline == 33
        [%w[val singleAccounting]]
      elsif underline == 34
        [%w[val doubleAccounting]]
      else
        []    # Default to single underline.
      end
    end

    #
    # Write the <color> element.
    #
    def write_color(name, value, writer = @writer) # :nodoc:
      attributes = [[name, value]]

      writer.empty_tag('color', attributes)
    end

    PERL_TRUE_VALUES = [false, nil, 0, "0", "", [], {}].freeze
    #
    # return perl's boolean result
    #
    def ptrue?(value)
      if PERL_TRUE_VALUES.include?(value)
        false
      else
        true
      end
    end

    def check_parameter(params, valid_keys, method)
      invalids = params.keys - valid_keys
      unless invalids.empty?
        raise WriteXLSXOptionParameterError,
              "Unknown parameter '#{invalids.join(", ")}' in #{method}."
      end
      true
    end

    #
    # Check that row and col are valid and store max and min values for use in
    # other methods/elements.
    #
    def check_dimensions_and_update_max_min_values(row, col, ignore_row = 0, ignore_col = 0)       # :nodoc:
      check_dimensions(row, col)
      store_row_max_min_values(row) if ignore_row == 0
      store_col_max_min_values(col) if ignore_col == 0

      0
    end

    def store_row_max_min_values(row)
      @dim_rowmin = row if !@dim_rowmin || (row < @dim_rowmin)
      @dim_rowmax = row if !@dim_rowmax || (row > @dim_rowmax)
    end

    def store_col_max_min_values(col)
      @dim_colmin = col if !@dim_colmin || (col < @dim_colmin)
      @dim_colmax = col if !@dim_colmax || (col > @dim_colmax)
    end

    def float_to_str(float)
      return '' unless float

      if float == float.to_i
        float.to_i.to_s
      else
        float.to_s
      end
    end

    #
    # Convert user defined legend properties to the structure required internally.
    #
    def legend_properties(params)
      legend = Writexlsx::Chart::Legend.new

      legend.position      = params[:position] || 'right'
      legend.delete_series = params[:delete_series]
      legend.font          = convert_font_args(params[:font])

      # Set the legend layout.
      legend.layout = layout_properties(params[:layout])

      # Turn off the legend.
      legend.position = 'none' if params[:none]

      # Set the line properties for the legend.
      line = line_properties(params[:line])

      # Allow 'border' as a synonym for 'line'.
      line = line_properties(params[:border]) if params[:border]

      # Set the fill properties for the legend.
      fill = fill_properties(params[:fill])

      # Set the pattern properties for the legend.
      pattern = pattern_properties(params[:pattern])

      # Set the gradient fill properties for the legend.
      gradient = gradient_properties(params[:gradient])

      # Pattern fill overrides solid fill.
      fill = nil if pattern

      # Gradient fill overrides solid and pattern fills.
      if gradient
        pattern = nil
        fill    = nil
      end

      # Set the legend layout.
      layout = layout_properties(params[:layout])

      legend.line     = line
      legend.fill     = fill
      legend.pattern  = pattern
      legend.gradient = gradient
      legend.layout   = layout

      @legend = legend
    end

    #
    # Convert user defined layout properties to the format required internally.
    #
    def layout_properties(args, is_text = false)
      return unless ptrue?(args)

      properties = is_text ? %i[x y] : %i[x y width height]

      # Check for valid properties.
      args.keys.each do |key|
        raise "Property '#{key}' not allowed in layout options\n" unless properties.include?(key.to_sym)
      end

      # Set the layout properties
      layout = {}
      properties.each do |property|
        value = args[property]
        # Convert to the format used by Excel for easier testing.
        layout[property] = sprintf("%.17g", value)
      end

      layout
    end

    #
    # Convert vertices from pixels to points.
    #
    def pixels_to_points(vertices)
      _col_start, _row_start, _x1,    _y1,
      _col_end,   _row_end,   _x2,    _y2,
      left,      top,       width, height  = vertices.flatten

      left   *= 0.75
      top    *= 0.75
      width  *= 0.75
      height *= 0.75

      [left, top, width, height]
    end

    def v_shape_attributes_base(id)
      [
        ['id',    "_x0000_s#{id}"],
        ['type',  type]
      ]
    end

    def v_shape_style_base(z_index, vertices)
      left, top, width, height = pixels_to_points(vertices)

      left_str    = float_to_str(left)
      top_str     = float_to_str(top)
      width_str   = float_to_str(width)
      height_str  = float_to_str(height)
      z_index_str = float_to_str(z_index)

      shape_style_base(left_str, top_str, width_str, height_str, z_index_str)
    end

    def shape_style_base(left_str, top_str, width_str, height_str, z_index_str)
      [
        'position:absolute;',
        'margin-left:',
        left_str, 'pt;',
        'margin-top:',
        top_str, 'pt;',
        'width:',
        width_str, 'pt;',
        'height:',
        height_str, 'pt;',
        'z-index:',
        z_index_str, ';'
      ]
    end

    #
    # Write the <v:fill> element.
    #
    def write_fill
      @writer.empty_tag('v:fill', fill_attributes)
    end

    #
    # Write the <v:path> element.
    #
    def write_comment_path(gradientshapeok, connecttype)
      attributes      = []

      attributes << %w[gradientshapeok t] if gradientshapeok
      attributes << ['o:connecttype', connecttype]

      @writer.empty_tag('v:path', attributes)
    end

    #
    # Write the <x:Anchor> element.
    #
    def write_anchor
      col_start, row_start, x1, y1, col_end, row_end, x2, y2 = @vertices
      data = [col_start, x1, row_start, y1, col_end, x2, row_end, y2].join(', ')

      @writer.data_element('x:Anchor', data)
    end

    #
    # Write the <x:AutoFill> element.
    #
    def write_auto_fill
      @writer.data_element('x:AutoFill', 'False')
    end

    #
    # Write the <div> element.
    #
    def write_div(align, font = nil)
      style = "text-align:#{align}"
      attributes = [['style', style]]

      @writer.tag_elements('div', attributes) do
        if font
          # Write the font element.
          write_font(font)
        end
      end
    end

    #
    # Write the <font> element.
    #
    def write_font(font)
      caption = font[:_caption]
      face    = 'Calibri'
      size    = 220
      color   = '#000000'

      attributes = [
        ['face',  face],
        ['size',  size],
        ['color', color]
      ]
      @writer.data_element('font', caption, attributes)
    end

    #
    # Write the <v:stroke> element.
    #
    def write_stroke
      attributes = [%w[joinstyle miter]]

      @writer.empty_tag('v:stroke', attributes)
    end

    def r_id_attributes(id)
      ['r:id', "rId#{id}"]
    end

    def write_xml_declaration
      @writer.xml_decl
      yield
      @writer.crlf
      @writer.close
    end

    #
    # Convert user defined line properties to the structure required internally.
    #
    def line_properties(line) # :nodoc:
      line_fill_properties(line) do
        value_or_raise(dash_types, line[:dash_type], 'dash type')
      end
    end

    #
    # Convert user defined fill properties to the structure required internally.
    #
    def fill_properties(fill) # :nodoc:
      line_fill_properties(fill)
    end

    #
    # Convert user defined pattern properties to the structure required internally.
    #
    def pattern_properties(args) # :nodoc:
      pattern = {}

      return nil unless args

      # Check the pattern type is present.
      return nil unless args.has_key?(:pattern)

      # Check the foreground color is present.
      retuen nil unless args.has_key?(:fg_color)

      types = {
        'percent_5'                => 'pct5',
        'percent_10'               => 'pct10',
        'percent_20'               => 'pct20',
        'percent_25'               => 'pct25',
        'percent_30'               => 'pct30',
        'percent_40'               => 'pct40',

        'percent_50'               => 'pct50',
        'percent_60'               => 'pct60',
        'percent_70'               => 'pct70',
        'percent_75'               => 'pct75',
        'percent_80'               => 'pct80',
        'percent_90'               => 'pct90',

        'light_downward_diagonal'  => 'ltDnDiag',
        'light_upward_diagonal'    => 'ltUpDiag',
        'dark_downward_diagonal'   => 'dkDnDiag',
        'dark_upward_diagonal'     => 'dkUpDiag',
        'wide_downward_diagonal'   => 'wdDnDiag',
        'wide_upward_diagonal'     => 'wdUpDiag',

        'light_vertical'           => 'ltVert',
        'light_horizontal'         => 'ltHorz',
        'narrow_vertical'          => 'narVert',
        'narrow_horizontal'        => 'narHorz',
        'dark_vertical'            => 'dkVert',
        'dark_horizontal'          => 'dkHorz',

        'dashed_downward_diagonal' => 'dashDnDiag',
        'dashed_upward_diagonal'   => 'dashUpDiag',
        'dashed_horizontal'        => 'dashHorz',
        'dashed_vertical'          => 'dashVert',
        'small_confetti'           => 'smConfetti',
        'large_confetti'           => 'lgConfetti',

        'zigzag'                   => 'zigZag',
        'wave'                     => 'wave',
        'diagonal_brick'           => 'diagBrick',
        'horizontal_brick'         => 'horzBrick',
        'weave'                    => 'weave',
        'plaid'                    => 'plaid',

        'divot'                    => 'divot',
        'dotted_grid'              => 'dotGrid',
        'dotted_diamond'           => 'dotDmnd',
        'shingle'                  => 'shingle',
        'trellis'                  => 'trellis',
        'sphere'                   => 'sphere',

        'small_grid'               => 'smGrid',
        'large_grid'               => 'lgGrid',
        'small_check'              => 'smCheck',
        'large_check'              => 'lgCheck',
        'outlined_diamond'         => 'openDmnd',
        'solid_diamond'            => 'solidDmnd'
      }

      # Check for valid types.
      if types[args[:pattern]]
        pattern[:pattern] = types[args[:pattern]]
      else
        raise "Unknown pattern type '#{args[:pattern]}'"
      end

      pattern[:bg_color] = args[:bg_color] || '#FFFFFF'
      pattern[:fg_color] = args[:fg_color]

      pattern
    end

    def line_fill_properties(params)
      return { _defined: 0 } unless params

      ret = params.dup
      ret[:dash_type] = yield if block_given? && ret[:dash_type]
      ret[:_defined] = 1
      ret
    end

    def dash_types
      {
        solid:               'solid',
        round_dot:           'sysDot',
        square_dot:          'sysDash',
        dash:                'dash',
        dash_dot:            'dashDot',
        long_dash:           'lgDash',
        long_dash_dot:       'lgDashDot',
        long_dash_dot_dot:   'lgDashDotDot',
        dot:                 'dot',
        system_dash_dot:     'sysDashDot',
        system_dash_dot_dot: 'sysDashDotDot'
      }
    end

    def value_or_raise(hash, key, msg)
      raise "Unknown #{msg} '#{key}'" if hash[key.to_sym].nil?

      hash[key.to_sym]
    end

    def palette_color_from_index(index)
      # Adjust the colour index.
      idx = index - 8

      r, g, b = @palette[idx]
      sprintf("%02X%02X%02X", r, g, b)
    end

    #
    # Convert user defined font values into private hash values.
    #
    def convert_font_args(params)
      return unless params

      font = params_to_font(params)

      # Convert font size units.
      font[:_size] *= 100 if font[:_size] && font[:_size] != 0

      # Convert rotation into 60,000ths of a degree.
      font[:_rotation] = 60_000 * font[:_rotation].to_i if ptrue?(font[:_rotation])

      font
    end

    def params_to_font(params)
      {
        _name:         params[:name],
        _color:        params[:color],
        _size:         params[:size],
        _bold:         params[:bold],
        _italic:       params[:italic],
        _underline:    params[:underline],
        _pitch_family: params[:pitch_family],
        _charset:      params[:charset],
        _baseline:     params[:baseline] || 0,
        _rotation:     params[:rotation]
      }
    end

    #
    # Write the <c:txPr> element.
    #
    def write_tx_pr(font, is_y_axis = nil) # :nodoc:
      rotation = nil
      rotation = font[:_rotation] if font && font.respond_to?(:[]) && font[:_rotation]
      @writer.tag_elements('c:txPr') do
        # Write the a:bodyPr element.
        write_a_body_pr(rotation, is_y_axis)
        # Write the a:lstStyle element.
        write_a_lst_style
        # Write the a:p element.
        write_a_p_formula(font)
      end
    end

    #
    # Write the <a:bodyPr> element.
    #
    def write_a_body_pr(rot, is_y_axis = nil) # :nodoc:
      rot = -5400000 if !rot && ptrue?(is_y_axis)
      attributes = []
      if rot
        if rot == 16_200_000
          # 270 deg/stacked angle.
          attributes << ['rot',  0]
          attributes << %w[vert wordArtVert]
        elsif rot == 16_260_000
          # 271 deg/stacked angle.
          attributes << ['rot',  0]
          attributes << %w[vert eaVert]
        else
          attributes << ['rot',  rot]
          attributes << %w[vert horz]
        end
      end

      @writer.empty_tag('a:bodyPr', attributes)
    end

    #
    # Write the <a:lstStyle> element.
    #
    def write_a_lst_style # :nodoc:
      @writer.empty_tag('a:lstStyle')
    end

    #
    # Write the <a:p> element for formula titles.
    #
    def write_a_p_formula(font = nil) # :nodoc:
      @writer.tag_elements('a:p') do
        # Write the a:pPr element.
        write_a_p_pr_formula(font)
        # Write the a:endParaRPr element.
        write_a_end_para_rpr
      end
    end

    #
    # Write the <a:pPr> element for formula titles.
    #
    def write_a_p_pr_formula(font) # :nodoc:
      @writer.tag_elements('a:pPr') { write_a_def_rpr(font) }
    end

    #
    # Write the <a:defRPr> element.
    #
    def write_a_def_rpr(font = nil) # :nodoc:
      write_def_rpr_r_pr_common(
        font,
        get_font_style_attributes(font),
        'a:defRPr'
      )
    end

    def write_def_rpr_r_pr_common(font, style_attributes, tag)  # :nodoc:
      latin_attributes = get_font_latin_attributes(font)
      has_color = ptrue?(font) && ptrue?(font[:_color])

      if !latin_attributes.empty? || has_color
        @writer.tag_elements(tag, style_attributes) do
          write_a_solid_fill(color: font[:_color]) if has_color
          write_a_latin(latin_attributes) unless latin_attributes.empty?
        end
      else
        @writer.empty_tag(tag, style_attributes)
      end
    end

    #
    # Get the font latin attributes from a font hash.
    #
    def get_font_latin_attributes(font)
      return [] unless font
      return [] unless font.respond_to?(:[])

      attributes = []
      attributes << ['typeface', font[:_name]]            if ptrue?(font[:_name])
      attributes << ['pitchFamily', font[:_pitch_family]] if font[:_pitch_family]
      attributes << ['charset', font[:_charset]]          if font[:_charset]

      attributes
    end

    #
    # Write the <a:solidFill> element.
    #
    def write_a_solid_fill(fill) # :nodoc:
      @writer.tag_elements('a:solidFill') do
        if fill[:color]
          # Write the a:srgbClr element.
          write_a_srgb_clr(color(fill[:color]), fill[:transparency])
        end
      end
    end

    #
    # Write the <a:srgbClr> element.
    #
    def write_a_srgb_clr(color, transparency = nil) # :nodoc:
      tag        = 'a:srgbClr'
      attributes = [['val', color]]

      if ptrue?(transparency)
        @writer.tag_elements(tag, attributes) do
          write_a_alpha(transparency)
        end
      else
        @writer.empty_tag(tag, attributes)
      end
    end

    #
    # Convert the user specified colour index or string to a rgb colour.
    #
    def color(color_code) # :nodoc:
      if color_code and color_code =~ /^#[0-9a-fA-F]{6}$/
        # Convert a HTML style #RRGGBB color.
        color_code.sub(/^#/, '').upcase
      else
        index = Format.color(color_code)
        raise "Unknown color '#{color_code}' used in chart formatting." unless index

        palette_color_from_index(index)
      end
    end

    #
    # Get the font style attributes from a font hash.
    #
    def get_font_style_attributes(font)
      return [] unless font
      return [] unless font.respond_to?(:[])

      attributes = []
      attributes << ['sz', font[:_size]]      if ptrue?(font[:_size])
      attributes << ['b',  font[:_bold]]      if font[:_bold]
      attributes << ['i',  font[:_italic]]    if font[:_italic]
      attributes << %w[u sng]             if font[:_underline]

      # Turn off baseline when testing fonts that don't have it.
      attributes << ['baseline', font[:_baseline]] if font[:_baseline] != -1
      attributes
    end

    #
    # Write the <a:endParaRPr> element.
    #
    def write_a_end_para_rpr # :nodoc:
      @writer.empty_tag('a:endParaRPr', [%w[lang en-US]])
    end
  end

  module WriteDPtPoint
    #
    # Write an individual <c:dPt> element. Override the parent method to add
    # markers.
    #
    def write_d_pt_point(index, point)
      @writer.tag_elements('c:dPt') do
        # Write the c:idx element.
        write_idx(index)
        @writer.tag_elements('c:marker') do
          # Write the c:spPr element.
          write_sp_pr(point)
        end
      end
    end
  end
end
end

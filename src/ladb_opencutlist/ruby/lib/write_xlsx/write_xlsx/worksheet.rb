# -*- coding: utf-8 -*-
# frozen_string_literal: true

require_relative 'colors'
require_relative 'drawing'
require_relative 'format'
require_relative 'image'
require_relative 'image_property'
require_relative 'inserted_chart'
require_relative 'package/button'
require_relative 'package/conditional_format'
require_relative 'package/xml_writer_simple'
require_relative 'sparkline'
require_relative 'utility'
require_relative 'worksheet/cell_data'
require_relative 'worksheet/data_validation'
require_relative 'worksheet/hyperlink'
require_relative 'worksheet/page_setup'
require 'tempfile'
require 'date'

module Ladb::OpenCutList
module Writexlsx
  class Worksheet
    include Writexlsx::Utility

    COLINFO = Struct.new('ColInfo', :width, :format, :hidden, :level, :collapsed, :autofit)

    attr_reader :index, :name                                     # :nodoc:
    attr_reader :charts, :images, :tables, :shapes, :drawings     # :nodoc:
    attr_reader :header_images, :footer_images, :background_image # :nodoc:
    attr_reader :vml_drawing_links                                # :nodoc:
    attr_reader :vml_data_id                                      # :nodoc:
    attr_reader :vml_header_id                                    # :nodoc:
    attr_reader :autofilter_area                                  # :nodoc:
    attr_reader :writer, :set_rows, :col_info, :row_sizes         # :nodoc:
    attr_reader :vml_shape_id                                     # :nodoc:
    attr_reader :comments, :comments_author                       # :nodoc:
    attr_accessor :data_bars_2010, :dxf_priority                  # :nodoc:
    attr_reader :vba_codename                                     # :nodoc:
    attr_writer :excel_version                                    # :nodoc:
    attr_reader :filter_cells                                     # :nodoc:
    attr_accessor :default_row_height                             # :nodoc:

    def initialize(workbook, index, name) # :nodoc:
      rowmax   = 1_048_576
      colmax   = 16_384
      strmax   = 32_767

      @writer = Package::XMLWriterSimple.new

      @workbook = workbook
      @index = index
      @name = name
      @col_info = {}
      @cell_data_table = []
      @excel_version = 2007
      @palette = workbook.palette
      @default_url_format = workbook.default_url_format
      @max_url_length = workbook.max_url_length

      @page_setup = PageSetup.new

      @screen_gridlines     = true
      @show_zeros           = true

      @xls_rowmax           = rowmax
      @xls_colmax           = colmax
      @xls_strmax           = strmax
      @dim_rowmin           = nil
      @dim_rowmax           = nil
      @dim_colmin           = nil
      @dim_colmax           = nil
      @selections           = []
      @panes                = []
      @hide_row_col_headers = 0
      @top_left_cell        = ''

      @tab_color  = 0

      @set_cols = {}
      @set_rows = {}
      @col_size_changed = false
      @zoom = 100
      @zoom_scale_normal = true
      @right_to_left = false
      @leading_zeros = false

      @autofilter_area = nil
      @filter_on    = false
      @filter_range = []
      @filter_cols  = {}
      @filter_cells = {}
      @filter_type  = {}

      @row_sizes = {}

      @last_shape_id          = 1
      @rel_count              = 0
      @external_hyper_links   = []
      @external_drawing_links = []
      @external_comment_links = []
      @external_vml_links     = []
      @external_background_links = []
      @external_table_links   = []
      @drawing_links          = []
      @vml_drawing_links      = []
      @charts                 = []
      @images                 = []
      @tables                 = []
      @sparklines             = []
      @shapes                 = []
      @shape_hash             = {}
      @drawing_rels           = {}
      @drawing_rels_id        = 0
      @vml_drawing_rels       = {}
      @vml_drawing_rels_id    = 0
      @has_dynamic_functions  = false
      @has_embedded_images    = false

      @use_future_functions   = false

      @header_images          = []
      @footer_images          = []
      @background_image       = nil

      @outline_row_level      = 0
      @outline_col_level      = 0

      @original_row_height    = 15
      @default_row_height     = 15
      @default_row_pixels     = 20
      @default_col_width      = 8.43
      @default_row_rezoed     = 0
      @default_date_pixels    = 68

      @merge = []

      @has_vml  = false
      @comments = Package::Comments.new(self)
      @buttons_array          = []
      @header_images_array    = []
      @ignore_errors          = nil

      @validations = []

      @cond_formats   = {}
      @data_bars_2010 = []
      @dxf_priority   = 1

      @protected_ranges     = []
      @num_protected_ranges = 0

      if excel2003_style?
        @original_row_height      = 12.75
        @default_row_height       = 12.75
        @default_row_pixels       = 17
        self.margins_left_right   = 0.75
        self.margins_top_bottom   = 1
        @page_setup.margin_header = 0.5
        @page_setup.margin_footer = 0.5
        @page_setup.header_footer_aligns = false
      end

      @embedded_image_indexes = @workbook.embedded_image_indexes
    end

    def set_xml_writer(filename) # :nodoc:
      @writer.set_xml_writer(filename)
    end

    def assemble_xml_file # :nodoc:
      write_xml_declaration do
        @writer.tag_elements('worksheet', write_worksheet_attributes) do
          write_sheet_pr
          write_dimension
          write_sheet_views
          write_sheet_format_pr
          write_cols
          write_sheet_data
          write_sheet_protection
          write_protected_ranges
          # write_sheet_calc_pr
          write_phonetic_pr if excel2003_style?
          write_auto_filter
          write_merge_cells
          write_conditional_formats
          write_data_validations
          write_hyperlinks
          write_print_options
          write_page_margins
          write_page_setup
          write_header_footer
          write_row_breaks
          write_col_breaks
          write_ignored_errors
          write_drawings
          write_legacy_drawing
          write_legacy_drawing_hf
          write_picture
          write_table_parts
          write_ext_list
        end
      end
    end

    #
    # Set this worksheet as a selected worksheet, i.e. the worksheet has its tab
    # highlighted.
    #
    def select
      @hidden   = false  # Selected worksheet can't be hidden.
      @selected = true
    end

    #
    # Set this worksheet as the active worksheet, i.e. the worksheet that is
    # displayed when the workbook is opened. Also set it as selected.
    #
    def activate
      @hidden = false
      @selected = true
      @workbook.activesheet = @index
    end

    #
    # Hide this worksheet.
    #
    def hide(hidden = :hidden)
      @hidden = hidden
      @selected = false
      @workbook.activesheet = 0 if @workbook.activesheet == @index
      @workbook.firstsheet  = 0 if @workbook.firstsheet  == @index
    end

    #
    # Hide this worksheet. This can only be unhidden from VBA.
    #
    def very_hidden
      hide(:very_hidden)
    end

    def hidden? # :nodoc:
      @hidden == :hidden
    end

    def very_hidden? # :nodoc:
      @hidden == :very_hidden
    end

    #
    # Set this worksheet as the first visible sheet. This is necessary
    # when there are a large number of worksheets and the activated
    # worksheet is not visible on the screen.
    #
    def set_first_sheet
      @hidden = false
      @workbook.firstsheet = @index
    end

    #
    # Set the worksheet protection flags to prevent modification of worksheet
    # objects.
    #
    def protect(password = nil, options = {})
      check_parameter(options, protect_default_settings.keys, 'protect')
      @protect = protect_default_settings.merge(options)

      # Set the password after the user defined values.
      if password && password != ''
        @protect[:password] =
          encode_password(password)
      end
    end

    #
    # Unprotect ranges within a protected worksheet.
    #
    def unprotect_range(range, range_name = nil, password = nil)
      if range.nil?
        raise "The range must be defined in unprotect_range())\n"
      else
        range = range.gsub("$", "")
        range = range.sub(/^=/, "")
        @num_protected_ranges += 1
      end

      range_name ||= "Range#{@num_protected_ranges}"
      password   &&= encode_password(password)

      @protected_ranges << [range, range_name, password]
    end

    #
    # :call-seq:
    #   set_column(firstcol, lastcol, width, format, hidden, level, collapsed)
    #
    # This method can be used to change the default properties of a single
    # column or a range of columns. All parameters apart from +first_col+
    # and +last_col+ are optional.
    #
    def set_column(*args)
      # Check for a cell reference in A1 notation and substitute row and column
      # ruby 3.2 no longer handles =~ for various types
      if args[0].respond_to?(:=~) && args[0].to_s =~ /^\D/
        _row1, firstcol, _row2, lastcol, *data = substitute_cellref(*args)
      else
        firstcol, lastcol, *data = args
      end

      # Ensure at least firstcol, lastcol and width
      return unless firstcol && lastcol && !data.empty?

      # Assume second column is the same as first if 0. Avoids KB918419 bug.
      lastcol = firstcol unless ptrue?(lastcol)

      # Ensure 2nd col is larger than first. Also for KB918419 bug.
      firstcol, lastcol = lastcol, firstcol if firstcol > lastcol

      width, format, hidden, level, collapsed = data
      autofit = 0

      # Check that cols are valid and store max and min values with default row.
      # NOTE: The check shouldn't modify the row dimensions and should only modify
      #       the column dimensions in certain cases.
      ignore_row = 1
      ignore_col = 1
      ignore_col = 0 if format.respond_to?(:xf_index)   # Column has a format.
      ignore_col = 0 if width && ptrue?(hidden)         # Column has a width but is hidden

      check_dimensions_and_update_max_min_values(0, firstcol, ignore_row, ignore_col)
      check_dimensions_and_update_max_min_values(0, lastcol,  ignore_row, ignore_col)

      # Set the limits for the outline levels (0 <= x <= 7).
      level ||= 0
      level = 0 if level < 0
      level = 7 if level > 7

      # Excel has a maximum column width of 255 characters.
      width = 255.0 if width && width > 255.0

      @outline_col_level = level if level > @outline_col_level

      # Store the column data based on the first column. Padded for sorting.
      (firstcol..lastcol).each do |col|
        @col_info[col] =
          COLINFO.new(width, format, hidden, level, collapsed, autofit)
      end

      # Store the column change to allow optimisations.
      @col_size_changed = true
    end

    #
    # Set the width (and properties) of a single column or a range of columns in
    # pixels rather than character units.
    #
    def set_column_pixels(*data)
      cell = data[0]

      # Check for a cell reference in A1 notation and substitute row and column
      if cell =~ /^\D/
        data = substitute_cellref(*data)

        # Returned values row1 and row2 aren't required here. Remove them.
        data.shift         # $row1
        data.delete_at(1)  # $row2
      end

      # Ensure at least $first_col, $last_col and $width
      return if data.size < 3

      first_col, last_col, pixels, format, hidden, level = data
      hidden ||= 0

      width = pixels_to_width(pixels) if ptrue?(pixels)

      set_column(first_col, last_col, width, format, hidden, level)
    end

    #
    # autofit()
    #
    # Simulate autofit based on the data, and datatypes in each column. We do this
    # by estimating a pixel width for each cell data.
    #
    def autofit
      col_width = {}

      # Iterate through all the data in the worksheet.
      (@dim_rowmin..@dim_rowmax).each do |row_num|
        # Skip row if it doesn't contain cell data.
        next unless @cell_data_table[row_num]

        (@dim_colmin..@dim_colmax).each do |col_num|
          length = 0
          case (cell_data = @cell_data_table[row_num][col_num])
          when StringCellData, RichStringCellData
            # Handle strings and rich strings.
            #
            # For standard shared strings we do a reverse lookup
            # from the shared string id to the actual string. For
            # rich strings we use the unformatted string. We also
            # split multiline strings and handle each part
            # separately.
            string = cell_data.raw_string

            if string =~ /\n/
              # Handle multiline strings.
              length = max = string.split("\n").collect do |str|
                xl_string_pixel_width(str)
              end.max
            else
              length = xl_string_pixel_width(string)
            end
          when DateTimeCellData

            # Handle dates.
            #
            # The following uses the default width for mm/dd/yyyy
            # dates. It isn't feasible to parse the number format
            # to get the actual string width for all format types.
            length = @default_date_pixels
          when NumberCellData

            # Handle numbers.
            #
            # We use a workaround/optimization for numbers since
            # digits all have a pixel width of 7. This gives a
            # slightly greater width for the decimal place and
            # minus sign but only by a few pixels and
            # over-estimation is okay.
            length = 7 * cell_data.token.to_s.length
          when BooleanCellData

            # Handle boolean values.
            #
            # Use the Excel standard widths for TRUE and FALSE.
            if ptrue?(cell_data.token)
              length = 31
            else
              length = 36
            end
          when FormulaCellData, FormulaArrayCellData, DynamicFormulaArrayCellData
            # Handle formulas.
            #
            # We only try to autofit a formula if it has a
            # non-zero value.
            if ptrue?(cell_data.data)
              length = xl_string_pixel_width(cell_data.data)
            end
          end

          # If the cell is in an autofilter header we add an
          # additional 16 pixels for the dropdown arrow.
          if length > 0 &&
             @filter_cells["#{row_num}:#{col_num}"]
            length += 16
          end

          # Add the string lenght to the lookup hash.
          max                = col_width[col_num] || 0
          col_width[col_num] = length if length > max
        end
      end

      # Apply the width to the column.
      col_width.each do |col_num, pixel_width|
        # Convert the string pixel width to a character width using an
        # additional padding of 7 pixels, like Excel.
        width = pixels_to_width(pixel_width + 7)

        # The max column character width in Excel is 255.
        width = 255.0 if width > 255.0

        # Add the width to an existing col info structure or add a new one.
        if @col_info[col_num]
          @col_info[col_num].width   = width
          @col_info[col_num].autofit = 1
        else
          @col_info[col_num] =
            COLINFO.new(width, nil, 0, 0, 0, 1)
        end
      end
    end

    #
    # :call-seq:
    #   set_selection(cell_or_cell_range)
    #
    # Set which cell or cells are selected in a worksheet.
    #
    def set_selection(*args)
      return if args.empty?

      if (row_col_array = row_col_notation(args.first))
        row_first, col_first, row_last, col_last = row_col_array
      else
        row_first, col_first, row_last, col_last = args
      end

      active_cell = xl_rowcol_to_cell(row_first, col_first)

      if row_last  # Range selection.
        # Swap last row/col for first row/col as necessary
        row_first, row_last = row_last, row_first if row_first > row_last
        col_first, col_last = col_last, col_first if col_first > col_last

        sqref = xl_range(row_first, row_last, col_first, col_last)
      else          # Single cell selection.
        sqref = active_cell
      end

      # Selection isn't set for cell A1.
      return if sqref == 'A1'

      @selections = [[nil, active_cell, sqref]]
    end

    ###############################################################################
    #
    # set_top_left_cell()
    #
    # Set the first visible cell at the top left of the worksheet.
    #
    def set_top_left_cell(row, col = nil)
      if (row_col_array = row_col_notation(row))
        _row, _col = row_col_array
      else
        _row = row
        _col = col
      end

      @top_left_cell = xl_rowcol_to_cell(_row, _col)
    end

    #
    # :call-seq:
    #   freeze_panes(row, col [ , top_row, left_col ] )
    #
    # This method can be used to divide a worksheet into horizontal or
    # vertical regions known as panes and to also "freeze" these panes so
    # that the splitter bars are not visible. This is the same as the
    # Window->Freeze Panes menu command in Excel
    #
    def freeze_panes(*args)
      return if args.empty?

      # Check for a cell reference in A1 notation and substitute row and column.
      if (row_col_array = row_col_notation(args.first))
        row, col, top_row, left_col = row_col_array
        type = args[1]
      else
        row, col, top_row, left_col, type = args
      end

      col      ||= 0
      top_row  ||= row
      left_col ||= col
      type     ||= 0

      @panes   = [row, col, top_row, left_col, type]
    end

    #
    # :call-seq:
    #   split_panes(y, x, top_row, left_col)
    #
    # Set panes and mark them as split.
    #
    def split_panes(*args)
      # Call freeze panes but add the type flag for split panes.
      freeze_panes(args[0], args[1], args[2], args[3], 2)
    end

    #
    # Set the page orientation as portrait.
    # The default worksheet orientation is portrait, so you won't generally
    # need to call this method.
    #
    def set_portrait
      @page_setup.orientation        = true
      @page_setup.page_setup_changed = true
    end

    #
    # Set the page orientation as landscape.
    #
    def set_landscape
      @page_setup.orientation         = false
      @page_setup.page_setup_changed  = true
    end

    #
    # This method is used to display the worksheet in "Page View/Layout" mode.
    #
    def set_page_view(flag = 1)
      @page_view = flag
    end

    #
    # set_pagebreak_view
    #
    # Set the page view mode.
    #
    def set_pagebreak_view
      @page_view = 2
    end

    #
    # Set the colour of the worksheet tab.
    #
    def tab_color=(color)
      @tab_color = Colors.new.color(color)
    end

    # This method is deprecated. use tab_color=().
    def set_tab_color(color)
      put_deprecate_message("#{self}.set_tab_color")
      self.tab_color = color
    end

    #
    # Set the paper type. Ex. 1 = US Letter, 9 = A4
    #
    def paper=(paper_size)
      @page_setup.paper = paper_size
    end

    def set_paper(paper_size)
      put_deprecate_message("#{self}.set_paper")
      self.paper = paper_size
    end

    #
    # Set the page header caption and optional margin.
    #
    def set_header(string = '', margin = 0.3, options = {})
      raise 'Header string must be less than 255 characters' if string.length > 255

      # Replace the Excel placeholder &[Picture] with the internal &G.
      header_footer_string = string.gsub("&[Picture]", '&G')
      # placeholeder /&G/ の数
      placeholder_count = header_footer_string.scan("&G").count
      @page_setup.header = header_footer_string

      @page_setup.header_footer_aligns = options[:align_with_margins] if options[:align_with_margins]

      @page_setup.header_footer_scales = options[:scale_with_doc] if options[:scale_with_doc]

      # Reset the array in case the function is called more than once.
      @header_images = []

      [
        [:image_left, 'LH'], [:image_center, 'CH'], [:image_right, 'RH']
      ].each do |p|
        @header_images << ImageProperty.new(options[p.first], position: p.last) if options[p.first]
      end

      # # placeholeder /&G/ の数
      # placeholder_count = @page_setup.header.scan("&G").count

      raise "Number of header image (#{@header_images.size}) doesn't match placeholder count (#{placeholder_count}) in string: #{@page_setup.header}" if @header_images.size != placeholder_count

      @page_setup.margin_header         = margin || 0.3
      @page_setup.header_footer_changed = true
    end

    #
    # Set the page footer caption and optional margin.
    #
    def set_footer(string = '', margin = 0.3, options = {})
      raise 'Footer string must be less than 255 characters' if string.length > 255

      # Replace the Excel placeholder &[Picture] with the internal &G.
      @page_setup.footer = string.gsub("&[Picture]", '&G')

      @page_setup.header_footer_aligns = options[:align_with_margins] if options[:align_with_margins]

      @page_setup.header_footer_scales = options[:scale_with_doc] if options[:scale_with_doc]

      # Reset the array in case the function is called more than once.
      @footer_images = []

      [
        [:image_left, 'LF'], [:image_center, 'CF'], [:image_right, 'RF']
      ].each do |p|
        @footer_images << ImageProperty.new(options[p.first], position: p.last) if options[p.first]
      end

      # placeholeder /&G/ の数
      placeholder_count = @page_setup.footer.scan("&G").count

      raise "Number of footer image (#{@footer_images.size}) doesn't match placeholder count (#{placeholder_count}) in string: #{@page_setup.footer}" if @footer_images.size != placeholder_count

      @page_setup.margin_footer         = margin
      @page_setup.header_footer_changed = true
    end

    #
    # Center the worksheet data horizontally between the margins on the printed page:
    #
    def center_horizontally
      @page_setup.center_horizontally
    end

    #
    # Center the worksheet data vertically between the margins on the printed page:
    #
    def center_vertically
      @page_setup.center_vertically
    end

    #
    # Set all the page margins to the same value in inches.
    #
    def margins=(margin)
      self.margin_left   = margin
      self.margin_right  = margin
      self.margin_top    = margin
      self.margin_bottom = margin
    end

    #
    # Set the left and right margins to the same value in inches.
    # See set_margins
    #
    def margins_left_right=(margin)
      self.margin_left  = margin
      self.margin_right = margin
    end

    #
    # Set the top and bottom margins to the same value in inches.
    # See set_margins
    #
    def margins_top_bottom=(margin)
      self.margin_top    = margin
      self.margin_bottom = margin
    end

    #
    # Set the left margin in inches.
    # See margins=()
    #
    def margin_left=(margin)
      @page_setup.margin_left = remove_white_space(margin)
    end

    #
    # Set the right margin in inches.
    # See margins=()
    #
    def margin_right=(margin)
      @page_setup.margin_right = remove_white_space(margin)
    end

    #
    # Set the top margin in inches.
    # See margins=()
    #
    def margin_top=(margin)
      @page_setup.margin_top = remove_white_space(margin)
    end

    #
    # Set the bottom margin in inches.
    # See margins=()
    #
    def margin_bottom=(margin)
      @page_setup.margin_bottom = remove_white_space(margin)
    end

    #
    # set_margin_* methods are deprecated. use margin_*=().
    #
    def set_margins(margin)
      put_deprecate_message("#{self}.set_margins")
      self.margins = margin
    end

    #
    # this method is deprecated. use margin_left_right=().
    # Set the left and right margins to the same value in inches.
    #
    def set_margins_LR(margin)
      put_deprecate_message("#{self}.set_margins_LR")
      self.margins_left_right = margin
    end

    #
    # this method is deprecated. use margin_top_bottom=().
    # Set the top and bottom margins to the same value in inches.
    #
    def set_margins_TB(margin)
      put_deprecate_message("#{self}.set_margins_TB")
      self.margins_top_bottom = margin
    end

    #
    # this method is deprecated. use margin_left=()
    # Set the left margin in inches.
    #
    def set_margin_left(margin = 0.7)
      put_deprecate_message("#{self}.set_margin_left")
      self.margin_left = margin
    end

    #
    # this method is deprecated. use margin_right=()
    # Set the right margin in inches.
    #
    def set_margin_right(margin = 0.7)
      put_deprecate_message("#{self}.set_margin_right")
      self.margin_right = margin
    end

    #
    # this method is deprecated. use margin_top=()
    # Set the top margin in inches.
    #
    def set_margin_top(margin = 0.75)
      put_deprecate_message("#{self}.set_margin_top")
      self.margin_top = margin
    end

    #
    # this method is deprecated. use margin_bottom=()
    # Set the bottom margin in inches.
    #
    def set_margin_bottom(margin = 0.75)
      put_deprecate_message("#{self}.set_margin_bottom")
      self.margin_bottom = margin
    end

    #
    # Set the number of rows to repeat at the top of each printed page.
    #
    def repeat_rows(row_min, row_max = nil)
      row_max ||= row_min

      # Convert to 1 based.
      row_min += 1
      row_max += 1

      area = "$#{row_min}:$#{row_max}"

      # Build up the print titles "Sheet1!$1:$2"
      sheetname = quote_sheetname(@name)
      @page_setup.repeat_rows = "#{sheetname}!#{area}"
    end

    def print_repeat_rows   # :nodoc:
      @page_setup.repeat_rows
    end

    #
    # :call-seq:
    #   repeat_columns(first_col, last_col = nil)
    #
    # Set the columns to repeat at the left hand side of each printed page.
    #
    def repeat_columns(*args)
      if args[0] =~ /^\D/
        _dummy, first_col, _dummy, last_col = substitute_cellref(*args)
      else
        first_col, last_col = args
      end
      last_col ||= first_col

      area = "#{xl_col_to_name(first_col, 1)}:#{xl_col_to_name(last_col, 1)}"
      @page_setup.repeat_cols = "#{quote_sheetname(@name)}!#{area}"
    end

    def print_repeat_cols  # :nodoc:
      @page_setup.repeat_cols
    end

    #
    # :call-seq:
    #   print_area(first_row, first_col, last_row, last_col)
    #
    # This method is used to specify the area of the worksheet that will
    # be printed. All four parameters must be specified. You can also use
    # A1 notation.
    #
    def print_area(*args)
      return @page_setup.print_area.dup if args.empty?

      if (row_col_array = row_col_notation(args.first))
        row1, col1, row2, col2 = row_col_array
      else
        row1, col1, row2, col2 = args
      end

      return if [row1, col1, row2, col2].include?(nil)

      # Ignore max print area since this is the same as no print area for Excel.
      return if row1 == 0 && col1 == 0 && row2 == ROW_MAX - 1 && col2 == COL_MAX - 1

      # Build up the print area range "=Sheet2!R1C1:R2C1"
      @page_setup.print_area = convert_name_area(row1, col1, row2, col2)
    end

    #
    # Set the worksheet zoom factor in the range <tt>10 <= scale <= 400</tt>:
    #
    def zoom=(scale)
      # Confine the scale to Excel's range
      @zoom = if scale < 10 or scale > 400
                # carp "Zoom factor scale outside range: 10 <= zoom <= 400"
                100
              else
                scale.to_i
              end
    end

    # This method is deprecated. use zoom=().
    def set_zoom(scale)
      put_deprecate_message("#{self}.set_zoom")
      self.zoom = scale
    end

    #
    # Set the scale factor of the printed page.
    # Scale factors in the range 10 <= scale <= 400 are valid:
    #
    def print_scale=(scale = 100)
      scale_val = scale.to_i
      # Confine the scale to Excel's range
      scale_val = 100 if scale_val < 10 || scale_val > 400

      # Turn off "fit to page" option.
      @page_setup.fit_page = false

      @page_setup.scale              = scale_val
      @page_setup.page_setup_changed = true
    end

    #
    # This method is deprecated. use print_scale=().
    #
    def set_print_scale(scale = 100)
      put_deprecate_message("#{self}.set_print_scale")
      self.print_scale = (scale)
    end

    #
    # Set the option to print the worksheet in black and white.
    #
    def print_black_and_white
      @page_setup.black_white        = true
      @page_setup.page_setup_changed = true
    end

    #
    # Causes the write() method to treat integers with a leading zero as a string.
    # This ensures that any leading zeros such, as in zip codes, are maintained.
    #
    def keep_leading_zeros(flag = true)
      @leading_zeros = !!flag
    end

    #
    # Display the worksheet right to left for some eastern versions of Excel.
    #
    def right_to_left(flag = true)
      @right_to_left = !!flag
    end

    #
    # Hide cell zero values.
    #
    def hide_zero(flag = true)
      @show_zeros = !flag
    end

    #
    # Set the order in which pages are printed.
    #
    def print_across(across = true)
      if across
        @page_setup.across             = true
        @page_setup.page_setup_changed = true
      else
        @page_setup.across = false
      end
    end

    #
    # The start_page=() method is used to set the number of the
    # starting page when the worksheet is printed out.
    #
    def start_page=(page_start)
      @page_setup.page_start = page_start
    end

    def set_start_page(page_start)
      put_deprecate_message("#{self}.set_start_page")
      self.start_page = page_start
    end

    #
    # :call-seq:
    #  write(row, column [ , token [ , format ] ])
    #
    # Excel makes a distinction between data types such as strings, numbers,
    # blanks, formulas and hyperlinks. To simplify the process of writing
    # data the {#write()}[#method-i-write] method acts as a general alias for several more
    # specific methods:
    #
    def write(row, col, token = nil, format = nil, value1 = nil, value2 = nil)
      # Check for a cell reference in A1 notation and substitute row and column
      if (row_col_array = row_col_notation(row))
        _row, _col = row_col_array
        _token     = col
        _format    = token
        _value1    = format
        _value2    = value1
      else
        _row = row
        _col = col
        _token = token
        _format = format
        _value1 = value1
        _value2 = value2
      end
      _token ||= ''
      _token = _token.to_s if token.instance_of?(Time) || token.instance_of?(Date)

      if _format.respond_to?(:force_text_format?) && _format.force_text_format?
        write_string(_row, _col, _token, _format) # Force text format
      # Match an array ref.
      elsif _token.respond_to?(:to_ary)
        write_row(_row, _col, _token, _format, _value1, _value2)
      elsif _token.respond_to?(:coerce)  # Numeric
        write_number(_row, _col, _token, _format)
      elsif _token.respond_to?(:=~)  # String
        # Match integer with leading zero(s)
        if @leading_zeros && _token =~ /^0\d*$/
          write_string(_row, _col, _token, _format)
        elsif _token =~ /\A([+-]?)(?=\d|\.\d)\d*(\.\d*)?([Ee]([+-]?\d+))?\Z/
          write_number(_row, _col, _token, _format)
        # Match formula
        elsif _token =~ /^=/
          write_formula(_row, _col, _token, _format, _value1)
        # Match array formula
        elsif _token =~ /^\{=.*\}$/
          write_formula(_row, _col, _token, _format, _value1)
        # Match blank
        elsif _token == ''
          #        row_col_args.delete_at(2)     # remove the empty string from the parameter list
          write_blank(_row, _col, _format)
        elsif @workbook.strings_to_urls
          # Match http, https or ftp URL
          if _token =~ %r{\A[fh]tt?ps?://}
            write_url(_row, _col, _token, _format, _value1, _value2)
          # Match mailto:
          elsif _token =~ /\Amailto:/
            write_url(_row, _col, _token, _format, _value1, _value2)
          # Match internal or external sheet link
          elsif _token =~ /\A(?:in|ex)ternal:/
            write_url(_row, _col, _token, _format, _value1, _value2)
          else
            write_string(_row, _col, _token, _format)
          end
        else
          write_string(_row, _col, _token, _format)
        end
      else
        write_string(_row, _col, _token, _format)
      end
    end

    #
    # :call-seq:
    #   write_row(row, col, array [ , format ])
    #
    # Write a row of data starting from (row, col). Call write_col() if any of
    # the elements of the array are in turn array. This allows the writing
    # of 1D or 2D arrays of data in one go.
    #
    def write_row(row, col, tokens = nil, *options)
      # Check for a cell reference in A1 notation and substitute row and column
      if (row_col_array = row_col_notation(row))
        _row, _col = row_col_array
        _tokens    = col
        _options   = [tokens] + options
      else
        _row = row
        _col = col
        _tokens = tokens
        _options = options
      end
      raise "Not an array ref in call to write_row()$!" unless _tokens.respond_to?(:to_ary)

      _tokens.each do |_token|
        # Check for nested arrays
        if _token.respond_to?(:to_ary)
          write_col(_row, _col, _token, *_options)
        else
          write(_row, _col, _token, *_options)
        end
        _col += 1
      end
    end

    #
    # :call-seq:
    #   write_col(row, col, array [ , format ])
    #
    # Write a column of data starting from (row, col). Call write_row() if any of
    # the elements of the array are in turn array. This allows the writing
    # of 1D or 2D arrays of data in one go.
    #
    def write_col(row, col, tokens = nil, *options)
      if (row_col_array = row_col_notation(row))
        _row, _col = row_col_array
        _tokens    = col
        _options   = [tokens] + options if options
      else
        _row = row
        _col = col
        _tokens = tokens
        _options = options
      end

      _tokens.each do |_token|
        # write() will deal with any nested arrays
        write(_row, _col, _token, *_options)
        _row += 1
      end
    end

    #
    # :call-seq:
    #   write_comment(row, column, string, options = {})
    #
    # Write a comment to the specified row and column (zero indexed).
    #
    def write_comment(row, col, string = nil, options = nil)
      # Check for a cell reference in A1 notation and substitute row and column
      if (row_col_array = row_col_notation(row))
        _row, _col = row_col_array
        _string    = col
        _options   = string
      else
        _row = row
        _col = col
        _string = string
        _options = options
      end
      raise WriteXLSXInsufficientArgumentError if [_row, _col, _string].include?(nil)

      # Check that row and col are valid and store max and min values
      check_dimensions(_row, _col)
      store_row_col_max_min_values(_row, _col)

      @has_vml = true

      # Process the properties of the cell comment.
      @comments.add(@workbook, self, _row, _col, _string, _options)
    end

    #
    # :call-seq:
    #   write_number(row, column, number [ , format ])
    #
    # Write an integer or a float to the cell specified by row and column:
    #
    def write_number(row, col, number, format = nil)
      # Check for a cell reference in A1 notation and substitute row and column
      if (row_col_array = row_col_notation(row))
        _row, _col = row_col_array
        _number = col
        _format = number
      else
        _row = row
        _col = col
        _number = number
        _format = format
      end
      raise WriteXLSXInsufficientArgumentError if _row.nil? || _col.nil? || _number.nil?

      # Check that row and col are valid and store max and min values
      check_dimensions(_row, _col)
      store_row_col_max_min_values(_row, _col)

      store_data_to_table(NumberCellData.new(_number, _format), _row, _col)
    end

    #
    # :call-seq:
    #   write_string(row, column, string [, format ])
    #
    # Write a string to the specified row and column (zero indexed).
    # +format+ is optional.
    #
    def write_string(row, col, string = nil, format = nil)
      # Check for a cell reference in A1 notation and substitute row and column
      if (row_col_array = row_col_notation(row))
        _row, _col = row_col_array
        _string = col
        _format = string
      else
        _row = row
        _col = col
        _string = string
        _format = format
      end
      _string &&= _string.to_s
      raise WriteXLSXInsufficientArgumentError if _row.nil? || _col.nil? || _string.nil?

      # Check that row and col are valid and store max and min values
      check_dimensions(_row, _col)
      store_row_col_max_min_values(_row, _col)

      index = shared_string_index(_string.length > STR_MAX ? _string[0, STR_MAX] : _string)

      store_data_to_table(StringCellData.new(index, _format, _string), _row, _col)
    end

    #
    # :call-seq:
    #    write_rich_string(row, column, (string | format, string)+,  [,cell_format])
    #
    # The write_rich_string() method is used to write strings with multiple formats.
    # The method receives string fragments prefixed by format objects. The final
    # format object is used as the cell format.
    #
    def write_rich_string(row, col, *rich_strings)
      # Check for a cell reference in A1 notation and substitute row and column
      if (row_col_array = row_col_notation(row))
        _row, _col    = row_col_array
        _rich_strings = [col] + rich_strings
      else
        _row = row
        _col = col
        _rich_strings = rich_strings
      end
      raise WriteXLSXInsufficientArgumentError if [_row, _col, _rich_strings[0]].include?(nil)

      _xf = cell_format_of_rich_string(_rich_strings)

      # Check that row and col are valid and store max and min values
      check_dimensions(_row, _col)
      store_row_col_max_min_values(_row, _col)

      _fragments, _raw_string = rich_strings_fragments(_rich_strings)
      # can't allow 2 formats in a row
      return -4 unless _fragments

      # Check that the string si < 32767 chars.
      return 3 if _raw_string.size > @xls_strmax

      index = shared_string_index(xml_str_of_rich_string(_fragments))

      store_data_to_table(RichStringCellData.new(index, _xf, _raw_string), _row, _col)
    end

    #
    # :call-seq:
    #   write_blank(row, col, format)
    #
    # Write a blank cell to the specified row and column (zero indexed).
    # A blank cell is used to specify formatting without adding a string
    # or a number.
    #
    def write_blank(row, col, format = nil)
      # Check for a cell reference in A1 notation and substitute row and column
      if (row_col_array = row_col_notation(row))
        _row, _col = row_col_array
        _format = col
      else
        _row = row
        _col = col
        _format = format
      end
      raise WriteXLSXInsufficientArgumentError if [_row, _col].include?(nil)

      # Don't write a blank cell unless it has a format
      return unless _format

      # Check that row and col are valid and store max and min values
      check_dimensions(_row, _col)
      store_row_col_max_min_values(_row, _col)

      store_data_to_table(BlankCellData.new(_format), _row, _col)
    end

    #
    # Utility method to strip equal sign and array braces from a formula
    # and also expand out future and dynamic array formulas.
    #
    def prepare_formula(given_formula, expand_future_functions = nil)
      # Ignore empty/null formulas.
      return given_formula unless ptrue?(given_formula)

      # Remove array formula braces and the leading =.
      formula = given_formula.sub(/^\{(.*)\}$/, '\1').sub(/^=/, '')

      # # Don't expand formulas that the user has already expanded.
      return formula if formula =~ /_xlfn\./

      # Expand dynamic array formulas.
      formula = expand_formula(formula, 'ANCHORARRAY\(')
      formula = expand_formula(formula, 'BYCOL\(')
      formula = expand_formula(formula, 'BYROW\(')
      formula = expand_formula(formula, 'CHOOSECOLS\(')
      formula = expand_formula(formula, 'CHOOSEROWS\(')
      formula = expand_formula(formula, 'DROP\(')
      formula = expand_formula(formula, 'EXPAND\(')
      formula = expand_formula(formula, 'FILTER\(', '._xlws')
      formula = expand_formula(formula, 'HSTACK\(')
      formula = expand_formula(formula, 'LAMBDA\(')
      formula = expand_formula(formula, 'MAKEARRAY\(')
      formula = expand_formula(formula, 'MAP\(')
      formula = expand_formula(formula, 'RANDARRAY\(')
      formula = expand_formula(formula, 'REDUCE\(')
      formula = expand_formula(formula, 'SCAN\(')
      formula = expand_formula(formula, 'SEQUENCE\(')
      formula = expand_formula(formula, 'SINGLE\(')
      formula = expand_formula(formula, 'SORT\(', '._xlws')
      formula = expand_formula(formula, 'SORTBY\(')
      formula = expand_formula(formula, 'SWITCH\(')
      formula = expand_formula(formula, 'TAKE\(')
      formula = expand_formula(formula, 'TEXTSPLIT\(')
      formula = expand_formula(formula, 'TOCOL\(')
      formula = expand_formula(formula, 'TOROW\(')
      formula = expand_formula(formula, 'UNIQUE\(')
      formula = expand_formula(formula, 'VSTACK\(')
      formula = expand_formula(formula, 'WRAPCOLS\(')
      formula = expand_formula(formula, 'WRAPROWS\(')
      formula = expand_formula(formula, 'XLOOKUP\(')

      if !@use_future_functions && !ptrue?(expand_future_functions)
        return formula
      end

      # Future functions.
      formula = expand_formula(formula, 'ACOTH\(')
      formula = expand_formula(formula, 'ACOT\(')
      formula = expand_formula(formula, 'AGGREGATE\(')
      formula = expand_formula(formula, 'ARABIC\(')
      formula = expand_formula(formula, 'ARRAYTOTEXT\(')
      formula = expand_formula(formula, 'BASE\(')
      formula = expand_formula(formula, 'BETA.DIST\(')
      formula = expand_formula(formula, 'BETA.INV\(')
      formula = expand_formula(formula, 'BINOM.DIST.RANGE\(')
      formula = expand_formula(formula, 'BINOM.DIST\(')
      formula = expand_formula(formula, 'BINOM.INV\(')
      formula = expand_formula(formula, 'BITAND\(')
      formula = expand_formula(formula, 'BITLSHIFT\(')
      formula = expand_formula(formula, 'BITOR\(')
      formula = expand_formula(formula, 'BITRSHIFT\(')
      formula = expand_formula(formula, 'BITXOR\(')
      formula = expand_formula(formula, 'CEILING.MATH\(')
      formula = expand_formula(formula, 'CEILING.PRECISE\(')
      formula = expand_formula(formula, 'CHISQ.DIST.RT\(')
      formula = expand_formula(formula, 'CHISQ.DIST\(')
      formula = expand_formula(formula, 'CHISQ.INV.RT\(')
      formula = expand_formula(formula, 'CHISQ.INV\(')
      formula = expand_formula(formula, 'CHISQ.TEST\(')
      formula = expand_formula(formula, 'COMBINA\(')
      formula = expand_formula(formula, 'CONCAT\(')
      formula = expand_formula(formula, 'CONFIDENCE.NORM\(')
      formula = expand_formula(formula, 'CONFIDENCE.T\(')
      formula = expand_formula(formula, 'COTH\(')
      formula = expand_formula(formula, 'COT\(')
      formula = expand_formula(formula, 'COVARIANCE.P\(')
      formula = expand_formula(formula, 'COVARIANCE.S\(')
      formula = expand_formula(formula, 'CSCH\(')
      formula = expand_formula(formula, 'CSC\(')
      formula = expand_formula(formula, 'DAYS\(')
      formula = expand_formula(formula, 'DECIMAL\(')
      formula = expand_formula(formula, 'ERF.PRECISE\(')
      formula = expand_formula(formula, 'ERFC.PRECISE\(')
      formula = expand_formula(formula, 'EXPON.DIST\(')
      formula = expand_formula(formula, 'F.DIST.RT\(')
      formula = expand_formula(formula, 'F.DIST\(')
      formula = expand_formula(formula, 'F.INV.RT\(')
      formula = expand_formula(formula, 'F.INV\(')
      formula = expand_formula(formula, 'F.TEST\(')
      formula = expand_formula(formula, 'FILTERXML\(')
      formula = expand_formula(formula, 'FLOOR.MATH\(')
      formula = expand_formula(formula, 'FLOOR.PRECISE\(')
      formula = expand_formula(formula, 'FORECAST.ETS.CONFINT\(')
      formula = expand_formula(formula, 'FORECAST.ETS.SEASONALITY\(')
      formula = expand_formula(formula, 'FORECAST.ETS.STAT\(')
      formula = expand_formula(formula, 'FORECAST.ETS\(')
      formula = expand_formula(formula, 'FORECAST.LINEAR\(')
      formula = expand_formula(formula, 'FORMULATEXT\(')
      formula = expand_formula(formula, 'GAMMA.DIST\(')
      formula = expand_formula(formula, 'GAMMA.INV\(')
      formula = expand_formula(formula, 'GAMMALN.PRECISE\(')
      formula = expand_formula(formula, 'GAMMA\(')
      formula = expand_formula(formula, 'GAUSS\(')
      formula = expand_formula(formula, 'HYPGEOM.DIST\(')
      formula = expand_formula(formula, 'IFNA\(')
      formula = expand_formula(formula, 'IFS\(')
      formula = expand_formula(formula, 'IMAGE\(')
      formula = expand_formula(formula, 'IMCOSH\(')
      formula = expand_formula(formula, 'IMCOT\(')
      formula = expand_formula(formula, 'IMCSCH\(')
      formula = expand_formula(formula, 'IMCSC\(')
      formula = expand_formula(formula, 'IMSECH\(')
      formula = expand_formula(formula, 'IMSEC\(')
      formula = expand_formula(formula, 'IMSINH\(')
      formula = expand_formula(formula, 'IMTAN\(')
      formula = expand_formula(formula, 'ISFORMULA\(')
      formula = expand_formula(formula, 'ISOMITTED\(')
      formula = expand_formula(formula, 'ISOWEEKNUM\(')
      formula = expand_formula(formula, 'LET\(')
      formula = expand_formula(formula, 'LOGNORM.DIST\(')
      formula = expand_formula(formula, 'LOGNORM.INV\(')
      formula = expand_formula(formula, 'MAXIFS\(')
      formula = expand_formula(formula, 'MINIFS\(')
      formula = expand_formula(formula, 'MODE.MULT\(')
      formula = expand_formula(formula, 'MODE.SNGL\(')
      formula = expand_formula(formula, 'MUNIT\(')
      formula = expand_formula(formula, 'NEGBINOM.DIST\(')
      formula = expand_formula(formula, 'NORM.DIST\(')
      formula = expand_formula(formula, 'NORM.INV\(')
      formula = expand_formula(formula, 'NORM.S.DIST\(')
      formula = expand_formula(formula, 'NORM.S.INV\(')
      formula = expand_formula(formula, 'NUMBERVALUE\(')
      formula = expand_formula(formula, 'PDURATION\(')
      formula = expand_formula(formula, 'PERCENTILE.EXC\(')
      formula = expand_formula(formula, 'PERCENTILE.INC\(')
      formula = expand_formula(formula, 'PERCENTRANK.EXC\(')
      formula = expand_formula(formula, 'PERCENTRANK.INC\(')
      formula = expand_formula(formula, 'PERMUTATIONA\(')
      formula = expand_formula(formula, 'PHI\(')
      formula = expand_formula(formula, 'POISSON.DIST\(')
      formula = expand_formula(formula, 'QUARTILE.EXC\(')
      formula = expand_formula(formula, 'QUARTILE.INC\(')
      formula = expand_formula(formula, 'QUERYSTRING\(')
      formula = expand_formula(formula, 'RANK.AVG\(')
      formula = expand_formula(formula, 'RANK.EQ\(')
      formula = expand_formula(formula, 'RRI\(')
      formula = expand_formula(formula, 'SECH\(')
      formula = expand_formula(formula, 'SEC\(')
      formula = expand_formula(formula, 'SHEETS\(')
      formula = expand_formula(formula, 'SHEET\(')
      formula = expand_formula(formula, 'SKEW.P\(')
      formula = expand_formula(formula, 'STDEV.P\(')
      formula = expand_formula(formula, 'STDEV.S\(')
      formula = expand_formula(formula, 'T.DIST.2T\(')
      formula = expand_formula(formula, 'T.DIST.RT\(')
      formula = expand_formula(formula, 'T.DIST\(')
      formula = expand_formula(formula, 'T.INV.2T\(')
      formula = expand_formula(formula, 'T.INV\(')
      formula = expand_formula(formula, 'T.TEST\(')
      formula = expand_formula(formula, 'TEXTAFTER\(')
      formula = expand_formula(formula, 'TEXTBEFORE\(')
      formula = expand_formula(formula, 'TEXTJOIN\(')
      formula = expand_formula(formula, 'UNICHAR\(')
      formula = expand_formula(formula, 'UNICODE\(')
      formula = expand_formula(formula, 'VALUETOTEXT\(')
      formula = expand_formula(formula, 'VAR.P\(')
      formula = expand_formula(formula, 'VAR.S\(')
      formula = expand_formula(formula, 'WEBSERVICE\(')
      formula = expand_formula(formula, 'WEIBULL.DIST\(')
      formula = expand_formula(formula, 'XMATCH\(')
      formula = expand_formula(formula, 'XOR\(')
      expand_formula(formula, 'Z.TEST\(')
    end

    #
    # :call-seq:
    #   write_formula(row, column, formula [ , format [ , value ] ])
    #
    # Write a formula or function to the cell specified by +row+ and +column+:
    #
    def write_formula(row, col, formula = nil, format = nil, value = nil)
      # Check for a cell reference in A1 notation and substitute row and column
      if (row_col_array = row_col_notation(row))
        _row, _col = row_col_array
        _formula   = col
        _format    = formula
        _value     = format
      else
        _row = row
        _col = col
        _formula = formula
        _format = format
        _value = value
      end
      raise WriteXLSXInsufficientArgumentError if [_row, _col, _formula].include?(nil)

      # Check for dynamic array functions.
      regex = /\bANCHORARRAY\(|\bBYCOL\(|\bBYROW\(|\bCHOOSECOLS\(|\bCHOOSEROWS\(|\bDROP\(|\bEXPAND\(|\bFILTER\(|\bHSTACK\(|\bLAMBDA\(|\bMAKEARRAY\(|\bMAP\(|\bRANDARRAY\(|\bREDUCE\(|\bSCAN\(|\bSEQUENCE\(|\bSINGLE\(|\bSORT\(|\bSORTBY\(|\bSWITCH\(|\bTAKE\(|\bTEXTSPLIT\(|\bTOCOL\(|\bTOROW\(|\bUNIQUE\(|\bVSTACK\(|\bWRAPCOLS\(|\bWRAPROWS\(|\bXLOOKUP\(/
      if _formula =~ regex
        return write_dynamic_array_formula(
          _row, _col, _row, _col, _formula, _format, _value
        )
      end

      # Hand off array formulas.
      if _formula =~ /^\{=.*\}$/
        write_array_formula(_row, _col, _row, _col, _formula, _format, _value)
      else
        check_dimensions(_row, _col)
        store_row_col_max_min_values(_row, _col)
        _formula = prepare_formula(_formula)

        store_data_to_table(FormulaCellData.new(_formula, _format, _value), _row, _col)
      end
    end

    #
    # Internal method shared by the write_array_formula() and
    # write_dynamic_array_formula() methods.
    #
    def write_array_formula_base(type, *args)
      # Check for a cell reference in A1 notation and substitute row and column
      # Convert single cell to range
      if args.first.to_s =~ /^([A-Za-z]+[0-9]+)$/
        range = "#{::Regexp.last_match(1)}:#{::Regexp.last_match(1)}"
        params = [range] + args[1..-1]
      else
        params = args
      end

      if (row_col_array = row_col_notation(params.first))
        row1, col1, row2, col2 = row_col_array
        formula, xf, value = params[1..-1]
      else
        row1, col1, row2, col2, formula, xf, value = params
      end
      raise WriteXLSXInsufficientArgumentError if [row1, col1, row2, col2, formula].include?(nil)

      # Swap last row/col with first row/col as necessary
      row1, row2 = row2, row1 if row1 > row2
      col1, col2 = col2, col1 if col1 > col2

      # Check that row and col are valid and store max and min values
      check_dimensions(row1, col1)
      check_dimensions(row2, col2)
      store_row_col_max_min_values(row1, col1)
      store_row_col_max_min_values(row2, col2)

      # Define array range
      range = if row1 == row2 && col1 == col2
                xl_rowcol_to_cell(row1, col1)
              else
                "#{xl_rowcol_to_cell(row1, col1)}:#{xl_rowcol_to_cell(row2, col2)}"
              end

      # Modify the formula string, as needed.
      formula = prepare_formula(formula, 1)

      store_data_to_table(
        if type == 'a'
          FormulaArrayCellData.new(formula, xf, range, value)
        elsif type == 'd'
          DynamicFormulaArrayCellData.new(formula, xf, range, value)
        else
          raise "invalid type in write_array_formula_base()."
        end,
        row1, col1
      )

      # Pad out the rest of the area with formatted zeroes.
      (row1..row2).each do |row|
        (col1..col2).each do |col|
          next if row == row1 && col == col1

          write_number(row, col, 0, xf)
        end
      end
    end

    #
    # write_array_formula(row1, col1, row2, col2, formula, format)
    #
    # Write an array formula to the specified row and column (zero indexed).
    #
    def write_array_formula(row1, col1, row2 = nil, col2 = nil, formula = nil, format = nil, value = nil)
      write_array_formula_base('a', row1, col1, row2, col2, formula, format, value)
    end

    #
    # write_dynamic_array_formula(row1, col1, row2, col2, formula, format)
    #
    # Write a dynamic formula to the specified row and column (zero indexed).
    #
    def write_dynamic_array_formula(row1, col1, row2 = nil, col2 = nil, formula = nil, format = nil, value = nil)
      write_array_formula_base('d', row1, col1, row2, col2, formula, format, value)
      @has_dynamic_functions = true
    end

    #
    # write_boolean(row, col, val, format)
    #
    # Write a boolean value to the specified row and column (zero indexed).
    #
    def write_boolean(row, col, val = nil, format = nil)
      if (row_col_array = row_col_notation(row))
        _row, _col = row_col_array
        _val       = col
        _format    = val
      else
        _row = row
        _col = col
        _val = val
        _format = format
      end
      raise WriteXLSXInsufficientArgumentError if _row.nil? || _col.nil?

      _val = _val ? 1 : 0  # Boolean value.
      # xf : cell format.

      # Check that row and col are valid and store max and min values
      check_dimensions(_row, _col)
      store_row_col_max_min_values(_row, _col)

      store_data_to_table(BooleanCellData.new(_val, _format), _row, _col)
    end

    #
    # :call-seq:
    #   update_format_with_params(row, col, format_params)
    #
    # Update formatting of the cell to the specified row and column (zero indexed).
    #
    def update_format_with_params(row, col, params = nil)
      if (row_col_array = row_col_notation(row))
        _row, _col = row_col_array
        _params = args[1]
      else
        _row = row
        _col = col
        _params = params
      end
      raise WriteXLSXInsufficientArgumentError if _row.nil? || _col.nil? || _params.nil?

      # Check that row and col are valid and store max and min values
      check_dimensions(_row, _col)
      store_row_col_max_min_values(_row, _col)

      format = nil
      cell_data = nil
      if @cell_data_table[_row].nil? || @cell_data_table[_row][_col].nil?
        format = @workbook.add_format(_params)
        write_blank(_row, _col, format)
      else
        if @cell_data_table[_row][_col].xf.nil?
          format = @workbook.add_format(_params)
          cell_data = @cell_data_table[_row][_col]
        else
          format = @workbook.add_format
          cell_data = @cell_data_table[_row][_col]
          format.copy(cell_data.xf)
          format.set_format_properties(_params)
        end
        # keep original value of cell
        value = if cell_data.is_a? FormulaCellData
                  "=#{cell_data.token}"
                elsif cell_data.is_a? FormulaArrayCellData
                  "{=#{cell_data.token}}"
                elsif cell_data.is_a? StringCellData
                  @workbook.shared_strings.string(cell_data.data[:sst_id])
                else
                  cell_data.data
                end
        write(_row, _col, value, format)
      end
    end

    #
    # :call-seq:
    #   update_range_format_with_params(row_first, col_first, row_last, col_last, format_params)
    #
    # Update formatting of cells in range to the specified row and column (zero indexed).
    #
    def update_range_format_with_params(row_first, col_first, row_last = nil, col_last = nil, params = nil)
      if (row_col_array = row_col_notation(row_first))
        _row_first, _col_first, _row_last, _col_last = row_col_array
        params = args[1..-1]
      else
        _row_first = row_first
        _col_first = col_first
        _row_last  = row_last
        _col_last  = col_last
        _params    = params
      end

      raise WriteXLSXInsufficientArgumentError if [_row_first, _col_first, _row_last, _col_last, _params].include?(nil)

      # Swap last row/col with first row/col as necessary
      _row_first, _row_last = _row_last, _row_first if _row_first > _row_last
      _col_first, _col_last = _col_last, _col_first if _col_first > _col_last

      # Check that column number is valid and store the max value
      check_dimensions(_row_last, _col_last)
      store_row_col_max_min_values(_row_last, _col_last)

      (_row_first.._row_last).each do |row|
        (_col_first.._col_last).each do |col|
          update_format_with_params(row, col, _params)
        end
      end
    end

    #
    # The outline_settings() method is used to control the appearance of
    # outlines in Excel.
    #
    def outline_settings(visible = 1, symbols_below = 1, symbols_right = 1, auto_style = false)
      @outline_on    = visible
      @outline_below = symbols_below
      @outline_right = symbols_right
      @outline_style = auto_style

      @outline_changed = 1
    end

    #
    # Deprecated. This is a writeexcel method that is no longer required
    # by WriteXLSX. See below.
    #
    def store_formula(string)
      string.split(/(\$?[A-I]?[A-Z]\$?\d+)/)
    end

    #
    # :call-seq:
    #   write_url(row, column, url [ , format, label, tip ])
    #
    # Write a hyperlink to a URL in the cell specified by +row+ and +column+.
    # The hyperlink is comprised of two elements: the visible label and
    # the invisible link. The visible label is the same as the link unless
    # an alternative label is specified. The label parameter is optional.
    # The label is written using the {#write()}[#method-i-write] method. Therefore it is
    # possible to write strings, numbers or formulas as labels.
    #
    def write_url(row, col, url = nil, format = nil, str = nil, tip = nil, ignore_write_string = false)
      # Check for a cell reference in A1 notation and substitute row and column
      if (row_col_array = row_col_notation(row))
        _row, _col           = row_col_array
        _url                 = col
        _format              = url
        _str                 = format
        _tip                 = str
        _ignore_write_string = tip
      else
        _row                 = row
        _col                 = col
        _url                 = url
        _format              = format
        _str                 = str
        _tip                 = tip
        _ignore_write_string = ignore_write_string
      end

      _format, _str = _str, _format if _str.respond_to?(:xf_index) || (_format && !_format.respond_to?(:xf_index))
      raise WriteXLSXInsufficientArgumentError if [_row, _col, _url].include?(nil)

      # Check that row and col are valid and store max and min values
      check_dimensions(_row, _col)
      store_row_col_max_min_values(_row, _col)

      hyperlink = Hyperlink.factory(_url, _str, _tip, @max_url_length)
      store_hyperlink(_row, _col, hyperlink)

      raise "URL '#{url}' added but URL exceeds Excel's limit of 65,530 URLs per worksheet." if hyperlinks_count > 65_530

      # Add the default URL format.
      _format ||= @default_url_format

      # Write the hyperlink string.
      write_string(_row, _col, hyperlink.str, _format) unless _ignore_write_string
    end

    #
    # :call-seq:
    #   write_date_time (row, col, date_string [ , format ])
    #
    # Write a datetime string in ISO8601 "yyyy-mm-ddThh:mm:ss.ss" format as a
    # number representing an Excel date. format is optional.
    #
    def write_date_time(row, col, str, format = nil)
      # Check for a cell reference in A1 notation and substitute row and column
      if (row_col_array = row_col_notation(row))
        _row, _col = row_col_array
        _str       = col
        _format    = str
      else
        _row = row
        _col = col
        _str = str
        _format = format
      end
      raise WriteXLSXInsufficientArgumentError if [_row, _col, _str].include?(nil)

      # Check that row and col are valid and store max and min values
      check_dimensions(_row, _col)
      store_row_col_max_min_values(_row, _col)

      date_time = convert_date_time(_str)

      if date_time
        store_data_to_table(DateTimeCellData.new(date_time, _format), _row, _col)
      else
        # If the date isn't valid then write it as a string.
        write_string(_row, _col, _str, _format)
      end
    end

    #
    # :call-seq:
    #   insert_chart(row, column, chart [ , x, y, x_scale, y_scale ])
    #
    # This method can be used to insert a Chart object into a worksheet.
    # The Chart must be created by the add_chart() Workbook method and
    # it must have the embedded option set.
    #
    def insert_chart(row, col, chart = nil, *options)
      # Check for a cell reference in A1 notation and substitute row and column.
      if (row_col_array = row_col_notation(row))
        _row, _col = row_col_array
        _chart     = col
        _options   = [chart] + options
      else
        _row = row
        _col = col
        _chart = chart
        _options = options
      end
      raise WriteXLSXInsufficientArgumentError if [_row, _col, _chart].include?(nil)

      if _options.first.instance_of?(Hash)
        params = _options.first
        x_offset    = params[:x_offset]
        y_offset    = params[:y_offset]
        x_scale     = params[:x_scale]
        y_scale     = params[:y_scale]
        anchor      = params[:object_position]
        description = params[:description]
        decorative  = params[:decorative]
      else
        x_offset, y_offset, x_scale, y_scale, anchor = _options
      end
      x_offset ||= 0
      y_offset ||= 0
      x_scale  ||= 1
      y_scale  ||= 1
      anchor   ||= 1

      raise "Not a Chart object in insert_chart()" unless _chart.is_a?(Chart) || _chart.is_a?(Chartsheet)
      raise "Not a embedded style Chart object in insert_chart()" if _chart.respond_to?(:embedded) && _chart.embedded == 0

      if _chart.already_inserted? || (_chart.combined && _chart.combined.already_inserted?)
        raise "Chart cannot be inserted in a worksheet more than once"
      else
        _chart.already_inserted          = true
        _chart.combined.already_inserted = true if _chart.combined
      end

      # Use the values set with chart.set_size, if any.
      x_scale  = _chart.x_scale  if _chart.x_scale  != 1
      y_scale  = _chart.y_scale  if _chart.y_scale  != 1
      x_offset = _chart.x_offset if ptrue?(_chart.x_offset)
      y_offset = _chart.y_offset if ptrue?(_chart.y_offset)

      @charts << InsertedChart.new(
        _row,    _col,    _chart, x_offset,    y_offset,
        x_scale, y_scale, anchor, description, decorative
      )
    end

    #
    # :call-seq:
    #   insert_image(row, column, filename, options)
    #
    def insert_image(row, col, image = nil, *options)
      # Check for a cell reference in A1 notation and substitute row and column.
      if (row_col_array = row_col_notation(row))
        _row, _col = row_col_array
        _image     = col
        _options   = [image] + options
      else
        _row = row
        _col = col
        _image = image
        _options = options
      end
      raise WriteXLSXInsufficientArgumentError if [_row, _col, _image].include?(nil)

      if _options.first.instance_of?(Hash)
        # Newer hash bashed options
        params      = _options.first
        x_offset    = params[:x_offset]
        y_offset    = params[:y_offset]
        x_scale     = params[:x_scale]
        y_scale     = params[:y_scale]
        anchor      = params[:object_position]
        url         = params[:url]
        tip         = params[:tip]
        description = params[:description]
        decorative  = params[:decorative]
      else
        x_offset, y_offset, x_scale, y_scale, anchor = _options
      end
      x_offset ||= 0
      y_offset ||= 0
      x_scale  ||= 1
      y_scale  ||= 1
      anchor   ||= 2

      @images << Image.new(
        _row, _col, _image, x_offset, y_offset,
        x_scale, y_scale, url, tip, anchor, description, decorative
      )
    end

    #
    # Embed an image into the worksheet.
    #
    def embed_image(row, col, filename, options = nil)
      # Check for a cell reference in A1 notation and substitute row and column.
      if (row_col_array = row_col_notation(row))
        _row, _col = row_col_array
        image      = col
        _options   = filename
      else
        _row     = row
        _col     = col
        image    = filename
        _options = options
      end
      xf, url, tip, description, decorative = []

      raise WriteXLSXInsufficientArgumentError if [_row, _col, image].include?(nil)
      raise "Couldn't locate #{image}" unless File.exist?(image)

      # Check that row and col are valid and store max and min values
      check_dimensions(_row, _col)
      store_row_col_max_min_values(_row, _col)

      if options
        xf          = options[:cell_format]
        url         = options[:url]
        tip         = options[:tip]
        description = options[:description]
        decorative  = options[:decorative]
      end

      # Write the url without writing a string.
      if url
        xf ||= @default_url_format

        write_url(row, col, url, xf, nil, tip, true)
      end

      # Get the image properties, mainly for the type and checksum.
      image_property = ImageProperty.new(
        image, description: description, decorative: decorative
      )
      @workbook.store_image_types(image_property.type)

      # Check for duplicate images.
      image_index = @embedded_image_indexes[image_property.md5]

      unless ptrue?(image_index)
        @workbook.embedded_images << image_property

        image_index = @workbook.embedded_images.size
        @embedded_image_indexes[image_property.md5] = image_index
      end

      # Write the cell placeholder.
      store_data_to_table(EmbedImageCellData.new(image_index, xf), _row, _col)
      @has_embedded_images = true
    end

    #
    # :call-seq:
    #   insert_shape(row, col, shape [ , x, y, x_scale, y_scale ])
    #
    # Insert a shape into the worksheet.
    #
    def insert_shape(
          row_start, column_start, shape = nil, x_offset = nil, y_offset = nil,
          x_scale = nil, y_scale = nil, anchor = nil
        )
      # Check for a cell reference in A1 notation and substitute row and column.
      if (row_col_array = row_col_notation(row_start))
        _row_start, _column_start = row_col_array
        _shape    = column_start
        _x_offset = shape
        _y_offset = x_offset
        _x_scale  = y_offset
        _y_scale  = x_scale
        _anchor   = y_scale
      else
        _row_start = row_start
        _column_start = column_start
        _shape = shape
        _x_offset = x_offset
        _y_offset = y_offset
        _x_scale = x_scale
        _y_scale = y_scale
        _anchor = anchor
      end
      raise "Insufficient arguments in insert_shape()" if [_row_start, _column_start, _shape].include?(nil)

      _shape.set_position(
        _row_start, _column_start, _x_offset, _y_offset,
        _x_scale, _y_scale, _anchor
      )
      # Assign a shape ID.
      while true
        id = _shape.id || 0
        used = @shape_hash[id]

        # Test if shape ID is already used. Otherwise assign a new one.
        if !used && id != 0
          break
        else
          @last_shape_id += 1
          _shape.id = @last_shape_id
        end
      end

      # Allow lookup of entry into shape array by shape ID.
      @shape_hash[_shape.id] = _shape.element = @shapes.size

      insert = if ptrue?(_shape.stencil)
                 # Insert a copy of the shape, not a reference so that the shape is
                 # used as a stencil. Previously stamped copies don't get modified
                 # if the stencil is modified.
                 _shape.dup
               else
                 _shape
               end

      # For connectors change x/y coords based on location of connected shapes.
      insert.auto_locate_connectors(@shapes, @shape_hash)

      # Insert a link to the shape on the list of shapes. Connection to
      # the parent shape is maintained.
      @shapes << insert
      insert
    end

    #
    # :call-seq:
    #   repeat_formula(row, column, formula [ , format ])
    #
    # Deprecated. This is a writeexcel gem's method that is no longer
    # required by WriteXLSX.
    #
    def repeat_formula(row, col, formula, format, *pairs)
      # Check for a cell reference in A1 notation and substitute row and column.
      if (row_col_array = row_col_notation(row))
        _row, _col = row_col_array
        _formula   = col
        _format    = formula
        _pairs     = [format] + pairs
      else
        _row = row
        _col = col
        _formula = formula
        _format = format
        _pairs = pairs
      end
      raise WriteXLSXInsufficientArgumentError if [_row, _col].include?(nil)

      raise "Odd number of elements in pattern/replacement list" unless _pairs.size.even?
      raise "Not a valid formula" unless _formula.respond_to?(:to_ary)

      tokens  = _formula.join("\t").split("\t")
      raise "No tokens in formula" if tokens.empty?

      _value = nil
      if _pairs[-2] == 'result'
        _value = _pairs.pop
        _pairs.pop
      end
      until _pairs.empty?
        pattern = _pairs.shift
        replace = _pairs.shift

        tokens.each do |token|
          break if token.sub!(pattern, replace)
        end
      end
      _formula = tokens.join('')
      write_formula(_row, _col, _formula, _format, _value)
    end

    #
    # :call-seq:
    #   set_row(row [ , height, format, hidden, level, collapsed ])
    #
    # This method can be used to change the default properties of a row.
    # All parameters apart from +row+ are optional.
    #
    def set_row(*args)
      return unless args[0]

      row = args[0]
      height = args[1] || @default_height
      xf     = args[2]
      hidden = args[3] || 0
      level  = args[4] || 0
      collapsed = args[5] || 0

      # Use min col in check_dimensions. Default to 0 if undefined.
      min_col = @dim_colmin || 0

      # Check that row and col are valid and store max and min values.
      check_dimensions(row, min_col)
      store_row_col_max_min_values(row, min_col)

      height ||= @default_row_height

      # If the height is 0 the row is hidden and the height is the default.
      if height == 0
        hidden = 1
        height = @default_row_height
      end

      # Set the limits for the outline levels (0 <= x <= 7).
      level = 0 if level < 0
      level = 7 if level > 7

      @outline_row_level = level if level > @outline_row_level

      # Store the row properties.
      @set_rows[row] = [height, xf, hidden, level, collapsed]

      # Store the row change to allow optimisations.
      @row_size_changed = true

      # Store the row sizes for use when calculating image vertices.
      @row_sizes[row] = [height, hidden]
    end

    #
    # This method is used to set the height (in pixels) and the properties of the
    # row.
    #
    def set_row_pixels(*data)
      height = data[1]

      data[1] = pixels_to_height(height) if ptrue?(height)
      set_row(*data)
    end

    #
    # Set the default row properties
    #
    def set_default_row(height = nil, zero_height = nil)
      height      ||= @original_row_height
      zero_height ||= 0

      if height != @original_row_height
        @default_row_height = height

        # Store the row change to allow optimisations.
        @row_size_changed = 1
      end

      @default_row_zeroed = 1 if ptrue?(zero_height)
    end

    #
    # merge_range(first_row, first_col, last_row, last_col, string, format)
    #
    # Merge a range of cells. The first cell should contain the data and the
    # others should be blank. All cells should contain the same format.
    #
    def merge_range(*args)
      if (row_col_array = row_col_notation(args.first))
        row_first, col_first, row_last, col_last = row_col_array
        string, format, *extra_args = args[1..-1]
      else
        row_first, col_first, row_last, col_last,
        string, format, *extra_args = args
      end

      raise "Incorrect number of arguments" if [row_first, col_first, row_last, col_last, format].include?(nil)
      raise "Fifth parameter must be a format object" unless format.respond_to?(:xf_index)
      raise "Can't merge single cell" if row_first == row_last && col_first == col_last

      # Swap last row/col with first row/col as necessary
      row_first,  row_last = row_last,  row_first  if row_first > row_last
      col_first, col_last = col_last, col_first if col_first > col_last

      # Check that the data range is valid and store the max and min values.
      check_dimensions(row_first, col_first)
      check_dimensions(row_last,  col_last)
      store_row_col_max_min_values(row_first, col_first)
      store_row_col_max_min_values(row_last,  col_last)

      # Store the merge range.
      @merge << [row_first, col_first, row_last, col_last]

      # Write the first cell
      write(row_first, col_first, string, format, *extra_args)

      # Pad out the rest of the area with formatted blank cells.
      write_formatted_blank_to_area(row_first, row_last, col_first, col_last, format)
    end

    #
    # Same as merge_range() above except the type of
    # {#write()}[#method-i-write] is specified.
    #
    def merge_range_type(type, *args)
      case type
      when 'array_formula', 'blank', 'rich_string'
        if (row_col_array = row_col_notation(args.first))
          row_first, col_first, row_last, col_last = row_col_array
          *others = args[1..-1]
        else
          row_first, col_first, row_last, col_last, *others = args
        end
        format = others.pop
      else
        if (row_col_array = row_col_notation(args.first))
          row_first, col_first, row_last, col_last = row_col_array
          token, format, *others = args[1..-1]
        else
          row_first, col_first, row_last, col_last,
          token, format, *others = args
        end
      end

      raise "Format object missing or in an incorrect position" unless format.respond_to?(:xf_index)
      raise "Can't merge single cell" if row_first == row_last && col_first == col_last

      # Swap last row/col with first row/col as necessary
      row_first, row_last = row_last, row_first if row_first > row_last
      col_first, col_last = col_last, col_first if col_first > col_last

      # Check that the data range is valid and store the max and min values.
      check_dimensions(row_first, col_first)
      check_dimensions(row_last,  col_last)
      store_row_col_max_min_values(row_first, col_first)
      store_row_col_max_min_values(row_last,  col_last)

      # Store the merge range.
      @merge << [row_first, col_first, row_last, col_last]

      # Write the first cell
      case type
      when 'blank', 'rich_string', 'array_formula'
        others << format
      end

      case type
      when 'string'
        write_string(row_first, col_first, token, format, *others)
      when 'number'
        write_number(row_first, col_first, token, format, *others)
      when 'blank'
        write_blank(row_first, col_first, *others)
      when 'date_time'
        write_date_time(row_first, col_first, token, format, *others)
      when 'rich_string'
        write_rich_string(row_first, col_first, *others)
      when 'url'
        write_url(row_first, col_first, token, format, *others)
      when 'formula'
        write_formula(row_first, col_first, token, format, *others)
      when 'array_formula'
        write_formula_array(row_first, col_first, *others)
      else
        raise "Unknown type '#{type}'"
      end

      # Pad out the rest of the area with formatted blank cells.
      write_formatted_blank_to_area(row_first, row_last, col_first, col_last, format)
    end

    #
    # :call-seq:
    #   conditional_formatting(cell_or_cell_range, options)
    #
    # Conditional formatting is a feature of Excel which allows you to apply a
    # format to a cell or a range of cells based on a certain criteria.
    #
    def conditional_formatting(*args)
      cond_format = Package::ConditionalFormat.factory(self, *args)
      @cond_formats[cond_format.range] ||= []
      @cond_formats[cond_format.range] << cond_format
    end

    #
    # :call-seq:
    #    add_table(row1, col1, row2, col2, properties)
    #
    # Add an Excel table to a worksheet.
    #
    def add_table(*args)
      # Table count is a member of Workbook, global to all Worksheet.
      table = Package::Table.new(self, *args)
      @tables << table
      table
    end

    #
    # :call-seq:
    #    add_sparkline(properties)
    #
    # Add sparklines to the worksheet.
    #
    def add_sparkline(param)
      @sparklines << Sparkline.new(self, param, quote_sheetname(@name))
    end

    #
    # :call-seq:
    #   insert_button(row, col, properties)
    #
    # The insert_button() method can be used to insert an Excel form button
    # into a worksheet.
    #
    def insert_button(row, col, properties = nil)
      if (row_col_array = row_col_notation(row))
        _row, _col = row_col_array
        _properties = col
      else
        _row = row
        _col = col
        _properties = properties
      end

      @buttons_array << Writexlsx::Package::Button.new(
        self, _row, _col, _properties, @default_row_pixels, @buttons_array.size + 1
      )
      @has_vml = true
    end

    #
    # :call-seq:
    #   data_validation(cell_or_cell_range, options)
    #
    # Data validation is a feature of Excel which allows you to restrict
    # the data that a users enters in a cell and to display help and
    # warning messages. It also allows you to restrict input to values
    # in a drop down list.
    #
    def data_validation(*args)
      validation = DataValidation.new(*args)
      @validations << validation unless validation.validate_none?
    end

    #
    # Set the option to hide gridlines on the screen and the printed page.
    #
    def hide_gridlines(option = 1)
      @screen_gridlines = (option != 2)

      @page_setup.hide_gridlines(option)
    end

    # Set the option to print the row and column headers on the printed page.
    #
    def print_row_col_headers(headers = true)
      @page_setup.print_row_col_headers(headers)
      # if headers
      #   @print_headers         = 1
      #   @page_setup.print_options_changed = 1
      # else
      #   @print_headers = 0
      # end
    end

    #
    # Set the option to hide the row and column headers in Excel.
    #
    def hide_row_col_headers
      @hide_row_col_headers = 1
    end

    #
    # The fit_to_pages() method is used to fit the printed area to a specific
    # number of pages both vertically and horizontally. If the printed area
    # exceeds the specified number of pages it will be scaled down to fit.
    # This guarantees that the printed area will always appear on the
    # specified number of pages even if the page size or margins change.
    #
    def fit_to_pages(width = 1, height = 1)
      @page_setup.fit_page   = true
      @page_setup.fit_width  = width
      @page_setup.fit_height = height
      @page_setup.page_setup_changed = true
    end

    #
    # :call-seq:
    #   autofilter(first_row, first_col, last_row, last_col)
    #
    # Set the autofilter area in the worksheet.
    #
    def autofilter(row1, col1 = nil, row2 = nil, col2 = nil)
      if (row_col_array = row_col_notation(row1))
        _row1, _col1, _row2, _col2 = row_col_array
      else
        _row1 = row1
        _col1 = col1
        _row2 = row2
        _col2 = col2
      end
      return if [_row1, _col1, _row2, _col2].include?(nil)

      # Reverse max and min values if necessary.
      _row1, _row2 = _row2, _row1 if _row2 < _row1
      _col1, _col2 = _col2, _col1 if _col2 < _col1

      @autofilter_area = convert_name_area(_row1, _col1, _row2, _col2)
      @autofilter_ref  = xl_range(_row1, _row2, _col1, _col2)
      @filter_range    = [_col1, _col2]

      # Store the filter cell positions for use in the autofit calculation.
      (_col1.._col2).each do |col|
        @filter_cells["#{_row1}:#{col}"] = 1
      end
    end

    #
    # Set the column filter criteria.
    #
    # The filter_column method can be used to filter columns in a autofilter
    # range based on simple conditions.
    #
    def filter_column(col, expression)
      raise "Must call autofilter before filter_column" unless @autofilter_area

      col = prepare_filter_column(col)

      tokens = extract_filter_tokens(expression)

      raise "Incorrect number of tokens in expression '#{expression}'" unless tokens.size == 3 || tokens.size == 7

      tokens = parse_filter_expression(expression, tokens)

      # Excel handles single or double custom filters as default filters. We need
      # to check for them and handle them accordingly.
      if tokens.size == 2 && tokens[0] == 2
        # Single equality.
        filter_column_list(col, tokens[1])
      elsif tokens.size == 5 && tokens[0] == 2 && tokens[2] == 1 && tokens[3] == 2
        # Double equality with "or" operator.
        filter_column_list(col, tokens[1], tokens[4])
      else
        # Non default custom filter.
        @filter_cols[col] = Array.new(tokens)
        @filter_type[col] = 0
      end

      @filter_on = 1
    end

    #
    # Set the column filter criteria in Excel 2007 list style.
    #
    def filter_column_list(col, *tokens)
      tokens.flatten!
      raise "Incorrect number of arguments to filter_column_list" if tokens.empty?
      raise "Must call autofilter before filter_column_list" unless @autofilter_area

      col = prepare_filter_column(col)

      @filter_cols[col] = tokens
      @filter_type[col] = 1           # Default style.
      @filter_on        = 1
    end

    #
    # Store the horizontal page breaks on a worksheet.
    #
    def set_h_pagebreaks(*args)
      breaks = args.collect do |brk|
        Array(brk)
      end.flatten
      @page_setup.hbreaks += breaks
    end

    #
    # Store the vertical page breaks on a worksheet.
    #
    def set_v_pagebreaks(*args)
      @page_setup.vbreaks += args
    end

    #
    # This method is used to make all cell comments visible when a worksheet
    # is opened.
    #
    def show_comments(visible = true)
      @comments_visible = visible
    end

    #
    # This method is used to set the default author of all cell comments.
    #
    def comments_author=(author)
      @comments_author = author || ''
    end

    # This method is deprecated. use comments_author=().
    def set_comments_author(author)
      put_deprecate_message("#{self}.set_comments_author")
      self.comments_author = author
    end

    def has_vml?  # :nodoc:
      @has_vml
    end

    def has_header_vml?  # :nodoc:
      !(@header_images.empty? && @footer_images.empty?)
    end

    def has_comments? # :nodoc:
      !@comments.empty?
    end

    def has_shapes?
      @has_shapes
    end

    def is_chartsheet? # :nodoc:
      !!@is_chartsheet
    end

    #
    # Set up chart/drawings.
    #
    def prepare_chart(index, chart_id, drawing_id) # :nodoc:
      drawing_type = 1

      inserted_chart = @charts[index]
      inserted_chart.chart.id = chart_id - 1

      dimensions = position_object_emus(inserted_chart)

      # Create a Drawing object to use with worksheet unless one already exists.
      drawing = Drawing.new(
        drawing_type, dimensions, 0, 0, nil, inserted_chart.anchor,
        drawing_rel_index, 0, nil, inserted_chart.name,
        inserted_chart.description, inserted_chart.decorative
      )
      if drawings?
        @drawings.add_drawing_object(drawing)
      else
        @drawings = Drawings.new
        @drawings.add_drawing_object(drawing)
        @drawings.embedded = true

        @external_drawing_links << ['/drawing', "../drawings/drawing#{drawing_id}.xml"]
      end
      @drawing_links << ['/chart', "../charts/chart#{chart_id}.xml"]
    end

    #
    # Returns a range of data from the worksheet _table to be used in chart
    # cached data. Strings are returned as SST ids and decoded in the workbook.
    # Return nils for data that doesn't exist since Excel can chart series
    # with data missing.
    #
    def get_range_data(row_start, col_start, row_end, col_end) # :nodoc:
      # TODO. Check for worksheet limits.

      # Iterate through the table data.
      data = []
      (row_start..row_end).each do |row_num|
        # Store nil if row doesn't exist.
        unless @cell_data_table[row_num]
          data << nil
          next
        end

        (col_start..col_end).each do |col_num|
          cell = @cell_data_table[row_num][col_num]
          if cell
            data << cell.data
          else
            data << nil
          end
        end
      end

      data
    end

    def comments_visible? # :nodoc:
      !!@comments_visible
    end

    def sorted_comments # :nodoc:
      @comments.sorted_comments
    end

    #
    # Write the cell value <v> element.
    #
    def write_cell_value(value = '') # :nodoc:
      return write_cell_formula('=NA()') if value.is_a?(Float) && value.nan?

      value ||= ''

      int_value = value.to_i
      value = int_value if value == int_value
      @writer.data_element('v', value)
    end

    #
    # Write the cell formula <f> element.
    #
    def write_cell_formula(formula = '') # :nodoc:
      @writer.data_element('f', formula)
    end

    #
    # Write the cell array formula <f> element.
    #
    def write_cell_array_formula(formula, range) # :nodoc:
      @writer.data_element(
        'f', formula,
        [
          %w[t array],
          ['ref', range]
        ]
      )
    end

    def date_1904? # :nodoc:
      @workbook.date_1904?
    end

    def excel2003_style? # :nodoc:
      @workbook.excel2003_style
    end

    #
    # Convert from an Excel internal colour index to a XML style #RRGGBB index
    # based on the default or user defined values in the Workbook palette.
    #
    def palette_color(index) # :nodoc:
      if index.to_s =~ /^#([0-9A-F]{6})$/i
        "FF#{::Regexp.last_match(1).upcase}"
      else
        "FF#{palette_color_from_index(index)}"
      end
    end

    def buttons_data  # :nodoc:
      @buttons_array
    end

    def header_images_data  # :nodoc:
      @header_images_array
    end

    def external_links
      [
        @external_hyper_links,
        @external_drawing_links,
        @external_vml_links,
        @external_background_links,
        @external_table_links,
        @external_comment_links
      ].reject { |a| a.empty? }
    end

    def drawing_links
      [@drawing_links]
    end

    #
    # Turn the HoH that stores the comments into an array for easier handling
    # and set the external links for comments and buttons.
    #
    def prepare_vml_objects(vml_data_id, vml_shape_id, vml_drawing_id, comment_id)
      set_external_vml_links(vml_drawing_id)
      set_external_comment_links(comment_id) if has_comments?

      # The VML o:idmap data id contains a comma separated range when there is
      # more than one 1024 block of comments, like this: data="1,2".
      data = "#{vml_data_id}"
      (1..num_comments_block).each do |i|
        data += ",#{vml_data_id + i}"
      end
      @vml_data_id = data
      @vml_shape_id = vml_shape_id
    end

    #
    # Setup external linkage for VML header/footer images.
    #
    def prepare_header_vml_objects(vml_header_id, vml_drawing_id)
      @vml_header_id = vml_header_id
      @external_vml_links << ['/vmlDrawing', "../drawings/vmlDrawing#{vml_drawing_id}.vml"]
    end

    #
    # Set the table ids for the worksheet tables.
    #
    def prepare_tables(table_id, seen)
      if tables_count > 0
        id = table_id
        tables.each do |table|
          table.prepare(id)

          if seen[table.name]
            raise "error: invalid duplicate table name '#{table.name}' found."
          else
            seen[table.name] = 1
          end

          # Store the link used for the rels file.
          @external_table_links << ['/table', "../tables/table#{id}.xml"]
          id += 1
        end
      end
      tables_count || 0
    end

    def num_comments_block
      @comments.size / 1024
    end

    def tables_count
      @tables.size
    end

    def horizontal_dpi=(val)
      @page_setup.horizontal_dpi = val
    end

    def vertical_dpi=(val)
      @page_setup.vertical_dpi = val
    end

    #
    # set the vba name for the worksheet
    #
    def set_vba_name(vba_codename = nil)
      @vba_codename = vba_codename || @name
    end

    #
    # Ignore worksheet errors/warnings in user defined ranges.
    #
    def ignore_errors(ignores)
      # List of valid input parameters.
      valid_parameter_keys = %i[
        number_stored_as_text
        eval_error
        formula_differs
        formula_range
        formula_unlocked
        empty_cell_reference
        list_data_validation
        calculated_column
        two_digit_text_year
      ]

      raise "Unknown parameter '#{ignores.key - valid_parameter_keys}' in ignore_errors()." unless (ignores.keys - valid_parameter_keys).empty?

      @ignore_errors = ignores
    end

    def write_ext(url, &block)
      attributes = [
        ['xmlns:x14', "#{OFFICE_URL}spreadsheetml/2009/9/main"],
        ['uri',       url]
      ]
      @writer.tag_elements('ext', attributes, &block)
    end

    def write_sparkline_groups
      # Write the x14:sparklineGroups element.
      @writer.tag_elements('x14:sparklineGroups', sparkline_groups_attributes) do
        # Write the sparkline elements.
        @sparklines.reverse.each do |sparkline|
          sparkline.write_sparkline_group(@writer)
        end
      end
    end

    def has_dynamic_functions?
      @has_dynamic_functions
    end

    def has_embedded_images?
      @has_embedded_images
    end

    # Check that some image or drawing needs to be processed.
    def some_image_or_drawing_to_be_processed?
      charts.size + images.size + shapes.size + header_images.size + footer_images.size + (background_image ? 1 : 0) == 0
    end

    def prepare_drawings(drawing_id, chart_ref_id, image_ref_id, image_ids, header_image_ids, background_ids)
      has_drawings = false

      # Check that some image or drawing needs to be processed.
      unless some_image_or_drawing_to_be_processed?

        # Don't increase the drawing_id header/footer images.
        unless charts.empty? && images.empty? && shapes.empty?
          drawing_id += 1
          has_drawings = true
        end

        # Prepare the background images.
        image_ref_id = prepare_background_image(background_ids, image_ref_id)

        # Prepare the worksheet images.
        images.each do |image|
          image_ref_id = prepare_image(image, drawing_id, image_ids, image_ref_id)
        end

        # Prepare the worksheet charts.
        charts.each_with_index do |_chart, index|
          chart_ref_id += 1
          prepare_chart(index, chart_ref_id, drawing_id)
        end

        # Prepare the worksheet shapes.
        shapes.each_with_index do |_shape, index|
          prepare_shape(index, drawing_id)
        end

        # Prepare the header and footer images.
        [header_images, footer_images].each do |images|
          images.each do |image|
            image_ref_id = prepare_header_footer_image(
              image, header_image_ids, image_ref_id
            )
          end
        end

        if has_drawings
          @workbook.drawings << drawings
        end
      end

      [drawing_id, chart_ref_id, image_ref_id]
    end

    #
    # Set the background image for the worksheet.
    #
    def set_background(image)
      raise "Couldn't locate #{image}: $!" unless File.exist?(image)

      @background_image = ImageProperty.new(image)
    end

    #
    # Calculate the vertices that define the position of a graphical object
    # within the worksheet in pixels.
    #
    def position_object_pixels(col_start, row_start, x1, y1, width, height, anchor = nil) # :nodoc:
      # Adjust start column for negative offsets.
      while x1 < 0 && col_start > 0
        x1 += size_col(col_start - 1)
        col_start -= 1
      end

      # Adjust start row for negative offsets.
      while y1 < 0 && row_start > 0
        y1 += size_row(row_start - 1)
        row_start -= 1
      end

      # Ensure that the image isn't shifted off the page at top left.
      x1 = 0 if x1 < 0
      y1 = 0 if y1 < 0

      # Calculate the absolute x offset of the top-left vertex.
      x_abs = if @col_size_changed
                (0..col_start - 1).inject(0) { |sum, col| sum += size_col(col, anchor) }
              else
                # Optimisation for when the column widths haven't changed.
                DEFAULT_COL_PIXELS * col_start
              end
      x_abs += x1

      # Calculate the absolute y offset of the top-left vertex.
      # Store the column change to allow optimisations.
      y_abs = if @row_size_changed
                (0..row_start - 1).inject(0) { |sum, row| sum += size_row(row, anchor) }
              else
                # Optimisation for when the row heights haven't changed.
                @default_row_pixels * row_start
              end
      y_abs += y1

      # Adjust start column for offsets that are greater than the col width.
      while x1 >= size_col(col_start, anchor)
        x1 -= size_col(col_start)
        col_start += 1
      end

      # Adjust start row for offsets that are greater than the row height.
      while y1 >= size_row(row_start, anchor)
        y1 -= size_row(row_start)
        row_start += 1
      end

      # Initialise end cell to the same as the start cell.
      col_end = col_start
      row_end = row_start

      # Only offset the image in the cell if the row/col isn't hidden.
      width  += x1 if size_col(col_start, anchor) > 0
      height += y1 if size_row(row_start, anchor) > 0

      # Subtract the underlying cell widths to find the end cell of the object.
      while width >= size_col(col_end, anchor)
        width -= size_col(col_end, anchor)
        col_end += 1
      end

      # Subtract the underlying cell heights to find the end cell of the object.
      while height >= size_row(row_end, anchor)
        height -= size_row(row_end, anchor)
        row_end += 1
      end

      # The end vertices are whatever is left from the width and height.
      x2 = width
      y2 = height

      [col_start, row_start, x1, y1, col_end, row_end, x2, y2, x_abs, y_abs]
    end

    private

    #
    # Convert the width of a cell from user's units to pixels. Excel rounds
    # the column width to the nearest pixel. If the width hasn't been set
    # by the user we use the default value. A hidden column is treated as
    # having a width of zero unless it has the special "object_position" of
    # 4 (size with cells).
    #
    def size_col(col, anchor = 0) # :nodoc:
      # Look up the cell value to see if it has been changed.
      if col_info[col]
        width  = col_info[col].width || @default_col_width
        hidden = col_info[col].hidden

        # Convert to pixels.
        pixels = if hidden == 1 && anchor != 4
                   0
                 elsif width < 1
                   ((width * (MAX_DIGIT_WIDTH + PADDING)) + 0.5).to_i
                 else
                   ((width * MAX_DIGIT_WIDTH) + 0.5).to_i + PADDING
                 end
      else
        pixels = DEFAULT_COL_PIXELS
      end
      pixels
    end

    #
    # Convert the height of a cell from user's units to pixels. If the height
    # hasn't been set by the user we use the default value. A hidden row is
    # treated as having a height of zero unless it has the special
    # "object_position" of 4 (size with cells).
    #
    def size_row(row, anchor = 0) # :nodoc:
      # Look up the cell value to see if it has been changed
      if row_sizes[row]
        height, hidden = row_sizes[row]

        pixels = if hidden == 1 && anchor != 4
                   0
                 else
                   (4 / 3.0 * height).to_i
                 end
      else
        pixels = (4 / 3.0 * default_row_height).to_i
      end
      pixels
    end

    #
    # Compare adjacent column information structures.
    #
    def compare_col_info(col_options, previous_options)
      if !col_options.width.nil? != !previous_options.width.nil?
        return nil
      end
      if col_options.width && previous_options.width &&
         col_options.width != previous_options.width
        return nil
      end

      if !col_options.format.nil? != !previous_options.format.nil?
        return nil
      end
      if col_options.format && previous_options.format &&
         col_options.format != previous_options.format
        return nil
      end

      return nil if col_options.hidden    != previous_options.hidden
      return nil if col_options.level     != previous_options.level
      return nil if col_options.collapsed != previous_options.collapsed

      true
    end

    def set_external_vml_links(vml_drawing_id) # :nodoc:
      @external_vml_links <<
        ['/vmlDrawing', "../drawings/vmlDrawing#{vml_drawing_id}.vml"]
    end

    def set_external_comment_links(comment_id) # :nodoc:
      @external_comment_links <<
        ['/comments',   "../comments#{comment_id}.xml"]
    end

    #
    # Get the index used to address a drawing rel link.
    #
    def drawing_rel_index(target = nil)
      if !target
        # Undefined values for drawings like charts will always be unique.
        @drawing_rels_id += 1
      elsif ptrue?(@drawing_rels[target])
        @drawing_rels[target]
      else
        @drawing_rels_id += 1
        @drawing_rels[target] = @drawing_rels_id
      end
    end

    #
    # Get the index used to address a vml_drawing rel link.
    #
    def get_vml_drawing_rel_index(target)
      if @vml_drawing_rels[target]
        @vml_drawing_rels[target]
      else
        @vml_drawing_rels_id += 1
        @vml_drawing_rels[target] = @vml_drawing_rels_id
      end
    end

    def hyperlinks_count
      @hyperlinks.keys.inject(0) { |s, n| s += @hyperlinks[n].keys.size }
    end

    def store_hyperlink(row, col, hyperlink)
      @hyperlinks      ||= {}
      @hyperlinks[row] ||= {}
      @hyperlinks[row][col] = hyperlink
    end

    def cell_format_of_rich_string(rich_strings)
      # If the last arg is a format we use it as the cell format.
      rich_strings.pop if rich_strings[-1].respond_to?(:xf_index)
    end

    #
    # Convert the list of format, string tokens to pairs of (format, string)
    # except for the first string fragment which doesn't require a default
    # formatting run. Use the default for strings without a leading format.
    #
    def rich_strings_fragments(rich_strings) # :nodoc:
      # Create a temp format with the default font for unformatted fragments.
      default = Format.new(0)

      last = 'format'
      pos  = 0
      raw_string = ''

      fragments = []
      rich_strings.each do |token|
        if token.respond_to?(:xf_index)
          # Can't allow 2 formats in a row
          return nil if last == 'format' && pos > 0

          # Token is a format object. Add it to the fragment list.
          fragments << token
          last = 'format'
        else
          # Token is a string.
          if last == 'format'
            # If previous token was a format just add the string.
            fragments << token
          else
            # If previous token wasn't a format add one before the string.
            fragments << default << token
          end

          raw_string += token    # Keep track of actual string length.
          last = 'string'
        end
        pos += 1
      end
      [fragments, raw_string]
    end

    def xml_str_of_rich_string(fragments)
      # Create a temp XML::Writer object and use it to write the rich string
      # XML to a string.
      writer = Package::XMLWriterSimple.new

      # If the first token is a string start the <r> element.
      writer.start_tag('r') unless fragments[0].respond_to?(:xf_index)

      # Write the XML elements for the format string fragments.
      fragments.each do |token|
        if token.respond_to?(:xf_index)
          # Write the font run.
          writer.start_tag('r')
          token.write_font_rpr(writer, self)
        else
          # Write the string fragment part, with whitespace handling.
          attributes = []

          attributes << ['xml:space', 'preserve'] if token =~ /^\s/ || token =~ /\s$/
          writer.data_element('t', token, attributes)
          writer.end_tag('r')
        end
      end
      writer.string
    end

    # Pad out the rest of the area with formatted blank cells.
    def write_formatted_blank_to_area(row_first, row_last, col_first, col_last, format)
      (row_first..row_last).each do |row|
        (col_first..col_last).each do |col|
          next if row == row_first && col == col_first

          write_blank(row, col, format)
        end
      end
    end

    #
    # Extract the tokens from the filter expression. The tokens are mainly non-
    # whitespace groups. The only tricky part is to extract string tokens that
    # contain whitespace and/or quoted double quotes (Excel's escaped quotes).
    #
    def extract_filter_tokens(expression = nil) # :nodoc:
      return [] unless expression

      tokens = []
      str = expression
      while str =~ /"(?:[^"]|"")*"|\S+/
        tokens << ::Regexp.last_match(0)
        str = $~.post_match
      end

      # Remove leading and trailing quotes and unescape other quotes
      tokens.map! do |token|
        token.sub!(/^"/, '')
        token.sub!(/"$/, '')
        token.gsub!('""', '"')

        # if token is number, convert to numeric.
        if token =~ /^([+-]?)(?=\d|\.\d)\d*(\.\d*)?([Ee]([+-]?\d+))?$/
          token.to_f == token.to_i ? token.to_i : token.to_f
        else
          token
        end
      end

      tokens
    end

    #
    # Converts the tokens of a possibly conditional expression into 1 or 2
    # sub expressions for further parsing.
    #
    def parse_filter_expression(expression, tokens) # :nodoc:
      # The number of tokens will be either 3 (for 1 expression)
      # or 7 (for 2  expressions).
      #
      if tokens.size == 7
        conditional = tokens[3]
        if conditional =~ /^(and|&&)$/
          conditional = 0
        elsif conditional =~ /^(or|\|\|)$/
          conditional = 1
        else
          raise "Token '#{conditional}' is not a valid conditional " +
                "in filter expression '#{expression}'"
        end
        expression_1 = parse_filter_tokens(expression, tokens[0..2])
        expression_2 = parse_filter_tokens(expression, tokens[4..6])
        [expression_1, conditional, expression_2].flatten
      else
        parse_filter_tokens(expression, tokens)
      end
    end

    #
    # Parse the 3 tokens of a filter expression and return the operator and token.
    #
    def parse_filter_tokens(expression, tokens)     # :nodoc:
      operators = {
        '==' => 2,
        '='  => 2,
        '=~' => 2,
        'eq' => 2,

        '!=' => 5,
        '!~' => 5,
        'ne' => 5,
        '<>' => 5,

        '<'  => 1,
        '<=' => 3,
        '>'  => 4,
        '>=' => 6
      }

      operator = operators[tokens[1]]
      token    = tokens[2]

      # Special handling of "Top" filter expressions.
      if tokens[0] =~ /^top|bottom$/i
        value = tokens[1]
        if value.to_s =~ /\D/ or value.to_i < 1 or value.to_i > 500
          raise "The value '#{value}' in expression '#{expression}' " +
                "must be in the range 1 to 500"
        end
        token.downcase!
        if token != 'items' and token != '%'
          raise "The type '#{token}' in expression '#{expression}' " +
                "must be either 'items' or '%'"
        end

        operator = if tokens[0] =~ /^top$/i
                     30
                   else
                     32
                   end

        operator += 1 if tokens[2] == '%'

        token    = value
      end

      if !operator and tokens[0]
        raise "Token '#{tokens[1]}' is not a valid operator " +
              "in filter expression '#{expression}'"
      end

      # Special handling for Blanks/NonBlanks.
      if token.to_s =~ /^blanks|nonblanks$/i
        # Only allow Equals or NotEqual in this context.
        if operator != 2 and operator != 5
          raise "The operator '#{tokens[1]}' in expression '#{expression}' " +
                "is not valid in relation to Blanks/NonBlanks'"
        end

        token.downcase!

        # The operator should always be 2 (=) to flag a "simple" equality in
        # the binary record. Therefore we convert <> to =.
        if token == 'blanks'
          token = ' ' if operator == 5
        elsif operator == 5
          operator = 2
          token    = 'blanks'
        else
          operator = 5
          token    = ' '
        end
      end

      # if the string token contains an Excel match character then change the
      # operator type to indicate a non "simple" equality.
      operator = 22 if operator == 2 and token.to_s =~ /[*?]/

      [operator, token]
    end

    #
    # This is an internal method that is used to filter elements of the array of
    # pagebreaks used in the _store_hbreak() and _store_vbreak() methods. It:
    #   1. Removes duplicate entries from the list.
    #   2. Sorts the list.
    #   3. Removes 0 from the list if present.
    #
    def sort_pagebreaks(*args) # :nodoc:
      return [] if args.empty?

      breaks = args.uniq.sort
      breaks.delete(0)

      # The Excel 2007 specification says that the maximum number of page breaks
      # is 1026. However, in practice it is actually 1023.
      max_num_breaks = 1023
      if breaks.size > max_num_breaks
        breaks[0, max_num_breaks]
      else
        breaks
      end
    end

    #
    # Calculate the vertices that define the position of a graphical object
    # within the worksheet in EMUs.
    #
    def position_object_emus(graphical_object) # :nodoc:
      go = graphical_object
      col_start, row_start, x1, y1, col_end, row_end, x2, y2, x_abs, y_abs =
        position_object_pixels(go.col, go.row, go.x_offset, go.y_offset, go.scaled_width, go.scaled_height, go.anchor)

      # Convert the pixel values to EMUs. See above.
      x1    = (0.5 + (9_525 * x1)).to_i
      y1    = (0.5 + (9_525 * y1)).to_i
      x2    = (0.5 + (9_525 * x2)).to_i
      y2    = (0.5 + (9_525 * y2)).to_i
      x_abs = (0.5 + (9_525 * x_abs)).to_i
      y_abs = (0.5 + (9_525 * y_abs)).to_i

      [col_start, row_start, x1, y1, col_end, row_end, x2, y2, x_abs, y_abs]
    end

    #
    # Convert the width of a cell from pixels to character units.
    #
    def pixels_to_width(pixels)
      max_digit_width = 7.0
      padding         = 5.0

      if pixels <= 12
        pixels / (max_digit_width + padding)
      else
        (pixels - padding) / max_digit_width
      end
    end

    #
    # Convert the height of a cell from pixels to character units.
    #
    def pixels_to_height(pixels)
      height = 0.75 * pixels
      height = height.to_i if (height - height.to_i).abs < 0.1
      height
    end

    #
    # Set up image/drawings.
    #
    def prepare_image(image, drawing_id, image_ids, image_ref_id) # :nodoc:
      image_type = image.type
      x_dpi  = image.x_dpi || 96
      y_dpi  = image.y_dpi || 96
      md5    = image.md5
      drawing_type = 2

      @workbook.store_image_types(image_type)

      if image_ids[md5]
        image_id = image_ids[md5]
      else
        image_ref_id += 1
        image_ids[md5] = image_id = image_ref_id
        @workbook.images << image
      end

      dimensions = position_object_emus(image)

      # Create a Drawing object to use with worksheet unless one already exists.
      drawing = Drawing.new(
        drawing_type, dimensions, image.width_emus, image.height_emus,
        nil, image.anchor, 0, 0, image.tip, image.name,
        image.description || image.name, image.decorative
      )
      unless drawings?
        @drawings = Drawings.new
        @drawings.embedded = true

        @external_drawing_links << ['/drawing', "../drawings/drawing#{drawing_id}.xml"]
      end
      @drawings.add_drawing_object(drawing)

      if image.url
        target_mode = 'External'
        target = escape_url(image.url) if image.url =~ %r{^[fh]tt?ps?://} || image.url =~ /^mailto:/
        if image.url =~ /^external:/
          target = escape_url(image.url.sub(/^external:/, ''))

          # Additional escape not required in worksheet hyperlinks
          target = target.gsub("#", '%23')

          # Prefix absolute paths (not relative) with file:///
          target = if target =~ /^\w:/ || target =~ /^\\\\/
                     "file:///#{target}"
                   else
                     target.gsub("\\", '/')
                   end
        end

        if image.url =~ /^internal:/
          target      = image.url.sub(/^internal:/, '#')
          target_mode = nil
        end

        if target.length > 255
          raise <<"EOS"
Ignoring URL #{target} where link or anchor > 255 characters since it exceeds Excel's limit for URLS. See LIMITATIONS section of the WriteXLSX documentation.
EOS
        end

        @drawing_links << ['/hyperlink', target, target_mode] if target && !@drawing_rels[image.url]
        drawing.url_rel_index = drawing_rel_index(image.url)
      end

      @drawing_links << ['/image', "../media/image#{image_id}.#{image_type}"] unless @drawing_rels[md5]

      drawing.rel_index = drawing_rel_index(md5)

      image_ref_id
    end

    def prepare_header_image(image_id, image_property)
      # Strip the extension from the filename.
      body = image_property.name.dup
      body[/\.[^.]+$/, 0] = ''
      image_property.body = body

      @vml_drawing_links << ['/image', "../media/image#{image_id}.#{image_property.type}"] unless @vml_drawing_rels[image_property.md5]

      image_property.ref_id = get_vml_drawing_rel_index(image_property.md5)
      @header_images_array << image_property
    end

    #
    # Set up an image without a drawing object for the background image.
    #
    def prepare_background(image_id, image_type)
      @external_background_links <<
        ['/image', "../media/image#{image_id}.#{image_type}"]
    end

    def prepare_background_image(background_ids, image_ref_id)
      unless background_image.nil?
        @workbook.store_image_types(background_image.type)

        if background_ids[background_image.md5]
          ref_id = background_ids[background_image.md5]
        else
          image_ref_id += 1
          ref_id = image_ref_id
          background_ids[background_image.md5] = ref_id
          @workbook.images << background_image
        end

        prepare_background(ref_id, background_image.type)
      end

      image_ref_id
    end

    #
    # Set up drawing shapes
    #
    def prepare_shape(index, drawing_id)
      shape = @shapes[index]

      # Create a Drawing object to use with worksheet unless one already exists.
      unless drawings?
        @drawings = Drawings.new
        @drawings.embedded = true
        @external_drawing_links << ['/drawing', "../drawings/drawing#{drawing_id}.xml"]
        @has_shapes = true
      end

      # Validate the he shape against various rules.
      shape.validate(index)
      shape.calc_position_emus(self)

      drawing_type = 3
      drawing = Drawing.new(
        drawing_type, shape.dimensions, shape.width_emu, shape.height_emu,
        shape, shape.anchor, drawing_rel_index, 0, shape.name, nil, 0
      )
      drawings.add_drawing_object(drawing)
    end

    #
    # Hash a worksheet password. Based on the algorithm in ECMA-376-4:2016,
    # Office Open XML File Foemats -- Transitional Migration Features,
    # Additional attributes for workbookProtection element (Part 1, §18.2.29).   #
    def encode_password(password) # :nodoc:
      hash = 0

      password.reverse.split("").each do |char|
        hash = ((hash >> 14) & 0x01) | ((hash << 1) & 0x7fff)
        hash ^= char.ord
      end

      hash = ((hash >> 14) & 0x01) | ((hash << 1) & 0x7fff)
      hash ^= password.length
      hash ^= 0xCE4B

      sprintf("%X", hash)
    end

    #
    # Write the <worksheet> element. This is the root element of Worksheet.
    #
    def write_worksheet_attributes # :nodoc:
      schema = 'http://schemas.openxmlformats.org/'
      attributes = [
        ['xmlns',    "#{schema}spreadsheetml/2006/main"],
        ['xmlns:r',  "#{schema}officeDocument/2006/relationships"]
      ]

      if @excel_version == 2010
        attributes << ['xmlns:mc',     "#{schema}markup-compatibility/2006"]
        attributes << ['xmlns:x14ac',  "#{OFFICE_URL}spreadsheetml/2009/9/ac"]
        attributes << ['mc:Ignorable', 'x14ac']
      end
      attributes
    end

    #
    # Write the <sheetPr> element for Sheet level properties.
    #
    def write_sheet_pr # :nodoc:
      return unless tab_outline_fit? || vba_codename? || filter_on?

      attributes = []
      attributes << ['codeName',   @vba_codename] if vba_codename?
      attributes << ['filterMode', 1]             if filter_on?

      if tab_outline_fit?
        @writer.tag_elements('sheetPr', attributes) do
          write_tab_color
          write_outline_pr
          write_page_set_up_pr
        end
      else
        @writer.empty_tag('sheetPr', attributes)
      end
    end

    def tab_outline_fit?
      tab_color? || outline_changed? || fit_page?
    end

    #
    # Write the <pageSetUpPr> element.
    #
    def write_page_set_up_pr # :nodoc:
      @writer.empty_tag('pageSetUpPr', [['fitToPage', 1]]) if fit_page?
    end

    # Write the <dimension> element. This specifies the range of cells in the
    # worksheet. As a special case, empty spreadsheets use 'A1' as a range.
    #
    def write_dimension # :nodoc:
      if !@dim_rowmin && !@dim_colmin
        # If the min dims are undefined then no dimensions have been set
        # and we use the default 'A1'.
        ref = 'A1'
      elsif !@dim_rowmin && @dim_colmin
        # If the row dims aren't set but the column dims are then they
        # have been changed via set_column().
        if @dim_colmin == @dim_colmax
          # The dimensions are a single cell and not a range.
          ref = xl_rowcol_to_cell(0, @dim_colmin)
        else
          # The dimensions are a cell range.
          cell_1 = xl_rowcol_to_cell(0, @dim_colmin)
          cell_2 = xl_rowcol_to_cell(0, @dim_colmax)
          ref = cell_1 + ':' + cell_2
        end
      elsif @dim_rowmin == @dim_rowmax && @dim_colmin == @dim_colmax
        # The dimensions are a single cell and not a range.
        ref = xl_rowcol_to_cell(@dim_rowmin, @dim_colmin)
      else
        # The dimensions are a cell range.
        cell_1 = xl_rowcol_to_cell(@dim_rowmin, @dim_colmin)
        cell_2 = xl_rowcol_to_cell(@dim_rowmax, @dim_colmax)
        ref = cell_1 + ':' + cell_2
      end
      @writer.empty_tag('dimension', [['ref', ref]])
    end

    #
    # Write the <sheetViews> element.
    #
    def write_sheet_views # :nodoc:
      @writer.tag_elements('sheetViews', []) { write_sheet_view }
    end

    def write_sheet_view # :nodoc:
      attributes = []
      # Hide screen gridlines if required.
      attributes << ['showGridLines', 0] unless @screen_gridlines

      # Hide the row/column headers.
      attributes << ['showRowColHeaders', 0] if ptrue?(@hide_row_col_headers)

      # Hide zeroes in cells.
      attributes << ['showZeros', 0] unless show_zeros?

      # Display worksheet right to left for Hebrew, Arabic and others.
      attributes << ['rightToLeft', 1] if @right_to_left

      # Show that the sheet tab is selected.
      attributes << ['tabSelected', 1] if @selected

      # Turn outlines off. Also required in the outlinePr element.
      attributes << ["showOutlineSymbols", 0] if @outline_on

      # Set the page view/layout mode if required.
      case @page_view
      when 1
        attributes << %w[view pageLayout]
      when 2
        attributes << %w[view pageBreakPreview]
      end

      # Set the first visible cell.
      attributes << ['topLeftCell', @top_left_cell] if ptrue?(@top_left_cell)

      # Set the zoom level.
      if @zoom != 100
        attributes << ['zoomScale', @zoom]

        if @page_view == 1
          attributes << ['zoomScalePageLayoutView', @zoom]
        elsif @page_view == 2
          attributes << ['zoomScaleSheetLayoutView', @zoom]
        elsif ptrue?(@zoom_scale_normal)
          attributes << ['zoomScaleNormal', @zoom]
        end
      end

      attributes << ['workbookViewId', 0]

      if @panes.empty? && @selections.empty?
        @writer.empty_tag('sheetView', attributes)
      else
        @writer.tag_elements('sheetView', attributes) do
          write_panes
          write_selections
        end
      end
    end

    #
    # Write the <selection> elements.
    #
    def write_selections # :nodoc:
      @selections.each { |selection| write_selection(*selection) }
    end

    #
    # Write the <selection> element.
    #
    def write_selection(pane, active_cell, sqref) # :nodoc:
      attributes  = []
      attributes << ['pane', pane]              if pane
      attributes << ['activeCell', active_cell] if active_cell
      attributes << ['sqref', sqref]            if sqref

      @writer.empty_tag('selection', attributes)
    end

    #
    # Write the <sheetFormatPr> element.
    #
    def write_sheet_format_pr # :nodoc:
      attributes = [
        ['defaultRowHeight', @default_row_height]
      ]
      attributes << ['customHeight', 1] if @default_row_height != @original_row_height

      attributes << ['zeroHeight', 1] if ptrue?(@default_row_zeroed)

      attributes << ['outlineLevelRow', @outline_row_level] if @outline_row_level > 0
      attributes << ['outlineLevelCol', @outline_col_level] if @outline_col_level > 0
      attributes << ['x14ac:dyDescent', '0.25'] if @excel_version == 2010
      @writer.empty_tag('sheetFormatPr', attributes)
    end

    #
    # Write the <cols> element and <col> sub elements.
    #
    def write_cols # :nodoc:
      # Exit unless some column have been formatted.
      return if @col_info.empty?

      @writer.tag_elements('cols') do
        # Use the first element of the column informatin structure to set
        # the initial/previous properties.
        first_col           = @col_info.keys.min
        last_col            = first_col
        previous_options    = @col_info[first_col]
        deleted_col         = first_col
        deleted_col_options = previous_options

        @col_info.delete(first_col)

        @col_info.keys.sort.each do |col|
          col_options = @col_info[col]

          # Check if the column number is contiguous with the previous
          # column and if the properties are the same.
          if (col == last_col + 1) &&
             compare_col_info(col_options, previous_options)
            last_col = col
          else
            # If not contiguous/equal then we write out the current range
            # of columns and start again.
            write_col_info([first_col, last_col, previous_options])
            first_col = col
            last_col  = first_col
            previous_options = col_options
          end
        end

        # We will exit the previous loop with one unhandled column range.
        write_col_info([first_col, last_col, previous_options])

        # Put back the deleted first column information structure:
        @col_info[deleted_col] = deleted_col_options
      end
    end

    #
    # Write the <col> element.
    #
    def write_col_info(args) # :nodoc:
      @writer.empty_tag('col', col_info_attributes(args))
    end

    def col_info_attributes(args)
      min       = args[0]           || 0 # First formatted column.
      max       = args[1]           || 0 # Last formatted column.
      width     = args[2].width          # Col width in user units.
      format    = args[2].format         # Format index.
      hidden    = args[2].hidden    || 0 # Hidden flag.
      level     = args[2].level     || 0 # Outline level.
      collapsed = args[2].collapsed || 0 # Outline Collapsed
      autofit   = args[2].autofit   || 0 # Best fit for autofit numbers.
      xf_index = format ? format.get_xf_index : 0

      custom_width = true
      custom_width = false if width.nil? && hidden == 0
      custom_width = false if width == 8.43

      width ||= hidden == 0 ? @default_col_width : 0

      # Convert column width from user units to character width.
      width = if width && width < 1
                (((width * (MAX_DIGIT_WIDTH + PADDING)) + 0.5).to_i / MAX_DIGIT_WIDTH.to_f * 256).to_i / 256.0
              else
                ((((width * MAX_DIGIT_WIDTH) + 0.5).to_i + PADDING).to_i / MAX_DIGIT_WIDTH.to_f * 256).to_i / 256.0
              end
      width = width.to_i if width - width.to_i == 0

      attributes = [
        ['min',   min + 1],
        ['max',   max + 1],
        ['width', width]
      ]

      attributes << ['style',        xf_index] if xf_index  != 0
      attributes << ['hidden',       1]        if hidden    != 0
      attributes << ['bestFit',      1]        if autofit   != 0
      attributes << ['customWidth',  1]        if custom_width
      attributes << ['outlineLevel', level]    if level     != 0
      attributes << ['collapsed',    1]        if collapsed != 0
      attributes
    end

    #
    # Write the <sheetData> element.
    #
    def write_sheet_data # :nodoc:
      if @dim_rowmin
        @writer.tag_elements('sheetData') { write_rows }
      else
        # If the dimensions aren't defined then there is no data to write.
        @writer.empty_tag('sheetData')
      end
    end

    #
    # Write out the worksheet data as a series of rows and cells.
    #
    def write_rows # :nodoc:
      calculate_spans

      (@dim_rowmin..@dim_rowmax).each do |row_num|
        # Skip row if it doesn't contain row formatting or cell data.
        next if not_contain_formatting_or_data?(row_num)

        span_index = row_num / 16
        span       = @row_spans[span_index]

        # Write the cells if the row contains data.
        if @cell_data_table[row_num]
          args = @set_rows[row_num] || []
          write_row_element(row_num, span, *args) do
            write_cell_column_dimension(row_num)
          end
        else
          # Row attributes only.
          write_empty_row(row_num, span, *(@set_rows[row_num]))
        end
      end
    end

    def not_contain_formatting_or_data?(row_num) # :nodoc:
      !@set_rows[row_num] && !@cell_data_table[row_num] && !@comments.has_comment_in_row?(row_num)
    end

    def write_cell_column_dimension(row_num)  # :nodoc:
      row = @cell_data_table[row_num]
      row_name = (row_num + 1).to_s
      (@dim_colmin..@dim_colmax).each do |col_num|
        if (cell = row[col_num])
          cell.write_cell(self, row_num, row_name, col_num)
        end
      end
    end

    #
    # Write the <row> element.
    #
    def write_row_element(*args, &block)  # :nodoc:
      @writer.tag_elements('row', row_attributes(args), &block)
    end

    #
    # Write and empty <row> element, i.e., attributes only, no cell data.
    #
    def write_empty_row(*args) # :nodoc:
      @writer.empty_tag('row', row_attributes(args))
    end

    def row_attributes(args)
      r, spans, height, format, hidden, level, collapsed, _empty_row = args
      height    ||= @default_row_height
      hidden    ||= 0
      level     ||= 0
      xf_index = format ? format.get_xf_index : 0

      attributes = [['r',  r + 1]]

      attributes << ['spans',        spans]    if spans
      attributes << ['s',            xf_index] if ptrue?(xf_index)
      attributes << ['customFormat', 1]        if ptrue?(format)
      attributes << ['ht',           height]   if height != @original_row_height
      attributes << ['hidden',       1]        if ptrue?(hidden)
      attributes << ['customHeight', 1]        if height != @original_row_height
      attributes << ['outlineLevel', level]    if ptrue?(level)
      attributes << ['collapsed',    1]        if ptrue?(collapsed)

      attributes << ['x14ac:dyDescent', '0.25'] if @excel_version == 2010
      attributes
    end

    #
    # Write the frozen or split <pane> elements.
    #
    def write_panes # :nodoc:
      return if @panes.empty?

      if @panes[4] == 2
        write_split_panes
      else
        write_freeze_panes(*@panes)
      end
    end

    #
    # Write the <pane> element for freeze panes.
    #
    def write_freeze_panes(row, col, top_row, left_col, type) # :nodoc:
      y_split       = row
      x_split       = col
      top_left_cell = xl_rowcol_to_cell(top_row, left_col)

      # Move user cell selection to the panes.
      unless @selections.empty?
        _dummy, active_cell, sqref = @selections[0]
        @selections = []
      end

      active_cell ||= nil
      sqref       ||= nil
      active_pane = set_active_pane_and_cell_selections(row, col, row, col, active_cell, sqref)

      # Set the pane type.
      state = if type == 0
                'frozen'
              elsif type == 1
                'frozenSplit'
              else
                'split'
              end

      attributes = []
      attributes << ['xSplit',      x_split] if x_split > 0
      attributes << ['ySplit',      y_split] if y_split > 0
      attributes << ['topLeftCell', top_left_cell]
      attributes << ['activePane',  active_pane]
      attributes << ['state',       state]

      @writer.empty_tag('pane', attributes)
    end

    #
    # Write the <pane> element for split panes.
    #
    # See also, implementers note for split_panes().
    #
    def write_split_panes # :nodoc:
      row, col, top_row, left_col = @panes
      has_selection = false
      y_split = row
      x_split = col

      # Move user cell selection to the panes.
      unless @selections.empty?
        _dummy, active_cell, sqref = @selections[0]
        @selections = []
        has_selection = true
      end

      # Convert the row and col to 1/20 twip units with padding.
      y_split = ((20 * y_split) + 300).to_i if y_split > 0
      x_split = calculate_x_split_width(x_split) if x_split > 0

      # For non-explicit topLeft definitions, estimate the cell offset based
      # on the pixels dimensions. This is only a workaround and doesn't take
      # adjusted cell dimensions into account.
      if top_row == row && left_col == col
        top_row  = (0.5 + ((y_split - 300) / 20 / 15)).to_i
        left_col = (0.5 + ((x_split - 390) / 20 / 3 * 4 / 64)).to_i
      end

      top_left_cell = xl_rowcol_to_cell(top_row, left_col)

      # If there is no selection set the active cell to the top left cell.
      unless has_selection
        active_cell = top_left_cell
        sqref       = top_left_cell
      end
      active_pane = set_active_pane_and_cell_selections(
        row, col, top_row, left_col, active_cell, sqref
      )

      attributes = []
      attributes << ['xSplit', x_split] if x_split > 0
      attributes << ['ySplit', y_split] if y_split > 0
      attributes << ['topLeftCell', top_left_cell]
      attributes << ['activePane', active_pane] if has_selection

      @writer.empty_tag('pane', attributes)
    end

    #
    # Convert column width from user units to pane split width.
    #
    def calculate_x_split_width(width) # :nodoc:
      # Convert to pixels.
      pixels = if width < 1
                 int((width * 12) + 0.5)
               else
                 ((width * MAX_DIGIT_WIDTH) + 0.5).to_i + PADDING
               end

      # Convert to points.
      points = pixels * 3 / 4

      # Convert to twips (twentieths of a point).
      twips = points * 20

      # Add offset/padding.
      twips + 390
    end

    #
    # Write the <sheetCalcPr> element for the worksheet calculation properties.
    #
    def write_sheet_calc_pr # :nodoc:
      @writer.empty_tag('sheetCalcPr', [['fullCalcOnLoad', 1]])
    end

    #
    # Write the <phoneticPr> element.
    #
    def write_phonetic_pr # :nodoc:
      attributes = [
        ['fontId', 0],
        %w[type noConversion]
      ]

      @writer.empty_tag('phoneticPr', attributes)
    end

    #
    # Write the <pageMargins> element.
    #
    def write_page_margins # :nodoc:
      @page_setup.write_page_margins(@writer)
    end

    #
    # Write the <pageSetup> element.
    #
    def write_page_setup # :nodoc:
      @page_setup.write_page_setup(@writer)
    end

    #
    # Write the <mergeCells> element.
    #
    def write_merge_cells # :nodoc:
      write_some_elements('mergeCells', @merge) do
        @merge.each { |merged_range| write_merge_cell(merged_range) }
      end
    end

    def write_some_elements(tag, container, &block)
      return if container.empty?

      @writer.tag_elements(tag, [['count', container.size]], &block)
    end

    #
    # Write the <mergeCell> element.
    #
    def write_merge_cell(merged_range) # :nodoc:
      row_min, col_min, row_max, col_max = merged_range

      # Convert the merge dimensions to a cell range.
      cell_1 = xl_rowcol_to_cell(row_min, col_min)
      cell_2 = xl_rowcol_to_cell(row_max, col_max)

      @writer.empty_tag('mergeCell', [['ref', "#{cell_1}:#{cell_2}"]])
    end

    #
    # Write the <printOptions> element.
    #
    def write_print_options # :nodoc:
      @page_setup.write_print_options(@writer)
    end

    #
    # Write the <headerFooter> element.
    #
    def write_header_footer # :nodoc:
      @page_setup.write_header_footer(@writer, excel2003_style?)
    end

    #
    # Write the <rowBreaks> element.
    #
    def write_row_breaks # :nodoc:
      write_breaks('rowBreaks')
    end

    #
    # Write the <colBreaks> element.
    #
    def write_col_breaks # :nodoc:
      write_breaks('colBreaks')
    end

    def write_breaks(tag) # :nodoc:
      case tag
      when 'rowBreaks'
        page_breaks = sort_pagebreaks(*@page_setup.hbreaks)
        max = 16383
      when 'colBreaks'
        page_breaks = sort_pagebreaks(*@page_setup.vbreaks)
        max = 1048575
      else
        raise "Invalid parameter '#{tag}' in write_breaks."
      end
      count = page_breaks.size

      return if page_breaks.empty?

      attributes = [
        ['count', count],
        ['manualBreakCount', count]
      ]

      @writer.tag_elements(tag, attributes) do
        page_breaks.each { |num| write_brk(num, max) }
      end
    end

    #
    # Write the <brk> element.
    #
    def write_brk(id, max) # :nodoc:
      attributes = [
        ['id',  id],
        ['max', max],
        ['man', 1]
      ]

      @writer.empty_tag('brk', attributes)
    end

    #
    # Write the <autoFilter> element.
    #
    def write_auto_filter # :nodoc:
      return unless autofilter_ref?

      attributes = [
        ['ref', @autofilter_ref]
      ]

      if filter_on?
        # Autofilter defined active filters.
        @writer.tag_elements('autoFilter', attributes) do
          write_autofilters
        end
      else
        # Autofilter defined without active filters.
        @writer.empty_tag('autoFilter', attributes)
      end
    end

    #
    # Function to iterate through the columns that form part of an autofilter
    # range and write the appropriate filters.
    #
    def write_autofilters # :nodoc:
      col1, col2 = @filter_range

      (col1..col2).each do |col|
        # Skip if column doesn't have an active filter.
        next unless @filter_cols[col]

        # Retrieve the filter tokens and write the autofilter records.
        tokens = @filter_cols[col]
        type   = @filter_type[col]

        # Filters are relative to first column in the autofilter.
        write_filter_column(col - col1, type, *tokens)
      end
    end

    #
    # Write the <filterColumn> element.
    #
    def write_filter_column(col_id, type, *filters) # :nodoc:
      @writer.tag_elements('filterColumn', [['colId', col_id]]) do
        if type == 1
          # Type == 1 is the new XLSX style filter.
          write_filters(*filters)
        else
          # Type == 0 is the classic "custom" filter.
          write_custom_filters(*filters)
        end
      end
    end

    #
    # Write the <filters> element.
    #
    def write_filters(*filters) # :nodoc:
      non_blanks = filters.reject { |filter| filter.to_s =~ /^blanks$/i }
      attributes = []

      attributes = [['blank', 1]] if filters != non_blanks

      if filters.size == 1 && non_blanks.empty?
        # Special case for blank cells only.
        @writer.empty_tag('filters', attributes)
      else
        # General case.
        @writer.tag_elements('filters', attributes) do
          non_blanks.sort.each { |filter| write_filter(filter) }
        end
      end
    end

    #
    # Write the <filter> element.
    #
    def write_filter(val) # :nodoc:
      @writer.empty_tag('filter', [['val', val]])
    end

    #
    # Write the <customFilters> element.
    #
    def write_custom_filters(*tokens) # :nodoc:
      if tokens.size == 2
        # One filter expression only.
        @writer.tag_elements('customFilters') { write_custom_filter(*tokens) }
      else
        # Two filter expressions.

        # Check if the "join" operand is "and" or "or".
        attributes = if tokens[2] == 0
                       [['and', 1]]
                     else
                       [['and', 0]]
                     end

        # Write the two custom filters.
        @writer.tag_elements('customFilters', attributes) do
          write_custom_filter(tokens[0], tokens[1])
          write_custom_filter(tokens[3], tokens[4])
        end
      end
    end

    #
    # Write the <customFilter> element.
    #
    def write_custom_filter(operator, val) # :nodoc:
      operators = {
        1  => 'lessThan',
        2  => 'equal',
        3  => 'lessThanOrEqual',
        4  => 'greaterThan',
        5  => 'notEqual',
        6  => 'greaterThanOrEqual',
        22 => 'equal'
      }

      # Convert the operator from a number to a descriptive string.
      if operators[operator]
        operator = operators[operator]
      else
        raise "Unknown operator = #{operator}\n"
      end

      # The 'equal' operator is the default attribute and isn't stored.
      attributes = []
      attributes << ['operator', operator] unless operator == 'equal'
      attributes << ['val', val]

      @writer.empty_tag('customFilter', attributes)
    end

    #
    # Process any sored hyperlinks in row/col order and write the <hyperlinks>
    # element. The attributes are different for internal and external links.
    #
    def write_hyperlinks # :nodoc:
      return unless @hyperlinks

      hlink_attributes = []
      @hyperlinks.keys.sort.each do |row_num|
        # Sort the hyperlinks into column order.
        col_nums = @hyperlinks[row_num].keys.sort
        # Iterate over the columns.
        col_nums.each do |col_num|
          # Get the link data for this cell.
          link = @hyperlinks[row_num][col_num]

          # If the cell isn't a string then we have to add the url as
          # the string to display
          if ptrue?(@cell_data_table)                   &&
             ptrue?(@cell_data_table[row_num])          &&
             ptrue?(@cell_data_table[row_num][col_num]) &&
             @cell_data_table[row_num][col_num].display_url_string?
            link.display_on
          end

          if link.respond_to?(:external_hyper_link)
            # External link with rel file relationship.
            @rel_count += 1
            # Links for use by the packager.
            @external_hyper_links << link.external_hyper_link
          end
          hlink_attributes << link.attributes(row_num, col_num, @rel_count)
        end
      end

      return if hlink_attributes.empty?

      # Write the hyperlink elements.
      @writer.tag_elements('hyperlinks') do
        hlink_attributes.each do |attributes|
          @writer.empty_tag('hyperlink', attributes)
        end
      end
    end

    #
    # Write the <tabColor> element.
    #
    def write_tab_color # :nodoc:
      return unless tab_color?

      @writer.empty_tag(
        'tabColor',
        [
          ['rgb', palette_color(@tab_color)]
        ]
      )
    end

    #
    # Write the <outlinePr> element.
    #
    def write_outline_pr
      return unless outline_changed?

      attributes = []
      attributes << ["applyStyles",  1] if @outline_style
      attributes << ["summaryBelow", 0] if @outline_below == 0
      attributes << ["summaryRight", 0] if @outline_right == 0
      attributes << ["showOutlineSymbols", 0] if @outline_on == 0

      @writer.empty_tag('outlinePr', attributes)
    end

    #
    # Write the <sheetProtection> element.
    #
    def write_sheet_protection # :nodoc:
      return unless protect?

      attributes = []
      attributes << ["password",         @protect[:password]] if ptrue?(@protect[:password])
      attributes << ["sheet",            1] if ptrue?(@protect[:sheet])
      attributes << ["content",          1] if ptrue?(@protect[:content])
      attributes << ["objects",          1] unless ptrue?(@protect[:objects])
      attributes << ["scenarios",        1] unless ptrue?(@protect[:scenarios])
      attributes << ["formatCells",      0] if ptrue?(@protect[:format_cells])
      attributes << ["formatColumns",    0] if ptrue?(@protect[:format_columns])
      attributes << ["formatRows",       0] if ptrue?(@protect[:format_rows])
      attributes << ["insertColumns",    0] if ptrue?(@protect[:insert_columns])
      attributes << ["insertRows",       0] if ptrue?(@protect[:insert_rows])
      attributes << ["insertHyperlinks", 0] if ptrue?(@protect[:insert_hyperlinks])
      attributes << ["deleteColumns",    0] if ptrue?(@protect[:delete_columns])
      attributes << ["deleteRows",       0] if ptrue?(@protect[:delete_rows])

      attributes << ["selectLockedCells", 1] unless ptrue?(@protect[:select_locked_cells])

      attributes << ["sort",        0] if ptrue?(@protect[:sort])
      attributes << ["autoFilter",  0] if ptrue?(@protect[:autofilter])
      attributes << ["pivotTables", 0] if ptrue?(@protect[:pivot_tables])

      attributes << ["selectUnlockedCells", 1] unless ptrue?(@protect[:select_unlocked_cells])

      @writer.empty_tag('sheetProtection', attributes)
    end

    #
    # Write the <protectedRanges> element.
    #
    def write_protected_ranges
      return if @num_protected_ranges == 0

      @writer.tag_elements('protectedRanges') do
        @protected_ranges.each do |protected_range|
          write_protected_range(*protected_range)
        end
      end
    end

    #
    # Write the <protectedRange> element.
    #
    def write_protected_range(sqref, name, password)
      attributes = []

      attributes << ['password', password] if password
      attributes << ['sqref',    sqref]
      attributes << ['name',     name]

      @writer.empty_tag('protectedRange', attributes)
    end

    #
    # Write the <drawing> elements.
    #
    def write_drawings # :nodoc:
      increment_rel_id_and_write_r_id('drawing') if drawings?
    end

    #
    # Write the <legacyDrawing> element.
    #
    def write_legacy_drawing # :nodoc:
      increment_rel_id_and_write_r_id('legacyDrawing') if has_vml?
    end

    #
    # Write the <legacyDrawingHF> element.
    #
    def write_legacy_drawing_hf # :nodoc:
      return unless has_header_vml?

      # Increment the relationship id for any drawings or comments.
      @rel_count += 1

      attributes = [['r:id', "rId#{@rel_count}"]]
      @writer.empty_tag('legacyDrawingHF', attributes)
    end

    #
    # Write the <picture> element.
    #
    def write_picture
      return unless @background_image

      # Increment the relationship id.
      @rel_count += 1
      id = @rel_count

      attributes = [['r:id', "rId#{id}"]]

      @writer.empty_tag('picture', attributes)
    end

    #
    # Write the underline font element.
    #
    def write_underline(writer, underline) # :nodoc:
      writer.empty_tag('u', underline_attributes(underline))
    end

    #
    # Write the <tableParts> element.
    #
    def write_table_parts
      return if @tables.empty?

      @writer.tag_elements('tableParts', [['count', tables_count]]) do
        tables_count.times { increment_rel_id_and_write_r_id('tablePart') }
      end
    end

    #
    # Write the <tablePart> element.
    #
    def write_table_part(id)
      @writer.empty_tag('tablePart', [r_id_attributes(id)])
    end

    def increment_rel_id_and_write_r_id(tag)
      @rel_count += 1
      write_r_id(tag, @rel_count)
    end

    def write_r_id(tag, id)
      @writer.empty_tag(tag, [r_id_attributes(id)])
    end

    #
    # Write the <extLst> element for data bars and sparklines.
    #
    def write_ext_list  # :nodoc:
      return if @data_bars_2010.empty? && @sparklines.empty?

      @writer.tag_elements('extLst') do
        write_ext_list_data_bars  if @data_bars_2010.size > 0
        write_ext_list_sparklines if @sparklines.size > 0
      end
    end

    #
    # Write the Excel 2010 data_bar subelements.
    #
    def write_ext_list_data_bars
      # Write the ext element.
      write_ext('{78C0D931-6437-407d-A8EE-F0AAD7539E65}') do
        @writer.tag_elements('x14:conditionalFormattings') do
          # Write each of the Excel 2010 conditional formatting data bar elements.
          @data_bars_2010.each do |data_bar|
            # Write the x14:conditionalFormatting element.
            write_conditional_formatting_2010(data_bar)
          end
        end
      end
    end

    #
    # Write the <x14:conditionalFormatting> element.
    #
    def write_conditional_formatting_2010(data_bar)
      xmlns_xm = 'http://schemas.microsoft.com/office/excel/2006/main'

      attributes = [['xmlns:xm', xmlns_xm]]

      @writer.tag_elements('x14:conditionalFormatting', attributes) do
        # Write the '<x14:cfRule element.
        write_x14_cf_rule(data_bar)

        # Write the x14:dataBar element.
        write_x14_data_bar(data_bar)

        # Write the x14 max and min data bars.
        write_x14_cfvo(data_bar[:x14_min_type], data_bar[:min_value])
        write_x14_cfvo(data_bar[:x14_max_type], data_bar[:max_value])

        # Write the x14:borderColor element.
        write_x14_border_color(data_bar[:bar_border_color]) unless ptrue?(data_bar[:bar_no_border])

        # Write the x14:negativeFillColor element.
        write_x14_negative_fill_color(data_bar[:bar_negative_color]) unless ptrue?(data_bar[:bar_negative_color_same])

        # Write the x14:negativeBorderColor element.
        if !ptrue?(data_bar[:bar_no_border]) &&
           !ptrue?(data_bar[:bar_negative_border_color_same])
          write_x14_negative_border_color(
            data_bar[:bar_negative_border_color]
          )
        end

        # Write the x14:axisColor element.
        write_x14_axis_color(data_bar[:bar_axis_color]) if data_bar[:bar_axis_position] != 'none'

        # Write closing elements.
        @writer.end_tag('x14:dataBar')
        @writer.end_tag('x14:cfRule')

        # Add the conditional format range.
        @writer.data_element('xm:sqref', data_bar[:range])
      end
    end

    #
    # Write the <cfvo> element.
    #
    def write_x14_cfvo(type, value)
      attributes = [['type', type]]

      if %w[min max autoMin autoMax].include?(type)
        @writer.empty_tag('x14:cfvo', attributes)
      else
        @writer.tag_elements('x14:cfvo', attributes) do
          @writer.data_element('xm:f', value)
        end
      end
    end

    #
    # Write the <'<x14:cfRule> element.
    #
    def write_x14_cf_rule(data_bar)
      type = 'dataBar'
      id   = data_bar[:guid]

      attributes = [
        ['type', type],
        ['id',   id]
      ]

      @writer.start_tag('x14:cfRule', attributes)
    end

    #
    # Write the <x14:dataBar> element.
    #
    def write_x14_data_bar(data_bar)
      min_length = 0
      max_length = 100

      attributes = [
        ['minLength', min_length],
        ['maxLength', max_length]
      ]

      attributes << ['border',   1] unless ptrue?(data_bar[:bar_no_border])
      attributes << ['gradient', 0] if ptrue?(data_bar[:bar_solid])

      attributes << %w[direction leftToRight] if data_bar[:bar_direction] == 'left'
      attributes << %w[direction rightToLeft] if data_bar[:bar_direction] == 'right'

      attributes << ['negativeBarColorSameAsPositive', 1] if ptrue?(data_bar[:bar_negative_color_same])

      if !ptrue?(data_bar[:bar_no_border]) &&
         !ptrue?(data_bar[:bar_negative_border_color_same])
        attributes << ['negativeBarBorderColorSameAsPositive', 0]
      end

      attributes << %w[axisPosition middle] if data_bar[:bar_axis_position] == 'middle'

      attributes << %w[axisPosition none] if data_bar[:bar_axis_position] == 'none'

      @writer.start_tag('x14:dataBar', attributes)
    end

    #
    # Write the <x14:borderColor> element.
    #
    def write_x14_border_color(rgb)
      attributes = [['rgb', rgb]]

      @writer.empty_tag('x14:borderColor', attributes)
    end

    #
    # Write the <x14:negativeFillColor> element.
    #
    def write_x14_negative_fill_color(rgb)
      attributes = [['rgb', rgb]]

      @writer.empty_tag('x14:negativeFillColor', attributes)
    end

    #
    # Write the <x14:negativeBorderColor> element.
    #
    def write_x14_negative_border_color(rgb)
      attributes = [['rgb', rgb]]

      @writer.empty_tag('x14:negativeBorderColor', attributes)
    end

    #
    # Write the <x14:axisColor> element.
    #
    def write_x14_axis_color(rgb)
      attributes = [['rgb', rgb]]

      @writer.empty_tag('x14:axisColor', attributes)
    end

    #
    # Write the sparkline subelements.
    #
    def write_ext_list_sparklines
      # Write the ext element.
      write_ext('{05C60535-1F16-4fd2-B633-F4F36F0B64E0}') do
        # Write the x14:sparklineGroups element.
        write_sparkline_groups
      end
    end

    #
    # Write the <x14:sparklines> element and <x14:sparkline> subelements.
    #
    def write_sparklines(sparkline)
      # Write the sparkline elements.
      @writer.tag_elements('x14:sparklines') do
        (0..sparkline[:count] - 1).each do |i|
          range    = sparkline[:ranges][i]
          location = sparkline[:locations][i]

          @writer.tag_elements('x14:sparkline') do
            @writer.data_element('xm:f', range)
            @writer.data_element('xm:sqref', location)
          end
        end
      end
    end

    def sparkline_groups_attributes  # :nodoc:
      [
        ['xmlns:xm', "#{OFFICE_URL}excel/2006/main"]
      ]
    end

    #
    # Write the <dataValidations> element.
    #
    def write_data_validations # :nodoc:
      write_some_elements('dataValidations', @validations) do
        @validations.each { |validation| validation.write_data_validation(@writer) }
      end
    end

    #
    # Write the Worksheet conditional formats.
    #
    def write_conditional_formats  # :nodoc:
      @cond_formats.keys.sort.each do |range|
        write_conditional_formatting(range, @cond_formats[range])
      end
    end

    #
    # Write the <conditionalFormatting> element.
    #
    def write_conditional_formatting(range, cond_formats) # :nodoc:
      @writer.tag_elements('conditionalFormatting', [['sqref', range]]) do
        cond_formats.each { |cond_format| cond_format.write_cf_rule }
      end
    end

    def store_data_to_table(cell_data, row, col) # :nodoc:
      if @cell_data_table[row]
        @cell_data_table[row][col] = cell_data
      else
        @cell_data_table[row] = []
        @cell_data_table[row][col] = cell_data
      end
    end

    def store_row_col_max_min_values(row, col)
      store_row_max_min_values(row)
      store_col_max_min_values(col)
    end

    #
    # Calculate the "spans" attribute of the <row> tag. This is an XLSX
    # optimisation and isn't strictly required. However, it makes comparing
    # files easier.
    #
    def calculate_spans # :nodoc:
      span_min = nil
      span_max = 0
      spans = []

      (@dim_rowmin..@dim_rowmax).each do |row_num|
        span_min, span_max = calc_spans(@cell_data_table, row_num, span_min, span_max) if @cell_data_table[row_num]

        # Calculate spans for comments.
        span_min, span_max = calc_spans(@comments, row_num, span_min, span_max) if @comments[row_num]

        next unless ((row_num + 1) % 16 == 0) || (row_num == @dim_rowmax)

        span_index = row_num / 16
        next unless span_min

        span_min += 1
        span_max += 1
        spans[span_index] = "#{span_min}:#{span_max}"
        span_min = nil
      end

      @row_spans = spans
    end

    def calc_spans(data, row_num, span_min, span_max)
      (@dim_colmin..@dim_colmax).each do |col_num|
        if data[row_num][col_num]
          if span_min
            span_min = col_num if col_num < span_min
            span_max = col_num if col_num > span_max
          else
            span_min = col_num
            span_max = col_num
          end
        end
      end
      [span_min, span_max]
    end

    #
    # Add a string to the shared string table, if it isn't already there, and
    # return the string index.
    #
    def shared_string_index(str) # :nodoc:
      @workbook.shared_string_index(str)
    end

    #
    # convert_name_area(first_row, first_col, last_row, last_col)
    #
    # Convert zero indexed rows and columns to the format required by worksheet
    # named ranges, eg, "Sheet1!$A$1:$C$13".
    #
    def convert_name_area(row_num_1, col_num_1, row_num_2, col_num_2) # :nodoc:
      range1       = ''
      range2       = ''
      row_col_only = false

      # Convert to A1 notation.
      col_char_1 = xl_col_to_name(col_num_1, 1)
      col_char_2 = xl_col_to_name(col_num_2, 1)
      row_char_1 = "$#{row_num_1 + 1}"
      row_char_2 = "$#{row_num_2 + 1}"

      # We need to handle some special cases that refer to rows or columns only.
      if row_num_1 == 0 and row_num_2 == ROW_MAX - 1
        range1       = col_char_1
        range2       = col_char_2
        row_col_only = true
      elsif col_num_1 == 0 and col_num_2 == COL_MAX - 1
        range1       = row_char_1
        range2       = row_char_2
        row_col_only = true
      else
        range1 = col_char_1 + row_char_1
        range2 = col_char_2 + row_char_2
      end

      # A repeated range is only written once (if it isn't a special case).
      area = if range1 == range2 && !row_col_only
               range1
             else
               "#{range1}:#{range2}"
             end

      # Build up the print area range "Sheet1!$A$1:$C$13".
      "#{quote_sheetname(@name)}!#{area}"
    end

    def fit_page? # :nodoc:
      @page_setup.fit_page
    end

    def filter_on? # :nodoc:
      ptrue?(@filter_on)
    end

    def tab_color? # :nodoc:
      ptrue?(@tab_color)
    end

    def outline_changed?
      ptrue?(@outline_changed)
    end

    def vba_codename?
      ptrue?(@vba_codename)
    end

    def zoom_scale_normal? # :nodoc:
      ptrue?(@zoom_scale_normal)
    end

    def right_to_left? # :nodoc:
      !!@right_to_left
    end

    def show_zeros? # :nodoc:
      !!@show_zeros
    end

    def protect? # :nodoc:
      !!@protect
    end

    def autofilter_ref? # :nodoc:
      !!@autofilter_ref
    end

    def drawings? # :nodoc:
      !!@drawings
    end

    def remove_white_space(margin) # :nodoc:
      if margin.respond_to?(:gsub)
        margin.gsub(/[^\d.]/, '')
      else
        margin
      end
    end

    def set_active_pane_and_cell_selections(row, col, top_row, left_col, active_cell, sqref) # :nodoc:
      if row > 0 && col > 0
        active_pane = 'bottomRight'
        row_cell = xl_rowcol_to_cell(top_row, 0)
        col_cell = xl_rowcol_to_cell(0, left_col)

        @selections <<
          ['topRight',    col_cell,    col_cell] <<
          ['bottomLeft',  row_cell,    row_cell] <<
          ['bottomRight', active_cell, sqref]
      elsif col > 0
        active_pane = 'topRight'
        @selections << ['topRight', active_cell, sqref]
      else
        active_pane = 'bottomLeft'
        @selections << ['bottomLeft', active_cell, sqref]
      end
      active_pane
    end

    def prepare_filter_column(col) # :nodoc:
      # Check for a column reference in A1 notation and substitute.
      if col.to_s =~ /^\D/
        col_letter = col

        # Convert col ref to a cell ref and then to a col number.
        _dummy, col = substitute_cellref("#{col}1")
        raise "Invalid column '#{col_letter}'" if col >= COL_MAX
      end

      col_first, col_last = @filter_range

      # Reject column if it is outside filter range.
      raise "Column '#{col}' outside autofilter column range (#{col_first} .. #{col_last})" if col < col_first or col > col_last

      col
    end

    #
    # Write the <ignoredErrors> element.
    #
    def write_ignored_errors
      return unless @ignore_errors

      ignore = @ignore_errors

      @writer.tag_elements('ignoredErrors') do
        {
          number_stored_as_text: 'numberStoredAsText',
          eval_error:            'evalError',
          formula_differs:       'formula',
          formula_range:         'formulaRange',
          formula_unlocked:      'unlockedFormula',
          empty_cell_reference:  'emptyCellReference',
          list_data_validation:  'listDataValidation',
          calculated_column:     'calculatedColumn',
          two_digit_text_year:   'twoDigitTextYear'
        }.each do |key, value|
          write_ignored_error(value, ignore[key]) if ignore[key]
        end
      end
    end

    #
    # Write the <ignoredError> element.
    #
    def write_ignored_error(type, sqref)
      attributes = [
        ['sqref', sqref],
        [type, 1]
      ]

      @writer.empty_tag('ignoredError', attributes)
    end

    def prepare_header_footer_image(image, header_image_ids, image_ref_id)
      @workbook.store_image_types(image.type)

      if header_image_ids[image.md5]
        ref_id = header_image_ids[image.md5]
      else
        image_ref_id += 1
        header_image_ids[image.md5] = ref_id = image_ref_id
        @workbook.images << image
      end

      prepare_header_image(ref_id, image)

      image_ref_id
    end

    def protect_default_settings  # :nodoc:
      {
        sheet:                 true,
        content:               false,
        objects:               false,
        scenarios:             false,
        format_cells:          false,
        format_columns:        false,
        format_rows:           false,
        insert_columns:        false,
        insert_rows:           false,
        insert_hyperlinks:     false,
        delete_columns:        false,
        delete_rows:           false,
        select_locked_cells:   true,
        sort:                  false,
        autofilter:            false,
        pivot_tables:          false,
        select_unlocked_cells: true
      }
    end

    def expand_formula(formula, function, addition = '')
      if formula =~ /\b(#{function})/
        formula.gsub(
          ::Regexp.last_match(1),
          "_xlfn#{addition}.#{::Regexp.last_match(1)}"
        )
      else
        formula
      end
    end
  end
end
end

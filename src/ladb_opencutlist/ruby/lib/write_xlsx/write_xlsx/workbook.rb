# -*- coding: utf-8 -*-
# frozen_string_literal: true

require_relative 'chart'
require_relative 'chartsheet'
require_relative 'format'
require_relative 'formats'
require_relative 'image_property'
require_relative 'shape'
require_relative 'sheets'
require_relative 'utility'
require_relative 'worksheet'
require_relative 'zip_file_utils'
require_relative 'package/xml_writer_simple'
require_relative 'package/packager'
require 'tmpdir'
require 'tempfile'
require 'digest/md5'

module Ladb::OpenCutList
module Writexlsx
  OFFICE_URL     = 'http://schemas.microsoft.com/office/'   # :nodoc:
  MAX_URL_LENGTH = 2_079

  class Workbook
    include Writexlsx::Utility

    attr_writer :firstsheet                     # :nodoc:
    attr_reader :palette                        # :nodoc:
    attr_reader :worksheets                     # :nodoc:
    attr_accessor :drawings                     # :nodoc:
    attr_reader :named_ranges                   # :nodoc:
    attr_reader :doc_properties                 # :nodoc:
    attr_reader :custom_properties              # :nodoc:
    attr_reader :image_types, :images           # :nodoc:
    attr_reader :shared_strings                 # :nodoc:
    attr_reader :vba_project                    # :nodoc:
    attr_reader :excel2003_style                # :nodoc:
    attr_reader :max_url_length                 # :nodoc:
    attr_reader :strings_to_urls                # :nodoc:
    attr_reader :read_only                      # :nodoc:
    attr_reader :embedded_image_indexes         # :nodec:
    attr_reader :embedded_images                # :nodoc:
    attr_reader :embedded_descriptions          # :nodoc:
    attr_writer :has_embedded_descriptions      # :nodoc:
    attr_accessor :charts                       # :nodoc:

    def initialize(file, *option_params)
      options, default_formats = process_workbook_options(*option_params)
      @options = options.dup                    # for test
      @default_formats = default_formats.dup    # for test
      @writer = Package::XMLWriterSimple.new

      @file = file
      @tempdir = options[:tempdir] ||
                 File.join(
                   Dir.tmpdir,
                   Digest::MD5.hexdigest("#{Time.now.to_f}-#{Process.pid}")
                 )
      @date_1904           = options[:date_1904] || false
      @activesheet         = 0
      @firstsheet          = 0
      @selected            = 0
      @fileclosed          = false
      @worksheets          = Sheets.new
      @charts              = []
      @drawings            = []
      @formats             = Formats.new
      @xf_formats          = []
      @dxf_formats         = []
      @num_formats         = []
      @defined_names       = []
      @named_ranges        = []
      @custom_colors       = []
      @doc_properties      = {}
      @custom_properties   = []
      @optimization        = options[:optimization] || 0
      @x_window            = 240
      @y_window            = 15
      @window_width        = 16_095
      @window_height       = 9_660
      @tab_ratio           = 600
      @excel2003_style     = options[:excel2003_style] || false
      @image_types         = {}
      @images              = []
      @strings_to_urls     = options[:strings_to_urls].nil? || options[:strings_to_urls] ? true : false

      @max_url_length      = MAX_URL_LENGTH
      @has_comments        = false
      @read_only           = 0
      @has_metadata        = false
      @has_embedded_images = false
      @has_embedded_descriptions = false

      if options[:max_url_length]
        @max_url_length = options[:max_url_length].to_i

        @max_url_length = MAX_URL_LENGTH if @max_url_length < 255
      end

      # Structures for the shared strings data.
      @shared_strings = Package::SharedStrings.new

      # Structures for embedded images.
      @embedded_image_indexes = {}
      @embedded_images        = []

      # Formula calculation default settings.
      @calc_id             = 124519
      @calc_mode           = 'auto'
      @calc_on_load        = true

      if @excel2003_style
        add_format(default_formats.merge(
                     xf_index:    0,
                     font_family: 0,
                     font:        'Arial',
                     size:        10,
                     theme:       -1
                   ))
      else
        add_format(default_formats.merge(xf_index: 0))
      end

      # Add a default URL format.
      @default_url_format = add_format(hyperlink: 1)

      set_color_palette
    end

    #
    # The close method is used to close an Excel file.
    #
    def close
      # In case close() is called twice.
      return if @fileclosed

      @fileclosed = true
      store_workbook
    end

    #
    # get array of Worksheet objects
    #
    # :call-seq:
    #   sheets              -> array of all Wordsheet object
    #   sheets(1, 3, 4)     -> array of spcified Worksheet object.
    #
    def sheets(*args)
      if args.empty?
        @worksheets
      else
        args.collect { |i| @worksheets[i] }
      end
    end

    #
    # Return a worksheet object in the workbook using the sheetname.
    #
    def worksheet_by_name(sheetname = nil)
      sheets.select { |s| s.name == sheetname }.first
    end
    alias get_worksheet_by_name worksheet_by_name

    #
    # Set the date system: false = 1900 (the default), true = 1904
    #
    def set_1904(mode = true)
      raise "set_1904() must be called before add_worksheet()" unless sheets.empty?

      @date_1904 = ptrue?(mode)
    end

    #
    # return date system. false = 1900, true = 1904
    #
    def get_1904
      @date_1904
    end

    def set_tempdir(dir)
      @tempdir = dir.dup
    end

    #
    # user must not use. it is internal method.
    #
    def set_xml_writer(filename)  # :nodoc:
      @writer.set_xml_writer(filename)
    end

    #
    # user must not use. it is internal method.
    #
    def xml_str  # :nodoc:
      @writer.string
    end

    #
    # user must not use. it is internal method.
    #
    def assemble_xml_file  # :nodoc:
      return unless @writer

      # Prepare format object for passing to Style.rb.
      prepare_format_properties

      write_xml_declaration do
        # Write the root workbook element.
        write_workbook do
          # Write the XLSX file version.
          write_file_version

          # Write the fileSharing element.
          write_file_sharing

          # Write the workbook properties.
          write_workbook_pr

          # Write the workbook view properties.
          write_book_views

          # Write the worksheet names and ids.
          @worksheets.write_sheets(@writer)

          # Write the workbook defined names.
          write_defined_names

          # Write the workbook calculation properties.
          write_calc_pr

          # Write the workbook extension storage.
          # write_ext_lst
        end
      end
    end

    #
    # At least one worksheet should be added to a new workbook. A worksheet is used to write data into cells:
    #
    def add_worksheet(name = '')
      name = check_sheetname(name)
      worksheet = Worksheet.new(self, @worksheets.size, name)
      @worksheets << worksheet
      worksheet
    end

    #
    # This method is use to create a new chart either as a standalone worksheet
    # (the default) or as an embeddable object that can be inserted into
    # a worksheet via the insert_chart method.
    #
    def add_chart(params = {})
      # Type must be specified so we can create the required chart instance.
      type     = params[:type]
      embedded = params[:embedded]
      name     = params[:name]
      raise "Must define chart type in add_chart()" unless type

      chart = Chart.factory(type, params[:subtype])
      chart.palette = @palette

      # If the chart isn't embedded let the workbook control it.
      if ptrue?(embedded)
        chart.name = name if name

        # Set index to 0 so that the activate() and set_first_sheet() methods
        # point back to the first worksheet if used for embedded charts.
        chart.index = 0
        chart.set_embedded_config_data
      else
        # Check the worksheet name for non-embedded charts.
        sheetname  = check_chart_sheetname(name)
        chartsheet = Chartsheet.new(self, @worksheets.size, sheetname)
        chartsheet.chart = chart
        @worksheets << chartsheet
      end
      @charts << chart
      ptrue?(embedded) ? chart : chartsheet
    end

    #
    # The add_format method can be used to create new Format objects
    # which are used to apply formatting to a cell. You can either define
    # the properties at creation time via a hash of property values
    # or later via method calls.
    #
    #     format1 = workbook.add_format(property_hash) # Set properties at creation
    #     format2 = workbook.add_format                # Set properties later
    #
    def add_format(property_hash = {})
      properties = {}
      properties.update(font: 'Arial', size: 10, theme: -1) if @excel2003_style
      properties.update(property_hash)

      format = Format.new(@formats, properties)

      @formats.formats.push(format)    # Store format reference

      format
    end

    #
    # The +add_shape+ method can be used to create new shapes that may be
    # inserted into a worksheet.
    #
    def add_shape(properties = {})
      shape = Shape.new(properties)
      shape.palette = @palette

      @shapes ||= []
      @shapes << shape  # Store shape reference.
      shape
    end

    #
    # Create a defined name in Excel. We handle global/workbook level names and
    # local/worksheet names.
    #
    def define_name(name, formula)
      sheet_index = nil
      sheetname   = ''

      # Local defined names are formatted like "Sheet1!name".
      if name =~ /^(.*)!(.*)$/
        sheetname   = ::Regexp.last_match(1)
        name        = ::Regexp.last_match(2)
        sheet_index = @worksheets.index_by_name(sheetname)
      else
        sheet_index = -1   # Use -1 to indicate global names.
      end

      # Raise if the sheet index wasn't found.
      raise "Unknown sheet name #{sheetname} in defined_name()" unless sheet_index

      # Raise if the name contains invalid chars as defined by Excel help.
      # Refer to the following to see Excel's syntax rules for defined names:
      # http://office.microsoft.com/en-001/excel-help/define-and-use-names-in-formulas-HA010147120.aspx#BMsyntax_rules_for_names
      #
      raise "Invalid characters in name '#{name}' used in defined_name()" if name =~ /\A[-0-9 !"#$%&'()*+,.:;<=>?@\[\]\^`{}~]/ || name =~ /.+[- !"#$%&'()*+,\\:;<=>?@\[\]\^`{}~]/

      # Raise if the name looks like a cell name.
      raise "Invalid name '#{name}' looks like a cell name in defined_name()" if name =~ /^[a-zA-Z][a-zA-Z]?[a-dA-D]?[0-9]+$/

      # Raise if the name looks like a R1C1
      raise "Invalid name '#{name}' like a RC cell ref in defined_name()" if name =~ /\A[rcRC]\Z/ || name =~ /\A[rcRC]\d+[rcRC]\d+\Z/

      @defined_names.push([name, sheet_index, formula.sub(/^=/, '')])
    end

    #
    # Set the workbook size.
    #
    def set_size(width = nil, height = nil)
      @window_width = if ptrue?(width)
                        # Convert to twips at 96 dpi.
                        width.to_i * 1440 / 96
                      else
                        16095
                      end

      @window_height = if ptrue?(height)
                         # Convert to twips at 96 dpi.
                         height.to_i * 1440 / 96
                       else
                         9660
                       end
    end

    #
    # Set the ratio of space for worksheet tabs.
    #
    def set_tab_ratio(tab_ratio = nil)
      return unless tab_ratio

      if tab_ratio < 0 || tab_ratio > 100
        raise "Tab ratio outside range: 0 <= zoom <= 100"
      else
        @tab_ratio = (tab_ratio * 10).to_i
      end
    end

    #
    # The set_properties method can be used to set the document properties
    # of the Excel file created by WriteXLSX. These properties are visible
    # when you use the Office Button -> Prepare -> Properties option in Excel
    # and are also available to external applications that read or index windows
    # files.
    #
    def set_properties(params)
      # Ignore if no args were passed.
      return -1 if params.empty?

      # List of valid input parameters.
      valid = {
        title:          1,
        subject:        1,
        author:         1,
        keywords:       1,
        comments:       1,
        last_author:    1,
        created:        1,
        category:       1,
        manager:        1,
        company:        1,
        status:         1,
        hyperlink_base: 1
      }

      # Check for valid input parameters.
      params.each_key do |key|
        return -1 unless valid.has_key?(key)
      end

      # Set the creation time unless specified by the user.
      params[:created] = @createtime unless params.has_key?(:created)

      @doc_properties = params.dup
    end

    #
    # Set a user defined custom document property.
    #
    def set_custom_property(name, value, type = nil)
      # Valid types.
      valid_type = {
        'text'       => 1,
        'date'       => 1,
        'number'     => 1,
        'number_int' => 1,
        'bool'       => 1
      }

      raise "The name and value parameters must be defined in set_custom_property()" if !name || (type != 'bool' && !value)

      # Determine the type for strings and numbers if it hasn't been specified.
      unless ptrue?(type)
        type = if value =~ /^\d+$/
                 'number_int'
               elsif value =~
                     /^([+-]?)(?=[0-9]|\.[0-9])[0-9]*(\.[0-9]*)?([Ee]([+-]?[0-9]+))?$/
                 'number'
               else
                 'text'
               end
      end

      # Check for valid validation types.
      raise "Unknown custom type '$type' in set_custom_property()" unless valid_type[type]

      #  Check for strings longer than Excel's limit of 255 chars.
      raise "Length of text custom value '$value' exceeds Excel's limit of 255 in set_custom_property()" if type == 'text' && value.length > 255

      if type == 'bool'
        value = value ? 1 : 0
      end

      @custom_properties << [name, value, type]
    end

    #
    # The add_vba_project method can be used to add macros or functions to an
    # WriteXLSX file using a binary VBA project file that has been extracted
    # from an existing Excel xlsm file.
    #
    def add_vba_project(vba_project)
      @vba_project = vba_project
    end

    #
    # Set the VBA name for the workbook.
    #
    def set_vba_name(vba_codename = nil)
      @vba_codename = vba_codename || 'ThisWorkbook'
    end

    #
    # Set the Excel "Read-only recommended" save option.
    #
    def read_only_recommended
      @read_only = 2
    end

    #
    # set_calc_mode()
    #
    # Set the Excel caclcuation mode for the workbook.
    #
    def set_calc_mode(mode, calc_id = nil)
      @calc_mode = mode || 'auto'

      if mode == 'manual'
        @calc_on_load = false
      elsif mode == 'auto_except_tables'
        @calc_mode = 'autoNoTable'
      end

      @calc_id = calc_id if calc_id
    end

    #
    # Get the default url format used when a user defined format isn't specified
    # with write_url(). The format is the hyperlink style defined by Excel for the
    # default theme.
    #
    attr_reader :default_url_format
    alias get_default_url_format default_url_format

    #
    # Change the RGB components of the elements in the colour palette.
    #
    def set_custom_color(index, red = 0, green = 0, blue = 0)
      # Match a HTML #xxyyzz style parameter
      if red.to_s =~ /^#(\w\w)(\w\w)(\w\w)/
        red   = ::Regexp.last_match(1).hex
        green = ::Regexp.last_match(2).hex
        blue  = ::Regexp.last_match(3).hex
      end

      # Check that the colour index is the right range
      raise "Color index #{index} outside range: 8 <= index <= 64" if index < 8 || index > 64

      # Check that the colour components are in the right range
      if (red   < 0 || red   > 255) ||
         (green < 0 || green > 255) ||
         (blue  < 0 || blue  > 255)
        raise "Color component outside range: 0 <= color <= 255"
      end

      index -= 8       # Adjust colour index (wingless dragonfly)

      # Set the RGB value
      @palette[index] = [red, green, blue]

      # Store the custome colors for the style.xml file.
      @custom_colors << sprintf("FF%02X%02X%02X", red, green, blue)

      index + 8
    end

    attr_writer :activesheet

    attr_reader :writer

    def date_1904? # :nodoc:
      @date_1904 ||= false
      !!@date_1904
    end

    def has_dynamic_functions?
      @has_dynamic_functions
    end

    #
    # Add a string to the shared string table, if it isn't already there, and
    # return the string index.
    #
    EMPTY_HASH = {}.freeze
    def shared_string_index(str) # :nodoc:
      @shared_strings.index(str, EMPTY_HASH)
    end

    def str_unique   # :nodoc:
      @shared_strings.unique_count
    end

    def shared_strings_empty?  # :nodoc:
      @shared_strings.empty?
    end

    def chartsheet_count
      @worksheets.chartsheet_count
    end

    def non_chartsheet_count
      @worksheets.worksheets.count
    end

    def style_properties
      [
        @xf_formats,
        @palette,
        @font_count,
        @num_formats,
        @border_count,
        @fill_count,
        @custom_colors,
        @dxf_formats,
        @has_comments
      ]
    end

    def num_vml_files
      @worksheets.select { |sheet| sheet.has_vml? || sheet.has_header_vml? }.count
    end

    def num_comment_files
      @worksheets.select { |sheet| sheet.has_comments? }.count
    end

    def chartsheets
      @worksheets.chartsheets
    end

    def non_chartsheets
      @worksheets.worksheets
    end

    def firstsheet # :nodoc:
      @firstsheet ||= 0
    end

    def activesheet # :nodoc:
      @activesheet ||= 0
    end

    def has_metadata?
      @has_metadata
    end

    def has_embedded_images?
      @has_embedded_images
    end

    def has_embedded_descriptions?
      @has_embedded_descriptions
    end

    #
    # Store the image types (PNG/JPEG/etc) used in the workbook to use in these
    # Content_Types file.
    #
    def store_image_types(type)
      case type
      when 'png'
        @image_types[:png] = 1
      when 'jpeg'
        @image_types[:jpeg] = 1
      when 'gif'
        @image_types[:gif] = 1
      when 'bmp'
        @image_types[:bmp] = 1
      end
    end

    private

    #
    # Workbook の生成時のオプションハッシュを解析する
    #
    def process_workbook_options(*params)
      case params.size
      when 0
        [{}, {}]
      when 1 # one hash
        options_keys = %i[tempdir date_1904 optimization excel2003_style strings_to_urls max_url_length]

        hash = params.first
        options = hash.reject { |k, _v| !options_keys.include?(k) }

        default_format_properties =
          hash[:default_format_properties] ||
          hash.reject { |k, _v| options_keys.include?(k) }

        [options, default_format_properties.dup]
      when 2 # array which includes options and default_format_properties
        options, default_format_properties = params
        default_format_properties ||= {}

        [options.dup, default_format_properties.dup]
      end
    end

    def filename
      setup_filename unless @filename
      @filename
    end

    def fileobj
      setup_filename unless @fileobj
      @fileobj
    end

    def setup_filename # :nodoc:
      if @file.respond_to?(:to_str) && @file != ''
        @filename = @file
        @fileobj  = nil
      elsif @file.respond_to?(:write)
        @filename = File.join(tempdir, Digest::MD5.hexdigest(Time.now.to_s) + '.xlsx.tmp')
        @fileobj  = @file
      else
        raise "'#{@file}' must be valid filename String of IO object."
      end
    end

    attr_reader :tempdir

    #
    # Sets the colour palette to the Excel defaults.
    #
    def set_color_palette # :nodoc:
      @palette = [
        [0x00, 0x00, 0x00, 0x00],    # 8
        [0xff, 0xff, 0xff, 0x00],    # 9
        [0xff, 0x00, 0x00, 0x00],    # 10
        [0x00, 0xff, 0x00, 0x00],    # 11
        [0x00, 0x00, 0xff, 0x00],    # 12
        [0xff, 0xff, 0x00, 0x00],    # 13
        [0xff, 0x00, 0xff, 0x00],    # 14
        [0x00, 0xff, 0xff, 0x00],    # 15
        [0x80, 0x00, 0x00, 0x00],    # 16
        [0x00, 0x80, 0x00, 0x00],    # 17
        [0x00, 0x00, 0x80, 0x00],    # 18
        [0x80, 0x80, 0x00, 0x00],    # 19
        [0x80, 0x00, 0x80, 0x00],    # 20
        [0x00, 0x80, 0x80, 0x00],    # 21
        [0xc0, 0xc0, 0xc0, 0x00],    # 22
        [0x80, 0x80, 0x80, 0x00],    # 23
        [0x99, 0x99, 0xff, 0x00],    # 24
        [0x99, 0x33, 0x66, 0x00],    # 25
        [0xff, 0xff, 0xcc, 0x00],    # 26
        [0xcc, 0xff, 0xff, 0x00],    # 27
        [0x66, 0x00, 0x66, 0x00],    # 28
        [0xff, 0x80, 0x80, 0x00],    # 29
        [0x00, 0x66, 0xcc, 0x00],    # 30
        [0xcc, 0xcc, 0xff, 0x00],    # 31
        [0x00, 0x00, 0x80, 0x00],    # 32
        [0xff, 0x00, 0xff, 0x00],    # 33
        [0xff, 0xff, 0x00, 0x00],    # 34
        [0x00, 0xff, 0xff, 0x00],    # 35
        [0x80, 0x00, 0x80, 0x00],    # 36
        [0x80, 0x00, 0x00, 0x00],    # 37
        [0x00, 0x80, 0x80, 0x00],    # 38
        [0x00, 0x00, 0xff, 0x00],    # 39
        [0x00, 0xcc, 0xff, 0x00],    # 40
        [0xcc, 0xff, 0xff, 0x00],    # 41
        [0xcc, 0xff, 0xcc, 0x00],    # 42
        [0xff, 0xff, 0x99, 0x00],    # 43
        [0x99, 0xcc, 0xff, 0x00],    # 44
        [0xff, 0x99, 0xcc, 0x00],    # 45
        [0xcc, 0x99, 0xff, 0x00],    # 46
        [0xff, 0xcc, 0x99, 0x00],    # 47
        [0x33, 0x66, 0xff, 0x00],    # 48
        [0x33, 0xcc, 0xcc, 0x00],    # 49
        [0x99, 0xcc, 0x00, 0x00],    # 50
        [0xff, 0xcc, 0x00, 0x00],    # 51
        [0xff, 0x99, 0x00, 0x00],    # 52
        [0xff, 0x66, 0x00, 0x00],    # 53
        [0x66, 0x66, 0x99, 0x00],    # 54
        [0x96, 0x96, 0x96, 0x00],    # 55
        [0x00, 0x33, 0x66, 0x00],    # 56
        [0x33, 0x99, 0x66, 0x00],    # 57
        [0x00, 0x33, 0x00, 0x00],    # 58
        [0x33, 0x33, 0x00, 0x00],    # 59
        [0x99, 0x33, 0x00, 0x00],    # 60
        [0x99, 0x33, 0x66, 0x00],    # 61
        [0x33, 0x33, 0x99, 0x00],    # 62
        [0x33, 0x33, 0x33, 0x00]    # 63
      ]
    end

    #
    # Check for valid worksheet names. We check the length, if it contains any
    # invalid characters and if the name is unique in the workbook.
    #
    def check_sheetname(name) # :nodoc:
      @worksheets.make_and_check_sheet_chart_name(:sheet, name)
    end

    def check_chart_sheetname(name)
      @worksheets.make_and_check_sheet_chart_name(:chart, name)
    end

    #
    # Convert a range formula such as Sheet1!$B$1:$B$5 into a sheet name and cell
    # range such as ( 'Sheet1', 0, 1, 4, 1 ).
    #
    def get_chart_range(range) # :nodoc:
      # Split the range formula into sheetname and cells at the last '!'.
      pos = range.rindex('!')
      return nil unless pos

      if pos > 0
        sheetname = range[0, pos]
        cells = range[pos + 1..-1]
      end

      # Split the cell range into 2 cells or else use single cell for both.
      if cells =~ /:/
        cell_1, cell_2 = cells.split(":")
      else
        cell_1 = cells
        cell_2 = cells
      end

      # Remove leading/trailing apostrophes and convert escaped quotes to single.
      sheetname.sub!(/^'/, '')
      sheetname.sub!(/'$/, '')
      sheetname.gsub!("''", "'")

      row_start, col_start = xl_cell_to_rowcol(cell_1)
      row_end,   col_end   = xl_cell_to_rowcol(cell_2)

      # Check that we have a 1D range only.
      return nil if row_start != row_end && col_start != col_end

      [sheetname, row_start, col_start, row_end, col_end]
    end

    def write_workbook(&block) # :nodoc:
      schema = 'http://schemas.openxmlformats.org'
      attributes = [
        ['xmlns',
         schema + '/spreadsheetml/2006/main'],
        ['xmlns:r',
         schema + '/officeDocument/2006/relationships']
      ]
      @writer.tag_elements('workbook', attributes, &block)
    end

    def write_file_version # :nodoc:
      attributes = [
        %w[appName xl],
        ['lastEdited', 4],
        ['lowestEdited', 4],
        ['rupBuild', 4505]
      ]

      attributes << [:codeName, '{37E998C4-C9E5-D4B9-71C8-EB1FF731991C}'] if @vba_project

      @writer.empty_tag('fileVersion', attributes)
    end

    #
    # Write the <fileSharing> element.
    #
    def write_file_sharing
      return unless ptrue?(@read_only)

      attributes = []
      attributes << ['readOnlyRecommended', 1]
      @writer.empty_tag('fileSharing', attributes)
    end

    def write_workbook_pr # :nodoc:
      attributes = []
      attributes << ['codeName', @vba_codename]  if ptrue?(@vba_codename)
      attributes << ['date1904', 1]              if date_1904?
      attributes << ['defaultThemeVersion', 124226]
      @writer.empty_tag('workbookPr', attributes)
    end

    def write_book_views # :nodoc:
      @writer.tag_elements('bookViews') { write_workbook_view }
    end

    def write_workbook_view # :nodoc:
      attributes = [
        ['xWindow',       @x_window],
        ['yWindow',       @y_window],
        ['windowWidth',   @window_width],
        ['windowHeight',  @window_height]
      ]
      attributes << ['tabRatio', @tab_ratio] if @tab_ratio != 600
      attributes << ['firstSheet', @firstsheet + 1] if @firstsheet > 0
      attributes << ['activeTab', @activesheet] if @activesheet > 0
      @writer.empty_tag('workbookView', attributes)
    end

    def write_calc_pr # :nodoc:
      attributes = [['calcId', @calc_id]]

      case @calc_mode
      when 'manual'
        attributes << %w[calcMode manual]
        attributes << ['calcOnSave', 0]
      when 'autoNoTable'
        attributes << %w[calcMode autoNoTable]
      end

      attributes << ['fullCalcOnLoad', 1] if @calc_on_load

      @writer.empty_tag('calcPr', attributes)
    end

    def write_ext_lst # :nodoc:
      @writer.tag_elements('extLst') { write_ext }
    end

    def write_ext # :nodoc:
      attributes = [
        ['xmlns:mx', "#{OFFICE_URL}mac/excel/2008/main"],
        ['uri', uri]
      ]
      @writer.tag_elements('ext', attributes) { write_mx_arch_id }
    end

    def write_mx_arch_id # :nodoc:
      @writer.empty_tag('mx:ArchID', ['Flags', 2])
    end

    def write_defined_names # :nodoc:
      return unless ptrue?(@defined_names)

      @writer.tag_elements('definedNames') do
        @defined_names.each { |defined_name| write_defined_name(defined_name) }
      end
    end

    def write_defined_name(defined_name) # :nodoc:
      name, id, range, hidden = defined_name

      attributes = [['name', name]]
      attributes << ['localSheetId', "#{id}"] unless id == -1
      attributes << %w[hidden 1]     if hidden

      @writer.data_element('definedName', range, attributes)
    end

    def write_io(str) # :nodoc:
      @writer << str
      str
    end

    # for test
    def defined_names # :nodoc:
      @defined_names ||= []
    end

    #
    # Assemble worksheets into a workbook.
    #
    def store_workbook # :nodoc:
      # Add a default worksheet if non have been added.
      add_worksheet if @worksheets.empty?

      # Ensure that at least one worksheet has been selected.
      @worksheets.visible_first.select if @activesheet == 0

      # Set the active sheet.
      @activesheet = @worksheets.visible_first.index if @activesheet == 0
      @worksheets[@activesheet].activate

      # Convert the SST strings data structure.
      prepare_sst_string_data

      # Prepare the worksheet VML elements such as comments and buttons.
      prepare_vml_objects
      # Set the defined names for the worksheets such as Print Titles.
      prepare_defined_names
      # Prepare the drawings, charts and images.
      prepare_drawings
      # Add cached data to charts.
      add_chart_data

      # Prepare the worksheet tables.
      prepare_tables

      # Prepare the metadata file links.
      prepare_metadata

      # Package the workbook.
      packager = Package::Packager.new(self)
      packager.set_package_dir(tempdir)
      packager.create_package

      # Free up the Packager object.
      packager = nil

      # Store the xlsx component files with the temp dir name removed.
      ZipFileUtils.zip("#{tempdir}", filename)

      IO.copy_stream(filename, fileobj) if fileobj
      Writexlsx::Utility.delete_files(tempdir)
    end

    def zip_entry_for_part(part)
      Zip::Entry.new("", part)
    end

    #
    # prepare_sst_string_data
    #
    def prepare_sst_string_data; end

    #
    # Prepare all of the format properties prior to passing them to Styles.rb.
    #
    def prepare_format_properties # :nodoc:
      # Separate format objects into XF and DXF formats.
      prepare_formats

      # Set the font index for the format objects.
      prepare_fonts

      # Set the number format index for the format objects.
      prepare_num_formats

      # Set the border index for the format objects.
      prepare_borders

      # Set the fill index for the format objects.
      prepare_fills
    end

    #
    # Iterate through the XF Format objects and separate them into XF and DXF
    # formats.
    #
    def prepare_formats # :nodoc:
      @formats.formats.each do |format|
        xf_index  = format.xf_index
        dxf_index = format.dxf_index

        @xf_formats[xf_index] = format   if xf_index
        @dxf_formats[dxf_index] = format if dxf_index
      end
    end

    #
    # Iterate through the XF Format objects and give them an index to non-default
    # font elements.
    #
    def prepare_fonts # :nodoc:
      fonts = {}

      @xf_formats.each { |format| format.set_font_info(fonts) }

      @font_count = fonts.size

      # For the DXF formats we only need to check if the properties have changed.
      @dxf_formats.each do |format|
        # The only font properties that can change for a DXF format are: color,
        # bold, italic, underline and strikethrough.
        format.has_dxf_font(true) if format.color? || format.bold? || format.italic? || format.underline? || format.strikeout?
      end
    end

    #
    # Iterate through the XF Format objects and give them an index to non-default
    # number format elements.
    #
    # User defined records start from index 0xA4.
    #
    def prepare_num_formats # :nodoc:
      num_formats        = []
      unique_num_formats = {}
      index              = 164

      (@xf_formats + @dxf_formats).each do |format|
        num_format = format.num_format

        # Check if num_format is an index to a built-in number format.
        # Also check for a string of zeros, which is a valid number format
        # string but would evaluate to zero.
        #
        if num_format.to_s =~ /^\d+$/ && num_format.to_s !~ /^0+\d/
          # Number format '0' is indexed as 1 in Excel.
          num_format = 1 if num_format == 0
          # Index to a built-in number format.
          format.num_format_index = num_format
          next
        elsif num_format.to_s == 'General'
          # The 'General' format has an number format index of 0.
          format.num_format_index = 0
          next
        end

        if unique_num_formats[num_format]
          # Number format has already been used.
          format.num_format_index = unique_num_formats[num_format]
        else
          # Add a new number format.
          unique_num_formats[num_format] = index
          format.num_format_index = index
          index += 1

          # Only store/increase number format count for XF formats
          # (not for DXF formats).
          num_formats << num_format if ptrue?(format.xf_index)
        end
      end

      @num_formats = num_formats
    end

    #
    # Iterate through the XF Format objects and give them an index to non-default
    # border elements.
    #
    def prepare_borders # :nodoc:
      borders = {}

      @xf_formats.each { |format| format.set_border_info(borders) }

      @border_count = borders.size

      # For the DXF formats we only need to check if the properties have changed.
      @dxf_formats.each do |format|
        key = format.get_border_key
        format.has_dxf_border(true) if key =~ /[^0:]/
      end
    end

    #
    # Iterate through the XF Format objects and give them an index to non-default
    # fill elements.
    #
    # The user defined fill properties start from 2 since there are 2 default
    # fills: patternType="none" and patternType="gray125".
    #
    def prepare_fills # :nodoc:
      fills = {}
      index = 2    # Start from 2. See above.

      # Add the default fills.
      fills['0:0:0']  = 0
      fills['17:0:0'] = 1

      # Store the DXF colors separately since them may be reversed below.
      @dxf_formats.each do |format|
        next unless format.pattern != 0 || format.bg_color != 0 || format.fg_color != 0

        format.has_dxf_fill(true)
        format.dxf_bg_color = format.bg_color
        format.dxf_fg_color = format.fg_color
      end

      @xf_formats.each do |format|
        # The following logical statements jointly take care of special cases
        # in relation to cell colours and patterns:
        # 1. For a solid fill (_pattern == 1) Excel reverses the role of
        #    foreground and background colours, and
        # 2. If the user specifies a foreground or background colour without
        #    a pattern they probably wanted a solid fill, so we fill in the
        #    defaults.
        #
        if format.pattern == 1 && ne_0?(format.bg_color) && ne_0?(format.fg_color)
          format.fg_color, format.bg_color = format.bg_color, format.fg_color
        elsif format.pattern <= 1 && ne_0?(format.bg_color) && eq_0?(format.fg_color)
          format.fg_color = format.bg_color
          format.bg_color = 0
          format.pattern  = 1
        elsif format.pattern <= 1 && eq_0?(format.bg_color) && ne_0?(format.fg_color)
          format.bg_color = 0
          format.pattern  = 1
        end

        key = format.get_fill_key

        if fills[key]
          # Fill has already been used.
          format.fill_index = fills[key]
          format.has_fill(false)
        else
          # This is a new fill.
          fills[key]        = index
          format.fill_index = index
          format.has_fill(true)
          index += 1
        end
      end

      @fill_count = index
    end

    def eq_0?(val)
      ptrue?(val) ? false : true
    end

    def ne_0?(val)
      !eq_0?(val)
    end

    #
    # Iterate through the worksheets and store any defined names in addition to
    # any user defined names. Stores the defined names for the Workbook.xml and
    # the named ranges for App.xml.
    #
    def prepare_defined_names # :nodoc:
      @worksheets.each do |sheet|
        # Check for Print Area settings.
        if sheet.autofilter_area
          @defined_names << [
            '_xlnm._FilterDatabase',
            sheet.index,
            sheet.autofilter_area,
            1
          ]
        end

        # Check for Print Area settings.
        unless sheet.print_area.empty?
          @defined_names << [
            '_xlnm.Print_Area',
            sheet.index,
            sheet.print_area
          ]
        end

        # Check for repeat rows/cols. aka, Print Titles.
        next unless !sheet.print_repeat_cols.empty? || !sheet.print_repeat_rows.empty?

        range = if !sheet.print_repeat_cols.empty? && !sheet.print_repeat_rows.empty?
                  sheet.print_repeat_cols + ',' + sheet.print_repeat_rows
                else
                  sheet.print_repeat_cols + sheet.print_repeat_rows
                end

        # Store the defined names.
        @defined_names << ['_xlnm.Print_Titles', sheet.index, range]
      end

      @defined_names = sort_defined_names(@defined_names)
      @named_ranges  = extract_named_ranges(@defined_names)
    end

    #
    # Iterate through the worksheets and set up the VML objects.
    #
    def prepare_vml_objects  # :nodoc:
      comment_id     = 0
      vml_drawing_id = 0
      vml_data_id    = 1
      vml_header_id  = 0
      vml_shape_id   = 1024
      has_button     = false

      @worksheets.each do |sheet|
        next if !sheet.has_vml? && !sheet.has_header_vml?

        if sheet.has_vml?
          if sheet.has_comments?
            comment_id += 1
            @has_comments = true
          end
          vml_drawing_id += 1

          sheet.prepare_vml_objects(
            vml_data_id, vml_shape_id,
            vml_drawing_id, comment_id
          )

          # Each VML file should start with a shape id incremented by 1024.
          vml_data_id += 1 * (1 + sheet.num_comments_block)
          vml_shape_id += 1024 * (1 + sheet.num_comments_block)
        end

        if sheet.has_header_vml?
          vml_header_id  += 1
          vml_drawing_id += 1
          sheet.prepare_header_vml_objects(vml_header_id, vml_drawing_id)
        end

        # Set the sheet vba_codename if it has a button and the workbook
        # has a vbaProject binary.
        unless sheet.buttons_data.empty?
          has_button = true
          sheet.set_vba_name if @vba_project && !sheet.vba_codename
        end
      end

      # Set the workbook vba_codename if one of the sheets has a button and
      # the workbook has a vbaProject binary.
      set_vba_name if has_button && @vba_project && !@vba_codename
    end

    #
    # Set the table ids for the worksheet tables.
    #
    def prepare_tables
      table_id = 0
      seen     = {}

      sheets.each do |sheet|
        table_id += sheet.prepare_tables(table_id + 1, seen)
      end
    end

    #
    # Set the metadata rel link.
    #
    def prepare_metadata
      @worksheets.each do |sheet|
        next unless sheet.has_dynamic_functions? || sheet.has_embedded_images?

        @has_metadata = true
        @has_dynamic_functions ||= sheet.has_dynamic_functions?
        @has_embedded_images   ||= sheet.has_embedded_images?
      end
    end

    #
    # Add "cached" data to charts to provide the numCache and strCache data for
    # series and title/axis ranges.
    #
    def add_chart_data # :nodoc:
      worksheets = {}
      seen_ranges = {}

      # Map worksheet names to worksheet objects.
      @worksheets.each { |worksheet| worksheets[worksheet.name] = worksheet }

      # Build an array of the worksheet charts including any combined charts.
      @charts.collect { |chart| [chart, chart.combined] }.flatten.compact
             .each do |chart|
        chart.formula_ids.each do |range, id|
          # Skip if the series has user defined data.
          if chart.formula_data[id]
            seen_ranges[range] = chart.formula_data[id] unless seen_ranges[range]
            next
          # Check to see if the data is already cached locally.
          elsif seen_ranges[range]
            chart.formula_data[id] = seen_ranges[range]
            next
          end

          # Convert the range formula to a sheet name and cell range.
          sheetname, *cells = get_chart_range(range)

          # Skip if we couldn't parse the formula.
          next unless sheetname

          # Handle non-contiguous ranges: (Sheet1!$A$1:$A$2,Sheet1!$A$4:$A$5).
          # We don't try to parse the ranges. We just return an empty list.
          if sheetname =~ /^\([^,]+,/
            chart.formula_data[id] = []
            seen_ranges[range] = []
            next
          end

          # Raise if the name is unknown since it indicates a user error in
          # a chart series formula.
          raise "Unknown worksheet reference '#{sheetname} in range '#{range}' passed to add_series()\n" unless worksheets[sheetname]

          # Add the data to the chart.
          # And store range data locally to avoid lookup if seen agein.
          chart.formula_data[id] =
            seen_ranges[range] = chart_data(worksheets[sheetname], cells)
        end
      end
    end

    def chart_data(worksheet, cells)
      # Get the data from the worksheet table.
      data = worksheet.get_range_data(*cells)

      # Convert shared string indexes to strings.
      data.collect do |token|
        if token.is_a?(Hash)
          string = @shared_strings.string(token[:sst_id])

          # Ignore rich strings for now. Deparse later if necessary.
          if string =~ /^<r>/ && string =~ %r{</r>$}
            ''
          else
            string
          end
        else
          token
        end
      end
    end

    #
    # Sort internal and user defined names in the same order as used by Excel.
    # This may not be strictly necessary but unsorted elements caused a lot of
    # issues in the the Spreadsheet::WriteExcel binary version. Also makes
    # comparison testing easier.
    #
    def sort_defined_names(names) # :nodoc:
      names.sort do |a, b|
        name_a  = normalise_defined_name(a[0])
        name_b  = normalise_defined_name(b[0])
        sheet_a = normalise_sheet_name(a[2])
        sheet_b = normalise_sheet_name(b[2])
        # Primary sort based on the defined name.
        if name_a > name_b
          1
        elsif name_a < name_b
          -1
        elsif sheet_a >= sheet_b  # name_a == name_b
          # Secondary sort based on the sheet name.
          1
        else
          -1
        end
      end
    end

    # Used in the above sort routine to normalise the defined names. Removes any
    # leading '_xmln.' from internal names and lowercases the strings.
    def normalise_defined_name(name) # :nodoc:
      name.sub(/^_xlnm./, '').downcase
    end

    # Used in the above sort routine to normalise the worksheet names for the
    # secondary sort. Removes leading quote and lowercases the strings.
    def normalise_sheet_name(name) # :nodoc:
      name.sub(/^'/, '').downcase
    end

    #
    # Extract the named ranges from the sorted list of defined names. These are
    # used in the App.xml file.
    #
    def extract_named_ranges(defined_names) # :nodoc:
      named_ranges = []

      defined_names.each do |defined_name|
        name, index, range = defined_name

        # Skip autoFilter ranges.
        next if name == '_xlnm._FilterDatabase'

        # We are only interested in defined names with ranges.
        next unless range =~ /^([^!]+)!/

        sheet_name = ::Regexp.last_match(1)

        # Match Print_Area and Print_Titles xlnm types.
        if name =~ /^_xlnm\.(.*)$/
          xlnm_type = ::Regexp.last_match(1)
          name = "#{sheet_name}!#{xlnm_type}"
        elsif index != -1
          name = "#{sheet_name}!#{name}"
        end

        named_ranges << name
      end

      named_ranges
    end

    #
    # Iterate through the worksheets and set up any chart or image drawings.
    #
    def prepare_drawings # :nodoc:
      # Store the image types for any embedded images.
      @embedded_images.each do |image|
        store_image_types(image.type)

        @has_embedded_descriptions = true if ptrue?(image.description)
      end

      prepare_drawings_of_all_sheets

      # Sort the workbook charts references into the order that the were
      # written from the worksheets above.
      @charts = @charts.select { |chart| chart.id != -1 }
                  .sort_by { |chart| chart.id }
    end

    def prepare_drawings_of_all_sheets
      drawing_id       = 0
      chart_ref_id     = 0
      image_ids        = {}
      header_image_ids = {}
      background_ids   = {}

      # The image IDs start from after the embedded images.
      image_ref_id = @embedded_images.size

      @worksheets.each do |sheet|
        drawing_id, chart_ref_id, image_ref_id =
          sheet.prepare_drawings(
            drawing_id, chart_ref_id, image_ref_id, image_ids,
            header_image_ids, background_ids
          )
      end
    end
  end
end
end

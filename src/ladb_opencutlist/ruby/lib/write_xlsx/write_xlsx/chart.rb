# -*- coding: utf-8 -*-
# frozen_string_literal: true

require_relative 'package/xml_writer_simple'
require_relative 'gradient'
require_relative 'chart/legend'
require_relative 'utility'
require_relative 'chart/axis'
require_relative 'chart/caption'
require_relative 'chart/series'

module Ladb::OpenCutList
module Writexlsx
  class Table
    include Writexlsx::Utility

    attr_reader :horizontal, :vertical, :outline, :show_keys, :font

    def initialize(params = {})
      @horizontal = true
      @vertical   = true
      @outline    = true
      @show_keys  = false
      @horizontal = params[:horizontal] if params.has_key?(:horizontal)
      @vertical   = params[:vertical]   if params.has_key?(:vertical)
      @outline    = params[:outline]    if params.has_key?(:outline)
      @show_keys  = params[:show_keys]  if params.has_key?(:show_keys)
      @font       = convert_font_args(params[:font])
    end

    attr_writer :palette

    def write_d_table(writer)
      @writer = writer
      @writer.tag_elements('c:dTable') do
        @writer.empty_tag('c:showHorzBorder', attributes) if ptrue?(horizontal)
        @writer.empty_tag('c:showVertBorder', attributes) if ptrue?(vertical)
        @writer.empty_tag('c:showOutline',    attributes) if ptrue?(outline)
        @writer.empty_tag('c:showKeys',       attributes) if ptrue?(show_keys)
        # Write the table font.
        write_tx_pr(font)                                 if ptrue?(font)
      end
    end

    private

    def attributes
      [['val', 1]]
    end
  end

  class ChartArea
    include Writexlsx::Utility
    include Writexlsx::Gradient

    attr_reader :line, :fill, :pattern, :gradient, :layout

    def initialize(params = {})
      @layout = layout_properties(params[:layout])

      # Allow 'border' as a synonym for 'line'.
      border = params_to_border(params)

      # Set the line properties for the chartarea.
      @line = line_properties(border || params[:line])

      # Set the pattern properties for the series.
      @pattern = pattern_properties(params[:pattern])

      # Set the gradient fill properties for the series.
      @gradient = gradient_properties(params[:gradient])

      # Map deprecated Spreadsheet::WriteExcel fill colour.
      fill = params[:color] ? { color: params[:color] } : params[:fill]
      @fill = fill_properties(fill)

      # Pattern fill overrides solid fill.
      @fill = nil if ptrue?(@pattern)

      # Gradient fill overrides solid and pattern fills.
      if ptrue?(@gradient)
        @pattern = nil
        @fill    = nil
      end
    end

    private

    def params_to_border(params)
      line_weight  = params[:line_weight]

      # Map deprecated Spreadsheet::WriteExcel line_weight.
      border = params[:border]
      border = { width: swe_line_weight(line_weight) } if line_weight

      # Map deprecated Spreadsheet::WriteExcel line_pattern.
      if params[:line_pattern]
        pattern = swe_line_pattern(params[:line_pattern])
        if pattern == 'none'
          border = { none: 1 }
        else
          border[:dash_type] = pattern
        end
      end

      # Map deprecated Spreadsheet::WriteExcel line colour.
      border[:color] = params[:line_color] if params[:line_color]
      border
    end

    #
    # Get the Spreadsheet::WriteExcel line pattern for backward compatibility.
    #
    def swe_line_pattern(val)
      swe_line_pattern_hash[numeric_or_downcase(val)] || 'solid'
    end

    def swe_line_pattern_hash
      {
        0              => 'solid',
        1              => 'dash',
        2              => 'dot',
        3              => 'dash_dot',
        4              => 'long_dash_dot_dot',
        5              => 'none',
        6              => 'solid',
        7              => 'solid',
        8              => 'solid',
        'solid'        => 'solid',
        'dash'         => 'dash',
        'dot'          => 'dot',
        'dash-dot'     => 'dash_dot',
        'dash-dot-dot' => 'long_dash_dot_dot',
        'none'         => 'none',
        'dark-gray'    => 'solid',
        'medium-gray'  => 'solid',
        'light-gray'   => 'solid'
      }
    end

    #
    # Get the Spreadsheet::WriteExcel line weight for backward compatibility.
    #
    def swe_line_weight(val)
      swe_line_weight_hash[numeric_or_downcase(val)] || 1
    end

    def swe_line_weight_hash
      {
        1          => 0.25,
        2          => 1,
        3          => 2,
        4          => 3,
        'hairline' => 0.25,
        'narrow'   => 1,
        'medium'   => 2,
        'wide'     => 3
      }
    end

    def numeric_or_downcase(val)
      val.respond_to?(:coerce) ? val : val.downcase
    end
  end

  class Chart
    include Writexlsx::Utility
    include Writexlsx::Gradient

    attr_accessor :id, :name                                         # :nodoc:
    attr_writer :index, :palette, :protection                        # :nodoc:
    attr_reader :embedded, :formula_ids, :formula_data               # :nodoc:
    attr_reader :x_scale, :y_scale, :x_offset, :y_offset             # :nodoc:
    attr_reader :width, :height                                      # :nodoc:
    attr_reader :label_positions, :label_position_default, :combined # :nodoc:
    attr_writer :date_category, :already_inserted                    # :nodoc:
    attr_writer :series_index                                        # :nodoc:
    attr_writer :writer                                              # :nodoc:
    attr_reader :x2_axis, :y2_axis, :axis2_ids                       # :nodoc:

    #
    # Factory method for returning chart objects based on their class type.
    #
    def self.factory(current_subclass, subtype = nil) # :nodoc:
      case current_subclass.downcase.capitalize
      when 'Area'
        require_relative 'chart/area'
        Chart::Area.new(subtype)
      when 'Bar'
        require_relative 'chart/bar'
        Chart::Bar.new(subtype)
      when 'Column'
        require_relative 'chart/column'
        Chart::Column.new(subtype)
      when 'Doughnut'
        require_relative 'chart/doughnut'
        Chart::Doughnut.new(subtype)
      when 'Line'
        require_relative 'chart/line'
        Chart::Line.new(subtype)
      when 'Pie'
        require_relative 'chart/pie'
        Chart::Pie.new(subtype)
      when 'Radar'
        require_relative 'chart/radar'
        Chart::Radar.new(subtype)
      when 'Scatter'
        require_relative 'chart/scatter'
        Chart::Scatter.new(subtype)
      when 'Stock'
        require_relative 'chart/stock'
        Chart::Stock.new(subtype)
      end
    end

    def initialize(subtype)   # :nodoc:
      @writer = Package::XMLWriterSimple.new

      @subtype           = subtype
      @sheet_type        = 0x0200
      @series            = []
      @embedded          = false
      @id                = -1
      @series_index      = 0
      @style_id          = 2
      @formula_ids       = {}
      @formula_data      = []
      @protection        = 0
      @chartarea         = ChartArea.new
      @plotarea          = ChartArea.new
      @title             = Caption.new(self)
      @name              = ''
      @table             = nil
      set_default_properties
      @combined          = nil
      @is_secondary      = false
    end

    def set_xml_writer(filename)   # :nodoc:
      @writer.set_xml_writer(filename)
    end

    #
    # Assemble and write the XML file.
    #
    def assemble_xml_file   # :nodoc:
      write_xml_declaration do
        # Write the c:chartSpace element.
        write_chart_space do
          # Write the c:lang element.
          write_lang
          # Write the c:style element.
          write_style
          # Write the c:protection element.
          write_protection
          # Write the c:chart element.
          write_chart
          # Write the c:spPr element for the chartarea formatting.
          write_sp_pr(@chartarea)
          # Write the c:printSettings element.
          write_print_settings if @embedded
        end
      end
    end

    #
    # Add a series and it's properties to a chart.
    #
    def add_series(params)
      # Check that the required input has been specified.
      raise "Must specify ':values' in add_series" unless params.has_key?(:values)

      raise "Must specify ':categories' in add_series for this chart type" if @requires_category != 0 && !params.has_key?(:categories)

      raise "The maximum number of series that can be added to an Excel Chart is 255." if @series.size == 255

      @series << Series.new(self, params)

      # Set the secondary axis properties.
      x2_axis = params[:x2_axis]
      y2_axis = params[:y2_axis]

      # Store secondary status for combined charts.
      @is_secondary = true if ptrue?(x2_axis) || ptrue?(y2_axis)

      # Set the gap and overlap for Bar/Column charts.
      if params[:gap]
        if ptrue?(y2_axis)
          @series_gap_2 = params[:gap]
        else
          @series_gap_1 = params[:gap]
        end
      end

      # Set the overlap for Bar/Column charts.
      if params[:overlap]
        if ptrue?(y2_axis)
          @series_overlap_2 = params[:overlap]
        else
          @series_overlap_1 = params[:overlap]
        end
      end
    end

    #
    # Set the properties of the x-axis.
    #
    def set_x_axis(params = {})
      @date_category = true if ptrue?(params[:date_axis])
      @x_axis.merge_with_hash(params)
    end

    #
    # Set the properties of the Y-axis.
    #
    # The set_y_axis() method is used to set properties of the Y axis.
    # The properties that can be set are the same as for set_x_axis,
    #
    def set_y_axis(params = {})
      @date_category = true if ptrue?(params[:date_axis])
      @y_axis.merge_with_hash(params)
    end

    #
    # Set the properties of the secondary X-axis.
    #
    def set_x2_axis(params = {})
      @date_category = true if ptrue?(params[:date_axis])
      @x2_axis.merge_with_hash(params)
    end

    #
    # Set the properties of the secondary Y-axis.
    #
    def set_y2_axis(params = {})
      @date_category = true if ptrue?(params[:date_axis])
      @y2_axis.merge_with_hash(params)
    end

    #
    # Set the properties of the chart title.
    #
    def set_title(params)
      @title.merge_with_hash(params)
    end

    #
    # Set the properties of the chart legend.
    #
    def set_legend(params)
      # Convert the user default properties to internal properties.
      legend_properties(params)
    end

    #
    # Set the properties of the chart plotarea.
    #
    def set_plotarea(params)
      # Convert the user defined properties to internal properties.
      @plotarea = ChartArea.new(params)
    end

    #
    # Set the properties of the chart chartarea.
    #
    def set_chartarea(params)
      # Convert the user defined properties to internal properties.
      @chartarea = ChartArea.new(params)
    end

    #
    # Set on of the 42 built-in Excel chart styles. The default style is 2.
    #
    def set_style(style_id = 2)
      style_id = 2 if style_id < 1 || style_id > 48
      @style_id = style_id
    end

    #
    # Set the option for displaying blank data in a chart. The default is 'gap'.
    #
    def show_blanks_as(option)
      return unless option

      raise "Unknown show_blanks_as() option '#{option}'\n" unless %i[gap zero span].include?(option.to_sym)

      @show_blanks = option
    end

    #
    # Display data in hidden rows or columns on the chart.
    #
    def show_hidden_data
      @show_hidden_data = true
    end

    #
    # Set dimensions for scale for the chart.
    #
    def set_size(params = {})
      @width    = params[:width]    if params[:width]
      @height   = params[:height]   if params[:height]
      @x_scale  = params[:x_scale]  if params[:x_scale]
      @y_scale  = params[:y_scale]  if params[:y_scale]
      @x_offset = params[:x_offset] if params[:x_offset]
      @y_offset = params[:y_offset] if params[:y_offset]
    end

    # Backward compatibility with poorly chosen method name.
    alias size set_size

    #
    # The set_table method adds a data table below the horizontal axis with the
    # data used to plot the chart.
    #
    def set_table(params = {})
      @table = Table.new(params)
      @table.palette = @palette
    end

    #
    # Set properties for the chart up-down bars.
    #
    def set_up_down_bars(params = {})
      # Map border to line.
      %i[up down].each do |up_down|
        if params[up_down]
          params[up_down][:line] = params[up_down][:border] if params[up_down][:border]
        else
          params[up_down] = {}
        end
      end

      # Set the up and down bar properties.
      @up_down_bars = {
        _up:   Chartline.new(params[:up]),
        _down: Chartline.new(params[:down])
      }
    end

    #
    # Set properties for the chart drop lines.
    #
    def set_drop_lines(params = {})
      @drop_lines = Chartline.new(params)
    end

    #
    # Set properties for the chart high-low lines.
    #
    def set_high_low_lines(params = {})
      @hi_low_lines = Chartline.new(params)
    end

    #
    # Add another chart to create a combined chart.
    #
    def combine(chart)
      @combined = chart
    end

    #
    # Setup the default configuration data for an embedded chart.
    #
    def set_embedded_config_data
      @embedded = true
    end

    #
    # Write the <c:barChart> element.
    #
    def write_bar_chart(params)   # :nodoc:
      series = if ptrue?(params[:primary_axes])
                 get_primary_axes_series
               else
                 get_secondary_axes_series
               end
      return if series.empty?

      subtype = @subtype
      subtype = 'percentStacked' if subtype == 'percent_stacked'

      # Set a default overlap for stacked charts.
      @series_overlap_1 = 100 if @subtype =~ (/stacked/) && !@series_overlap_1

      @writer.tag_elements('c:barChart') do
        # Write the c:barDir element.
        write_bar_dir
        # Write the c:grouping element.
        write_grouping(subtype)
        # Write the c:ser elements.
        series.each { |s| write_ser(s) }

        # write the c:marker element.
        write_marker_value

        if ptrue?(params[:primary_axes])
          # Write the c:gapWidth element.
          write_gap_width(@series_gap_1)
          # Write the c:overlap element.
          write_overlap(@series_overlap_1)
        else
          # Write the c:gapWidth element.
          write_gap_width(@series_gap_2)
          # Write the c:overlap element.
          write_overlap(@series_overlap_2)
        end

        # write the c:overlap element.
        write_overlap(@series_overlap)

        # Write the c:axId elements
        write_axis_ids(params)
      end
    end

    #
    # Switch name and name_formula parameters if required.
    #
    def process_names(name = nil, name_formula = nil) # :nodoc:
      # Name looks like a formula, use it to set name_formula.
      if name.respond_to?(:to_ary)
        cell = xl_rowcol_to_cell(name[1], name[2], 1, 1)
        name_formula = "#{quote_sheetname(name[0])}!#{cell}"
        name = ''
      elsif name && name =~ /^=[^!]+!\$/
        name_formula = name
        name         = ''
      end

      [name, name_formula]
    end

    #
    # Assign an id to a each unique series formula or title/axis formula. Repeated
    # formulas such as for categories get the same id. If the series or title
    # has user specified data associated with it then that is also stored. This
    # data is used to populate cached Excel data when creating a chart.
    # If there is no user defined data then it will be populated by the parent
    # workbook in Workbook::_add_chart_data
    #
    def data_id(full_formula, data) # :nodoc:
      return unless full_formula

      # Strip the leading '=' from the formula.
      formula = full_formula.sub(/^=/, '')

      # Store the data id in a hash keyed by the formula and store the data
      # in a separate array with the same id.
      if @formula_ids.has_key?(formula)
        # Formula already seen. Return existing id.
        id = @formula_ids[formula]
        # Store user defined data if it isn't already there.
        @formula_data[id] ||= data
      else
        # Haven't seen this formula before.
        id = @formula_ids[formula] = @formula_data.size
        @formula_data << data
      end

      id
    end

    def already_inserted?
      @already_inserted
    end

    def is_secondary?
      @is_secondary
    end

    #
    # Set the option for displaying #N/A as an empty cell in a chart.
    #
    def show_na_as_empty_cell
      @show_na_as_empty = true
    end

    private

    def axis_setup
      @axis_ids          = []
      @axis2_ids         = []
      @cat_has_num_fmt   = false
      @requires_category = 0
      @cat_axis_position = 'b'
      @val_axis_position = 'l'
      @horiz_cat_axis    = 0
      @horiz_val_axis    = 1
      @x_axis            = Axis.new(self)
      @y_axis            = Axis.new(self)
      @x2_axis           = Axis.new(self)
      @y2_axis           = Axis.new(self)
    end

    def display_setup
      @orientation       = 0x0
      @width             = 480
      @height            = 288
      @x_scale           = 1
      @y_scale           = 1
      @x_offset          = 0
      @y_offset          = 0
      @legend            = Legend.new
      @smooth_allowed    = 0
      @cross_between     = 'between'
      @date_category     = false
      @show_blanks       = 'gap'
      @show_na_as_empty  = false
      @show_hidden_data  = false
      @show_crosses      = true
    end

    #
    # retun primary/secondary series by :primary_axes flag
    #
    def axes_series(params)
      if params[:primary_axes] == 0
        secondary_axes_series
      else
        primary_axes_series
      end
    end

    #
    # Find the overall type of the data associated with a series.
    #
    # TODO. Need to handle date type.
    #
    def get_data_type(data) # :nodoc:
      # Check for no data in the series.
      return 'none' unless data
      return 'none' if data.empty?
      return 'multi_str' if data.first.is_a?(Array)

      # If the token isn't a number assume it is a string.
      data.each do |token|
        next unless token
        return 'str' unless token.is_a?(Numeric)
      end

      # The series data was all numeric.
      'num'
    end

    #
    # Returns series which use the primary axes.
    #
    def get_primary_axes_series
      @series.reject { |s| s.y2_axis }
    end
    alias primary_axes_series get_primary_axes_series

    #
    # Returns series which use the secondary axes.
    #
    def get_secondary_axes_series
      @series.select { |s| s.y2_axis }
    end
    alias secondary_axes_series get_secondary_axes_series

    #
    # Add a unique ids for primary or secondary axis.
    #
    def add_axis_ids(params) # :nodoc:
      if ptrue?(params[:primary_axes])
        @axis_ids  += ids
      else
        @axis2_ids += ids
      end
    end

    def ids
      chart_id   = 5001 + @id
      axis_count = 1 + @axis2_ids.size + @axis_ids.size

      id1 = sprintf('%04d%04d', chart_id, axis_count)
      id2 = sprintf('%04d%04d', chart_id, axis_count + 1)

      [id1, id2]
    end

    #
    # Setup the default properties for a chart.
    #
    def set_default_properties # :nodoc:
      display_setup
      axis_setup
      set_axis_defaults

      set_x_axis
      set_y_axis

      set_x2_axis
      set_y2_axis
    end

    def set_axis_defaults
      @x_axis.defaults  = x_axis_defaults
      @y_axis.defaults  = y_axis_defaults
      @x2_axis.defaults = x2_axis_defaults
      @y2_axis.defaults = y2_axis_defaults
    end

    def x_axis_defaults
      {
        num_format:      'General',
        major_gridlines: { visible: 0 }
      }
    end

    def y_axis_defaults
      {
        num_format:      'General',
        major_gridlines: { visible: 1 }
      }
    end

    def x2_axis_defaults
      {
        num_format:     'General',
        label_position: 'none',
        crossing:       'max',
        visible:        0
      }
    end

    def y2_axis_defaults
      {
        num_format:      'General',
        major_gridlines: { visible: 0 },
        position:        'right',
        visible:         1
      }
    end

    #
    # Write the <c:chartSpace> element.
    #
    def write_chart_space(&block) # :nodoc:
      @writer.tag_elements('c:chartSpace', chart_space_attributes, &block)
    end

    # for <c:chartSpace> element.
    def chart_space_attributes # :nodoc:
      schema  = 'http://schemas.openxmlformats.org/'
      [
        ['xmlns:c', "#{schema}drawingml/2006/chart"],
        ['xmlns:a', "#{schema}drawingml/2006/main"],
        ['xmlns:r', "#{schema}officeDocument/2006/relationships"]
      ]
    end

    #
    # Write the <c:lang> element.
    #
    def write_lang # :nodoc:
      @writer.empty_tag('c:lang', [%w[val en-US]])
    end

    #
    # Write the <c:style> element.
    #
    def write_style # :nodoc:
      return if @style_id == 2

      @writer.empty_tag('c:style', [['val', @style_id]])
    end

    #
    # Write the <c:chart> element.
    #
    def write_chart # :nodoc:
      @writer.tag_elements('c:chart') do
        # Write the chart title elements.
        if @title.none
          # Turn off the title.
          write_auto_title_deleted
        elsif @title.formula
          write_title_formula(@title, nil, nil, @title.layout, @title.overlay)
        elsif @title.name
          write_title_rich(@title, nil, @title.name_font, @title.layout, @title.overlay)
        end

        # Write the c:plotArea element.
        write_plot_area
        # Write the c:legend element.
        write_legend
        # Write the c:plotVisOnly element.
        write_plot_vis_only

        # Write the c:dispBlanksAs element.
        write_disp_blanks_as

        # Write the c:extLst element.
        write_ext_lst_display_na if @show_na_as_empty
      end
    end

    #
    # Write the <c:dispBlanksAs> element.
    #
    def write_disp_blanks_as
      return if @show_blanks == 'gap'

      @writer.empty_tag('c:dispBlanksAs', [['val', @show_blanks]])
    end

    #
    # Write the <c:plotArea> element.
    #
    def write_plot_area   # :nodoc:
      second_chart = @combined
      @writer.tag_elements('c:plotArea') do
        # Write the c:layout element.
        write_layout(@plotarea.layout, 'plot')
        # Write the subclass chart type elements for primary and secondary axes.
        write_chart_type(primary_axes: 1)
        write_chart_type(primary_axes: 0)

        # Configure a combined chart if present.
        if second_chart

          # Secondary axis has unique id otherwise use same as primary.
          second_chart.id = if second_chart.is_secondary?
                              1000 + @id
                            else
                              @id
                            end

          # Share the same writer for writing.
          second_chart.writer = @writer

          # Share series index with primary chart.
          second_chart.series_index = @series_index

          # Write the subclass chart type elements for combined chart.
          second_chart.write_chart_type(primary_axes: 1)
          second_chart.write_chart_type(primary_axes: 0)
        end

        # Write the category and value elements for the primary axes.
        params = {
          x_axis:   @x_axis,
          y_axis:   @y_axis,
          axis_ids: @axis_ids
        }

        if @date_category
          write_date_axis(params)
        else
          write_cat_axis(params)
        end

        write_val_axis(@x_axis, @y_axis, @axis_ids)

        # Write the category and value elements for the secondary axes.
        params = {
          x_axis:   @x2_axis,
          y_axis:   @y2_axis,
          axis_ids: @axis2_ids
        }

        write_val_axis(@x2_axis, @y2_axis, @axis2_ids)

        # Write the secondary axis for the secondary chart.
        if second_chart && second_chart.is_secondary?

          params = {
            x_axis:   second_chart.x2_axis,
            y_axis:   second_chart.y2_axis,
            axis_ids: second_chart.axis2_ids
          }

          second_chart.write_val_axis(
            second_chart.x2_axis,
            second_chart.y2_axis,
            second_chart.axis2_ids
          )
        end

        if @date_category
          write_date_axis(params)
        else
          write_cat_axis(params)
        end

        # Write the c:dTable element.
        write_d_table

        # Write the c:spPr element for the plotarea formatting.
        write_sp_pr(@plotarea)
      end
    end

    #
    # Write the <c:layout> element.
    #
    def write_layout(layout = nil, type = nil) # :nodoc:
      tag = 'c:layout'

      if layout
        @writer.tag_elements(tag)  { write_manual_layout(layout, type) }
      else
        @writer.empty_tag(tag)
      end
    end

    #
    # Write the <c:manualLayout> element.
    #
    def write_manual_layout(layout, type)
      @writer.tag_elements('c:manualLayout') do
        # Plotarea has a layoutTarget element.
        @writer.empty_tag('c:layoutTarget', [%w[val inner]]) if type == 'plot'

        # Set the x, y positions.
        @writer.empty_tag('c:xMode', [%w[val edge]])
        @writer.empty_tag('c:yMode', [%w[val edge]])
        @writer.empty_tag('c:x',     [['val', layout[:x]]])
        @writer.empty_tag('c:y',     [['val', layout[:y]]])

        # For plotarea and legend set the width and height.
        if type != 'text'
          @writer.empty_tag('c:w', [['val', layout[:width]]])
          @writer.empty_tag('c:h', [['val', layout[:height]]])
        end
      end
    end

    #
    # Write the chart type element. This method should be overridden by the
    # subclasses.
    #
    def write_chart_type; end

    #
    # Write the <c:grouping> element.
    #
    def write_grouping(val) # :nodoc:
      @writer.empty_tag('c:grouping', [['val', val]])
    end

    #
    # Write the series elements.
    #
    def write_series(series) # :nodoc:
      write_ser(series)
    end

    #
    # Write the <c:ser> element.
    #
    def write_ser(series) # :nodoc:
      @writer.tag_elements('c:ser') do
        write_ser_base(series) do
          write_c_invert_if_negative(series.invert_if_negative)
        end
        # Write the c:cat element.
        write_cat(series)
        # Write the c:val element.
        write_val(series)
        # Write the c:smooth element.
        write_c_smooth(series.smooth) if ptrue?(@smooth_allowed)
        # Write the c:extLst element.
        write_ext_lst_inverted_fill(series.inverted_color) if series.inverted_color
      end
      @series_index += 1
    end

    def write_ext_lst_inverted_fill(color)
      uri = '{6F2FDCE9-48DA-4B69-8628-5D25D57E5C99}'
      xmlns_c_14 =
        'http://schemas.microsoft.com/office/drawing/2007/8/2/chart'

      attributes_1 = [
        ['uri', uri],
        ['xmlns:c14', xmlns_c_14]
      ]

      attributes_2 = [
        ['xmlns:c14', xmlns_c_14]
      ]

      @writer.tag_elements('c:extLst') do
        @writer.tag_elements('c:ext', attributes_1) do
          @writer.tag_elements('c14:invertSolidFillFmt') do
            @writer.tag_elements('c14:spPr', attributes_2) do
              write_a_solid_fill(color: color)
            end
          end
        end
      end
    end

    #
    # Write the <c:extLst> element for the display N/A as empty cell option.
    #
    def write_ext_lst_display_na
      uri        = '{56B9EC1D-385E-4148-901F-78D8002777C0}'
      xmlns_c_16 = 'http://schemas.microsoft.com/office/drawing/2017/03/chart'

      attributes1 = [
        ['uri', uri],
        ['xmlns:c16r3', xmlns_c_16]
      ]

      attributes2 = [
        ['val', 1]
      ]

      @writer.tag_elements('c:extLst') do
        @writer.tag_elements('c:ext', attributes1) do
          @writer.tag_elements('c16r3:dataDisplayOptions16') do
            @writer.empty_tag('c16r3:dispNaAsBlank', attributes2)
          end
        end
      end
    end

    def write_ser_base(series)
      # Write the c:idx element.
      write_idx(@series_index)
      # Write the c:order element.
      write_order(@series_index)
      # Write the series name.
      write_series_name(series)
      # Write the c:spPr element.
      write_sp_pr(series)
      # Write the c:marker element.
      write_marker(series.marker)

      yield if block_given?

      # Write the c:dPt element.
      write_d_pt(series.points)
      # Write the c:dLbls element.
      write_d_lbls(series.labels)
      # Write the c:trendline element.
      write_trendline(series.trendline)
      # Write the c:errBars element.
      write_error_bars(series.error_bars)
    end

    #
    # Write the <c:idx> element.
    #
    def write_idx(val) # :nodoc:
      @writer.empty_tag('c:idx', [['val', val]])
    end

    #
    # Write the <c:order> element.
    #
    def write_order(val) # :nodoc:
      @writer.empty_tag('c:order', [['val', val]])
    end

    #
    # Write the series name.
    #
    def write_series_name(series) # :nodoc:
      if series.name_formula
        write_tx_formula(series.name_formula, series.name_id)
      elsif series.name
        write_tx_value(series.name)
      end
    end

    #
    # Write the <c:cat> element.
    #
    def write_cat(series) # :nodoc:
      formula = series.categories
      data_id = series.cat_data_id

      data = @formula_data[data_id] if data_id

      # Ignore <c:cat> elements for charts without category values.
      return unless formula

      @writer.tag_elements('c:cat') do
        # Check the type of cached data.
        type = get_data_type(data)
        if type == 'str'
          @cat_has_num_fmt = false
          # Write the c:strRef element.
          write_str_ref(formula, data, type)
        elsif type == 'multi_str'
          @cat_has_num_fmt = false
          # Write the c:multiLvLStrRef element.
          write_multi_lvl_str_ref(formula, data)
        else
          @cat_has_num_fmt = true
          # Write the c:numRef element.
          write_num_ref(formula, data, type)
        end
      end
    end

    #
    # Write the <c:val> element.
    #
    def write_val(series) # :nodoc:
      write_val_base(series.values, series.val_data_id, 'c:val')
    end

    def write_val_base(formula, data_id, tag) # :nodoc:
      data = @formula_data[data_id]

      @writer.tag_elements(tag) do
        # Unlike Cat axes data should only be numeric.

        # Write the c:numRef element.
        write_num_ref(formula, data, 'num')
      end
    end

    #
    # Write the <c:numRef> or <c:strRef> element.
    #
    def write_num_or_str_ref(tag, formula, data, type) # :nodoc:
      @writer.tag_elements(tag) do
        # Write the c:f element.
        write_series_formula(formula)
        if type == 'num'
          # Write the c:numCache element.
          write_num_cache(data)
        elsif type == 'str'
          # Write the c:strCache element.
          write_str_cache(data)
        end
      end
    end

    #
    # Write the <c:numRef> element.
    #
    def write_num_ref(formula, data, type) # :nodoc:
      write_num_or_str_ref('c:numRef', formula, data, type)
    end

    #
    # Write the <c:strRef> element.
    #
    def write_str_ref(formula, data, type) # :nodoc:
      write_num_or_str_ref('c:strRef', formula, data, type)
    end

    #
    # Write the <c:multiLvLStrRef> element.
    #
    def write_multi_lvl_str_ref(formula, data)
      return if data.empty?

      @writer.tag_elements('c:multiLvlStrRef') do
        # Write the c:f element.
        write_series_formula(formula)

        @writer.tag_elements('c:multiLvlStrCache') do
          # Write the c:ptCount element.
          write_pt_count(data.last.size)

          # Write the data arrays in reverse order.
          data.reverse.each do |arr|
            @writer.tag_elements('c:lvl') do
              # Write the c:pt element.
              arr.each_with_index { |a, i| write_pt(i, a) }
            end
          end
        end
      end
    end

    #
    # Write the <c:numLit> element for literal number list elements.
    #
    def write_num_lit(data)
      write_num_base('c:numLit', data)
    end

    #
    # Write the <c:f> element.
    #
    def write_series_formula(formula) # :nodoc:
      # Strip the leading '=' from the formula.
      formula = formula.sub(/^=/, '')

      @writer.data_element('c:f', formula)
    end

    #
    # Write the <c:axId> elements for the primary or secondary axes.
    #
    def write_axis_ids(params)
      # Generate the axis ids.
      add_axis_ids(params)

      if params[:primary_axes] == 0
        # Write the axis ids for the secondary axes.
        write_axis_id(@axis2_ids[0])
        write_axis_id(@axis2_ids[1])
      else
        # Write the axis ids for the primary axes.
        write_axis_id(@axis_ids[0])
        write_axis_id(@axis_ids[1])
      end
    end

    #
    # Write the <c:axId> element.
    #
    def write_axis_id(val) # :nodoc:
      @writer.empty_tag('c:axId', [['val', val]])
    end

    #
    # Write the <c:catAx> element. Usually the X axis.
    #
    def write_cat_axis(params) # :nodoc:
      x_axis   = params[:x_axis]
      y_axis   = params[:y_axis]
      axis_ids = params[:axis_ids]

      # if there are no axis_ids then we don't need to write this element
      return unless axis_ids
      return if axis_ids.empty?

      position  = @cat_axis_position
      is_y_axis = @horiz_cat_axis

      # Overwrite the default axis position with a user supplied value.
      position = x_axis.position || position

      @writer.tag_elements('c:catAx') do
        write_axis_id(axis_ids[0])
        # Write the c:scaling element.
        write_scaling(x_axis.reverse)

        write_delete(1) unless ptrue?(x_axis.visible)

        # Write the c:axPos element.
        write_axis_pos(position, y_axis.reverse)

        # Write the c:majorGridlines element.
        write_major_gridlines(x_axis.major_gridlines)

        # Write the c:minorGridlines element.
        write_minor_gridlines(x_axis.minor_gridlines)

        # Write the axis title elements.
        if x_axis.formula
          write_title_formula(x_axis, is_y_axis, @x_axis, x_axis.layout)
        elsif x_axis.name
          write_title_rich(x_axis, is_y_axis, x_axis.name_font, x_axis.layout)
        end

        # Write the c:numFmt element.
        write_cat_number_format(x_axis)

        # Write the c:majorTickMark element.
        write_major_tick_mark(x_axis.major_tick_mark)

        # Write the c:minorTickMark element.
        write_minor_tick_mark(x_axis.minor_tick_mark)

        # Write the c:tickLblPos element.
        write_tick_label_pos(x_axis.label_position)

        # Write the c:spPr element for the axis line.
        write_sp_pr(x_axis)

        # Write the axis font elements.
        write_axis_font(x_axis.num_font)

        # Write the c:crossAx element.
        write_cross_axis(axis_ids[1])

        write_crossing(y_axis.crossing) if @show_crosses || ptrue?(x_axis.visible)
        # Write the c:auto element.
        write_auto(1) unless x_axis.text_axis
        # Write the c:labelAlign element.
        write_label_align(x_axis.label_align)
        # Write the c:labelOffset element.
        write_label_offset(100)
        # Write the c:tickLblSkip element.
        write_tick_lbl_skip(x_axis.interval_unit)
        # Write the c:tickMarkSkip element.
        write_tick_mark_skip(x_axis.interval_tick)
      end
    end

    #
    # Write the <c:valAx> element. Usually the Y axis.
    #
    def write_val_axis(x_axis, y_axis, axis_ids, position = nil)
      return unless axis_ids && !axis_ids.empty?

      write_val_axis_base(
        x_axis, y_axis,
        axis_ids[0],
        axis_ids[1],
        y_axis.position || position || @val_axis_position
      )
    end
    public :write_val_axis

    def write_val_axis_base(x_axis, y_axis, axis_ids_0, axis_ids_1, position)  # :nodoc:
      @writer.tag_elements('c:valAx') do
        write_axis_id(axis_ids_1)

        # Write the c:scaling element.
        write_scaling_with_param(y_axis)

        write_delete(1) unless ptrue?(y_axis.visible)

        # Write the c:axPos element.
        write_axis_pos(position, x_axis.reverse)

        # Write the c:majorGridlines element.
        write_major_gridlines(y_axis.major_gridlines)

        # Write the c:minorGridlines element.
        write_minor_gridlines(y_axis.minor_gridlines)

        # Write the axis title elements.
        if y_axis.formula
          write_title_formula(y_axis, @horiz_val_axis, nil, y_axis.layout)
        elsif y_axis.name
          write_title_rich(y_axis, @horiz_val_axis, y_axis.name_font, y_axis.layout)
        end

        # Write the c:numberFormat element.
        write_number_format(y_axis)

        # Write the c:majorTickMark element.
        write_major_tick_mark(y_axis.major_tick_mark)

        # Write the c:minorTickMark element.
        write_minor_tick_mark(y_axis.minor_tick_mark)

        # Write the c:tickLblPos element.
        write_tick_label_pos(y_axis.label_position)

        # Write the c:spPr element for the axis line.
        write_sp_pr(y_axis)

        # Write the axis font elements.
        write_axis_font(y_axis.num_font)

        # Write the c:crossAx element.
        write_cross_axis(axis_ids_0)

        write_crossing(x_axis.crossing)

        # Write the c:crossBetween element.
        write_cross_between(x_axis.position_axis)

        # Write the c:majorUnit element.
        write_c_major_unit(y_axis.major_unit)

        # Write the c:minorUnit element.
        write_c_minor_unit(y_axis.minor_unit)

        # Write the c:dispUnits element.
        write_disp_units(y_axis.display_units, y_axis.display_units_visible)
      end
    end

    #
    # Write the <c:dateAx> element. Usually the X axis.
    #
    def write_date_axis(params)  # :nodoc:
      x_axis    = params[:x_axis]
      y_axis    = params[:y_axis]
      axis_ids  = params[:axis_ids]

      return unless axis_ids && !axis_ids.empty?

      position  = @cat_axis_position

      # Overwrite the default axis position with a user supplied value.
      position = x_axis.position || position

      @writer.tag_elements('c:dateAx') do
        write_axis_id(axis_ids[0])
        # Write the c:scaling element.
        write_scaling_with_param(x_axis)

        write_delete(1) unless ptrue?(x_axis.visible)

        # Write the c:axPos element.
        write_axis_pos(position, y_axis.reverse)

        # Write the c:majorGridlines element.
        write_major_gridlines(x_axis.major_gridlines)

        # Write the c:minorGridlines element.
        write_minor_gridlines(x_axis.minor_gridlines)

        # Write the axis title elements.
        if x_axis.formula
          write_title_formula(x_axis, nil, nil, x_axis.layout)
        elsif x_axis.name
          write_title_rich(x_axis, nil, x_axis.name_font, x_axis.layout)
        end
        # Write the c:numFmt element.
        write_number_format(x_axis)
        # Write the c:majorTickMark element.
        write_major_tick_mark(x_axis.major_tick_mark)

        # Write the c:tickLblPos element.
        write_tick_label_pos(x_axis.label_position)
        # Write the c:spPr element for the axis line.
        write_sp_pr(x_axis)
        # Write the font elements.
        write_axis_font(x_axis.num_font)
        # Write the c:crossAx element.
        write_cross_axis(axis_ids[1])

        write_crossing(y_axis.crossing) if @show_crosses || ptrue?(x_axis.visible)

        # Write the c:auto element.
        write_auto(1)
        # Write the c:labelOffset element.
        write_label_offset(100)
        # Write the c:tickLblSkip element.
        write_tick_lbl_skip(x_axis.interval_unit)
        # Write the c:tickMarkSkip element.
        write_tick_mark_skip(x_axis.interval_tick)
        # Write the c:majorUnit element.
        write_c_major_unit(x_axis.major_unit)
        # Write the c:majorTimeUnit element.
        write_c_major_time_unit(x_axis.major_unit_type) if x_axis.major_unit
        # Write the c:minorUnit element.
        write_c_minor_unit(x_axis.minor_unit)
        # Write the c:minorTimeUnit element.
        write_c_minor_time_unit(x_axis.minor_unit_type) if x_axis.minor_unit
      end
    end

    def write_crossing(crossing)
      # Note, the category crossing comes from the value axis.
      if [nil, 'max', 'min'].include?(crossing)
        # Write the c:crosses element.
        write_crosses(crossing)
      else
        # Write the c:crossesAt element.
        write_c_crosses_at(crossing)
      end
    end

    def write_scaling_with_param(param)
      write_scaling(
        param.reverse,
        param.min,
        param.max,
        param.log_base
      )
    end

    #
    # Write the <c:scaling> element.
    #
    def write_scaling(reverse, min = nil, max = nil, log_base = nil) # :nodoc:
      @writer.tag_elements('c:scaling') do
        # Write the c:logBase element.
        write_c_log_base(log_base)
        # Write the c:orientation element.
        write_orientation(reverse)
        # Write the c:max element.
        write_c_max(max)
        # Write the c:min element.
        write_c_min(min)
      end
    end

    #
    # Write the <c:logBase> element.
    #
    def write_c_log_base(val) # :nodoc:
      return unless ptrue?(val)

      @writer.empty_tag('c:logBase', [['val', val]])
    end

    #
    # Write the <c:orientation> element.
    #
    def write_orientation(reverse = nil) # :nodoc:
      val = ptrue?(reverse) ? 'maxMin' : 'minMax'

      @writer.empty_tag('c:orientation', [['val', val]])
    end

    #
    # Write the <c:max> element.
    #
    def write_c_max(max = nil) # :nodoc:
      @writer.empty_tag('c:max', [['val', max]]) if max
    end

    #
    # Write the <c:min> element.
    #
    def write_c_min(min = nil) # :nodoc:
      @writer.empty_tag('c:min', [['val', min]]) if min
    end

    #
    # Write the <c:axPos> element.
    #
    def write_axis_pos(val, reverse = false) # :nodoc:
      if reverse
        val = 'r' if val == 'l'
        val = 't' if val == 'b'
      end

      @writer.empty_tag('c:axPos', [['val', val]])
    end

    #
    # Write the <c:numberFormat> element. Note: It is assumed that if a user
    # defined number format is supplied (i.e., non-default) then the sourceLinked
    # attribute is 0. The user can override this if required.
    #

    def write_number_format(axis) # :nodoc:
      axis.write_number_format(@writer)
    end

    #
    # Write the <c:numFmt> element. Special case handler for category axes which
    # don't always have a number format.
    #
    def write_cat_number_format(axis)
      axis.write_cat_number_format(@writer, @cat_has_num_fmt)
    end

    #
    # Write the <c:numberFormat> element for data labels.
    #
    def write_data_label_number_format(format_code)
      source_linked = 0

      attributes = [
        ['formatCode',   format_code],
        ['sourceLinked', source_linked]
      ]

      @writer.empty_tag('c:numFmt', attributes)
    end

    #
    # Write the <c:majorTickMark> element.
    #
    def write_major_tick_mark(val)
      return unless ptrue?(val)

      @writer.empty_tag('c:majorTickMark', [['val', val]])
    end

    #
    # Write the <c:minorTickMark> element.
    #
    def write_minor_tick_mark(val)
      return unless ptrue?(val)

      @writer.empty_tag('c:minorTickMark', [['val', val]])
    end

    #
    # Write the <c:tickLblPos> element.
    #
    def write_tick_label_pos(val) # :nodoc:
      val ||= 'nextTo'
      val = 'nextTo' if val == 'next_to'

      @writer.empty_tag('c:tickLblPos', [['val', val]])
    end

    #
    # Write the <c:crossAx> element.
    #
    def write_cross_axis(val = 'autoZero') # :nodoc:
      @writer.empty_tag('c:crossAx', [['val', val]])
    end

    #
    # Write the <c:crosses> element.
    #
    def write_crosses(val) # :nodoc:
      val ||= 'autoZero'

      @writer.empty_tag('c:crosses', [['val', val]])
    end

    #
    # Write the <c:crossesAt> element.
    #
    def write_c_crosses_at(val) # :nodoc:
      @writer.empty_tag('c:crossesAt', [['val', val]])
    end

    #
    # Write the <c:auto> element.
    #
    def write_auto(val) # :nodoc:
      @writer.empty_tag('c:auto', [['val', val]])
    end

    #
    # Write the <c:labelAlign> element.
    #
    def write_label_align(val) # :nodoc:
      val ||= 'ctr'
      if val == 'right'
        val = 'r'
      elsif val == 'left'
        val = 'l'
      end
      @writer.empty_tag('c:lblAlgn', [['val', val]])
    end

    #
    # Write the <c:labelOffset> element.
    #
    def write_label_offset(val) # :nodoc:
      @writer.empty_tag('c:lblOffset', [['val', val]])
    end

    #
    # Write the <c:tickLblSkip> element.
    #
    def write_tick_lbl_skip(val) # :nodoc:
      return unless val

      @writer.empty_tag('c:tickLblSkip', [['val', val]])
    end

    #
    # Write the <c:tickMarkSkip> element.
    #
    def write_tick_mark_skip(val)  # :nodoc:
      return unless val

      @writer.empty_tag('c:tickMarkSkip', [['val', val]])
    end

    #
    # Write the <c:majorGridlines> element.
    #
    def write_major_gridlines(gridlines) # :nodoc:
      write_gridlines_base('c:majorGridlines', gridlines)
    end

    #
    # Write the <c:minorGridlines> element.
    #
    def write_minor_gridlines(gridlines)  # :nodoc:
      write_gridlines_base('c:minorGridlines', gridlines)
    end

    def write_gridlines_base(tag, gridlines)  # :nodoc:
      return unless gridlines
      return if gridlines.respond_to?(:[]) and !ptrue?(gridlines[:_visible])

      if gridlines.line_defined?
        @writer.tag_elements(tag) { write_sp_pr(gridlines) }
      else
        @writer.empty_tag(tag)
      end
    end

    #
    # Write the <c:crossBetween> element.
    #
    def write_cross_between(val = nil) # :nodoc:
      val ||= @cross_between

      @writer.empty_tag('c:crossBetween', [['val', val]])
    end

    #
    # Write the <c:majorUnit> element.
    #
    def write_c_major_unit(val = nil) # :nodoc:
      return unless val

      @writer.empty_tag('c:majorUnit', [['val', val]])
    end

    #
    # Write the <c:minorUnit> element.
    #
    def write_c_minor_unit(val = nil) # :nodoc:
      return unless val

      @writer.empty_tag('c:minorUnit', [['val', val]])
    end

    #
    # Write the <c:majorTimeUnit> element.
    #
    def write_c_major_time_unit(val) # :nodoc:
      val ||= 'days'

      @writer.empty_tag('c:majorTimeUnit', [['val', val]])
    end

    #
    # Write the <c:minorTimeUnit> element.
    #
    def write_c_minor_time_unit(val) # :nodoc:
      val ||= 'days'

      @writer.empty_tag('c:minorTimeUnit', [['val', val]])
    end

    #
    # Write the <c:legend> element.
    #
    def write_legend # :nodoc:
      position = @legend.position.sub(/^overlay_/, '')
      return if position == 'none' || !position_allowed.has_key?(position)

      @delete_series = @legend.delete_series if @legend.delete_series.is_a?(Array)
      @writer.tag_elements('c:legend') do
        # Write the c:legendPos element.
        write_legend_pos(position_allowed[position])
        # Remove series labels from the legend.
        # Write the c:legendEntry element.
        @delete_series.each { |i| write_legend_entry(i) } if @delete_series
        # Write the c:layout element.
        write_layout(@legend.layout, 'legend')
        # Write the c:overlay element.
        write_overlay if @legend.position =~ /^overlay_/
        # Write the c:spPr element.
        write_sp_pr(@legend)
        # Write the c:txPr element.
        write_tx_pr(@legend.font) if ptrue?(@legend.font)
      end
    end

    def position_allowed
      {
        'right'     => 'r',
        'left'      => 'l',
        'top'       => 't',
        'bottom'    => 'b',
        'top_right' => 'tr'
      }
    end

    #
    # Write the <c:legendPos> element.
    #
    def write_legend_pos(val) # :nodoc:
      @writer.empty_tag('c:legendPos', [['val', val]])
    end

    #
    # Write the <c:legendEntry> element.
    #
    def write_legend_entry(index) # :nodoc:
      @writer.tag_elements('c:legendEntry') do
        # Write the c:idx element.
        write_idx(index)
        # Write the c:delete element.
        write_delete(1)
      end
    end

    #
    # Write the <c:overlay> element.
    #
    def write_overlay # :nodoc:
      @writer.empty_tag('c:overlay', [['val', 1]])
    end

    #
    # Write the <c:plotVisOnly> element.
    #
    def write_plot_vis_only # :nodoc:
      val  = 1

      # Ignore this element if we are plotting hidden data.
      return if @show_hidden_data

      @writer.empty_tag('c:plotVisOnly', [['val', val]])
    end

    #
    # Write the <c:printSettings> element.
    #
    def write_print_settings # :nodoc:
      @writer.tag_elements('c:printSettings') do
        # Write the c:headerFooter element.
        write_header_footer
        # Write the c:pageMargins element.
        write_page_margins
        # Write the c:pageSetup element.
        write_page_setup
      end
    end

    #
    # Write the <c:headerFooter> element.
    #
    def write_header_footer # :nodoc:
      @writer.empty_tag('c:headerFooter')
    end

    #
    # Write the <c:pageMargins> element.
    #
    def write_page_margins # :nodoc:
      attributes = [
        ['b',      0.75],
        ['l',      0.7],
        ['r',      0.7],
        ['t',      0.75],
        ['header', 0.3],
        ['footer', 0.3]
      ]

      @writer.empty_tag('c:pageMargins', attributes)
    end

    #
    # Write the <c:pageSetup> element.
    #
    def write_page_setup # :nodoc:
      @writer.empty_tag('c:pageSetup')
    end

    #
    # Write the <c:autoTitleDeleted> element.
    #
    def write_auto_title_deleted
      attributes = [['val', 1]]

      @writer.empty_tag('c:autoTitleDeleted', attributes)
    end

    #
    # Write the <c:title> element for a rich string.
    #
    def write_title_rich(title, is_y_axis, font, layout, overlay = nil) # :nodoc:
      @writer.tag_elements('c:title') do
        # Write the c:tx element.
        write_tx_rich(title, is_y_axis, font)
        # Write the c:layout element.
        write_layout(layout, 'text')
        # Write the c:overlay element.
        write_overlay if overlay
      end
    end

    #
    # Write the <c:title> element for a rich string.
    #
    def write_title_formula(title, is_y_axis = nil, axis = nil, layout = nil, overlay = nil) # :nodoc:
      @writer.tag_elements('c:title') do
        # Write the c:tx element.
        write_tx_formula(title.formula, axis ? axis.data_id : title.data_id)
        # Write the c:layout element.
        write_layout(layout, 'text')
        # Write the c:overlay element.
        write_overlay if overlay
        # Write the c:txPr element.
        write_tx_pr(axis ? axis.name_font : title.name_font, is_y_axis)
      end
    end

    #
    # Write the <c:tx> element.
    #
    def write_tx_rich(title, is_y_axis, font) # :nodoc:
      @writer.tag_elements('c:tx') do
        write_rich(title, font, is_y_axis)
      end
    end

    #
    # Write the <c:tx> element with a simple value such as for series names.
    #
    def write_tx_value(title) # :nodoc:
      @writer.tag_elements('c:tx') { write_v(title) }
    end

    #
    # Write the <c:tx> element.
    #
    def write_tx_formula(title, data_id) # :nodoc:
      data = @formula_data[data_id] if data_id

      @writer.tag_elements('c:tx') { write_str_ref(title, data, 'str') }
    end

    #
    # Write the <c:rich> element.
    #
    def write_rich(title, font, is_y_axis, ignore_rich_pr = false) # :nodoc:
      rotation = nil

      rotation = font[:_rotation] if font && font[:_rotation]
      @writer.tag_elements('c:rich') do
        # Write the a:bodyPr element.
        write_a_body_pr(rotation, is_y_axis)
        # Write the a:lstStyle element.
        write_a_lst_style
        # Write the a:p element.
        write_a_p_rich(title, font, ignore_rich_pr)
      end
    end

    #
    # Write the <a:p> element for rich string titles.
    #
    def write_a_p_rich(title, font, ignore_rich_pr) # :nodoc:
      @writer.tag_elements('a:p') do
        # Write the a:pPr element.
        write_a_p_pr_rich(font) unless ignore_rich_pr
        # Write the a:r element.
        write_a_r(title, font)
      end
    end

    #
    # Write the <a:pPr> element for rich string titles.
    #
    def write_a_p_pr_rich(font) # :nodoc:
      @writer.tag_elements('a:pPr') { write_a_def_rpr(font) }
    end

    #
    # Write the <a:r> element.
    #
    def write_a_r(title, font) # :nodoc:
      @writer.tag_elements('a:r') do
        # Write the a:rPr element.
        write_a_r_pr(font)
        # Write the a:t element.
        write_a_t(title.respond_to?(:name) ? title.name : title)
      end
    end

    #
    # Write the <a:rPr> element.
    #
    def write_a_r_pr(font) # :nodoc:
      attributes = [%w[lang en-US]]
      attr_font = get_font_style_attributes(font)
      attributes += attr_font unless attr_font.empty?

      write_def_rpr_r_pr_common(font, attributes, 'a:rPr')
    end

    #
    # Write the <a:t> element.
    #
    def write_a_t(title) # :nodoc:
      @writer.data_element('a:t', title)
    end

    #
    # Write the <c:marker> element.
    #
    def write_marker(marker = nil) # :nodoc:
      marker ||= @default_marker

      return unless ptrue?(marker)
      return if ptrue?(marker.automatic?)

      @writer.tag_elements('c:marker') do
        # Write the c:symbol element.
        write_symbol(marker.type)
        # Write the c:size element.
        size = marker.size
        write_marker_size(size) if ptrue?(size)
        # Write the c:spPr element.
        write_sp_pr(marker)
      end
    end

    #
    # Write the <c:marker> element without a sub-element.
    #
    def write_marker_value # :nodoc:
      return unless @default_marker

      @writer.empty_tag('c:marker', [['val', 1]])
    end

    #
    # Write the <c:size> element.
    #
    def write_marker_size(val) # :nodoc:
      @writer.empty_tag('c:size', [['val', val]])
    end

    #
    # Write the <c:symbol> element.
    #
    def write_symbol(val) # :nodoc:
      @writer.empty_tag('c:symbol', [['val', val]])
    end

    def has_fill_formatting(element)
      line     = series_property(element, :line)
      fill     = series_property(element, :fill)
      pattern  = series_property(element, :pattern)
      gradient = series_property(element, :gradient)

      (line && ptrue?(line[:_defined])) ||
        (fill && ptrue?(fill[:_defined])) || pattern || gradient
    end

    #
    # Write the <c:spPr> element.
    #
    def write_sp_pr(series) # :nodoc:
      return unless has_fill_formatting(series)

      line     = series_property(series, :line)
      fill     = series_property(series, :fill)
      pattern  = series_property(series, :pattern)
      gradient = series_property(series, :gradient)

      @writer.tag_elements('c:spPr') do
        # Write the fill elements for solid charts such as pie/doughnut and bar.
        if fill && fill[:_defined] != 0
          if ptrue?(fill[:none])
            # Write the a:noFill element.
            write_a_no_fill
          else
            # Write the a:solidFill element.
            write_a_solid_fill(fill)
          end
        end
        write_a_patt_fill(pattern) if ptrue?(pattern)
        if ptrue?(gradient)
          # Write the a:gradFill element.
          write_a_grad_fill(gradient)
        end
        # Write the a:ln element.
        write_a_ln(line) if line && ptrue?(line[:_defined])
      end
    end

    def series_property(object, property)
      if object.respond_to?(property)
        object.send(property)
      elsif object.respond_to?(:[])
        object[property]
      end
    end

    #
    # Write the <a:ln> element.
    #
    def write_a_ln(line) # :nodoc:
      attributes = []

      # Add the line width as an attribute.
      if line[:width]
        width = line[:width]
        # Round width to nearest 0.25, like Excel.
        width = ((width + 0.125) * 4).to_i / 4.0

        # Convert to internal units.
        width = (0.5 + (12700 * width)).to_i

        attributes << ['w', width]
      end

      if ptrue?(line[:none]) || ptrue?(line[:color]) || line[:dash_type]
        @writer.tag_elements('a:ln', attributes) do
          # Write the line fill.
          if ptrue?(line[:none])
            # Write the a:noFill element.
            write_a_no_fill
          elsif ptrue?(line[:color])
            # Write the a:solidFill element.
            write_a_solid_fill(line)
          end

          # Write the line/dash type.
          if line[:dash_type]
            # Write the a:prstDash element.
            write_a_prst_dash(line[:dash_type])
          end
        end
      else
        @writer.empty_tag('a:ln', attributes)
      end
    end

    #
    # Write the <a:noFill> element.
    #
    def write_a_no_fill # :nodoc:
      @writer.empty_tag('a:noFill')
    end

    #
    # Write the <a:alpha> element.
    #
    def write_a_alpha(val)
      val = (100 - val.to_i) * 1000

      @writer.empty_tag('a:alpha', [['val', val]])
    end

    #
    # Write the <a:prstDash> element.
    #
    def write_a_prst_dash(val) # :nodoc:
      @writer.empty_tag('a:prstDash', [['val', val]])
    end

    #
    # Write the <c:trendline> element.
    #
    def write_trendline(trendline) # :nodoc:
      return unless trendline

      @writer.tag_elements('c:trendline') do
        # Write the c:name element.
        write_name(trendline.name)
        # Write the c:spPr element.
        write_sp_pr(trendline)
        # Write the c:trendlineType element.
        write_trendline_type(trendline.type)
        # Write the c:order element for polynomial trendlines.
        write_trendline_order(trendline.order) if trendline.type == 'poly'
        # Write the c:period element for moving average trendlines.
        write_period(trendline.period) if trendline.type == 'movingAvg'
        # Write the c:forward element.
        write_forward(trendline.forward)
        # Write the c:backward element.
        write_backward(trendline.backward)
        if trendline.intercept
          # Write the c:intercept element.
          write_intercept(trendline.intercept)
        end
        if trendline.display_r_squared
          # Write the c:dispRSqr element.
          write_disp_rsqr
        end
        if trendline.display_equation
          # Write the c:dispEq element.
          write_disp_eq
          # Write the c:trendlineLbl element.
          write_trendline_lbl(trendline)
        end
      end
    end

    #
    # Write the <c:trendlineType> element.
    #
    def write_trendline_type(val) # :nodoc:
      @writer.empty_tag('c:trendlineType', [['val', val]])
    end

    #
    # Write the <c:name> element.
    #
    def write_name(data) # :nodoc:
      return unless data

      @writer.data_element('c:name', data)
    end

    #
    # Write the <c:order> element.
    #
    def write_trendline_order(val = 2) # :nodoc:
      @writer.empty_tag('c:order', [['val', val]])
    end

    #
    # Write the <c:period> element.
    #
    def write_period(val = 2) # :nodoc:
      @writer.empty_tag('c:period', [['val', val]])
    end

    #
    # Write the <c:forward> element.
    #
    def write_forward(val) # :nodoc:
      return unless val

      @writer.empty_tag('c:forward', [['val', val]])
    end

    #
    # Write the <c:backward> element.
    #
    def write_backward(val) # :nodoc:
      return unless val

      @writer.empty_tag('c:backward', [['val', val]])
    end

    #
    # Write the <c:intercept> element.
    #
    def write_intercept(val)
      @writer.empty_tag('c:intercept', [['val', val]])
    end

    #
    # Write the <c:dispEq> element.
    #
    def write_disp_eq
      @writer.empty_tag('c:dispEq', [['val', 1]])
    end

    #
    # Write the <c:dispRSqr> element.
    #
    def write_disp_rsqr
      @writer.empty_tag('c:dispRSqr', [['val', 1]])
    end

    #
    # Write the <c:trendlineLbl> element.
    #
    def write_trendline_lbl(trendline)
      @writer.tag_elements('c:trendlineLbl') do
        # Write the c:layout element.
        write_layout
        # Write the c:numFmt element.
        write_trendline_num_fmt
        # Write the c:spPr element for the label formatting.
        write_sp_pr(trendline.label)
        # Write the data label font elements.
        if trendline.label && ptrue?(trendline.label[:font])
          write_axis_font(trendline.label[:font])
        end
      end
    end

    #
    # Write the <c:numFmt> element.
    #
    def write_trendline_num_fmt
      format_code   = 'General'
      source_linked = 0

      attributes = [
        ['formatCode',   format_code],
        ['sourceLinked', source_linked]
      ]

      @writer.empty_tag('c:numFmt', attributes)
    end

    #
    # Write the <c:hiLowLines> element.
    #
    def write_hi_low_lines # :nodoc:
      write_lines_base(@hi_low_lines, 'c:hiLowLines')
    end

    #
    # Write the <c:dropLines> elent.
    #
    def write_drop_lines
      write_lines_base(@drop_lines, 'c:dropLines')
    end

    def write_lines_base(lines, tag)
      return unless lines

      if lines.line_defined?
        @writer.tag_elements(tag) { write_sp_pr(lines) }
      else
        @writer.empty_tag(tag)
      end
    end

    #
    # Write the <c:overlap> element.
    #
    def write_overlap(val = nil) # :nodoc:
      return unless val

      @writer.empty_tag('c:overlap', [['val', val]])
    end

    #
    # Write the <c:numCache> element.
    #
    def write_num_cache(data) # :nodoc:
      write_num_base('c:numCache', data)
    end

    def write_num_base(tag, data)
      @writer.tag_elements(tag) do
        # Write the c:formatCode element.
        write_format_code('General')

        # Write the c:ptCount element.
        count = if data
                  data.size
                else
                  0
                end
        write_pt_count(count)

        data.each_with_index do |token, i|
          # Write non-numeric data as 0.
          if token &&
             !(token.to_s =~ /^([+-]?)(?=\d|\.\d)\d*(\.\d*)?([Ee]([+-]?\d+))?$/)
            token = 0
          end

          # Write the c:pt element.
          write_pt(i, token)
        end
      end
    end

    #
    # Write the <c:strCache> element.
    #
    def write_str_cache(data) # :nodoc:
      @writer.tag_elements('c:strCache') do
        write_pt_count(data.size)
        write_pts(data)
      end
    end

    def write_pts(data)
      data.each_index { |i| write_pt(i, data[i]) }
    end

    #
    # Write the <c:formatCode> element.
    #
    def write_format_code(data) # :nodoc:
      @writer.data_element('c:formatCode', data)
    end

    #
    # Write the <c:ptCount> element.
    #
    def write_pt_count(val) # :nodoc:
      @writer.empty_tag('c:ptCount', [['val', val]])
    end

    #
    # Write the <c:pt> element.
    #
    def write_pt(idx, value) # :nodoc:
      return unless value

      attributes = [['idx', idx]]

      @writer.tag_elements('c:pt', attributes) { write_v(value) }
    end

    #
    # Write the <c:v> element.
    #
    def write_v(data) # :nodoc:
      @writer.data_element('c:v', data)
    end

    #
    # Write the <c:protection> element.
    #
    def write_protection # :nodoc:
      return if @protection == 0

      @writer.empty_tag('c:protection')
    end

    #
    # Write the <c:dPt> elements.
    #
    def write_d_pt(points = nil)
      return unless ptrue?(points)

      index = -1
      points.each do |point|
        index += 1
        next unless ptrue?(point)

        write_d_pt_point(index, point)
      end
    end

    #
    # Write an individual <c:dPt> element.
    #
    def write_d_pt_point(index, point)
      @writer.tag_elements('c:dPt') do
        # Write the c:idx element.
        write_idx(index)
        # Write the c:spPr element.
        write_sp_pr(point)
      end
    end

    #
    # Write the <c:dLbls> element.
    #
    def write_d_lbls(labels) # :nodoc:
      return unless labels

      @writer.tag_elements('c:dLbls') do
        # Write the custom c:dLbl elements.
        write_custom_labels(labels, labels[:custom]) if labels[:custom]
        # Write the c:numFmt element.
        write_data_label_number_format(labels[:num_format]) if labels[:num_format]
        # Write the c:spPr element.
        write_sp_pr(labels)
        # Write the data label font elements.
        write_axis_font(labels[:font]) if labels[:font]
        # Write the c:dLblPos element.
        write_d_lbl_pos(labels[:position]) if ptrue?(labels[:position])
        # Write the c:showLegendKey element.
        write_show_legend_key if labels[:legend_key]
        # Write the c:showVal element.
        write_show_val if labels[:value]
        # Write the c:showCatName element.
        write_show_cat_name if labels[:category]
        # Write the c:showSerName element.
        write_show_ser_name if labels[:series_name]
        # Write the c:showPercent element.
        write_show_percent if labels[:percentage]
        # Write the c:separator element.
        write_separator(labels[:separator]) if labels[:separator]
        # Write the c:showLeaderLines element.
        write_show_leader_lines if labels[:leader_lines]
      end
    end

    #
    # Write the <c:dLbl> element.
    #
    def write_custom_labels(parent, labels)
      index  = 0

      labels.each do |label|
        index += 1
        next unless ptrue?(label)

        @writer.tag_elements('c:dLbl') do
          # Write the c:idx element.
          write_idx(index - 1)

          if label[:delete]
            write_delete(1)
          elsif label[:formula]
            write_custom_label_formula(label)

            write_d_lbl_pos(parent[:position]) if parent[:position]
            write_show_val      if parent[:value]
            write_show_cat_name if parent[:category]
            write_show_ser_name if parent[:series_name]
          elsif label[:value]
            write_custom_label_str(label)

            write_d_lbl_pos(parent[:position]) if parent[:position]
            write_show_val      if parent[:value]
            write_show_cat_name if parent[:category]
            write_show_ser_name if parent[:series_name]
          else
            write_custom_label_format_only(label)
          end
        end
      end
    end

    #
    # Write parts of the <c:dLbl> element for strings.
    #
    def write_custom_label_str(label)
      value          = label[:value]
      font           = label[:font]
      is_y_axis      = 0
      has_formatting = has_fill_formatting(label)

      # Write the c:layout element.
      write_layout

      @writer.tag_elements('c:tx') do
        # Write the c:rich element.
        write_rich(value, font, is_y_axis, !has_formatting)
      end

      # Write the c:cpPr element.
      write_sp_pr(label)
    end

    #
    # Write parts of the <c:dLbl> element for formulas.
    #
    def write_custom_label_formula(label)
      formula = label[:formula]
      data_id = label[:data_id]

      data = @formula_data[data_id] if data_id

      # Write the c:layout element.
      write_layout

      @writer.tag_elements('c:tx') do
        # Write the c:strRef element.
        write_str_ref(formula, data, 'str')
      end

      # Write the data label formatting, if any.
      write_custom_label_format_only(label)
    end

    #
    # Write parts of the <c:dLbl> element for labels where only the formatting has
    # changed.
    #
    def write_custom_label_format_only(label)
      font           = label[:font]
      has_formatting = has_fill_formatting(label)

      if has_formatting
        # Write the c:spPr element.
        write_sp_pr(label)
        write_tx_pr(font)
      elsif font
        @writer.empty_tag('c:spPr')
        write_tx_pr(font)
      end
    end

    #
    # Write the <c:showLegendKey> element.
    #
    def write_show_legend_key
      @writer.empty_tag('c:showLegendKey', [['val', 1]])
    end

    #
    # Write the <c:showVal> element.
    #
    def write_show_val # :nodoc:
      @writer.empty_tag('c:showVal', [['val', 1]])
    end

    #
    # Write the <c:showCatName> element.
    #
    def write_show_cat_name # :nodoc:
      @writer.empty_tag('c:showCatName', [['val', 1]])
    end

    #
    # Write the <c:showSerName> element.
    #
    def write_show_ser_name # :nodoc:
      @writer.empty_tag('c:showSerName', [['val', 1]])
    end

    #
    # Write the <c:showPercent> element.
    #
    def write_show_percent
      @writer.empty_tag('c:showPercent', [['val', 1]])
    end

    #
    # Write the <c:separator> element.
    #
    def write_separator(data)
      @writer.data_element('c:separator', data)
    end

    # Write the <c:showLeaderLines> element. This is different for Pie/Doughnut
    # charts. Other chart types only supported leader lines after Excel 2015 via
    # an extension element.
    def write_show_leader_lines
      uri        = '{CE6537A1-D6FC-4f65-9D91-7224C49458BB}'
      xmlns_c_15 = 'http://schemas.microsoft.com/office/drawing/2012/chart'

      attributes1 = [
        ['uri', uri],
        ['xmlns:c15', xmlns_c_15]
      ]

      attributes2 = [['val',  1]]

      @writer.tag_elements('c:extLst') do
        @writer.tag_elements('c:ext', attributes1) do
          @writer.empty_tag('c15:showLeaderLines', attributes2)
        end
      end
    end

    #
    # Write the <c:dLblPos> element.
    #
    def write_d_lbl_pos(val)
      @writer.empty_tag('c:dLblPos', [['val', val]])
    end

    #
    # Write the <c:delete> element.
    #
    def write_delete(val) # :nodoc:
      @writer.empty_tag('c:delete', [['val', val]])
    end

    #
    # Write the <c:invertIfNegative> element.
    #
    def write_c_invert_if_negative(invert = nil) # :nodoc:
      return unless ptrue?(invert)

      @writer.empty_tag('c:invertIfNegative', [['val', 1]])
    end

    #
    # Write the axis font elements.
    #
    def write_axis_font(font) # :nodoc:
      return unless font

      @writer.tag_elements('c:txPr') do
        write_a_body_pr(font[:_rotation])
        write_a_lst_style
        @writer.tag_elements('a:p') do
          write_a_p_pr_rich(font)
          write_a_end_para_rpr
        end
      end
    end

    #
    # Write the <a:latin> element.
    #
    def write_a_latin(args)  # :nodoc:
      @writer.empty_tag('a:latin', args)
    end

    #
    # Write the <c:dTable> element.
    #
    def write_d_table
      @table.write_d_table(@writer) if @table
    end

    #
    # Write the X and Y error bars.
    #
    def write_error_bars(error_bars)
      return unless ptrue?(error_bars)

      write_err_bars('x', error_bars[:_x_error_bars]) if error_bars[:_x_error_bars]
      write_err_bars('y', error_bars[:_y_error_bars]) if error_bars[:_y_error_bars]
    end

    #
    # Write the <c:errBars> element.
    #
    def write_err_bars(direction, error_bars)
      return unless ptrue?(error_bars)

      @writer.tag_elements('c:errBars') do
        # Write the c:errDir element.
        write_err_dir(direction)

        # Write the c:errBarType element.
        write_err_bar_type(error_bars.direction)

        # Write the c:errValType element.
        write_err_val_type(error_bars.type)

        unless ptrue?(error_bars.endcap)
          # Write the c:noEndCap element.
          write_no_end_cap
        end

        case error_bars.type
        when 'stdErr'
          # Don't need to write a c:errValType tag.
        when 'cust'
          # Write the custom error tags.
          write_custom_error(error_bars)
        else
          # Write the c:val element.
          write_error_val(error_bars.value)
        end

        # Write the c:spPr element.
        write_sp_pr(error_bars)
      end
    end

    #
    # Write the <c:errDir> element.
    #
    def write_err_dir(val)
      @writer.empty_tag('c:errDir', [['val', val]])
    end

    #
    # Write the <c:errBarType> element.
    #
    def write_err_bar_type(val)
      @writer.empty_tag('c:errBarType', [['val', val]])
    end

    #
    # Write the <c:errValType> element.
    #
    def write_err_val_type(val)
      @writer.empty_tag('c:errValType', [['val', val]])
    end

    #
    # Write the <c:noEndCap> element.
    #
    def write_no_end_cap
      @writer.empty_tag('c:noEndCap', [['val', 1]])
    end

    #
    # Write the <c:val> element.
    #
    def write_error_val(val)
      @writer.empty_tag('c:val', [['val', val]])
    end

    #
    # Write the custom error bars type.
    #
    def write_custom_error(error_bars)
      if ptrue?(error_bars.plus_values)
        write_custom_error_base('c:plus',  error_bars.plus_values,  error_bars.plus_data)
        write_custom_error_base('c:minus', error_bars.minus_values, error_bars.minus_data)
      end
    end

    def write_custom_error_base(tag, values, data)
      @writer.tag_elements(tag) do
        write_num_ref_or_lit(values, data)
      end
    end

    def write_num_ref_or_lit(values, data)
      if values.to_s =~ /^=/                # '=Sheet1!$A$1:$A$5'
        write_num_ref(values, data, 'num')
      else                                  # [1, 2, 3]
        write_num_lit(values)
      end
    end

    #
    # Write the <c:upDownBars> element.
    #
    def write_up_down_bars
      return unless ptrue?(@up_down_bars)

      @writer.tag_elements('c:upDownBars') do
        # Write the c:gapWidth element.
        write_gap_width(150)

        # Write the c:upBars element.
        write_up_bars(@up_down_bars[:_up])

        # Write the c:downBars element.
        write_down_bars(@up_down_bars[:_down])
      end
    end

    #
    # Write the <c:gapWidth> element.
    #
    def write_gap_width(val = nil)
      return unless val

      @writer.empty_tag('c:gapWidth', [['val', val]])
    end

    #
    # Write the <c:upBars> element.
    #
    def write_up_bars(format)
      write_bars_base('c:upBars', format)
    end

    #
    # Write the <c:upBars> element.
    #
    def write_down_bars(format)
      write_bars_base('c:downBars', format)
    end

    #
    # Write the <c:smooth> element.
    #
    def write_c_smooth(smooth)
      return unless ptrue?(smooth)

      attributes = [['val', 1]]

      @writer.empty_tag('c:smooth', attributes)
    end

    #
    # Write the <c:dispUnits> element.
    #
    def write_disp_units(units, display)
      return unless ptrue?(units)

      attributes = [['val', units]]

      @writer.tag_elements('c:dispUnits') do
        @writer.empty_tag('c:builtInUnit', attributes)
        if ptrue?(display)
          @writer.tag_elements('c:dispUnitsLbl') do
            @writer.empty_tag('c:layout')
          end
        end
      end
    end

    #
    # Write the <a:gradFill> element.
    #
    def write_a_grad_fill(gradient)
      attributes = [
        %w[flip none],
        ['rotWithShape', 1]
      ]
      attributes = [] if gradient[:type] == 'linear'

      @writer.tag_elements('a:gradFill', attributes) do
        # Write the a:gsLst element.
        write_a_gs_lst(gradient)

        if gradient[:type] == 'linear'
          # Write the a:lin element.
          write_a_lin(gradient[:angle])
        else
          # Write the a:path element.
          write_a_path(gradient[:type])

          # Write the a:tileRect element.
          write_a_tile_rect(gradient[:type])
        end
      end
    end

    #
    # Write the <a:gsLst> element.
    #
    def write_a_gs_lst(gradient)
      positions = gradient[:positions]
      colors    = gradient[:colors]

      @writer.tag_elements('a:gsLst') do
        (0..colors.size - 1).each do |i|
          pos = (positions[i] * 1000).to_i

          attributes = [['pos', pos]]
          @writer.tag_elements('a:gs', attributes) do
            color = color(colors[i])

            # Write the a:srgbClr element.
            # TODO: Wait for a feature request to support transparency.
            write_a_srgb_clr(color)
          end
        end
      end
    end

    #
    # Write the <a:lin> element.
    #
    def write_a_lin(angle)
      scaled = 0

      angle = (60000 * angle).to_i

      attributes = [
        ['ang',    angle],
        ['scaled', scaled]
      ]

      @writer.empty_tag('a:lin', attributes)
    end

    #
    # Write the <a:path> element.
    #
    def write_a_path(type)
      attributes = [['path', type]]

      @writer.tag_elements('a:path', attributes) do
        # Write the a:fillToRect element.
        write_a_fill_to_rect(type)
      end
    end

    #
    # Write the <a:fillToRect> element.
    #
    def write_a_fill_to_rect(type)
      attributes = if type == 'shape'
                     [
                       ['l', 50000],
                       ['t', 50000],
                       ['r', 50000],
                       ['b', 50000]
                     ]
                   else
                     [
                       ['l', 100000],
                       ['t', 100000]
                     ]
                   end

      @writer.empty_tag('a:fillToRect', attributes)
    end

    #
    # Write the <a:tileRect> element.
    #
    def write_a_tile_rect(type)
      attributes = if type == 'shape'
                     []
                   else
                     [
                       ['r', -100000],
                       ['b', -100000]
                     ]
                   end

      @writer.empty_tag('a:tileRect', attributes)
    end

    #
    # Write the <a:pattFill> element.
    #
    def write_a_patt_fill(pattern)
      attributes = [['prst', pattern[:pattern]]]

      @writer.tag_elements('a:pattFill', attributes) do
        write_a_fg_clr(pattern[:fg_color])
        write_a_bg_clr(pattern[:bg_color])
      end
    end

    def write_a_fg_clr(color)
      @writer.tag_elements('a:fgClr') { write_a_srgb_clr(color(color)) }
    end

    def write_a_bg_clr(color)
      @writer.tag_elements('a:bgClr') { write_a_srgb_clr(color(color)) }
    end

    def write_bars_base(tag, format)
      if format.line_defined? || format.fill_defined?
        @writer.tag_elements(tag) { write_sp_pr(format) }
      else
        @writer.empty_tag(tag)
      end
    end
  end
end
end

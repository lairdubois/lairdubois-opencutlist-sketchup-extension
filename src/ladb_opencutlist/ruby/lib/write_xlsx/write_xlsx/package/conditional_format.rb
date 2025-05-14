# -*- coding: utf-8 -*-
# frozen_string_literal: true

module Ladb::OpenCutList
module Writexlsx
  module Package
    class ConditionalFormat
      include Writexlsx::Utility

      def self.factory(worksheet, *args)
        range, param  =
          Package::ConditionalFormat
          .new(worksheet, nil, nil)
          .range_param_for_conditional_formatting(*args)

        case param[:type]
        when 'cellIs'
          CellIsFormat.new(worksheet, range, param)
        when 'aboveAverage'
          AboveAverageFormat.new(worksheet, range, param)
        when 'top10'
          Top10Format.new(worksheet, range, param)
        when 'containsText', 'notContainsText', 'beginsWith', 'endsWith'
          TextOrWithFormat.new(worksheet, range, param)
        when 'timePeriod'
          TimePeriodFormat.new(worksheet, range, param)
        when 'containsBlanks', 'notContainsBlanks', 'containsErrors', 'notContainsErrors'
          BlanksOrErrorsFormat.new(worksheet, range, param)
        when 'colorScale'
          ColorScaleFormat.new(worksheet, range, param)
        when 'dataBar'
          DataBarFormat.new(worksheet, range, param)
        when 'expression'
          ExpressionFormat.new(worksheet, range, param)
        when 'iconSet'
          IconSetFormat.new(worksheet, range, param)
        else # when 'duplicateValues', 'uniqueValues'
          ConditionalFormat.new(worksheet, range, param)
        end
      end

      attr_reader :range

      def initialize(worksheet, range, param)
        @worksheet = worksheet
        @range = range
        @param = param
        @writer = @worksheet.writer
      end

      def write_cf_rule
        @writer.empty_tag('cfRule', attributes)
      end

      def write_cf_rule_formula_tag(tag = formula)
        @writer.tag_elements('cfRule', attributes) do
          write_formula_tag(tag)
        end
      end

      def write_formula_tag(data) # :nodoc:
        data = data.sub(/^=/, '') if data.respond_to?(:sub)
        @writer.data_element('formula', data)
      end

      #
      # Write the <cfvo> element.
      #
      def write_cfvo(type, value, criteria = nil)
        attributes = [['type', type]]
        attributes << ['val', value] if value

        attributes << ['gte', 0] if ptrue?(criteria)

        @writer.empty_tag('cfvo', attributes)
      end

      def attributes
        attr = []
        attr << ['type', type]
        attr << ['dxfId',    format]   if format
        attr << ['priority', priority]
        attr << ['stopIfTrue', 1] if stop_if_true
        attr
      end

      def type
        @param[:type]
      end

      def format
        @param[:format]
      end

      def priority
        @param[:priority]
      end

      def stop_if_true
        @param[:stop_if_true]
      end

      def criteria
        @param[:criteria]
      end

      def maximum
        @param[:maximum]
      end

      def minimum
        @param[:minimum]
      end

      def value
        @param[:value]
      end

      def direction
        @param[:direction]
      end

      def formula
        @param[:formula]
      end

      def min_type
        @param[:min_type]
      end

      def min_value
        @param[:min_value]
      end

      def min_color
        @param[:min_color]
      end

      def mid_type
        @param[:mid_type]
      end

      def mid_value
        @param[:mid_value]
      end

      def mid_color
        @param[:mid_color]
      end

      def max_type
        @param[:max_type]
      end

      def max_value
        @param[:max_value]
      end

      def max_color
        @param[:max_color]
      end

      def bar_color
        @param[:bar_color]
      end

      def bar_border_color
        @param[:bar_border_color]
      end

      def bar_negative_color
        @param[:bar_negative_color]
      end

      def bar_negative_color_same
        @param[:bar_negative_color_same]
      end

      def bar_no_border
        @param[:bar_no_border]
      end

      def bar_axis_position
        @param[:bar_axis_position]
      end

      def bar_axis_color
        @param[:bar_axis_color]
      end

      def icon_style
        @param[:icon_style]
      end

      def total_icons
        @param[:total_icons]
      end

      def icons
        @param[:icons]
      end

      def icons_only
        @param[:icons_only]
      end

      def reverse_icons
        @param[:reverse_icons]
      end

      def bar_only
        @param[:bar_only]
      end

      def range_param_for_conditional_formatting(*args)  # :nodoc:
        range_start_cell_for_conditional_formatting(*args)
        param_for_conditional_formatting(*args)

        handling_of_text_criteria        if @param[:type] == 'text'
        handling_of_time_period_criteria if @param[:type] == 'timePeriod'
        handling_of_blanks_error_types

        [@range, @param]
      end

      private

      def handling_of_text_criteria
        case @param[:criteria]
        when 'containsText'
          @param[:type]    = 'containsText'
          @param[:formula] =
            %!NOT(ISERROR(SEARCH("#{@param[:value]}",#{@start_cell})))!
        when 'notContains'
          @param[:type]    = 'notContainsText'
          @param[:formula] =
            %!ISERROR(SEARCH("#{@param[:value]}",#{@start_cell}))!
        when 'beginsWith'
          @param[:type] = 'beginsWith'
          @param[:formula] =
            %!LEFT(#{@start_cell},#{@param[:value].size})="#{@param[:value]}"!
        when 'endsWith'
          @param[:type] = 'endsWith'
          @param[:formula] =
            %!RIGHT(#{@start_cell},#{@param[:value].size})="#{@param[:value]}"!
        else
          raise "Invalid text criteria '#{@param[:criteria]} in conditional_formatting()"
        end
      end

      def handling_of_time_period_criteria
        case @param[:criteria]
        when 'yesterday'
          @param[:formula] = "FLOOR(#{@start_cell},1)=TODAY()-1"
        when 'today'
          @param[:formula] = "FLOOR(#{@start_cell},1)=TODAY()"
        when 'tomorrow'
          @param[:formula] = "FLOOR(#{@start_cell},1)=TODAY()+1"
        when 'last7Days'
          @param[:formula] =
            "AND(TODAY()-FLOOR(#{@start_cell},1)<=6,FLOOR(#{@start_cell},1)<=TODAY())"
        when 'lastWeek'
          @param[:formula] =
            "AND(TODAY()-ROUNDDOWN(#{@start_cell},0)>=(WEEKDAY(TODAY())),TODAY()-ROUNDDOWN(#{@start_cell},0)<(WEEKDAY(TODAY())+7))"
        when 'thisWeek'
          @param[:formula] =
            "AND(TODAY()-ROUNDDOWN(#{@start_cell},0)<=WEEKDAY(TODAY())-1,ROUNDDOWN(#{@start_cell},0)-TODAY()<=7-WEEKDAY(TODAY()))"
        when 'nextWeek'
          @param[:formula] =
            "AND(ROUNDDOWN(#{@start_cell},0)-TODAY()>(7-WEEKDAY(TODAY())),ROUNDDOWN(#{@start_cell},0)-TODAY()<(15-WEEKDAY(TODAY())))"
        when 'lastMonth'
          @param[:formula] =
            "AND(MONTH(#{@start_cell})=MONTH(TODAY())-1,OR(YEAR(#{@start_cell})=YEAR(TODAY()),AND(MONTH(#{@start_cell})=1,YEAR(A1)=YEAR(TODAY())-1)))"
        when 'thisMonth'
          @param[:formula] =
            "AND(MONTH(#{@start_cell})=MONTH(TODAY()),YEAR(#{@start_cell})=YEAR(TODAY()))"
        when 'nextMonth'
          @param[:formula] =
            "AND(MONTH(#{@start_cell})=MONTH(TODAY())+1,OR(YEAR(#{@start_cell})=YEAR(TODAY()),AND(MONTH(#{@start_cell})=12,YEAR(#{@start_cell})=YEAR(TODAY())+1)))"
        else
          raise "Invalid time_period criteria '#{@param[:criteria]}' in conditional_formatting()"
        end
      end

      def handling_of_blanks_error_types
        # Special handling of blanks/error types.
        case @param[:type]
        when 'containsBlanks'
          @param[:formula] = "LEN(TRIM(#{@start_cell}))=0"
        when 'notContainsBlanks'
          @param[:formula] = "LEN(TRIM(#{@start_cell}))>0"
        when 'containsErrors'
          @param[:formula] = "ISERROR(#{@start_cell})"
        when 'notContainsErrors'
          @param[:formula] = "NOT(ISERROR(#{@start_cell}))"
        when '2_color_scale'
          @param[:type] = 'colorScale'

          # Color scales don't use any additional formatting.
          @param[:format] = nil

          # Turn off 3 color parameters.
          @param[:mid_type]  = nil
          @param[:mid_color] = nil

          @param[:min_type]  ||= 'min'
          @param[:max_type]  ||= 'max'
          @param[:min_value] ||= 0
          @param[:max_value] ||= 0
          @param[:min_color] ||= '#FF7128'
          @param[:max_color] ||= '#FFEF9C'

          @param[:max_color] = palette_color(@param[:max_color])
          @param[:min_color] = palette_color(@param[:min_color])
        when '3_color_scale'
          @param[:type] = 'colorScale'

          # Color scales don't use any additional formatting.
          @param[:format] = nil

          @param[:min_type]  ||= 'min'
          @param[:mid_type]  ||= 'percentile'
          @param[:max_type]  ||= 'max'
          @param[:min_value] ||= 0
          @param[:mid_value] ||= 50
          @param[:max_value] ||= 0
          @param[:min_color] ||= '#F8696B'
          @param[:mid_color] ||= '#FFEB84'
          @param[:max_color] ||= '#63BE7B'

          @param[:max_color] = palette_color(@param[:max_color])
          @param[:mid_color] = palette_color(@param[:mid_color])
          @param[:min_color] = palette_color(@param[:min_color])
        when 'dataBar'
          # Excel 2007 data bars don't use any additional formatting.
          @param[:format] = nil

          if @param[:min_type]
            @param[:x14_min_type] = @param[:min_type]
          else
            @param[:min_type]     = 'min'
            @param[:x14_min_type] = 'autoMin'
          end
          if @param[:max_type]
            @param[:x14_max_type] = @param[:max_type]
          else
            @param[:max_type]     = 'max'
            @param[:x14_max_type] = 'autoMax'
          end

          @param[:min_value]                      ||= 0
          @param[:max_value]                      ||= 0
          @param[:bar_color]                      ||= '#638EC6'
          @param[:bar_border_color]               ||= @param[:bar_color]
          @param[:bar_only]                       ||= 0
          @param[:bar_no_border]                  ||= 0
          @param[:bar_solid]                      ||= 0
          @param[:bar_direction]                  ||= ''
          @param[:bar_negative_color]             ||= '#FF0000'
          @param[:bar_negative_border_color]      ||= '#FF0000'
          @param[:bar_negative_color_same]        ||= 0
          @param[:bar_negative_border_color_same] ||= 0
          @param[:bar_axis_position]              ||= ''
          @param[:bar_axis_color]                 ||= '#000000'

          @param[:bar_color] =
            palette_color(@param[:bar_color])
          @param[:bar_border_color] =
            palette_color(@param[:bar_border_color])
          @param[:bar_negative_color] =
            palette_color(@param[:bar_negative_color])
          @param[:bar_negative_border_color] =
            palette_color(@param[:bar_negative_border_color])
          @param[:bar_axis_color] =
            palette_color(@param[:bar_axis_color])
        end

        # Adjust for 2010 style data_bar parameters.
        if ptrue?(@param[:is_data_bar_2010])
          @worksheet.excel_version = 2010

          @param[:min_value] = nil if @param[:min_type] == 'min' && @param[:min_value] == 0
          @param[:max_value] = nil if @param[:max_type] == 'max' && @param[:max_value] == 0

          # Store range for Excel 2010 data bars.
          @param[:range] = range
        end

        # Strip the leading = from formulas.
        @param[:min_value] = @param[:min_value].to_s.sub(/^=/, '') if @param[:min_value]
        @param[:mid_value] = @param[:mid_value].to_s.sub(/^=/, '') if @param[:mid_value]
        @param[:max_value] = @param[:max_value].to_s.sub(/^=/, '') if @param[:max_value]
      end

      def palette_color(index)
        @worksheet.palette_color(index)
      end

      def range_start_cell_for_conditional_formatting(*args)  # :nodoc:
        row1, row2, col1, col2, user_range, _param =
          row_col_param_for_conditional_formatting(*args)
        range       = xl_range(row1, row2, col1, col2)
        @start_cell = xl_rowcol_to_cell(row1, col1)

        # Override with user defined multiple range if provided.
        range = user_range if user_range

        @range = range
      end

      def row_col_param_for_conditional_formatting(*args)
        # Check for a cell reference in A1 notation and substitute row and column
        user_range = if args[0].to_s =~ (/^\D/) && (args[0] =~ /,/)
                       # Check for a user defined multiple range like B3:K6,B8:K11.
                       args[0].sub(/^=/, '').gsub(/\s*,\s*/, ' ').gsub("$", '')
                     end

        if (row_col_array = row_col_notation(args.first))
          if row_col_array.size == 2
            row1, col1 = row_col_array
            row2 = args[1]
          elsif row_col_array.size == 4
            row1, col1, row2, col2 = row_col_array
            param = args[1]
          end
        else
          row1, col1, row2, col2, param = args
        end

        if row2.respond_to?(:keys)
          param = row2
          row2 = row1
          col2 = col1
        end
        raise WriteXLSXInsufficientArgumentError if [row1, col1, row2, col2, param].include?(nil)

        # Check that row and col are valid without storing the values.
        check_dimensions(row1, col1)
        check_dimensions(row2, col2)

        # Swap last row/col for first row/col as necessary
        row1, row2 = row2, row1 if row1 > row2
        col1, col2 = col2, col1 if col1 > col2

        [row1, row2, col1, col2, user_range, param.dup]
      end

      def param_for_conditional_formatting(*args)  # :nodoc:
        _dummy, _dummy, _dummy, _dummy, _dummy, @param =
          row_col_param_for_conditional_formatting(*args)
        check_conditional_formatting_parameters(@param)

        @param[:format] = @param[:format].get_dxf_index if @param[:format]
        @param[:priority] = @worksheet.dxf_priority

        # Check for 2010 style data_bar parameters.
        %i[data_bar_2010 bar_solid bar_border_color bar_negative_color
           bar_negative_color_same bar_negative_border_color
           bar_negative_border_color_same bar_no_border
           bar_axis_position bar_axis_color bar_direction].each do |key|
          if @param[key]
            @param[:is_data_bar_2010] = 1
            break
          end
        end

        @worksheet.dxf_priority += 1
      end

      def check_conditional_formatting_parameters(param)  # :nodoc:
        # Check for valid input parameters.
        if !(param.keys.uniq - valid_parameter_for_conditional_formatting).empty? ||
           !param.has_key?(:type) ||
           !valid_type_for_conditional_formatting.has_key?(param[:type].downcase)
          raise WriteXLSXOptionParameterError, "Invalid type : #{param[:type]}"
        end

        param[:direction] = 'bottom' if param[:type] == 'bottom'
        param[:type] = valid_type_for_conditional_formatting[param[:type].downcase]

        # Check for valid criteria types.
        param[:criteria] = valid_criteria_type_for_conditional_formatting[param[:criteria].downcase] if param.has_key?(:criteria) && valid_criteria_type_for_conditional_formatting.has_key?(param[:criteria].downcase)

        # Convert date/times value if required.
        if %w[date time cellIs].include?(param[:type])
          param[:type] = 'cellIs'

          param[:value]   = convert_date_time_if_required(param[:value])
          param[:minimum] = convert_date_time_if_required(param[:minimum])
          param[:maximum] = convert_date_time_if_required(param[:maximum])
        end

        # Set properties for icon sets.
        if param[:type] == 'iconSet'
          unless param[:icon_style]
            raise "The 'icon_style' parameter must be specified when " +
                  "'type' == 'icon_set' in conditional_formatting()"
          end

          # Check for valid icon styles.
          if icon_set_styles[param[:icon_style]]
            param[:icon_style] = icon_set_styles[param[:icon_style]]
          else
            raise "Unknown icon style '$param->{icon_style}' for parameter " +
                  "'icon_style' in conditional_formatting()"
          end

          # Set the number of icons for the icon style.
          param[:total_icons] = 3
          if param[:icon_style] =~ /^4/
            param[:total_icons] = 4
          elsif param[:icon_style] =~ /^5/
            param[:total_icons] = 5
          end

          param[:icons] = set_icon_properties(param[:total_icons], param[:icons])
        end

        # 'Between' and 'Not between' criteria require 2 values.
        if param[:criteria] == 'between' || param[:criteria] == 'notBetween'
          raise WriteXLSXOptionParameterError, "Invalid criteria : #{param[:criteria]}" unless param.has_key?(:minimum) || param.has_key?(:maximum)
        else
          param[:minimum] = nil
          param[:maximum] = nil
        end

        # Convert date/times value if required.
        raise WriteXLSXOptionParameterError if (param[:type] == 'date' || param[:type] == 'time') && !(convert_date_time_value(param, :value) || convert_date_time_value(param, :maximum))
      end

      def convert_date_time_if_required(val)
        if val.to_s =~ /T/
          date_time = convert_date_time(val)
          raise "Invalid date/time value '#{val}' in conditional_formatting()" unless date_time

          date_time
        else
          val
        end
      end

      # List of valid input parameters for conditional_formatting.
      def valid_parameter_for_conditional_formatting
        %i[
          type
          format
          criteria
          value
          minimum
          maximum
          stop_if_true
          min_type
          mid_type
          max_type
          min_value
          mid_value
          max_value
          min_color
          mid_color
          max_color
          bar_color
          bar_negative_color
          bar_negative_color_same
          bar_solid
          bar_border_color
          bar_negative_border_color
          bar_negative_border_color_same
          bar_no_border
          bar_direction
          bar_axis_position
          bar_axis_color
          bar_only
          icon_style
          reverse_icons
          icons_only
          icons
          data_bar_2010
        ]
      end

      # List of  valid validation types for conditional_formatting.
      def valid_type_for_conditional_formatting
        {
          'cell'          => 'cellIs',
          'date'          => 'date',
          'time'          => 'time',
          'average'       => 'aboveAverage',
          'duplicate'     => 'duplicateValues',
          'unique'        => 'uniqueValues',
          'top'           => 'top10',
          'bottom'        => 'top10',
          'text'          => 'text',
          'time_period'   => 'timePeriod',
          'blanks'        => 'containsBlanks',
          'no_blanks'     => 'notContainsBlanks',
          'errors'        => 'containsErrors',
          'no_errors'     => 'notContainsErrors',
          '2_color_scale' => '2_color_scale',
          '3_color_scale' => '3_color_scale',
          'data_bar'      => 'dataBar',
          'formula'       => 'expression',
          'icon_set'      => 'iconSet'
        }
      end

      # List of valid criteria types for conditional_formatting.
      def valid_criteria_type_for_conditional_formatting
        {
          'between'                  => 'between',
          'not between'              => 'notBetween',
          'equal to'                 => 'equal',
          '='                        => 'equal',
          '=='                       => 'equal',
          'not equal to'             => 'notEqual',
          '!='                       => 'notEqual',
          '<>'                       => 'notEqual',
          'greater than'             => 'greaterThan',
          '>'                        => 'greaterThan',
          'less than'                => 'lessThan',
          '<'                        => 'lessThan',
          'greater than or equal to' => 'greaterThanOrEqual',
          '>='                       => 'greaterThanOrEqual',
          'less than or equal to'    => 'lessThanOrEqual',
          '<='                       => 'lessThanOrEqual',
          'containing'               => 'containsText',
          'not containing'           => 'notContains',
          'begins with'              => 'beginsWith',
          'ends with'                => 'endsWith',
          'yesterday'                => 'yesterday',
          'today'                    => 'today',
          'last 7 days'              => 'last7Days',
          'last week'                => 'lastWeek',
          'this week'                => 'thisWeek',
          'next week'                => 'nextWeek',
          'last month'               => 'lastMonth',
          'this month'               => 'thisMonth',
          'next month'               => 'nextMonth'
        }
      end

      # List of valid icon styles.
      def icon_set_styles
        {
          "3_arrows"                => "3Arrows",            # 1
          "3_flags"                 => "3Flags",             # 2
          "3_traffic_lights_rimmed" => "3TrafficLights2",    # 3
          "3_symbols_circled"       => "3Symbols",           # 4
          "4_arrows"                => "4Arrows",            # 5
          "4_red_to_black"          => "4RedToBlack",        # 6
          "4_traffic_lights"        => "4TrafficLights",     # 7
          "5_arrows_gray"           => "5ArrowsGray",        # 8
          "5_quarters"              => "5Quarters",          # 9
          "3_arrows_gray"           => "3ArrowsGray",        # 10
          "3_traffic_lights"        => "3TrafficLights",     # 11
          "3_signs"                 => "3Signs",             # 12
          "3_symbols"               => "3Symbols2",          # 13
          "4_arrows_gray"           => "4ArrowsGray",        # 14
          "4_ratings"               => "4Rating",            # 15
          "5_arrows"                => "5Arrows",            # 16
          "5_ratings"               => "5Rating"            # 17
        }
      end

      #
      # Set the sub-properites for icons.
      #
      def set_icon_properties(total_icons, user_props)
        props       = []

        # Set the default icon properties.
        total_icons.times do
          props << {
            criteria: 0,
            value:    0,
            type:     'percent'
          }
        end

        # Set the default icon values based on the number of icons.
        if total_icons == 3
          props[0][:value] = 67
          props[1][:value] = 33
        elsif total_icons == 4
          props[0][:value] = 75
          props[1][:value] = 50
          props[2][:value] = 25
        elsif total_icons == 5
          props[0][:value] = 80
          props[1][:value] = 60
          props[2][:value] = 40
          props[3][:value] = 20
        end

        # Overwrite default properties with user defined properties.
        if user_props

          # Ensure we don't set user properties for lowest icon.
          max_data = user_props.size
          max_data = total_icons - 1 if max_data >= total_icons

          (0..max_data - 1).each do |i|
            # Set the user defined 'value' property.
            props[i][:value] = user_props[i][:value].to_s.sub(/^=/, '') if user_props[i][:value]

            # Set the user defined 'type' property.
            if user_props[i][:type]

              type = user_props[i][:type]

              if type != 'percent' && type != 'percentile' &&
                 type != 'number'  && type != 'formula'
                raise "Unknown icon property type '$props->{type}' for sub-" +
                      "property 'type' in conditional_formatting()"
              else
                props[i][:type] = type

                props[i][:type] = 'num' if props[i][:type] == 'number'
              end
            end

            # Set the user defined 'criteria' property.
            props[i][:criteria] = 1 if user_props[i][:criteria] && user_props[i][:criteria] == '>'
          end
        end
        props
      end

      def date_1904?
        @worksheet.date_1904?
      end
    end

    class CellIsFormat < ConditionalFormat
      def attributes
        super << ['operator', criteria]
      end

      def write_cf_rule
        if minimum && maximum
          @writer.tag_elements('cfRule', attributes) do
            write_formula_tag(minimum)
            write_formula_tag(maximum)
          end
        else
          quoted_value = value.to_s
          numeric_regex = /^([+-]?)(?=\d|\.\d)\d*(\.\d*)?([Ee]([+-]?\d+))?$/
          # String "Cell" values must be quoted, apart from ranges.
          if !(quoted_value =~ /(\$?)([A-Z]{1,3})(\$?)(\d+)/) &&
             !(quoted_value =~ numeric_regex) &&
             !(quoted_value =~ /^".*"$/)
            quoted_value = %("#{value}")
          end
          write_cf_rule_formula_tag(quoted_value)
        end
      end
    end

    class AboveAverageFormat < ConditionalFormat
      def attributes
        attr = super
        attr << ['aboveAverage', 0] if criteria =~ /below/
        attr << ['equalAverage', 1] if criteria =~ /equal/
        attr << ['stdDev', $~[1]] if criteria =~ /([123]) std dev/
        attr
      end
    end

    class Top10Format < ConditionalFormat
      def attributes
        attr = super
        attr << ['percent', 1]             if criteria == '%'
        attr << ['bottom',  1]             if direction
        attr << ['rank',    value || 10]
        attr
      end
    end

    class TextOrWithFormat < ConditionalFormat
      def attributes
        attr = super
        attr << ['operator', criteria]
        attr << ['text',     value]
        attr
      end

      def write_cf_rule
        write_cf_rule_formula_tag
      end
    end

    class TimePeriodFormat < ConditionalFormat
      def attributes
        super << ['timePeriod', criteria]
      end

      def write_cf_rule
        write_cf_rule_formula_tag
      end
    end

    class BlanksOrErrorsFormat < ConditionalFormat
      def write_cf_rule
        write_cf_rule_formula_tag
      end
    end

    class ColorScaleFormat < ConditionalFormat
      def write_cf_rule
        @writer.tag_elements('cfRule', attributes) do
          write_color_scale
        end
      end

      #
      # Write the <colorScale> element.
      #
      def write_color_scale
        @writer.tag_elements('colorScale') do
          write_cfvo(min_type, min_value)
          write_cfvo(mid_type, mid_value) if mid_type
          write_cfvo(max_type, max_value)
          write_color('rgb', min_color)
          write_color('rgb', mid_color)  if mid_color
          write_color('rgb', max_color)
        end
      end
    end

    class DataBarFormat < ConditionalFormat
      def write_cf_rule
        @writer.tag_elements('cfRule', attributes) do
          write_data_bar
          write_data_bar_ext(@param) if ptrue?(@param[:is_data_bar_2010])
        end
      end

      #
      # Write the <dataBar> element.
      #
      def write_data_bar
        attributes = []

        attributes << ['showValue', 0] if ptrue?(bar_only)
        @writer.tag_elements('dataBar', attributes) do
          write_cfvo(min_type, min_value)
          write_cfvo(max_type, max_value)

          write_color('rgb', bar_color)
        end
      end

      #
      # Write the <extLst> dataBar extension element.
      #
      def write_data_bar_ext(param)
        # Create a pseudo GUID for each unique Excel 2010 data bar.
        worksheet_count = @worksheet.index + 1
        data_bar_count  = @worksheet.data_bars_2010.size + 1

        guid = sprintf(
          "{DA7ABA51-AAAA-BBBB-%04X-%012X}",
          worksheet_count, data_bar_count
        )

        # Store the 2010 data bar parameters to write the extLst elements.
        param[:guid] = guid
        @worksheet.data_bars_2010 << param

        @writer.tag_elements('extLst') do
          @worksheet.write_ext('{B025F937-C7B1-47D3-B67F-A62EFF666E3E}') do
            @writer.data_element('x14:id', guid)
          end
        end
      end
    end

    class ExpressionFormat < ConditionalFormat
      def write_cf_rule
        write_cf_rule_formula_tag(criteria)
      end
    end

    class IconSetFormat < ConditionalFormat
      def write_cf_rule
        @writer.tag_elements('cfRule', attributes) do
          write_icon_set
        end
      end

      #
      # Write the <iconSet> element.
      #
      def write_icon_set
        attributes = []
        # Don't set attribute for default style.
        attributes = [['iconSet', icon_style]] if icon_style != '3TrafficLights'
        attributes << ['showValue', 0]           if icons_only
        attributes << ['reverse', 1]             if reverse_icons

        @writer.tag_elements('iconSet', attributes) do
          # Write the properties for different icon styles.
          if icons
            icons.reverse.each do |icon|
              write_cfvo(icon[:type], icon[:value], icon[:criteria])
            end
          end
        end
      end
    end
  end
end
end

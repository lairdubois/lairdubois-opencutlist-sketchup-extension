# -*- coding: utf-8 -*-
# frozen_string_literal: true

module Ladb::OpenCutList
module Writexlsx
  class Chart
    require_relative '../gradient'

    class Chartline
      include Writexlsx::Utility
      include Writexlsx::Gradient

      attr_reader :line, :fill, :type, :gradient, :pattern

      def initialize(params)
        @line      = params[:line]
        @fill      = params[:fill]
        @pattern   = params[:pattern]
        @gradient  = params[:gradient]
        # Set the line properties for the marker..
        @line = line_properties(@line)
        # Allow 'border' as a synonym for 'line'.
        @line = line_properties(params[:border]) if params[:border]
        # Set the fill properties for the marker.
        @fill = fill_properties(@fill)
        # Set the pattern properties for the series.
        @pattern = pattern_properties(@pattern)
        # Set the gradient fill properties for the series.
        @gradient = gradient_properties(@gradient)
        # Pattern fill overrides solid fill.
        @fill = nil if ptrue?(@gradient)
        # Gradient fill overrides solid and pattern fills.
        if ptrue?(@gradient)
          @pattern = nil
          @fill    = nil
        end
      end

      def line_defined?
        line && ptrue?(line[:_defined])
      end

      def fill_defined?
        fill && ptrue?(fill[:_defined])
      end
    end

    class Point < Chartline
    end

    class Gridline < Chartline
      attr_reader :visible

      def initialize(params)
        super
        @visible = params[:visible]
      end
    end

    class Trendline < Chartline
      attr_reader :name, :forward, :backward, :order, :period
      attr_reader :intercept, :display_equation, :display_r_squared
      attr_reader :label

      def initialize(params)
        super

        @label = trendline_label_properties(params[:label])

        @name              = params[:name]
        @forward           = params[:forward]
        @backward          = params[:backward]
        @order             = params[:order]
        @period            = params[:period]
        @intercept         = params[:intercept]
        @display_equation  = params[:display_equation]
        @display_r_squared = params[:display_r_squared]
        @type              = value_or_raise(types, params[:type], 'trendline type')
      end

      private

      #
      # Convert user defined trendline label properties to the structure required
      # internally.
      #
      def trendline_label_properties(_label)
        return unless _label || _label.is_a?(Hash)

        # Copy the user supplied properties.
        label = {}

        # Set the font properties for the label.
        label[:font] = convert_font_args(_label[:font]) if ptrue?(_label[:font])

        # Set the line properties for the label.
        line = line_properties(_label[:line])

        # Allow 'border' as a synonym for 'line'.
        line = line_properties(_label[:border]) if ptrue?(_label[:border])

        # Set the pattern properties for the label.
        pattern = pattern_properties(_label[:pattern])

        # Set the gradient fill properties for the label.
        gradient = gradient_properties(_label[:gradient])

        # Set the fill properties for the label.
        # Pattern fill overrides solid fill.
        fill = pattern ? nil : fill_properties(_label[:fill])

        # Gradient fill overrides solid and pattern fills.
        if ptrue?(gradient)
          pattern = nil
          fill    = nil
        end

        label[:line]     = line
        label[:fill]     = fill
        label[:pattern]  = pattern
        label[:gradient] = gradient

        label
      end

      def types
        {
          exponential:    'exp',
          linear:         'linear',
          log:            'log',
          moving_average: 'movingAvg',
          polynomial:     'poly',
          power:          'power'
        }
      end
    end

    class Marker < Chartline
      attr_reader :size

      def initialize(params)
        super

        @type = value_or_raise(types, params[:type], 'maker type') if params[:type]

        @size      = params[:size]
        @automatic = false
        @automatic = true if @type == 'automatic'
      end

      def automatic?
        @automatic
      end

      private

      def types
        {
          automatic:  'automatic',
          none:       'none',
          square:     'square',
          diamond:    'diamond',
          triangle:   'triangle',
          x:          'x',
          star:       'star',
          dot:        'dot',
          short_dash: 'dot',
          dash:       'dash',
          long_dash:  'dash',
          circle:     'circle',
          plus:       'plus',
          picture:    'picture'
        }
      end
    end

    class Errorbars
      include Writexlsx::Utility

      attr_reader :type, :direction, :endcap, :value, :line, :fill
      attr_reader :plus_values, :minus_values, :plus_data, :minus_data

      def initialize(params)
        @type = types[params[:type].to_sym] || 'fixedVal'
        @value = params[:value] || 1    # value for error types that require it.
        @endcap = params[:end_style] || 1 # end-cap style.

        # Set the error bar direction.
        @direction = error_bar_direction(params[:direction])

        # Set any custom values
        @plus_values  = params[:plus_values]  || [1]
        @minus_values = params[:minus_values] || [1]
        @plus_data    = params[:plus_data]    || []
        @minus_data   = params[:minus_data]   || []

        # Set the line properties for the error bars.
        @line = line_properties(params[:line])
        @fill = params[:fill]
      end

      private

      def types
        {
          fixed:              'fixedVal',
          percentage:         'percentage',
          standard_deviation: 'stdDev',
          standard_error:     'stdErr',
          custom:             'cust'
        }
      end

      def error_bar_direction(direction)
        case direction
        when 'minus'
          'minus'
        when 'plus'
          'plus'
        else
          'both'
        end
      end
    end

    class Series
      include Writexlsx::Utility
      include Writexlsx::Gradient

      attr_reader :values, :categories, :name, :name_formula, :name_id
      attr_reader :cat_data_id, :val_data_id, :fill, :pattern, :gradient
      attr_reader :trendline, :smooth, :labels, :invert_if_negative
      attr_reader :inverted_color
      attr_reader :x2_axis, :y2_axis, :error_bars, :points
      attr_accessor :line, :marker

      def initialize(chart, params = {})
        @chart      = chart
        @values     = aref_to_formula(params[:values])
        @categories = aref_to_formula(params[:categories])
        @name, @name_formula =
          chart.process_names(params[:name], params[:name_formula])

        set_data_ids(params)

        @line       = line_properties(params[:border] || params[:line])
        @fill       = fill_properties(params[:fill])
        @pattern    = pattern_properties(params[:pattern])
        @gradient   = gradient_properties(params[:gradient])
        # Pattern fill overrides solid fill.
        @fill       = nil if ptrue?(@pattern)
        # Gradient fill overrides solid and patter fills.
        if ptrue?(@gradient)
          @pattern = nil
          @fill    = nil
        end

        # Set the marker properties for the series.
        @marker     = Marker.new(params[:marker]) if params[:marker]
        # Set the trendline properties for the series.
        @trendline  = Trendline.new(params[:trendline]) if params[:trendline]
        @error_bars = errorbars(params[:x_error_bars], params[:y_error_bars])
        if params[:points]
          @points = params[:points].collect { |p| p ? Point.new(p) : p }
        end

        @label_positions = chart.label_positions
        @label_position_default = chart.label_position_default
        @labels = labels_properties(params[:data_labels])
        @inverted_color = params[:invert_if_negative_color]

        %i[
          smooth invert_if_negative x2_axis y2_axis
        ].each { |key| instance_variable_set("@#{key}", params[key]) }
      end

      def ==(other)
        methods = %w[
          categories values name name_formula name_id
          cat_data_id val_data_id
          line fill gradient marker trendline
          smooth labels inverted_color
          x2_axis y2_axis error_bars points
        ]
        methods.each do |method|
          return false unless instance_variable_get("@#{method}") == other.instance_variable_get("@#{method}")
        end
        true
      end

      def line_defined?
        line && ptrue?(line[:_defined])
      end

      private

      #
      # Convert and aref of row col values to a range formula.
      #
      def aref_to_formula(data) # :nodoc:
        # If it isn't an array ref it is probably a formula already.
        return data unless data.is_a?(Array)

        xl_range_formula(*data)
      end

      def set_data_ids(params)
        @cat_data_id = @chart.data_id(@categories, params[:categories_data])
        @val_data_id = @chart.data_id(@values, params[:values_data])
        @name_id = @chart.data_id(@name_formula, params[:name_data])
      end

      def errorbars(x, y)
        {
          _x_error_bars: x ? Errorbars.new(x) : nil,
          _y_error_bars: y ? Errorbars.new(y) : nil
        }
      end

      #
      # Convert user defined labels properties to the structure required internally.
      #
      def labels_properties(labels) # :nodoc:
        return nil unless labels

        # Map user defined label positions to Excel positions.
        position = labels[:position]
        if ptrue?(position)
          if @label_positions[position]
            labels[:position] = if position == @label_position_default
                                  nil
                                else
                                  @label_positions[position]
                                end
          else
            raise "Unsupported label position '#{position}' for this chart type"
          end
        end

        # Map the user defined label separator to the Excel separator.
        separators = {
          ","  => ", ",
          ";"  => "; ",
          "."  => ". ",
          "\n" => "\n",
          " "  => " "
        }
        separator = labels[:separator]
        unless separator.nil? || separator.empty?
          raise "unsuppoted label separator #{separator}" unless separators[separator]

          labels[:separator] = separators[separator]
        end

        # Set the line properties for the data labels.
        line = line_properties(labels[:border] || labels[:line])

        # Set the pattern properties for the labels.
        pattern = pattern_properties(labels[:pattern])

        # Set the gradient fill properties for the labels.
        gradient = gradient_properties(labels[:gradient])

        # Set the fill properties for the labels.
        fill = pattern ? nil : fill_properties(labels[:fill])

        # Gradient fill overrides solid and pattern fills.
        if gradient
          pattern = nil
          fill    = nil
        end

        labels[:line]     = line
        labels[:fill]     = fill
        labels[:pattern]  = pattern
        labels[:gradient] = gradient

        labels[:font] = convert_font_args(labels[:font]) if labels[:font]

        if labels[:custom]
          # Duplicate, and modify, the custom label properties.
          custom = []

          labels[:custom].each do |label|
            unless label
              custom << nil
              next
            end

            property = label.dup

            # Convert formula.
            property[:formula] = property[:value] if property[:value] && property[:value].to_s =~ /^=[^!]+!\$/

            if property[:formula]
              property[:formula] = property[:formula].sub(/^=/, '')

              data_id = @chart.data_id(property[:formula], property[:data])
              property[:data_id] = data_id
            end

            property[:font] = convert_font_args(property[:font]) if property[:font]

            # Allow 'border' as a synonym for 'line'.
            line = line_properties(property[:border] || property[:line])

            # Set the fill properties for the labels.
            # Pattern fill overrides solid fill.
            fill = pattern ? nil : fill_properties(property[:fill])

            # Set the pattern properties for the labels.
            pattern = pattern_properties(property[:pattern])

            # Set the gradient fill properties for the labels.
            gradient = gradient_properties(property[:gradient])

            # Gradient fill overrides solid and pattern fills.
            if gradient
              pattern = nil
              fill    = nil
            end

            property[:line]     = line
            property[:fill]     = fill
            property[:pattern]  = pattern
            property[:gradient] = gradient

            custom << property
          end
          labels[:custom] = custom
        end

        labels
      end
    end
  end
end
end

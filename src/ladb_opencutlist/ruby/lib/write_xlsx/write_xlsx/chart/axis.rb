# -*- encoding: utf-8 -*-
# frozen_string_literal: true

require_relative '../package/xml_writer_simple'
require_relative '../utility'
require_relative '../chart/caption'

module Ladb::OpenCutList
module Writexlsx
  class Chart
    class Axis < Caption
      include Writexlsx::Utility

      attr_accessor :defaults
      attr_accessor :min, :max, :num_format, :position
      attr_accessor :major_tick_mark, :minor_tick_mark
      attr_reader :minor_unit, :major_unit, :minor_unit_type, :major_unit_type
      attr_reader :display_units_visible, :display_units
      attr_reader :log_base, :crossing, :position_axis, :label_position, :visible
      attr_reader :num_format_linked, :num_font, :layout, :interval_unit
      attr_reader :interval_tick, :major_gridlines, :minor_gridlines, :reverse
      attr_reader :line, :fill, :text_axis, :label_align

      #
      # Convert user defined axis values into axis instance.
      #
      def merge_with_hash(params) # :nodoc:
        super
        args      = (defaults || {}).merge(params)

        %i[
          reverse min max minor_unit major_unit minor_unit_type
          major_unit_type log_base crossing position_axis
          label_position num_format num_format_linked interval_unit
          interval_tick line fill label_align
        ].each { |val| instance_variable_set("@#{val}", args[val]) }
        set_major_minor_gridlines(args)

        @visible           = args[:visible] || 1
        set_display_units(args)
        set_display_units_visible(args)
        set_position(args)
        set_position_axis
        set_font_properties(args)
        set_axis_name_layout(args)
        set_axis_line(args)
        set_axis_fill(args)
        if ptrue?(args[:text_axis])
          chart.date_category = false
          @text_axis = true
        end

        # Set the tick marker types.
        @major_tick_mark = get_tick_type(params[:major_tick_mark])
        @minor_tick_mark = get_tick_type(params[:minor_tick_mark])
      end

      #
      # Write the <c:numberFormat> element. Note: It is assumed that if a user
      # defined number format is supplied (i.e., non-default) then the sourceLinked
      # attribute is 0. The user can override this if required.
      #

      def write_number_format(writer) # :nodoc:
        writer.empty_tag('c:numFmt', num_fmt_attributes)
      end

      #
      # Write the <c:numFmt> element. Special case handler for category axes which
      # don't always have a number format.
      #
      def write_cat_number_format(writer, cat_has_num_fmt)
        return unless user_defined_num_fmt_set? || cat_has_num_fmt

        writer.empty_tag('c:numFmt', num_fmt_attributes)
      end

      private

      def user_defined_num_fmt_set?
        @defaults && @num_format != @defaults[:num_format]
      end

      def source_linked
        value = 1
        value = 0 if user_defined_num_fmt_set?
        value = 1 if @num_format_linked

        value
      end

      def num_fmt_attributes
        [
          ['formatCode',   @num_format],
          ['sourceLinked', source_linked]
        ]
      end

      def set_major_minor_gridlines(args)
        # Map major/minor_gridlines properties.
        %i[major_gridlines minor_gridlines].each do |lines|
          if args[lines] && ptrue?(args[lines][:visible])
            instance_variable_set("@#{lines}", Gridline.new(args[lines]))
          else
            instance_variable_set("@#{lines}", nil)
          end
        end
      end

      #
      #
      # Convert user defined display units to internal units.
      #
      def get_display_units(display_units)
        return unless ptrue?(display_units)

        types = {
          'hundreds'          => 'hundreds',
          'thousands'         => 'thousands',
          'ten_thousands'     => 'tenThousands',
          'hundred_thousands' => 'hundredThousands',
          'millions'          => 'millions',
          'ten_millions'      => 'tenMillions',
          'hundred_millions'  => 'hundredMillions',
          'billions'          => 'billions',
          'trillions'         => 'trillions'
        }

        types[display_units] || warn("Unknown display_units type '$display_units'\n")
      end

      #
      # Convert user tick types to internal units.
      #
      def get_tick_type(tick_type)
        return unless ptrue?(tick_type)

        types = {
          'outside' => 'out',
          'inside'  => 'in',
          'none'    => 'none',
          'cross'   => 'cross'
        }

        types[tick_type] || raise("Unknown tick_type type '#{tick_type}'\n")
      end

      def set_display_units(args)
        @display_units = get_display_units(args[:display_units])
      end

      def set_display_units_visible(args)
        @display_units_visible = args[:display_units_visible] || 1
      end

      def set_position(args)
        # Only use the first letter of bottom, top, left or right.
        @position = args[:position]
        @position = @position.downcase[0, 1] if @position
      end

      def set_position_axis
        # Set the position for a category axis on or between the tick marks.
        if @position_axis
          if @position_axis == 'on_tick'
            @position_axis = 'midCat'
          elsif @position_axis == 'between'
          # Doesn't neet to be modified.
          else
            # Otherwise use the default value.
            @position_axis = nil
          end
        end
      end

      def set_font_properties(args)
        @num_font  = convert_font_args(args[:num_font])
        @name_font = convert_font_args(args[:name_font])
      end

      def set_axis_name_layout(args)
        @layout    = chart.layout_properties(args[:name_layout], 1)
      end

      def set_axis_line(args)
        @line = chart.line_properties(args[:line])
      end

      def set_axis_fill(args)
        @fill = chart.fill_properties(args[:fill])
      end
    end
  end
end
end

# -*- coding: utf-8 -*-
# frozen_string_literal: true

###############################################################################
#
# Scatter - A class for writing Excel Scatter charts.
#
# Used in conjunction with Chart.
#
# See formatting note in Chart.
#
# Copyright 2000-2011, John McNamara, jmcnamara@cpan.org
# Convert to ruby by Hideo NAKAMURA, nakamura.hideo@gmail.com
#

require_relative '../package/xml_writer_simple'
require_relative '../chart'
require_relative '../utility'

module Ladb::OpenCutList
module Writexlsx
  class Chart
    class Scatter < self
      include Writexlsx::Utility
      include Writexlsx::WriteDPtPoint

      def initialize(subtype)
        super
        @subtype           = subtype || 'marker_only'
        @cross_between     = 'midCat'
        @horiz_val_axis    = 0
        @val_axis_position = 'b'
        @smooth_allowed    = 1

        # Set the available data label positions for this chart type.
        @label_position_default = 'right'
        @label_positions = {
          'center' => 'ctr',
          'right'  => 'r',
          'left'   => 'l',
          'above'  => 't',
          'below'  => 'b',
          # For backward compatibility.
          'top'    => 't',
          'bottom' => 'b'
        }
      end

      #
      # Override parent method to add a warning.
      #
      def combine(_chart)
        raise 'Combined chart not currently supported with scatter chart as the primary chart'
      end

      #
      # Override the virtual superclass method with a chart specific method.
      #
      def write_chart_type(params)
        # Write the c:areaChart element.
        write_scatter_chart(params)
      end

      #
      # Write the <c:scatterChart> element.
      #
      def write_scatter_chart(params)
        series = if params[:primary_axes] == 1
                   get_primary_axes_series
                 else
                   get_secondary_axes_series
                 end
        return if series.empty?

        style = 'lineMarker'
        # Set the user defined chart subtype
        style = 'smoothMarker' if %w[smooth_with_markers smooth].include?(@subtype)

        # Add default formatting to the series data.
        modify_series_formatting

        @writer.tag_elements('c:scatterChart') do
          # Write the c:scatterStyle element.
          write_scatter_style(style)
          # Write the series elements.
          series.each { |s| write_series(s) }
          # Write the c:marker element.
          write_marker_value
          # Write the c:axId elements
          write_axis_ids(params)
        end
      end

      #
      # Over-ridden to write c:xVal/c:yVal instead of c:cat/c:val elements.
      #
      # Write the <c:ser> element.
      #
      def write_ser(series)
        @writer.tag_elements('c:ser') do
          write_ser_base(series)
          # Write the c:xVal element.
          write_x_val(series)
          # Write the c:yVal element.
          write_y_val(series)
          # Write the c:smooth element.
          if @subtype =~ /smooth/ && !series.smooth
            write_c_smooth(1)
          else
            write_c_smooth(series.smooth)
          end
        end
        @series_index += 1
      end

      #
      # Over-ridden to have 2 valAx elements for scatter charts instead of
      # catAx/valAx.
      #
      # Write the <c:plotArea> element.
      #
      def write_plot_area
        @writer.tag_elements('c:plotArea') do
          # Write the c:layout element.
          write_layout(@plotarea.layout, 'plot')

          # Write the subclass chart type elements for primary and secondary axes.
          write_chart_type(primary_axes: 1)
          write_chart_type(primary_axes: 0)

          # Write c:catAx and c:valAx elements for series using primary axes.
          write_cat_val_axis(@x_axis, @y_axis, @axis_ids, 'b')

          tmp = @horiz_val_axis
          @horiz_val_axis = 1
          write_val_axis(@x_axis, @y_axis, @axis_ids, 'l')
          @horiz_val_axis = tmp

          # Write c:valAx and c:catAx elements for series using secondary axes.
          write_cat_val_axis(@x2_axis, @y2_axis, @axis2_ids, 'b')

          @horiz_val_axis = 1
          write_val_axis(@x2_axis, @y2_axis, @axis2_ids, 'l')

          # Write the c:spPr element for the plotarea formatting.
          write_sp_pr(@plotarea)
        end
      end

      #
      # Write the <c:xVal> element.
      #
      def write_x_val(series)
        formula = series.categories
        data_id = series.cat_data_id
        data    = @formula_data[data_id]

        @writer.tag_elements('c:xVal') do
          # Check the type of cached data.
          type = get_data_type(data)

          # TODO. Can a scatter plot have non-numeric data.

          if type == 'str'
            # Write the c:numRef element.
            write_str_ref(formula, data, type)
          else
            write_num_ref(formula, data, type)
          end
        end
      end

      #
      # Write the <c:yVal> element.
      #
      def write_y_val(series)
        formula = series.values
        data_id = series.val_data_id
        data    = @formula_data[data_id]

        @writer.tag_elements('c:yVal') do
          # Unlike Cat axes data should only be numeric

          # Write the c:numRef element.
          write_num_ref(formula, data, 'num')
        end
      end

      #
      # Write the <c:scatterStyle> element.
      #
      def write_scatter_style(val)
        @writer.empty_tag('c:scatterStyle', [['val', val]])
      end

      #
      # Add default formatting to the series data unless it has already been
      # specified by the user.
      #
      def modify_series_formatting
        # The default scatter style "markers only" requires a line type
        if @subtype == 'marker_only'
          # Go through each series and define default values.
          @series.each do |series|
            # Set a line type unless there is already a user defined type.
            series.line = line_properties(width: 2.25, none: 1, _defined: 1) unless series.line_defined?
          end
        end

        # Turn markers off for subtypes that don't have them
        unless @subtype =~ /marker/
          # Go through each series and define default values.
          @series.each do |series|
            # Set a marker type unless there is already a user defined type.
            series.marker = Marker.new(type: 'none', _defined: 1) unless ptrue?(series.marker)
          end
        end
      end

      #
      # Write the <c:valAx> element.
      # This is for the second valAx in scatter plots.
      #
      # Usually the X axis.
      #
      def write_cat_val_axis(x_axis, y_axis, axis_ids, position) # :nodoc:
        return unless axis_ids && !axis_ids.empty?

        write_val_axis_base(
          y_axis, x_axis,
          axis_ids[1],
          axis_ids[0],
          x_axis.position || position || @val_axis_position
        )
      end
    end
  end
end
end

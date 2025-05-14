# -*- coding: utf-8 -*-
# frozen_string_literal: true

###############################################################################
#
# Stock - A class for writing Excel Stock charts.
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
    #
    # The default Stock chart is an High-Low-Close chart.
    # A series must be added for each of these data sources.
    #
    class Stock < self
      include Writexlsx::Utility

      def initialize(subtype)
        super
        @show_crosses  = false
        @hi_low_lines  = Chartline.new({})
        @date_category = true

        # Override and reset the default axis values.
        @x_axis.defaults[:num_format] = 'dd/mm/yyyy'
        @x2_axis.defaults[:num_format] = 'dd/mm/yyyy'
        set_x_axis
        set_x2_axis

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
      # Override the virtual superclass method with a chart specific method.
      #
      def write_chart_type(params)
        # Write the c:areaChart element.
        write_stock_chart(params)
      end

      #
      # Write the <c:stockChart> element.
      # Overridden to add hi_low_lines(). TODO. Refactor up into the SUPER class
      #
      def write_stock_chart(params)
        series = if params[:primary_axes] == 1
                   get_primary_axes_series
                 else
                   get_secondary_axes_series
                 end
        return if series.empty?

        # Add default formatting to the series data.
        modify_series_formatting

        @writer.tag_elements('c:stockChart') do
          # Write the series elements.
          series.each { |s| write_series(s) }

          # Write the c:dtopLines element.
          write_drop_lines

          # Write the c:hiLowLines element.
          write_hi_low_lines if ptrue?(params[:primary_axes])

          # Write the c:upDownBars element.
          write_up_down_bars

          # Write the c:marker element.
          write_marker_value

          # Write the c:axId elements
          write_axis_ids(params)
        end
      end

      #
      # Add default formatting to the series data.
      #
      def modify_series_formatting
        array = []
        @series.each_with_index do |series, index|
          if index % 4 != 3
            unless series.line_defined?
              series.line = {
                width:    2.25,
                none:     1,
                _defined: 1
              }
            end

            unless ptrue?(series.marker)
              series.marker = if index % 4 == 2
                                Marker.new(type: 'dot', size: 3)
                              else
                                Marker.new(type: 'none')
                              end
            end
          end
          array << series
        end
        @series = array
      end
    end
  end
end
end

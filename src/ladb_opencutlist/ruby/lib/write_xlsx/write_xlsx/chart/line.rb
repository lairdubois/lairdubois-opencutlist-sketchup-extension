# -*- coding: utf-8 -*-
# frozen_string_literal: true

###############################################################################
#
# Line - A class for writing Excel Line charts.
#
# Used in conjunction with Chart.
#
# See formatting note in Chart.
#
# Copyright 2000-2011, John McNamara, jmcnamara@cpan.org
# Convert to ruby by Hideo NAKAMURA, nakamura.hideo@gmail.com
#

require_relative '../package/xml_writer_simple'
require_relative '../utility'

module Ladb::OpenCutList
module Writexlsx
  class Chart
    class Line < self
      include Writexlsx::Utility
      include Writexlsx::WriteDPtPoint

      def initialize(subtype)
        super
        @subtype ||= 'standard'
        @default_marker = Marker.new(type: 'none')
        @smooth_allowed = 1

        # Override and reset the default axis values.
        @y_axis.defaults[:num_format] = '0%' if @subtype == 'percent_stacked'

        set_y_axis

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
        # Write the c:barChart element.
        write_line_chart(params)
      end

      #
      # Write the <c:lineChart> element.
      #
      def write_line_chart(params)
        series = axes_series(params)
        return if series.empty?

        subtype = if @subtype == 'percent_stacked'
                    'percentStacked'
                  else
                    @subtype
                  end

        @writer.tag_elements('c:lineChart') do
          # Write the c:grouping element.
          write_grouping(subtype)
          # Write the series elements.
          series.each { |s| write_series(s) }

          # Write the c:dropLines element.
          write_drop_lines

          # Write the c:hiLowLines element.
          write_hi_low_lines

          # Write the c:upDownBars element.
          write_up_down_bars

          # Write the c:marker element.
          write_marker_value

          # Write the c:axId elements
          write_axis_ids(params)
        end
      end
    end
  end
end
end

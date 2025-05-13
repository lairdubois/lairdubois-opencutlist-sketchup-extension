# -*- coding: utf-8 -*-
# frozen_string_literal: true

###############################################################################
#
# Area - A class for writing Excel Area charts.
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
    class Area < self
      include Writexlsx::Utility

      def initialize(subtype)
        super
        @subtype = subtype || 'standard'
        @cross_between = 'midCat'
        @show_crosses  = false

        # Override and reset the default axis values.
        @y_axis.defaults[:num_format] = '0%' if @subtype == 'percent_stacked'

        set_y_axis

        # Set the available data label positions for this chart type.
        @label_position_default = 'center'
        @label_positions = { 'center' => 'ctr' }
      end

      #
      # Override the virtual superclass method with a chart specific method.
      #
      def write_chart_type(params)
        # Write the c:areaChart element.
        write_area_chart(params)
      end

      #
      # Write the <c:areaChart> element.
      #
      def write_area_chart(params)
        series = axes_series(params)
        return if series.empty?

        subtype = if @subtype == 'percent_stacked'
                    'percentStacked'
                  else
                    @subtype
                  end
        @writer.tag_elements('c:areaChart') do
          # Write the c:grouping element.
          write_grouping(subtype)
          # Write the series elements.
          series.each { |s| write_series(s) }

          # Write the c:dropLines element.
          write_drop_lines

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

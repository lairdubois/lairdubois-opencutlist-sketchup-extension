# -*- coding: utf-8 -*-
# frozen_string_literal: true

###############################################################################
#
# Radar - A class for writing Excel Radar charts.
#
# Used in conjunction with Chart.
#
# See formatting note in Chart.
#
# Copyright 2000-2012, John McNamara, jmcnamara@cpan.org
# Convert to ruby by Hideo NAKAMURA, nakamura.hideo@gmail.com
#

require_relative '../package/xml_writer_simple'
require_relative '../utility'

module Ladb::OpenCutList
module Writexlsx
  class Chart
    # The Column chart module also supports the following sub-types:
    #
    #     stacked
    #     percent_stacked
    # These can be specified at creation time via the add_chart() Worksheet
    # method:
    #
    #     chart = workbook.add_chart( :type => 'column', :subtype => 'stacked' )
    #
    class Radar < self
      include Writexlsx::Utility

      def initialize(subtype)
        super
        @subtype = subtype || 'marker'
        @default_marker = Marker.new(type: 'none') if @subtype == 'marker'

        # Override and reset the default axis values.
        @x_axis.defaults[:major_gridlines] = { visible: 1 }
        set_x_axis

        # Hardcode major_tick_mark for now untill there is an accessor.
        @y_axis.major_tick_mark = 'cross'

        # Set the available data label positions for this chart type.
        @label_position_default = 'center'
        @label_positions = { 'center' => 'ctr' }
      end

      #
      # Override the virtual superclass method with a chart specific method.
      #
      def write_chart_type(params)
        # Write the c:radarChart element.
        write_radar_chart(params)
      end

      #
      # Write the <c:radarChart> element.
      #
      def write_radar_chart(params)
        series = if ptrue?(params[:primary_axes])
                   get_primary_axes_series
                 else
                   get_secondary_axes_series
                 end

        return if series.empty?

        @writer.tag_elements('c:radarChart') do
          # Write the c:radarStyle element.
          write_radar_style

          # Write the series elements.
          series.each { |s| write_series(s) }

          # Write the c:axId elements
          write_axis_ids(params)
        end
      end

      #
      # Write the <c:radarStyle> element.
      #
      def write_radar_style
        val = 'marker'
        val = 'filled' if @subtype == 'filled'

        attributes = [['val', val]]

        @writer.empty_tag('c:radarStyle', attributes)
      end
    end
  end
end
end

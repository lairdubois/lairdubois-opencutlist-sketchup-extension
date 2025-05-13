# -*- coding: utf-8 -*-
# frozen_string_literal: true

###############################################################################
#
# Doughnut - A class for writing Excel Doughnut charts.
#
# Used in conjunction with Excel::Writer::XLSX::Chart.
#
# See formatting note in Excel::Writer::XLSX::Chart.
#
# Copyright 2000-2014, John McNamara, jmcnamara@cpan.org
# Convert to ruby by Hideo NAKAMURA, nakamura.hideo@gmail.com
#

require_relative '../package/xml_writer_simple'
require_relative '../chart'
require_relative '../chart/pie'
require_relative '../utility'

module Ladb::OpenCutList
module Writexlsx
  class Chart
    class Doughnut < Pie
      include Writexlsx::Utility

      def initialize(subtype)
        super
        @vary_data_color = 1
        @hole_size       = 50
        @rotation        = 0
      end

      #
      # set_hole_size
      #
      # Set the Doughnut chart hole size.
      #
      def set_hole_size(size)
        return unless size

        if size >= 10 && size <= 90
          @hole_size = size
        else
          raise "Hole size $size outside Excel range: 10 <= size <= 90"
        end
      end

      private

      #
      # write_chart_type
      #
      # Override the virtual superclass method with a chart specific method.
      #
      def write_chart_type
        # Write the c:doughnutChart element.
        write_doughnut_chart
      end

      #
      # write_doughnut_chart
      #
      # Write the <c:doughnutChart> element. Over-ridden method to remove axis_id code
      # since Doughnut charts don't require val and cat axes.
      #
      def write_doughnut_chart
        @writer.tag_elements('c:doughnutChart') do
          # Write the c:varyColors element.
          write_vary_colors

          # Write the series elements.
          @series.each { |s| write_ser(s) }

          # Write the c:firstSliceAng element.
          write_first_slice_ang

          # Write the c:holeSize element.
          write_hole_size
        end
      end

      #
      # write_hole_size
      #
      # Write the <c:holeSize> element.
      #
      def write_hole_size
        @writer.empty_tag('c:holeSize', [['val', @hole_size]])
      end
    end
  end
end
end

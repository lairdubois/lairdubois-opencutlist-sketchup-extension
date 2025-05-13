# -*- coding: utf-8 -*-
# frozen_string_literal: true

###############################################################################
#
# Pie - A class for writing Excel Pie charts.
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
    # A Pie chart doesn't have an X or Y axis so the following common chart
    # methods are ignored.
    #
    #     chart.set_x_axis
    #     chart.set_y_axis
    #
    class Pie < self
      include Writexlsx::Utility

      def initialize(subtype)
        super
        @vary_data_color = 1
        @rotation        = 0

        # Set the available data label positions for this chart type.
        @label_position_default = 'best_fit'
        @label_positions = {
          'center'      => 'ctr',
          'inside_base' => 'inBase',
          'inside_end'  => 'inEnd',
          'outside_end' => 'outEnd',
          'best_fit'    => 'bestFit'
        }
      end

      #
      # Set the Pie/Doughnut chart rotation: the angle of the first slice.
      #
      def set_rotation(rotation)
        return unless rotation

        if rotation >= 0 && rotation <= 360
          @rotation = rotation
        else
          raise "Chart rotation $rotation outside range: 0 <= rotation <= 360"
        end
      end

      #
      # Override the virtual superclass method with a chart specific method.
      #
      def write_chart_type
        # Write the c:areaChart element.
        write_pie_chart
      end

      #
      # Write the <c:pieChart> element. Over-ridden method to remove axis_id code
      # since pie charts don't require val and vat axes.
      #
      def write_pie_chart
        @writer.tag_elements('c:pieChart') do
          # Write the c:varyColors element.
          write_vary_colors
          # Write the series elements.
          @series.each { |s| write_series(s) }
          # Write the c:firstSliceAng element.
          write_first_slice_ang
        end
      end

      #
      # Over-ridden method to remove the cat_axis() and val_axis() code since
      # Pie/Doughnut charts don't require those axes.
      #
      # Write the <c:plotArea> element.
      #
      def write_plot_area
        second_chart = @combined

        @writer.tag_elements('c:plotArea') do
          # Write the c:layout element.
          write_layout(@plotarea.layout, 'plot')
          # Write the subclass chart type element.
          write_chart_type
          # Configure a combined chart if present.
          if second_chart
            # Secondary axis has unique id otherwise use same as primary.
            second_chart.id = if second_chart.is_secondary?
                                1000 + @id
                              else
                                @id
                              end

            # Share the same filehandle for writing
            second_chart.writer = @writer

            # Share series index with primary chart.
            second_chart.series_index = @series_index

            # Write the subclass chart type elements for combined chart.
            second_chart.write_chart_type
          end
          # Write the c:spPr eleent for the plotarea formatting.
          write_sp_pr(@plotarea)
        end
      end

      #
      # Over-ridden method to add <c:txPr> to legend.
      #
      # Write the <c:legend> element.
      #
      def write_legend
        allowed = %w[right left top bottom]
        delete_series = @legend.delete_series || []

        if @legend.position =~ /^overlay_/
          position = @legend.position.sub(/^overlay_/, '')
          overlay = true
        else
          position = @legend.position
          overlay = false
        end

        return if position == 'none'
        return unless allowed.include?(position)

        @writer.tag_elements('c:legend') do
          # Write the c:legendPos element.
          write_legend_pos(position[0])
          # Remove series labels from the legend.
          # Write the c:legendEntry element.
          delete_series.each { |index| write_legend_entry(index) }
          # Write the c:layout element.
          write_layout(@legend.layout, 'legend')
          # Write the c:overlay element.
          write_overlay if overlay
          # Write the c:spPr element.
          write_sp_pr(@legend)
          # Write the c:txPr element. Over-ridden.
          write_tx_pr_legend(0, @legend.font)
        end
      end

      #
      # Write the <c:txPr> element for legends.
      #
      def write_tx_pr_legend(horiz, font)
        rotation = nil
        rotation = font[:_rotation] if ptrue?(font) && font[:_rotation]

        @writer.tag_elements('c:txPr') do
          # Write the a:bodyPr element.
          write_a_body_pr(rotation, horiz)
          # Write the a:lstStyle element.
          write_a_lst_style
          # Write the a:p element.
          write_a_p_legend(font)
        end
      end

      #
      # Write the <a:p> element for legends.
      #
      def write_a_p_legend(font)
        @writer.tag_elements('a:p') do
          # Write the a:pPr element.
          write_a_p_pr_legend(font)
          # Write the a:endParaRPr element.
          write_a_end_para_rpr
        end
      end

      #
      # Write the <a:pPr> element for legends.
      #
      def write_a_p_pr_legend(font)
        @writer.tag_elements('a:pPr', [['rtl', 0]]) do
          # Write the a:defRPr element.
          write_a_def_rpr(font)
        end
      end

      #
      # Write the <c:varyColors> element.
      #
      def write_vary_colors
        @writer.empty_tag('c:varyColors', [['val', 1]])
      end

      #
      # Write the <c:firstSliceAng> element.
      #
      def write_first_slice_ang
        @writer.empty_tag('c:firstSliceAng', [['val', @rotation]])
      end

      #
      # Write the <c:showLeaderLines> element. This is for Pie/Doughnut charts.
      # Other chart types only supported leader lines after Excel 2015 via an
      # extension element.
      #
      def write_show_leader_lines
        val  = 1

        attributes = [['val', val]]

        @writer.empty_tag('c:showLeaderLines', attributes)
      end
    end
  end
end
end

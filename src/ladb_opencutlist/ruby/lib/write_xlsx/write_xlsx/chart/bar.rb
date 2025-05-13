# -*- coding: utf-8 -*-
# frozen_string_literal: true

###############################################################################
#
# Bar - A class for writing Excel Bar charts.
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
    class Bar < self
      include Writexlsx::Utility

      def initialize(subtype)
        super
        @subtype = subtype || 'clustered'
        @cat_axis_position = 'l'
        @val_axis_position = 'b'
        @horiz_val_axis    = 0
        @horiz_cat_axis    = 1
        @show_crosses      = false
        # Override and reset the default axis values.
        axis_defaults_set
        set_x_axis
        set_y_axis

        # Set the available data label positions for this chart type.
        @label_position_default = 'outside_end'
        @label_positions = {
          'center'      => 'ctr',
          'inside_base' => 'inBase',
          'inside_end'  => 'inEnd',
          'outside_end' => 'outEnd'
        }
      end

      #
      # Override parent method to add an extra check that is required for Bar
      # charts to ensure that their combined chart is on a secondary axis.
      #
      def combine(chart)
        raise 'Charts combined with Bar charts must be on a secondary axis' unless chart.is_secondary?

        super
      end

      #
      # Override the virtual superclass method with a chart specific method.
      #
      def write_chart_type(params)
        if params[:primary_axes] != 0
          # Reverse X and Y axes for Bar charts.
          @y_axis, @x_axis = @x_axis, @y_axis
          @y2_axis.position = 't' if @y2_axis.position == 'r'
        end

        # Write the c:barChart element.
        write_bar_chart(params)
      end

      #
      # Write the <c:barDir> element.
      #
      def write_bar_dir
        @writer.empty_tag('c:barDir', [%w[val bar]])
      end

      #
      # Write the <c:errDir> element. Overridden from Chart class since it is not
      # used in Bar charts.
      #
      def write_err_dir(direction)
        # do nothing
      end

      private

      def axis_defaults_set
        if @x_axis.defaults
          @x_axis.defaults[:major_gridlines] = { visible: 1 }
        else
          @x_axis.defaults = { major_gridlines: { visible: 1 } }
        end
        if @y_axis.defaults
          @y_axis.defaults[:major_gridlines] = { visible: 0 }
        else
          @y_axis.defaults = { major_gridlines: { visible: 0 } }
        end
        @x_axis.defaults[:num_format] = '0%' if @subtype == 'percent_stacked'
      end
    end
  end
end
end

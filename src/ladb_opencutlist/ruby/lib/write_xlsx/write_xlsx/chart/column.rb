# -*- coding: utf-8 -*-
# frozen_string_literal: true

###############################################################################
#
# Column - A class for writing Excel Column charts.
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
    # The Column chart module also supports the following sub-types:
    #
    #     stacked
    #     percent_stacked
    # These can be specified at creation time via the add_chart() Worksheet
    # method:
    #
    #     chart = workbook.add_chart( :type => 'column', :subtype => 'stacked' )
    #
    class Column < self
      include Writexlsx::Utility

      def initialize(subtype)
        super
        @subtype = subtype || 'clustered'
        @horiz_val_axis = 0

        # Override and reset the default axis values.
        @y_axis.defaults[:num_format] = '0%' if @subtype == 'percent_stacked'

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
      # Override the virtual superclass method with a chart specific method.
      #
      def write_chart_type(params)
        # Write the c:barChart element.
        write_bar_chart(params)
      end

      #
      # Write the <c:barDir> element.
      #
      def write_bar_dir
        @writer.empty_tag('c:barDir', [%w[val col]])
      end

      #
      # Write the <c:errDir> element. Overridden from Chart class since it is not
      # used in Bar charts.
      #
      def write_err_dir(direction)
        # do nothing
      end
    end
  end
end
end

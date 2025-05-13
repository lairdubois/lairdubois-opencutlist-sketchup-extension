# -*- coding: utf-8 -*-
# frozen_string_literal: true

###############################################################################
#
# Chartsheet - A class for writing the Excel XLSX Chartsheet files.
#
# Used in conjunction with WriteXLSX
#
# Copyright 2000-2011, John McNamara, jmcnamara@cpan.org
# Convert to ruby by Hideo NAKAMURA, nakamura.hideo@gmail.com
#

require_relative 'worksheet'

module Ladb::OpenCutList
module Writexlsx
  class Chartsheet < Worksheet
    include Writexlsx::Utility

    attr_writer :chart

    def initialize(workbook, index, name)
      super
      @drawings          = Drawings.new
      @is_chartsheet     = true
      @chart             = nil
      @charts            = [1]
      @zoom_scale_normal = 0
      @page_setup.orientation = false
    end

    #
    # Assemble and write the XML file.
    #
    def assemble_xml_file # :nodoc:
      return unless @writer

      write_xml_declaration do
        # Write the root chartsheet element.
        write_chartsheet do
          # Write the worksheet properties.
          write_sheet_pr
          # Write the sheet view properties.
          write_sheet_views
          # Write the sheetProtection element.
          write_sheet_protection
          # Write the printOptions element.
          write_print_options
          # Write the worksheet page_margins.
          write_page_margins
          # Write the worksheet page setup.
          write_page_setup
          # Write the headerFooter element.
          write_header_footer
          # Write the drawing element.
          write_drawings
          # Write the legaacyDrawingHF element.
          write_legacy_drawing_hf
          # Close the worksheet tag.
        end
      end
    end

    def protect(password = '', user_options = nil, options = {})
      # Objects are default on for chartsheets.
      if user_options
        options[:objects] = if user_options.has_key?(:objects)
                              if ptrue?(user_options[:objects])
                                0
                              else
                                1
                              end
                            else
                              0
                            end

        options[:content] = if user_options.has_key?(:content)
                              user_options[:content]
                            else
                              1
                            end
      else
        options[:objects] = 0
        options[:content] = 1
      end

      # Is objects and content are off then the chartsheet isn't locked.
      # except if it has a password.
      return if password == '' && ptrue?(options[:objects]) && !ptrue?(options[:content])

      @chart.protection = 1

      # Turn off worksheet defaults.
      options[:sheet]     = 0
      options[:scenarios] = 1

      super(password, options)
    end

    ###############################################################################
    #
    # Encapsulated Chart methods.
    #
    ###############################################################################

    def add_series(*args)
      @chart.add_series(*args)
    end

    def set_x_axis(*args)
      @chart.set_x_axis(*args)
    end

    def set_y_axis(*args)
      @chart.set_y_axis(*args)
    end

    def set_x2_axis(*args)
      @chart.set_x2_axis(*args)
    end

    def set_y2_axis(*args)
      @chart.set_y2_axis(*args)
    end

    def set_title(*args)
      @chart.set_title(*args)
    end

    def set_legend(*args)
      @chart.set_legend(*args)
    end

    def set_plotarea(*args)
      @chart.set_plotarea(*args)
    end

    def set_chartarea(*args)
      @chart.set_chartarea(*args)
    end

    def set_style(*args)
      @chart.set_style(*args)
    end

    def show_blanks_as(*args)
      @chart.show_blanks_as(*args)
    end

    def show_na_as_empty_cell
      @chart.show_na_as_empty_cell(*args)
    end

    def show_hidden_data(*args)
      @chart.show_hidden_data(*args)
    end

    def set_size(*args)
      @chart.set_size(*args)
    end

    def set_table(*args)
      @chart.set_table(*args)
    end

    def set_up_down_bars(*args)
      @chart.set_up_down_bars(*args)
    end

    def set_drop_lines(*args)
      @chart.set_drop_lines(*args)
    end

    def set_high_low_lines(*args)
      @chart.set_high_low_lines(*args)
    end

    #
    # Set up chart/drawings.
    #
    def prepare_chart(_index, chart_id, drawing_id) # :nodoc:
      @chart.id = chart_id - 1

      drawings  = Drawings.new
      @drawings = drawings
      @drawings.orientation = @page_setup.orientation

      @external_drawing_links << ['/drawing', "../drawings/drawing#{drawing_id}.xml"]

      @drawing_links << ['/chart', "../charts/chart#{chart_id}.xml"]
    end

    def external_links
      [
        @external_drawing_links,
        @external_vml_links
      ]
    end

    private

    #
    # Write the <chartsheet> element. This is the root element of Chartsheet.
    #
    def write_chartsheet(&block) # :nodoc:
      schema  = 'http://schemas.openxmlformats.org/'
      xmlns   = schema + 'spreadsheetml/2006/main'
      xmlns_r = schema + 'officeDocument/2006/relationships'

      attributes = [
        ['xmlns',   xmlns],
        ['xmlns:r', xmlns_r]
      ]

      @writer.tag_elements('chartsheet', attributes, &block)
    end

    #
    # Write the <sheetPr> element for Sheet level properties.
    #
    def write_sheet_pr # :nodoc:
      attributes = []

      attributes << ['filterMode', 1] if ptrue?(@filter_on)

      if ptrue?(@fit_page) || ptrue?(@tab_color)
        @writer.tag_elements('sheetPr', attributes) do
          write_tab_color
          write_page_set_up_pr
        end
      else
        @writer.empty_tag('sheetPr', attributes)
      end
    end
  end
end
end

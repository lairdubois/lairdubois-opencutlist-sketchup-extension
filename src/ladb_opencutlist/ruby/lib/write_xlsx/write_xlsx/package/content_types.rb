# -*- coding: utf-8 -*-
# frozen_string_literal: true

require_relative '../package/xml_writer_simple'
require_relative '../utility'

module Ladb::OpenCutList
module Writexlsx
  module Package
    class ContentTypes
      include Writexlsx::Utility

      App_package  = 'application/vnd.openxmlformats-package.'
      App_document = 'application/vnd.openxmlformats-officedocument.'

      def initialize(workbook)
        @writer = Package::XMLWriterSimple.new
        @workbook  = workbook
        @defaults  = [
          ['rels', "#{App_package}relationships+xml"],
          ['xml', 'application/xml']
        ]
        @overrides = [
          ['/docProps/app.xml',    "#{App_document}extended-properties+xml"],
          ['/docProps/core.xml',   "#{App_package}core-properties+xml"],
          ['/xl/styles.xml',       "#{App_document}spreadsheetml.styles+xml"],
          ['/xl/theme/theme1.xml', "#{App_document}theme+xml"],
          ['/xl/workbook.xml',     "#{App_document}spreadsheetml.sheet.main+xml"]
        ]
      end

      def set_xml_writer(filename)
        @writer.set_xml_writer(filename)
      end

      def assemble_xml_file
        write_xml_declaration do
          write_types do
            write_defaults
            write_overrides
          end
        end
      end

      #
      # Add elements to the ContentTypes defaults.
      #
      def add_default(part_name, content_type)
        @defaults.push([part_name, content_type])
      end

      #
      # Add elements to the ContentTypes overrides.
      #
      def add_override(part_name, content_type)
        @overrides.push([part_name, content_type])
      end

      def add_worksheet_names
        @workbook.non_chartsheet_count.times do |index|
          add_worksheet_name("sheet#{index + 1}")
        end
      end

      #
      # Add the name of a worksheet to the ContentTypes overrides.
      #
      def add_worksheet_name(name)
        worksheet_name = "/xl/worksheets/#{name}.xml"

        add_override(worksheet_name, "#{App_document}spreadsheetml.worksheet+xml")
      end

      def add_chartsheet_names
        @workbook.chartsheet_count.times do |index|
          add_chartsheet_name("sheet#{index + 1}")
        end
      end

      #
      # Add the name of a chartsheet to the ContentTypes overrides.
      #
      def add_chartsheet_name(name)
        chartsheet_name = "/xl/chartsheets/#{name}.xml"

        add_override(chartsheet_name, "#{App_document}spreadsheetml.chartsheet+xml")
      end

      def add_chart_names
        (1..@workbook.charts.size).each { |i| add_chart_name("chart#{i}") }
      end

      #
      # Add the name of a chart to the ContentTypes overrides.
      #
      def add_chart_name(name)
        chart_name = "/xl/charts/#{name}.xml"

        add_override(chart_name, "#{App_document}drawingml.chart+xml")
      end

      def add_drawing_names
        (1..@workbook.drawings.size).each do |i|
          add_drawing_name("drawing#{i}")
        end
      end

      #
      # Add the name of a drawing to the ContentTypes overrides.
      #
      def add_drawing_name(name)
        drawing_name = "/xl/drawings/#{name}.xml"

        add_override(drawing_name, "#{App_document}drawing+xml")
      end

      #
      # Add the name of a VML drawing to the ContentTypes defaults.
      #
      def add_vml_name
        add_default('vml', "#{App_document}vmlDrawing")
      end

      def add_comment_names
        (1..@workbook.num_comment_files).each do |i|
          add_comment_name("comments#{i}")
        end
      end

      #
      # Add the name of a comment to the ContentTypes overrides.
      #
      def add_comment_name(name)
        comment_name = "/xl/#{name}.xml"

        add_override(comment_name, "#{App_document}spreadsheetml.comments+xml")
      end

      #
      # Add the sharedStrings link to the ContentTypes overrides.
      #
      def add_shared_strings
        add_override('/xl/sharedStrings.xml', "#{App_document}spreadsheetml.sharedStrings+xml")
      end

      #
      # Add the calcChain link to the ContentTypes overrides.
      #
      def add_calc_chain
        add_override('/xl/calcChain.xml', "#{App_document}spreadsheetml.calcChain+xml")
      end

      #
      # Add the image default types.
      #
      def add_image_types
        @workbook.image_types.each_key do |type|
          add_default(type, "image/#{type}")
        end
      end

      def add_table_names(table_count)
        (1..table_count).each { |i| add_table_name("table#{i}") }
      end

      #
      # Add the name of a table to the ContentTypes overrides.
      #
      def add_table_name(table_name)
        add_override(
          "/xl/tables/#{table_name}.xml",
          "#{App_document}spreadsheetml.table+xml"
        )
      end

      #
      # Add a vbaProject to the ContentTypes defaults.
      #
      def add_vba_project
        change_the_workbook_xml_content_type_from_xlsx_to_xlsm
        add_default('bin', 'application/vnd.ms-office.vbaProject')
      end

      #
      # Add the name of a table to the ContentTypes overrides.
      #
      def add_custom_properties
        custom = "/docProps/custom.xml"

        add_override(custom, "#{App_document}custom-properties+xml")
      end

      #
      # Add the metadata file to the ContentTypes overrides.
      #
      def add_metadata
        add_override(
          "/xl/metadata.xml",
          "#{App_document}spreadsheetml.sheetMetadata+xml"
        )
      end

      def add_richvalue
        add_override(
          '/xl/richData/rdRichValueTypes.xml',
          'application/vnd.ms-excel.rdrichvaluetypes+xml'
        )

        add_override(
          '/xl/richData/rdrichvalue.xml',
          'application/vnd.ms-excel.rdrichvalue+xml'
        )

        add_override(
          '/xl/richData/rdrichvaluestructure.xml',
          'application/vnd.ms-excel.rdrichvaluestructure+xml'
        )

        add_override(
          '/xl/richData/richValueRel.xml',
          'application/vnd.ms-excel.richvaluerel+xml'
        )
      end

      private

      def change_the_workbook_xml_content_type_from_xlsx_to_xlsm
        @overrides.collect! do |arr|
          arr[1] = 'application/vnd.ms-excel.sheet.macroEnabled.main+xml' if arr[0] == '/xl/workbook.xml'
          arr
        end
      end

      #
      # Write out all of the <Default> types.
      #
      def write_defaults
        @defaults.each do |a|
          write_default_or_override('Default', 'Extension', a)
        end
      end

      #
      # Write out all of the <Override> types.
      #
      def write_overrides
        @overrides.each do |a|
          write_default_or_override('Override', 'PartName', a)
        end
      end

      def write_default_or_override(tag, param0, a)
        @writer.empty_tag(tag,
                          [
                            [param0, a[0]],
                            ['ContentType', a[1]]
                          ])
      end

      #
      # Write the <Types> element.
      #
      def write_types(&block)
        xmlns = 'http://schemas.openxmlformats.org/package/2006/content-types'
        attributes = [
          ['xmlns', xmlns]
        ]

        @writer.tag_elements('Types', attributes, &block)
      end

      #
      # Write the <Default> element.
      #
      def write_default(extension, content_type)
        attributes = [
          ['Extension',   extension],
          ['ContentType', content_type]
        ]

        @writer.empty_tag('Default', attributes)
      end

      #
      # Write the <Override> element.
      #
      def write_override(part_name, content_type)
        attributes = [
          ['PartName',    part_name],
          ['ContentType', content_type]
        ]

        @writer.empty_tag('Override', attributes)
      end
    end
  end
end
end

# -*- coding: utf-8 -*-
# frozen_string_literal: true

require_relative '../package/xml_writer_simple'
require_relative '../utility'

module Ladb::OpenCutList
module Writexlsx
  module Package
    class App
      include Writexlsx::Utility
      attr_writer :doc_security

      def initialize(workbook)
        @writer = Package::XMLWriterSimple.new
        @workbook      = workbook
        @part_names    = []
        @heading_pairs = []
        @properties    = {}
        @doc_security  = 0
      end

      def set_xml_writer(filename)
        @writer.set_xml_writer(filename)
      end

      def assemble_xml_file
        write_xml_declaration do
          write_properties do
            write_application
            write_doc_security
            write_scale_crop
            write_heading_pairs
            write_titles_of_parts
            write_manager
            write_company
            write_links_up_to_date
            write_shared_doc
            write_hyperlink_base
            write_hyperlinks_changed
            write_app_version
          end
        end
      end

      def add_worksheet_heading_pairs
        add_heading_pair(
          [
            'Worksheets',
            @workbook.worksheets.reject do |s|
              s.is_chartsheet? || s.very_hidden?
            end.count
          ]
        )
      end

      def add_chartsheet_heading_pairs
        add_heading_pair(['Charts', @workbook.chartsheet_count])
      end

      def add_worksheet_part_names
        @workbook.worksheets
          .reject { |sheet| sheet.is_chartsheet? || sheet.very_hidden? }
          .each  do |sheet|
          add_part_name(sheet.name)
        end
      end

      def add_chartsheet_part_names
        @workbook.worksheets
          .select { |sheet| sheet.is_chartsheet? }
          .each   { |sheet| add_part_name(sheet.name) }
      end

      def add_part_name(part_name)
        @part_names.push(part_name)
      end

      def add_named_range_heading_pairs
        range_count = @workbook.named_ranges.size

        add_heading_pair(['Named Ranges', range_count]) if range_count != 0
      end

      def add_named_ranges_parts
        @workbook.named_ranges.each { |named_range| add_part_name(named_range) }
      end

      def add_heading_pair(heading_pair)
        return if heading_pair[1] == 0

        @heading_pairs.push(['lpstr', heading_pair[0]], ['i4', heading_pair[1]])
      end

      #
      # Set the document properties.
      #
      def set_properties(properties)
        @properties = properties
      end

      private

      #
      # Write the <Properties> element.
      #
      def write_properties(&block)
        schema = 'http://schemas.openxmlformats.org/officeDocument/2006/'
        attributes = [
          ['xmlns',     "#{schema}extended-properties"],
          ['xmlns:vt',  "#{schema}docPropsVTypes"]
        ]

        @writer.tag_elements('Properties', attributes, &block)
      end

      #
      # Write the <Application> element.
      #
      def write_application
        data = 'Microsoft Excel'

        @writer.data_element('Application', data)
      end

      #
      # Write the <DocSecurity> element.
      #
      def write_doc_security
        @writer.data_element('DocSecurity', @doc_security)
      end

      #
      # Write the <ScaleCrop> element.
      #
      def write_scale_crop
        data = 'false'

        @writer.data_element('ScaleCrop', data)
      end

      #
      # Write the <HeadingPairs> element.
      #
      def write_heading_pairs
        @writer.tag_elements('HeadingPairs') do
          write_vt_vector('variant', @heading_pairs)
        end
      end

      #
      # Write the <TitlesOfParts> element.
      #
      def write_titles_of_parts
        @writer.tag_elements('TitlesOfParts') do
          parts_data = @part_names.collect { |part_name| ['lpstr', part_name] }
          write_vt_vector('lpstr', parts_data)
        end
      end

      #
      # Write the <vt:vector> element.
      #
      def write_vt_vector(base_type, data)
        attributes = [
          ['size',     data.size],
          ['baseType', base_type]
        ]

        @writer.tag_elements('vt:vector', attributes) do
          data.each do |a|
            if base_type == 'variant'
              @writer.tag_elements('vt:variant') { write_vt_data(*a) }
            else
              write_vt_data(*a)
            end
          end
        end
      end

      #
      # Write the <vt:*> elements such as <vt:lpstr> and <vt:if>.
      #
      def write_vt_data(type, data)
        @writer.data_element("vt:#{type}", data)
      end

      #
      # Write the <Company> element.
      #
      def write_company
        data = @properties[:company] || ''

        @writer.data_element('Company', data)
      end

      #
      # Write the <Manager> element.
      #
      def write_manager
        data = @properties[:manager]

        return unless data

        @writer.data_element('Manager', data)
      end

      #
      # Write the <LinksUpToDate> element.
      #
      def write_links_up_to_date
        data = 'false'

        @writer.data_element('LinksUpToDate', data)
      end

      #
      # Write the <SharedDoc> element.
      #
      def write_shared_doc
        data = 'false'

        @writer.data_element('SharedDoc', data)
      end

      #
      # Write the <HyperlinkBase> element.
      #
      def write_hyperlink_base
        data = @properties[:hyperlink_base]

        return unless data

        @writer.data_element('HyperlinkBase', data)
      end

      #
      # Write the <HyperlinksChanged> element.
      #
      def write_hyperlinks_changed
        data = 'false'

        @writer.data_element('HyperlinksChanged', data)
      end

      #
      # Write the <AppVersion> element.
      #
      def write_app_version
        data = '12.0000'

        @writer.data_element('AppVersion', data)
      end
    end
  end
end
end

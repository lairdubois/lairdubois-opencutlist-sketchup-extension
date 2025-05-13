# -*- coding: utf-8 -*-
# frozen_string_literal: true

require_relative '../package/xml_writer_simple'
require_relative '../utility'

module Ladb::OpenCutList
module Writexlsx
  module Package
    #
    # RichValueRel - A class for writing the Excel XLSX richValueRel.xml file.
    #
    # Used in conjunction with Excel::Writer::XLSX
    #
    # Copyright 2000-2024, John McNamara, jmcnamara@cpan.org
    #
    # Convert to Ruby by Hideo Nakamura, nakamura.hideo@gmail.com
    #
    class RichValueRel
      include Writexlsx::Utility

      attr_writer :value_count

      def initialize
        @writer = Package::XMLWriterSimple.new
        @value_count = 0
      end

      def set_xml_writer(filename)
        @writer.set_xml_writer(filename)
      end

      def assemble_xml_file
        write_xml_declaration do
          write_rich_value_rels
        end
      end

      private

      #
      # Write the <richValueRels> element.
      #
      def write_rich_value_rels
        xmlns = 'http://schemas.microsoft.com/office/spreadsheetml/2022/richvaluerel'
        xmlns_r = 'http://schemas.openxmlformats.org/officeDocument/2006/relationships'

        attributes = [
          ['xmlns',   xmlns],
          ['xmlns:r', xmlns_r]
        ]

        @writer.tag_elements('richValueRels', attributes) do
          (0..(@value_count - 1)).each do |index|
            # Write the rel element.
            write_rel(index + 1)
          end
        end
      end

      #
      # Write the <rel> element.
      #
      def write_rel(id)
        attributes = [['r:id',  "rId#{id}"]]

        @writer.empty_tag('rel', attributes)
      end
    end
  end
end
end

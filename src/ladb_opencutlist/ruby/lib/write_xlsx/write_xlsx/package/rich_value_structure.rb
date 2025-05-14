# -*- coding: utf-8 -*-
# frozen_string_literal: true

require_relative '../package/xml_writer_simple'
require_relative '../utility'

module Ladb::OpenCutList
module Writexlsx
  module Package
    #
    # RichValueStructure - A class for writing the Excel XLSX rdrichvaluestructure.xml
    # file.
    #
    # Used in conjunction with Excel::Writer::XLSX
    #
    # Copyright 2000-2024, John McNamara, jmcnamara@cpan.org
    #
    # Convert to Ruby by Hideo NAKAMURA, nakamura.hideo@gmail.com
    #
    class RichValueStructure
      include Writexlsx::Utility

      attr_writer :has_embedded_descriptions

      def initialize
        @writer = Package::XMLWriterSimple.new
        @has_embedded_descriptions = false
      end

      def set_xml_writer(filename)
        @writer.set_xml_writer(filename)
      end

      def assemble_xml_file
        write_xml_declaration do
          write_rv_structures
        end
      end

      private

      #
      # Write the <rvStructures> element.
      #
      def write_rv_structures
        xmlns = 'http://schemas.microsoft.com/office/spreadsheetml/2017/richdata'

        attributes = [
          ['xmlns', xmlns],
          ['count', 1]
        ]

        @writer.tag_elements('rvStructures', attributes) do
          write_s
        end
      end

      #
      # Write the <s> element.
      #
      def write_s
        attributes = [%w[t _localImage]]

        @writer.tag_elements('s', attributes) do
          write_k('_rvRel:LocalImageIdentifier', 'i')
          write_k('CalcOrigin',                  'i')
          write_k('Text', 's') if @has_embedded_descriptions
        end
      end

      #
      # Write the <k> element.
      #
      def write_k(n, t)
        attributes = [
          ['n', n],
          ['t', t]
        ]

        @writer.empty_tag('k', attributes)
      end
    end
  end
end
end

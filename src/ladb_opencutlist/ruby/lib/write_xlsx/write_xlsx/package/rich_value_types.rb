# -*- coding: utf-8 -*-
# frozen_string_literal: true

require_relative '../package/xml_writer_simple'
require_relative '../utility'

module Ladb::OpenCutList
module Writexlsx
  module Package
    #
    # RichValueTypes - A class for writing the Excel XLSX rdRichValueTypes.xml file.
    #
    # Used in conjunction with Excel::Writer::XLSX
    #
    # Copyright 2000-2024, John McNamara, jmcnamara@cpan.org
    #
    # Convert to Ruby by Hideo NAKAMURA, nakamura.hideo@gmail.com
    #
    class RichValueTypes
      include Writexlsx::Utility

      def initialize
        @writer          = Package::XMLWriterSimple.new
      end

      def set_xml_writer(filename)
        @writer.set_xml_writer(filename)
      end

      def assemble_xml_file
        write_xml_declaration do
          write_rv_types_info
        end
      end

      private

      #
      # Write the <rvTypesInfo> element.
      #
      def write_rv_types_info
        xmlns = 'http://schemas.microsoft.com/office/spreadsheetml/2017/richdata2'
        xmlns_mc = 'http://schemas.openxmlformats.org/markup-compatibility/2006'
        xmlns_x  = 'http://schemas.openxmlformats.org/spreadsheetml/2006/main'

        attributes = [
          ['xmlns',        xmlns],
          ['xmlns:mc',     xmlns_mc],
          ['mc:Ignorable', 'x'],
          ['xmlns:x',      xmlns_x]
        ]

        key_flags = [
          ['_Self', %w[ExcludeFromFile ExcludeFromCalcComparison]],
          ['_DisplayString',          ['ExcludeFromCalcComparison']],
          ['_Flags',                  ['ExcludeFromCalcComparison']],
          ['_Format',                 ['ExcludeFromCalcComparison']],
          ['_SubLabel',               ['ExcludeFromCalcComparison']],
          ['_Attribution',            ['ExcludeFromCalcComparison']],
          ['_Icon',                   ['ExcludeFromCalcComparison']],
          ['_Display',                ['ExcludeFromCalcComparison']],
          ['_CanonicalPropertyNames', ['ExcludeFromCalcComparison']],
          ['_ClassificationId',       ['ExcludeFromCalcComparison']]
        ]

        @writer.tag_elements('rvTypesInfo', attributes) do
          @writer.tag_elements('global') do
            @writer.tag_elements('keyFlags') do
              # Write the keyFlags element.
              key_flags.each do |key_flag|
                write_key(key_flag[0], key_flag[1])
              end
            end
          end
        end
      end

      #
      # Write the <key> element.
      #
      def write_key(name, flags = [])
        attributes = [['name',  name]]

        @writer.tag_elements('key', attributes) do
          flags.each do |flag|
            write_flag(flag)
          end
        end
      end

      #
      # Write the <flag> element.
      #
      def write_flag(name)
        attributes = [
          ['name', name],
          ['value', 1]
        ]

        @writer.empty_tag('flag', attributes)
      end
    end
  end
end
end

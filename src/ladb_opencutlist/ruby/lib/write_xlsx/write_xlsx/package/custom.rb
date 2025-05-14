# -*- coding: utf-8 -*-
# frozen_string_literal: true

require_relative '../package/xml_writer_simple'
require_relative '../utility'

module Ladb::OpenCutList
module Writexlsx
  module Package
    class Custom
      include Writexlsx::Utility

      def initialize
        @writer     = Package::XMLWriterSimple.new
        @properties = []
        @pid        = 1
      end

      def set_xml_writer(filename)
        @writer.set_xml_writer(filename)
      end

      def assemble_xml_file
        write_xml_declaration do
          write_properties
        end
      end

      #
      # Set the document properties.
      #
      def set_properties(properties)
        @properties = properties
      end

      private

      def write_properties
        schema   = 'http://schemas.openxmlformats.org/officeDocument/2006/'
        xmlns    = "#{schema}custom-properties"
        xmlns_vt = "#{schema}docPropsVTypes"

        attributes = [
          ['xmlns',    xmlns],
          ['xmlns:vt', xmlns_vt]
        ]

        @writer.tag_elements('Properties', attributes) do
          @properties.each do |property|
            # Write the property element.
            write_property(property)
          end
        end
      end

      def write_property(property)
        fmtid = '{D5CDD505-2E9C-101B-9397-08002B2CF9AE}'

        @pid += 1
        name, value, type  = property

        attributes = [
          ['fmtid', fmtid],
          ['pid',   @pid],
          ['name',  name]
        ]

        @writer.tag_elements('property', attributes) do
          if type == 'date'
            # Write the vt:filetime element.
            write_vt_filetime(value)
          elsif type == 'number'
            # Write the vt:r8 element.
            write_vt_r8(value)
          elsif type == 'number_int'
            # Write the vt:i4 element.
            write_vt_i4(value)
          elsif type == 'bool'
            # Write the vt:bool element.
            write_vt_bool(value)
          else
            # Write the vt:lpwstr element.
            write_vt_lpwstr(value)
          end
        end
      end

      def write_vt_lpwstr(data)
        @writer.data_element('vt:lpwstr', data)
      end

      #
      # Write the <vt:i4> element.
      #
      def write_vt_i4(data)
        @writer.data_element('vt:i4', data)
      end

      #
      # Write the <vt:r8> element.
      #
      def write_vt_r8(data)
        @writer.data_element('vt:r8', data)
      end

      #
      # Write the <vt:bool> element.
      #
      def write_vt_bool(data)
        data = if ptrue?(data)
                 'true'
               else
                 'false'
               end

        @writer.data_element('vt:bool', data)
      end

      #
      # Write the <vt:filetime> element.
      #
      def write_vt_filetime(data)
        @writer.data_element('vt:filetime', data)
      end
    end
  end
end
end

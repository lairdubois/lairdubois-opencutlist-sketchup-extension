# -*- coding: utf-8 -*-
# frozen_string_literal: true

require_relative '../package/xml_writer_simple'
require_relative '../utility'

module Ladb::OpenCutList
module Writexlsx
  module Package
    #
    # Metadata - A class for writing the Excel XLSX metadata.xml file.
    #
    class Metadata
      include Writexlsx::Utility

      attr_writer :has_dynamic_functions
      attr_writer :num_embedded_images

      def initialize(workbook)
        @writer = Package::XMLWriterSimple.new
        @workbook = workbook
        @has_dynamic_functions = false
        @has_embedded_images   = false
        @num_embedded_images   = 0
      end

      def set_xml_writer(filename)
        @writer.set_xml_writer(filename)
      end

      def assemble_xml_file
        @has_embedded_images = true if @num_embedded_images > 0

        write_xml_declaration do
          # Write the metadata element.
          write_metadata

          # Write the metadataTypes element.
          write_metadata_types

          # Write the futureMetadata element.
          write_cell_future_metadata  if @has_dynamic_functions
          write_value_future_metadata if @has_embedded_images

          # Write the cellMetadata element.
          write_cell_metadata  if @has_dynamic_functions
          write_value_metadata if @has_embedded_images

          @writer.end_tag('metadata')
        end
      end

      private

      #
      # Write the <metadata> element.
      #
      def write_metadata
        xmlns = 'http://schemas.openxmlformats.org/spreadsheetml/2006/main'
        attributes = [
          ['xmlns',     xmlns]
        ]

        if @has_embedded_images
          attributes << [
            'xmlns:xlrd',
            'http://schemas.microsoft.com/office/spreadsheetml/2017/richdata'
          ]
        end
        if @has_dynamic_functions
          attributes << [
            'xmlns:xda',
            'http://schemas.microsoft.com/office/spreadsheetml/2017/dynamicarray'
          ]
        end

        @writer.start_tag('metadata', attributes)
      end

      #
      # Write the <metadataTypes> element.
      #
      def write_metadata_types
        count =
          (@has_dynamic_functions ? 1 : 0) +
          (@has_embedded_images   ? 1 : 0)

        attributes = [['count', count]]

        @writer.tag_elements('metadataTypes', attributes) do
          # Write the metadataType element.
          write_cell_metadata_type  if @has_dynamic_functions
          write_value_metadata_type if @has_embedded_images
        end
      end

      #
      # Write the <metadataType> element.
      #
      def write_cell_metadata_type
        attributes = [
          %w[name XLDAPR],
          ['minSupportedVersion', 120000],
          ['copy',                1],
          ['pasteAll',            1],
          ['pasteValues',         1],
          ['merge',               1],
          ['splitFirst',          1],
          ['rowColShift',         1],
          ['clearFormats',        1],
          ['clearComments',       1],
          ['assign',              1],
          ['coerce',              1],
          ['cellMeta',            1]
        ]

        @writer.empty_tag('metadataType', attributes)
      end

      #
      # Write the <metadataType> element.
      #
      def write_value_metadata_type
        attributes = [
          %w[name XLRICHVALUE],
          ['minSupportedVersion', 120000],
          ['copy',                1],
          ['pasteAll',            1],
          ['pasteValues',         1],
          ['merge',               1],
          ['splitFirst',          1],
          ['rowColShift',         1],
          ['clearFormats',        1],
          ['clearComments',       1],
          ['assign',              1],
          ['coerce',              1]
        ]

        @writer.empty_tag('metadataType', attributes)
      end

      #
      # Write the <futureMetadata> element.
      #
      def write_cell_future_metadata
        attributes = [
          %w[name XLDAPR],
          ['count', 1]
        ]

        @writer.tag_elements('futureMetadata', attributes) do
          @writer.tag_elements('bk') do
            @writer.tag_elements('extLst') do
              # Write the ext element.
              write_cell_ext

              @writer.end_tag('ext')
            end
          end
        end
      end

      #
      # Write the <futureMetadata> element.
      #
      def write_value_future_metadata
        num_images = @num_embedded_images

        attributes = [
          %w[name XLRICHVALUE],
          ['count', num_images]
        ]

        @writer.tag_elements('futureMetadata', attributes) do
          (0..(num_images - 1)).each do |i|
            @writer.tag_elements('bk') do
              @writer.tag_elements('extLst') do
                # Write the ext element.
                write_value_ext(i)

                @writer.end_tag('ext')
              end
            end
          end
        end
      end

      #
      # Write the <ext> element.
      #
      def write_cell_ext
        attributes = [['uri', '{bdbb8cdc-fa1e-496e-a857-3c3f30c029c3}']]
        @writer.start_tag('ext', attributes)

        # Write the xda:dynamicArrayProperties element.
        write_xda_dynamic_array_properties
      end

      #
      # Write the <ext> element.
      #
      def write_value_ext(num)
        attributes = [['uri', '{3e2802c4-a4d2-4d8b-9148-e3be6c30e623}']]
        @writer.start_tag('ext', attributes)

        # Write the <xlrd:rvb> element.
        write_xlrd_rvb(num)
      end

      #
      # Write the <xda:dynamicArrayProperties> element.
      #
      def write_xda_dynamic_array_properties
        attributes = [
          ['fDynamic',   1],
          ['fCollapsed', 0]
        ]

        @writer.empty_tag('xda:dynamicArrayProperties', attributes)
      end

      #
      # Write the <cellMetadata> element.
      #
      def write_cell_metadata
        count = 1

        attributes = [['count', count]]

        @writer.tag_elements('cellMetadata', attributes) do
          @writer.tag_elements('bk') do
            # Write the rc element.
            write_rc(1, 0)
          end
        end
      end

      #
      # Write the <valueMetadata> element.
      #
      def write_value_metadata
        count = @num_embedded_images
        type  = 1
        type  = 2 if @has_dynamic_functions

        attributes = [['count', count]]

        @writer.tag_elements('valueMetadata', attributes) do
          (0..(count - 1)).each do |i|
            @writer.tag_elements('bk') do
              # Write the rc element.
              write_rc(type, i)
            end
          end
        end
      end

      #
      # Write the <rc> element.
      #
      def write_rc(type, value)
        attributes = [
          ['t', type],
          ['v', value]
        ]
        @writer.empty_tag('rc', attributes)
      end

      #
      # Write the <xlrd:rvb> element.
      #
      def write_xlrd_rvb(value)
        attributes = [['i', value]]

        @writer.empty_tag('xlrd:rvb', attributes)
      end
    end
  end
end
end

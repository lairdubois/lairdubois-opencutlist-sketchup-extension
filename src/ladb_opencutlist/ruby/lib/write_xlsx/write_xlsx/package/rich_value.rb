# -*- coding: utf-8 -*-
# frozen_string_literal: true

require_relative '../package/xml_writer_simple'
require_relative '../utility'

module Ladb::OpenCutList
module Writexlsx
  module Package
    class RichValue
      include Writexlsx::Utility

      attr_accessor :embedded_images

      def initialize
        @writer          = Package::XMLWriterSimple.new
        @embedded_images = []
      end

      def set_xml_writer(filename)
        @writer.set_xml_writer(filename)
      end

      def assemble_xml_file
        write_xml_declaration do
          write_rv_data
        end
      end

      private

      def write_rv_data
        xmlns = 'http://schemas.microsoft.com/office/spreadsheetml/2017/richdata'

        attributes = [
          ['xmlns', xmlns],
          ['count', @embedded_images.size]
        ]

        @writer.tag_elements('rvData', attributes) do
          @embedded_images.each_with_index do |image, index|
            write_rv(index, image.description, image.decorative)
          end
        end
      end

      #
      # Write the <rv> element.
      #
      def write_rv(index, description, decorative)
        value = 5
        value = 6 if ptrue?(decorative)

        attributes = [['s',  0]]

        @writer.tag_elements('rv', attributes) do
          write_v(index)
          write_v(value)
          write_v(description) if ptrue?(description)
        end
      end

      #
      # Write the <v> element.
      #
      def write_v(data)
        @writer.data_element('v', data)
      end
    end
  end
end
end

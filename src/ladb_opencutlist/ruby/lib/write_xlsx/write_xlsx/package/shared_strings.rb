# -*- coding: utf-8 -*-
# frozen_string_literal: true

require_relative '../package/xml_writer_simple'
require_relative '../utility'

module Ladb::OpenCutList
module Writexlsx
  module Package
    class SharedStrings
      include Writexlsx::Utility

      PRESERVE_SPACE_ATTRIBUTES = ['xml:space', 'preserve'].freeze

      attr_reader :strings

      def initialize
        @writer        = Package::XMLWriterSimple.new
        @strings       = [] # string table
        @strings_index = {} # string table index
        @count         = 0 # count
        @str_unique    = 0
      end

      def index(string, params = {})
        add(string) unless params[:only_query]
        @strings_index[string]
      end

      def add(string)
        unless @strings_index[string]
          str = string.frozen? ? string : string.freeze
          @strings << str
          @str_unique += 1
          @strings_index[str] = @strings.size - 1
        end
        @count += 1
      end

      def string(index)
        @strings[index]
      end

      def empty?
        @strings.empty?
      end

      def set_xml_writer(filename)
        @writer.set_xml_writer(filename)
      end

      def assemble_xml_file
        write_xml_declaration do
          # Write the sst table.
          write_sst { write_sst_strings }
        end
      end

      private

      #
      # Write the <sst> element.
      #
      def write_sst(&block)
        schema       = 'http://schemas.openxmlformats.org'

        attributes =
          [
            ['xmlns',       schema + '/spreadsheetml/2006/main'],
            ['count',       total_count],
            ['uniqueCount', unique_count]
          ]

        @writer.tag_elements('sst', attributes, &block)
      end

      #
      # Write the sst string elements.
      #
      def write_sst_strings
        @strings.each { |string| write_si(string) }
      end

      #
      # Write the <si> element.
      #
      def write_si(string)
        attributes = []

        # Excel escapes control characters with _xHHHH_ and also escapes any
        # literal strings of that type by encoding the leading underscore. So
        # "\0" -> _x0000_ and "_x0000_" -> _x005F_x0000_.
        # The following substitutions deal with those cases.

        # Escape the escape.
        string = string.gsub(/(_x[0-9a-fA-F]{4}_)/, '_x005F\1')

        # Convert control character to the _xHHHH_ escape.
        if string =~ /([\x00-\x08\x0B-\x1F])/
          string = string.gsub(
            /([\x00-\x08\x0B-\x1F])/,
            sprintf("_x%04X_", ::Regexp.last_match(1).ord)
          )
        end

        # Convert character to \xC2\xxx or \xC3\xxx
        string = add_c2_c3(string) if string.bytesize == 1 && 0x80 <= string.ord && string.ord <= 0xFF

        # Add attribute to preserve leading or trailing whitespace.
        attributes << PRESERVE_SPACE_ATTRIBUTES if string =~ /\A\s|\s\Z/

        # Write any rich strings without further tags.
        if string =~ /^<r>/ && string =~ %r{</r>$}
          @writer.si_rich_element(string)
        else
          @writer.si_element(string, attributes)
        end
      end

      def add_c2_c3(string)
        num = string.ord
        if 0x80 <= num && num < 0xC0
          0xC2.chr + num.chr
        else
          0xC3.chr + (num - 0x40).chr
        end
      end

      def total_count
        @count
      end

      def unique_count
        @str_unique
      end
    end
  end
end
end

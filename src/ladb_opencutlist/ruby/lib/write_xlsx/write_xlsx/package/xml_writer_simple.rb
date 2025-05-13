# coding: utf-8
# frozen_string_literal: true

#
# XMLWriterSimple
#
require 'stringio'

module Ladb::OpenCutList
module Writexlsx
  module Package
    class XMLWriterSimple
      XMLNS = 'http://schemas.openxmlformats.org/spreadsheetml/2006/main'

      def initialize
        @io = StringIO.new
        # Will allocate new string once, then use allocated string
        # Key is tag name
        # Only tags without attributes will be cached
        @tag_start_cache = {}
        @tag_end_cache = {}
      end

      def set_xml_writer(filename = nil)
        @filename = filename
      end

      def xml_decl(encoding = 'UTF-8', standalone = true)
        str = %(<?xml version="1.0" encoding="#{encoding}" standalone="#{standalone ? "yes" : "no"}"?>\n)
        io_write(str)
      end

      def tag_elements(tag, attributes = nil)
        start_tag(tag, attributes)
        yield
        end_tag(tag)
      end

      def tag_elements_str(tag, attributes = nil)
        start_tag_str(tag, attributes) +
          yield +
          end_tag_str(tag)
      end

      def start_tag(tag, attr = nil)
        io_write(start_tag_str(tag, attr))
      end

      def start_tag_str(tag, attr = nil)
        if attr.nil? || attr.empty?
          @tag_start_cache[tag] ||= "<#{tag}>"
        else
          "<#{tag}#{key_vals(attr)}>"
        end
      end

      def end_tag(tag)
        io_write(end_tag_str(tag))
      end

      def end_tag_str(tag)
        @tag_end_cache[tag] ||= "</#{tag}>"
      end

      def empty_tag(tag, attr = nil)
        str = "<#{tag}#{key_vals(attr)}/>"
        io_write(str)
      end

      def data_element(tag, data, attr = nil)
        tag_elements(tag, attr) { io_write(escape_data(data)) }
      end

      #
      # Optimised tag writer ?  for shared strings <si> elements.
      #
      def si_element(data, attr)
        tag_elements('si') { data_element('t', data, attr) }
      end

      #
      # Optimised tag writer for shared strings <si> rich string elements.
      #
      def si_rich_element(data)
        io_write("<si>#{data}</si>")
      end

      def characters(data)
        io_write(escape_data(data))
      end

      def crlf
        io_write("\n")
      end

      def close
        File.open(@filename, "wb:utf-8:utf-8") { |f| f << string } if @filename
        @io.close
      end

      def string
        @io.string
      end

      def io_write(str)
        @io << str
        str
      end

      private

      def key_vals(attribute)
        if attribute
          result = "".dup
          attribute.each do |attr|
            # Generate and concat %( #{key}="#{val}") values for attribute pair
            result << " "
            result << attr.first.to_s
            result << '="'
            result << escape_attributes(attr.last).to_s
            result << '"'
          end
          result
        end
      end

      def escape_attributes(str = '')
        return str unless str.respond_to?(:match) && str =~ /["&<>\n]/

        str
          .gsub("&", "&amp;")
          .gsub('"', "&quot;")
          .gsub("<", "&lt;")
          .gsub(">", "&gt;")
          .gsub("\n", "&#xA;")
      end

      def escape_data(str = '')
        if str.respond_to?(:match) && str =~ /[&<>]/
          str.gsub("&", '&amp;')
             .gsub("<", '&lt;')
             .gsub(">", '&gt;')
        else
          str
        end
      end
    end
  end
end
end

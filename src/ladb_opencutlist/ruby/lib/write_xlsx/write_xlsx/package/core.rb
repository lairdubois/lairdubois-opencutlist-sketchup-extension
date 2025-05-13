# -*- coding: utf-8 -*-
# frozen_string_literal: true

require_relative '../package/xml_writer_simple'
require_relative '../utility'

module Ladb::OpenCutList
module Writexlsx
  module Package
    class Core
      include Writexlsx::Utility

      App_package  = 'application/vnd.openxmlformats-package.'
      App_document = 'application/vnd.openxmlformats-officedocument.'

      def initialize
        @writer = Package::XMLWriterSimple.new
        @properties = {}
        @createtime  = [Time.now.gmtime]
      end

      def set_xml_writer(filename)
        @writer.set_xml_writer(filename)
      end

      def assemble_xml_file
        write_xml_declaration do
          write_cp_core_properties { write_cp_core_properties_base }
        end
      end

      def set_properties(properties)
        @properties = properties
      end

      private

      def write_cp_core_properties_base
        write_dc_title
        write_dc_subject
        write_dc_creator
        write_cp_keywords
        write_dc_description
        write_cp_last_modified_by
        write_dcterms_created
        write_dcterms_modified
        write_cp_category
        write_cp_content_status
      end

      #
      # Convert a gmtime/localtime() date to a ISO 8601 style
      # "2010-01-01T00:00:00Z" date. Excel always treats this as
      # a utc date/time.
      #
      def datetime_to_iso8601_date(gm_time = nil)
        gm_time ||= Time.now.gmtime

        gm_time.strftime('%Y-%m-%dT%H:%M:%SZ')
      end

      #
      # Write the <cp:coreProperties> element.
      #
      def write_cp_core_properties(&block)
        xmlns_cp       = 'http://schemas.openxmlformats.org/package/2006/metadata/core-properties'
        xmlns_dc       = 'http://purl.org/dc/elements/1.1/'
        xmlns_dcterms  = 'http://purl.org/dc/terms/'
        xmlns_dcmitype = 'http://purl.org/dc/dcmitype/'
        xmlns_xsi      = 'http://www.w3.org/2001/XMLSchema-instance'

        attributes = [
          ['xmlns:cp',       xmlns_cp],
          ['xmlns:dc',       xmlns_dc],
          ['xmlns:dcterms',  xmlns_dcterms],
          ['xmlns:dcmitype', xmlns_dcmitype],
          ['xmlns:xsi',      xmlns_xsi]
        ]

        @writer.tag_elements('cp:coreProperties', attributes, &block)
      end

      #
      # Write the <dc:creator> element.
      #
      def write_dc_creator
        write_base(:author, 'dc:creator', '')
      end

      #
      # Write the <cp:lastModifiedBy> element.
      #
      def write_cp_last_modified_by
        write_base(:author, 'cp:lastModifiedBy', '')
      end

      #
      # Write the <dcterms:created> element.
      #
      def write_dcterms_created
        write_dcterms('dcterms:created')
      end

      #
      # Write the <dcterms:modified> element.
      #
      def write_dcterms_modified
        write_dcterms('dcterms:modified')
      end

      def write_dcterms(tag)
        @writer.data_element(tag, dcterms_date, [['xsi:type', 'dcterms:W3CDTF']])
      end

      def dcterms_date
        datetime_to_iso8601_date(@properties[:created])
      end

      #
      # Write the <dc:title> element.
      #
      def write_dc_title
        write_base(:title, 'dc:title')
      end

      #
      # Write the <dc:subject> element.
      #
      def write_dc_subject
        write_base(:subject, 'dc:subject')
      end

      #
      # Write the <cp:keywords> element.
      #
      def write_cp_keywords
        write_base(:keywords, 'cp:keywords')
      end

      #
      # Write the <dc:description> element.
      #
      def write_dc_description
        write_base(:comments, 'dc:description')
      end

      #
      # Write the <cp:category> element.
      #
      def write_cp_category
        write_base(:category, 'cp:category')
      end

      #
      # Write the <cp:contentStatus> element.
      #
      def write_cp_content_status
        write_base(:status, 'cp:contentStatus')
      end

      def write_base(key, tag, default = nil)
        data = @properties[key] || default
        return unless data

        @writer.data_element(tag, data)
      end
    end
  end
end
end

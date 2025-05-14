# -*- encoding: utf-8 -*-
# frozen_string_literal: true

require 'delegate'
require_relative 'package/xml_writer_simple'

module Ladb::OpenCutList
module Writexlsx
  class Sheets < DelegateClass(Array)
    include Writexlsx::Utility

    BASE_NAME = { sheet: 'Sheet', chart: 'Chart' }  # :nodoc:

    def initialize
      super([])
    end

    def chartsheet_count
      chartsheets.count
    end

    def sheetname_count
      count - chartname_count
    end

    def chartname_count
      chartsheet_count
    end

    def make_and_check_sheet_chart_name(type, name)
      count = sheet_chart_count(type)
      name = "#{BASE_NAME[type]}#{count + 1}" unless ptrue?(name)

      check_valid_sheetname(name)
      name
    end

    def write_sheets(writer)
      writer.tag_elements('sheets') do
        id_num = 1
        each do |sheet|
          write_sheet(writer, sheet, id_num)
          id_num += 1
        end
      end
    end

    def write_worksheet_files(package_dir)
      dir = "#{package_dir}/xl/worksheets"
      worksheets.each_with_index do |sheet, index|
        write_sheet_files(dir, sheet, index)
      end
    end

    def write_chartsheet_files(package_dir)
      dir = "#{package_dir}/xl/chartsheets"
      chartsheets.each_with_index do |sheet, index|
        write_sheet_files(dir, sheet, index)
      end
    end

    def write_vml_files(package_dir)
      dir = "#{package_dir}/xl/drawings"
      index = 1
      each do |sheet|
        next if !sheet.has_vml? and !sheet.has_header_vml?

        FileUtils.mkdir_p(dir)

        if sheet.has_vml?
          vml = Package::Vml.new
          vml.set_xml_writer("#{dir}/vmlDrawing#{index}.vml")
          vml.assemble_xml_file(
            sheet.vml_data_id, sheet.vml_shape_id,
            sheet.sorted_comments, sheet.buttons_data
          )
          index += 1
        end
        next unless sheet.has_header_vml?

        vml = Package::Vml.new
        vml.set_xml_writer("#{dir}/vmlDrawing#{index}.vml")
        vml.assemble_xml_file(
          sheet.vml_header_id, sheet.vml_header_id * 1024,
          [], [], sheet.header_images_data
        )
        write_vml_drawing_rels_files(package_dir, sheet, index)
        index += 1
      end
    end

    def write_comment_files(package_dir)
      self.select { |sheet| sheet.has_comments? }
          .each_with_index do |sheet, index|
        FileUtils.mkdir_p("#{package_dir}/xl/drawings")
        sheet.comments.set_xml_writer("#{package_dir}/xl/comments#{index + 1}.xml")
        sheet.comments.assemble_xml_file
      end
    end

    def write_table_files(package_dir)
      unless tables.empty?
        dir = "#{package_dir}/xl/tables"
        FileUtils.mkdir_p(dir)
        tables.each_with_index do |table, index|
          table.set_xml_writer("#{dir}/table#{index + 1}.xml")
          table.assemble_xml_file
        end
      end
    end

    def write_chartsheet_rels_files(package_dir)
      write_sheet_rels_files_base(
        chartsheets, "#{package_dir}/xl/chartsheets/_rels", 'sheet'
      )
    end

    def write_drawing_rels_files(package_dir)
      dir = "#{package_dir}/xl/drawings/_rels"

      index = 0
      each do |sheet|
        index += 1 if !sheet.drawing_links[0].empty? || sheet.has_shapes?

        next if sheet.drawing_links[0].empty?

        FileUtils.mkdir_p(dir)

        rels = Package::Relationships.new

        sheet.drawing_links.each do |drawing_datas|
          drawing_datas.each do |drawing_data|
            rels.add_document_relationship(*drawing_data)
          end
        end

        # Create the .rels file such as /xl/drawings/_rels/sheet1.xml.rels.
        rels.set_xml_writer("#{dir}/drawing#{index}.xml.rels")
        rels.assemble_xml_file
      end
    end

    def write_vml_drawing_rels_files(package_dir, worksheet, index)
      # Create the drawing .rels dir.
      dir = "#{package_dir}/xl/drawings/_rels"
      FileUtils.mkdir_p(dir)

      rels = Package::Relationships.new

      worksheet.vml_drawing_links.each do |drawing_data|
        rels.add_document_relationship(*drawing_data)
      end

      # Create the .rels file such as /xl/drawings/_rels/vmlDrawing1.vml.rels.
      rels.set_xml_writer("#{dir}/vmlDrawing#{index}.vml.rels")
      rels.assemble_xml_file
    end

    def write_worksheet_rels_files(package_dir)
      write_sheet_rels_files_base(
        worksheets, "#{package_dir}/xl/worksheets/_rels", 'sheet'
      )
    end

    def write_sheet_rels_files_base(sheets, dir, body)
      sheets.each_with_index do |sheet, index|
        next if sheet.external_links.empty?

        FileUtils.mkdir_p(dir)

        rels = Package::Relationships.new

        sheet.external_links.each do |link_datas|
          link_datas.each do |link_data|
            rels.add_worksheet_relationship(*link_data)
          end
        end

        # Create the .rels file such as /xl/worksheets/_rels/sheet1.xml.rels.
        rels.set_xml_writer("#{dir}/#{body}#{index + 1}.xml.rels")
        rels.assemble_xml_file
      end
    end

    def tables
      inject([]) { |tables, sheet| tables + sheet.tables }.flatten
    end

    def tables_count
      tables.count
    end

    def index_by_name(sheetname)
      name = sheetname.sub(/^'/, '').sub(/'$/, '')
      collect { |sheet| sheet.name }.index(name)
    end

    def worksheets
      reject { |worksheet| worksheet.is_chartsheet? }
    end

    def chartsheets
      self.select { |worksheet| worksheet.is_chartsheet? }
    end

    def visible_first
      reject { |worksheet| worksheet.hidden? }.first
    end

    private

    def sheet_chart_count(type)
      case type
      when :sheet
        sheetname_count
      when :chart
        chartname_count
      end
    end

    def check_valid_sheetname(name)
      # Check that sheet name is <= 31. Excel limit.
      raise "Sheetname #{name} must be <= #{SHEETNAME_MAX} chars" if name.length > SHEETNAME_MAX

      # Check that sheetname doesn't contain any invalid characters
      invalid_char = %r{[\[\]:*?/\\]}
      raise 'Invalid character []:*?/\\ in worksheet name: ' + name if name =~ invalid_char

      # Check that sheetname doesn't start or end with an apostrophe.
      raise "Worksheet name #{name} cannot start or end with an " if name =~ /^'/ || name =~ /'$/

      # Check that the worksheet name doesn't already exist since this is a fatal
      # error in Excel 97. The check must also exclude case insensitive matches.
      raise "apostropheWorksheet name '#{name}', with case ignored, is already used." unless is_sheetname_uniq?(name)
    end

    def is_sheetname_uniq?(name)
      each do |worksheet|
        return false if name.downcase == worksheet.name.downcase
      end
      true
    end

    def write_sheet_files(dir, sheet, index)
      FileUtils.mkdir_p(dir)
      sheet.set_xml_writer("#{dir}/sheet#{index + 1}.xml")
      sheet.assemble_xml_file
    end

    def write_sheet(writer, sheet, sheet_id) # :nodoc:
      attributes = [
        ['name',    sheet.name],
        ['sheetId', sheet_id]
      ]

      if sheet.hidden?
        attributes << %w[state hidden]
      elsif sheet.very_hidden?
        attributes << %w[state veryHidden]
      end
      attributes << r_id_attributes(sheet_id)
      writer.empty_tag('sheet', attributes)
    end
  end
end
end

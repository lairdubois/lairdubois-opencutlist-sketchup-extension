# -*- coding: utf-8 -*-
# frozen_string_literal: true

require_relative 'write_xlsx/workbook'

#
# write is gem to create a new file in the Excel 2007+ XLSX format,
# and you can use the same interface as writeexcel gem.
# write_xlsx is converted from Perl’s module github.com/jmcnamara/excel-writer-xlsx .
#
# == Description
# The WriteXLSX supports the following features:
#
#    Multiple worksheets
#    Strings and numbers
#    Unicode text
#    Rich string formats
#    Formulas (including array formats)
#    cell formatting
#    Embedded images
#    Charts
#    Autofilters
#    Data validation
#    Conditional formatting
#    Tables
#    Hyperlinks
#    Defined names
#    Grouping/Outlines
#    Cell comments
#    Panes
#    Page set-up and printing options
# WriteXLSX uses the same interface as WriteExcel gem.
#
# == Synopsis
# To write a string, a formatted string, a number and a formula to the
# first worksheet in an Excel XMLX spreadsheet called ruby.xlsx:
#
#   require 'write_xlsx'
#
#   # Create a new Excel workbook
#   workbook = WriteXLSX.new('ruby.xlsx')
#
#   # Add a worksheet
#   worksheet = workbook.add_worksheet
#
#   #  Add and define a format
#   format = workbook.add_format # Add a format
#   format.set_bold
#   format.set_color('red')
#   format.set_align('center')
#
#   # Write a formatted and unformatted string, row and column notation.
#   col = row = 0
#   worksheet.write(row, col, "Hi Excel!", format)
#   worksheet.write(1,   col, "Hi Excel!")
#
#   # Write a number and a formula using A1 notation
#   worksheet.write('A3', 1.2345)
#   worksheet.write('A4', '=SIN(PI()/4)')
#
#   workbook.close
#
# == Description
#
# The WriteXLSX gem can be used to create an Excel file in the 2007+ XLSX
# format.
#
# The XLSX format is the Office Open XML(OOXML) format used by Excel 2007
# and later.
#
# Multiple worksheets can be added to a workbook and formatting can be applied
# to cells. Text, numbers and formulas can be written to the cells.
#
# This module cannot, as yet, be used to write to an exsisting Excel XLSX file.
#
# == WriteXLSX and WriteExcel
#
# WriteXLSX uses the same interface as the WriteExcel gem which produces an
# Excel file in binary XLS format.
#
# WriteXLSX supports all the features of WriteExcel and in some cases has more
# functionally.
#
# == Other Methods
#
# see Writexlsx::Workbook, Writexlsx::Worksheet, Writexlsx::Chart etc.
#
module Ladb::OpenCutList
class WriteXLSX < Writexlsx::Workbook
end

class WriteXLSXInsufficientArgumentError < StandardError
end

class WriteXLSXDimensionError < StandardError
end

class WriteXLSXOptionParameterError < StandardError
end
end

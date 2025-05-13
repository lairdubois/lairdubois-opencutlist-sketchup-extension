# -*- encoding: utf-8 -*-
# frozen_string_literal: true

module Ladb::OpenCutList
module Writexlsx
  class Worksheet
    class DataValidation   # :nodoc:
      include Writexlsx::Utility

      attr_reader :value, :source, :minimum, :maximum, :validate, :criteria
      attr_reader :error_type, :cells, :other_cells
      attr_reader :ignore_blank, :dropdown, :show_input, :show_error
      attr_reader :error_title, :error_message, :input_title, :input_message

      def initialize(*args)
        # Check for a cell reference in A1 notation and substitute row and column.
        if (row_col_array = row_col_notation(args.first))
          case row_col_array.size
          when 2
            row1, col1 = row_col_array
            row2, col2, options = args[1..-1]
          when 4
            row1, col1, row2, col2 = row_col_array
            options = args[1]
          end
        else
          row1, col1, row2, col2, options = args
        end

        if row2.respond_to?(:keys)
          options_to_instance_variable(row2.dup)
          row2 = row1
          col2 = col1
        elsif options.respond_to?(:keys)
          options_to_instance_variable(options.dup)
        else
          raise WriteXLSXInsufficientArgumentError
        end
        raise WriteXLSXInsufficientArgumentError if [row1, col1, row2, col2].include?(nil)

        check_for_valid_input_params

        check_dimensions(row1, col1)
        check_dimensions(row2, col2)
        @cells = [[row1, col1, row2, col2]]

        @value = @source  if @source
        @value = @minimum if @minimum

        @validate = valid_validation_type[@validate.downcase]

        # No action is required for validate type 'any'
        # unless there are input messages.
        if @validate == 'none' && !@input_message && !@input_title
          @validate_none = true
          return
        end

        # The any, list and custom validations don't have a criteria
        # so we use a default of 'between'
        if %w[none list custom].include?(@validate)
          @criteria  = 'between'
          @maximum   = nil
        end

        check_criteria_required
        check_valid_citeria_types
        @criteria = valid_criteria_type[@criteria.downcase]

        check_maximum_value_when_criteria_is_between_or_notbetween
        @error_type = has_key?(:error_type) ? error_type_hash[@error_type.downcase] : 0

        convert_date_time_value_if_required
        # Check that the input title doesn't exceed the maximum length.
        raise "Length of input title '#{@input_title}' exceeds Excel's limit of 32" if @input_title && @input_title.length > 32
        # Check that the input message doesn't exceed the maximum length.
        raise "Length of input message '#{@input_message}' exceeds Excel's limit of 255" if @input_message && @input_message.length > 255

        set_some_defaults

        # A (for now) undocumented parameter to pass additional cell ranges.
        @other_cells.each { |cells| @cells << cells } if has_key?(:other_cells)
      end

      def options_to_instance_variable(params)
        params.each do |k, v|
          instance_variable_set("@#{k}", v)
        end
      end

      def keys
        instance_variables.collect { |v| v.to_s.sub(/@/, '').to_sym }
      end

      def validate_none?
        @validate_none
      end

      #
      # Write the <dataValidation> element.
      #
      def write_data_validation(writer) # :nodoc:
        @writer = writer
        if @validate == 'none'
          @writer.empty_tag('dataValidation', attributes)
        else
          @writer.tag_elements('dataValidation', attributes) do
            # Write the formula1 element.
            write_formula_1(@value)
            # Write the formula2 element.
            write_formula_2(@maximum) if @maximum
          end
        end
      end

      private

      #
      # Write the <formula1> element.
      #
      def write_formula_1(formula) # :nodoc:
        # Convert a list array ref into a comma separated string.
        formula   = %("#{formula.join(",")}") if formula.is_a?(Array)

        formula = formula.sub(/^=/, '') if formula.respond_to?(:sub)

        @writer.data_element('formula1', formula)
      end

      #
      # Write the <formula2> element.
      #
      def write_formula_2(formula) # :nodoc:
        formula = formula.sub(/^=/, '') if formula.respond_to?(:sub)

        @writer.data_element('formula2', formula)
      end

      def attributes
        sqref      = ''
        attributes = []

        # Set the cell range(s) for the data validation.
        @cells.each do |cells|
          # Add a space between multiple cell ranges.
          sqref += ' ' if sqref != ''

          row_first, col_first, row_last, col_last = cells

          # Swap last row/col for first row/col as necessary
          row_first, row_last = row_last, row_first if row_first > row_last
          col_first, col_last = col_last, col_first if col_first > col_last

          sqref += xl_range(row_first, row_last, col_first, col_last)
        end

        if @validate != 'none'
          attributes << ['type', @validate]
          attributes << ['operator', @criteria] if @criteria != 'between'
        end

        if @error_type
          attributes << %w[errorStyle warning] if @error_type == 1
          attributes << %w[errorStyle information] if @error_type == 2
        end
        attributes << ['allowBlank',       1] if @ignore_blank != 0
        attributes << ['showDropDown',     1] if @dropdown     == 0
        attributes << ['showInputMessage', 1] if @show_input   != 0
        attributes << ['showErrorMessage', 1] if @show_error   != 0

        attributes << ['errorTitle',  @error_title]   if @error_title
        attributes << ['error',       @error_message] if @error_message
        attributes << ['promptTitle', @input_title]   if @input_title
        attributes << ['prompt',      @input_message] if @input_message
        attributes << ['sqref',       sqref]
      end

      def has_key?(key)
        keys.index(key)
      end

      def set_some_defaults
        @ignore_blank ||= 1
        @dropdown     ||= 1
        @show_input   ||= 1
        @show_error   ||= 1
      end

      def check_for_valid_input_params
        check_parameter(self, valid_validation_parameter, 'data_validation')

        raise WriteXLSXOptionParameterError, "Parameter :validate is required in data_validation()" unless has_key?(:validate)

        unless valid_validation_type.has_key?(@validate.downcase)
          raise WriteXLSXOptionParameterError,
                "Unknown validation type '#{@validate}' for parameter :validate in data_validation()"
        end
        if @error_type && !error_type_hash.has_key?(@error_type.downcase)
          raise WriteXLSXOptionParameterError,
                "Unknown criteria type '#param[:error_type}' for parameter :error_type in data_validation()"
        end
      end

      def check_criteria_required
        raise WriteXLSXOptionParameterError, "Parameter :criteria is required in data_validation()" unless has_key?(:criteria)
      end

      def check_maximum_value_when_criteria_is_between_or_notbetween
        if @criteria == 'between' || @criteria == 'notBetween'
          unless has_key?(:maximum)
            raise WriteXLSXOptionParameterError,
                  "Parameter :maximum is required in data_validation() when using :between or :not between criteria"
          end
        else
          @maximum = nil
        end
      end

      def check_valid_citeria_types
        unless valid_criteria_type.has_key?(@criteria.downcase)
          raise WriteXLSXOptionParameterError,
                "Unknown criteria type '#{@criteria}' for parameter :criteria in data_validation()"
        end
      end

      def convert_date_time_value_if_required
        if @validate == 'date' || @validate == 'time'
          date_time = convert_date_time(@value)
          @value = date_time if date_time

          if @maximum
            date_time = convert_date_time(@maximum)
            @maximum = date_time if date_time
          end
        end
      end

      def error_type_hash
        { 'stop' => 0, 'warning' => 1, 'information' => 2 }
      end

      def valid_validation_type # :nodoc:
        {
          'any'          => 'none',
          'any value'    => 'none',
          'whole number' => 'whole',
          'whole'        => 'whole',
          'integer'      => 'whole',
          'decimal'      => 'decimal',
          'list'         => 'list',
          'date'         => 'date',
          'time'         => 'time',
          'text length'  => 'textLength',
          'length'       => 'textLength',
          'custom'       => 'custom'
        }
      end

      # List of valid input parameters.
      def valid_validation_parameter
        %i[
          validate
          criteria
          value
          source
          minimum
          maximum
          ignore_blank
          dropdown
          show_input
          input_title
          input_message
          show_error
          error_title
          error_message
          error_type
          other_cells
        ]
      end

      # List of valid criteria types.
      def valid_criteria_type  # :nodoc:
        {
          'between'                  => 'between',
          'not between'              => 'notBetween',
          'equal to'                 => 'equal',
          '='                        => 'equal',
          '=='                       => 'equal',
          'not equal to'             => 'notEqual',
          '!='                       => 'notEqual',
          '<>'                       => 'notEqual',
          'greater than'             => 'greaterThan',
          '>'                        => 'greaterThan',
          'less than'                => 'lessThan',
          '<'                        => 'lessThan',
          'greater than or equal to' => 'greaterThanOrEqual',
          '>='                       => 'greaterThanOrEqual',
          'less than or equal to'    => 'lessThanOrEqual',
          '<='                       => 'lessThanOrEqual'
        }
      end

      def date_1904?
        @date_1904
      end
    end
  end
end
end

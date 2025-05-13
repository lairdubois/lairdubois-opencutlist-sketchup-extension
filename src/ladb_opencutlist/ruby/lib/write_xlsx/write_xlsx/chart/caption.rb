# -*- coding: utf-8 -*-
# frozen_string_literal: true

module Ladb::OpenCutList
module Writexlsx
  class Chart
    class Caption
      include Writexlsx::Utility

      attr_accessor :name, :formula, :data_id, :name_font
      attr_reader :layout, :overlay, :none

      def initialize(chart)
        @chart = chart
      end

      def merge_with_hash(params) # :nodoc:
        @name, @formula = chart.process_names(params[:name], params[:name_formula])
        @data_id   = chart.data_id(@formula, params[:data])
        @name_font = convert_font_args(params[:name_font])
        @layout    = chart.layout_properties(params[:layout], 1)

        # Set the title overlay option.
        @overlay  = params[:overlay]

        # Set the no automatic title option.
        @none = params[:none]
      end

      private

      attr_reader :chart
    end
  end
end
end

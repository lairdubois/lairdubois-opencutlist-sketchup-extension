# -*- coding: utf-8 -*-
# frozen_string_literal: true

module Ladb::OpenCutList
module Writexlsx
  class InsertedChart
    include Writexlsx::Utility

    attr_reader :row, :col, :chart, :x_offset, :y_offset
    attr_reader :x_scale, :y_scale
    attr_reader :anchor, :description, :decorative

    def initialize(
          row, col, chart, x_offset, y_offset, x_scale, y_scale,
          anchor, description, decorative
        )
      @row         = row
      @col         = col
      @chart       = chart
      @x_offset    = x_offset
      @y_offset    = y_offset
      @x_scale     = x_scale || 0
      @y_scale     = y_scale || 0
      @anchor      = anchor
      @description = description
      @decorative  = decorative
    end

    def name
      chart.name
    end

    def scaled_width
      width = chart.width if ptrue?(chart.width)
      (0.5 + (width * x_scale)).to_i
    end

    def scaled_height
      height = chart.height if ptrue?(chart.height)
      (0.5 + (height * y_scale)).to_i
    end
  end
end
end

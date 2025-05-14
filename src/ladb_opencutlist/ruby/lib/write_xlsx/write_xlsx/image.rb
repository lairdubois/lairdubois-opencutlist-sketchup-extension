# -*- coding: utf-8 -*-
# frozen_string_literal: true

require_relative 'image_property'

module Ladb::OpenCutList
module Writexlsx
  class Image
    attr_reader :row, :col, :x_offset, :y_offset, :x_scale, :y_scale
    attr_reader :url, :tip, :anchor, :description, :decorative

    def initialize(
          row, col, image, x_offset, y_offset, x_scale, y_scale,
          url, tip, anchor, description, decorative
        )
      @row         = row
      @col         = col
      @image       = ImageProperty.new(image)
      @x_offset    = x_offset
      @y_offset    = y_offset
      @x_scale     = x_scale
      @y_scale     = y_scale
      @url         = url
      @tip         = tip
      @anchor      = anchor
      @description = description
      @decorative  = decorative
    end

    def scaled_width
      width * x_scale * 96.0 / x_dpi
    end

    def scaled_height
      height * y_scale * 96.0 / y_dpi
    end

    def width_emus
      (0.5 + (scaled_width * 9_525)).to_i
    end

    def height_emus
      (0.5 + (scaled_height * 9_525)).to_i
    end

    def image
      @image.filename
    end

    def type
      @image.type
    end

    def width
      @image.width
    end

    def height
      @image.height
    end

    def name
      @image.name
    end

    def x_dpi
      @image.x_dpi
    end

    def y_dpi
      @image.y_dpi
    end

    def md5
      @image.md5
    end

    def filename
      @image.filename
    end

    def position
      @image.position
    end

    def ref_id
      @image.ref_id
    end
  end
end
end

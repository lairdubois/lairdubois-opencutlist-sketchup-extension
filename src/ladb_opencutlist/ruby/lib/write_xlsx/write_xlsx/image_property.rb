# -*- coding: utf-8 -*-
# frozen_string_literal: true

require 'digest/md5'

module Ladb::OpenCutList
module Writexlsx
  class ImageProperty
    attr_reader :type, :width, :height, :name, :x_dpi, :y_dpi, :md5
    attr_reader :filename, :description, :decorative
    attr_accessor :ref_id, :body, :position

    def initialize(filename, options = {})
      @filename    = filename
      @description = options[:description]
      @decorative  = options[:decorative]
      @position    = options[:position]
      @name        = File.basename(filename)

      # Open the image file and import the data.
      data = File.binread(filename)
      @md5  = Digest::MD5.hexdigest(data)
      if data.unpack1('x A3') == 'PNG'
        process_png(data)
      elsif data.unpack1('n') == 0xFFD8
        process_jpg(data)
      elsif data.unpack1('A4') == 'GIF8'
        process_gif(data)
      elsif data.unpack1('A2') == 'BM'
        process_bmp(data)
      else
        # TODO. Add Image::Size to support other types.
        raise "Unsupported image format for file: #{filename}\n"
      end

      # Set a default dpi for images with 0 dpi.
      @x_dpi = 96 if @x_dpi == 0
      @y_dpi = 96 if @y_dpi == 0
    end

    #
    # Extract width and height information from a PNG file.
    #
    def process_png(data)
      @type   = 'png'
      @width  = 0
      @height = 0
      @x_dpi  = 96
      @y_dpi  = 96

      offset = 8
      data_length = data.size

      # Search through the image data to read the height and width in th the
      # IHDR element. Also read the DPI in the pHYs element.
      while offset < data_length

        length = data[offset + 0, 4].unpack1("N")
        png_type   = data[offset + 4, 4].unpack1("A4")

        case png_type
        when "IHDR"
          @width  = data[offset + 8, 4].unpack1("N")
          @height = data[offset + 12, 4].unpack1("N")
        when "pHYs"
          x_ppu = data[offset + 8,  4].unpack1("N")
          y_ppu = data[offset + 12, 4].unpack1("N")
          units = data[offset + 16, 1].unpack1("C")

          if units == 1
            @x_dpi = x_ppu * 0.0254
            @y_dpi = y_ppu * 0.0254
          end
        end

        offset = offset + length + 12

        break if png_type == "IEND"
      end
      raise "#{@filename}: no size data found in png image.\n" unless @height
    end

    def process_jpg(data)
      @type  = 'jpeg'
      @x_dpi = 96
      @y_dpi = 96

      offset = 2
      data_length = data.bytesize

      # Search through the image data to read the JPEG markers.
      while offset < data_length
        marker  = data[offset + 0, 2].unpack1("n")
        length  = data[offset + 2, 2].unpack1("n")

        # Read the height and width in the 0xFFCn elements
        # (Except C4, C8 and CC which aren't SOF markers).
        if (marker & 0xFFF0) == 0xFFC0 &&
           marker != 0xFFC4 && marker != 0xFFCC
          @height = data[offset + 5, 2].unpack1("n")
          @width  = data[offset + 7, 2].unpack1("n")
        end

        # Read the DPI in the 0xFFE0 element.
        if marker == 0xFFE0
          units     = data[offset + 11, 1].unpack1("C")
          x_density = data[offset + 12, 2].unpack1("n")
          y_density = data[offset + 14, 2].unpack1("n")

          if units == 1
            @x_dpi = x_density
            @y_dpi = y_density
          elsif units == 2
            @x_dpi = x_density * 2.54
            @y_dpi = y_density * 2.54
          end
        end

        offset += length + 2
        break if marker == 0xFFDA
      end

      raise "#{@filename}: no size data found in jpeg image.\n" unless @height
    end

    #
    # Extract width and height information from a GIF file.
    #
    def process_gif(data)
      @type  = 'gif'
      @x_dpi = 96
      @y_dpi = 96

      @width  = data[6, 2].unpack1("v")
      @height = data[8, 2].unpack1("v")

      raise "#{@filename}: no size data found in gif image.\n" if @height.nil?
    end

    # Extract width and height information from a BMP file.
    def process_bmp(data)       # :nodoc:
      @type = 'bmp'

      # Check that the file is big enough to be a bitmap.
      raise "#{@filename} doesn't contain enough data." if data.bytesize <= 0x36

      # Read the bitmap width and height. Verify the sizes.
      @width, @height = data.unpack("x18 V2")
      raise "#{@filename}: largest image width #{width} supported is 65k." if width > 0xFFFF
      raise "#{@filename}: largest image height supported is 65k." if @height > 0xFFFF

      # Read the bitmap planes and bpp data. Verify them.
      planes, bitcount = data.unpack("x26 v2")
      raise "#{@filename} isn't a 24bit true color bitmap." unless bitcount == 24
      raise "#{@filename}: only 1 plane supported in bitmap image." unless planes == 1

      # Read the bitmap compression. Verify compression.
      compression = data.unpack1("x30 V")
      raise "#{@filename}: compression not supported in bitmap image." unless compression == 0

      @x_dpi = @y_dpi = 96
    end
  end
end
end

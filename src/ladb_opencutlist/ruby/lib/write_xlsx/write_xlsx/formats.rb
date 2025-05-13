# -*- encoding: utf-8 -*-
# frozen_string_literal: true

require_relative 'package/xml_writer_simple'

module Ladb::OpenCutList
module Writexlsx
  class Formats
    include Writexlsx::Utility

    attr_reader :formats, :xf_format_indices, :dxf_format_indices

    def initialize
      @formats = []
      @xf_format_indices = {}
      @dxf_format_indices = {}
    end

    def xf_index_by_key(key)
      @xf_format_indices[key]
    end

    def set_xf_index_by_key(key)
      @xf_format_indices[key] ||= 1 + @xf_format_indices.size
    end

    def dxf_index_by_key(key)
      @dxf_format_indices[key]
    end

    def set_dxf_index_by_key(key)
      @dxf_format_indices[key] ||= @dxf_format_indices.size
    end
  end
end
end

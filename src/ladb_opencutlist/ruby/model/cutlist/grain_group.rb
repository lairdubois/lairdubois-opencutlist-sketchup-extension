module Ladb::OpenCutList

  require_relative '../data_container'
  require_relative '../../helper/def_helper'
  require_relative '../../helper/hashable_helper'

  class GrainGroup < DataContainer

    include DefHelper
    include HashableHelper

    attr_reader :batch_index, :batch_count,
                :name,
                :items

    def initialize(_def, _x_axis, _z_axis, batch_index, batch_count)
      @_def = _def

      @_x_axis = _x_axis
      @_z_axis = _z_axis

      @batch_index = batch_index
      @batch_count = batch_count

      @name = _def.name
      @name += " (#{batch_index + 1}/#{batch_count})" if batch_count > 1

      @items = []

    end

    def x_axis
      @_x_axis
    end

    def z_axis
      @_z_axis
    end

    def add_item(item)
      @items << item
    end

  end

end
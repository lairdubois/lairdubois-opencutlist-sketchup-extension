module Ladb::OpenCutList

  require_relative '../data_container'
  require_relative '../../helper/def_helper'
  require_relative '../../helper/hashable_helper'
  require_relative '../../utils/color_utils'

  class OutlinerMaterial < DataContainer

    include DefHelper
    include HashableHelper

    attr_reader :name, :display_name, :type, :color

    def initialize(_def)
      @_def = _def

      @name = _def.material.name
      @display_name = _def.material.display_name
      @type = _def.material_attributes.type
      @color = ColorUtils.color_to_hex(_def.material.color)

    end

  end

end
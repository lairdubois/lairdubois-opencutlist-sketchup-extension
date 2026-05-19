module Ladb::OpenCutList

  require_relative '../data_container'
  require_relative '../../helper/def_helper'
  require_relative '../../helper/hashable_helper'

  class GrainItem < DataContainer

    include DefHelper
    include HashableHelper

    def initialize(_def, _part)
      @_def = _def
      @_part = _part
    end

    def part
      @_part
    end

  end

end
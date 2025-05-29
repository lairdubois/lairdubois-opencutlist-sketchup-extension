module Ladb::OpenCutList

  require_relative '../data_container'

  class FormulaData < DataContainer

    def get_binding
      binding
    end

  end

end

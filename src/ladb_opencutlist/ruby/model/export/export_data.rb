module Ladb::OpenCutList

  require_relative '../data_container'

  class ExportData < DataContainer

    def get_binding
      binding
    end

  end

end

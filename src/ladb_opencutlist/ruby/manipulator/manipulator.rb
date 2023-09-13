module Ladb::OpenCutList

  class Manipulator

    attr_accessor :data

    def initialize()
      @data = {}
    end

    # -----

    def reset_cache
      # TODO implement it in sub classes
    end

  end

end

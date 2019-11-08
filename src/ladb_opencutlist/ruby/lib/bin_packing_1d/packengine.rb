module Ladb::OpenCutList::BinPacking1D

  require_relative 'packing1d'
  require_relative 'options'

  class PackEngine < Packing1D
  
    def initialize(options)
      @options = options
      @bins = []
      @parts = []
    end

    def add_bin(length)
      # TODO
    end
    
    def add_part(length, data = nil)
      # TODO
    end

    def run

      # Check bins definitions
      if @options.base_bin_length == 0 and @bins.empty?
        return nil, ERROR_NO_BIN
      end

      return nil, ERROR_NONE
    end
    
  end
end

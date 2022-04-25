# frozen_string_literal: true

module Ladb::OpenCutList::BinPacking1D
  #
  # Implements First-Fit Decreasing Heuristic
  #
  class PackerFFD < Packer
    #
    # run the bin packing optimization.
    #
    def run
      @gstat[:algorithm] = ALG_FFD

      remove_unfit
      if @boxes.empty?
        @unplaced_boxes = @unfit_boxes unless @unfit_boxes.empty?
        return ERROR_NO_BIN
      end

      @error = first_fit_decreasing
      prepare_results if @error == ERROR_NONE
      @error
    end

    #
    # First Fit Decreasing algorithm as an alternative. Runs fast!
    #
    def first_fit_decreasing
      @bins += @leftovers
      @bins << Bin.new(@options.base_bin_length, BIN_TYPE_AUTO_GENERATED, @options) if @bins.empty?

      @boxes.each do |box|
        packed = false
        # Box can be packed into one of the existing bins, first fit wins
        @bins.each do |bin|
          next unless box.length <= bin.current_leftover

          bin.add(box)
          packed = true
          break
        end
        # box could not be packed, create new bin if allowed to
        unless packed
          if @options.base_bin_length > EPS
            bin = Bin.new(@options.base_bin_length, BIN_TYPE_AUTO_GENERATED, @options)
            if box.length <= bin.current_leftover
              bin.add(box)
              @bins << bin
            else
              @unplaced_boxes << box
            end
          else
            @unplaced_boxes << box
          end
        end
      end
      packed_bins = []
      @bins.each do |bin|
        if bin.type == BIN_TYPE_USER_DEFINED && bin.boxes.empty?
          @unused_bins << bin
        else
          packed_bins << bin
        end
      end
      # Make sure these two are empty
      @boxes = []
      @leftovers = []
      # Remove bins that have not been used
      @bins = packed_bins
      @unplaced_boxes += @unfit_boxes
      @unfit_boxes = []

      ERROR_NONE
    end
  end
end

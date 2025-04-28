module Ladb::OpenCutList

  require_relative '../../model/attributes/material_attributes'
  require_relative '../../helper/material_attributes_caching_helper'
  require_relative 'cutlist_packing_worker'

  class CutlistEstimateWorker

    include MaterialAttributesCachingHelper

    def initialize(cutlist,

                   hidden_group_ids: []

    )

      @cutlist = cutlist

      @hidden_group_ids = hidden_group_ids

      @cutlist_groups = @cutlist.groups.select { |group| group.material_type != MaterialAttributes::TYPE_UNKNOWN && !@hidden_group_ids.include?(group.id) }

      @runs = []
      @run_index = 0
      @run_progress = 0.0
      @run_name = ''

      @cancelled = false

    end

    # -----

    def run(action = :start)
      case action

      when :start

        # Create runs
        @cutlist_groups.each do |cutlist_group|
          @runs << _create_run(cutlist_group)
        end

        return {
          runs: @runs.length,
          running: true
        }

      when :advance
        return {
          cancelled: true
        } if @cancelled

        # Process current run
        solution = nil
        unless (run = @runs[@run_index]).nil?
          if run.finished?

            # Jump to the next run
            @run_index += 1
            run = @runs[@run_index]

          end
        end
        unless run.nil?
          if !run.started?

            run.start
            solution = 'none' # Clear solution preview

          else

            result = run.advance
            solution = result['solution'] unless result.nil?

          end
        end

        return {
          running: true,
          run_index: @run_index,
          run_progress: run.progress,
          run_name: run.name,
          solution: solution,
        } unless run.nil?
        return {
        }

      when :next

        # Cancel current run
        unless (run = @runs[@run_index]).nil?
          run.cancel
        end

        return {
        }

      when :cancel
        @cancelled = true

        # Cancel current run
        unless (run = @runs[@run_index]).nil?
          run.cancel
        end

        return {
        }

      end
      {}
    end

    # -----

    private

    def _create_run(cutlist_group)

      material_attributes = _get_material_attributes(cutlist_group.material_name)

      case material_attributes.type

      when MaterialAttributes::TYPE_SHEET_GOOD
        return EstimatePackingRun.new(@cutlist, cutlist_group, material_attributes)

      else
        return EstimateBasicRun.new(@cutlist, cutlist_group, material_attributes)
      end

    end

  end

  # -----

  class EstimateRun

    def initialize(cutlist, cutlist_group, material_attributes)

      @cutlist = cutlist
      @cutlist_group = cutlist_group
      @material_attributes = material_attributes

      @name = "#{cutlist_group.material_name} / #{cutlist_group.std_dimension}"
      @progress = 0.0
      @started = false
      @finished = false

    end

    def start
      @started = true
    end

    def advance
    end

    def cancel
    end

    # -----

    def name
      @name
    end

    def progress
      @progress
    end

    def started?
      @started
    end

    def finished?
      @finished
    end

    protected

    def _finalize
      @progress = 1.0
      @finished = true
    end

  end

  class EstimateBasicRun < EstimateRun

    def start
      super
      _finalize
    end

  end

  class EstimatePackingRun < EstimateRun

    def initialize(cutlist, cutlist_group, material_attributes)
      super

      @packing = nil

    end

    def start
      super

      settings = HashUtils.symbolize_keys(PLUGIN.get_model_preset('cutlist_packing_options', @cutlist_group.id))
      settings[:group_id] = @cutlist_group.id

      std_sizes = @material_attributes.std_sizes.split(DimensionUtils::LIST_SEPARATOR)
      if settings[:std_bin_2d_sizes] == '' || settings[:std_bin_2d_sizes] != '0x0' && !std_sizes.include?(settings[:std_bin_2d_sizes])
        settings[:std_bin_2d_sizes] = std_sizes[0] unless std_sizes.empty?
      end

      @time_limit = settings[:time_limit]
      @start_time = Time.new

      @worker = CutlistPackingWorker.new(@cutlist, **settings)
      @packing = @worker.run

      _finalize unless @packing.running

      @packing.to_hash
    end

    def advance
      super
      unless finished? || @worker.nil?

        @packing = @worker.run(:advance)
        @progress = [ (Time.new - @start_time) / @time_limit, 1.0 ].min

        _finalize unless @packing.running

        return @packing.to_hash
      end
      nil
    end

    def cancel
      super
      unless finished? || @worker.nil?

        packing = @worker.run(:cancel)

        return packing.to_hash
      end
      nil
    end

    def _finalize
      super
    end

  end

end
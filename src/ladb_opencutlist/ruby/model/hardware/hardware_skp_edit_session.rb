module Ladb::OpenCutList

  # A SKP part of a descriptor being shaped in SketchUp - see
  # HardwareSkpEditStartWorker : the bench laid in the model, the part
  # opened for edit in it, and what to give back once it is done.
  class HardwareSkpEditSession

    attr_reader :model, :bench, :instance, :placeholder, :definitions, :view_state
    attr_accessor :closing

    # definitions : the ones of the model before the bench came ;
    # view_state : the camera and the Smart Join action put aside.
    def initialize(model:, bench:, instance:, placeholder:, definitions:, view_state:)
      @model = model
      @bench = bench
      @instance = instance
      @placeholder = placeholder
      @definitions = definitions
      @view_state = view_state
      @closing = false
      @left = false
      @closed = false
    end

    def valid?
      @instance.valid? && @model == Sketchup.active_model
    end

    # True - once - when the active path no longer goes through the part :
    # left by the user, not closed by the session itself. Inside a nested
    # component of the part, it is still edited.
    def part_left!
      return false if @closing || @left
      return false unless @model.valid? && @model == Sketchup.active_model
      path = @model.active_path
      return false if @instance.valid? && !path.nil? && path.include?(@instance)
      @left = true
    end

    # The bench leaves the model, with every definition it brought, and the
    # camera and the Smart Join tool it put aside come back.
    def close
      return if @closed
      @closed = true
      @closing = true
      return unless @model.valid?
      close_active
      @model.start_operation('OCL Hardware Edit', true)
      @bench.erase! if @bench.valid?
      if @model.definitions.respond_to?(:remove)
        added = @model.definitions.to_a - @definitions
        added.each { |definition| @model.definitions.remove(definition) if definition.valid? && definition.instances.empty? }
      end
      @model.commit_operation
      self.class.restore_view(@view_state) if @model == Sketchup.active_model
    end

    def close_active
      if @model.respond_to?(:active_path=)
        @model.active_path = nil unless @model.active_path.nil?
      else
        @model.close_active until @model.active_path.nil?
      end
    end

    def self.restore_view(view_state)
      model = Sketchup.active_model
      return if model.nil? || !view_state.is_a?(Hash)
      model.active_view.camera = view_state[:camera] if view_state[:camera].is_a?(Sketchup::Camera)
      # A new instance on the same action : a reactivated one doesn't rebuild its whole state
      model.select_tool(SmartJoinTool.new(current_action: view_state[:smart_join_action])) unless view_state[:smart_join_action].nil?
    end

  end

end

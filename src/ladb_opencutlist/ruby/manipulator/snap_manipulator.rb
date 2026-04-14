module Ladb::OpenCutList

  require_relative 'manipulator'

  class SnapManipulator < Manipulator

    attr_reader :snap

    def initialize(snap, transformation = IDENTITY, material = nil, layer = nil)
      raise "snap must be a Sketchup::Snap." unless snap.is_a?(Sketchup::Snap)
      super(transformation, _combine_material(snap.material, material), _combine_layer(snap.layer, layer))
      @snap = snap
    end

    # -----

    def reset_cache
      super
      @position = nil
      @direction = nil
      @up = nil
    end
    
    # -----

    def position
      @position ||= @snap.position.transform(@transformation)
    end

    def direction
      @direction ||= @snap.direction.transform(@transformation).normalize
    end

    def up
      @up ||= @snap.up.transform(@transformation).normalize
    end

    # -----

    def to_s
      [
        "SNAP",
        "- position = #{position}",
        "- direction = #{direction}",
        "- up = #{up}",
      ].join("\n")
    end

  end

end

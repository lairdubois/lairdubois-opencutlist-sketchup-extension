module Ladb::OpenCutList

  require_relative 'outliner_material'

  class OutlinerMaterialDef

    attr_reader :material, :material_attributes, :used_by_node_defs

    def initialize(material)
      @material = material
      @used_by_node_defs = []
      fill
    end

    def fill
      @material_attributes = MaterialAttributes.new(@material)
    end

    # -----

    def add_used_by_node_def(node_def)
      @used_by_node_defs << node_def
    end

    def each_used_by
      @used_by_node_defs.each { |node_def| yield node_def }
    end

    # -----

    def clear_hashable
      @hashable = nil
    end

    def create_hashable
      @hashable = OutlinerMaterial.new(self) if @hashable.nil?
      @hashable
    end

  end

end
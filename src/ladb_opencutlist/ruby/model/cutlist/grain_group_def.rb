module Ladb::OpenCutList

  require_relative '../data_container'

  class GrainGroupDef < DataContainer

    attr_reader :entity,
                :item_defs

    def initialize(entity)
      @entity = entity
      @item_defs = []
    end

    def name
      return PLUGIN.get_i18n_string('tab.outliner.type_0') if @entity.is_a?(Sketchup::Model)
      return @entity.name if @entity.respond_to?(:name) && !@entity.name.empty?
      return "<#{@entity.definition.name}>" if @entity.respond_to?(:definition)
      ''
    end

  end

end
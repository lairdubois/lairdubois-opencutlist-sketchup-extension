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
      return 'model' if @entity.is_a?(Sketchup::Model)
      return @entity.name if @entity.respond_to?(:name) && !@entity.name.empty?
      return "##{@entity.entityID}" if @entity.respond_to?(:entityID)
      ''
    end

  end

end
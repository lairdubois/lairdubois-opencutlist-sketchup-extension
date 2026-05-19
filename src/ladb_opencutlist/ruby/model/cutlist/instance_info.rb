module Ladb::OpenCutList

  require_relative '../data_container'
  require_relative '../../model/geom/scale3d'
  require_relative '../../utils/path_utils'

  class InstanceInfo < DataContainer

    NAME_SOURCE_DEFINITION = 0
    NAME_SOURCE_INSTANCE = 1
    NAME_SOURCE_DYNAMIC_ATTRIBUTE = 2

    attr_accessor :size, :definition_bounds
    attr_reader :path

    @size = nil
    @definition_bounds = nil

    def initialize(path = [])
      @path = path
    end

    # -----

    def read_name(try_from_dynamic_attributes = false)
      if try_from_dynamic_attributes
        name = entity.get_attribute('dynamic_attributes', 'name', nil)
        return [ name, NAME_SOURCE_DYNAMIC_ATTRIBUTE ] unless name.nil?
      end
      return [ entity.name, NAME_SOURCE_INSTANCE ] if entity.definition.group?
      [ entity.definition.name, NAME_SOURCE_DEFINITION ]
    end

    # -----

    def definition
      @definition ||= entity.respond_to?(:definition) ? entity.definition : nil
    end

    def entity
      @path.last
    end

    def layer
      entity.layer
    end

    def serialized_path
      @serialized_path ||= PathUtils.serialize_path(@path)
    end

    def named_path
      @named_path ||= PathUtils.get_named_path(@path).join('.')
    end

    def transformation
      @transformation ||= PathUtils.get_transformation(@path)
    end

    def scale
      @scale ||= Scale3d.create_from_transformation(transformation)
    end

    def flipped
      @flipped ||= TransformationUtils::flipped?(transformation)
    end

    # -----

    def size
      @size ||= Size3d.new
    end

  end

end
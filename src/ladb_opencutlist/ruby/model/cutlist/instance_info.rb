module Ladb::OpenCutList

  require_relative '../../model/geom/scale3d'
  require_relative '../../utils/path_utils'

  class InstanceInfo

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
        return [ name, true ] unless name.nil?
      end
      [ entity.definition.name, false ]
    end

    # -----

    def definition
      return @definition if @definition
      @definition = entity.definition if entity.is_a?(Sketchup::ComponentInstance)
    end

    def entity
      @path.last
    end

    def layer
      entity.layer
    end

    def serialized_path
      return @serialized_path if @serialized_path
      @serialized_path = PathUtils.serialize_path(@path)
    end

    def named_path
      return @named_path if @named_path
      @named_path = PathUtils.get_named_path(@path).join('.')
    end

    def transformation
      return @transformation if @transformation
      @transformation = PathUtils.get_transformation(@path)
    end

    def scale
      return @scale if @scale
      @scale = Scale3d.create_from_transformation(transformation)
    end

    def flipped
      return @flipped if @flipped
      @flipped = TransformationUtils::flipped?(transformation)
    end

    # -----

    def size
      return @size if @size
      Size3d.new
    end

  end

end
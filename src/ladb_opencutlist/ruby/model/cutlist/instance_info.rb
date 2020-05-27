module Ladb::OpenCutList

  require_relative '../../utils/path_utils'

  class InstanceInfo

    attr_accessor :size, :definition_bounds
    attr_reader :path

    @size = nil
    @definition_bounds = nil

    def initialize(path = [])
      @path = path
    end

    def read_name(try_from_dynamic_attributes = false)
      if try_from_dynamic_attributes
        name = entity.get_attribute('dynamic_attributes', 'name', nil)
        return name, true unless name.nil?
      end
      [ entity.definition.name, false ]
    end

    # -----

    def entity
      @path.last
    end

    def serialized_path
      if @serialized_path
        return @serialized_path
      end
      @serialized_path = PathUtils.serialize_path(@path)
    end

    def transformation
      if @transformation
        return @transformation
      end
      @transformation = PathUtils.get_transformation(@path)
    end

    def scale
      if @scale
        return @scale
      end
      @scale = TransformationUtils::get_scale3d(transformation)
    end

    def flipped
      if @flipped
        return @flipped
      end
      @flipped = TransformationUtils::flipped?(transformation)
    end

    # -----

    def size
      if @size
        return @size
      end
      Size3d.new
    end

  end

end
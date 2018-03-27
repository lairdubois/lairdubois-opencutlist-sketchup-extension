module Ladb
  module Toolbox
    class InstanceDef

      attr_accessor :entity, :transformation

      def initialize(entity, transformation)
        @entity = entity
        @transformation = transformation
      end

    end
  end
end
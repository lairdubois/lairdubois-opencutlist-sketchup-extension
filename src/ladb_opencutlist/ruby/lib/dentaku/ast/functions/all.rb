require_relative '../function'
require_relative '../../exceptions'

module Ladb::OpenCutList
module Dentaku
  module AST
    class All < Function
      def self.min_param_count
        3
      end

      def self.max_param_count
        3
      end

      def deferred_args
        [1, 2]
      end

      def value(context = {})
        collection      = @args[0].value(context)
        item_identifier = @args[1].identifier
        expression      = @args[2]

        Array(collection).all? do |item_value|
          expression.value(
            context.update(
              FlatHash.from_hash(item_identifier => item_value)
            )
          )
        end
      end
    end
  end
end
end

module Ladb::OpenCutList
  Dentaku::AST::Function.register_class(:all, Dentaku::AST::All)
end

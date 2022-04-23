require_relative './enum'

module Ladb::OpenCutList
module Dentaku
  module AST
    class Any < Enum
      def value(context = {})
        collection      = Array(@args[0].value(context))
        item_identifier = @args[1].identifier
        expression      = @args[2]

        collection.any? do |item_value|
          expression.value(
            context.merge(
              FlatHash.from_hash_with_intermediates(item_identifier => item_value)
            )
          )
        end
      end
    end
  end
end
end

module Ladb::OpenCutList
  Dentaku::AST::Function.register_class(:any, Dentaku::AST::Any)
end
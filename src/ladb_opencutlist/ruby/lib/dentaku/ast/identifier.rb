require_relative '../exceptions'
require_relative '../string_casing'

module Ladb::OpenCutList
module Dentaku
  module AST
    class Identifier < Node
      include StringCasing
      attr_reader :identifier, :case_sensitive

      def initialize(token, options = {})
        @case_sensitive = options.fetch(:case_sensitive, false)
        @identifier = standardize_case(token.value)
      end

      def value(context = {})
        v = context.fetch(identifier) do
          raise UnboundVariableError.new([identifier]),
                "no value provided for variables: #{identifier}"
        end

        case v
        when Node
          value = v.value(context)
          context[identifier] = value if Dentaku.cache_identifier?
          value
        when Proc
          v.call
        else
          v
        end
      end

      def dependencies(context = {})
        context.key?(identifier) ? dependencies_of(context[identifier]) : [identifier]
      end

      private

      def dependencies_of(node)
        node.respond_to?(:dependencies) ? node.dependencies : []
      end
    end
  end
end
end

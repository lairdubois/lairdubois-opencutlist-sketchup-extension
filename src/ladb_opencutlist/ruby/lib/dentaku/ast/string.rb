require_relative "./literal"

module Ladb::OpenCutList
module Dentaku
  module AST
    class String < Literal
      def quoted
        %Q{"#{ escaped }"}
      end

      def escaped
        @value.gsub('"', '\"')
      end
    end
  end
end
end

require_relative '../function'

module Ladb::OpenCutList
  Dentaku::AST::Function.register(:not, :logical, ->(logical) {
    ! logical
  })
end
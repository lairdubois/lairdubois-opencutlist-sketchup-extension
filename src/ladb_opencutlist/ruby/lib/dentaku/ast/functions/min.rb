require_relative '../function'

module Ladb::OpenCutList
  Dentaku::AST::Function.register(:min, :numeric, ->(*args) {
    args.flatten.map { |arg| Dentaku::AST::Function.numeric(arg) }.min
  })
end
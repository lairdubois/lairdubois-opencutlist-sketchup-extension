module Ladb::OpenCutList

  module HashableHelper

    def to_hash
      hash = {}
      self.instance_variables.each do |var|
        key = var.to_s.delete('@')
        next if key.start_with? '_'   # Exclude "private" instance variables
        variable = self.instance_variable_get(var)
        if variable.is_a?(HashableHelper)
          variable = variable.to_hash
        elsif variable.is_a?(Array)
          variable = variable.map { |v| v.is_a?(HashableHelper) ? v.to_hash : v }
        elsif variable.is_a?(Hash)
          variable = variable.map { |k,v| [ k, v.is_a?(HashableHelper) ? v.to_hash : v ] }.to_h
        end
        hash[key] = variable
      end
      hash
    end

  end

end
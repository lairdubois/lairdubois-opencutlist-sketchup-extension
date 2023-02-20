module Ladb::OpenCutList

  module HashableHelper

    def to_hash
      hash = {}
      self.instance_variables.each do |var|
        key = var.to_s.delete('@')
        next if key.start_with? '_'   # Exclude "private" instance variables
        value = self.instance_variable_get(var)
        if value.is_a?(HashableHelper)
          value = value.to_hash
        elsif value.is_a?(Array)
          value = value.collect{ |v| v.is_a?(HashableHelper) ? v.to_hash : v }
        elsif value.is_a?(Hash)
          value = value.map{ |k,v| [ k, v.is_a?(HashableHelper) ? v.to_hash : v ] }.to_h
        end
        hash[key] = value
      end
      hash
    end

  end

end
module Ladb::OpenCutList

  require_relative '../model/attributes/instance_attributes'

  module InstanceAttributesCachingHelper

    def _get_instance_attributes(instance)
      return nil if instance.nil?
      @instance_attributes_cache ||= {}
      @instance_attributes_cache[instance] ||= InstanceAttributes.new(instance)
    end

  end

end
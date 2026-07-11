module Ladb::OpenCutList

  # SketchUp locks are NOT enforced by the Ruby API : erasing an instance,
  # transforming it or rebuilding its definition succeeds silently whatever
  # its locked state. Tools and workers enforce the locks themselves, with a
  # single shared semantic : an instance is EFFECTIVELY locked when at least
  # one of its occurrence paths traverses a locked instance. Locks above the
  # model active path count too : the rule is global, whatever the open
  # context.
  module LockUtils

    # True when the given entity is locked itself. Safe on any entity : only
    # groups and component instances can be locked.
    def self.locked?(entity)
      entity.respond_to?(:locked?) && entity.locked?
    end

    # True when the given occurrence path (Array of entities, model root
    # first) traverses a locked instance.
    def self.locked_path?(path)
      path.is_a?(Array) && path.any? { |entity| locked?(entity) }
    end

    # True when the given instance is locked or reachable through a locked
    # occurrence path, walking the ancestors up (parent definition instances)
    # rather than enumerating the paths down : the cost is local to the
    # instance placement, not proportional to the model.
    # The optional cache ({}, owned and shared by the caller) memoizes the
    # per definition verdicts across calls : valid as long as the model locks
    # and instance placements do not change.
    def self.effectively_locked?(instance, cache = nil)
      return true if locked?(instance)
      parent = instance.respond_to?(:parent) ? instance.parent : nil
      return false unless parent.is_a?(Sketchup::ComponentDefinition)
      cache = {} if cache.nil?
      return cache[parent] if cache.key?(parent)
      cache[parent] = false   # In-progress guard : definitions are acyclic, but stay safe
      cache[parent] = parent.instances.any? { |parent_instance| effectively_locked?(parent_instance, cache) }
    end

    # Partitions the live instances of the given definition external to
    # members (Array, or Hash keyed by instance) into
    # [ effectively locked instances, free instances ].
    def self.partition_locked_extern_instances(definition, members, cache = nil)
      cache = {} if cache.nil?
      definition.instances
                .reject { |instance| instance.deleted? || members.include?(instance) }
                .partition { |instance| effectively_locked?(instance, cache) }
    end

  end

end
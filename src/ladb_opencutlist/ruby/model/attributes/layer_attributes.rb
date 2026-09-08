module Ladb::OpenCutList

  # What a LAYER says about the parts drawn on it — the counterpart, for tags,
  # of what MaterialAttributes says for materials.
  #
  # A layer is where such a marking belongs : it is the one property of a part
  # the user can see, set and change without leaving SketchUp, one tag speaks
  # for every part of a kind at once, and a part that is no longer of that kind
  # only has to be moved off it.
  #
  # TYPE_DOOR is the first of them. A door is a panel LAID ON its carcass, and
  # nothing in its geometry says so — see CommonSolidFindCavitiesWorker, its
  # doc's APPLIED PANELS : a back laid on the same way is shaped exactly alike,
  # and only what the part is FOR tells the two apart. Being told, the cavity
  # detection can read the carcass bare, and a second door be fitted to the
  # openings the first one left.
  class LayerAttributes

    TYPE_UNKNOWN = 0
    TYPE_DOOR = 1

    attr_accessor :type
    attr_reader :layer

    def initialize(layer)
      @layer = layer
      read_from_attributes
    end

    # -----

    def self.valid_type(type)
      return TYPE_UNKNOWN if type.nil?
      i_type = type.to_i
      return TYPE_UNKNOWN if i_type < TYPE_UNKNOWN || i_type > TYPE_DOOR
      i_type
    end

    # The type marked on the layer the given entity is drawn on, TYPE_UNKNOWN
    # when it carries none — which is what an entity of an untouched model, or
    # one on Layer0, answers.
    def self.type_of(entity)
      return TYPE_UNKNOWN unless entity.respond_to?(:layer)
      layer = entity.layer
      return TYPE_UNKNOWN if layer.nil?
      LayerAttributes.new(layer).type
    end

    # The model's layer marked with the given type, or nil. The MARKING is what
    # is looked for, never the name : the user is free to rename the tag.
    def self.fetch_layer(model, type)
      model.layers.find { |layer| LayerAttributes.new(layer).type == type }
    end

    # The model's layer marked with the given type, created under +name+ and
    # marked if it has none yet.
    def self.fetch_or_create_layer(model, type, name)
      layer = fetch_layer(model, type)
      return layer unless layer.nil?

      layer = model.layers.add(name)
      layer_attributes = LayerAttributes.new(layer)
      layer_attributes.type = type
      layer_attributes.write_to_attributes

      layer
    end

    # -----

    def read_from_attributes
      @type = @layer.nil? ? TYPE_UNKNOWN : LayerAttributes.valid_type(PLUGIN.get_attribute(@layer, 'type', nil))
    end

    def write_to_attributes
      PLUGIN.set_attribute(@layer, 'type', @type) unless @layer.nil?
    end

  end

end

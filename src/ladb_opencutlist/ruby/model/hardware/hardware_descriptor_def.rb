module Ladb::OpenCutList

  require 'json'
  require_relative '../data_container'
  require_relative '../../utils/dimension_utils'

  # A HARDWARE of the asset library : a JSON descriptor - data - whose
  # geometries are SKP files it refers to, possibly shared with other
  # hardware. See the spec "Bibliothèque de quincailleries Smart".
  #
  #  {
  #    "format": "ocl-hardware", "version": 1,
  #    "id": "<uuid>",              stable identity, whatever the file's path
  #    "type": "hinge",             how the tool finds where to lay it (TYPES)
  #    "category": "…",             free, for filtering
  #    "name": "…", "thumbnail": "./….png",
  #    "meta": { "reference", "supplier", "url",
  #              "items": [ { "component": "a", "reference", "name", "quantity", "unit_price" } ] },
  #    "hardware_material": "…",
  #    "components": { "<role>": <component> },
  #    "options": { "<name>": "<value>" }   defaults of the tool's options
  #  }
  #
  # A <component> is either :
  #  - { "hardware": <ref>, "machining": <ref> | { "holes": [ … ] }, "stretch": { … }, "attributes": { … } }
  #  - { "same_as": "<role>" } / { "mirror_of": "<role>" }
  #  - { "variants": { "select": { "by": "<measure>", "mode": "exact" | "max_le", "ratio": <Float> },
  #                    "fallback": "<key>", "items": { "<key>": <component> | null } },
  #      "attributes": { … } }
  #  - null : the role is left empty (a one sided fitting)
  #
  # "attributes" are written as is in the OCL dictionary of the laid hardware
  # definition - over those its SKP bears : { "role": "hinge",
  # "hinge_max_angle": 110, "hinge_pivot": [ -8.5, 4.2 ] }. Values are
  # scalars or arrays of scalars. Those of a variant override those of the
  # component holding the variants.
  #
  # Refs are '$LIB/…' / '$OCL/…' refs of a library, './…' paths relative to the
  # descriptor, or anything else _get_geometries_def understands (a
  # definition name). './…' refs are made absolute here, library ones are
  # left to their consumer.
  class HardwareDescriptorDef < DataContainer

    FORMAT = 'ocl-hardware'.freeze
    VERSION = 1

    TYPE_CONNECTOR = 'connector'.freeze
    TYPE_FITTING = 'fitting'.freeze
    TYPE_HINGE = 'hinge'.freeze
    TYPE_FACE = 'face'.freeze
    TYPE_SPAN = 'span'.freeze

    # The roles of the components each type lays
    TYPES = {
      TYPE_CONNECTOR => %w[a b],
      TYPE_FITTING => %w[a b],
      TYPE_HINGE => %w[a b],
      TYPE_FACE => %w[main],
      TYPE_SPAN => %w[a b span],
    }.freeze

    SELECT_MODE_EXACT = 'exact'.freeze
    SELECT_MODE_MAX_LE = 'max_le'.freeze   # The largest key <= the measure

    # How much the measure may fall short of a key and still take it
    MAX_LE_EPSILON = 1e-6

    # What a hardware definition laid from a descriptor bears - in the OCL
    # attribute dictionary : the descriptor's id, the role of the component it
    # is, and the key of its variant (nil when it has none).
    DEFINITION_ATTRIBUTE_ID = 'hardware_id'.freeze
    DEFINITION_ATTRIBUTE_COMPONENT = 'hardware_component'.freeze
    DEFINITION_ATTRIBUTE_VARIANT = 'hardware_variant'.freeze

    # A component resolved for a context : the refs to load, and how to lay them.
    #  - hardware, machining : ref String, nil - or a Hash of primitives for machining ;
    #  - mirror : true when the geometry is laid mirrored (mirror_of) ;
    #  - stretch : the component's "stretch" Hash, or nil ;
    #  - variant : the key of the picked variant, or nil ;
    #  - attributes : the Hash of the definition attributes, maybe empty.
    HardwareComponentDef = Struct.new(:role, :hardware, :machining, :mirror, :stretch, :variant, :attributes)

    attr_reader :path, :data, :errors

    # -- Loading --

    # The descriptor at the given path - absolute, or a '$LIB/…' ref - nil if
    # the file can't be read or isn't a hardware descriptor. An invalid one is
    # returned, see valid? and errors.
    def self.load(ref)
      path = defined?(PLUGIN) && PLUGIN.respond_to?(:resolve_library_ref) ? PLUGIN.resolve_library_ref(ref) : ref
      return nil unless path.is_a?(String) && File.file?(path)
      begin
        data = JSON.parse(File.read(path, mode: 'r:UTF-8'))
      rescue JSON::ParserError, SystemCallError
        return nil
      end
      return nil unless descriptor?(data)
      new(data, path)
    end

    # Is the given parsed JSON a hardware descriptor - of any version ?
    def self.descriptor?(data)
      data.is_a?(Hash) && data['format'] == FORMAT
    end

    def initialize(data, path = nil)
      @data = data
      @path = path
      @errors = _validate
    end

    # -- Accessors --

    def valid?
      @errors.empty?
    end

    def id
      @data['id']
    end

    def type
      @data['type']
    end

    def category
      @data['category']
    end

    def name
      @data['name']
    end

    def thumbnail
      _resolve_ref(@data['thumbnail'])
    end

    def hardware_material
      _resolve_ref(@data['hardware_material'])
    end

    def roles
      TYPES[type] || []
    end

    # The defaults of the tool's options, as their raw strings.
    def options
      @data['options'].is_a?(Hash) ? @data['options'] : {}
    end

    def option(name)
      value = options[name.to_s]
      value.nil? ? nil : value.to_s
    end

    def meta_items
      meta = @data['meta']
      meta.is_a?(Hash) && meta['items'].is_a?(Array) ? meta['items'].select { |item| item.is_a?(Hash) } : []
    end

    # The unit price of one instance of the given role's component : the sum
    # of the items it bears - nil when it bears none, or none priced.
    def unit_price(role)
      items = meta_items.select { |item| item['component'] == role.to_s && item['unit_price'].is_a?(Numeric) }
      return nil if items.empty?
      items.inject(0.0) { |sum, item| sum + (item['quantity'].is_a?(Numeric) ? item['quantity'] : 1) * item['unit_price'] }
    end

    # -- Resolution --

    # The component of the given role, resolved for the given context - the
    # measures the tool took, keyed by the "by" of the variants they select :
    # { 'hinge_kind' => 'inset', 'depth' => <Length>, … }. nil when the role is
    # empty, or no variant fits.
    def resolve_component(role, context = {})
      _resolve_component(role.to_s, _stringify_keys(context), false, [])
    end

    # -----

    private

    def _resolve_component(role, context, mirror, visited)
      return nil if visited.include?(role)   # Cycle
      visited = visited + [ role ]
      components = @data['components']
      return nil unless components.is_a?(Hash)
      _resolve_value(role, components[role], context, mirror, visited)
    end

    def _resolve_value(role, value, context, mirror, visited, variant = nil, attributes = {})
      return nil unless value.is_a?(Hash)
      attributes = attributes.merge(value['attributes']) if value['attributes'].is_a?(Hash)
      if value.key?('same_as')
        resolved = _resolve_component(value['same_as'].to_s, context, mirror, visited)
      elsif value.key?('mirror_of')
        resolved = _resolve_component(value['mirror_of'].to_s, context, !mirror, visited)
      elsif value.key?('variants')
        key = _select_variant(value['variants'], context)
        return nil if key.nil?
        return _resolve_value(role, value['variants']['items'][key], context, mirror, visited, key, attributes)
      else
        machining = value['machining']
        machining = _resolve_ref(machining) unless machining.is_a?(Hash)
        return HardwareComponentDef.new(role, _resolve_ref(value['hardware']), machining, mirror, value['stretch'], variant, attributes)
      end
      return nil if resolved.nil?
      resolved.role = role
      resolved
    end

    # The key of the variant the context selects, nil if none. A missing key
    # - or no measure at all - falls back on "fallback" ; a key set to null
    # means the hardware doesn't support that case : no fallback.
    def _select_variant(variants, context)
      return nil unless variants.is_a?(Hash) && variants['items'].is_a?(Hash)
      items = variants['items']
      select = variants['select'].is_a?(Hash) ? variants['select'] : {}
      fallback = variants['fallback'].is_a?(String) && items[variants['fallback']].is_a?(Hash) ? variants['fallback'] : nil
      measure = context[select['by'].to_s]
      return fallback if measure.nil?

      if select['mode'] == SELECT_MODE_MAX_LE
        ratio = select['ratio'].is_a?(Numeric) ? select['ratio'] : 1.0
        limit = measure.to_f * ratio
        best_key = nil
        best_length = nil
        items.each do |key, item|
          next unless item.is_a?(Hash)
          length = _to_length(key)
          next if length.nil? || length > limit + MAX_LE_EPSILON
          next if !best_length.nil? && length <= best_length
          best_key = key
          best_length = length
        end
        best_key || fallback
      else
        key = measure.to_s
        return fallback unless items.key?(key)
        items[key].is_a?(Hash) ? key : nil
      end
    end

    # A variant key as a length in inches, nil if it isn't one.
    def _to_length(key)
      DimensionUtils.str_to_ifloat(key.to_s).to_l.to_f
    rescue StandardError
      nil
    end

    def _resolve_ref(ref)
      return nil unless ref.is_a?(String) && !ref.strip.empty?
      return ref unless ref.start_with?('./') && @path.is_a?(String)
      File.join(File.dirname(@path), ref[2..-1])
    end

    def _stringify_keys(hash)
      return {} unless hash.is_a?(Hash)
      Hash[hash.map { |k, v| [ k.to_s, v ] }]
    end

    # -- Validation --

    # The problems of the descriptor, as messages. Empty when it is valid.
    def _validate
      errors = []
      return [ 'not an ocl-hardware descriptor' ] unless self.class.descriptor?(@data)
      errors << "unsupported version #{@data['version'].inspect}" unless @data['version'].is_a?(Integer) && @data['version'] >= 1 && @data['version'] <= VERSION
      errors << 'missing id' unless @data['id'].is_a?(String) && !@data['id'].empty?
      errors << "unknown type #{@data['type'].inspect}" unless TYPES.key?(@data['type'])
      errors << 'missing name' unless @data['name'].is_a?(String) && !@data['name'].empty?

      components = @data['components']
      if components.is_a?(Hash)
        components.each do |role, value|
          errors << "unknown role '#{role}'" unless roles.include?(role)
          _validate_component(role, value, errors)
        end
        errors << 'no component' if TYPES.key?(@data['type']) && roles.all? { |role| components[role].nil? }
      else
        errors << 'missing components'
      end

      if @data.key?('options')
        if @data['options'].is_a?(Hash)
          @data['options'].each do |name, value|
            errors << "option '#{name}' is not a scalar" unless _scalar?(value)
          end
        else
          errors << 'options is not an object'
        end
      end

      errors
    end

    def _validate_component(path, value, errors)
      return if value.nil?
      unless value.is_a?(Hash)
        errors << "component '#{path}' is not an object"
        return
      end
      _validate_attributes(path, value['attributes'], errors) if value.key?('attributes')
      if value.key?('same_as') || value.key?('mirror_of')
        errors << "component '#{path}' links to another role and has attributes" if value.key?('attributes')
        target = value.key?('same_as') ? value['same_as'] : value['mirror_of']
        errors << "component '#{path}' links to unknown role #{target.inspect}" unless roles.include?(target)
        errors << "component '#{path}' links to itself" if target == path
      elsif value.key?('variants')
        variants = value['variants']
        unless variants.is_a?(Hash) && variants['items'].is_a?(Hash) && !variants['items'].empty?
          errors << "component '#{path}' has no variant"
          return
        end
        select = variants['select']
        errors << "component '#{path}' has no select.by" unless select.is_a?(Hash) && select['by'].is_a?(String)
        if variants.key?('fallback') && !variants['items'][variants['fallback']].is_a?(Hash)
          errors << "component '#{path}' falls back on unknown variant #{variants['fallback'].inspect}"
        end
        variants['items'].each do |key, item|
          errors << "component '#{path}' variant '#{key}' links to another role" if item.is_a?(Hash) && (item.key?('same_as') || item.key?('mirror_of') || item.key?('variants'))
          _validate_component("#{path}/#{key}", item, errors)
        end
      else
        has_hardware = value['hardware'].is_a?(String) && !value['hardware'].empty?
        has_machining = value['machining'].is_a?(Hash) || value['machining'].is_a?(String) && !value['machining'].empty?
        errors << "component '#{path}' has neither hardware nor machining" unless has_hardware || has_machining
      end
    end

    def _validate_attributes(path, attributes, errors)
      unless attributes.is_a?(Hash)
        errors << "component '#{path}' attributes is not an object"
        return
      end
      attributes.each do |name, value|
        next if _scalar?(value) || value.is_a?(Array) && value.all? { |item| _scalar?(item) }
        errors << "component '#{path}' attribute '#{name}' is neither a scalar nor an array of scalars"
      end
    end

    def _scalar?(value)
      value.is_a?(String) || value.is_a?(Numeric) || value == true || value == false
    end

  end

end

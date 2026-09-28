module Ladb::OpenCutList

  require 'json'
  require_relative '../data_container'
  require_relative '../../utils/dimension_utils'
  require_relative '../../utils/length_expression_utils'

  # A HARDWARE of the asset library : a JSON descriptor - data - whose
  # geometries are SKP files of the same library, possibly shared with other
  # hardware. See the spec "Bibliothèque de quincailleries Smart".
  #
  #  {
  #    "format": "ocl-hardware", "version": 1,
  #    "id": "<uuid>",              stable identity, whatever the file's path
  #    "type": "hinge",             how the tool finds where to lay it (TYPES)
  #    "name": "…",
  #    "supplier": "…", "url": "…",
  #    "hardware_material": "…",
  #    "components": { "<slot>": <component> },
  #    "options": { "<name>": "<value>" }   defaults of the tool's options
  #  }
  #
  # A <component> is either :
  #  - { "name", "description", "price", "url", "mass",
  #      "hardware": <part> | <primitives>, "machining": <part> | <primitives>, "stretch": { … }, "attributes": { … } }
  #  - { "same_as": "<slot>" } / { "mirror_of": "<slot>" } : the other slot's
  #    component, laid mirrored across the YZ plane of the laying frame - x
  #    negated - for mirror_of ;
  #  - { "name", …, "variants": { "select": { "by": "<measure>", "mode": "exact" | "max_le", "ratio": <Float> },
  #                               "fallback": "<key>", "items": { "<key>": <component> | null } },
  #      "attributes": { … } }
  #  - null : the slot is left empty (a one sided fitting)
  #
  # A <part> is declared explicitly - a missing file stays an error :
  #  - true : the file named after the slot, in the components folder of the
  #    descriptor - see components_dir_ref and part_file_name ;
  #  - "<path>.skp" : a shared file, relative to the components folder of the
  #    descriptor's library ;
  #  - { "same_as": "<slot>" } : the same part of another slot ;
  #  - absent, null or false : none.
  # '$LIB/…', '$OCL/…' and './…' refs - and definition names - are still read.
  #
  # A part can instead be given as <primitives>, the tool generates its
  # geometry, in the laying frame of the type - the face at z = 0, the part
  # toward -Z. Lengths are strings with a unit, or numbers in millimeters ;
  # x and y default to 0.
  #  - a machining, as operations - for what a fixed SKP can't adapt, a
  #    through hole in a part of any thickness :
  #    { "drillings": [ { "x": "-64mm", "y": 0, "diameter": "5mm", "depth": "through" | "12mm" } ] }
  #    from the face into the part ;
  #  - a hardware, as shapes - a dowel :
  #    { "cylinders": [ { "x": 0, "y": 0, "diameter": "8mm", "from": "-20mm", "to": "20mm" } ] }
  #    along Z, from one height to the other.
  # A length can be an expression of the measures the tool takes where it
  # lays the part - VARIABLES - : "@thickness - 2mm", "@thickness / 2". Its
  # literals bear a unit as SketchUp reads it - mm, cm, m, ", ', yd - bare
  # numbers are factors. See LengthExpressionUtils.
  # "through" is "@thickness".
  #
  # "name", "description", "price", "url" and "mass" are what the cut list
  # reads of the laid hardware definition. Those of a variant override those
  # of the component holding the variants.
  #
  # "attributes" are written as is in the OCL dictionary of the laid hardware
  # definition - over those its SKP bears : { "role": "hinge",
  # "hinge_max_angle": 110, "hinge_pivot": [ -8.5, 4.2 ] }. Values are
  # scalars or arrays of scalars. Those of a variant override those of the
  # component holding the variants.
  class HardwareDescriptorDef < DataContainer

    FORMAT = 'ocl-hardware'.freeze
    VERSION = 1

    TYPE_CONNECTOR = 'connector'.freeze
    TYPE_FITTING = 'fitting'.freeze
    TYPE_HINGE = 'hinge'.freeze
    TYPE_FACE = 'face'.freeze
    TYPE_SPAN = 'span'.freeze

    # The slots each type lays a component in
    TYPES = {
      TYPE_CONNECTOR => %w[a b],
      TYPE_FITTING => %w[a b],
      TYPE_HINGE => %w[a b],
      TYPE_FACE => %w[main],
      TYPE_SPAN => %w[a b span],
    }.freeze

    PART_HARDWARE = 'hardware'.freeze
    PART_MACHINING = 'machining'.freeze
    PARTS = [ PART_HARDWARE, PART_MACHINING ].freeze

    # What the cut list reads of a laid hardware definition
    INFO_KEYS = %w[name description price url mass].freeze

    SELECT_MODE_EXACT = 'exact'.freeze
    SELECT_MODE_MAX_LE = 'max_le'.freeze   # The largest key <= the measure

    # How much the measure may fall short of a key and still take it
    MAX_LE_EPSILON = 1e-6

    # The folder of a library the SKP files of its descriptors live in
    COMPONENTS_DIR_NAME = 'components'.freeze

    LIBRARY_REF_PREFIXES = %w[$LIB/ $OCL/].freeze

    # What a definition loaded from a hardware SKP bears - in the OCL
    # attribute dictionary : the portable ref of its file, it is found by.
    DEFINITION_ATTRIBUTE_SOURCE = 'hardware_source'.freeze

    # What a definition generated from primitives bears - in the OCL
    # attribute dictionary : the key of its geometry, it is found by.
    DEFINITION_ATTRIBUTE_PRIMITIVES = 'hardware_primitives'.freeze

    MACHINING_DRILLINGS = 'drillings'.freeze
    HARDWARE_CYLINDERS = 'cylinders'.freeze

    # The primitives each part can be given as
    PRIMITIVES = {
      PART_HARDWARE => [ HARDWARE_CYLINDERS ],
      PART_MACHINING => [ MACHINING_DRILLINGS ],
    }.freeze

    DRILLING_DEPTH_THROUGH = 'through'.freeze

    # The measures the lengths of primitives can use, taken by the tool where
    # it lays the part :
    #  - thickness : how far the part goes behind the face - toward -Z.
    VARIABLE_THICKNESS = 'thickness'.freeze
    VARIABLES = [ VARIABLE_THICKNESS ].freeze

    VARIABLE_PATTERN = /@([A-Za-z_]\w*)/

    # A solid of primitives - a drilling or a cylinder - resolved for the
    # measures of where it is laid, its lengths in inches : a cylinder along
    # Z, from z_min to z_max.
    PrimitiveCylinderDef = Struct.new(:x, :y, :diameter, :z_min, :z_max)

    # A component resolved for a context : the refs to load, and how to lay them.
    #  - slot : the slot asked for ; source_slot : the one whose component
    #    it is - they differ through same_as / mirror_of ;
    #  - hardware, machining : ref String, nil - or a Hash of primitives ;
    #  - mirror : true when the geometry is laid mirrored (mirror_of) ;
    #  - stretch : the component's "stretch" Hash, or nil ;
    #  - variant : the key of the picked variant, or nil ;
    #  - attributes : the Hash of the definition attributes, maybe empty ;
    #  - name : the component's name ; variant_name : the variant's own one,
    #    nil when it has none ;
    #  - description, price, url, mass : as written, the variant's over the component's ;
    #  - part_slots : the slot whose component each part - 'hardware',
    #    'machining' - comes from, another one when the part is linked.
    HardwareComponentDef = Struct.new(:slot, :source_slot, :hardware, :machining, :mirror, :stretch, :variant, :attributes,
                                      :name, :variant_name, :description, :price, :url, :mass, :part_slots)

    attr_reader :path, :ref, :data, :errors

    # -- Loading --

    # The descriptor at the given path - absolute, or a '$LIB/…' ref - nil if
    # the file can't be read or isn't a hardware descriptor. An invalid one is
    # returned, see valid? and errors.
    def self.load(ref)
      plugin = defined?(PLUGIN) ? PLUGIN : nil
      path = plugin && plugin.respond_to?(:resolve_library_ref) ? plugin.resolve_library_ref(ref) : ref
      return nil unless path.is_a?(String) && File.file?(path)
      ref = plugin.library_ref_from_path(path) if !library_ref?(ref) && plugin && plugin.respond_to?(:library_ref_from_path)
      begin
        data = JSON.parse(File.read(path, mode: 'r:UTF-8'))
      rescue JSON::ParserError, SystemCallError
        return nil
      end
      return nil unless descriptor?(data)
      new(data, path, library_ref?(ref) ? ref : nil)
    end

    # Is the given parsed JSON a hardware descriptor - of any version ?
    def self.descriptor?(data)
      data.is_a?(Hash) && data['format'] == FORMAT
    end

    def self.library_ref?(value)
      value.is_a?(String) && LIBRARY_REF_PREFIXES.any? { |prefix| value.start_with?(prefix) }
    end

    # Is the given resolved part - see HardwareComponentDef#hardware and
    # #machining - given as primitives ?
    def self.primitives?(part)
      part.is_a?(Hash) && (part[MACHINING_DRILLINGS].is_a?(Array) || part[HARDWARE_CYLINDERS].is_a?(Array))
    end

    # The variables the lengths of the given primitives use - "through"
    # uses thickness.
    def self.primitive_variables(primitives)
      return [] unless primitives?(primitives)
      names = []
      _primitive_items(primitives).each do |_, item|
        item.each do |key, value|
          names << VARIABLE_THICKNESS if key == 'depth' && value == DRILLING_DEPTH_THROUGH
          names.concat(value.scan(VARIABLE_PATTERN).flatten) if value.is_a?(String)
        end
      end
      names.uniq
    end

    # The solids of the given primitives, resolved for the given variables -
    # { 'thickness' => <inches> } - as PrimitiveCylinderDefs : a drilling
    # goes from the face into the part, a cylinder from one height to the
    # other. Those a length can't be resolved for are left out. nil when it
    # isn't given as primitives.
    def self.primitive_cylinders(primitives, variables = {})
      return nil unless primitives?(primitives)
      variables = Hash[variables.map { |k, v| [ k.to_s, v ] }]
      _primitive_items(primitives).map { |key, item|
        x = item['x'].nil? ? 0.0 : to_length(item['x'], true, variables)
        y = item['y'].nil? ? 0.0 : to_length(item['y'], true, variables)
        diameter = to_length(item['diameter'], false, variables)
        if key == MACHINING_DRILLINGS
          depth = to_length(item['depth'] == DRILLING_DEPTH_THROUGH ? "@#{VARIABLE_THICKNESS}" : item['depth'], false, variables)
          z_min = depth.nil? ? nil : -depth
          z_max = 0.0
        else
          z_min = to_length(item['from'], true, variables)
          z_max = to_length(item['to'], true, variables)
        end
        next nil if [ x, y, diameter, z_min, z_max ].any?(&:nil?) || z_max <= z_min
        PrimitiveCylinderDef.new(x, y, diameter, z_min, z_max)
      }.compact
    end

    # The given length in inches - a string with a unit, an expression of
    # variables, or a number of millimeters - nil if it isn't one or uses a
    # variable not given. 0 is only a length where negative ones are allowed.
    def self.to_length(value, negative_allowed = false, variables = {})
      if value.is_a?(Numeric)
        length = value / 25.4
      elsif value.is_a?(String) && value =~ VARIABLE_PATTERN
        length = _evaluate_length(value, variables)
        return nil if length.nil?
      elsif value.is_a?(String) && !value.strip.empty?
        length = DimensionUtils.str_to_ifloat(value, negative_allowed).to_l.to_f
      else
        return nil
      end
      return nil if length <= 0 && !negative_allowed
      length.to_f
    rescue StandardError
      nil
    end

    # [ [ primitive key, item Hash ] ] of the given primitives.
    def self._primitive_items(primitives)
      [ MACHINING_DRILLINGS, HARDWARE_CYLINDERS ].flat_map { |key|
        items = primitives[key]
        items.is_a?(Array) ? items.select { |item| item.is_a?(Hash) }.map { |item| [ key, item ] } : []
      }
    end
    private_class_method :_primitive_items

    # The value of the given length expression in inches - "@thickness -
    # 2mm" - nil if it can't be read, isn't a length, or uses a variable not
    # given. Unlike the VCB, a bare number is a factor : a descriptor can't
    # depend on the units of the model it is used in.
    def self._evaluate_length(expression, variables)
      value, dimension = LengthExpressionUtils.evaluate(
        expression,
        read_literal: lambda { |literal|
          next [ literal.include?('/') ? literal.split('/').map { |v| v.tr(',', '.').to_f }.reduce(:/) : literal.tr(',', '.').to_f, 0 ] if LengthExpressionUtils.bare_number?(literal)
          [ LengthExpressionUtils.literal_to_inches(literal), 1 ]
        },
        read_variable: lambda { |name|
          value = variables[name]
          raise LengthExpressionUtils::LengthExpressionError.new('syntax_error') unless value.is_a?(Numeric)
          [ value.to_f, 1 ]
        }
      )
      return nil unless dimension == 1 && value.finite?
      value
    rescue LengthExpressionUtils::LengthExpressionError, ZeroDivisionError
      nil
    end
    private_class_method :_evaluate_length

    # The file name of the given part of the given slot's component - or of
    # its given variant : "a.skp", "a.overlay.machining.skp".
    def self.part_file_name(slot, variant, part)
      [ slot, variant, part == PART_MACHINING ? PART_MACHINING : nil ].compact.join('.') + '.skp'
    end

    # path : the file the descriptor was read from ; ref : its '$LIB/…' or
    # '$OCL/…' ref when it lives in a library - its parts are then refs of
    # that library.
    def initialize(data, path = nil, ref = nil)
      @data = data
      @path = path
      @ref = ref
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

    def name
      @data['name']
    end

    def supplier
      @data['supplier']
    end

    def url
      @data['url']
    end

    def hardware_material
      _resolve_ref(@data['hardware_material'])
    end

    def slots
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

    # The folder the files of the parts declared true live in : the
    # descriptor's place mirrored under the components folder of its library
    # - '$LIB/hinges/blum/Mine.json' -> '$LIB/components/hinges/blum/Mine'.
    # Out of a library, a folder named after the descriptor next to it. nil
    # when the descriptor has no file.
    def components_dir_ref
      if @ref.is_a?(String)
        prefix = LIBRARY_REF_PREFIXES.find { |p| @ref.start_with?(p) }
        relative = @ref[prefix.length..-1]
        return prefix + COMPONENTS_DIR_NAME + '/' + relative.sub(/#{Regexp.escape(File.extname(relative))}\z/, '')
      end
      return nil unless @path.is_a?(String)
      File.join(File.dirname(@path), File.basename(@path, File.extname(@path)))
    end

    # -- Resolution --

    # The component of the given slot, resolved for the given context - the
    # measures the tool took, keyed by the "by" of the variants they select :
    # { 'hinge_kind' => 'inset', 'depth' => <Length>, … }. nil when the slot is
    # empty, or no variant fits.
    def resolve_component(slot, context = {})
      _resolve_component(slot.to_s, _stringify_keys(context), false, [])
    end

    # -----

    private

    def _resolve_component(slot, context, mirror, visited)
      return nil if visited.include?(slot)   # Cycle
      visited = visited + [ slot ]
      components = @data['components']
      return nil unless components.is_a?(Hash)
      _resolve_value(slot, components[slot], context, mirror, visited)
    end

    # slot : the one whose component value is - the source slot.
    def _resolve_value(slot, value, context, mirror, visited, variant = nil, attributes = {}, info = {})
      return nil unless value.is_a?(Hash)
      attributes = attributes.merge(value['attributes']) if value['attributes'].is_a?(Hash)
      if value.key?('same_as')
        resolved = _resolve_component(value['same_as'].to_s, context, mirror, visited)
      elsif value.key?('mirror_of')
        resolved = _resolve_component(value['mirror_of'].to_s, context, !mirror, visited)
      elsif value.key?('variants')
        key = _select_variant(value['variants'], context)
        return nil if key.nil?
        return _resolve_value(slot, value['variants']['items'][key], context, mirror, visited, key, attributes, info.merge(_info(value)))
      else
        own_info = _info(value)
        merged_info = info.merge(own_info)   # The variant's over the component's
        hardware, hardware_slot = _resolve_part(slot, variant, PART_HARDWARE, value[PART_HARDWARE], context, visited)
        machining, machining_slot = _resolve_part(slot, variant, PART_MACHINING, value[PART_MACHINING], context, visited)
        return HardwareComponentDef.new(
          slot, slot,
          hardware, machining,
          mirror, value['stretch'], variant, attributes,
          variant.nil? ? own_info['name'] : info['name'],
          variant.nil? ? nil : own_info['name'],
          merged_info['description'], merged_info['price'], merged_info['url'], merged_info['mass'],
          { PART_HARDWARE => hardware_slot, PART_MACHINING => machining_slot }
        )
      end
      return nil if resolved.nil?
      resolved.slot = slot
      resolved
    end

    # The fields the cut list reads the given component value gives.
    def _info(value)
      value.select { |key, _| INFO_KEYS.include?(key) && !value[key].nil? }
    end

    # The ref of the given part of the given slot's component - or of its
    # given variant - nil when there is none, and the slot whose component
    # the part comes from : [ ref, slot ].
    def _resolve_part(slot, variant, part, value, context, visited)
      if value.is_a?(Hash) && value.key?('same_as')
        resolved = _resolve_component(value['same_as'].to_s, context, false, visited)
        return [ nil, nil ] if resolved.nil?
        return [ resolved.send(part), resolved.part_slots[part] ]
      end
      ref = _resolve_part_ref(slot, variant, part, value)
      [ ref, ref.nil? ? nil : slot ]
    end

    def _resolve_part_ref(slot, variant, part, value)
      if value == true
        dir = components_dir_ref
        return nil if dir.nil?
        return "#{dir}/#{self.class.part_file_name(slot, variant, part)}"
      end
      return value if value.is_a?(Hash)   # Primitives
      return nil unless value.is_a?(String) && !value.strip.empty?
      return _resolve_ref(value) if value.start_with?('./') || self.class.library_ref?(value) || File.extname(value).downcase != '.skp'
      if @ref.is_a?(String)   # A file shared in the components folder of the library
        prefix = LIBRARY_REF_PREFIXES.find { |p| @ref.start_with?(p) }
        return prefix + COMPONENTS_DIR_NAME + '/' + value
      end
      return value unless @path.is_a?(String)   # Nowhere to look from
      File.join(File.dirname(@path), value)
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
      %w[supplier url].each do |key|
        errors << "#{key} is not a string" if @data.key?(key) && !@data[key].nil? && !@data[key].is_a?(String)
      end

      components = @data['components']
      if components.is_a?(Hash)
        components.each do |slot, value|
          errors << "unknown slot '#{slot}'" unless slots.include?(slot)
          _validate_component(slot, value, errors)
        end
        errors << 'no component' if TYPES.key?(@data['type']) && slots.all? { |slot| components[slot].nil? }
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

    # path : the slot, then the variant's key - 'a', 'a/inset'.
    def _validate_component(path, value, errors)
      return if value.nil?
      unless value.is_a?(Hash)
        errors << "component '#{path}' is not an object"
        return
      end
      _validate_attributes(path, value['attributes'], errors) if value.key?('attributes')
      _validate_info(path, value, errors)
      if value.key?('same_as') || value.key?('mirror_of')
        errors << "component '#{path}' links to another slot and has attributes" if value.key?('attributes')
        errors << "component '#{path}' links to another slot and has #{(value.keys & INFO_KEYS).join(', ')}" unless (value.keys & INFO_KEYS).empty?
        target = value.key?('same_as') ? value['same_as'] : value['mirror_of']
        errors << "component '#{path}' links to unknown slot #{target.inspect}" unless slots.include?(target)
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
          errors << "component '#{path}' variant '#{key}' links to another slot" if item.is_a?(Hash) && (item.key?('same_as') || item.key?('mirror_of') || item.key?('variants'))
          _validate_component("#{path}/#{key}", item, errors)
        end
      else
        present = PARTS.select { |part| _validate_part(path, part, value[part], errors) }
        errors << "component '#{path}' has neither hardware nor machining" if present.empty?
      end
    end

    # Is the given part declared - valid or not ?
    def _validate_part(path, part, value, errors)
      return false if value.nil? || value == false
      return true if value == true
      if value.is_a?(String)
        errors << "component '#{path}' #{part} is an empty path" if value.strip.empty?
        return !value.strip.empty?
      end
      if value.is_a?(Hash) && value.key?('same_as')
        slot = path.split('/').first
        errors << "component '#{path}' #{part} links to unknown slot #{value['same_as'].inspect}" unless slots.include?(value['same_as'])
        errors << "component '#{path}' #{part} links to itself" if value['same_as'] == slot
        return true
      end
      if value.is_a?(Hash)
        _validate_primitives(path, part, value, errors)
        return true
      end
      errors << "component '#{path}' #{part} is neither true, a path nor a link"
      true
    end

    def _validate_primitives(path, part, value, errors)
      if value.empty?
        errors << "component '#{path}' #{part} is neither true, a path nor a link"
        return
      end
      (value.keys - PRIMITIVES[part]).each do |key|
        errors << "component '#{path}' #{part} has an unknown primitive '#{key}'"
      end
      _validate_primitive_list(path, part, value, MACHINING_DRILLINGS, 'drilling', %w[x y diameter depth], errors) do |drilling, label|
        unless drilling['depth'] == DRILLING_DEPTH_THROUGH || !_to_checked_length(drilling['depth'], false).nil?
          errors << "#{label} depth is neither \"#{DRILLING_DEPTH_THROUGH}\" nor a positive length"
        end
      end
      _validate_primitive_list(path, part, value, HARDWARE_CYLINDERS, 'cylinder', %w[x y diameter from to], errors) do |cylinder, label|
        from = _to_checked_length(cylinder['from'], true)
        to = _to_checked_length(cylinder['to'], true)
        errors << "#{label} from is not a length" if from.nil?
        errors << "#{label} to is not a length" if to.nil?
        # Checkable only without variables : they change with where it is laid
        errors << "#{label} to is not above from" if !from.nil? && !to.nil? && to <= from && [ cylinder['from'], cylinder['to'] ].none? { |v| v.is_a?(String) && v =~ VARIABLE_PATTERN }
      end
    end

    # The given length checked as a descriptor holds it : its variables set
    # to a typical measure - 18 mm - nil if it isn't one.
    def _to_checked_length(value, negative_allowed)
      self.class.to_length(value, negative_allowed, Hash[VARIABLES.map { |name| [ name, 18 / 25.4 ] }])
    end

    # Validates the list of the given primitive - x, y and diameter - then
    # yields each item and the label of its errors for what is its own.
    def _validate_primitive_list(path, part, value, key, name, keys, errors)
      return unless PRIMITIVES[part].include?(key) && value.key?(key)
      items = value[key]
      unless items.is_a?(Array) && !items.empty?
        errors << "component '#{path}' #{part} #{key} is not a list of #{key}"
        return
      end
      items.each_with_index do |item, index|
        label = "component '#{path}' #{name} #{index + 1}"
        unless item.is_a?(Hash)
          errors << "#{label} is not an object"
          next
        end
        (item.keys - keys).each do |k|
          errors << "#{label} has an unknown key '#{k}'"
        end
        item.each do |k, v|
          next unless v.is_a?(String)
          (v.scan(VARIABLE_PATTERN).flatten - VARIABLES).uniq.each do |name|
            errors << "#{label} #{k} uses the unknown variable @#{name}"
          end
        end
        %w[x y].each do |k|
          errors << "#{label} #{k} is not a length" if item.key?(k) && !item[k].nil? && _to_checked_length(item[k], true).nil?
        end
        errors << "#{label} diameter is not a positive length" if _to_checked_length(item['diameter'], false).nil?
        yield(item, label)
      end
    end

    def _validate_info(path, value, errors)
      %w[name description url].each do |key|
        errors << "component '#{path}' #{key} is not a string" if value.key?(key) && !value[key].nil? && !value[key].is_a?(String)
      end
      %w[price mass].each do |key|
        errors << "component '#{path}' #{key} is neither a number nor a string" if value.key?(key) && !value[key].nil? && !value[key].is_a?(Numeric) && !value[key].is_a?(String)
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

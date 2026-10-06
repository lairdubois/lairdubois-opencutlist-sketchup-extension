module Ladb::OpenCutList

  require 'json'
  require_relative '../../model/hardware/hardware_descriptor_def'
  require_relative '../../model/hardware/hardware_bench_def'

  # What the hardware editor shows of a descriptor on its test bench - see
  # HardwareBenchDef : the panels, the variables and asserts evaluated there,
  # the solids of the primitives and the SKP files to lay, in the bench frame.
  # Called on each edit : it reads neither the model nor a file.
  #
  # Lengths are in inches, as numbers, and as text in the model's units -
  # *_text. A result that differs from slot to slot - it uses an unsuffixed
  # measure - is given per group of slots it is the same for.
  class HardwareBenchComputeWorker

    DEFAULT_THICKNESS = 19 / 25.4

    # descriptor : the JSON text - as edited, maybe invalid - or its parsed
    # Hash ; ref : its '$LIB/…' or '$OCL/…' ref, its parts declared true are
    # found by - see HardwareDescriptorDef#components_dir_ref - nil for a new
    # one ; topology : one of HardwareBenchDef::TOPOLOGIES, nil for the
    # type's first ; thickness_a, thickness_b : lengths - numbers are
    # millimeters, strings as typed, a bare number in the model's unit ;
    # swapped : a and b swapped, where the topology can be - see
    # HardwareBenchDef#swappable?.
    def initialize(descriptor:,

                   ref: nil,
                   topology: nil,
                   thickness_a: nil,
                   thickness_b: nil,
                   swapped: false
    )

      @descriptor = descriptor
      @ref = HardwareDescriptorDef.library_ref?(ref) ? ref : nil
      @topology = topology
      @thickness_a = thickness_a
      @thickness_b = thickness_b
      @swapped = swapped == true

    end

    # -----

    def run

      data = @descriptor
      if data.is_a?(String)
        begin
          data = JSON.parse(data)
        rescue JSON::ParserError => e
          return { :errors => [ "json: #{_json_error(e)}" ], :supported => false }
        end
      end
      return { :errors => [ 'not an ocl-hardware descriptor' ], :supported => false } unless HardwareDescriptorDef.descriptor?(data)

      descriptor = HardwareDescriptorDef.new(data, nil, @ref)
      response = { :errors => descriptor.errors.dup, :type => descriptor.type, :abstract => descriptor.abstract?, :inheritance => _inheritance(descriptor) }

      unless HardwareBenchDef.supported?(descriptor.type)
        response[:supported] = false
        return response
      end

      thickness_a = HardwareDescriptorDef.to_length(_typed_length(@thickness_a)) || DEFAULT_THICKNESS
      thickness_b = HardwareDescriptorDef.to_length(_typed_length(@thickness_b)) || DEFAULT_THICKNESS
      # 0 - or less - is a height the tool lays at, as it reads it : negative allowed
      height = descriptor.option('height')
      height = HardwareDescriptorDef.to_length(height, true) unless height.nil? || height.start_with?('/', '*')
      bench_def = HardwareBenchDef.new(descriptor.type, @topology, thickness_a, thickness_b, @swapped, height)
      bench_def = HardwareBenchDef.new(descriptor.type, nil, thickness_a, thickness_b, @swapped, height) unless bench_def.valid?

      slots = descriptor.slots & %w[a b]
      variables_by_slot = Hash[slots.map { |slot| [ slot, descriptor.resolve_variables(bench_def.slot_measures(slot)) ] }]

      response.merge!(
        :supported => true,
        :topology => bench_def.topology,
        :topologies => HardwareBenchDef::TOPOLOGIES[descriptor.type],
        :swappable => bench_def.swappable?,
        :swapped => bench_def.swapped,
        :thickness_a => thickness_a,
        :thickness_b => thickness_b,
        :view_transformation => bench_def.view_transformation,
        :panels => bench_def.panels.map { |panel_def| { :slot => panel_def.slot, :min => panel_def.min, :max => panel_def.max, :reference => panel_def.reference } },
        :measures => _measures(descriptor, bench_def),
        :settings => _settings(descriptor),
        :variables => _variables(descriptor, slots, variables_by_slot),
        :asserts => _asserts(descriptor, slots, variables_by_slot),
        :slots => {},
        :solids => [],
        :skps => []
      )

      slots.each do |slot|
        _slot(descriptor, bench_def, slot, variables_by_slot[slot], response)
      end
      response[:accepted] = response[:asserts].all? { |assert| assert[:results].all? { |result| result[:ok] } } &&
                            response[:slots].values.all? { |slot| slot[:component].nil? || (slot[:component][:articles] || []).all? { |article| article[:ok] != false } }

      response
    rescue StandardError => e
      { :errors => [ "#{e.class}: #{e.message}" ], :supported => false }
    end

    # -----

    private

    # The measures of the joint the descriptor uses - the thicknesses always -,
    # with where they are taken - see HardwareBenchDef#measure_cotes.
    def _measures(descriptor, bench_def)
      used = descriptor.used_measures
      cotes = bench_def.measure_cotes
      bench_def.measures
               .select { |name, _| used.include?(name) || name =~ /\Athickness_[ab]\z/ }
               .map { |name, value| { :name => name, :value => value, :text => _text(value), :cote => cotes[name] } }
    end

    # What it inherits - see "extends" - : its parents, the nearest first,
    # its data merged with theirs, and theirs alone. nil when it extends none.
    def _inheritance(descriptor)
      return nil if descriptor.parent_refs.empty?
      { :parents => descriptor.parent_refs, :data => descriptor.data, :parent_data => descriptor.parent_data }
    end

    # Is the given variable its parents' only - not written in its own data ?
    def _inherited_variable?(descriptor, name)
      return false if descriptor.parent_refs.empty?
      own = descriptor.own_data['variables']
      !(own.is_a?(Hash) && own.key?(name))
    end

    def _settings(descriptor)
      descriptor.settings.map do |name, setting|
        {
          :name => name,
          :inherited => _inherited_variable?(descriptor, name),
          :label => setting['label'].is_a?(String) ? setting['label'] : nil,
          :raw => setting,
          :value => _length(setting['value']),
          :steps => setting['steps'].is_a?(Array) ? setting['steps'].map { |step| (_length(step) || {}).merge(:raw => step) } : nil,
          :min => setting.key?('min') ? _length(setting['min']) : nil,
          :max => setting.key?('max') ? _length(setting['max']) : nil,
        }
      end
    end

    def _variables(descriptor, slots, variables_by_slot)
      descriptor.variables.map do |name, expression|
        results = slots.map do |slot|
          variables = variables_by_slot[slot]
          if variables.key?(name)
            { :value => variables[name], :text => _text(variables[name]) }
          else
            key, params = HardwareDescriptorDef.length_error(expression, true, variables)
            { :error => { :key => key, :params => params } }
          end
        end
        {
          :name => name,
          :expression => expression.to_s,
          :setting => HardwareDescriptorDef.setting?(descriptor.data['variables'][name]),
          :results => _group(slots, results)
        }
      end
    end

    def _asserts(descriptor, slots, variables_by_slot)
      descriptor.asserts.map do |expression|
        results = slots.map do |slot|
          left, operator, right = HardwareDescriptorDef.assert_sides(expression, variables_by_slot[slot])
          {
            :ok => HardwareDescriptorDef.assert?(expression, variables_by_slot[slot]) == true,
            :operator => operator,
            :left => left, :left_text => _text(left),
            :right => right, :right_text => _text(right),
          }
        end
        { :expression => expression.to_s, :results => _group(slots, results) }
      end
    end

    # The component of the given slot on the bench : its solids and SKP
    # files added to the response.
    def _slot(descriptor, bench_def, slot, variables, response)
      component = descriptor.resolve_component(slot, bench_def.context)
      slot_matrix = bench_def.slot_transformation(slot)
      if component.nil?
        # Its variant all the same : an empty one is edited as any other
        response[:slots][slot] = { :transformation => slot_matrix, :component => nil, :variant => descriptor.selected_variant(slot, bench_def.context) }
        return
      end
      mirror = component.mirror ? MIRROR_X : IDENTITY
      response[:slots][slot] = {
        :transformation => slot_matrix,
        :component => {
          :source_slot => component.source_slot,
          :variant => component.variant,
          :name => component.variant_name || component.name,
          :mirror => component.mirror ? true : false,
        },
        # What the lengths of its primitives and articles can use, as the
        # editor offers them - the slot's own measures unsuffixed only
        :names => variables
          .reject { |name, _| bench_def.measures.key?(name) && name.end_with?("_#{slot}") }
          .map { |name, length| { :name => name, :text => _text(length) } }
      }
      hardware_z_offset = component.z_offset.nil? ? 0.0 : HardwareDescriptorDef.to_length(component.z_offset, true, variables) || 0.0
      if bench_def.hinge? && slot == 'a'
        # Borne by its hardware - whether its file is found or not
        response[:hinge] = _hinge(component, _multiply(slot_matrix, _multiply(mirror, _translation(0, 0, hardware_z_offset))))
      end
      HardwareDescriptorDef::PARTS.each do |part|
        value = component.send(part)
        next if value.nil?
        z_offset = part == HardwareDescriptorDef::PART_HARDWARE ? hardware_z_offset : 0.0
        part_matrix = _multiply(slot_matrix, _multiply(mirror, _translation(0, 0, z_offset)))
        if HardwareDescriptorDef.primitives?(value)
          # Each primitive alone : its solid known by its key and index
          primitives = response[:slots][slot][:component][:primitives] ||= {}
          primitives[part] = {}
          cylinders = []
          HardwareDescriptorDef::PRIMITIVES[part].each do |key|
            next unless value[key].is_a?(Array)
            primitives[part][key] = value[key].each_with_index.map do |item, index|
              next nil unless item.is_a?(Hash)
              cylinder = HardwareDescriptorDef.primitive_cylinders({ key => [ item ] }, variables, HardwareDescriptorDef.height_reversed?(bench_def.type, slot)).first
              cylinders << [ cylinder, key, index ] unless cylinder.nil?
              { :resolved => !cylinder.nil?, :fields => _primitive_fields(item, variables) }
            end
          end
          cylinders.each do |cylinder, key, index|
            axis_matrix = AXIS_MATRICES[cylinder.axis] || IDENTITY
            # Its position cotes, in the frame of its part - its x, y, z as
            # the descriptor gives them - : from the origin to its axis, on
            # the plane of the joint or its nearest end
            lift = [ [ 0.0, cylinder.z_min.to_f ].max, cylinder.z_max.to_f ].min
            cotes_origin = _apply(axis_matrix, [ 0.0, 0.0, lift ])
            cotes_position = _apply(axis_matrix, [ cylinder.x.to_f, cylinder.y.to_f, lift ])
            texts = {
              :diameter => _text(cylinder.diameter),
              :length => _text(cylinder.length),
              :depth => _text(cylinder.z_max - cylinder.z_min),
            }
            unless cylinder.prism?   # Placed by its outline : no position
              texts[:x] = _text(cotes_position[0] - cotes_origin[0])
              texts[:y] = _text(cotes_position[1] - cotes_origin[1])
              texts[:z] = _text(cotes_position[2] - cotes_origin[2])
            end
            response[:solids] << {
              :slot => slot,
              :part => part,
              :key => key,
              :index => index,
              :transformation => _multiply(part_matrix, axis_matrix),
              :part_transformation => part_matrix,
              :cotes => cylinder.prism? ? nil : { :origin => cotes_origin, :position => cotes_position },
              :x => cylinder.x, :y => cylinder.y,
              :diameter => cylinder.diameter,
              :z_min => cylinder.z_min, :z_max => cylinder.z_max,
              :length => cylinder.length,
              :profile => cylinder.profile,
              :outline => _prism_outline(cylinder),
              # What the viewer tells of it when hovered
              :kind => cylinder.key,
              :axis => _descriptor_axis(cylinder),  # As the descriptor gives it
              :texts => texts,
            }
            # The editor's row tells the same
            primitives[part][key][index][:texts] = texts
          end
          count = HardwareDescriptorDef::PRIMITIVES[part].inject(0) { |sum, key| sum + (value[key].is_a?(Array) ? value[key].count { |item| item.is_a?(Hash) } : 0) }
          response[:slots][slot][:component][:"#{part}_unresolved"] = count - cylinders.length
        else
          response[:skps] << { :slot => slot, :part => part, :ref => value, :variant => component.variant, :transformation => part_matrix }
        end
      end
      _articles(bench_def, slot, component, variables, _multiply(slot_matrix, mirror), response) unless component.articles.nil?
    end

    # The articles of the given component on the bench - see
    # HardwareDescriptorDef "hardware" : what the editor tells of each, and
    # their solids and SKP files at each of their positions - those of a
    # used connector evaluated with its own variables, its virtual side Z
    # reversed, its host side's machining drilled in the slot's part.
    def _articles(bench_def, slot, component, variables, matrix, response)
      response[:slots][slot][:component][:articles] = component.articles.map do |article|
        positions = (article.at.is_a?(Array) ? article.at : [ {} ]).map { |item|
          item = {} unless item.is_a?(Hash)
          fields = {}
          HardwareDescriptorDef::ARTICLE_AT_KEYS.each do |k|
            value = item[k].nil? ? 0 : item[k]
            length = HardwareDescriptorDef.to_length(value, true, variables)
            if length.nil?
              key, params = HardwareDescriptorDef.length_error(value, true, variables)
              fields[k.to_sym] = { :error => { :key => key || 'not_a_length', :params => params || {} } }
            else
              fields[k.to_sym] = { :value => length, :text => _text(length) }
            end
          end
          fields
        }
        # [ index, x, y, z ] : the index the editor knows the position by
        resolved = positions.each_with_index.select { |fields, _| fields.values.all? { |field| !field[:value].nil? } }.map { |fields, index| [ index, fields[:x][:value], fields[:y][:value], fields[:z][:value] ] }
        result = { :key => article.key, :name => article.name, :use => article.use, :positions => positions }
        if article.use?
          _used_article(bench_def, slot, article, variables, matrix, resolved, result, response)
        else
          result[:kind] = article.hardware.is_a?(String) ? 'skp' : 'primitives'
          if HardwareDescriptorDef.primitives?(article.hardware)
            # What the editor tells of each, as for the slot's - see _slot
            result[:primitives] = Hash[HardwareDescriptorDef::PRIMITIVES[HardwareDescriptorDef::PART_HARDWARE].select { |k| article.hardware[k].is_a?(Array) }.map { |k|
              [ k, article.hardware[k].map { |item|
                next nil unless item.is_a?(Hash)
                cylinder = HardwareDescriptorDef.primitive_cylinders({ k => [ item ] }, variables).first
                fields = _primitive_fields(item, variables)
                texts = nil
                unless cylinder.nil?
                  x, y, z = _descriptor_position(cylinder)
                  texts = { :x => _text(x), :y => _text(y), :z => _text(z),
                            :diameter => _text(cylinder.diameter), :length => _text(cylinder.length), :depth => _text(cylinder.z_max - cylinder.z_min) }
                end
                { :resolved => !cylinder.nil?, :fields => fields, :texts => texts }
              } ]
            }]
          end
          sub = { :hardware => article.hardware, :mirror => false, :z_offset => nil }
          _article_geometry(slot, article.key, HardwareDescriptorDef::PART_HARDWARE, sub, variables, IDENTITY, matrix, resolved, response)
        end
        result
      end
    end

    # A used connector's article - see _articles.
    def _used_article(bench_def, slot, article, variables, matrix, positions, result, response)
      result[:kind] = 'use'
      result[:host] = article.host
      result[:axis] = article.axis
      used = article.descriptor
      if used.nil?
        result[:missing] = true
        result[:ok] = false
        return
      end
      result[:used_name] = used.name
      expression = article.measures[HardwareDescriptorDef::VARIABLE_THICKNESS]
      thickness = HardwareDescriptorDef.to_length(expression, false, variables)
      if thickness.nil?
        key, params = HardwareDescriptorDef.length_error(expression, false, variables)
        result[:virtual] = { :measure => "thickness_#{article.other_slot}", :error => { :key => key || 'not_a_length', :params => params || {} } }
        result[:ok] = false
        return
      end
      result[:virtual] = { :measure => "thickness_#{article.other_slot}", :value => thickness, :text => _text(thickness) }
      slot_measures = bench_def.slot_measures(slot).reject { |name, _| name.end_with?('_a', '_b') }
      # Each with the connector's own value : the one an override replaces
      result[:settings] = used.settings.map { |name, setting|
        overridden = article.overrides.key?(name)
        own = overridden && used.parent_data.is_a?(Hash) && used.parent_data['variables'].is_a?(Hash) ? used.parent_data['variables'][name] : setting
        {
          :name => name, :label => setting['label'].is_a?(String) ? setting['label'] : nil,
          :value => _length(setting['value']),
          :default => _length(HardwareDescriptorDef.setting?(own) ? own['value'] : nil),
          :overridden => overridden,
          :steps => setting['steps'].is_a?(Array) ? setting['steps'].map { |step| _length(step) } : nil,
        }
      }
      # Along Y : its thicknesses taken from the edge, see
      # HardwareBenchDef#edge_depth
      if article.along_y?
        depth = bench_def.edge_depth(slot)
        if depth.nil?
          result[:ok] = false
          return
        end
        slot_measures = slot_measures.merge(
          HardwareDescriptorDef::VARIABLE_THICKNESS => depth,
          HardwareDescriptorDef::VARIABLE_THICKNESS_MIN => depth,
          HardwareDescriptorDef::VARIABLE_THICKNESS_MAX => depth
        )
      end
      height = slot_measures[HardwareDescriptorDef::VARIABLE_HEIGHT]
      reversed = HardwareDescriptorDef.height_reversed?(bench_def.type, slot)
      frame = article.along_y? ? (reversed ? AXIS_Y_REVERSED : AXIS_MATRICES[HardwareDescriptorDef::AXIS_Y]) : IDENTITY
      # Its measures depend on how far each position lifts it off the face
      # it goes in by - see HardwareArticleDef#lift : evaluated at each lift
      # - the variables told at the first one, the asserts at each, the
      # coordinate they fail at told when they differ
      groups = positions.group_by { |position| article.lift(position[1, 3], height, reversed).to_f.round(6) }
      groups = { 0.0 => [] } if groups.empty?
      result[:asserts] = []
      groups.each_with_index do |(lift, group), group_index|
        joint = article.joint_measures(slot_measures, variables, lift)
        used_variables = used.resolve_variables(article.side_measures(joint, article.host))
        result[:variables] = used.variables.keys.select { |name| used_variables.key?(name) }.map { |name| { :name => name, :value => used_variables[name], :text => _text(used_variables[name]) } } if group_index == 0
        used.asserts.each do |assert|
          left, operator, right = HardwareDescriptorDef.assert_sides(assert, used_variables)
          entry = { :expression => assert, :ok => HardwareDescriptorDef.assert?(assert, used_variables) == true, :operator => operator,
                    :left => left, :left_text => _text(left), :right => right, :right_text => _text(right) }
          entry[:z_text] = _text(group.first[article.along_y? ? 2 : 3]) if groups.length > 1 && !group.empty?
          result[:asserts] << entry
        end
        [ article.host, article.other_slot ].each do |side|
          used_component = used.resolve_component(side)
          next if used_component.nil?
          side_variables = used.resolve_variables(article.side_measures(joint, side))
          side_matrix = side == article.host ? frame : _multiply(frame, FLIP_Z)
          sub = { :hardware => used_component.hardware, :mirror => used_component.mirror, :z_offset => used_component.z_offset }
          _article_geometry(slot, article.key, HardwareDescriptorDef::PART_HARDWARE, sub, side_variables, side_matrix, matrix, group, response)
          next unless side == article.host && HardwareDescriptorDef.primitives?(used_component.machining)
          sub = { :hardware => used_component.machining, :mirror => used_component.mirror, :z_offset => nil }
          _article_geometry(slot, article.key, HardwareDescriptorDef::PART_MACHINING, sub, side_variables, frame, matrix, group, response)
        end
      end
      result[:ok] = result[:asserts].all? { |assert| assert[:ok] }
    end

    # The solids or SKP of one geometry of an article - its hardware ref or
    # primitives, mirror and z_offset in sub - at each of the given positions
    # [ index, x, y, z ] of the slot, by the given matrices : the side one in the
    # article's frame, then the slot's.
    def _article_geometry(slot, key, part, sub, variables, side_matrix, matrix, positions, response)
      value = sub[:hardware]
      return if value.nil?
      z_offset = sub[:z_offset].nil? ? 0.0 : HardwareDescriptorDef.to_length(sub[:z_offset], true, variables) || 0.0
      local = _multiply(side_matrix, _multiply(sub[:mirror] ? MIRROR_X : IDENTITY, _translation(0, 0, z_offset)))
      cylinders = nil
      if HardwareDescriptorDef.primitives?(value)
        # Each primitive alone : its solid known by its key and index
        cylinders = []
        HardwareDescriptorDef::PRIMITIVES[part].each do |primitive_key|
          next unless value[primitive_key].is_a?(Array)
          value[primitive_key].each_with_index do |item, index|
            next unless item.is_a?(Hash)
            cylinder = HardwareDescriptorDef.primitive_cylinders({ primitive_key => [ item ] }, variables).first
            cylinders << [ cylinder, primitive_key, index ] unless cylinder.nil?
          end
        end
      end
      positions.each do |position, x, y, z|
        position_matrix = _multiply(matrix, _multiply(_translation(x, y, z), local))
        if cylinders.nil?
          response[:skps] << { :slot => slot, :part => part, :ref => value, :article => key, :position => position, :transformation => position_matrix } if value.is_a?(String)
          next
        end
        cylinders.each do |cylinder, primitive_key, index|
          response[:solids] << {
            :slot => slot, :part => part, :article => key, :position => position, :key => primitive_key, :index => index,
            :transformation => _multiply(position_matrix, AXIS_MATRICES[cylinder.axis] || IDENTITY),
            :part_transformation => position_matrix,
            :x => cylinder.x, :y => cylinder.y,
            :diameter => cylinder.diameter,
            :z_min => cylinder.z_min, :z_max => cylinder.z_max,
            :length => cylinder.length,
            :profile => cylinder.profile,
            :outline => _prism_outline(cylinder),
            :kind => cylinder.key,
            :axis => _descriptor_axis(cylinder),
            :texts => { :diameter => _text(cylinder.diameter), :length => _text(cylinder.length), :depth => _text(cylinder.z_max - cylinder.z_min) },
          }
        end
      end
    end

    # The axis of the given solid as the descriptor gives it - see
    # HardwareDescriptorDef::PrimitiveCylinderDef#axis.
    def _descriptor_axis(cylinder)
      case cylinder.axis
      when nil, HardwareDescriptorDef::AXIS_Z_LENGTH_Y
        HardwareDescriptorDef::AXIS_Z
      when HardwareDescriptorDef::AXIS_PRISM_X, HardwareDescriptorDef::AXIS_X_LENGTH_Z
        HardwareDescriptorDef::AXIS_X
      else
        HardwareDescriptorDef::AXIS_Y
      end
    end

    # The [ x, y, z ] of the given solid of hardware as the descriptor gives
    # them - its from along its axis - see
    # HardwareDescriptorDef::PrimitiveCylinderDef#axis.
    def _descriptor_position(cylinder)
      case cylinder.axis
      when HardwareDescriptorDef::AXIS_PRISM_X   # [ x, y, z ] is [ z, x, y ]
        [ cylinder.z_min, cylinder.x, cylinder.y ]
      when HardwareDescriptorDef::AXIS_X_LENGTH_Z   # [ x, y, z ] is [ z, -y, x ]
        [ cylinder.z_min, -cylinder.y, cylinder.x ]
      when HardwareDescriptorDef::AXIS_Y   # [ x, y, z ] is [ x, z, -y ]
        [ cylinder.x, cylinder.z_min, -cylinder.y ]
      when HardwareDescriptorDef::AXIS_Y_LENGTH_Z   # [ x, y, z ] is [ -y, z, -x ]
        [ -cylinder.y, cylinder.z_min, -cylinder.x ]
      when HardwareDescriptorDef::AXIS_Z_LENGTH_Y   # [ x, y, z ] is [ -y, x, z ]
        [ -cylinder.y, cylinder.x, cylinder.z_min ]
      else
        [ cylinder.x, cylinder.y, cylinder.z_min ]
      end
    end

    # The points of the outline of the given prism - [ [ u, v ] ]
    # counterclockwise, its roundings in segments - nil when it isn't one.
    def _prism_outline(cylinder)
      return nil unless cylinder.prism?
      HardwareDescriptorDef.prism_points(HardwareDescriptorDef.prism_corners(cylinder.outline))
    end

    PRIMITIVE_LENGTH_FIELDS = %w[x y z diameter length width depth from to].freeze
    PRIMITIVE_SIGNED_FIELDS = %w[x y z from to].freeze

    # The lengths of the given primitive item, evaluated for the given
    # variables : { field => { :text } | { :error => { :key, :params } } },
    # its head's as 'head_diameter' and 'head_depth'. A "through" depth is
    # the one it goes to.
    def _primitive_fields(item, variables)
      fields = {}
      add_field = lambda do |name, value, signed|
        if value == HardwareDescriptorDef::DRILLING_DEPTH_THROUGH
          value = "@#{variables.key?(HardwareDescriptorDef::VARIABLE_THICKNESS_MAX) ? HardwareDescriptorDef::VARIABLE_THICKNESS_MAX : HardwareDescriptorDef::VARIABLE_THICKNESS}"
        end
        length = HardwareDescriptorDef.to_length(value, signed, variables)
        if length.nil?
          key, params = HardwareDescriptorDef.length_error(value, signed, variables)
          fields[name] = { :error => { :key => key || 'not_a_length', :params => params || {} } }
        else
          fields[name] = { :text => _text(length) }
        end
      end
      PRIMITIVE_LENGTH_FIELDS.each do |name|
        add_field.call(name, item[name], PRIMITIVE_SIGNED_FIELDS.include?(name)) if item.key?(name)
      end
      if item['outline'].is_a?(Array)
        # A prism's points : 'outline_<index>_<key>'
        item['outline'].each_with_index do |point, index|
          next unless point.is_a?(Hash)
          point.each do |key, value|
            add_field.call("outline_#{index}_#{key}", value, key != HardwareDescriptorDef::PRISM_RADIUS_KEY)
          end
        end
      end
      head = HardwareDescriptorDef::HEADS.map { |key| item[key] }.find { |value| value.is_a?(Hash) }
      unless head.nil?
        add_field.call('head_diameter', head['diameter'], false) if head.key?('diameter')
        add_field.call('head_depth', head['depth'], false) if head.key?('depth')
      end
      fields
    end

    # The axis the door turns around - see DoorHingeDef - given by the
    # kinematics of the hinge in the frame of its hardware, the given
    # matrix : { :origin, :axis, :max_angle, :approximate, :cotes, :texts }
    # in the bench frame, the door opening by a positive rotation around
    # :axis. :cotes : from the origin of the hardware to the axis, as its y
    # and z give it. nil when its kinematics are incomplete.
    def _hinge(component, matrix)
      attributes = component.attributes
      max_angle = attributes[HardwareDescriptorDef::ATTRIBUTE_HINGE_MAX_ANGLE]
      pivot = HardwareDescriptorDef.hinge_pivot(attributes[HardwareDescriptorDef::ATTRIBUTE_HINGE_PIVOT])
      return nil if pivot.nil? || !HardwareDescriptorDef.hinge_max_angle?(max_angle)
      y, z = pivot
      origin = _apply(matrix, [ 0.0, y, z ])
      axis = _cross(matrix[4, 3], matrix[8, 3])
      norm = Math.sqrt(axis.inject(0) { |sum, v| sum + v * v })
      {
        :origin => origin,
        :axis => axis.map { |v| v / norm },
        :max_angle => max_angle.to_f,
        :approximate => attributes[HardwareDescriptorDef::ATTRIBUTE_HINGE_PIVOT_APPROXIMATE] == true,
        :cotes => { :origin => _apply(matrix, [ 0.0, 0.0, 0.0 ]), :y => _apply(matrix, [ 0.0, y, 0.0 ]), :position => origin },
        :texts => { :y => _text(y), :z => _text(z) },
      }
    end

    def _cross(u, v)
      [ u[1] * v[2] - u[2] * v[1], u[2] * v[0] - u[0] * v[2], u[0] * v[1] - u[1] * v[0] ]
    end

    # The message of the given parse error : its first line, short - an old
    # parser quotes the whole rest of the text.
    def _json_error(error)
      message = error.message.lines.first.to_s.strip
      message.length > 80 ? "#{message[0, 80]}…" : message
    end

    # The given results - one per slot - grouped by value : [ { :slots => […], … } ].
    def _group(slots, results)
      groups = []
      slots.each_with_index do |slot, index|
        group = groups.find { |g| g[:result] == results[index] }
        if group.nil?
          groups << { :result => results[index], :slots => [ slot ] }
        else
          group[:slots] << slot
        end
      end
      groups.map { |g| { :slots => g[:slots] }.merge(g[:result]) }
    end

    # The given thickness as a length expression : a number in millimeters,
    # a typed bare number in the model's unit - as the VCB reads it.
    def _typed_length(value)
      return "#{value}mm" if value.is_a?(Numeric)
      return value unless value.is_a?(String) && !value.strip.empty? && LengthExpressionUtils.bare_number?(value.strip)
      DimensionUtils.str_add_units(value)
    end

    # A plain length of a setting : { :value, :text }, nil if it isn't one.
    def _length(value)
      length = HardwareDescriptorDef.to_length(value, true)
      length.nil? ? nil : { :value => length, :text => _text(length) }
    end

    # Not rounded to the model's precision - 42,7 mm, not ~ 43 mm - its
    # trailing zeros dropped : 15 mm, not 15,000 mm.
    def _text(inches)
      return nil if inches.nil?
      DimensionUtils.to_ocl_precision_s(inches.to_l).sub(/([.,]\d*?)0+(?=\D*\z)/, '\\1').sub(/[.,](?=\D*\z)/, '')
    end

    # -- 4x4 matrices, column after column --

    IDENTITY = [ 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1 ].freeze
    MIRROR_X = [ -1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1 ].freeze
    FLIP_Z = [ 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, -1, 0, 0, 0, 0, 1 ].freeze   # The virtual side of a used connector
    # An article along Y when the height is reversed : [ x, y, z ] -> [ x, -z, y ] - see SmartJoinTool::TRANSFORMATION_ARTICLE_AXIS_Y_REVERSED
    AXIS_Y_REVERSED = [ 1, 0, 0, 0, 0, 0, 1, 0, 0, -1, 0, 0, 0, 0, 0, 1 ].freeze

    # The frames the primitives along Y - or turned on Z - are given in - see
    # HardwareDescriptorDef::PrimitiveCylinderDef#axis and
    # SmartJoinActionHandler::TRANSFORMATION_AXIS_Y.
    AXIS_MATRICES = {
      HardwareDescriptorDef::AXIS_Y => [ 1, 0, 0, 0, 0, 0, -1, 0, 0, 1, 0, 0, 0, 0, 0, 1 ].freeze,           # [ x, y, z ] -> [ x, z, -y ]
      HardwareDescriptorDef::AXIS_Y_LENGTH_Z => [ 0, 0, -1, 0, -1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1 ].freeze,  # [ x, y, z ] -> [ -y, z, -x ]
      HardwareDescriptorDef::AXIS_Z_LENGTH_Y => [ 0, 1, 0, 0, -1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1 ].freeze,   # [ x, y, z ] -> [ -y, x, z ]
      HardwareDescriptorDef::AXIS_PRISM_X => [ 0, 1, 0, 0, 0, 0, 1, 0, 1, 0, 0, 0, 0, 0, 0, 1 ].freeze,      # [ u, v, w ] -> [ w, u, v ]
      HardwareDescriptorDef::AXIS_PRISM_Y => [ 1, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0, 0, 0, 0, 0, 1 ].freeze,      # [ u, v, w ] -> [ u, w, v ]
      HardwareDescriptorDef::AXIS_X_LENGTH_Z => [ 0, 0, 1, 0, 0, -1, 0, 0, 1, 0, 0, 0, 0, 0, 0, 1 ].freeze,  # [ x, y, z ] -> [ z, -y, x ]
    }.freeze

    def _translation(x, y, z)
      [ 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, x, y, z, 1 ]
    end

    # The given point by the given column-major 4x4 matrix
    def _apply(m, point)
      (0...3).map { |row| m[row] * point[0] + m[4 + row] * point[1] + m[8 + row] * point[2] + m[12 + row] }
    end

    def _multiply(a, b)
      (0...4).flat_map { |col| (0...4).map { |row| (0...4).inject(0) { |sum, k| sum + a[k * 4 + row] * b[col * 4 + k] } } }
    end

  end

end

module Ladb::OpenCutList

  require_relative 'hardware_descriptor_def'
  require_relative '../../utils/dimension_utils'

  # The options of a SmartJoin action a hardware descriptor can give the
  # default of - see HardwareDescriptorDef "options" - read from three
  # levels, the first that has it :
  #  1. the user's override for the picked hardware - the preset's
  #     "hardware_options", keyed by the descriptor's id ;
  #  2. the descriptor's options ;
  #  3. the action's base value - the preset's own.
  # Picking a hardware writes nothing : the values of the one picked before
  # never linger. A change goes to the level the value came from : an
  # override when the descriptor defines the option, the base otherwise.
  # See the spec "Options actuelles et presets".
  class HardwareOptionsDef

    # The global presets of the SmartJoin actions - see SmartJoinTool
    DICTIONARY = 'tool_smart_join_options'.freeze
    OPTION_HARDWARE = 'hardware'.freeze
    OPTION_HARDWARE_OPTIONS = 'hardware_options'.freeze   # { "<descriptor id>" => { "<option>" => "<value>" } }

    LENGTH_OPTIONS = %w[height start_offset end_offset min_spacing max_spacing].freeze
    OPTIONS = (LENGTH_OPTIONS + %w[hardware_material_name machining_material_name hardware_layer_name machining_layer_name]).freeze

    SOURCE_BASE = :base
    SOURCE_HARDWARE = :hardware
    SOURCE_OVERRIDE = :override

    @descriptor_defs = {}   # ref => HardwareDescriptorDef

    # The usable descriptor of the given ref - nil if there is none. Kept
    # while its files - its parents' too - don't change.
    def self.descriptor_def(ref)
      return nil unless ref.is_a?(String) && !ref.strip.empty?
      descriptor = @descriptor_defs[ref]
      if descriptor.nil? || descriptor.stale?
        descriptor = HardwareDescriptorDef.load(ref)
        descriptor = nil unless descriptor.nil? || (!descriptor.abstract? && descriptor.valid?)
        @descriptor_defs[ref] = descriptor
      end
      descriptor
    end

    def self.option?(option)
      OPTIONS.include?(option.to_s)
    end

    attr_reader :section, :preset, :descriptor

    # The given preset - the action's, read when nil - as it stands.
    def initialize(section, preset = nil)
      @section = section
      @preset = preset || PLUGIN.get_global_preset(DICTIONARY, nil, section) || {}
      @descriptor = self.class.descriptor_def(@preset[OPTION_HARDWARE])
    end

    # The values the descriptor gives, by option : lengths with their unit.
    def hardware_values
      @hardware_values ||= begin
                             values = {}
                             (@descriptor.nil? ? {} : @descriptor.options).each do |name, value|
                               next unless OPTIONS.include?(name) && (value.is_a?(String) || value.is_a?(Numeric))
                               value = _normalize(name, value)
                               values[name] = value unless value.empty?
                             end
                             values
                           end
    end

    # The user's overrides of the picked hardware, by option - only the
    # options it defines.
    def overrides
      return {} if @descriptor.nil? || (id = @descriptor.id).nil?
      all = @preset[OPTION_HARDWARE_OPTIONS]
      own = all.is_a?(Hash) ? all[id] : nil
      return {} unless own.is_a?(Hash)
      own.select { |name, value| hardware_values.key?(name) && !value.nil? }
    end

    def source(option)
      option = option.to_s
      return SOURCE_OVERRIDE if overrides.key?(option)
      return SOURCE_HARDWARE if hardware_values.key?(option)
      SOURCE_BASE
    end

    def base_value(option)
      @preset[option.to_s]
    end

    def value(option)
      option = option.to_s
      case source(option)
      when SOURCE_OVERRIDE
        overrides[option]
      when SOURCE_HARDWARE
        hardware_values[option]
      else
        base_value(option)
      end
    end

    # The preset with the given values - by option - stored at their level,
    # nil when nothing changed. A value the descriptor defines is an
    # override, dropped when it equals the descriptor's.
    def store(values)
      preset = @preset.dup
      all = preset[OPTION_HARDWARE_OPTIONS].is_a?(Hash) ? Marshal.load(Marshal.dump(preset[OPTION_HARDWARE_OPTIONS])) : {}
      id = @descriptor.nil? ? nil : @descriptor.id
      values.each do |option, value|
        option = option.to_s
        if !id.nil? && hardware_values.key?(option)
          own = all[id].is_a?(Hash) ? all[id] : {}
          value = value.nil? ? '' : _normalize(option, value)
          if value.empty? || value == hardware_values[option]
            own.delete(option)
          else
            own[option] = value
          end
          if own.empty?
            all.delete(id)
          else
            all[id] = own
          end
        else
          preset[option] = value
        end
      end
      preset[OPTION_HARDWARE_OPTIONS] = all unless all.empty? && !preset.key?(OPTION_HARDWARE_OPTIONS)
      preset == @preset ? nil : preset
    end

    # What the dialog of the action shows : the base values, and what the
    # picked hardware gives.
    def to_hash
      {
        :preset => @preset,
        :hardware => @descriptor.nil? ? nil : {
          :name => @descriptor.name,
          :values => hardware_values,
          :overrides => overrides,
        }
      }
    end

    # The given value of the given option as stored : a length bears its
    # unit - "/2" and "*0.5" factors stay as they are.
    def _normalize(option, value)
      value = value.to_s.strip
      value = DimensionUtils.d_add_units(value) if !value.empty? && LENGTH_OPTIONS.include?(option) && !value.start_with?('/', '*')
      value
    end
    private :_normalize

    # The given preset without the overrides of the descriptor of the given
    # id - nil when it has none.
    def self.forget(preset, id)
      return nil unless preset.is_a?(Hash) && preset[OPTION_HARDWARE_OPTIONS].is_a?(Hash) && preset[OPTION_HARDWARE_OPTIONS].key?(id)
      preset = preset.dup
      preset[OPTION_HARDWARE_OPTIONS] = preset[OPTION_HARDWARE_OPTIONS].reject { |key, _| key == id }
      preset
    end

  end

end

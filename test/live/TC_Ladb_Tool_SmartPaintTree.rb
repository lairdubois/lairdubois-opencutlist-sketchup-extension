# LIVE test : needs a real SketchUp with OpenCutList loaded. Any model can be
# the active one : it reuses the TC_Ladb_Tool_SmartPaintRect fixture - built
# in an aborted operation.
#
# What it checks : the tree dropup (STATE_SELECT_TREE) of
# SmartPaintPartsActionHandler, opened on G2a1 (G2 > G2a > G2a1, C2b in G2) :
#   - a parent row paints the parent itself - not its parts ;
#   - its hover previews the parts inheriting the material : the ones reached
#     by no material between the parent and them ;
#   - the part row paints the part, as a click would.
#   - each row swatch shows the level own material - "no material" without -
#     and, hovered, the material a click applies ; SmartDropupSwatch switches
#     on the :hover pseudo class (swatch_* cases, no model needed).
#
# The rows are driven through their SmartDropupBtnDef lambdas, captured from
# SmartDropup.new. The current material is stubbed.
#
# Through TestUp : add test/live as a test path, run TC_Ladb_Tool_SmartPaintTree.
#
# From the Ruby console or the Claude Bridge, without TestUp :
#   load 'test/live/TC_Ladb_Tool_SmartPaintTree.rb'
#   PaintTreeRegression.run                      # one line per case
begin
  require 'testup/testcase'
rescue LoadError
  # Console / bridge use : the runner below is all there is
end

load File.join(__dir__, 'TC_Ladb_Tool_SmartPaintRect.rb') unless defined?(PaintRectRegression)

module PaintTreeRegression

  OCL = Ladb::OpenCutList

  class << self
    attr_accessor :btn_defs
  end

  # Captures the rows of the last built dropup
  module DropupCapture
    def initialize(tool, btn_defs, *args, **kwargs)
      PaintTreeRegression.btn_defs = btn_defs
      super
    end
  end
  OCL::SmartDropup.prepend(DropupCapture) unless OCL::SmartDropup.ancestors.include?(DropupCapture)

  PATH = %w[G2 G2a G2a1]

  # Each case : the row clicked (its depth in PATH), the instances given an
  # other material first, expecting the hover preview (part names) and the
  # instances painted with the test material.
  CASES = {
    'parent_g2' => { row: 0, preview: %w[C2b G2a1], painted: %w[G2] },
    'parent_g2a' => { row: 1, preview: %w[G2a1], painted: %w[G2a] },
    'part_itself' => { row: 2, preview: %w[G2a1], painted: %w[G2a1] },
    'parent_g2_part_painted' => { row: 0, other: %w[C2b], preview: %w[G2a1], painted: %w[G2] },
    'parent_g2_container_painted' => { row: 0, other: %w[G2a], preview: %w[C2b], painted: %w[G2] },
    'parent_g2a_none_inheriting' => { row: 1, other: %w[G2a1], preview: [], painted: %w[G2a] },
    'parent_g2_all_instances' => { row: 0, all: true, preview: %w[C2b G2a1], painted: %w[G2] },
    'material_changed' => { row: 0, change: true, preview: %w[C2b G2a1], painted: %w[G2] },
    # C2b and C3a share their definition : the option changes while hovering
    'option_changed' => { path: %w[G2 C2b], row: 1, option_change: true, preview: %w[C2b C3a], painted: %w[C2b C3a] },
  }

  # The hovered state of each swatch of the open tree dropup : [ none?, rgb ]
  def self.hover_swatch_states(handler)
    handler.instance_variable_get(:@tree_dropup).swatches.map { |k_swatch|
      k_swatch.activate_pseudo_class(:hover)
      k_swatch.do_style
      state = [ k_swatch.none_material?, k_swatch.background_color.to_a.first(3) ]
      k_swatch.deactivate_pseudo_class(:hover)
      k_swatch.do_style
      state
    }
  end

  # The meshes the hover preview draws
  def self.preview_mesh_count(tool)
    k_layer = tool.instance_variable_get(:@layers_3d)[OCL::SmartPaintActionHandler::LAYER_3D_ACTION_PREVIEW]
    k_layer.nil? ? 0 : k_layer.instance_variable_get(:@children).size
  end

  def self.with_tool(model, current, messages, shown, all = [ false ])
    tool = OCL::SmartPaintTool.new(current_action: OCL::SmartPaintTool::ACTION_PAINT_PARTS)
    [ :notify_success, :notify_warnings, :notify_errors, :notify, :set_root_tooltip, :show_message ].each do |name|
      tool.define_singleton_method(name) do |*args|
        shown << args.first if name == :show_message
        next if [ :notify_success, :set_root_tooltip, :show_message ].include?(name)
        messages << [ name.to_s, args.first ].inspect
      end
    end
    tool.define_singleton_method(:get_current_material) { current[0] }
    # The instances option given : the stored one must not change the result
    tool.define_singleton_method(:fetch_action_option_boolean) do |action, option_group, option|
      next all[0] if option_group == OCL::SmartPaintTool::ACTION_OPTION_INSTANCES && option == OCL::SmartPaintTool::ACTION_OPTION_INSTANCES_ALL
      super(action, option_group, option)
    end
    model.select_tool(tool)
    begin
      yield tool
    ensure
      model.select_tool(nil)
    end
  end

  def self.run_case(model, instances, spec, material, other, messages)
    names = %w[G2 G2a G2a1 C2b C3a]
    names.each { |name| instances[name].material = nil }
    (spec[:other] || []).each { |name| instances[name].material = other }
    model.selection.clear

    previewed = nil
    shown = []
    current = [ material ]
    all = [ !!spec[:all] ]
    with_tool(model, current, messages, shown, all) do |tool|
      handler = tool.instance_variable_get(:@action_handler)
      path = (spec[:path] || PATH).map { |name| instances[name] }
      part = handler.send(:_generate_part_from_path, path)
      handler.send(:_set_active_part, path, part)

      self.btn_defs = nil
      handler.set_state(OCL::SmartSelectActionHandler::STATE_SELECT_TREE)
      btn_defs = self.btn_defs
      if btn_defs.nil? || btn_defs.size != path.size
        messages << "rows #{btn_defs.nil? ? nil : btn_defs.size}"
        next
      end
      btn_def = btn_defs[spec[:row]]

      # Each row swatch : the level own material, "no material" without one
      expected_swatches = path.map { |entity| entity.material.nil? ? OCL::SmartDropup::SWATCH_NONE_MATERIAL : entity.material.color.to_a.first(3) }
      swatches = btn_defs.map { |row_def| row_def.swatch_color.is_a?(Sketchup::Color) ? row_def.swatch_color.to_a.first(3) : row_def.swatch_color }
      messages << "swatches #{swatches.inspect}" unless swatches == expected_swatches
      # Hovered : the material a click applies
      hover_swatches = btn_defs.map { |row_def| row_def.swatch_hover_color.is_a?(Sketchup::Color) ? row_def.swatch_hover_color.to_a.first(3) : row_def.swatch_hover_color }
      messages << "hover swatches #{hover_swatches.inspect}" unless hover_swatches.uniq == [ material.color.to_a.first(3) ]

      btn_def.on_enter.call(nil)
      if spec[:change]
        # The material changes while hovering : swatches and preview follow
        current[0] = nil
        handler.onToolCurrentMaterialChanged(tool)
        states = hover_swatch_states(handler)
        messages << "none hover swatches #{states.inspect}" unless states.all? { |none, _rgb| none }
        messages << 'preview lost' if handler.instance_variable_get(:@tree_preview_part_paths).nil?
        current[0] = material
        handler.onToolCurrentMaterialChanged(tool)
        states = hover_swatch_states(handler)
        messages << "material hover swatches #{states.inspect}" unless states.uniq == [ [ false, material.color.to_a.first(3) ] ]
      end
      if spec[:option_change]
        # The instances option changes while hovering : the preview follows
        count = preview_mesh_count(tool)
        all[0] = true
        handler.onToolActionOptionStored(tool, OCL::SmartPaintTool::ACTION_PAINT_PARTS, OCL::SmartPaintTool::ACTION_OPTION_INSTANCES, OCL::SmartPaintTool::ACTION_OPTION_INSTANCES_ALL)
        messages << "preview meshes #{count} -> #{preview_mesh_count(tool)}" unless count == 1 && preview_mesh_count(tool) == 2
      end
      if spec[:row] == path.size - 1
        previewed = handler.send(:_get_option_instances, path.last).map(&:name).sort
      else
        previewed = handler.instance_variable_get(:@tree_preview_part_paths).map { |p| p.last.name }.sort
        messages << 'parent not outlined' unless model.selection.to_a == [ path[spec[:row]] ]
      end
      messages << "message #{!spec[:message]}" unless shown.empty? == !spec[:message]
      btn_def.on_leave.call(nil)
      messages << 'preview kept' unless handler.instance_variable_get(:@tree_preview_part_paths).nil? && model.selection.empty?

      btn_def.on_click.call(nil)
      messages << 'not restarted' if tool.instance_variable_get(:@action_handler).equal?(handler)
    end
    messages << "previewed #{previewed.inspect}" unless previewed == spec[:preview].sort
    names.select { |name| instances[name].material == material }.sort
  end

  # SmartDropupSwatch : [ color, hover color ] -> expected [ none?, background ] out of and in hover
  SWATCH_CASES = {
    'swatch_none_to_color' => [ OCL::SmartDropup::SWATCH_NONE_MATERIAL, Sketchup::Color.new(200, 0, 0) ],
    'swatch_color_to_none' => [ Sketchup::Color.new(0, 0, 200), OCL::SmartDropup::SWATCH_NONE_MATERIAL ],
    'swatch_no_hover_color' => [ OCL::SmartDropup::SWATCH_NONE_MATERIAL, nil ],
  }

  def self.swatch_state(color)
    color == OCL::SmartDropup::SWATCH_NONE_MATERIAL ? [ true, OCL::Kuix::COLOR_WHITE.to_a ] : [ false, color.to_a ]
  end

  def self.swatch_results
    SWATCH_CASES.map { |name, (color, hover_color)|
      k_swatch = OCL::SmartDropupSwatch.new(color, hover_color)
      k_swatch.do_style
      out = [ k_swatch.none_material?, k_swatch.background_color.to_a ]
      k_swatch.activate_pseudo_class(:hover)
      k_swatch.do_style
      hover = [ k_swatch.none_material?, k_swatch.background_color.to_a ]
      expected = [ swatch_state(color), swatch_state(hover_color.nil? ? color : hover_color) ]
      [ name, { 'expected' => expected.inspect, 'painted' => [ out, hover ].inspect, 'messages' => [] } ]
    }.to_h
  end

  def self.results(names = CASES.keys)
    model = Sketchup.active_model
    model.select_tool(nil)
    model.active_path = nil unless model.active_path.nil?

    results = {}
    model.start_operation('Paint tree fixture', true)
    neutralized = [ :start_operation, :commit_operation, :abort_operation ]
    begin
      neutralized.each { |name| model.define_singleton_method(name) { |*_args| true } }
      instances = PaintRectRegression.build(model)
      material = model.materials.add('OCL Paint Tree')
      other = model.materials.add('OCL Paint Tree Other')
      names.each do |name|
        spec = CASES[name]
        messages = []
        painted = run_case(model, instances, spec, material, other, messages)
        results[name] = { 'expected' => spec[:painted].sort, 'painted' => painted, 'messages' => messages }
      end
    ensure
      model.select_tool(nil)
      neutralized.each { |name| model.singleton_class.send(:remove_method, name) }
      model.abort_operation
    end
    results.merge(swatch_results)
  end

  def self.failure(result)
    return "painted #{result['painted'].inspect} expected #{result['expected'].inspect}" unless result['painted'] == result['expected']
    return "messages #{result['messages'].inspect}" unless result['messages'].empty?
    nil
  end

  def self.run(names = CASES.keys)
    results(names).map { |name, result|
      failure = failure(result)
      "#{name} #{failure.nil? ? 'PASS' : "FAIL(#{failure})"} — #{result['painted'].inspect}"
    }.join("\n")
  end

end

if defined?(TestUp::TestCase)

  class TC_Ladb_Tool_SmartPaintTree < TestUp::TestCase

    def test_tree_paints_parent
      PaintTreeRegression.results.each do |name, result|
        failure = PaintTreeRegression.failure(result)
        assert(failure.nil?, "#{name} : #{failure}\n#{result.inspect}")
      end
    end

  end

end

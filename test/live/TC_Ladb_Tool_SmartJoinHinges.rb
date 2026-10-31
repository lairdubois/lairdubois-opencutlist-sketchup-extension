# LIVE test : needs a real SketchUp with OpenCutList loaded. Any model can be
# the active one : the fixtures - a caisson with an overlay door, see
# HingeFixture - are built in it and the model operation they are built in is
# aborted afterwards : the model is left as it was.
#
# What it checks : SmartJoinAddHingesActionHandler lays the hinges on the
# door and their plates on the side, and SmartJoinRemoveHingesActionHandler
# removes them all, whatever the hinge is made of :
#  - full        : hardware and machining given as primitives, a pivot ;
#  - bare        : the same without a pivot - laid and removed, but no door
#                  that turns ; laid after "full", whose cup is the same :
#                  its kinematics must not leak into this one ;
#  - machining   : a machining only - it bears the hinge ;
#  - articles    : hardware made of articles - the cup, its pins - in a
#                  group bearing the hinge ;
#  - mixed       : a machining only, its cup a SKP file beside its screw
#                  holes given as primitives - both laid, the SKP alone
#                  bears the hinge ;
#  - clip_top    : the bundled Blum Clip Top, SKP files ;
#  - shelf       : "full" on a caisson with a fixed shelf flush with the
#                  front right behind the centre of the door - and the
#                  cursor : the back of the door is still found facing the
#                  cavities, the hinges still laid one per compartment ;
#  - shelves     : "full" behind three evenly spaced shelves flush with the
#                  front, blocking the centre of the door and every point
#                  halfway towards its corners : the back of the door is
#                  still found, read off the section of the cavities ;
#  - materials   : "machining" whose cup drilling gives its own material :
#                  in each laid machining, the cup's group is painted with
#                  it - created as a machining material - its screw holes'
#                  left unpainted, the instance bearing the tool's ;
#  - tool_material : "machining" laid again - after it, its definitions in
#                  the model - with another machining material of the tool :
#                  a definition of its own, its instance painted with it ;
#  - own_materials : every drilling gives its own material - the cup one,
#                  its screw holes and the plate's another : the instances
#                  bear the one most of their drillings give, the tool's
#                  machining material is never created ;
#  - notched     : "full" on a narrow caisson whose left side, top and
#                  bottom are set back while its right side is flush : the
#                  compartment's mouth, a slanted hull bridge, still counts
#                  as facing the door - the joint line is not lost.
# Every case lays then removes on a caisson of its own, in the same model :
# the definitions of one are there for the next.
#
# Through TestUp : add test/live as a test path, run TC_Ladb_Tool_SmartJoinHinges.
#
# From the Ruby console or the Claude Bridge, without TestUp :
#   load 'test/live/TC_Ladb_Tool_SmartJoinHinges.rb'
#   HingesRegression.run                     # one line per case
require_relative 'hinge_fixture'
begin
  require 'testup/testcase'
rescue LoadError
  # Console / bridge use : the runner below is all there is
end

module HingesRegression

  OCL = Ladb::OpenCutList

  # The descriptor of each case - a Hash written to a temporary folder, or a
  # library ref - in the order they are run.
  CASES = {
    'full' => HingeFixture.descriptor('full'),
    'bare' => HingeFixture.descriptor('bare', pivot: false),
    'machining' => HingeFixture.descriptor('machining', hardware: false),
    'articles' => HingeFixture.descriptor('articles', articles: true),
    'mixed' => HingeFixture.descriptor('mixed', hardware: false, machining_skp: "./#{HingeFixture::MACHINING_SKP}"),
    'clip_top' => '$OCL/hinges/blum/clip-top.json',
    'shelf' => HingeFixture.descriptor('shelf'),
    'shelves' => HingeFixture.descriptor('shelves'),
    'notched' => HingeFixture.descriptor('notched'),
    'materials' => HingeFixture.descriptor('materials', hardware: false, cup_material: 'Hinge fixture CNC'),
    'tool_material' => HingeFixture.descriptor('tool_material', hardware: false),
    'own_materials' => HingeFixture.descriptor('own_materials', hardware: false, cup_material: 'Hinge fixture CNC', screws_material: 'Hinge fixture screws', plate_material: 'Hinge fixture screws'),
  }

  # The options of HingeFixture.build of each case, none by default.
  FIXTURE_OPTIONS = {
    'shelf' => { shelf: true },
    'shelves' => { shelves: true },
    'notched' => { notched: true },
  }

  # What each case gives, once laid then once removed : the hinges on the
  # door (DoorDef.hinge_instances), whether it turns (DoorDef.from), the
  # entities laid in the door and in each side.
  EXPECTED = {
    'full' => { 'laid' => { 'hinges' => 2, 'door' => true, 'door_entities' => 4, 'side_l' => 2, 'side_r' => 0 } },
    'bare' => { 'laid' => { 'hinges' => 2, 'door' => false, 'door_entities' => 4, 'side_l' => 2, 'side_r' => 0 } },
    'machining' => { 'laid' => { 'hinges' => 2, 'door' => true, 'door_entities' => 2, 'side_l' => 2, 'side_r' => 0 } },
    'articles' => { 'laid' => { 'hinges' => 2, 'door' => true, 'door_entities' => 4, 'side_l' => 2, 'side_r' => 0 } },
    'mixed' => { 'laid' => { 'hinges' => 2, 'door' => true, 'door_entities' => 4, 'side_l' => 2, 'side_r' => 0 } },
    'clip_top' => { 'laid' => { 'hinges' => 2, 'door' => true, 'door_entities' => 4, 'side_l' => 4, 'side_r' => 0 } },
    'shelf' => { 'laid' => { 'hinges' => 2, 'door' => true, 'door_entities' => 4, 'side_l' => 2, 'side_r' => 0 } },
    'shelves' => { 'laid' => { 'hinges' => 2, 'door' => true, 'door_entities' => 4, 'side_l' => 2, 'side_r' => 0 } },
    'notched' => { 'laid' => { 'hinges' => 2, 'door' => true, 'door_entities' => 4, 'side_l' => 2, 'side_r' => 0 } },
    'materials' => { 'laid' => { 'hinges' => 2, 'door' => true, 'door_entities' => 2, 'side_l' => 2, 'side_r' => 0 },
                     'door_materials' => [ [ :tool, 'Hinge fixture CNC', nil, nil ] ] },
    'tool_material' => { 'laid' => { 'hinges' => 2, 'door' => true, 'door_entities' => 2, 'side_l' => 2, 'side_r' => 0 },
                         'door_materials' => [ [ 'Hinge fixture tool', nil, nil, nil ] ] },
    'own_materials' => { 'laid' => { 'hinges' => 2, 'door' => true, 'door_entities' => 2, 'side_l' => 2, 'side_r' => 0 },
                         'door_materials' => [ [ 'Hinge fixture screws', 'Hinge fixture CNC', 'Hinge fixture screws', 'Hinge fixture screws' ] ],
                         'side_materials' => [ [ 'Hinge fixture screws', 'Hinge fixture screws', 'Hinge fixture screws' ] ],
                         'created' => [] },
  }

  # The material of the cases that give one - see 'materials' - and the
  # machining material of the tool of 'tool_material'.
  CUP_MATERIAL = 'Hinge fixture CNC'
  SCREWS_MATERIAL = 'Hinge fixture screws'
  TOOL_MATERIAL = 'Hinge fixture tool'
  GHOST_MATERIAL = 'Hinge fixture ghost'   # The tool's of 'own_materials' : none of its drillings shows it
  NAMED_MATERIALS = [ CUP_MATERIAL, SCREWS_MATERIAL, TOOL_MATERIAL, GHOST_MATERIAL ]

  # The tool options of each case, none by default - see HingeFixture.with_handler.
  TOOL_OPTIONS = {
    'tool_material' => { 'machining_material_name' => TOOL_MATERIAL },
    'own_materials' => { 'machining_material_name' => GHOST_MATERIAL },
  }
  REMOVED = { 'hinges' => 0, 'door' => false, 'door_entities' => 0, 'side_l' => 0, 'side_r' => 0 }

  def self.state(fixture)
    fn_laid = lambda { |instance| instance.definition.entities.count { |e| e.is_a?(Sketchup::ComponentInstance) || e.is_a?(Sketchup::Group) } }
    {
      'hinges' => OCL::DoorDef.hinge_instances(fixture['DOOR']).length,
      'door' => !OCL::DoorDef.from(fixture['DOOR']).nil?,
      'door_entities' => fn_laid.call(fixture['DOOR']),
      'side_l' => fn_laid.call(fixture['SIDE_L']),
      'side_r' => fn_laid.call(fixture['SIDE_R']),
    }
  end

  # The materials of each machining laid in the given part : the one of its
  # instance, then the ones of the groups of its operations, the widest -
  # the cup - first, once per distinct list. Each : :tool for a machining
  # material of the tool's - not one of NAMED_MATERIALS - nil for none, the
  # name of any other.
  def self.part_materials(instance)
    instance.definition.entities.grep(Sketchup::ComponentInstance).map { |machining|
      groups = machining.definition.entities.grep(Sketchup::Group)
      groups = groups.sort_by { |group| -group.bounds.width }   # The cup first : the widest
      ([ machining ] + groups).map { |entity|
        material = entity.material
        if material.nil?
          nil
        elsif !NAMED_MATERIALS.include?(material.name) && OCL::MaterialAttributes.new(material).type == OCL::MaterialAttributes::TYPE_MACHINING
          :tool
        elsif NAMED_MATERIALS.include?(material.name) && OCL::MaterialAttributes.new(material).type != OCL::MaterialAttributes::TYPE_MACHINING
          "#{material.name} (not a machining material)"
        else
          material.name
        end
      }
    }.uniq
  end

  def self.door_materials(fixture)
    part_materials(fixture['DOOR'])
  end

  def self.run_case(model, descriptor_ref, fixture_options = {}, tool_options = {})
    messages = []
    materials_before = model.materials.map(&:name)
    fixture = HingeFixture.build(model, **fixture_options)
    HingeFixture.with_handler(model, OCL::SmartJoinTool::ACTION_ADD_HINGES, messages, descriptor_ref, tool_options) do |handler, tool|
      HingeFixture.hover_and_click(model, handler, tool, fixture)
    end
    laid = state(fixture)
    door_materials = door_materials(fixture)
    side_materials = part_materials(fixture['SIDE_L'])
    created = model.materials.map(&:name) - materials_before
    HingeFixture.with_handler(model, OCL::SmartJoinTool::ACTION_REMOVE_HINGES, messages) do |handler, tool|
      HingeFixture.hover_and_click(model, handler, tool, fixture)
    end
    { 'laid' => laid, 'door_materials' => door_materials, 'side_materials' => side_materials, 'created' => created - [ CUP_MATERIAL, SCREWS_MATERIAL ], 'removed' => state(fixture), 'messages' => messages }
  ensure
    HingeFixture.erase(fixture) unless fixture.nil?
  end

  # The results by case - computed, then undone.
  def self.results
    model = Sketchup.active_model
    results = {}
    HingeFixture.aborted(model) do |dir|
      HingeFixture.write_machining_skp(model, dir)
      CASES.each do |id, descriptor|
        ref = descriptor.is_a?(Hash) ? HingeFixture.write_descriptor(dir, descriptor) : descriptor
        begin
          results[id] = run_case(model, ref, FIXTURE_OPTIONS.fetch(id, {}), TOOL_OPTIONS.fetch(id, {}))
        rescue Exception => e
          results[id] = { 'error' => "#{e.class}: #{e.message} @ #{e.backtrace.first(2).join(' < ')}" }
        end
      end
    end
    results
  end

  # Why the given result of the given case is wrong, nil when it is right.
  def self.failure(id, result)
    return result['error'] if result.key?('error')
    return "laid #{result['laid'].inspect}" unless result['laid'] == EXPECTED[id]['laid']
    %w[door_materials side_materials created].each do |key|
      return "#{key} #{result[key].inspect}" if EXPECTED[id].key?(key) && result[key] != EXPECTED[id][key]
    end
    return "removed #{result['removed'].inspect}" unless result['removed'] == REMOVED
    return "messages #{result['messages'].inspect}" unless result['messages'].empty?
    nil
  end

  def self.run
    results.map { |id, result|
      failure = failure(id, result)
      "#{id} #{failure.nil? ? 'PASS' : "FAIL(#{failure})"} — laid #{result['laid'].inspect}"
    }.join("\n")
  end

end

if defined?(TestUp::TestCase)

  class TC_Ladb_Tool_SmartJoinHinges < TestUp::TestCase

    def test_lay_and_remove_hinges
      results = HingesRegression.results
      HingesRegression::CASES.each_key do |id|
        failure = HingesRegression.failure(id, results[id])
        assert(failure.nil?, "#{id} : #{failure}\n#{results[id].inspect}")
      end
    end

  end

end

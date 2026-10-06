# LIVE test : needs a real SketchUp with OpenCutList loaded. Any model can be
# the active one : the fixtures - a caisson with an overlay door, see
# HingeFixture - are built in it and the model operation they are built in is
# aborted afterwards : the model is left as it was.
#
# What it checks : the opening SmartJoin previews while hinges are hovered
# (SmartJoinAddFittingsActionHandler#_preview_door_opening) turns around the
# axis the door gets once they are laid, whatever the hinge's hardware is
# made of - a single part, or articles whose group bears the hinge.
#
# The hinge is HingeFixture's : a cup given as primitives - no SKP file - its
# pivot [ 17mm, -29mm ].
#
# Through TestUp : add test/live as a test path, run TC_Ladb_Tool_SmartJoinHingePreview.
#
# From the Ruby console or the Claude Bridge, without TestUp :
#   load 'test/live/TC_Ladb_Tool_SmartJoinHingePreview.rb'
#   HingePreviewRegression.run                     # one line per case
require_relative 'hinge_fixture'
begin
  require 'testup/testcase'
rescue LoadError
  # Console / bridge use : the runner below is all there is
end

module HingePreviewRegression

  OCL = Ladb::OpenCutList

  # Each case : whether the hardware of its hinge is made of articles.
  CASES = {
    'single' => false,
    'articles' => true,
  }

  # How far two axes may lie apart and still be the same line.
  TOLERANCE = 0.01   # mm

  # Records the axis each preview of the door opening turns around.
  module Probe
    def _preview_door_swing(transformation, axis_line, *args)
      (@probe_axis_lines ||= []) << axis_line
      super
    end
  end

  # The axis the preview turns around and the one the door gets once the
  # hinges are laid - [ pivot (mm), axis ] of the hinge nearest the bottom,
  # in the door definition's coordinates - and the tool's messages.
  def self.run_case(model, descriptor_path)
    messages = []
    fixture = HingeFixture.build(model)
    previewed = nil
    HingeFixture.with_handler(model, OCL::SmartJoinTool::ACTION_ADD_HINGES, messages, descriptor_path) do |handler, tool|
      handler.singleton_class.send(:prepend, Probe)
      handler.onPickerChanged(HingeFixture.picker(fixture), model.active_view)
      previewed = (handler.instance_variable_get(:@probe_axis_lines) || []).min_by { |point, _| point.z }
      handler.onToolLButtonUp(tool, 0, 0, 0, model.active_view)
    end

    door_def = OCL::DoorDef.from(fixture['DOOR'])
    laid = door_def.nil? ? nil : door_def.hinge_defs.min_by { |hinge_def| hinge_def.pivot.z }.axis_line

    fn_axis = lambda { |axis_line| axis_line.nil? ? nil : [ axis_line[0].to_a.map { |v| v.to_mm.round(3) }, axis_line[1].normalize.to_a.map { |v| v.round(6) } ] }
    { 'previewed' => fn_axis.call(previewed), 'laid' => fn_axis.call(laid), 'messages' => messages }
  ensure
    HingeFixture.erase(fixture) unless fixture.nil?
  end

  # The results by case - computed, then undone.
  def self.results
    model = Sketchup.active_model
    results = {}
    HingeFixture.aborted(model) do |dir|
      CASES.each do |name, articles|
        path = HingeFixture.write_descriptor(dir, HingeFixture.descriptor("preview-#{name}", articles: articles))
        results[name] = run_case(model, path)
      end
    end
    results
  end

  # Why the given result is wrong - the pivot previewed where the laid door
  # turns - nil when it is right.
  def self.failure(result)
    previewed, laid = result['previewed'], result['laid']
    return 'no preview' if previewed.nil?
    return 'no door once laid' if laid.nil?
    return "previewed #{previewed.inspect} laid #{laid.inspect}" unless same_axis?(previewed, laid)
    nil
  end

  # Are the given axes - [ point (mm), direction ] - the same line, the same
  # way ?
  def self.same_axis?(a, b)
    direction = Geom::Vector3d.new(b[1])
    return false unless Geom::Vector3d.new(a[1]).samedirection?(direction)
    Geom::Point3d.new(a[0]).distance_to_line([ Geom::Point3d.new(b[0]), direction ]).to_f <= TOLERANCE
  end

  def self.run
    results().map { |name, result|
      failure = failure(result)
      line = "#{name} #{failure.nil? ? 'PASS' : "FAIL(#{failure})"} — previewed #{result['previewed'].inspect}"
      line += "\n    messages: #{result['messages'].inspect}" unless result['messages'].empty?
      line
    }.join("\n")
  end

end

if defined?(TestUp::TestCase)

  class TC_Ladb_Tool_SmartJoinHingePreview < TestUp::TestCase

    def test_opening_preview_turns_around_the_laid_axis
      HingePreviewRegression.results.each do |name, result|
        failure = HingePreviewRegression.failure(result)
        assert(failure.nil?, "#{name} : #{failure}\n#{result.inspect}")
      end
    end

  end

end

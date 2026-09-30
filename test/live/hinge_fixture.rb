# What the live tests of the SmartJoin hinges share : a caisson with an
# overlay door built in the active model, hinge descriptors written to a
# temporary folder, and the real action handlers driven without the mouse -
# inside a model operation that is aborted afterwards. See
# TC_Ladb_Tool_SmartJoinHinges and TC_Ladb_Tool_SmartJoinHingePreview.
require 'json'
require 'tmpdir'

module HingeFixture

  OCL = Ladb::OpenCutList

  # The fixture : far below whatever the model holds.
  ORIGIN_OFFSET = [ 0, 0, -20000 ]   # mm

  # The parts of the caisson, as boxes [ x0, y0, z0, x1, y1, z1 ] in mm : the
  # door lies over the sides, its back on their front edges.
  PARTS = {
    'SIDE_L' => [ 0, 0, 0, 18, 560, 720 ],
    'SIDE_R' => [ 582, 0, 0, 600, 560, 720 ],
    'BOTTOM' => [ 18, 0, 0, 582, 560, 18 ],
    'TOP' => [ 18, 0, 702, 582, 560, 720 ],
    'BACK' => [ 18, 542, 18, 582, 560, 702 ],
    'DOOR' => [ 2, -19, 2, 598, 0, 718 ],
  }

  # Where the door is hovered : near its left edge, on its front face.
  PICK_POINT = [ 40, -19, 360 ]   # mm, caisson local

  PIVOT = [ '17mm', '-29mm' ]   # y and z in the fitting frame

  # What the handler reads off a SmartPicker, nil for the rest.
  class Picker
    attr_accessor :picked_face_path, :picked_point
    def method_missing(*)
      nil
    end
    def respond_to_missing?(*)
      true
    end
  end

  # A 35 mm cup hinge given as primitives - no SKP file - and a plate drilled
  # in the side. hardware : false for a hinge made of its machining only ;
  # pivot : false for one without its pivot - it can't turn ; z_offset : of
  # its hardware.
  def self.descriptor(id, hardware: true, pivot: true, z_offset: nil)
    cup = lambda do |y, screws_y|
      item = {
        'machining' => { 'drillings' => [
          { 'y' => y, 'diameter' => '35mm', 'depth' => '13mm' },
          { 'x' => '-22.5mm', 'y' => screws_y, 'diameter' => '8mm', 'depth' => '13mm' },
          { 'x' => '22.5mm', 'y' => screws_y, 'diameter' => '8mm', 'depth' => '13mm' },
        ] },
      }
      item['hardware'] = { 'cylinders' => [ { 'y' => y, 'diameter' => '35mm', 'from' => '-11.5mm', 'to' => '0mm' } ] } if hardware
      item
    end
    attributes = { 'hinge_max_angle' => 110 }
    attributes['hinge_pivot'] = PIVOT if pivot
    a = {
      'attributes' => attributes,
      'variants' => {
        'select' => { 'by' => 'hinge_kind' },
        'fallback' => 'overlay',
        'items' => { 'overlay' => cup.call('-6.5mm', '-16mm'), 'half_overlay' => cup.call('-16mm', '-25.5mm'), 'inset' => cup.call('-24.5mm', '-34mm') },
      },
    }
    a['z_offset'] = z_offset unless z_offset.nil?
    {
      'format' => 'ocl-hardware', 'version' => 1,
      'id' => "hinge-fixture-#{id}", 'type' => 'hinge',
      'name' => "Hinge fixture #{id}",
      'components' => {
        'a' => a,
        'b' => { 'machining' => { 'drillings' => [ { 'x' => '-16mm', 'y' => '37mm', 'diameter' => '5mm', 'depth' => '12mm' }, { 'x' => '16mm', 'y' => '37mm', 'diameter' => '5mm', 'depth' => '12mm' } ] } },
      },
      'options' => { 'start_offset' => '100mm', 'end_offset' => '100mm', 'max_spacing' => '800mm' },
    }
  end

  # Writes the given descriptor in the given folder : its path.
  def self.write_descriptor(dir, data)
    path = File.join(dir, "#{data['id']}.json")
    File.write(path, JSON.generate(data))
    path
  end

  # The caisson, as { 'caisson' => instance, 'DOOR' => instance, 'SIDE_L' => … }.
  # One at a time : the handlers probe the model, they would find the parts
  # of another one standing at the same place - see erase.
  def self.build(model)
    caisson = model.definitions.add('HINGE_FIXTURE')
    instances = {}
    PARTS.each do |name, (x0, y0, z0, x1, y1, z1)|
      definition = model.definitions.add("HINGE_FIXTURE_#{name}")
      face = definition.entities.add_face([ x0.mm, y0.mm, z0.mm ], [ x1.mm, y0.mm, z0.mm ], [ x1.mm, y1.mm, z0.mm ], [ x0.mm, y1.mm, z0.mm ])
      face.reverse! if face.normal.z < 0
      face.pushpull((z1 - z0).mm)
      OCL::DefinitionAttributes.write_role(definition, OCL::DefinitionAttributes::ROLE_FRONT_PANEL) if name == 'DOOR'
      instances[name] = caisson.entities.add_instance(definition, IDENTITY)
    end
    instances['caisson'] = model.entities.add_instance(caisson, Geom::Transformation.translation(ORIGIN_OFFSET.map(&:mm)))
    instances
  end

  # Erases the caisson of the given fixture - its definitions stay, and what
  # was laid in them.
  def self.erase(fixture)
    fixture['caisson'].erase! if fixture['caisson'].valid?
  end

  # The picker hovering the door of the given fixture near its left edge.
  def self.picker(fixture)
    door = fixture['DOOR']
    picker = Picker.new
    picker.picked_face_path = [ fixture['caisson'], door, door.definition.entities.grep(Sketchup::Face).find { |face| face.normal.y < -0.9 } ]
    picker.picked_point = Geom::Point3d.new(PICK_POINT.map(&:mm)).transform(fixture['caisson'].transformation)
    picker
  end

  # Yields the handler of the given SmartJoin action, its tool selected -
  # laying the given descriptor ref when given - the tool's messages
  # appended to the given array.
  def self.with_handler(model, action, messages, descriptor_ref = nil)
    tool = OCL::SmartJoinTool.new(current_action: action)
    [ :notify_success, :notify_warnings, :notify_errors, :notify, :show_tooltip, :show_message ].each do |name|
      tool.define_singleton_method(name) do |*args|
        next if [ :notify_success, :show_tooltip ].include?(name)
        next if name == :show_message && args[1] != OCL::SmartTool::MESSAGE_TYPE_ERROR   # "2 hinges to remove"
        messages << [ name.to_s, args.first ].inspect
      end
    end
    model.select_tool(tool)
    begin
      handler = tool.instance_variable_get(:@action_handler)
      unless descriptor_ref.nil?
        handler.define_singleton_method(:_fetch_option_hardware) { descriptor_ref }
        handler.set_state(handler.get_startup_state)   # Out of the "pick a hardware" state
      end
      yield handler, tool
    ensure
      model.select_tool(nil)
    end
  end

  # Hovers the door of the given fixture, then clicks.
  def self.hover_and_click(model, handler, tool, fixture)
    handler.onPickerChanged(picker(fixture), model.active_view)
    handler.onToolLButtonUp(tool, 0, 0, 0, model.active_view)
  end

  # Yields a temporary folder, inside a model operation aborted afterwards -
  # the handlers' own operations neutralized.
  def self.aborted(model)
    Dir.mktmpdir do |dir|
      model.start_operation('Hinge fixture', true)
      neutralized = [ :start_operation, :commit_operation, :abort_operation ]
      begin
        neutralized.each { |name| model.define_singleton_method(name) { |*_args| true } }
        yield dir
      ensure
        neutralized.each { |name| model.singleton_class.send(:remove_method, name) }
        model.abort_operation
      end
    end
  end

end

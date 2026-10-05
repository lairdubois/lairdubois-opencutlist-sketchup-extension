# What the live tests of the SmartJoin hinges share : a caisson with an
# overlay door - or a frame door, see FRAME_DOORS - built in the active
# model, hinge descriptors written to a temporary folder, and the real action
# handlers driven without the mouse - inside a model operation that is
# aborted afterwards. See TC_Ladb_Tool_SmartJoinHinges,
# TC_Ladb_Tool_SmartJoinHingePreview and TC_Ladb_Tool_SmartJoinFrameDoorHinges.
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

  # A fixed shelf flush with the front, at mid height of the door : right
  # behind its centre - and behind PICK_POINT.
  SHELF = [ 18, 0, 351, 582, 542, 369 ]

  # Three fixed shelves flush with the front, evenly spaced : right behind
  # the centre of the door AND the points halfway towards its corners - the
  # very points its back was once looked for at, all of them blocked.
  SHELVES = [
    [ 18, 0, 172, 582, 542, 190 ],
    SHELF,
    [ 18, 0, 530, 582, 542, 548 ],
  ]

  # Where the door is hovered : near its left edge, on its front face.
  PICK_POINT = [ 40, -19, 360 ]   # mm, caisson local

  # FRAME DOORS : the door made of several parts - stiles, rails and a
  # recessed panel - held by a component bearing ROLE_FRONT_PANEL. Its box
  # [ x0, y0, z0, x1, y1, z1 ] in mm, the width of its stiles and the height
  # of its rails - the top one the bottom one's by default - the rails
  # running between the stiles, or across the whole width when through. The
  # right stile shares the left one's definition, turned half a turn around
  # Y, and so does the top rail the bottom one's when they are alike - or,
  # mirror, the left stile is the right one's mirrored. pick : where it is
  # hovered, on the left stile.
  FRAME_DOORS = {
    'frame' => { box: [ 2, -19, 2, 598, 0, 718 ], stile: 60, rail_b: 60 },
    'frame_through' => { box: [ 2, -19, 2, 598, 0, 718 ], stile: 60, rail_b: 150, through: true },
    'frame_straddle' => { box: [ 2, -19, 2, 598, 0, 718 ], stile: 60, rail_b: 100, rail_t: 150, through: true },
    'frame_inset' => { box: [ 20, 0, 20, 580, 19, 700 ], stile: 60, rail_b: 60, pick: [ 50, 0, 360 ] },
    'frame_mirror' => { box: [ 2, -19, 2, 598, 0, 718 ], stile: 60, rail_b: 60, mirror: true },
  }

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
  # its hardware ; articles : its hardware made of articles - the cup and its
  # two pins, each a part of its own.
  def self.descriptor(id, hardware: true, pivot: true, z_offset: nil, articles: false)
    cup = lambda do |y, screws_y|
      item = {
        'machining' => { 'drillings' => [
          { 'y' => y, 'diameter' => '35mm', 'depth' => '13mm' },
          { 'x' => '-22.5mm', 'y' => screws_y, 'diameter' => '8mm', 'depth' => '13mm' },
          { 'x' => '22.5mm', 'y' => screws_y, 'diameter' => '8mm', 'depth' => '13mm' },
        ] },
      }
      item['hardware'] = { 'cylinders' => [ { 'y' => y, 'diameter' => '35mm', 'from' => '-11.5mm', 'to' => '0mm' } ] } if hardware
      if articles
        item['hardware'] = {
          'cup' => item['hardware'],
          'pins' => { 'cylinders' => [ { 'diameter' => '8mm', 'from' => '-11.5mm', 'to' => '0mm' } ],
                      'at' => [ { 'x' => '-22.5mm', 'y' => screws_y }, { 'x' => '22.5mm', 'y' => screws_y } ] },
        }
      end
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
  # of another one standing at the same place - see erase. shelf : with the
  # SHELF. shelves : with the SHELVES. frame : the FRAME_DOORS key of the door, its parts given too, as
  # { 'STILE_L' => instance, … } under 'parts'.
  def self.build(model, shelf: false, shelves: false, frame: nil)
    caisson = model.definitions.add('HINGE_FIXTURE')
    instances = {}
    parts = shelf ? PARTS.merge('SHELF' => SHELF) : PARTS
    parts = parts.merge(SHELVES.each_with_index.map { |box, index| [ "SHELF_#{index + 1}", box ] }.to_h) if shelves
    parts = parts.reject { |name, _| name == 'DOOR' } unless frame.nil?
    parts.each do |name, box|
      definition = box_definition(model, "HINGE_FIXTURE_#{name}", box)
      OCL::DefinitionAttributes.write_role(definition, OCL::DefinitionAttributes::ROLE_FRONT_PANEL) if name == 'DOOR'
      instances[name] = caisson.entities.add_instance(definition, IDENTITY)
    end
    unless frame.nil?
      door = model.definitions.add('HINGE_FIXTURE_DOOR')
      OCL::DefinitionAttributes.write_role(door, OCL::DefinitionAttributes::ROLE_FRONT_PANEL)
      instances['parts'] = {}
      frame_parts(FRAME_DOORS[frame]).each do |name, (box, source, mirror)|
        if source.nil?
          instances['parts'][name] = door.entities.add_instance(box_definition(model, "HINGE_FIXTURE_#{name}", box), IDENTITY)
        else
          source_box = frame_parts(FRAME_DOORS[frame])[source].first
          if mirror
            t = Geom::Transformation.translation([ (box[3] + source_box[0]).mm, 0, 0 ]) * Geom::Transformation.scaling(-1, 1, 1)
          else
            t = Geom::Transformation.translation([ (box[3] + source_box[0]).mm, 0, (box[5] + source_box[2]).mm ]) * Geom::Transformation.rotation(ORIGIN, Y_AXIS, 180.degrees)
          end
          instances['parts'][name] = door.entities.add_instance(instances['parts'][source].definition, t)
        end
      end
      instances['DOOR'] = caisson.entities.add_instance(door, IDENTITY)
    end
    instances['caisson'] = model.entities.add_instance(caisson, Geom::Transformation.translation(ORIGIN_OFFSET.map(&:mm)))
    instances
  end

  # A definition holding the given box [ x0, y0, z0, x1, y1, z1 ] in mm.
  def self.box_definition(model, name, box)
    x0, y0, z0, x1, y1, z1 = box
    definition = model.definitions.add(name)
    face = definition.entities.add_face([ x0.mm, y0.mm, z0.mm ], [ x1.mm, y0.mm, z0.mm ], [ x1.mm, y1.mm, z0.mm ], [ x0.mm, y1.mm, z0.mm ])
    face.reverse! if face.normal.z < 0
    face.pushpull((z1 - z0).mm)
    definition
  end

  # The parts of the given frame door - see FRAME_DOORS - as { name =>
  # [ box, source, mirror ] }, source the part whose definition it shares,
  # nil for one of its own, mirror whether it is that part mirrored.
  def self.frame_parts(spec)
    x0, y0, z0, x1, y1, z1 = spec[:box]
    stile = spec[:stile]
    rail_b = spec[:rail_b]
    rail_t = spec[:rail_t] || rail_b
    rail_t_source = rail_t == rail_b ? 'RAIL_B' : nil
    panel = [ y0 + 6, y1 - 6 ]
    if spec[:through]
      {
        'RAIL_B' => [ [ x0, y0, z0, x1, y1, z0 + rail_b ], nil ],
        'RAIL_T' => [ [ x0, y0, z1 - rail_t, x1, y1, z1 ], rail_t_source ],
        'STILE_L' => [ [ x0, y0, z0 + rail_b, x0 + stile, y1, z1 - rail_t ], nil ],
        'STILE_R' => [ [ x1 - stile, y0, z0 + rail_b, x1, y1, z1 - rail_t ], rail_b == rail_t ? 'STILE_L' : nil ],
        'PANEL' => [ [ x0 + stile, panel[0], z0 + rail_b, x1 - stile, panel[1], z1 - rail_t ], nil ],
      }
    elsif spec[:mirror]
      {
        'STILE_R' => [ [ x1 - stile, y0, z0, x1, y1, z1 ], nil ],
        'STILE_L' => [ [ x0, y0, z0, x0 + stile, y1, z1 ], 'STILE_R', true ],
        'RAIL_B' => [ [ x0 + stile, y0, z0, x1 - stile, y1, z0 + rail_b ], nil ],
        'RAIL_T' => [ [ x0 + stile, y0, z1 - rail_t, x1 - stile, y1, z1 ], rail_t_source ],
        'PANEL' => [ [ x0 + stile, panel[0], z0 + rail_b, x1 - stile, panel[1], z1 - rail_t ], nil ],
      }
    else
      {
        'STILE_L' => [ [ x0, y0, z0, x0 + stile, y1, z1 ], nil ],
        'STILE_R' => [ [ x1 - stile, y0, z0, x1, y1, z1 ], 'STILE_L' ],
        'RAIL_B' => [ [ x0 + stile, y0, z0, x1 - stile, y1, z0 + rail_b ], nil ],
        'RAIL_T' => [ [ x0 + stile, y0, z1 - rail_t, x1 - stile, y1, z1 ], rail_t_source ],
        'PANEL' => [ [ x0 + stile, panel[0], z0 + rail_b, x1 - stile, panel[1], z1 - rail_t ], nil ],
      }
    end
  end

  # Erases the caisson of the given fixture - its definitions stay, and what
  # was laid in them.
  def self.erase(fixture)
    fixture['caisson'].erase! if fixture['caisson'].valid?
  end

  # The picker hovering the door of the given fixture near its left edge -
  # or the given part of a frame door, at the given point (mm, caisson
  # local).
  def self.picker(fixture, part = nil, point = PICK_POINT)
    door = fixture['DOOR']
    path = [ fixture['caisson'], door ]
    path << fixture['parts'][part] unless part.nil?
    picker = Picker.new
    picker.picked_face_path = path + [ path.last.definition.entities.grep(Sketchup::Face).find { |face| face.normal.transform(path.last.transformation).y < -0.9 } ]
    picker.picked_point = Geom::Point3d.new(point.map(&:mm)).transform(fixture['caisson'].transformation)
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

  # Hovers the door of the given fixture - or the given picker - then clicks.
  def self.hover_and_click(model, handler, tool, fixture, picker = picker(fixture))
    handler.onPickerChanged(picker, model.active_view)
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

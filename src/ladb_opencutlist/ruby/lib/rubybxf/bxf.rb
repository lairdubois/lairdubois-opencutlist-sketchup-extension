module Ladb::OpenCutList

  require 'rexml/document'

  module Bxf

    class BxfModel

      attr_accessor :version,
                    :date,
                    :author,
                    :copyright,
                    :country,
                    :language,
                    :unit,
                    :angular_unit,
                    :parameters

      attr_reader   :scene,
                    :library

      def initialize

        @version = nil
        @date = nil
        @author = nil
        @copyright = nil
        @country = nil
        @language = nil

        @unit = BxfUnit.new(self)
        @angular_unit = BxfAngularUnit.new(self)
        @parameters = BxfParameters.new(self)

        @scene = BxfScene.new(self)
        @library = BxfLibrary.new(self)

      end

      def self.load(file_path)
        doc = REXML::Document.new(File.open(file_path))
        bxf_elm = doc.elements['bxf']
        return BxfModel.new.read(bxf_elm) if bxf_elm
      end

      def read(bxf_elm)

        head_elm = bxf_elm.elements['head']
        if head_elm

          version_elm = head_elm.elements['version']
          self.version = version_elm.text if version_elm

          date_elm = head_elm.elements['date']
          self.date = date_elm.text if date_elm

          author_elm = head_elm.elements['author']
          self.author = author_elm.text if author_elm

          copyright_elm = head_elm.elements['copyright']
          self.copyright = copyright_elm.text if copyright_elm

          country_elm = head_elm.elements['country']
          self.country = country_elm.text if country_elm

          language_elm = head_elm.elements['language']
          self.language = language_elm.text if language_elm

          unit_elm = head_elm.elements['unit']
          self.unit.read(unit_elm) if unit_elm

          angular_unit_elm = head_elm.elements['angularUnit']
          self.angular_unit.read(angular_unit_elm) if angular_unit_elm

          parameters_elm = head_elm.elements['parameters']
          self.parameters.read(parameters_elm) if parameters_elm

        end

        scene_elm = bxf_elm.elements['scene']
        self.scene.read(scene_elm) if scene_elm

        library_elm = bxf_elm.elements['library']
        self.library.read(library_elm) if library_elm

        self
      end

    end

    class BxfModelable

      attr_reader :model

      def initialize(model)
        @model = model
      end

      def read(data)
        self
      end

      def inspect
        self.class.inspect  # Simplify exception display
      end

    end

    # -- Base objects

    class BxfObject < BxfModelable

      attr_accessor :uid,
                    :description

      attr_reader   :parameters

      def initialize(model)
        super

        @uid = nil
        @description = nil

        @parameters = BxfParameters.new(model)

      end

      def read(data)

        self.uid = data.attributes['uid']

        description_elm = data.elements['description']
        self.description = description_elm.text if description_elm

        parameters_elm = data.elements['parameters']
        self.parameters.read(parameters_elm) if parameters_elm

        super
      end

      def inspect
        self.class.inspect  # Simplify exception display
      end

    end

    class BxfReferenceableObject < BxfObject

      attr_accessor :id

      def initialize(model)
        super

        @id = nil

      end

      def read(elm)

        self.id = elm.attributes['id']

        super
      end

    end

    # -- Base links

    class BxfObjectLink < BxfObject

      attr_accessor :reference_id

      def initialize(model)
        super(model)

        @reference_id = nil

      end

      def read(elm)

        self.reference_id = elm.attributes['referenceId']

        super
      end

    end

    class BxfReferenceableObjectLink < BxfObjectLink

      attr_accessor :id

      def initialize(model)
        super

        @id = nil

      end

      def read(elm)

        self.id = elm.attributes['id']

        super
      end

    end

    class BxfTransformableObjectLink < BxfObjectLink

      attr_reader :transformations

      def initialize(model)
        super(model)

        @transformations = BxfTransformations.new(model)

      end

      def read(elm)

        transformations_elm = elm.elements['transformations']
        self.transformations.read(transformations_elm) if transformations_elm

        super
      end

    end

    class BxfTransformableReferenceableObjectLink < BxfReferenceableObjectLink

      attr_reader :transformations

      def initialize(model)
        super(model)

        @transformations = BxfTransformations.new(model)

      end

      def read(elm)

        transformations_elm = elm.elements['transformations']
        self.transformations.read(transformations_elm) if transformations_elm

        super
      end

    end

    class BxfZoneLink < BxfTransformableObjectLink

      attr_reader :zone

      def initialize(model)
        super(model)

        @zone = BxfZone.new(model)

      end

      def read(elm)

        zone_elm = elm.elements['zone']
        self.zone.read(zone_elm) if zone_elm

        super
      end

    end

    # -- Units

    class BxfUnit < BxfModelable

      attr_accessor :meter,
                    :name

      def initialize(model)
        super

        @meter = 1.0
        @name = 'meter'

      end

      def read(unit_elm)

        meter_attr = unit_elm.attributes['meter']
        self.meter = meter_attr.to_f if meter_attr

        name_attr = unit_elm.attributes['name']
        self.name = name_attr if name_attr

        super
      end

      def convert_to_su_length(bxf_length)
        (bxf_length.value * meter).m
      end

    end

    class BxfAngularUnit < BxfModelable

      DEGREE = 'degree'.freeze
      RADIANS = 'radians'.freeze

      attr_accessor :name

      def initialize(model)
        super

        @name = DEGREE

      end

      def read(unit_elm)

        self.name = unit_elm.text

        super
      end

      def convert_to_radians(bxf_angle)
        case name
        when DEGREE
          bxf_angle.value.degrees
        when RADIANS
          bxf_angle.value
        else
          raise "Unsupported Angular Unit: #{name}"
        end
      end

    end

    # --

    class BxfLength < BxfModelable

      attr_accessor :value

      def initialize(model, default = nil)
        super(model)

        @value = 0.0

        read(default) if default.is_a?(String)

      end

      def read(str)

        self.value = str.strip.to_f

        super
      end

      def to_l
        model.unit.convert_to_su_length(self)
      end

    end

    class BxfAngle < BxfModelable

      attr_accessor :value

      def initialize(model, default = nil)
        super(model)

        @value = 0.0

        read(default) if default.is_a?(String)

      end

      def read(str)

        self.value = str.strip.to_f

        super
      end

      def to_radians
        model.angular_unit.convert_to_radians(self)
      end

    end

    class BxfPoint2d < BxfModelable

      attr_reader :x, :y

      def initialize(model, default = nil)
        super(model)

        @x = BxfLength.new(model)
        @y = BxfLength.new(model)

        read(default) if default.is_a?(String)

      end

      def read(str)

        x, y = str.strip.split(/\s+/)

        self.x.read(x) if x
        self.y.read(y) if y

        super
      end

      def to_p
        Geom::Point3d.new(self.x.to_l, self.y.to_l)
      end

    end

    class BxfPoint3d < BxfModelable

      attr_reader :x, :y, :z

      def initialize(model, default = nil)
        super(model)

        @x = BxfLength.new(model)
        @y = BxfLength.new(model)
        @z = BxfLength.new(model)

        read(default) if default.is_a?(String)

      end

      def read(str)

        x, y, z = str.strip.split(/\s+/)

        self.x.read(x) if x
        self.y.read(y) if y
        self.z.read(z) if z

        super
      end

      def to_p
        Geom::Point3d.new(self.x.to_l, self.y.to_l, self.z.to_l)
      end

    end

    class BxfVector3d < BxfModelable

      attr_reader :x, :y, :z

      def initialize(model, default = nil)
        super(model)

        @x = BxfLength.new(model)
        @y = BxfLength.new(model)
        @z = BxfLength.new(model)

        read(default) if default.is_a?(String)

      end

      def read(str)

        x, y, z = str.strip.split(/\s+/)

        self.x.read(x) if x
        self.y.read(y) if y
        self.z.read(z) if z

        super
      end

      def to_v
        Geom::Vector3d.new(self.x.to_l, self.y.to_l, self.z.to_l)
      end

    end

    class BxfExtent < BxfModelable

      attr_reader :length,
                  :width,
                  :thickness

      def initialize(model, default = nil)
        super(model)

        @length = BxfLength.new(model)
        @width = BxfLength.new(model)
        @thickness = BxfLength.new(model)

        read(default) if default.is_a?(String)

      end

      def read(elm)

        length, width, thickness = elm.text.strip.split(/\s+/)

        self.length.read(length) if length
        self.width.read(width) if width
        self.thickness.read(thickness) if thickness

        super
      end

      def to_b
        bounds = Geom::BoundingBox.new
        bounds.add(
          ORIGIN,
          Geom::Point3d.new(self.length.to_l, self.width.to_l, self.thickness.to_l)
        )
        bounds
      end

    end

    class BxfZone < BxfModelable

      attr_accessor :row,
                    :column

      def initialize(model)
        super

        @row = 0
        @column = 0

      end

      def read(zone_elm)

        self.row = zone_elm.attributes['row'].to_i
        self.column = zone_elm.attributes['column'].to_i

        super
      end

    end

    # --

    class BxfParameters < BxfModelable

      include Enumerable

      def initialize(model)
        super

        @parameters = []

      end

      def read(parameters_elm)

        parameters_elm.elements.each('parameter') do |elm|
          @parameters << BxfParameter.new(model).read(elm)
        end

        super
      end

      def each(&block)
        @parameters.each(&block)
      end

    end

    class BxfParameter < BxfModelable

      attr_accessor :name,
                    :value

      def initialize(model)
        super

        @name = nil
        @value = nil

      end

      def read(parameter_elm)

        self.name = parameter_elm.attributes['name']

        value_elm = parameter_elm.elements['value']
        type = value_elm.attributes['xsi:type']
        case type
        when 'xs:string'
          self.value = value_elm.text
        when 'xs:int'
          self.value = value_elm.text.to_i
        when 'xs:double'
          self.value = value_elm.text.to_f
        when 'xs:boolean'
          self.value = value_elm.text == 'true'
        else
          raise "Unsupported parameter value type: #{type}"
        end if value_elm

        super
      end

    end

    # --

    class BxfTransformations < BxfModelable

      include Enumerable

      def initialize(model)
        super

        @transformations = [] # Array<BxfTransformation>

      end

      def read(transformations_elm)

        transformations_elm.elements.each('transformation') do |elm|
          if elm.attributes['translation']
            @transformations << BxfTransformationTranslation.new(model).read(elm)
          elsif elm.attributes['rotation']
            @transformations << BxfTransformationRotation.new(model).read(elm)
          end
        end

        super
      end

      def each(&block)
        @transformations.each(&block)
      end

      def to_t
        @transformations
          .reverse
          .inject(Geom::Transformation.new) { |t, transformation| t * transformation.to_t }
      end

    end

    class BxfTransformation < BxfModelable

      def to_t
        IDENTITY
      end

    end

    class BxfTransformationTranslation < BxfTransformation

      attr_accessor :vector

      def initialize(model)
        super

        @vector = BxfVector3d.new(model)

      end

      def read(transformation_elm)

        translation_elm = transformation_elm.attributes['translation']
        self.vector.read(translation_elm) if translation_elm

        super
      end

      def to_t
        Geom::Transformation.translation(vector.to_v)
      end

    end

    class BxfTransformationRotation < BxfTransformation

      attr_reader :center,
                  :vector,
                  :angle

      def initialize(model)
        super

        @center = BxfPoint3d.new(model)
        @vector = BxfVector3d.new(model, '0 1 0')
        @angle = BxfAngle.new(model)

      end

      def read(transformation_elm)

        center_attr = transformation_elm.attributes['center']
        self.center.read(center_attr) if center_attr

        rotation_attr = transformation_elm.attributes['rotation']
        if rotation_attr
          self.vector.read(rotation_attr)
          self.angle.read(rotation_attr.strip.split(/\s+/).last)
        end

        super
      end

      def to_t
        Geom::Transformation.rotation(center.to_p, vector.to_v, angle.to_radians)
      end

    end

    # --

    class BxfGeometry < BxfObject

      TYPE_BOX = 'Box'
      TYPE_PRISM = 'Prism'
      TYPE_CYLINDER = 'Cylinder'

      attr_reader :type

      def initialize(model, type)
        super(model)

        @type = type

      end

      def self.create(model, elm)
        type = elm.attributes['xsi:type']
        case type
        when TYPE_BOX
          BxfGeometryBox.new(model).read(elm)
        when TYPE_PRISM
          BxfGeometryPrism.new(model).read(elm)
        when TYPE_CYLINDER
          BxfGeometryCylinder.new(model).read(elm)
        else
          raise "Unknown geometry type '#{type}'"
        end
      end

    end

    class BxfGeometryBox < BxfGeometry

      attr_reader :extent

      def initialize(model)
        super(model, TYPE_BOX)

        @extent = BxfExtent.new(model)

      end

      def read(box_elm)

        extent_elm = box_elm.elements['extent']
        self.extent.read(extent_elm) if extent_elm

        super
      end

    end

    class BxfGeometryPrism < BxfGeometry

      attr_reader :base_points,
                  :z_value

      def initialize(model)
        super(model, TYPE_PRISM)

        @base_points = [] # Array<BxfPoint2d>
        @z_value = BxfLength.new(model)

      end

      def read(prism_elm)

        prism_elm.elements.each('basePoints/point') do |elm|
          self.base_points << BxfPoint2d.new(model).read(elm.text)
        end

        z_value_elm = prism_elm.elements['zValue']
        self.z_value.read(z_value_elm.text) if z_value_elm

        super
      end

    end

    class BxfGeometryCylinder < BxfGeometry

      attr_reader :radius,
                  :z_value

      def initialize(model)
        super(model, TYPE_CYLINDER)

        @radius = BxfLength.new(model)
        @z_value = BxfLength.new(model)

      end

      def read(cylinder_elm)

        radius_elm = cylinder_elm.elements['radius']
        self.radius.read(radius_elm.text) if radius_elm

        z_value_elm = cylinder_elm.elements['zValue']
        self.z_value.read(z_value_elm.text) if z_value_elm

        super
      end

    end

    # --

    class BxfGeometricReference < BxfModelable

      def self.create(model, elm)
        type = elm.attributes['xsi:type']
        case type
        when 'PointReference'
          BxfPointReference.new(model).read(elm)
        when 'EdgeReference'
          BxfEdgeReference.new(model).read(elm)
        when 'FaceReference'
          BxfFaceReference.new(model).read(elm)
        else
          raise "Unknown geometric reference type '#{type}'"
        end
      end

    end

    class BxfPointReference < BxfGeometricReference

      attr_accessor :index,
                    :add_z_value

      def initialize(model)
        super

        @index = 0
        @add_z_value = false

      end

      def read(point_reference_elm)

        self.index = point_reference_elm.attributes['index'].to_i
        self.add_z_value = point_reference_elm.attributes['addZValue'] == 'true'

        super
      end

    end

    class BxfEdgeReference < BxfGeometricReference

      attr_reader :start,
                  :end

      def initialize(model)

        @start = BxfPointReference.new(model)
        @end = BxfPointReference.new(model)

        super
      end

      def read(edge_reference_elm)

        start_elm = edge_reference_elm.elements['start']
        self.start.read(start_elm) if start_elm

        end_elm = edge_reference_elm.elements['end']
        self.end.read(end_elm) if end_elm

        super
      end

    end

    class BxfRoundedEdge < BxfEdgeReference

      attr_reader :radius

      def initialize(model)
        super

        @radius = BxfLength.new(model)

      end

      def read(edge_reference_elm)

        radius_attr = edge_reference_elm.attributes['radius']
        self.radius.read(radius_attr) if radius_attr

        super
      end

    end

    class BxfFaceReference < BxfGeometricReference

      attr_reader :main_edge,
                  :support_edge

      def initialize(model)
        super

        @main_edge = BxfEdgeReference.new(model)
        @support_edge = BxfEdgeReference.new(model)

      end

      def read(face_reference_elm)

        main_edge_elm = face_reference_elm.elements['mainEdge']
        self.main_edge.read(main_edge_elm) if main_edge_elm

        support_edge_elm = face_reference_elm.elements['supportEdge']
        self.support_edge.read(support_edge_elm) if support_edge_elm

        super
      end

    end


    # --

    class BxfDrawingDetail < BxfModelable

      attr_accessor :front_orientation,
                    :floor_orientation

      def initialize(model)
        super

        @front_orientation = BxfVector3d.new(model)
        @floor_orientation = BxfVector3d.new(model)

      end

      def read(drawing_detail_elm)

        front_orientation_attr = drawing_detail_elm.attributes['frontOrientation']
        self.front_orientation.read(front_orientation_attr) if front_orientation_attr

        floor_orientation_attr = drawing_detail_elm.attributes['floorOrientation']
        self.floor_orientation.read(floor_orientation_attr) if floor_orientation_attr

        super
      end

    end

    class BxfMaterial < BxfModelable

      TYPE_WOOD = 'WoodMaterial'
      TYPE_ALUMINUIM = 'AluminiumMaterial'
      TYPE_GLASS = 'GlassMaterial'

      attr_accessor :type,
                    :name
      attr_reader   :grain_direction

      def initialize(model)
        super

        @type = nil
        @name = nil

        @grain_direction = BxfVector3d.new(model)

      end

      def read(material_elm)

        self.type = material_elm.attributes['type']
        self.name = material_elm.attributes['name']

        grain_direction_attr = material_elm.attributes['grainDirection']
        self.grain_direction.read(grain_direction_attr) if grain_direction_attr

        super
      end

    end

    # --

    class BxfScene < BxfModelable

      attr_reader :nodes

      def initialize(model)
        super

        @nodes = BxfNodes.new(model)
        @parameters = BxfParameters.new(model)

      end

      def read(scene_elm)

        nodes_elm = scene_elm.elements['nodes']
        self.nodes.read(nodes_elm) if nodes_elm

        parameters_elm = scene_elm.elements['parameters']
        self.parameters.read(parameters_elm) if parameters_elm

        super
      end

    end

    class BxfNodes < BxfModelable

      include Enumerable

      def initialize(model)
        super

        @nodes = [] # Array<BxfNode>

      end

      def read(nodes_elm)

        nodes_elm.elements.each('node') do |elm|
          @nodes << BxfNode.new(model).read(elm)
        end

        super
      end

      def each(&block)
        @nodes.each(&block)
      end

    end

    class BxfNode < BxfObject

      attr_reader   :transformations,
                    :cabinet_group_links,
                    :cabinet_links,
                    :container_links,
                    :function_unit_links,
                    :links,
                    :nodes

      def initialize(model)
        super

        @transformations = BxfTransformations.new(model)

        @cabinet_group_links = []   # Array<BxfCabinetGroup>
        @cabinet_links = []         # Array<BxfCabinetLink>
        @container_links = []       # Array<BxfContainerLink>
        @function_unit_links = []   # Array<BxfFunctionUnitLink>
        @links = []                 # Array<BxfTransformableLink>

        @nodes = BxfNodes.new(model)

      end

      def read(node_elm)

        transformations_elm = node_elm.elements['transformations']
        self.transformations.read(transformations_elm) if transformations_elm

        node_elm.elements.each('cabinetGroupLinks/cabinetGroupLink') do |elm|
          self.cabinet_group_links << BxfCabinetGroupLink.new(model).read(elm)
        end

        node_elm.elements.each('cabinetLinks/cabinetLink') do |elm|
          self.cabinet_links << BxfCabinetLink.new(model).read(elm)
        end

        node_elm.elements.each('containerLinks/containerLink') do |elm|
          self.container_links << BxfContainerLink.new(model).read(elm)
        end

        node_elm.elements.each('functionUnitLinks/functionUnitLink') do |elm|
          self.function_unit_links << BxfFunctionUnitLink.new(model).read(elm)
        end

        node_elm.elements.each('links/link') do |elm|
          self.links << BxfTransformableObjectLink.new(model).read(elm)
        end

        nodes_elm = node_elm.elements['nodes']
        self.nodes.read(nodes_elm) if nodes_elm

        super
      end

    end

    class BxfLibrary < BxfModelable

      attr_reader :cabinet_groups, :cabinets,
                  :containers,
                  :parts,
                  :function_units,
                  :articles,
                  :components,
                  :machining_groups, :machinings

      def initialize(model)
        super

        @cabinet_groups = BxfCabinetGroups.new(model)
        @cabinets = BxfCabinets.new(model)
        @containers = BxfContainers.new(model)
        @parts = BxfParts.new(model)
        @function_units = BxfFunctionUnits.new(model)
        @articles = BxfArticles.new(model)
        @components = BxfComponents.new(model)
        @machining_groups = BxfMachiningGroups.new(model)
        @machinings = BxfMachinings.new(model)

      end

      def read(library_elm)

        cabinet_groups_elm = library_elm.elements['cabinetGroups']
        self.cabinet_groups.read(cabinet_groups_elm) if cabinet_groups_elm

        cabinets_elm = library_elm.elements['cabinets']
        self.cabinets.read(cabinets_elm) if cabinets_elm

        container_elm = library_elm.elements['containers']
        self.containers.read(container_elm) if container_elm

        parts_elm = library_elm.elements['parts']
        self.parts.read(parts_elm) if parts_elm

        function_units_elm = library_elm.elements['functionUnits']
        self.function_units.read(function_units_elm) if function_units_elm

        articles_elm = library_elm.elements['articles']
        self.articles.read(articles_elm) if articles_elm

        components_elm = library_elm.elements['components']
        self.components.read(components_elm) if components_elm

        machining_groups_elm = library_elm.elements['machiningGroups']
        self.machining_groups.read(machining_groups_elm) if machining_groups_elm

        machinings_elm = library_elm.elements['machinings']
        self.machinings.read(machinings_elm) if machinings_elm

        super
      end

    end


    # -- Cabinets


    class BxfCabinetGroups < BxfModelable

      include Enumerable

      def initialize(model)
        super
        @cabinet_groups = {}
      end

      def [](id)
        @cabinet_groups[id]
      end

      def []=(id, cabinet_group)
        @cabinet_groups[id] = cabinet_group
      end

      def read(cabinet_groups_elm)

        cabinet_groups_elm.elements.each('cabinetGroup') do |elm|
          cabinet_group = BxfCabinetGroup.new(model).read(elm)
          self[cabinet_group.id] = cabinet_group
        end

        super
      end

      def each(&block)
        @cabinet_groups.each(&block)
      end

    end

    class BxfCabinetGroup < BxfReferenceableObject

      attr_reader :cabinet_links

      def initialize(model)
        super

        @cabinet_links = [] # Array<BxfCabinetLink>

      end

      def read(cabinet_groups_elm)

        cabinet_groups_elm.elements.each('cabinetLinks/cabinetLink') do |elm|
          self.cabinet_links << BxfCabinetLink.new(model).read(elm)
        end

        super
      end

    end


    class BxfCabinets < BxfModelable

      include Enumerable

      def initialize(model)
        super
        @cabinets = {}
      end

      def [](id)
        @cabinets[id]
      end

      def []=(id, cabinet)
        @cabinets[id] = cabinet
      end

      def read(cabinets_elm)

        cabinets_elm.elements.each('cabinet') do |elm|
          cabinet = BxfCabinet.new(model).read(elm)
          self[cabinet.id] = cabinet
        end

        super
      end

      def each(&block)
        @cabinets.each(&block)
      end

    end

    class BxfCabinet < BxfReferenceableObject

      attr_accessor :model_key
      attr_reader   :part_links,
                    :function_unit_links,
                    :container_links

      def initialize(model)
        super

        @model_key = nil

        @part_links = []            # Array<BxfPartLink>
        @function_unit_links = []   # Array<BxfFunctionUnitLink>
        @container_links = []       # Array<BxfContainerLink>

      end

      def read(cabinets_elm)

        self.model_key = cabinets_elm.attributes['modelKey']

        cabinets_elm.elements.each('partLinks/partLink') do |elm|
          self.part_links << BxfPartLink.new(model).read(elm)
        end

        cabinets_elm.elements.each('functionUnitLinks/functionUnitLink') do |elm|
          self.part_links << BxfFunctionUnitLink.new(model).read(elm)
        end

        cabinets_elm.elements.each('containerLinks/containerLink') do |elm|
          self.container_links << BxfContainerLink.new(model).read(elm)
        end

        super
      end

    end


    class BxfCabinetGroupLink < BxfTransformableObjectLink

      def cabinet_group
        model.library.cabinet_groups[self.reference_id]
      end

    end

    class BxfCabinetLink < BxfTransformableObjectLink

      def cabinet
        model.library.cabinets[self.reference_id]
      end

    end


    # -- Containers


    class BxfContainers < BxfModelable

      include Enumerable

      def initialize(model)
        super
        @containers = {}
      end

      def [](id)
        @containers[id]
      end

      def []=(id, container)
        @containers[id] = container
      end

      def read(containers_elm)

        containers_elm.elements.each('container') do |elm|
          container = BxfContainer.new(model).read(elm)
          self[container.id] = container
        end

        super
      end

      def each(&block)
        @containers.each(&block)
      end

    end

    class BxfContainer < BxfReferenceableObject

      attr_accessor :model_key,
                    :boundary
      attr_reader   :function_unit_links

      def initialize(model)
        super

        @model_key = nil
        @boundary = nil # BxfGeometry

        @function_unit_links = [] # Array<BxfFunctionUnitLink>

      end

      def read(container_elm)

        self.model_key = container_elm.attributes['modelKey']

        boundary_elm = container_elm.elements['boundary']
        self.boundary = BxfGeometry.create(model, boundary_elm) if boundary_elm

        container_elm.elements.each('functionUnitLinks/functionUnitLink') do |elm|
          self.function_unit_links << BxfFunctionUnitLink.new(model).read(elm)
        end

        super
      end

    end


    class BxfContainerLink < BxfZoneLink

      def container
        model.library.containers[self.reference_id]
      end

    end


    # -- Parts


    class BxfParts < BxfModelable

      include Enumerable

      def initialize(model)
        super
        @parts = {}
      end

      def [](id)
        @parts[id]
      end

      def []=(id, part)
        @parts[id] = part
      end

      def read(parts_elm)

        parts_elm.elements.each('part') do |elm|
          part = BxfPart.new(model).read(elm)
          self[part.id] = part
        end

        super
      end

      def each(&block)
        @parts.each(&block)
      end

    end

    class BxfPart < BxfReferenceableObject

      attr_accessor :model_key,
                    :geometry
      attr_reader   :inherited_machinings,
                    :machining_group_links,
                    :machining_links,
                    :drawing_detail,
                    :material

      def initialize(model)
        super

        @model_key = nil

        @geometry = nil # BxfGeometry

        @inherited_machinings = []    # Array<BxfInheritedMachining>
        @machining_group_links = []   # Array<BxfMachiningGroupLink>
        @machining_links = []         # Array<BxfMachiningLink>

        @drawing_detail = BxfDrawingDetail.new(model)
        @material = BxfMaterial.new(model)

      end

      def read(part_elm)

        self.model_key = part_elm.attributes['modelKey']

        geometry_elm = part_elm.elements['geometry']
        self.geometry = BxfGeometry.create(model, geometry_elm) if geometry_elm

        part_elm.elements.each('inheritedMachinings/inheritedMachining') do |elm|
          self.inherited_machinings << BxfInheritedMachining.new(model).read(elm)
        end

        part_elm.elements.each('machiningGroupLinks/machiningGroupLink') do |elm|
          self.machining_group_links << BxfMachiningGroupLink.new(model).read(elm)
        end

        part_elm.elements.each('machiningLinks/machiningLink') do |elm|
          self.machining_links << BxfMachiningLink.new(model).read(elm)
        end

        drawing_detail_elm = part_elm.elements['drawingDetail']
        self.drawing_detail.read(drawing_detail_elm) if drawing_detail_elm

        material_elm = part_elm.elements['material']
        self.material.read(material_elm) if material_elm

        super
      end

    end


    class BxfPartLink < BxfZoneLink

      def part
        model.library.parts[self.reference_id]
      end

    end


    # -- FunctionUnits


    class BxfFunctionUnits < BxfModelable

      include Enumerable

      def initialize(model)
        super
        @function_units = {}
      end

      def [](id)
        @function_units[id]
      end

      def []=(id, function_unit)
        @function_units[id] = function_unit
      end

      def read(function_units_elm)

        function_units_elm.elements.each('functionUnit') do |elm|
          function_unit = BxfFunctionUnit.new(model).read(elm)
          self[function_unit.id] = function_unit
        end

        super
      end

      def each(&block)
        @function_units.each(&block)
      end

    end

    class BxfFunctionUnit < BxfReferenceableObject

      attr_accessor :model_key
      attr_reader   :article_links,
                    :part_links,
                    :component_links

      def initialize(model)
        super

        @model_key = nil

        @article_links = []     # Array<BxfArticleLink>
        @part_links = []        # Array<BxfPartLink>
        @component_links = []   # Array<BxfComponentLink>

      end

      def read(function_unit_elm)

        self.model_key = function_unit_elm.attributes['modelKey']

        function_unit_elm.elements.each('articleLinks/articleLink') do |elm|
          self.article_links << BxfArticleLink.new(model).read(elm)
        end

        function_unit_elm.elements.each('partLinks/partLink') do |elm|
          self.part_links << BxfPartLink.new(model).read(elm)
        end

        function_unit_elm.elements.each('componentLinks/componentLink') do |elm|
          self.component_links << BxfComponentLink.new(model).read(elm)
        end

        super
      end

    end


    class BxfFunctionUnitLink < BxfZoneLink

      def function_unit
        model.library.function_units[self.reference_id]
      end

    end


    # -- Articles


    class BxfArticles < BxfModelable

      include Enumerable

      def initialize(model)
        super
        @articles = {}
      end

      def [](id)
        @articles[id]
      end

      def []=(id, article)
        @articles[id] = article
      end

      def read(articles_elm)

        articles_elm.elements.each('article') do |elm|
          article = BxfArticle.new(model).read(elm)
          self[article.id] = article
        end

        super
      end

      def each(&block)
        @articles.each(&block)
      end

    end

    class BxfArticle < BxfReferenceableObject

      attr_accessor :material,
                    :item_number,
                    :article_number,
                    :total_quantity
      attr_reader   :material,
                    :component_numbers

      def initialize(model)
        super

        @material = nil
        @item_number = nil
        @article_number = nil
        @total_quantity = 0

        @component_numbers = [] # Array<String>

      end

      def read(article_elm)

        material_elm = article_elm.elements['material']
        self.material = material_elm.text if material_elm

        self.item_number = article_elm.attributes['itemNumber']
        self.article_number = article_elm.attributes['articleNumber']
        self.total_quantity = article_elm.attributes['totalQuantity'].to_i

        article_elm.elements.each('componentNumbers/componentNumber') do |elm|
          self.component_numbers << elm.text
        end

        super
      end

      def components
        @component_numbers.map { |component_number| model.library.components.values.find { |component| component.component_number == component_number } }
      end

    end


    class BxfArticleLink < BxfObjectLink

      attr_accessor :quantity

      def initialize(model)
        super

        @quantity = 0

      end

      def read(article_links_elm)

        self.quantity = article_links_elm.attributes['quantity'].to_i

        super
      end

      def article
        model.library.articles[self.reference_id]
      end

    end


    # -- Components


    class BxfComponents < BxfModelable

      include Enumerable

      def initialize(model)
        super
        @components = {}
      end

      def [](id)
        @components[id]
      end

      def []=(id, component)
        @components[id] = component
      end

      def read(components_elm)

        components_elm.elements.each('component') do |elm|
          component = BxfComponent.new(model).read(elm)
          self[component.id] = component
        end

        super
      end

      def each(&block)
        @components.each(&block)
      end

    end

    class BxfComponent < BxfReferenceableObject

      attr_accessor :model_key,
                    :component_number
      attr_reader   :machining_group_links,
                    :machining_links,
                    :related_machining_group_links,
                    :related_machining_links

      def initialize(model)
        super

        @model_key = nil
        @component_number = nil

        @machining_group_links = []           # Array<BxfMachiningGroupLink>
        @machining_links = []                 # Array<BxfMachiningLink>
        @related_machining_group_links = []   # Array<BxfMachiningGroupLink>
        @related_machining_links = []         # Array<BxfMachiningLink>

      end

      def read(component_elm)

        self.model_key = component_elm.attributes['modelKey']
        self.component_number = component_elm.attributes['componentNumber']

        component_elm.elements.each('machiningGroupLinks.machiningGroupLink') do |elm|
          self.machining_group_links << BxfMachiningGroupLink.new(model).read(elm)
        end

        component_elm.elements.each('machiningLinks/machiningLink') do |elm|
          self.machining_links << BxfMachiningLink.new(model).read(elm)
        end

        component_elm.elements.each('relatedMachiningGroupLinks/machiningGroupLink') do |elm|
          self.related_machining_group_links << BxfMachiningGroupLink.new(model).read(elm)
        end

        component_elm.elements.each('relatedMachiningLinks/machiningLink') do |elm|
          self.related_machining_links << BxfMachiningLink.new(model).read(elm)
        end

        super
      end

      def article
        id, article = model.library.articles.find { |id, article| article.component_numbers.include?(self.component_number) }
        article
      end

    end


    class BxfComponentLink < BxfTransformableObjectLink

      def component
        model.library.components[self.reference_id]
      end

    end


    # -- Machinings


    class BxfMachiningType < BxfObject

      attr_accessor :model_key
      attr_reader   :category

      def initialize(model)
        super

        @model_key = nil
        @category = BxfMachiningCategory.new(model)

      end

      def read(type_elm)

        self.model_key = type_elm.attributes['modelKey']

        category_attr = type_elm.attributes['category']
        self.category.read(category_attr) if category_attr

        super
      end

    end

    class BxfMachiningCategory < BxfModelable

      CATEGORY_CONNECTOR = 'connector'

      attr_accessor :value

      def initialize(model)
        super

        @value = CATEGORY_CONNECTOR

      end

      def read(str)

        self.value = str

        super
      end

    end


    class BxfMachiningGroups < BxfModelable

      include Enumerable

      def initialize(model)
        super
        @machining_groups = {}
      end

      def [](id)
        @machining_groups[id]
      end

      def []=(id, machining_group)
        @machining_groups[id] = machining_group
      end

      def read(machining_groups_elm)

        machining_groups_elm.elements.each('machiningGroup') do |elm|
          machining_group = BxfMachiningGroup.create(model, elm)
          self[machining_group.id] = machining_group
        end

        super
      end

      def each(&block)
        @machining_groups.each(&block)
      end

    end

    class BxfMachiningGroup < BxfReferenceableObject

      attr_accessor :model_key
      attr_reader   :machining_links

      def initialize(model)
        super

        @model_key = nil

        @machining_links = [] # Array<BxfMachiningLink>

      end

      def self.create(model, elm)
        type = elm.attributes['xsi:type']
        case type
        when 'GridMachining'
          BxfGridMachining.new(model).read(elm)
        else
          BxfMachiningGroup.new(model).read(elm)
        end
      end

      def read(machining_group_elm)

        self.model_key = machining_group_elm.attributes['modelKey']

        machining_group_elm.elements.each('machiningLinks/machiningLink') do |elm|
          self.machining_links << BxfMachiningLink.new(model).read(elm)
        end

        super
      end

    end

    class BxfGridMachining < BxfMachiningGroup

      attr_accessor :column_count,
                    :column_distance,
                    :row_count,
                    :row_distance

      def initialize(model)
        super

        @column_count = 1
        @column_distance = BxfLength.new(model)
        @row_count = 1
        @row_distance = BxfLength.new(model)

      end

      def read(machining_group_elm)

        self.column_count = machining_group_elm.attributes['columnCount'].to_i

        column_distance_elm = machining_group_elm.attributes['columnDistance']
        self.column_distance.read(column_distance_elm) if column_distance_elm

        self.row_count = machining_group_elm.attributes['rowCount'].to_i

        row_distance_elm = machining_group_elm.attributes['rowDistance']
        self.row_distance.read(row_distance_elm) if row_distance_elm

        super
      end

    end


    class BxfMachinings < BxfModelable

      include Enumerable

      def initialize(model)
        super
        @machinings = {}
      end

      def [](id)
        @machinings[id]
      end

      def []=(id, machining)
        @machinings[id] = machining
      end

      def read(machinings_elm)

        machinings_elm.elements.each('machining') do |elm|
          machining = BxfMachining.create(model, elm)
          self[machining.id] = machining
        end

        super
      end

      def each(&block)
        @machinings.each(&block)
      end

    end

    class BxfMachining < BxfReferenceableObject

      TYPE_CUT = 'Cut'
      TYPE_DRILLING = 'Drilling'
      TYPE_ROUNDING = 'Rounding'
      TYPE_RABBET = 'Rabbet'
      TYPE_GROOVE = 'Groove'
      TYPE_ROUNDED_GROOVE = 'RoundedGroove'
      TYPE_GLUE = 'Glue'
      TYPE_CHAMFER = 'Chamfer'

      def initialize(model, type)
        super(model)

        @type = type

      end

      def self.create(model, elm)
        type = elm.attributes['xsi:type']
        case type
        when TYPE_CUT
          BxfMachiningCut.new(model).read(elm)
        when TYPE_DRILLING
          BxfMachiningDrilling.new(model).read(elm)
        when TYPE_ROUNDING
          BxfMachiningRounding.new(model).read(elm)
        when TYPE_RABBET
          BxfMachiningRabbet.new(model).read(elm)
        when TYPE_GROOVE
          BxfMachiningGroove.new(model).read(elm)
        when TYPE_ROUNDED_GROOVE
          BxfMachiningRoundedGroove.new(model).read(elm)
        when TYPE_GLUE
          BxfMachiningGlue.new(model).read(elm)
        when TYPE_CHAMFER
          BxfMachiningChamfer.new(model).read(elm)
        else
          raise "Unknown machining type : #{type}"
        end
      end

    end

    class BxfMachiningCut < BxfMachining

      attr_reader :orientation,
                  :original_size,
                  :final_size

      def initialize(model)
        super(model, TYPE_CUT)

        @orientation = BxfVector3d.new(model)
        @original_size = BxfLength.new(model)
        @final_size = BxfLength.new(model)

      end

    end

    class BxfMachiningDrilling < BxfMachining

      attr_reader :radius,
                  :depth,
                  :depth_orientation

      def initialize(model)
        super(model, TYPE_DRILLING)

        @radius = BxfLength.new(model)
        @depth = BxfLength.new(model)
        @depth_orientation = BxfVector3d.new(model, '0 0 -1')

      end

      def read(drilling_elm)

        radius_attr = drilling_elm.attributes['radius']
        self.radius.read(radius_attr) if radius_attr

        depth_attr = drilling_elm.attributes['depth']
        self.depth.read(depth_attr) if depth_attr

        depth_orientation_attr = drilling_elm.attributes['depthOrientation']
        self.depth_orientation.read(depth_orientation_attr) if depth_orientation_attr

        super
      end

    end

    class BxfMachiningRounding < BxfMachining

      attr_reader :radius,
                  :length,
                  :length_orientation

      def initialize(model)
        super(model, TYPE_ROUNDING)

        @radius = BxfLength.new(model)
        @length = BxfLength.new(model)
        @length_orientation = BxfVector3d.new(model)

      end

      def read(rounding_elm)

        radius_attr = rounding_elm.attributes['radius']
        self.radius.read(radius_attr) if radius_attr

        length_attr = rounding_elm.attributes['length']
        self.length.read(length_attr) if length_attr

        length_orientation_attr = rounding_elm.attributes['lengthOrientation']
        self.length_orientation.read(length_orientation_attr) if length_orientation_attr

        super
      end

    end

    class BxfMachiningRabbet < BxfMachining

      attr_reader :radius,
                  :depth,
                  :length,
                  :depth_orientation,
                  :length_orientation

      def initialize(model)
        super(model, TYPE_RABBET)

        @radius = BxfLength.new(model)
        @depth = BxfLength.new(model)
        @depth_orientation = BxfVector3d.new(model, '0 0 -1')
        @length = BxfLength.new(model)
        @length_orientation = BxfVector3d.new(model)

      end

      def read(rabbet_elm)

        radius_attr = rabbet_elm.attributes['radius']
        self.radius.read(radius_attr) if radius_attr

        depth_attr = rabbet_elm.attributes['depth']
        self.depth.read(depth_attr) if depth_attr

        depth_orientation_attr = rabbet_elm.attributes['depthOrientation']
        self.depth_orientation.read(depth_orientation_attr) if depth_orientation_attr

        length_attr = rabbet_elm.attributes['length']
        self.length.read(length_attr) if length_attr

        length_orientation_attr = rabbet_elm.attributes['lengthOrientation']
        self.length_orientation.read(length_orientation_attr) if length_orientation_attr

        super
      end

    end

    class BxfMachiningGroove < BxfMachining

      attr_reader :radius,
                  :depth,
                  :length,
                  :depth_orientation,
                  :length_orientation

      def initialize(model)
        super(model, TYPE_GROOVE)

        @radius = BxfLength.new(model)
        @depth = BxfLength.new(model)
        @depth_orientation = BxfVector3d.new(model, '0 0 -1')
        @length = BxfLength.new(model)
        @length_orientation = BxfVector3d.new(model)

      end

      def read(groove_elm)

        radius_attr = groove_elm.attributes['radius']
        self.radius.read(radius_attr) if radius_attr

        depth_attr = groove_elm.attributes['depth']
        self.depth.read(depth_attr) if depth_attr

        depth_orientation_attr = groove_elm.attributes['depthOrientation']
        self.depth_orientation.read(depth_orientation_attr) if depth_orientation_attr

        length_attr = groove_elm.attributes['length']
        self.length.read(length_attr) if length_attr

        length_orientation_attr = groove_elm.attributes['lengthOrientation']
        self.length_orientation.read(length_orientation_attr) if length_orientation_attr

        super
      end

    end

    class BxfMachiningRoundedGroove < BxfMachining

      attr_reader :radius,
                  :depth,
                  :length,
                  :depth_orientation,
                  :length_orientation,
                  :rounded_edges

      def initialize(model)
        super(model, TYPE_ROUNDED_GROOVE)

        @radius = BxfLength.new(model)
        @depth = BxfLength.new(model)
        @depth_orientation = BxfVector3d.new(model, '0 0 -1')
        @length = BxfLength.new(model)
        @length_orientation = BxfVector3d.new(model)

        @rounded_edges = [] # Array<BxfRoundedEdge>

      end

      def read(rounded_groove_elm)

        radius_attr = rounded_groove_elm.attributes['radius']
        self.radius.read(radius_attr) if radius_attr

        depth_attr = rounded_groove_elm.attributes['depth']
        self.depth.read(depth_attr) if depth_attr

        depth_orientation_attr = rounded_groove_elm.attributes['depthOrientation']
        self.depth_orientation.read(depth_orientation_attr) if depth_orientation_attr

        length_attr = rounded_groove_elm.attributes['length']
        self.length.read(length_attr) if length_attr

        length_orientation_attr = rounded_groove_elm.attributes['lengthOrientation']
        self.length_orientation.read(length_orientation_attr) if length_orientation_attr

        rounded_groove_elm.elements.each('roundedEdges/edge') do |elm|
          self.rounded_edges << BxfRoundedEdge.new(model).read(elm)
        end

        super
      end

    end

    class BxfMachiningGlue < BxfMachining

      attr_reader :width,
                  :thickness,
                  :length,
                  :thickness_orientation,
                  :length_orientation

      def initialize(model)
        super(model, TYPE_GLUE)

        @width = BxfLength.new(model)
        @thickness = BxfLength.new(model)
        @length = BxfLength.new(model)
        @thickness_orientation = BxfVector3d.new(model)
        @length_orientation = BxfVector3d.new(model)

      end

      def read(glue_elm)

        width_attr = glue_elm.attributes['width']
        self.width.read(width_attr) if width_attr

        thickness_attr = glue_elm.attributes['thickness']
        self.thickness.read(thickness_attr) if thickness_attr

        length_attr = glue_elm.attributes['length']
        self.length.read(length_attr) if length_attr

        thickness_orientation_attr = glue_elm.attributes['thicknessOrientation']
        self.thickness_orientation.read(thickness_orientation_attr) if thickness_orientation_attr

        length_orientation_attr = glue_elm.attributes['lengthOrientation']
        self.length_orientation.read(length_orientation_attr) if length_orientation_attr

        super
      end

    end

    class BxfMachiningChamfer < BxfMachining

      attr_reader :distance1,
                  :distance2,
                  :length,
                  :distance1_orientation,
                  :distance2_orientation,
                  :length_orientation

      def initialize(model)
        super(model, TYPE_CHAMFER)

        @distance1 = BxfLength.new(model)
        @distance2 = BxfLength.new(model)
        @length = BxfLength.new(model)
        @distance1_orientation = BxfVector3d.new(model)
        @distance2_orientation = BxfVector3d.new(model)
        @length_orientation = BxfVector3d.new(model)

      end

      def read(chamfer_elm)

        distance1_attr = chamfer_elm.attributes['distance1']
        self.distance1.read(distance1_attr) if distance1_attr

        distance2_attr = chamfer_elm.attributes['distance2']
        self.distance2.read(distance2_attr) if distance2_attr

        length_attr = chamfer_elm.attributes['length']
        self.length.read(length_attr) if length_attr

        distance1_orientation_attr = chamfer_elm.attributes['distance1Orientation']
        self.distance1_orientation.read(distance1_orientation_attr) if distance1_orientation_attr

        distance2_orientation_attr = chamfer_elm.attributes['distance2Orientation']
        self.distance2_orientation.read(distance2_orientation_attr) if distance2_orientation_attr

        length_orientation_attr = chamfer_elm.attributes['lengthOrientation']
        self.length_orientation.read(length_orientation_attr) if length_orientation_attr

        super
      end

    end


    class BxfInheritedMachining < BxfObject

      attr_reader :component_link,
                  :machining_group_link_references,
                  :machining_link_references

      def initialize(model)
        super

        @component_link = BxfComponentLink.new(model)
        @machining_group_link_references = []
        @machining_link_references = []

      end

      def read(inherited_machining_elm)

        component_link_elm = inherited_machining_elm.elements['componentLink']
        self.component_link.read(component_link_elm) if component_link_elm

        inherited_machining_elm.elements.each('machiningGroupLinkReferences/machiningGroupLinkReference') do |elm|
          self.machining_group_link_references << BxfMachiningGroupLinkReference.new(model).read(elm)
        end

        inherited_machining_elm.elements.each('machiningLinkReferences/machiningLinkReference') do |elm|
          self.machining_link_references << BxfMachiningLinkReference.new(model).read(elm)
        end

        super
      end

    end


    class BxfMachiningBaseLink < BxfTransformableReferenceableObjectLink

      attr_accessor :preferred_stop
      attr_reader   :type

      def initialize(model)
        super

        @type = BxfMachiningType.new(model)
        @preferred_stop = nil # BxfGeometricReference

      end

      def read(elm)

        type_elm = elm.elements['type']
        self.type.read(type_elm) if type_elm

        preferred_stop_elm = elm.elements['preferredStop']
        self.preferred_stop = BxfGeometricReference.create(model, preferred_stop_elm) if preferred_stop_elm

        super
      end

    end

    class BxfMachiningGroupLink < BxfMachiningBaseLink

      attr_accessor :model_key

      def initialize(model)
        super

        @model_key = nil

      end

      def read(machining_group_links_elm)

        self.model_key = machining_group_links_elm.attributes['modelKey']

        super
      end

      def machining_group
        model.library.machining_groups[self.reference_id]
      end

    end

    class BxfMachiningLink < BxfMachiningBaseLink

      def machining
        model.library.machinings[self.reference_id]
      end

    end


    class BxfMachiningBaseLinkReference < BxfObjectLink

      attr_accessor :preferred_stop
      attr_reader   :type

      def initialize(model)
        super

        @type = BxfMachiningType.new(model)
        @preferred_stop = nil # BxfGeometricReference

      end

      def read(elm)

        type_elm = elm.elements['type']
        self.type.read(type_elm) if type_elm

        preferred_stop_elm = elm.elements['preferredStop']
        self.preferred_stop = BxfGeometricReference.create(model, preferred_stop_elm) if preferred_stop_elm

        super
      end

    end

    class BxfMachiningGroupLinkReference < BxfMachiningBaseLinkReference
    end

    class BxfMachiningLinkReference < BxfMachiningBaseLinkReference
    end

  end

end
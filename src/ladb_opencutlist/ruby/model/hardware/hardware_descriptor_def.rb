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
  #    "length_unit": "mm",         the unit of its bare numbers - see below
  #    "hardware_material": "…",
  #    "components": { "<slot>": <component> },
  #    "variables": { "<name>": "<length expression>" },
  #    "asserts": [ "<length expression> <= <length expression>" ],
  #    "options": { "<name>": "<value>" }   defaults of the tool's options
  #  }
  #
  # A <component> is either :
  #  - { "name", "description", "price", "url", "mass",
  #      "hardware": <part> | <primitives>, "machining": <part> | <primitives>,
  #      "stretch": { … }, "attributes": { … } }
  #  - { "same_as": "<slot>" } / { "mirror_of": "<slot>" } : the other slot's
  #    component, laid mirrored across the YZ plane of the laying frame - x
  #    negated - for mirror_of ;
  #  - { "name", …, "variants": { "select": { "by": "<measure>", "mode": "exact" | "max_le", "ratio": <Float> },
  #                               "fallback": "<key>", "items": { "<key>": <component> | null } },
  #      "attributes": { … } }
  #  - null or {} : the slot is left empty (a one sided fitting) - {} keeps
  #    the slot listed in the editor, ready to be filled.
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
  # The hardware part can instead hold several ARTICLES - each its own part
  # in the cut list - as an object keyed by short names, unique in the slot
  # (ARTICLE_KEY_PATTERN, never one of ARTICLE_FIELDS - that tells it from
  # a single article) :
  #    "hardware": {
  #      "body": { "name": "Angle bracket 40x40", "price": 0.30, "skp": true },
  #      "screws": { "use": "connectors/generic/screws/screw-4x20.json", "host": "a",
  #                  "measures": { "thickness_b": "@bracket_thickness" },
  #                  "variables": { "length": { "value": "18mm" } },
  #                  "at": [ { "x": -8, "y": "-@hole_distance" }, { "x": 8, "y": "-@hole_distance" } ] }
  #    }
  # An article gives its info fields - as a component - and its geometry,
  # one of :
  #  - "skp" : true - the file named after the slot and its key, see
  #    article_file_name - or a shared path, as a part ;
  #  - primitives : "cylinders", "oblongs", "prisms" ;
  #  - "use" : a concrete connector of the library - its path relative to
  #    the library's root, or a '$OCL/…' ref - reused as it is. "host" says
  #    which of its sides - "a" or "b" - the part is ; the other one is
  #    VIRTUAL : "measures" gives its thickness - "thickness_<side>" - its
  #    hardware is laid, its machining isn't. "variables" overrides the
  #    VALUES of its settings, nothing else. Its asserts are checked at each
  #    position. Its host side's machining is merged into the slot's.
  #    "axis" - "z" by default, or "y" - is the one of the slot it goes into
  #    the part along : "y" turns it a quarter around X, it goes into the
  #    face a machining along Y starts on - the edge, see VARIABLE_HEIGHT.
  #    Its host side's machining can then only be drillings and mortises
  #    along Z, their length along X.
  # "at" lists its positions - x, y and z lengths in the laying frame of the
  # slot, 0 by default - one at the origin when absent. They shift the
  # article off the face it goes in by - below it, sunk in a pocket, or
  # above it, on a spacer - and with it the contact plane of a used
  # connector : its host side's thickness - along its axis - loses what the
  # position sinks, see HardwareArticleDef#lift. Only a hardware that isn't
  # a connector can use another one - a cycle can't be.
  #
  # A part can instead be given as <primitives>, the tool generates its
  # geometry, in the laying frame of the type - the face at z = 0, the part
  # toward -Z. Lengths are strings or numbers - see "length_unit" ; x and
  # y default to 0. {} : none yet - nothing laid, the part kept
  # listed in the editor, ready to be filled, as an empty slot.
  #  - a machining, as operations - for what a fixed SKP can't adapt, a
  #    through hole in a part of any thickness :
  #    { "drillings": [ { "x": "-64mm", "y": 0, "diameter": "5mm", "depth": "through" | "12mm" } ],
  #      "mortises": [ { "x": 0, "y": 0, "length": "19mm", "width": "5mm", "depth": "15mm" } ] }
  #    from the face into the part - a mortise length long along X and
  #    width wide along Y, or the other way round with "length_axis": "y" ;
  #  - along Y - "axis": "y" - a drilling or a mortise goes from the face
  #    of the part +Y of the laying frame leads to - @height away, see
  #    measures - toward -Y. It is then placed by x and z - z toward -Z,
  #    into the part - its depth is a length, and a mortise is length long
  #    along X - the edge - and width wide along Z, or the other way round
  #    with "length_axis": "z". The access hole of a Clamex, on the face
  #    next to the joint, and the flush collar recess of a Cabineo :
  #    { "drillings": [ { "axis": "y", "z": "-7mm", "diameter": "6mm", "depth": "@height + 2mm" } ] }
  #    { "mortises": [ { "axis": "y", "length_axis": "z", "z": "-13mm", "length": "42.7mm", "width": "16.7mm", "depth": "0.8mm" } ] }
  #    On b of a hinge or a fitting - its part going away from the joint
  #    toward +Y - it goes the other way : from the face -Y leads to -
  #    @height away - toward +Y. See height_reversed?.
  #  - a hardware, as shapes - a dowel, a Domino tenon :
  #    { "cylinders": [ { "x": 0, "y": 0, "diameter": "8mm", "from": "-20mm", "to": "20mm" } ],
  #      "oblongs": [ { "x": 0, "y": 0, "length": "19mm", "width": "5mm", "from": "-15mm", "to": "15mm" } ] }
  #    along Z, from one height to the other. Either can lie along X or Y
  #    - "axis": "x" or "y" - from one length to the other along it, then
  #    placed by the two other axes, as the points of a prism : y and z
  #    along X, x and z along Y. An oblong is long along the first of them
  #    - x along Z or Y, y along X - or the second with "length_axis". A
  #    screw across the joint :
  #    { "cylinders": [ { "axis": "x", "z": "-8mm", "diameter": "4mm", "from": "-10mm", "to": "10mm" } ] }
  #    A plate, an angle bracket - a prism : an outline extruded along its
  #    axis - "z" by default, "x" or "y" - from one height to the other. Its
  #    points are given by the two other axes - x and y along Z, y and z
  #    along X, x and z along Y - 0 when absent, "r" rounds the corner :
  #    { "prisms": [ { "axis": "x", "from": "-20mm", "to": "20mm",
  #                    "outline": [ { "y": 0, "z": 0 }, { "y": "30mm", "z": 0 }, { "y": "30mm", "z": "2mm" },
  #                                 { "y": "2mm", "z": "2mm", "r": "1mm" }, { "y": "2mm", "z": "30mm" }, { "y": 0, "z": "30mm" } ] } ] }
  #    It doesn't cross itself, and each rounding fits its two sides.
  #  - a machining can be given pockets - an outline hollowed out of the
  #    part : a groove, a recess, what a drilling or a mortise can't shape -
  #    laid as they are, not centered. Like them, a pocket goes from the face
  #    into the part, depth deep - or along Y, "axis": "y", from the face
  #    +Y leads to - its points given by the two other axes, as a prism's :
  #    x and y, x and z along Y - z toward -Z, into the part :
  #    { "pockets": [ { "depth": "8mm", "outline": [ … ] } ] }
  # A mortise or an oblong is a slot with round ends, its length along X -
  # ends included - and its width along Y - but along Y, see above.
  # A drilling or a cylinder can widen at one end, in one solid with it :
  #  - "countersink": { "diameter": "8.5mm", "angle": 90, … } a cone, the
  #    head of a countersunk screw, angle in degrees - 90 by default ;
  #  - "counterbore": { "diameter": "10mm", "depth": "4mm", … } a step.
  # The end is "face": "contact" | "opposite" for a drilling - the face it is
  # laid on, or the other one, then its depth must be "through" - and "end":
  # "from" | "to" for a cylinder. A screw driven into a, through b, its head
  # on the far face of b :
  #    { "cylinders": [ { "diameter": "4mm", "from": "-@embed", "to": "@thickness_max_b",
  #                       "countersink": { "diameter": "8mm", "end": "to" } } ] }
  # A length can be an expression of the measures the tool takes where it
  # lays the part - see measures - : "@thickness - 2mm", "@thickness / 2",
  # "min(@thickness_a - 5mm; 20mm)". See LengthExpressionUtils. "through"
  # is "@thickness_max" - "@thickness" when it isn't given.
  #
  # "length_unit" - one of LengthExpressionUtils::LENGTH_UNITS - is the
  # unit of the bare numbers of its lengths, as the VCB's are in the
  # model's : "8", 8, "@thickness - 2" are millimeters with "mm", "@length
  # / 2" stays a factor. Without it, a length bears its unit - "8mm",
  # "3/4in", "1' 6\"" - and a bare number is a factor - but 0. Whatever the
  # model it is used in, a descriptor means the same. It is inherited and
  # can't change - see "extends". Read with each file - see
  # with_length_unit - the data holds its lengths with their unit.
  #
  # "variables" names expressions, evaluated in the order of their
  # dependencies : each can use the measures and the other variables,
  # wherever they are written - a cycle is an error - and the lengths of the
  # components can use them all - "@depth_a".
  #
  # A variable given as an object is a SETTING - what the editor shows the
  # user to set - its value a plain length, no variable nor function :
  #    "diameter": { "value": "8mm", "label": "Diamètre", "steps": [ "6mm", "8mm", "10mm" ] }
  #    "length": { "value": "40mm", "label": "Longueur", "min": "20mm", "max": "60mm" }
  # "steps" - the values it can take - or "min" / "max" - its range - both
  # optional, not together. Anywhere else, it reads as its value.
  #
  # "asserts" are comparisons - <=, >=, <, >, = - the measures must satisfy
  # for the hardware to be laid : "@depth_b <= @thickness_b - 5mm". The tool
  # refuses the anchors where one fails.
  #
  # A hardware is laid at the face : to shift it, give it as an article
  # with its "at" - see "hardware" below. "z_offset" is no more : a
  # component still having it is refused.
  #
  # "name", "description", "price", "url" and "mass" are what the cut list
  # reads of the laid hardware definition. Those of a variant override those
  # of the component holding the variants.
  #
  # "attributes" are written as is in the OCL dictionary of the laid hardware
  # definition - over those its SKP bears : { "hinge_max_angle": 110,
  # "hinge_pivot": [ "-8.5mm", "4.2mm" ] }. Values are scalars or arrays of
  # scalars. Those of a variant override those of the component holding the
  # variants. The kinematics of a hinge - see HINGE_ATTRIBUTES and DoorDef -
  # are checked : "hinge_pivot" is two lengths.
  # Those of a hinge made of articles go to the group holding them, laid in
  # the laying frame of its slot : its pivot is given in that frame,
  # whatever each article is shifted by.
  #
  # "extends" names the descriptor it inherits from - its path relative to
  # the root of the same library, or a '$OCL/…' ref from the user's library
  # - and it only declares what changes. The parent's data is merged into
  # it as a JSON Merge Patch (RFC 7386) : objects merge key by key, arrays
  # and scalars replace, null removes - but a variant set to null, that stays
  # "unsupported". format, version, id, name, extends and abstract are never
  # inherited ; type is, and can't change. "@super" as an element of an array
  # stands for the parent's array ; in the expression of a redefined
  # variable, for the parent's expression, in parentheses. A part declared
  # true, a shared file or a './' ref inherited as is stay the ones of the
  # descriptor that declares them. "abstract": true keeps a descriptor out of
  # the listings : it is only validated merged into a child. See data -
  # merged - and own_data - as written.
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
      TYPE_FACE => %w[a],
      TYPE_SPAN => %w[a b span],
    }.freeze

    PART_HARDWARE = 'hardware'.freeze
    PART_MACHINING = 'machining'.freeze
    PARTS = [ PART_HARDWARE, PART_MACHINING ].freeze

    # What the cut list reads of a laid hardware definition
    INFO_KEYS = %w[name description price url mass].freeze

    # A key no more supported : refused - see _validate_component
    Z_OFFSET = 'z_offset'.freeze

    # Articles - see "hardware" above
    ARTICLE_SKP = 'skp'.freeze
    ARTICLE_USE = 'use'.freeze
    ARTICLE_HOST = 'host'.freeze
    ARTICLE_MEASURES = 'measures'.freeze
    ARTICLE_VARIABLES = 'variables'.freeze
    ARTICLE_AT = 'at'.freeze
    ARTICLE_AT_KEYS = %w[x y z].freeze
    ARTICLE_AXIS = 'axis'.freeze
    ARTICLE_USE_KEYS = [ ARTICLE_USE, ARTICLE_HOST, ARTICLE_MEASURES, ARTICLE_VARIABLES, ARTICLE_AXIS ].freeze
    ARTICLE_KEY_PATTERN = /\A[a-z][a-z0-9_-]*\z/

    SELECT_MODE_EXACT = 'exact'.freeze
    SELECT_MODE_MAX_LE = 'max_le'.freeze   # The largest key <= the measure

    # How much the measure may fall short of a key and still take it
    MAX_LE_EPSILON = 1e-6

    # The folder of a library the SKP files of its descriptors live in
    COMPONENTS_DIR_NAME = 'components'.freeze

    LIBRARY_REF_PREFIXES = %w[$LIB/ $OCL/].freeze
    LIBRARY_REF_USER_PREFIX = '$LIB/'.freeze
    LIBRARY_REF_BUNDLED_PREFIX = '$OCL/'.freeze

    # Inheritance - see "extends"
    EXTENDS = 'extends'.freeze
    ABSTRACT = 'abstract'.freeze
    OWN_KEYS = [ 'format', 'version', 'id', 'name', EXTENDS, ABSTRACT ].freeze
    SUPER = 'super'.freeze
    SUPER_ELEMENT = '@super'.freeze
    SUPER_PATTERN = /@super(?!\w)/
    MAX_INHERITANCE_DEPTH = 8

    # What a definition loaded from a hardware SKP bears - in the OCL
    # attribute dictionary : the portable ref of its file, it is found by.
    DEFINITION_ATTRIBUTE_SOURCE = 'hardware_source'.freeze

    # What a definition generated from primitives bears - in the OCL
    # attribute dictionary : the key of its geometry, it is found by.
    DEFINITION_ATTRIBUTE_PRIMITIVES = 'hardware_primitives'.freeze

    MACHINING_DRILLINGS = 'drillings'.freeze
    MACHINING_MORTISES = 'mortises'.freeze
    HARDWARE_CYLINDERS = 'cylinders'.freeze
    HARDWARE_OBLONGS = 'oblongs'.freeze
    HARDWARE_PRISMS = 'prisms'.freeze
    MACHINING_POCKETS = 'pockets'.freeze

    # The primitives given as a prism - see HARDWARE_PRISMS - a pocket is
    # one hollowed out of the part, depth deep from the face like a drilling.
    PRISM_KEYS = [ HARDWARE_PRISMS, MACHINING_POCKETS ].freeze

    # What an article can hold - its key can't be one of them
    ARTICLE_FIELDS = (INFO_KEYS + [ ARTICLE_SKP, ARTICLE_AT ] + ARTICLE_USE_KEYS + [ HARDWARE_CYLINDERS, HARDWARE_OBLONGS, HARDWARE_PRISMS ]).freeze

    # The primitives each part can be given as
    PRIMITIVES = {
      PART_HARDWARE => [ HARDWARE_CYLINDERS, HARDWARE_OBLONGS, HARDWARE_PRISMS ],
      PART_MACHINING => [ MACHINING_DRILLINGS, MACHINING_MORTISES, MACHINING_POCKETS ],
    }.freeze

    DRILLING_DEPTH_THROUGH = 'through'.freeze

    # The axis a machining - a drilling, a mortise, a pocket - goes along :
    # Z - by default - from the face, or Y from the face of the part +Y leads
    # to - see PrimitiveCylinderDef#axis and VARIABLE_HEIGHT.
    AXIS_Z = 'z'.freeze
    AXIS_Y = 'y'.freeze
    AXES = [ AXIS_Z, AXIS_Y ].freeze

    # The axes the length of a mortise can go along, by the axis it goes
    # along : X - by default - or the other one across it. See
    # AXIS_Z_LENGTH_Y and AXIS_Y_LENGTH_Z.
    AXIS_X = 'x'.freeze
    LENGTH_AXES = {
      AXIS_Z => [ AXIS_X, AXIS_Y ],
      AXIS_Y => [ AXIS_X, AXIS_Z ],
    }.freeze

    # PrimitiveCylinderDef#axis of a mortise along Z whose length goes along
    # Y, and of one along Y whose length goes along Z - values of their own,
    # not of the descriptor.
    AXIS_Z_LENGTH_Y = 'z-y'.freeze
    AXIS_Y_LENGTH_Z = 'y-z'.freeze

    # The axis a prism is extruded along - Z by default - and the axes its
    # outline points are given by, in that order.
    PRISM_AXES = [ AXIS_Z, AXIS_X, AXIS_Y ].freeze
    PRISM_OUTLINE_KEYS = {
      AXIS_Z => %w[x y],
      AXIS_X => %w[y z],
      AXIS_Y => %w[x z],
    }.freeze
    PRISM_RADIUS_KEY = 'r'.freeze

    # PrimitiveCylinderDef#axis of a prism along X or Y - values of their
    # own, not of the descriptor : its outline given by [ u, v ], extruded
    # along w, a point [ u, v, w ] of it is [ w, u, v ] in the laying frame
    # along X, [ u, w, v ] along Y. AXIS_PRISM_X - a turn, not a mirror -
    # is also the one of a cylinder or an oblong along X, see SHAPE_FRAMES.
    AXIS_PRISM_X = 'prism-x'.freeze
    AXIS_PRISM_Y = 'prism-y'.freeze

    # PrimitiveCylinderDef#axis of an oblong along X whose length goes along
    # Z - a value of its own, not of the descriptor : a point [ x, y, z ] of
    # it is [ z, -y, x ] in the laying frame.
    AXIS_X_LENGTH_Z = 'x-z'.freeze

    # The frame a cylinder or an oblong is given in - see
    # PrimitiveCylinderDef#axis - by "<axis>-<length axis>", and its x and y
    # in it from the [ u, v ] the descriptor places it by - see
    # PRISM_OUTLINE_KEYS. Each is a turn - no mirror - its Z along the axis.
    SHAPE_FRAMES = {
      'z-x' => [ nil, lambda { |u, v| [ u, v ] } ],                    # [ x, y, z ]
      'z-y' => [ AXIS_Z_LENGTH_Y, lambda { |u, v| [ v, -u ] } ],       # [ -y, x, z ]
      'x-y' => [ AXIS_PRISM_X, lambda { |u, v| [ u, v ] } ],           # [ z, x, y ]
      'x-z' => [ AXIS_X_LENGTH_Z, lambda { |u, v| [ v, -u ] } ],       # [ z, -y, x ]
      'y-x' => [ AXIS_Y, lambda { |u, v| [ u, -v ] } ],                # [ x, z, -y ]
      'y-z' => [ AXIS_Y_LENGTH_Z, lambda { |u, v| [ -v, -u ] } ],      # [ -y, z, -x ]
    }.freeze

    # How a drilling or a cylinder widens at one end - see PrimitiveCylinderDef#profile
    HEAD_COUNTERSINK = 'countersink'.freeze
    HEAD_COUNTERBORE = 'counterbore'.freeze
    HEADS = [ HEAD_COUNTERSINK, HEAD_COUNTERBORE ].freeze
    HEAD_DEFAULT_ANGLE = 90

    # The end it widens at : 'face' of a drilling, 'end' of a cylinder -
    # the first of each is its top, z_max.
    HEAD_FACES = %w[contact opposite].freeze
    HEAD_ENDS = %w[to from].freeze

    # The measures the lengths can use, taken by the tool where it lays a
    # part - see measures :
    #  - thickness : how far the part goes behind the face - toward -Z ;
    #  - thickness_min, thickness_max : how far the other face of the part
    #    is, right behind the solids of the slot - their centers and
    #    outlines - the nearest and the farthest. They differ when the faces
    #    aren't parallel there : "@thickness_max_a - @thickness_min_a <= 0.2mm" ;
    #  - height : how far the part goes toward +Y from the anchor, just
    #    behind the face - the face a drilling along Y starts on. For a
    #    connector, the face of the edge it is laid from - its "height"
    #    option away. Toward -Y on b of a hinge or a fitting - see
    #    height_reversed? ;
    #  - height_min, height_max : where the same line leaves the part, the
    #    first time - height - and the last : the voids it crosses - a
    #    groove by the anchor - skipped, to its far edge on that line ;
    #  - <measure>_<slot> : the one of the part the given slot is laid on, for
    #    the types that join two parts - JOIN_TYPES. An expression then reads
    #    the same from either slot.
    VARIABLE_THICKNESS = 'thickness'.freeze
    VARIABLE_THICKNESS_MIN = 'thickness_min'.freeze
    VARIABLE_THICKNESS_MAX = 'thickness_max'.freeze
    VARIABLE_HEIGHT = 'height'.freeze
    VARIABLE_HEIGHT_MIN = 'height_min'.freeze
    VARIABLE_HEIGHT_MAX = 'height_max'.freeze
    VARIABLES = [ VARIABLE_THICKNESS, VARIABLE_THICKNESS_MIN, VARIABLE_THICKNESS_MAX, VARIABLE_HEIGHT, VARIABLE_HEIGHT_MIN, VARIABLE_HEIGHT_MAX ].freeze

    JOIN_TYPES = [ TYPE_CONNECTOR, TYPE_FITTING, TYPE_HINGE ].freeze

    # The types whose b goes away from the joint toward +Y of its laying
    # frame - X along the joint line, Z out of its face, Y = Z × X - : the
    # edge by the joint lies toward -Y. See height_reversed?.
    HEIGHT_REVERSED_TYPES = [ TYPE_FITTING, TYPE_HINGE ].freeze
    HEIGHT_REVERSED_SLOT = 'b'.freeze

    # The attributes of the kinematics of a hinge - see DoorDef : the widest
    # opening in degrees, the [ y, z ] lengths of the axis it turns around in
    # the fitting frame, and whether that axis only stands in for a moving one.
    ATTRIBUTE_HINGE_MAX_ANGLE = 'hinge_max_angle'.freeze
    ATTRIBUTE_HINGE_PIVOT = 'hinge_pivot'.freeze
    ATTRIBUTE_HINGE_PIVOT_APPROXIMATE = 'hinge_pivot_approximate'.freeze
    HINGE_ATTRIBUTES = [ ATTRIBUTE_HINGE_MAX_ANGLE, ATTRIBUTE_HINGE_PIVOT, ATTRIBUTE_HINGE_PIVOT_APPROXIMATE ].freeze
    HINGE_MAX_ANGLE_MAX = 180

    VARIABLE_PATTERN = /@([A-Za-z_]\w*)/
    VARIABLE_NAME_PATTERN = /\A[A-Za-z_]\w*\z/

    # The unit of the bare numbers of its lengths - see "length_unit".
    LENGTH_UNIT = 'length_unit'.freeze

    # The keys of the lengths of a primitive, of a point of its outline and
    # of its head - see with_length_unit.
    PRIMITIVE_LENGTH_KEYS = %w[x y z diameter length width depth from to].freeze
    OUTLINE_LENGTH_KEYS = %w[x y z r].freeze
    HEAD_LENGTH_KEYS = %w[diameter depth].freeze

    # The tool's options that are lengths - or factors : "/2".
    LENGTH_OPTIONS = %w[height start_offset end_offset min_spacing max_spacing].freeze

    # A comparison of two lengths : the tolerance it is checked with, in inches.
    ASSERT_PATTERN = /\A(.+?)(<=|>=|<|>|=)(.+)\z/
    ASSERT_TOLERANCE = 1e-5

    # A solid of primitives - a drilling, a mortise, a cylinder or an oblong
    # - resolved for the measures of where it is laid, its lengths in inches :
    # a slot with round ends along Z, from z_min to z_max, diameter wide
    # along Y and length long along X - a cylinder when length is diameter.
    # profile : when it widens at one end - a round one only - its outline
    # as [ radius, z ] from z_max down to z_min, nil otherwise.
    # axis : AXIS_Y when it goes along Y, AXIS_PRISM_X or AXIS_X_LENGTH_Z
    # for a cylinder or an oblong along X - see SHAPE_FRAMES - nil
    # otherwise - AXIS_Z_LENGTH_Y
    # when it goes along Z and its length along Y : given in the laying
    # frame turned a quarter around Z, a point [ x, y, z ] of it is
    # [ -y, x, z ] in the laying frame. Along Y, it is given in
    # the laying frame turned a quarter around X - its Z along Y - : a point
    # [ x, y, z ] of it is [ x, z, -y ] in the laying frame. AXIS_Y_LENGTH_Z
    # when it goes along Y and its length along Z : given in the laying frame
    # turned so that its X goes along -Z and its Z along Y, a point
    # [ x, y, z ] of it is [ -y, z, -x ] in the laying frame.
    # key : the primitives it is one of - MACHINING_DRILLINGS, … .
    # outline : a prism's - PRISM_KEYS - [ [ u, v, r ] ] corners, r 0
    # when it isn't rounded, see prism_corners. It is extruded along its Z
    # from z_min to z_max, in the frame its axis - nil, AXIS_PRISM_X or
    # AXIS_PRISM_Y - gives, x and y 0, length and diameter the extents of
    # its outline along u and v.
    PrimitiveCylinderDef = Struct.new(:x, :y, :diameter, :z_min, :z_max, :length, :profile, :axis, :key, :outline) do
      def prism?
        !outline.nil?
      end
      def round?
        !prism? && (length.nil? || length <= diameter)
      end
      # Its widest radius
      def radius
        profile.nil? ? diameter / 2 : profile.map(&:first).max
      end
    end

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
    #    'machining' - comes from, another one when the part is linked ;
    #  - articles : its hardware's articles - HardwareArticleDefs, hardware
    #    then nil - or nil when the hardware is a single part.
    HardwareComponentDef = Struct.new(:slot, :source_slot, :hardware, :machining, :mirror, :stretch, :variant, :attributes,
                                      :name, :variant_name, :description, :price, :url, :mass, :part_slots, :articles)

    # An article of a hardware - see "hardware" above :
    #  - key : its key in the slot ;
    #  - name, description, price, url, mass : as written ;
    #  - hardware : its ref String or Hash of primitives - nil for a used one ;
    #  - use : the ref of the connector it uses, nil for its own geometry ;
    #  - descriptor : that connector's HardwareDescriptorDef - its settings
    #    overridden - nil when it can't be read ;
    #  - host : the side of the connector the part is ;
    #  - measures : the expressions of its other side's measures, unsuffixed
    #    - { 'thickness' => '@bracket_thickness' } ;
    #  - at : its positions as written - [ { 'x' => …, 'y' => …, 'z' => … } ] ;
    #  - overrides : the settings of the used connector it overrides, as
    #    written - { 'length' => { 'value' => '18mm' } } ;
    #  - axis : the one of the slot it goes into the part along - AXIS_Z or
    #    AXIS_Y, see "axis".
    HardwareArticleDef = Struct.new(:key, :name, :description, :price, :url, :mass, :hardware, :use, :descriptor, :host, :measures, :at, :overrides, :axis) do
      def use?
        !use.nil?
      end
      # As a component's, for the definition it gives - see HardwareComponentDef
      def attributes
        {}
      end
      # The virtual side of a used connector
      def other_slot
        host == 'a' ? 'b' : 'a'
      end
      # Its positions, evaluated with the given variables : [ [ x, y, z ] ]
      # in inches - nil when one can't be.
      def positions(variables = {})
        items = at.is_a?(Array) ? at : [ {} ]
        items.map { |item|
          return nil unless item.is_a?(Hash)
          ARTICLE_AT_KEYS.map { |k|
            v = item[k].nil? ? 0 : HardwareDescriptorDef.to_length(item[k], true, variables)
            return nil if v.nil?
            v
          }
        }
      end
      # Does it go into the part along Y - by the edge ?
      def along_y?
        axis == AXIS_Y
      end
      # How far the given position - see positions - lifts it off the face
      # it goes in by, toward the outside - negative : sunk in it. Along Z,
      # off the face : its z. Along Y, off the edge - the face given height
      # away toward +Y, or toward -Y when height_reversed, see
      # HardwareDescriptorDef.height_reversed? - nil when height is.
      def lift(position, height = nil, height_reversed = false)
        return position[2] unless along_y?
        return nil if height.nil?
        height_reversed ? -position[1] - height : position[1] - height
      end
      # The measures of the joint of the used connector at a position the
      # given lift off the face it goes in by - see lift : its host side's
      # from the given measures of the slot - unsuffixed, its thicknesses
      # along its axis - less what a negative lift sinks, its other side's
      # evaluated with the given variables. nil when they can't be.
      def joint_measures(slot_measures, variables = {}, lift = 0.0)
        thickness = HardwareDescriptorDef.to_length(measures.is_a?(Hash) ? measures[VARIABLE_THICKNESS] : nil, false, variables)
        return nil if thickness.nil?
        sunk = [ lift.to_f, 0.0 ].min
        joint = {}
        slot_measures.each do |name, value|
          next unless VARIABLES.include?(name.to_s)
          value += sunk if sunk != 0 && !value.nil? && [ VARIABLE_THICKNESS, VARIABLE_THICKNESS_MIN, VARIABLE_THICKNESS_MAX ].include?(name.to_s)
          joint["#{name}_#{host}"] = value
        end
        [ VARIABLE_THICKNESS, VARIABLE_THICKNESS_MIN, VARIABLE_THICKNESS_MAX ].each { |name| joint["#{name}_#{other_slot}"] = thickness }
        joint
      end
      # The given joint measures and the unsuffixed ones of the given side
      # of the used connector - see HardwareDescriptorDef::VARIABLES.
      def side_measures(joint, side)
        own = {}
        joint.each { |name, value| own[name[0..-(side.length + 2)]] = value if name.end_with?("_#{side}") }
        joint.merge(own)
      end
    end

    # data : merged with its parents' - see "extends" ; own_data : as written ;
    # parent_data : its parents' merged, without its own - nil when it
    # extends none.
    attr_reader :path, :ref, :data, :own_data, :parent_data, :errors

    # -- Loading --

    # The descriptor at the given path - absolute, or a '$LIB/…' ref - nil if
    # the file can't be read or isn't a hardware descriptor. An invalid one is
    # returned, see valid? and errors.
    def self.load(ref)
      path = resolve_library_ref(ref)
      return nil unless path.is_a?(String) && File.file?(path)
      ref = library_ref_from_path(path) unless library_ref?(ref)
      data = read_data(path)
      return nil unless descriptor?(data)
      new(data, path, library_ref?(ref) ? ref : nil)
    end

    # The parsed JSON of the given file, nil if it can't be read.
    def self.read_data(path)
      JSON.parse(File.read(path, mode: 'r:UTF-8'))
    rescue JSON::ParserError, SystemCallError
      nil
    end

    # The file of the given '$LIB/…' or '$OCL/…' ref - a path is itself.
    # Tests set library_resolver : a lambda (ref) -> path.
    def self.resolve_library_ref(ref)
      return @library_resolver.call(ref) unless @library_resolver.nil?
      plugin = defined?(PLUGIN) ? PLUGIN : nil
      plugin && plugin.respond_to?(:resolve_library_ref) ? plugin.resolve_library_ref(ref) : ref
    end

    def self.library_ref_from_path(path)
      return nil unless @library_resolver.nil?
      plugin = defined?(PLUGIN) ? PLUGIN : nil
      plugin && plugin.respond_to?(:library_ref_from_path) ? plugin.library_ref_from_path(path) : nil
    end

    class << self
      attr_accessor :library_resolver
    end

    # The ref of the parent the given "extends" names, for a descriptor of
    # the given ref : relative to the root of its library - the user's one
    # when it has no ref, a new descriptor is written there - or a library
    # ref itself. nil if it can't be one.
    def self.parent_ref(extends, ref)
      return nil unless extends.is_a?(String) && !extends.strip.empty?
      return extends if library_ref?(extends)
      return nil if extends.start_with?('/', './', '../') || extends =~ /\A[A-Za-z]:[\\\/]/
      prefix = ref.is_a?(String) ? LIBRARY_REF_PREFIXES.find { |p| ref.start_with?(p) } : nil
      (prefix || LIBRARY_REF_USER_PREFIX) + extends
    end

    # The given JSON text of a descriptor, its "extends" set to the given
    # value - the rest of the text as it is.
    def self.replace_extends(text, value)
      text.sub(/("#{EXTENDS}"\s*:\s*)"(?:[^"\\]|\\.)*"/) { "#{$1}#{JSON.generate(value)}" }
    end

    # The "extends" a descriptor of the given ref writes to name the given
    # parent ref : relative to the root of its library when they share it.
    def self.extends_value(parent_ref, ref)
      prefix = ref.is_a?(String) ? LIBRARY_REF_PREFIXES.find { |p| ref.start_with?(p) } : nil
      !prefix.nil? && parent_ref.start_with?(prefix) ? parent_ref[prefix.length..-1] : parent_ref
    end

    # The descriptors - their refs - that extend the one of the given ref,
    # directly, among the JSON files of the given library folder.
    def self.children_refs(ref, library_dir, library_prefix)
      return [] unless File.directory?(library_dir)
      Dir.glob(File.join(library_dir, '**', '*.json')).map { |path|
        child_ref = library_prefix + path[(library_dir.length + 1)..-1]
        data = read_data(path)
        next nil unless descriptor?(data) && parent_ref(data[EXTENDS], child_ref) == ref
        child_ref
      }.compact.sort
    end

    # The articles of the given components - see "hardware" : yields the
    # slot, the variant - nil if none - the key and the value of each.
    def self.each_article(components)
      return unless components.is_a?(Hash)
      fn_articles = lambda do |slot, variant, value|
        next unless value.is_a?(Hash) && articles?(value[PART_HARDWARE])
        value[PART_HARDWARE].each { |key, article| yield(slot, variant, key, article) if article.is_a?(Hash) }
      end
      components.each do |slot, value|
        next unless value.is_a?(Hash)
        if value['variants'].is_a?(Hash) && value['variants']['items'].is_a?(Hash)
          value['variants']['items'].each { |variant, item| fn_articles.call(slot, variant, item) }
        else
          fn_articles.call(slot, nil, value)
        end
      end
    end

    # The descriptors - their refs - whose articles use the one of the given
    # ref - see "use" - among the JSON files of the given library folder.
    def self.users_refs(ref, library_dir, library_prefix)
      return [] unless File.directory?(library_dir)
      Dir.glob(File.join(library_dir, '**', '*.json')).map { |path|
        user_ref = library_prefix + path[(library_dir.length + 1)..-1]
        next nil if user_ref == ref
        data = read_data(path)
        next nil unless descriptor?(data)
        used = false
        each_article(data['components']) { |_, _, _, article| used ||= parent_ref(article[ARTICLE_USE], user_ref) == ref }
        used ? user_ref : nil
      }.compact.sort
    end

    # The given JSON text of a descriptor, each "use" value of its articles
    # replaced by the one the given block returns for it - kept if nil.
    def self.replace_uses(text)
      text.gsub(/("#{ARTICLE_USE}"\s*:\s*)("(?:[^"\\]|\\.)*")/) do
        match = $~
        value = begin
          JSON.parse("[#{match[2]}]").first
        rescue JSON::ParserError
          nil
        end
        replacement = value.nil? ? nil : yield(value)
        replacement.nil? || replacement == value ? match[0] : "#{match[1]}#{JSON.generate(replacement)}"
      end
    end

    # Is the given parsed JSON a hardware descriptor - of any version ?
    def self.descriptor?(data)
      data.is_a?(Hash) && data['format'] == FORMAT
    end

    def self.library_ref?(value)
      value.is_a?(String) && LIBRARY_REF_PREFIXES.any? { |prefix| value.start_with?(prefix) }
    end

    # Is the given component value an empty slot - null or {} - ?
    def self.empty_component?(value)
      value.nil? || value.is_a?(Hash) && value.empty?
    end

    # Is the given hardware part value an object of articles - see "hardware" ?
    def self.articles?(value)
      value.is_a?(Hash) && !value.empty? && value.values.all? { |article| article.nil? || article.is_a?(Hash) } &&
        (value.keys & (ARTICLE_FIELDS + PRIMITIVES.values.flatten + [ 'same_as' ])).empty?
    end

    # The file name of the given article of the given slot's component - or
    # of its given variant : "a.body.skp", "a.overlay.body.skp".
    def self.article_file_name(slot, variant, key)
      [ slot, variant, key ].compact.join('.') + '.skp'
    end

    # Does a machining along Y of the given slot - 'a', :b - of the given
    # type start on the face -Y leads to, @height away, and go toward +Y -
    # see HEIGHT_REVERSED_TYPES - rather than on the one +Y leads to, toward
    # -Y ?
    def self.height_reversed?(type, slot)
      HEIGHT_REVERSED_TYPES.include?(type) && slot.to_s == HEIGHT_REVERSED_SLOT
    end

    # Is the given resolved part - see HardwareComponentDef#hardware and
    # #machining - given as primitives ?
    def self.primitives?(part)
      part.is_a?(Hash) && PRIMITIVES.values.flatten.any? { |key| part[key].is_a?(Array) }
    end

    # The variables the lengths of the given primitives use - "through"
    # uses thickness_max, a machining along Y height.
    def self.primitive_variables(primitives)
      return [] unless primitives?(primitives)
      names = []
      _primitive_items(primitives).each do |primitive_key, item|
        item.each do |key, value|
          names << VARIABLE_THICKNESS_MAX if key == 'depth' && value == DRILLING_DEPTH_THROUGH
          names << VARIABLE_HEIGHT if key == 'axis' && value == AXIS_Y && PRIMITIVES[PART_MACHINING].include?(primitive_key)
          names.concat(value.scan(VARIABLE_PATTERN).flatten) if value.is_a?(String)
          names.concat(value.values.select { |v| v.is_a?(String) }.flat_map { |v| v.scan(VARIABLE_PATTERN).flatten }) if value.is_a?(Hash)
          if value.is_a?(Array)   # A prism's outline
            value.select { |point| point.is_a?(Hash) }.each do |point|
              names.concat(point.values.select { |v| v.is_a?(String) }.flat_map { |v| v.scan(VARIABLE_PATTERN).flatten })
            end
          end
        end
      end
      names.uniq
    end

    # The solids of the given primitives, resolved for the given variables -
    # { 'thickness' => <inches> } - as PrimitiveCylinderDefs : a drilling
    # goes from the face into the part - or from the one +Y leads to, see
    # PrimitiveCylinderDef#axis - a cylinder from one length to the other
    # along its axis. height_reversed : a machining along Y starts on the
    # face -Y leads to and goes toward +Y - see height_reversed?.
    # Those a length can't be resolved for are left out. nil when it isn't
    # given as primitives.
    def self.primitive_cylinders(primitives, variables = {}, height_reversed = false)
      return nil unless primitives?(primitives)
      variables = Hash[variables.map { |k, v| [ k.to_s, v ] }]
      _primitive_items(primitives).map { |key, item|
        next _primitive_prism(key, item, variables, height_reversed) if PRISM_KEYS.include?(key)
        axis = item['axis'] == AXIS_Y && (key == MACHINING_DRILLINGS || key == MACHINING_MORTISES) ? AXIS_Y : nil
        along_y = !axis.nil?
        if key == MACHINING_MORTISES
          axis = AXIS_Y_LENGTH_Z if axis == AXIS_Y && item['length_axis'] == AXIS_Z
          axis = AXIS_Z_LENGTH_Y if axis.nil? && item['length_axis'] == AXIS_Y
        end
        if key == HARDWARE_CYLINDERS || key == HARDWARE_OBLONGS
          # Placed by the two axes across the one it goes along, an oblong
          # long along the first by default - see SHAPE_FRAMES
          along = PRISM_OUTLINE_KEYS.key?(item['axis']) ? item['axis'] : AXIS_Z
          keys = PRISM_OUTLINE_KEYS[along]
          u, v = keys.map { |k| item[k].nil? ? 0.0 : to_length(item[k], true, variables) }
          next nil if u.nil? || v.nil?
          length_axis = key == HARDWARE_OBLONGS && item['length_axis'] == keys[1] ? keys[1] : keys[0]
          axis, fn_position = SHAPE_FRAMES["#{along}-#{length_axis}"]
          x, y = fn_position.call(u, v)
        elsif !along_y
          x = item['x'].nil? ? 0.0 : to_length(item['x'], true, variables)
          y = item['y'].nil? ? 0.0 : to_length(item['y'], true, variables)
          x, y = y, (x.nil? ? nil : -x) if axis == AXIS_Z_LENGTH_Y
        else
          x = item['x'].nil? ? 0.0 : to_length(item['x'], true, variables)
          z = item['z'].nil? ? 0.0 : to_length(item['z'], true, variables)
          if axis == AXIS_Y_LENGTH_Z
            x, y = (z.nil? ? nil : -z), (x.nil? ? nil : -x)
          else
            y = z.nil? ? nil : -z
          end
        end
        if key == MACHINING_MORTISES || key == HARDWARE_OBLONGS
          diameter = to_length(item['width'], false, variables)
          length = to_length(item['length'], false, variables)
          next nil if length.nil? || !diameter.nil? && length < diameter
        else
          diameter = to_length(item['diameter'], false, variables)
          length = nil
        end
        if along_y
          z_min, z_max = _along_y_range(item, variables, height_reversed)
        elsif key == MACHINING_DRILLINGS || key == MACHINING_MORTISES
          through = variables.key?(VARIABLE_THICKNESS_MAX) ? VARIABLE_THICKNESS_MAX : VARIABLE_THICKNESS
          depth = to_length(item['depth'] == DRILLING_DEPTH_THROUGH ? "@#{through}" : item['depth'], false, variables)
          z_min = depth.nil? ? nil : -depth
          z_max = 0.0
        else
          z_min = to_length(item['from'], true, variables)
          z_max = to_length(item['to'], true, variables)
        end
        next nil if [ x, y, diameter, z_min, z_max ].any?(&:nil?) || z_max <= z_min
        profile = nil
        if (head_key = HEADS.find { |k| item.key?(k) })
          profile = _head_profile(head_key, item[head_key], key == MACHINING_DRILLINGS ? HEAD_FACES : HEAD_ENDS, diameter, z_min, z_max, variables, along_y && height_reversed)
          next nil if profile.nil?
        end
        PrimitiveCylinderDef.new(x, y, diameter, z_min, z_max, length.nil? || length <= diameter ? nil : length, profile, axis, key)
      }.compact
    end

    # A corner of the outline of a prism - see prism_corners - from start
    # to finish along it, [ u, v ] : a point when they are the same, else an
    # arc around center - radius away - of the given signed angle,
    # counterclockwise when positive.
    PrismCornerDef = Struct.new(:start, :finish, :center, :radius, :sweep) do
      def arc?
        !center.nil?
      end
    end

    # The corners of the given outline of a prism - [ [ u, v, r ] ], see
    # PrimitiveCylinderDef#outline - as PrismCornerDefs, counterclockwise.
    # nil when it is flat, crosses or touches itself, or a rounding doesn't
    # fit its two sides.
    def self.prism_corners(outline)
      eps = 1e-6
      fn_same = lambda { |p, q| (p[0] - q[0]).abs < eps && (p[1] - q[1]).abs < eps }
      points = []
      outline.each do |u, v, r|
        point = [ u.to_f, v.to_f, r.to_f ]
        points << point unless !points.empty? && fn_same.call(points.last, point)
      end
      points.pop while points.length > 1 && fn_same.call(points.last, points.first)
      n = points.length
      return nil if n < 3

      area = 0.0
      points.each_with_index do |(u0, v0), i|
        u1, v1 = points[(i + 1) % n]
        area += u0 * v1 - u1 * v0
      end
      return nil if area.abs / 2 < 1e-9
      points.reverse! if area < 0

      n.times do |i|
        (i + 2...n).each do |j|
          next if i == 0 && j == n - 1   # Adjacent across the closing side
          return nil if _segments_touch?(points[i], points[(i + 1) % n], points[j], points[(j + 1) % n], eps)
        end
      end

      tangents = Array.new(n, 0.0)
      corners = points.each_with_index.map { |(u, v, r), i|
        previous = points[i - 1]
        following = points[(i + 1) % n]
        d1 = _unit_vector(previous[0] - u, previous[1] - v)
        d2 = _unit_vector(following[0] - u, following[1] - v)
        cos = d1[0] * d2[0] + d1[1] * d2[1]
        return nil if cos > 1 - 1e-9   # A spike : its two sides along each other
        next PrismCornerDef.new([ u, v ], [ u, v ]) if r < eps || cos < -1 + 1e-9   # Sharp, or on a straight line
        half = Math.acos(cos) / 2
        t = r / Math.tan(half)
        tangents[i] = t
        bisector = _unit_vector(d1[0] + d2[0], d1[1] + d2[1])
        distance = r / Math.sin(half)
        start = [ u + d1[0] * t, v + d1[1] * t ]
        finish = [ u + d2[0] * t, v + d2[1] * t ]
        center = [ u + bisector[0] * distance, v + bisector[1] * distance ]
        sweep = Math.atan2(finish[1] - center[1], finish[0] - center[0]) - Math.atan2(start[1] - center[1], start[0] - center[0])
        sweep -= 2 * Math::PI while sweep > Math::PI
        sweep += 2 * Math::PI while sweep <= -Math::PI
        PrismCornerDef.new(start, finish, center, r, sweep)
      }
      n.times do |i|
        following = points[(i + 1) % n]
        side = Math.hypot(following[0] - points[i][0], following[1] - points[i][1])
        return nil if tangents[i] + tangents[(i + 1) % n] > side + 1e-9
      end
      corners
    end

    # The points along the given corners - see prism_corners - [ [ u, v ] ]
    # counterclockwise : each arc in as many segments as the given block
    # tells for its radius and angle - one per 15° without it.
    def self.prism_points(corners)
      points = []
      corners.each do |corner|
        if corner.arc?
          count = block_given? ? yield(corner.radius, corner.sweep.abs) : (corner.sweep.abs / (Math::PI / 12)).ceil
          count = [ count, 1 ].max
          a0 = Math.atan2(corner.start[1] - corner.center[1], corner.start[0] - corner.center[0])
          (0..count).each do |k|
            a = a0 + corner.sweep * k / count
            points << [ corner.center[0] + corner.radius * Math.cos(a), corner.center[1] + corner.radius * Math.sin(a) ]
          end
        else
          points << corner.start
        end
      end
      # A rounding as long as its side ends where the next one starts
      points.each_with_index.reject { |p, i| q = points[(i + 1) % points.length]; (p[0] - q[0]).abs < 1e-9 && (p[1] - q[1]).abs < 1e-9 }.map(&:first)
    end

    # The given prism - see PRISM_KEYS, key its own - resolved for the given
    # variables as a PrimitiveCylinderDef, nil if it can't be. A pocket goes
    # depth deep from the face - along Z or Y, see AXES - a prism from one
    # length to the other - see primitive_cylinders for height_reversed.
    def self._primitive_prism(key, item, variables, height_reversed = false)
      axis = item['axis'].nil? ? AXIS_Z : item['axis']
      return nil if key == MACHINING_POCKETS && !AXES.include?(axis)
      keys = PRISM_OUTLINE_KEYS[axis]
      points = item['outline']
      return nil if keys.nil? || !points.is_a?(Array) || points.length < 3
      outline = []
      points.each do |point|
        return nil unless point.is_a?(Hash)
        u, v = keys.map { |k| point[k].nil? ? 0.0 : to_length(point[k], true, variables) }
        r = point[PRISM_RADIUS_KEY].nil? ? 0.0 : to_length(point[PRISM_RADIUS_KEY], false, variables)
        return nil if u.nil? || v.nil? || r.nil?
        outline << [ u, v, r ]
      end
      if key != MACHINING_POCKETS
        z_min = to_length(item['from'], true, variables)
        z_max = to_length(item['to'], true, variables)
      elsif axis == AXIS_Y
        z_min, z_max = _along_y_range(item, variables, height_reversed)
      else
        through = variables.key?(VARIABLE_THICKNESS_MAX) ? VARIABLE_THICKNESS_MAX : VARIABLE_THICKNESS
        depth = to_length(item['depth'] == DRILLING_DEPTH_THROUGH ? "@#{through}" : item['depth'], false, variables)
        z_min = depth.nil? ? nil : -depth
        z_max = 0.0
      end
      return nil if z_min.nil? || z_max.nil? || z_max <= z_min
      return nil if prism_corners(outline).nil?
      us = outline.map { |u, _, _| u }
      vs = outline.map { |_, v, _| v }
      internal_axis = axis == AXIS_X ? AXIS_PRISM_X : axis == AXIS_Y ? AXIS_PRISM_Y : nil
      PrimitiveCylinderDef.new(0.0, 0.0, vs.max - vs.min, z_min, z_max, us.max - us.min, nil, internal_axis, key, outline)
    end
    private_class_method :_primitive_prism

    # The [ z_min, z_max ] of the given machining along Y - its Z along Y -
    # resolved for the given variables : from the face height away, toward
    # -Y - or from the one height away toward -Y, toward +Y, when
    # height_reversed, see height_reversed?. nils when it can't be.
    def self._along_y_range(item, variables, height_reversed)
      depth = item['depth'] == DRILLING_DEPTH_THROUGH ? nil : to_length(item['depth'], false, variables)
      height = variables[VARIABLE_HEIGHT].is_a?(Numeric) ? variables[VARIABLE_HEIGHT].to_f : nil
      return [ nil, nil ] if depth.nil? || height.nil?
      height_reversed ? [ -height, -height + depth ] : [ height - depth, height ]
    end
    private_class_method :_along_y_range

    # Do the given segments - [ u, v ] ends - cross or touch, the given
    # distance apart or less ?
    def self._segments_touch?(a, b, c, d, eps)
      fn_side = lambda { |p, q, r| (q[0] - p[0]) * (r[1] - p[1]) - (q[1] - p[1]) * (r[0] - p[0]) }
      fn_near = lambda do |p, q, r|   # r on the segment pq
        length = Math.hypot(q[0] - p[0], q[1] - p[1])
        next Math.hypot(r[0] - p[0], r[1] - p[1]) <= eps if length < eps
        t = ((r[0] - p[0]) * (q[0] - p[0]) + (r[1] - p[1]) * (q[1] - p[1])) / length
        fn_side.call(p, q, r).abs / length <= eps && t >= -eps && t <= length + eps
      end
      s1 = fn_side.call(c, d, a)
      s2 = fn_side.call(c, d, b)
      s3 = fn_side.call(a, b, c)
      s4 = fn_side.call(a, b, d)
      return true if (s1 > 0) != (s2 > 0) && (s3 > 0) != (s4 > 0) && s1 != 0 && s2 != 0 && s3 != 0 && s4 != 0
      fn_near.call(c, d, a) || fn_near.call(c, d, b) || fn_near.call(a, b, c) || fn_near.call(a, b, d)
    end
    private_class_method :_segments_touch?

    def self._unit_vector(x, y)
      length = Math.hypot(x, y)
      [ x / length, y / length ]
    end
    private_class_method :_unit_vector

    # The profile - [ [ radius, z ] ] from z_max down to z_min - of a solid
    # of the given diameter widened by the given head at one end - see
    # HEADS. sides : its names of the top end and of the bottom one - the
    # other way round when reversed. nil if it can't be resolved, or is as
    # long as the solid.
    def self._head_profile(head_key, head, sides, diameter, z_min, z_max, variables, reversed = false)
      return nil unless head.is_a?(Hash)
      r = diameter / 2
      head_diameter = to_length(head['diameter'], false, variables)
      return nil if head_diameter.nil? || head_diameter / 2 <= r
      big_r = head_diameter / 2
      if head_key == HEAD_COUNTERSINK
        angle = head['angle'].nil? ? HEAD_DEFAULT_ANGLE : head['angle']
        return nil unless angle.is_a?(Numeric) && angle > 0 && angle < 180
        height = (big_r - r) / Math.tan(angle * Math::PI / 360)
      else
        height = to_length(head['depth'], false, variables)
        return nil if height.nil?
      end
      return nil if height >= z_max - z_min - 1e-6
      side = head[sides.equal?(HEAD_FACES) ? 'face' : 'end']
      top = (side.nil? || side == sides[0]) != reversed   # Reversed : the face it is laid on at z_min
      if top
        points = head_key == HEAD_COUNTERSINK ? [ [ big_r, z_max ] ] : [ [ big_r, z_max ], [ big_r, z_max - height ] ]
        points + [ [ r, z_max - height ], [ r, z_min ] ]
      else
        points = head_key == HEAD_COUNTERSINK ? [ [ big_r, z_min ] ] : [ [ big_r, z_min + height ], [ big_r, z_min ] ]
        [ [ r, z_max ], [ r, z_min + height ] ] + points
      end
    end
    private_class_method :_head_profile

    # The given length in inches - an expression of literals with a unit and
    # of variables, see LengthExpressionUtils - nil if it isn't one or uses
    # a variable not given. A bare number is a factor, but 0 : the bare
    # numbers of a descriptor got its "length_unit" when it was read - see
    # with_length_unit. 0 is only a length where negative ones are allowed.
    def self.to_length(value, negative_allowed = false, variables = {})
      value = '0' if value.is_a?(Numeric) && value == 0
      return nil unless value.is_a?(String) && !value.strip.empty?
      length = _evaluate_length(value, variables)
      return nil if length.nil? || length <= 0 && !negative_allowed
      length.to_f
    rescue StandardError
      nil
    end

    # The given data - a descriptor file's own, as written - its bare
    # numbers that stand for lengths - JSON numbers too - given the given
    # unit - see "length_unit" and LengthExpressionUtils.with_unit - : a
    # copy. The data itself when unit is none : its lengths bear their unit.
    # What isn't a length expression - "through", "/2" - stays as it is.
    def self.with_length_unit(data, unit)
      return data unless data.is_a?(Hash) && LengthExpressionUtils::LENGTH_UNITS.include?(unit)
      data = Marshal.load(Marshal.dump(data))
      fn_length = lambda do |value|
        text = value.is_a?(Numeric) ? (value == value.to_i ? value.to_i.to_s : value.to_s) : value
        return value unless text.is_a?(String)
        begin
          LengthExpressionUtils.with_unit(text, unit)
        rescue LengthExpressionUtils::LengthExpressionError
          value
        end
      end
      fn_keys = lambda do |hash, keys|
        keys.each { |key| hash[key] = fn_length.call(hash[key]) if hash.key?(key) } if hash.is_a?(Hash)
      end
      fn_primitives = lambda do |primitives|
        _primitive_items(primitives).each do |_, item|
          fn_keys.call(item, PRIMITIVE_LENGTH_KEYS)
          item['outline'].each { |point| fn_keys.call(point, OUTLINE_LENGTH_KEYS) } if item['outline'].is_a?(Array)
          HEADS.each { |head| fn_keys.call(item[head], HEAD_LENGTH_KEYS) }
        end
      end
      fn_component = lambda do |component|
        next unless component.is_a?(Hash)
        attributes = component['attributes']
        if attributes.is_a?(Hash) && attributes[ATTRIBUTE_HINGE_PIVOT].is_a?(Array)
          attributes[ATTRIBUTE_HINGE_PIVOT] = attributes[ATTRIBUTE_HINGE_PIVOT].map { |value| fn_length.call(value) }
        end
        PARTS.each do |part|
          value = component[part]
          next unless value.is_a?(Hash)
          if part == PART_HARDWARE && articles?(value)
            value.each_value do |article|
              next unless article.is_a?(Hash)
              fn_primitives.call(article)
              article[ARTICLE_AT].each { |position| fn_keys.call(position, ARTICLE_AT_KEYS) } if article[ARTICLE_AT].is_a?(Array)
              fn_keys.call(article[ARTICLE_MEASURES], article[ARTICLE_MEASURES].keys) if article[ARTICLE_MEASURES].is_a?(Hash)
              article[ARTICLE_VARIABLES].each_value { |setting| fn_keys.call(setting, [ 'value' ]) } if article[ARTICLE_VARIABLES].is_a?(Hash)
            end
          else
            fn_primitives.call(value)
          end
        end
        variants = component['variants']
        next unless variants.is_a?(Hash) && variants['items'].is_a?(Hash)
        variants['items'].each_value { |item| fn_component.call(item) }
        if variants['select'].is_a?(Hash) && variants['select']['mode'] == SELECT_MODE_MAX_LE   # Its keys are lengths
          variants['items'] = Hash[variants['items'].map { |key, item| [ fn_length.call(key), item ] }]
        end
      end
      if data['variables'].is_a?(Hash)
        data['variables'].each do |name, value|
          if setting?(value)
            fn_keys.call(value, %w[value min max])
            value['steps'] = value['steps'].map { |step| fn_length.call(step) } if value['steps'].is_a?(Array)
          else
            data['variables'][name] = fn_length.call(value)
          end
        end
      end
      if data['asserts'].is_a?(Array)
        data['asserts'] = data['asserts'].map { |expression|
          match = expression.is_a?(String) ? ASSERT_PATTERN.match(expression) : nil
          match.nil? ? expression : fn_length.call(match[1]) + match[2] + fn_length.call(match[3])
        }
      end
      fn_keys.call(data['options'], LENGTH_OPTIONS)
      data['components'].each_value { |component| fn_component.call(component) } if data['components'].is_a?(Hash)
      data
    end

    # The given hinge_pivot attribute - [ "y", "z" ] lengths - as [ y, z ]
    # in inches, nil when it isn't one.
    def self.hinge_pivot(value)
      return nil unless value.is_a?(Array) && value.length == 2 && value.all? { |v| v.is_a?(String) }
      pivot = value.map { |v| to_length(v, true) }
      pivot.any?(&:nil?) ? nil : pivot
    end

    # Is the given hinge_max_angle attribute an opening angle in degrees ?
    def self.hinge_max_angle?(value)
      value.is_a?(Numeric) && value > 0 && value <= HINGE_MAX_ANGLE_MAX
    end

    # Why the given length can't be evaluated for the given variables - see
    # to_length : [ key, params ], the key of LengthExpressionUtils'
    # errors - 'no_matching_value', … - or 'unresolved_variable' { name }
    # when it uses a variable not given, 'not_a_length' when it isn't one.
    # nil when it can.
    def self.length_error(value, negative_allowed = false, variables = {})
      return nil unless to_length(value, negative_allowed, variables).nil?
      if value.is_a?(String) && !value.strip.empty?
        variables = Hash[variables.map { |k, v| [ k.to_s, v ] }]
        missing = value.scan(VARIABLE_PATTERN).flatten.find { |name| !variables[name].is_a?(Numeric) }
        return [ 'unresolved_variable', { :name => missing } ] unless missing.nil?
        begin
          _evaluate_length!(value, variables)
        rescue LengthExpressionUtils::LengthExpressionError => e
          return [ e.key, e.params ]
        rescue ZeroDivisionError
          return [ 'zero_division', {} ]
        end
      end
      [ 'not_a_length', {} ]
    end

    # Does the given comparison - "@depth_b <= @thickness_b - 5mm" - hold
    # for the given variables ? nil if it isn't a comparison of lengths, or
    # uses a variable not given.
    def self.assert?(expression, variables = {})
      left, operator, right = assert_sides(expression, variables)
      return nil if left.nil? || right.nil?
      case operator
      when '<=' then left <= right + ASSERT_TOLERANCE
      when '>=' then left >= right - ASSERT_TOLERANCE
      when '<' then left < right - ASSERT_TOLERANCE
      when '>' then left > right + ASSERT_TOLERANCE
      else (left - right).abs <= ASSERT_TOLERANCE
      end
    end

    # The sides of the given comparison, evaluated for the given variables :
    # [ left, operator, right ], a side nil when it can't be. nil if it isn't
    # a comparison.
    def self.assert_sides(expression, variables = {})
      return nil unless expression.is_a?(String) && (match = ASSERT_PATTERN.match(expression.strip))
      variables = Hash[variables.map { |k, v| [ k.to_s, v ] }]
      [ to_length(match[1].strip, true, variables), match[2], to_length(match[3].strip, true, variables) ]
    end

    # The given variable's expression : a setting's value, or itself - see
    # "variables".
    def self.variable_expression(value)
      value.is_a?(Hash) ? value['value'] : value
    end

    # Is the given variable a setting - see "variables" ?
    def self.setting?(value)
      value.is_a?(Hash)
    end

    # [ [ primitive key, item Hash ] ] of the given primitives.
    def self._primitive_items(primitives)
      PRIMITIVES.values.flatten.flat_map { |key|
        items = primitives[key]
        items.is_a?(Array) ? items.select { |item| item.is_a?(Hash) }.map { |item| [ key, item ] } : []
      }
    end
    private_class_method :_primitive_items

    # The value of the given length expression in inches - "@thickness -
    # 2mm" - nil if it can't be read, isn't a length, or uses a variable not
    # given. Unlike the VCB, a bare number is a factor : a descriptor can't
    # depend on the units of the model it is used in - see "length_unit".
    def self._evaluate_length(expression, variables)
      _evaluate_length!(expression, variables)
    rescue LengthExpressionUtils::LengthExpressionError, ZeroDivisionError
      nil
    end
    private_class_method :_evaluate_length

    # As _evaluate_length, raising LengthExpressionUtils::LengthExpressionError
    # instead of returning nil.
    def self._evaluate_length!(expression, variables)
      value, dimension = LengthExpressionUtils.evaluate(
        expression,
        read_literal: lambda { |literal|
          next [ LengthExpressionUtils.bare_number_value(literal), 0 ] if LengthExpressionUtils.bare_number?(literal)
          [ LengthExpressionUtils.literal_to_inches(literal), 1 ]
        },
        read_variable: lambda { |name|
          value = variables[name]
          raise LengthExpressionUtils::LengthExpressionError.new('syntax_error') unless value.is_a?(Numeric)
          [ value.to_f, 1 ]
        }
      )
      raise LengthExpressionUtils::LengthExpressionError.new('invalid_dimension') unless dimension == 1 || value == 0   # A bare 0 is a length
      raise LengthExpressionUtils::LengthExpressionError.new('zero_division') unless value.finite?
      value
    end
    private_class_method :_evaluate_length!

    # The file name of the given part of the given slot's component - or of
    # its given variant : "a.skp", "a.overlay.machining.skp".
    def self.part_file_name(slot, variant, part)
      [ slot, variant, part == PART_MACHINING ? PART_MACHINING : nil ].compact.join('.') + '.skp'
    end

    # path : the file the descriptor was read from ; ref : its '$LIB/…' or
    # '$OCL/…' ref when it lives in a library - its parts are then refs of
    # that library.
    def initialize(data, path = nil, ref = nil)
      @own_data = data
      @path = path
      @ref = ref
      @parent_refs = []
      @sources = path.is_a?(String) && File.file?(path) ? [ [ path, File.mtime(path) ] ] : []
      @inheritance_errors = []
      @parent_data = nil
      @data = _inherit(data)
      @errors = _validate
    end

    # -- Accessors --

    def valid?
      @errors.empty?
    end

    # Is it only there to be extended - see "abstract" ?
    def abstract?
      @own_data.is_a?(Hash) && @own_data[ABSTRACT] == true
    end

    # The refs of its parents, the nearest first - see "extends".
    def parent_refs
      @parent_refs.dup
    end

    # Has one of the files it was read from - its own, its parents' - changed
    # since ?
    def stale?
      @sources.any? { |path, mtime| !File.file?(path) || File.mtime(path) != mtime }
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

    # The measures its lengths can use - see VARIABLES.
    def measures
      return VARIABLES unless JOIN_TYPES.include?(type)
      VARIABLES + VARIABLES.flat_map { |name| slots.map { |slot| "#{name}_#{slot}" } }
    end

    # The measures its lengths - of primitives, variables and asserts - use :
    # the ones the tool has to take.
    def used_measures
      @used_measures ||= begin
        text = JSON.generate(@data)
        names = text.scan(VARIABLE_PATTERN).flatten
        names << VARIABLE_THICKNESS_MAX if text.include?("\"#{DRILLING_DEPTH_THROUGH}\"")
        names << VARIABLE_HEIGHT if _along_y_machining?(@data)
        measures & names
      end
    end

    # Its own variables : { name => length expression }, in order - a
    # setting's value for a setting.
    def variables
      return {} unless @data['variables'].is_a?(Hash)
      Hash[@data['variables'].map { |name, value| [ name, self.class.variable_expression(value) ] }]
    end

    # Its settings - the variables given as objects : { name => { 'value' =>
    # …, 'label' => …, 'steps' | 'min' / 'max' => … } }, in order.
    def settings
      return {} unless @data['variables'].is_a?(Hash)
      @data['variables'].select { |_, value| self.class.setting?(value) }
    end

    # Its asserts : the comparisons of lengths the measures must satisfy.
    def asserts
      @data['asserts'].is_a?(Array) ? @data['asserts'] : []
    end

    # The given measures - { 'thickness' => <inches>, … } - completed by its
    # variables, in inches. A variable that can't be evaluated is left out.
    def resolve_variables(measures)
      resolved = Hash[measures.map { |k, v| [ k.to_s, v ] }]
      expressions = variables
      _variable_order.first.each do |name|
        value = self.class.to_length(expressions[name], true, resolved)
        resolved[name] = value unless value.nil?
      end
      resolved
    end

    # Its asserts that fail - or can't be evaluated - for the given resolved
    # variables - see resolve_variables.
    def failed_asserts(variables)
      asserts.reject { |expression| self.class.assert?(expression, variables) }
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
      self.class.components_dir_ref(@path, @ref)
    end

    def self.components_dir_ref(path, ref)
      if ref.is_a?(String)
        prefix = LIBRARY_REF_PREFIXES.find { |p| ref.start_with?(p) }
        relative = ref[prefix.length..-1]
        return prefix + COMPONENTS_DIR_NAME + '/' + relative.sub(/#{Regexp.escape(File.extname(relative))}\z/, '')
      end
      return nil unless path.is_a?(String)
      File.join(File.dirname(path), File.basename(path, File.extname(path)))
    end

    # -- Resolution --

    # The component of the given slot, resolved for the given context - the
    # measures the tool took, keyed by the "by" of the variants they select :
    # { 'hinge_kind' => 'inset', 'depth' => <Length>, … }. nil when the slot is
    # empty, or no variant fits.
    def resolve_component(slot, context = {})
      _resolve_component(slot.to_s, _stringify_keys(context), false, [])
    end

    # The key of the variant of the given slot's own component the given
    # context selects - see resolve_component - even when it is empty and
    # the component then nil. nil when it has no variants, or none fits.
    def selected_variant(slot, context = {})
      components = @data['components']
      value = components.is_a?(Hash) ? components[slot.to_s] : nil
      return nil unless value.is_a?(Hash) && value.key?('variants')
      _select_variant(value['variants'], _stringify_keys(context))
    end

    # -----

    private

    # Its variables in the order of their dependencies, and those that depend
    # on each other - left out : [ [ names ], [ cycle names ] ]. A variable
    # that isn't one - a name or a length - comes in its written place.
    def _variable_order
      @variable_order ||= begin
        expressions = variables
        dependencies = Hash[expressions.map { |name, expression|
          [ name, expression.is_a?(String) ? expression.scan(VARIABLE_PATTERN).flatten.uniq & expressions.keys - [ name ] : [] ]
        }]
        self_cycles = expressions.select { |name, expression| expression.is_a?(String) && expression.scan(VARIABLE_PATTERN).flatten.include?(name) }.keys
        order = []
        cycles = self_cycles.dup
        states = {}   # name => :visiting | :done
        fn_visit = lambda do |name, stack|
          return if states[name] == :done
          if states[name] == :visiting
            cycles.concat(stack[stack.index(name)..-1])
            return
          end
          states[name] = :visiting
          dependencies[name].each { |dependency| fn_visit.call(dependency, stack + [ name ]) }
          states[name] = :done
          order << name
        end
        expressions.keys.each { |name| fn_visit.call(name, []) }
        cycles.uniq!
        # What depends on a cycle can't be evaluated either, it stays in order
        [ order - cycles, cycles ]
      end
    end

    # -- Inheritance --

    # The given data merged with the one of its parents - see "extends".
    def _inherit(own)
      return self.class.with_length_unit(own, own.is_a?(Hash) ? own[LENGTH_UNIT] : nil) unless own.is_a?(Hash) && own.key?(EXTENDS)
      parent = _ancestor_data(own[EXTENDS], @ref, @ref.nil? ? [] : [ @ref ], 1)
      return self.class.with_length_unit(own, own[LENGTH_UNIT]) if parent.nil?   # Invalid, see @inheritance_errors
      @parent_data = parent
      _merge_descriptor(parent, self.class.with_length_unit(own, own[LENGTH_UNIT] || parent[LENGTH_UNIT]))
    end

    # The data of the ancestor the given "extends" of a descriptor of the
    # given ref names, merged with its own ancestors', its parts and refs
    # made its own - see _localize. nil if it can't be read.
    def _ancestor_data(extends, child_ref, visited, depth)
      ref = self.class.parent_ref(extends, child_ref)
      if ref.nil?
        @inheritance_errors << "extends #{extends.inspect} is not a descriptor path"
        return nil
      end
      if child_ref.is_a?(String) && child_ref.start_with?(LIBRARY_REF_BUNDLED_PREFIX) && ref.start_with?(LIBRARY_REF_USER_PREFIX)
        @inheritance_errors << "extends #{ref} : the OCL library can't extend the user's one"
        return nil
      end
      if visited.include?(ref)
        @inheritance_errors << "extends #{ref} : inheritance cycle"
        return nil
      end
      if depth > MAX_INHERITANCE_DEPTH
        @inheritance_errors << "extends #{ref} : more than #{MAX_INHERITANCE_DEPTH} levels"
        return nil
      end
      path = self.class.resolve_library_ref(ref)
      data = path.is_a?(String) && File.file?(path) ? self.class.read_data(path) : nil
      unless self.class.descriptor?(data)
        @inheritance_errors << "extends #{ref} : parent not found"
        return nil
      end
      @parent_refs << ref
      @sources << [ path, File.mtime(path) ]
      data = _localize(data, path, ref)
      return self.class.with_length_unit(data, data[LENGTH_UNIT]) unless data.key?(EXTENDS)
      grand_parent = _ancestor_data(data[EXTENDS], ref, visited + [ ref ], depth + 1)
      return nil if grand_parent.nil?
      _merge_descriptor(grand_parent, self.class.with_length_unit(data, data[LENGTH_UNIT] || grand_parent[LENGTH_UNIT]))
    end

    # The given data of an ancestor read from the given file, what it names
    # relatively - parts declared true, shared files, './' refs - made refs
    # of its own place : they stay its own once inherited.
    def _localize(data, path, ref)
      data = Marshal.load(Marshal.dump(data))
      dir_ref = self.class.components_dir_ref(path, ref)
      prefix = LIBRARY_REF_PREFIXES.find { |p| ref.start_with?(p) }
      fn_ref = lambda do |value|
        return value unless value.is_a?(String) && value.start_with?('./')
        File.join(File.dirname(ref), value[2..-1])
      end
      fn_part = lambda do |slot, variant, part, value|
        return "#{dir_ref}/#{self.class.part_file_name(slot, variant, part)}" if value == true
        return value unless value.is_a?(String) && !value.strip.empty?
        return fn_ref.call(value) if value.start_with?('./')
        return value if self.class.library_ref?(value) || File.extname(value).downcase != '.skp'
        prefix + COMPONENTS_DIR_NAME + '/' + value
      end
      fn_component = lambda do |slot, variant, value|
        return unless value.is_a?(Hash)
        if self.class.articles?(value[PART_HARDWARE])
          value[PART_HARDWARE].each do |key, article|
            next unless article.is_a?(Hash)
            if article[ARTICLE_SKP] == true
              article[ARTICLE_SKP] = "#{dir_ref}/#{self.class.article_file_name(slot, variant, key)}"
            elsif article.key?(ARTICLE_SKP)
              article[ARTICLE_SKP] = fn_part.call(slot, variant, PART_HARDWARE, article[ARTICLE_SKP])
            end
            used = self.class.parent_ref(article[ARTICLE_USE], ref)   # Relative to its own library
            article[ARTICLE_USE] = used unless used.nil?
          end
          fn_part_keys = [ PART_MACHINING ]
        else
          fn_part_keys = PARTS
        end
        fn_part_keys.each { |part| value[part] = fn_part.call(slot, variant, part, value[part]) if value.key?(part) }
      end
      material = data['hardware_material']
      data['hardware_material'] = File.join(File.dirname(path), material[2..-1]) if material.is_a?(String) && material.start_with?('./')   # As _resolve_ref
      if data['components'].is_a?(Hash)
        data['components'].each do |slot, value|
          next unless value.is_a?(Hash)
          fn_component.call(slot, nil, value)
          next unless value['variants'].is_a?(Hash) && value['variants']['items'].is_a?(Hash)
          value['variants']['items'].each { |variant, item| fn_component.call(slot, variant, item) }
        end
      end
      data
    end

    # The given own data merged into the given parent's - see "extends".
    def _merge_descriptor(parent, own)
      if own.key?('type') && parent.key?('type') && own['type'] != parent['type']
        @inheritance_errors << "type #{own['type'].inspect} differs from its parent's #{parent['type'].inspect}"
      end
      if own.key?(LENGTH_UNIT) && parent.key?(LENGTH_UNIT) && own[LENGTH_UNIT] != parent[LENGTH_UNIT]
        @inheritance_errors << "length_unit #{own[LENGTH_UNIT].inspect} differs from its parent's #{parent[LENGTH_UNIT].inspect}"
      end
      merged = _merge(parent.reject { |key, _| OWN_KEYS.include?(key) }, own.reject { |key, _| OWN_KEYS.include?(key) }, [])
      result = {}
      OWN_KEYS.each { |key| result[key] = own[key] if own.key?(key) }
      result.merge(merged)
    end

    # JSON Merge Patch of the given own value into the given parent's - with
    # "@super" and null variants, see "extends". path : the keys down to them.
    def _merge(parent, own, path)
      if own.is_a?(Hash)
        parent = {} unless parent.is_a?(Hash)
        variants = path.length >= 2 && path[-2..-1] == %w[variants items]   # null is "unsupported" there
        result = {}
        parent.each { |key, value| result[key] = value unless own.key?(key) && own[key].nil? && !variants }
        own.each do |key, value|
          if value.nil?
            result[key] = nil if variants
            next
          end
          result[key] = path == [ 'variables' ] ? _merge_variable(key, parent[key], value) : _merge(parent[key], value, path + [ key ])
        end
        result
      elsif own.is_a?(Array)
        count = own.count(SUPER_ELEMENT)
        @inheritance_errors << "#{path.join('/')} has #{SUPER_ELEMENT} more than once" if count > 1
        return own if count == 0
        own.flat_map { |value| value == SUPER_ELEMENT ? (parent.is_a?(Array) ? parent : []) : [ value ] }
      else
        own
      end
    end

    # The given variable redefined : "@super" in its expression is the
    # parent's, in parentheses.
    def _merge_variable(name, parent, own)
      return _merge(parent, own, [ 'variables', name ]) if own.is_a?(Hash)
      return own unless own.is_a?(String) && own =~ SUPER_PATTERN
      expression = self.class.variable_expression(parent)
      expression = expression.to_s if expression.is_a?(Numeric)
      unless expression.is_a?(String) && !expression.strip.empty?
        @inheritance_errors << "variable '#{name}' uses @#{SUPER} but its parent has no such variable"
        return own
      end
      own.gsub(SUPER_PATTERN) { "(#{expression})" }
    end

    def _resolve_component(slot, context, mirror, visited)
      return nil if visited.include?(slot)   # Cycle
      visited = visited + [ slot ]
      components = @data['components']
      return nil unless components.is_a?(Hash)
      _resolve_value(slot, components[slot], context, mirror, visited)
    end

    # slot : the one whose component value is - the source slot.
    def _resolve_value(slot, value, context, mirror, visited, variant = nil, attributes = {}, info = {})
      return nil unless value.is_a?(Hash) && !value.empty?
      attributes = attributes.merge(value['attributes']) if value['attributes'].is_a?(Hash)
      if value.key?('same_as')
        resolved = _resolve_component(value['same_as'].to_s, context, mirror, visited)
      elsif value.key?('mirror_of')
        resolved = _resolve_component(value['mirror_of'].to_s, context, !mirror, visited)
      elsif value.key?('variants')
        key = _select_variant(value['variants'], context)
        return nil if key.nil?
        info = info.merge(_info(value))
        return _resolve_value(slot, value['variants']['items'][key], context, mirror, visited, key, attributes, info)
      else
        own_info = _info(value)
        merged_info = info.merge(own_info)   # The variant's over the component's
        hardware, hardware_slot, articles = _resolve_part(slot, variant, PART_HARDWARE, value[PART_HARDWARE], context, visited)
        machining, machining_slot = _resolve_part(slot, variant, PART_MACHINING, value[PART_MACHINING], context, visited)
        return HardwareComponentDef.new(
          slot, slot,
          hardware, machining,
          mirror, value['stretch'], variant, attributes,
          variant.nil? ? own_info['name'] : info['name'],
          variant.nil? ? nil : own_info['name'],
          merged_info['description'], merged_info['price'], merged_info['url'], merged_info['mass'],
          { PART_HARDWARE => hardware_slot, PART_MACHINING => machining_slot },
          articles
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
    # given variant - nil when there is none, the slot whose component the
    # part comes from, and its articles - nil when it isn't made of some :
    # [ ref, slot, articles ].
    def _resolve_part(slot, variant, part, value, context, visited)
      if value.is_a?(Hash) && value.key?('same_as')
        resolved = _resolve_component(value['same_as'].to_s, context, false, visited)
        return [ nil, nil, nil ] if resolved.nil?
        articles = part == PART_HARDWARE ? resolved.articles : nil
        return [ resolved.send(part), resolved.part_slots[part], articles ]
      end
      if part == PART_HARDWARE && self.class.articles?(value)
        articles = _resolve_articles(slot, variant, value)
        return [ nil, articles.empty? ? nil : slot, articles ]
      end
      ref = _resolve_part_ref(slot, variant, part, value)
      [ ref, ref.nil? ? nil : slot, nil ]
    end

    # The articles of the given slot's component - or of its given variant -
    # see "hardware" : HardwareArticleDefs, in order.
    def _resolve_articles(slot, variant, value)
      value.map { |key, article|
        next nil unless article.is_a?(Hash)
        info = _info(article)
        if article.key?(ARTICLE_USE)
          used = self.class.parent_ref(article[ARTICLE_USE], @ref)
          host = article[ARTICLE_HOST].to_s
          measures = article[ARTICLE_MEASURES].is_a?(Hash) ? Hash[article[ARTICLE_MEASURES].map { |name, expression| [ name.sub(/_[ab]\z/, ''), expression ] }] : {}
          HardwareArticleDef.new(key, info['name'], info['description'], info['price'], info['url'], info['mass'],
                                 nil, used, _used_descriptor(used, article[ARTICLE_VARIABLES]), host, measures, article[ARTICLE_AT],
                                 article[ARTICLE_VARIABLES].is_a?(Hash) ? article[ARTICLE_VARIABLES] : {}, article[ARTICLE_AXIS] == AXIS_Y ? AXIS_Y : AXIS_Z)
        else
          geometry = article[ARTICLE_SKP] == true ? true : article[ARTICLE_SKP]
          geometry = article.select { |k, _| PRIMITIVES[PART_HARDWARE].include?(k) } if geometry.nil?
          hardware = geometry == true ? _resolve_article_file(slot, variant, key) : _resolve_part_ref(slot, variant, PART_HARDWARE, geometry)
          HardwareArticleDef.new(key, info['name'], info['description'], info['price'], info['url'], info['mass'],
                                 hardware, nil, nil, nil, nil, article[ARTICLE_AT])
        end
      }.compact
    end

    def _resolve_article_file(slot, variant, key)
      dir = components_dir_ref
      dir.nil? ? nil : "#{dir}/#{self.class.article_file_name(slot, variant, key)}"
    end

    # The connector of the given ref, the VALUES of its settings overridden
    # by the given variables - see "hardware" - nil when it can't be read.
    def _used_descriptor(ref, overrides)
      return nil unless ref.is_a?(String)
      @used_descriptors ||= {}
      cache_key = [ ref, overrides ].to_s
      return @used_descriptors[cache_key] if @used_descriptors.key?(cache_key)
      @used_descriptors[cache_key] = begin
        if @ref.is_a?(String) && @ref.start_with?(LIBRARY_REF_BUNDLED_PREFIX) && ref.start_with?(LIBRARY_REF_USER_PREFIX)
          nil   # The OCL library can't use the user's one
        else
          used = self.class.load(ref)
          if !used.nil? && overrides.is_a?(Hash) && !overrides.empty?
            # A child of it, its own variables the overrides
            data = { 'format' => FORMAT, 'version' => VERSION, 'id' => used.id, 'name' => used.name, 'type' => used.type, EXTENDS => ref, 'variables' => overrides }
            used = self.class.new(data)   # No ref : it would extend itself
          end
          used
        end
      end
    end

    def _resolve_part_ref(slot, variant, part, value)
      if value == true
        dir = components_dir_ref
        return nil if dir.nil?
        return "#{dir}/#{self.class.part_file_name(slot, variant, part)}"
      end
      return value.empty? ? nil : value if value.is_a?(Hash)   # Primitives - none yet when empty
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
      self.class.to_length(key.to_s, true)
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
      errors << 'missing name' unless @data['name'].is_a?(String) && !@data['name'].empty?
      errors << 'extends is not a string' if @own_data.key?(EXTENDS) && !@own_data[EXTENDS].is_a?(String)
      errors << 'abstract is not true or false' if @own_data.key?(ABSTRACT) && @own_data[ABSTRACT] != true && @own_data[ABSTRACT] != false
      errors.concat(@inheritance_errors)
      return errors if abstract?   # Only validated merged into a child
      errors << "unknown type #{@data['type'].inspect}" unless TYPES.key?(@data['type'])
      if @data.key?(LENGTH_UNIT) && !LengthExpressionUtils::LENGTH_UNITS.include?(@data[LENGTH_UNIT])
        errors << "length_unit #{@data[LENGTH_UNIT].inspect} is none of #{LengthExpressionUtils::LENGTH_UNITS.join(', ')}"
      end
      %w[supplier url].each do |key|
        errors << "#{key} is not a string" if @data.key?(key) && !@data[key].nil? && !@data[key].is_a?(String)
      end

      _validate_variables(errors)

      components = @data['components']
      if components.is_a?(Hash)
        components.each do |slot, value|
          errors << "unknown slot '#{slot}'" unless slots.include?(slot)
          _validate_component(slot, value, errors)
        end
        errors << 'no component' if TYPES.key?(@data['type']) && slots.all? { |slot| self.class.empty_component?(components[slot]) }
      else
        errors << 'missing components'
      end

      _validate_asserts(errors)

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

    # Sets the names the lengths can use and the values they are checked
    # with - see _to_checked_length.
    def _validate_variables(errors)
      @checked_variables = Hash[measures.map { |name| [ name, 18 / 25.4 ] }]
      @variable_names = measures.dup
      return unless @data.key?('variables')
      unless @data['variables'].is_a?(Hash)
        errors << 'variables is not an object'
        return
      end
      names = @data['variables'].keys.select { |name| name =~ VARIABLE_NAME_PATTERN && name != SUPER && !measures.include?(name) }
      @variable_names.concat(names)   # Known everywhere, even if it can't be evaluated
      @data['variables'].each do |name, expression|
        label = "variable '#{name}'"
        if name !~ VARIABLE_NAME_PATTERN
          errors << "#{label} is not a valid name"
        elsif name == SUPER
          errors << "#{label} is a reserved name"
        elsif measures.include?(name)
          errors << "#{label} is a measure"
        elsif self.class.setting?(expression)
          _validate_setting(label, expression, errors)
        end
      end
      order, cycles = _variable_order
      if cycles.length == 1
        errors << "variable '#{cycles.first}' depends on itself"
      elsif cycles.length > 1
        errors << "variables #{cycles.map { |name| "'#{name}'" }.join(', ')} depend on each other"
      end
      order.each do |name|
        next unless names.include?(name)
        label = "variable '#{name}'"
        expression = self.class.variable_expression(@data['variables'][name])
        unless expression.is_a?(String) || expression.is_a?(Numeric)
          errors << "#{label} is not a length" unless self.class.setting?(@data['variables'][name])   # Its setting says why
          next
        end
        unknown = _unknown_variables(expression)
        unknown.each do |unknown_name|
          errors << "#{label} uses the unknown variable @#{unknown_name}"
        end
        value = self.class.to_length(expression, true, @checked_variables)
        # One of its dependencies not evaluated has its own error
        dependencies = expression.is_a?(String) ? expression.scan(VARIABLE_PATTERN).flatten : []
        errors << "#{label} is not a length" if value.nil? && unknown.empty? && dependencies.all? { |dependency| @checked_variables.key?(dependency) }
        @checked_variables[name] = value unless value.nil?
      end
    end

    # A setting - see "variables" - : its value is checked as a variable's,
    # after this.
    def _validate_setting(label, setting, errors)
      plain = lambda { |value| !value.nil? && !(value.is_a?(String) && (value =~ VARIABLE_PATTERN || LengthExpressionUtils.functions?(value))) }
      fn_length = lambda { |value| plain.call(value) ? self.class.to_length(value, true) : nil }
      unless setting.key?('value')
        errors << "#{label} has no value"
        return
      end
      value = fn_length.call(setting['value'])
      errors << "#{label} value is not a plain length" if value.nil? && !plain.call(setting['value'])
      errors << "#{label} label is not a string" if setting.key?('label') && !setting['label'].is_a?(String)
      if setting.key?('steps') && (setting.key?('min') || setting.key?('max'))
        errors << "#{label} has both steps and min / max"
        return
      end
      if setting.key?('steps')
        steps = setting['steps'].is_a?(Array) ? setting['steps'].map { |step| fn_length.call(step) } : [ nil ]
        if steps.empty? || steps.any?(&:nil?)
          errors << "#{label} steps are not a list of plain lengths"
        elsif !value.nil? && steps.none? { |step| (step - value).abs <= ASSERT_TOLERANCE }
          errors << "#{label} value is not one of its steps"
        end
      end
      bounds = %w[min max].map { |key|
        next nil unless setting.key?(key)
        bound = fn_length.call(setting[key])
        errors << "#{label} #{key} is not a plain length" if bound.nil?
        bound
      }
      min, max = bounds
      if !min.nil? && !max.nil? && min > max + ASSERT_TOLERANCE
        errors << "#{label} min is above max"
      elsif !value.nil? && (!min.nil? && value < min - ASSERT_TOLERANCE || !max.nil? && value > max + ASSERT_TOLERANCE)
        errors << "#{label} value is out of min / max"
      end
    end

    def _validate_asserts(errors)
      return unless @data.key?('asserts')
      unless @data['asserts'].is_a?(Array)
        errors << 'asserts is not a list'
        return
      end
      @data['asserts'].each_with_index do |expression, index|
        label = "assert #{index + 1}"
        unless expression.is_a?(String) && expression =~ ASSERT_PATTERN
          errors << "#{label} is not a comparison"
          next
        end
        unknown = _unknown_variables(expression)
        unknown.each do |name|
          errors << "#{label} uses the unknown variable @#{name}"
        end
        errors << "#{label} is not a comparison of lengths" if unknown.empty? && self.class.assert?(expression, @checked_variables).nil?
      end
    end

    # The variables the given expression uses that are neither measures nor
    # variables declared above.
    def _unknown_variables(expression)
      return [] unless expression.is_a?(String)
      (expression.scan(VARIABLE_PATTERN).flatten - @variable_names).uniq
    end

    # path : the slot, then the variant's key - 'a', 'a/inset'.
    def _validate_component(path, value, errors)
      return if self.class.empty_component?(value)
      unless value.is_a?(Hash)
        errors << "component '#{path}' is not an object"
        return
      end
      _validate_attributes(path, value['attributes'], errors) if value.key?('attributes')
      _validate_info(path, value, errors)
      errors << "component '#{path}' has z_offset, no more supported : give its hardware as an article, shifted by its \"at\"" if value.key?(Z_OFFSET)
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
      if part == PART_HARDWARE && self.class.articles?(value)
        _validate_articles(path, value, errors)
        return true
      end
      if value.is_a?(Hash)
        _validate_primitives(path, part, value, errors)
        return true
      end
      errors << "component '#{path}' #{part} is neither true, a path nor a link"
      true
    end

    # The articles of a hardware - see "hardware".
    def _validate_articles(path, articles, errors)
      articles.each do |key, article|
        label = "component '#{path}' article '#{key}'"
        errors << "#{label} key is not made of lowercase letters, digits, - and _" unless key =~ ARTICLE_KEY_PATTERN
        next if article.nil?   # Removed from an inherited one
        unless article.is_a?(Hash)
          errors << "#{label} is not an object"
          next
        end
        (article.keys - ARTICLE_FIELDS).each do |k|
          errors << "#{label} has an unknown key '#{k}'"
        end
        _validate_info("#{path}/#{key}", article, errors)
        primitives = article.select { |k, _| PRIMITIVES[PART_HARDWARE].include?(k) }
        geometries = [ article.key?(ARTICLE_USE), article.key?(ARTICLE_SKP), !primitives.empty? ].count(true)
        if geometries == 0
          errors << "#{label} has no geometry - skp, primitives or use"
        elsif geometries > 1
          errors << "#{label} has more than one geometry - skp, primitives or use"
        end
        if article.key?(ARTICLE_SKP) && !(article[ARTICLE_SKP] == true || article[ARTICLE_SKP].is_a?(String) && !article[ARTICLE_SKP].strip.empty?)
          errors << "#{label} skp is neither true nor a path"
        end
        _validate_primitives("#{path}/#{key}", PART_HARDWARE, primitives, errors) unless primitives.empty?
        if article.key?(ARTICLE_USE)
          _validate_used(label, article, errors)
        else
          (article.keys & (ARTICLE_USE_KEYS - [ ARTICLE_USE ])).each do |k|
            errors << "#{label} has '#{k}' but uses no connector"
          end
        end
        _validate_at(label, article[ARTICLE_AT], errors) if article.key?(ARTICLE_AT)
      end
    end

    # An article using a connector - see "use".
    def _validate_used(label, article, errors)
      errors << "#{label} : a connector can't use another hardware" if type == TYPE_CONNECTOR
      ref = self.class.parent_ref(article[ARTICLE_USE], @ref)
      if ref.nil?
        errors << "#{label} use #{article[ARTICLE_USE].inspect} is not a descriptor path"
        return
      end
      used = _used_descriptor(ref, nil)
      if used.nil?
        errors << (@ref.is_a?(String) && @ref.start_with?(LIBRARY_REF_BUNDLED_PREFIX) && ref.start_with?(LIBRARY_REF_USER_PREFIX) ? "#{label} uses #{ref} : the OCL library can't use the user's one" : "#{label} uses #{ref} : not found")
        return
      end
      unless used.type == TYPE_CONNECTOR
        errors << "#{label} uses #{ref} : a #{used.type}, not a connector"
        return
      end
      errors << "#{label} uses #{ref} : it is abstract" if used.abstract?
      errors << "#{label} uses #{ref} : #{used.errors.first}" unless used.abstract? || used.valid?
      host = article[ARTICLE_HOST]
      unless %w[a b].include?(host)
        errors << "#{label} host is neither \"a\" nor \"b\""
        return
      end
      axis = article[ARTICLE_AXIS]
      errors << "#{label} axis is neither #{AXES.map(&:inspect).join(' nor ')}" if article.key?(ARTICLE_AXIS) && !AXES.include?(axis)
      other = host == 'a' ? 'b' : 'a'
      measure = "#{VARIABLE_THICKNESS}_#{other}"
      measures = article[ARTICLE_MEASURES]
      if !measures.is_a?(Hash) || !measures.key?(measure)
        errors << "#{label} measures has no #{measure} - the thickness of its virtual side"
      end
      if measures.is_a?(Hash)
        measures.each do |name, expression|
          if name != measure
            errors << "#{label} measures has the unknown measure '#{name}'"
            next
          end
          unknown = _unknown_variables(expression)
          unknown.each { |n| errors << "#{label} #{name} uses the unknown variable @#{n}" }
          errors << "#{label} #{name} is not a positive length" if unknown.empty? && _to_checked_length(expression, false).nil?
        end
      elsif article.key?(ARTICLE_MEASURES)
        errors << "#{label} measures is not an object"
      end
      overrides = article[ARTICLE_VARIABLES]
      if article.key?(ARTICLE_VARIABLES)
        if overrides.is_a?(Hash)
          settings = used.settings
          overrides.each do |name, value|
            if !settings.key?(name)
              errors << "#{label} variable '#{name}' is not a setting of #{used.name}"
            elsif !(value.is_a?(Hash) && value.keys == [ 'value' ])
              errors << "#{label} variable '#{name}' overrides more than its value"
            end
          end
          # Its own checks of the overridden settings - the rest is the connector's
          overridden = _used_descriptor(ref, overrides)
          unless overridden.nil?
            overridden.errors.select { |error| overrides.keys.any? { |name| error.start_with?("variable '#{name}' ") } }.each do |error|
              errors << "#{label} #{error}"
            end
          end
        else
          errors << "#{label} variables is not an object"
        end
      end
      component = used.resolve_component(host)
      if !component.nil? && component.machining.is_a?(String)
        errors << "#{label} : the machining of side #{host} of #{used.name} is a file, it can't be merged"
      elsif axis == AXIS_Y && !component.nil? && !_turnable_machining?(component.machining)
        errors << "#{label} goes along Y : the machining of side #{host} of #{used.name} can only be drillings and mortises along Z, their length along X"
      end
    end

    # Can the given machining of a used connector be turned to go along Y -
    # see "axis" : none, or only drillings and mortises along Z, their
    # length along X ?
    def _turnable_machining?(machining)
      return true unless machining.is_a?(Hash)
      return false if machining[MACHINING_POCKETS].is_a?(Array) && !machining[MACHINING_POCKETS].empty?
      [ MACHINING_DRILLINGS, MACHINING_MORTISES ].all? { |key|
        !machining[key].is_a?(Array) || machining[key].all? { |item|
          item.is_a?(Hash) && [ nil, AXIS_Z ].include?(item['axis']) && [ nil, AXIS_X ].include?(item['length_axis'])
        }
      }
    end

    # The positions of an article - see "at".
    def _validate_at(label, at, errors)
      unless at.is_a?(Array) && !at.empty?
        errors << "#{label} at is not a list of positions"
        return
      end
      at.each_with_index do |item, index|
        position = "#{label} position #{index + 1}"
        unless item.is_a?(Hash)
          errors << "#{position} is not an object"
          next
        end
        (item.keys - ARTICLE_AT_KEYS).each { |k| errors << "#{position} has an unknown key '#{k}'" }
        ARTICLE_AT_KEYS.each do |k|
          next if item[k].nil?
          unknown = _unknown_variables(item[k])
          unknown.each { |n| errors << "#{position} #{k} uses the unknown variable @#{n}" }
          errors << "#{position} #{k} is not a length" if unknown.empty? && _to_checked_length(item[k], true).nil?
        end
      end
    end

    def _validate_primitives(path, part, value, errors)
      return if value.empty?   # None yet : declared, nothing laid
      (value.keys - PRIMITIVES[part]).each do |key|
        errors << "component '#{path}' #{part} has an unknown primitive '#{key}'"
      end
      fn_depth = lambda do |item, label|
        # Its sign checkable only without variables : they change with where it is laid
        unless item['depth'] == DRILLING_DEPTH_THROUGH || !_to_checked_length(item['depth'], _variable_lengths?(item['depth'])).nil?
          errors << "#{label} depth is neither \"#{DRILLING_DEPTH_THROUGH}\" nor a positive length"
        end
      end
      fn_from_to = lambda do |item, label|
        from = _to_checked_length(item['from'], true)
        to = _to_checked_length(item['to'], true)
        errors << "#{label} from is not a length" if from.nil?
        errors << "#{label} to is not a length" if to.nil?
        # Checkable only without variables : they change with where it is laid
        errors << "#{label} to is not above from" if !from.nil? && !to.nil? && to <= from && !_variable_lengths?(item['from'], item['to'])
      end
      _validate_primitive_list(path, part, value, MACHINING_DRILLINGS, 'drilling', %w[axis x y z diameter depth] + HEADS, %w[diameter], errors) do |item, label|
        fn_depth.call(item, label)
        _validate_axis(item, label, errors)
        _validate_head(item, label, 'face', HEAD_FACES, errors)
      end
      _validate_primitive_list(path, part, value, MACHINING_MORTISES, 'mortise', %w[axis length_axis x y z length width depth], %w[length width], errors) do |item, label|
        fn_depth.call(item, label)
        _validate_axis(item, label, errors)
        length_axes = LENGTH_AXES[item['axis'].nil? ? AXIS_Z : item['axis']]
        if item.key?('length_axis') && !length_axes.nil? && !length_axes.include?(item['length_axis'])
          errors << "#{label} length_axis is neither #{length_axes.map(&:inspect).join(' nor ')}"
        end
      end
      _validate_primitive_list(path, part, value, HARDWARE_CYLINDERS, 'cylinder', %w[axis x y z diameter from to] + HEADS, %w[diameter], errors) do |item, label|
        fn_from_to.call(item, label)
        _validate_cylinder_axis(item, label, errors)
        _validate_head(item, label, 'end', HEAD_ENDS, errors)
      end
      _validate_primitive_list(path, part, value, HARDWARE_OBLONGS, 'oblong', %w[axis length_axis x y z length width from to], %w[length width], errors) do |item, label|
        fn_from_to.call(item, label)
        _validate_cylinder_axis(item, label, errors)
        keys = PRISM_OUTLINE_KEYS[item['axis'].nil? ? AXIS_Z : item['axis']]
        if item.key?('length_axis') && !keys.nil? && !keys.include?(item['length_axis'])
          errors << "#{label} length_axis is neither #{keys.map(&:inspect).join(' nor ')}"
        end
      end
      _validate_primitive_list(path, part, value, HARDWARE_PRISMS, 'prism', %w[axis from to outline], [], errors) do |item, label|
        fn_from_to.call(item, label)
        _validate_prism_outline(item, label, errors)
      end
      _validate_primitive_list(path, part, value, MACHINING_POCKETS, 'pocket', %w[axis depth outline], [], errors) do |item, label|
        fn_depth.call(item, label)
        _validate_axis(item, label, errors)
        _validate_prism_outline(item, label, errors) if !item.key?('axis') || AXES.include?(item['axis'])
      end
    end

    # Validates the axis and the outline of a prism - see PRISM_KEYS :
    # its points given by the two other axes, the outline checked - not
    # crossing itself, each rounding fitting its sides - when no length of
    # it depends on where it is laid.
    def _validate_prism_outline(item, label, errors)
      axis = item['axis'].nil? ? AXIS_Z : item['axis']
      keys = PRISM_OUTLINE_KEYS[axis]
      if keys.nil?
        errors << "#{label} axis is neither #{PRISM_AXES.map(&:inspect).join(' nor ')}"
        return
      end
      points = item['outline']
      unless points.is_a?(Array) && points.length >= 3
        errors << "#{label} outline is not a list of 3 points or more"
        return
      end
      outline = []
      points.each_with_index do |point, index|
        point_label = "#{label} point #{index + 1}"
        unless point.is_a?(Hash)
          errors << "#{point_label} is not an object"
          outline = nil
          next
        end
        (point.keys - keys - [ PRISM_RADIUS_KEY ]).each do |k|
          errors << "#{point_label} has an unknown key '#{k}'#{k =~ /\A[xyz]\z/ ? " - along #{axis.upcase}, a point is given by #{keys.join(' and ')}" : ''}"
        end
        point.each do |k, v|
          _unknown_variables(v).each do |name|
            errors << "#{point_label} #{k} uses the unknown variable @#{name}"
          end
        end
        u, v = keys.map do |k|
          next 0.0 if point[k].nil?
          length = _to_checked_length(point[k], true)
          errors << "#{point_label} #{k} is not a length" if length.nil?
          length
        end
        r = 0.0
        unless point[PRISM_RADIUS_KEY].nil?
          r = _to_checked_length(point[PRISM_RADIUS_KEY], false)
          errors << "#{point_label} r is not a positive length" if r.nil?
        end
        if outline.nil? || u.nil? || v.nil? || r.nil? || _variable_lengths?(*point.values)
          outline = nil
        else
          outline << [ u, v, r ]
        end
      end
      errors << "#{label} outline is flat, crosses itself or has a rounding its sides can't hold" if !outline.nil? && self.class.prism_corners(outline).nil?
    end

    # Validates the axis a machining goes along - see AXES : one along Y is
    # placed by x and z, and isn't through.
    def _validate_axis(item, label, errors)
      if item.key?('axis') && !AXES.include?(item['axis'])
        errors << "#{label} axis is neither #{AXES.map(&:inspect).join(' nor ')}"
        return
      end
      if item['axis'] == AXIS_Y
        errors << "#{label} is along Y and has a y - it is placed by x and z" if item.key?('y')
        errors << "#{label} is along Y and through" if item['depth'] == DRILLING_DEPTH_THROUGH
      elsif item.key?('z')
        errors << "#{label} has a z but isn't along Y"
      end
    end

    # Does the given value - its data or a part of it - hold a machining
    # along Y : it starts on the face height away ? A cylinder or a prism
    # along Y doesn't.
    def _along_y_machining?(value)
      case value
      when Hash
        PRIMITIVES[PART_MACHINING].any? { |key| value[key].is_a?(Array) && value[key].any? { |item| item.is_a?(Hash) && item['axis'] == AXIS_Y } } ||
          value.values.any? { |v| _along_y_machining?(v) }
      when Array
        value.any? { |v| _along_y_machining?(v) }
      else
        false
      end
    end

    # Validates the axis a cylinder or an oblong goes along - see
    # PRISM_AXES : it is placed by the two other axes.
    def _validate_cylinder_axis(item, label, errors)
      axis = item['axis'].nil? ? AXIS_Z : item['axis']
      keys = PRISM_OUTLINE_KEYS[axis]
      if keys.nil?
        errors << "#{label} axis is neither #{PRISM_AXES.map(&:inspect).join(' nor ')}"
        return
      end
      (%w[x y z] - keys).select { |k| item.key?(k) }.each do |k|
        errors << "#{label} is along #{axis.upcase} and has a #{k} - it is placed by #{keys.join(' and ')}"
      end
    end

    # Validates the head a drilling or a cylinder widens by at one end - see
    # HEADS. side_key : 'face' or 'end', sides : its values.
    def _validate_head(item, label, side_key, sides, errors)
      head_keys = HEADS.select { |k| item.key?(k) }
      return if head_keys.empty?
      if head_keys.length > 1
        errors << "#{label} has both #{head_keys.join(' and ')}"
        return
      end
      head_key = head_keys.first
      head = item[head_key]
      label = "#{label} #{head_key}"
      unless head.is_a?(Hash)
        errors << "#{label} is not an object"
        return
      end
      keys = %w[diameter] + (head_key == HEAD_COUNTERSINK ? %w[angle] : %w[depth]) + [ side_key ]
      (head.keys - keys).each do |k|
        errors << "#{label} has an unknown key '#{k}'"
      end
      head.each do |k, v|
        next unless v.is_a?(String)
        _unknown_variables(v).each do |name|
          errors << "#{label} #{k} uses the unknown variable @#{name}"
        end
      end
      diameter = _to_checked_length(head['diameter'], false)
      if diameter.nil?
        errors << "#{label} diameter is not a positive length"
      else
        own = _to_checked_length(item['diameter'], false)
        errors << "#{label} diameter is not above the one of the #{side_key == 'face' ? 'drilling' : 'cylinder'}" if !own.nil? && diameter <= own && !_variable_lengths?(head['diameter'], item['diameter'])
      end
      if head_key == HEAD_COUNTERSINK
        angle = head['angle']
        errors << "#{label} angle is not an angle between 0 and 180" unless angle.nil? || angle.is_a?(Numeric) && angle > 0 && angle < 180
      else
        errors << "#{label} depth is not a positive length" if _to_checked_length(head['depth'], false).nil?
      end
      if side_key == 'end' && !head.key?(side_key)
        errors << "#{label} has no end - #{sides.map(&:inspect).join(' or ')}"
      elsif head.key?(side_key) && !sides.include?(head[side_key])
        errors << "#{label} #{side_key} is neither #{sides.map(&:inspect).join(' nor ')}"
      end
      errors << "#{label} is on the opposite face of a drilling that isn't through" if side_key == 'face' && head[side_key] == sides[1] && item['depth'] != DRILLING_DEPTH_THROUGH
    end

    # Do the given lengths depend on where they are laid ?
    def _variable_lengths?(*values)
      values.any? { |v| v.is_a?(String) && (v =~ VARIABLE_PATTERN || LengthExpressionUtils.functions?(v)) }
    end

    # The given length checked as a descriptor holds it : its measures set
    # to a typical one - 18 mm - nil if it isn't one.
    def _to_checked_length(value, negative_allowed)
      self.class.to_length(value, negative_allowed, @checked_variables)
    end

    # Validates the list of the given primitive - x, y and its size - then
    # yields each item and the label of its errors for what is its own.
    def _validate_primitive_list(path, part, value, key, name, keys, size_keys, errors)
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
          _unknown_variables(v).each do |name|
            errors << "#{label} #{k} uses the unknown variable @#{name}"
          end
        end
        %w[x y z].each do |k|
          errors << "#{label} #{k} is not a length" if item.key?(k) && !item[k].nil? && _to_checked_length(item[k], true).nil?
        end
        sizes = size_keys.map { |k| _to_checked_length(item[k], false) }
        size_keys.each_with_index do |k, i|
          errors << "#{label} #{k} is not a positive length" if sizes[i].nil?
        end
        if size_keys.length == 2 && sizes.none?(&:nil?) && sizes[0] < sizes[1] && !_variable_lengths?(item['length'], item['width'])
          errors << "#{label} length is below its width"
        end
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
        unless _scalar?(value) || value.is_a?(Array) && value.all? { |item| _scalar?(item) }
          errors << "component '#{path}' attribute '#{name}' is neither a scalar nor an array of scalars"
          next
        end
        case name
        when ATTRIBUTE_HINGE_MAX_ANGLE
          errors << "component '#{path}' attribute '#{name}' is not an angle in degrees - above 0, up to #{HINGE_MAX_ANGLE_MAX}" unless self.class.hinge_max_angle?(value)
        when ATTRIBUTE_HINGE_PIVOT
          errors << "component '#{path}' attribute '#{name}' is not two lengths [ \"y\", \"z\" ]" if self.class.hinge_pivot(value).nil?
        when ATTRIBUTE_HINGE_PIVOT_APPROXIMATE
          errors << "component '#{path}' attribute '#{name}' is not true or false" unless value == true || value == false
        end
      end
    end

    def _scalar?(value)
      value.is_a?(String) || value.is_a?(Numeric) || value == true || value == false
    end

  end

end

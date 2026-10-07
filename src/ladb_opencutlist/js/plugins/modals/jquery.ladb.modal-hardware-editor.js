+function ($) {
    'use strict';

    // CONSTANTS
    // ======================

    const COMPUTE_DELAY = 300;  // ms after the last edit

    // What Tab moves through in a panel - see captureFocus
    const FOCUSABLE_SELECTOR = 'input:not([type="hidden"]), select, textarea, button, a[href]';

    // The size and position of the editor while a part is shaped in SketchUp :
    // top left of the screen, beside the minimized OpenCutList bar
    const SHAPING_WIDTH = 380;
    const SHAPING_HEIGHT = 290;
    const SHAPING_LEFT = 100;
    const SHAPING_TOP = 100;

    const PARTS = [ 'hardware', 'machining' ];

    // The units of "length_unit", with their label's index - see default.unit_*
    const LENGTH_UNIT_OPTIONS = [
        { unit: 'mm', index: 2 },
        { unit: 'cm', index: 3 },
        { unit: 'm', index: 4 },
        { unit: 'in', index: 0 },
        { unit: 'ft', index: 1 },
        { unit: 'yd', index: 5 }
    ];

    const PRIMITIVE_KEYS = [ 'cylinders', 'oblongs', 'prisms', 'drillings', 'mortises', 'pockets' ];

    // The primitives each part can be given as - see HardwareDescriptorDef::PRIMITIVES -
    // and the one each starts as, once added.
    const PART_PRIMITIVE_KEYS = {
        hardware: [ 'cylinders', 'oblongs', 'prisms' ],
        machining: [ 'drillings', 'mortises', 'pockets' ]
    };
    const PRIMITIVE_DEFAULTS = {
        cylinders: { diameter: '8', from: '-10', to: '10' },
        oblongs: { length: '19', width: '5', from: '-10', to: '10' },
        prisms: { from: '-1', to: '1', outline: [ { x: '-20', y: '-10' }, { x: '20', y: '-10' }, { x: '20', y: '10' }, { x: '-20', y: '10' } ] },
        drillings: { diameter: '5', depth: '12' },
        mortises: { length: '19', width: '5', depth: '12' },
        pockets: { depth: '10', outline: [ { x: '-20', y: '-10' }, { x: '20', y: '-10' }, { x: '20', y: '10' }, { x: '-20', y: '10' } ] }
    };
    // The primitives given as a prism - see HardwareDescriptorDef::PRISM_KEYS -
    // a pocket hollowed out of the part, depth deep from the face.
    const PRISM_KEYS = [ 'prisms', 'pockets' ];
    const PRIMITIVE_HEADS = [ 'countersink', 'counterbore' ];

    // The axis a prism is extruded along, and the axes its points are given
    // by - see HardwareDescriptorDef::PRISM_OUTLINE_KEYS.
    const PRISM_AXES = [ 'x', 'y', 'z' ];
    const PRISM_OUTLINE_KEYS = { z: [ 'x', 'y' ], x: [ 'y', 'z' ], y: [ 'x', 'z' ] };
    const PRISM_MIN_POINTS = 3;

    // The sizes of a primitive, from the texts of its lengths : '⌀D×L',
    // 'L×W×D' for an elongated one or a prism - its outline extents then.
    const fnPrimitiveSizes = function (key, texts) {
        const sizes = key === 'mortises' || key === 'oblongs' || PRISM_KEYS.includes(key) ? [ texts.length, texts.diameter ] : [ '⌀' + texts.diameter ];
        sizes.push(texts.depth);
        return sizes.join('×');
    };

    // A primitive in a few words, from the texts of its lengths : its sizes
    // and position by the two axes across the one it goes along - '(X, Y)',
    // (X, Z) along Y, (Y, Z) along X - none for a prism, placed by its outline.
    const fnPrimitiveSummary = function (key, axis, texts) {
        if (PRISM_KEYS.includes(key)) {
            return fnPrimitiveSizes(key, texts);
        }
        const keys = PRISM_OUTLINE_KEYS[axis] || PRISM_OUTLINE_KEYS.z;
        return fnPrimitiveSizes(key, texts) + ' (' + texts[keys[0]] + ', ' + texts[keys[1]] + ')';
    };
    const PRIMITIVE_HEAD_DEFAULT_ANGLE = 90;

    // Its outline, in the color of its part : a machining seen from above
    const PRIMITIVE_ICONS = {
        cylinders: '<svg width="16" height="16" viewBox="0 0 18 18" fill="none" stroke="currentColor" stroke-width="1.4"><ellipse cx="9" cy="4" rx="4" ry="1.6"/><path d="M5 4v10M13 4v10"/><path d="M5 14a4 1.6 0 0 0 8 0"/></svg>',
        oblongs: '<svg width="16" height="16" viewBox="0 0 18 18" fill="none" stroke="currentColor" stroke-width="1.4"><rect x="2" y="2.5" width="14" height="4" rx="2"/><path d="M2 4.5v9M16 4.5v9"/><path d="M2 13.5a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2"/></svg>',
        prisms: '<svg width="16" height="16" viewBox="0 0 18 18" fill="none" stroke="currentColor" stroke-width="1.4" stroke-linejoin="round"><path d="M15.2 12.9 8.5 16.8 8.5 13.9 12.7 11.4 12.7 6 15.2 4.6zM9.5 1.2 15.2 4.6 12.7 6 7 2.7zM7 8.1 12.7 11.4 12.7 6 7 2.7zM7 8.1 12.7 11.4 8.5 13.9 2.8 10.6zM2.8 13.4 8.5 16.8 8.5 13.9 2.8 10.6z"/></svg>',
        drillings: '<svg width="16" height="16" viewBox="0 0 18 18" fill="none" stroke="currentColor" stroke-width="1.4"><circle cx="9" cy="9" r="5.5"/><path d="M9 7.2v3.6M7.2 9h3.6" opacity=".6"/></svg>',
        mortises: '<svg width="16" height="16" viewBox="0 0 18 18" fill="none" stroke="currentColor" stroke-width="1.4"><rect x="1.5" y="6" width="15" height="6" rx="3"/></svg>',
        pockets: '<svg width="16" height="16" viewBox="0 0 18 18" fill="none" stroke="currentColor" stroke-width="1.4" stroke-linejoin="round"><path d="M4 2.5h10a1.5 1.5 0 0 1 1.5 1.5v5a1.5 1.5 0 0 1-1.5 1.5h-3.5v4a1.5 1.5 0 0 1-1.5 1.5H4A1.5 1.5 0 0 1 2.5 14.5V4A1.5 1.5 0 0 1 4 2.5z"/></svg>'
    };

    // The given element with a bootstrap tooltip - none without a title -,
    // set up with its panel - see LadbAbstractDialog#setupTooltips.
    const fnTooltip = function ($element, title) {
        if (!title) return $element;
        return $element
            .attr('data-toggle', 'tooltip')
            .attr('title', title);
    };

    // Buttons, one pressed - the option whose value is current -, onSelect
    // told the option clicked when not already pressed. An axis one is its
    // letter alone, in the axis color, an other one its label.
    const fnSegments = function (options, current, readonly, onSelect) {
        const $group = $('<div class="btn-group btn-group-xs ladb-hardware-editor-primitive-segments">');
        for (const option of options) {
            $group.append(fnTooltip($('<button type="button" class="btn btn-default">'), option.help ? i18next.t('core.hardware_editor.' + option.help) : null)
                .append(option.axis
                    ? $('<span class="ladb-hardware-editor-primitive-axis">').addClass('ladb-hardware-editor-placement-' + option.axis).text(option.axis.toUpperCase())
                    : document.createTextNode(i18next.t('core.hardware_editor.' + option.label)))
                .toggleClass('active', option.value === current)
                .prop('disabled', readonly || option.disabled === true)
                .on('click', function () {
                    this.blur();
                    if (option.value !== current) {
                        onSelect(option);
                    }
                })
            );
        }
        return $group;
    };

    // The decimal separator lengths are shown with - the model's : the ','
    // of a French numeric keypad - set at init. The JSON always gets '.'.
    let decimalSeparator = '.';

    // The given written length as a field shows it : its decimal separator
    // the model's.
    const fnLengthText = function (value) {
        const text = value === undefined || value === null ? '' : String(value);
        return decimalSeparator === '.' ? text : text.replace(/(\d)\.(?=\d)/g, '$1' + decimalSeparator);
    };

    // The given typed length as written in the JSON : its decimal commas
    // made '.' - the ones between two digits, ', ' still separates the
    // arguments of a function.
    const fnLengthJson = function (text) {
        return String(text).replace(/(\d),(?=\d)/g, '$1.');
    };

    // The given primitive length as the field shows it - a number is in
    // the descriptor's length_unit.
    const fnPrimitiveText = function (value) {
        return fnLengthText(value);
    };

    // The given typed length as written in the JSON : a number alone is in
    // the descriptor's length_unit, written as a number - the rest as typed.
    const fnPrimitiveValue = function (text) {
        text = fnLengthJson(text.trim());
        return /^-?\d+(?:\.\d+)?$/.test(text) ? parseFloat(text) : text;
    };

    // The millimeters of the given written length when it is a plain one - a
    // number, or one with mm - null otherwise.
    const fnPrismNumber = function (value) {
        if (value === undefined) return 0;
        if (typeof value === 'number') return value;
        const match = /^\s*(-?\d+(?:[.,]\d+)?)\s*(mm)?\s*$/.exec(String(value));
        return match ? parseFloat(match[1].replace(',', '.')) : null;
    };

    // The given primitive - { slot, part, key, index }, and the key of its
    // article if it is one's - as a key
    const fnPrimitiveId = function (primitive) {
        return primitive ? [ primitive.slot, primitive.article || '', primitive.part, primitive.key, primitive.index ].join('/') : null;
    };

    // The keys an article can't be named by - see HardwareDescriptorDef::ARTICLE_FIELDS
    const ARTICLE_KEY_PATTERN = /^[a-z][a-z0-9_-]*$/;
    const ARTICLE_RESERVED_KEYS = [ 'name', 'description', 'price', 'url', 'mass', 'skp', 'at', 'use', 'host', 'measures', 'variables', 'axis', 'same_as' ].concat(PRIMITIVE_KEYS);
    const ARTICLE_INFO_KEYS = [ 'name', 'price', 'mass' ];

    // Is the given hardware part value its articles - an object of them by
    // key - see HardwareDescriptorDef.articles? ?
    const fnIsArticles = function (value) {
        if (value === null || typeof value !== 'object' || Array.isArray(value)) return false;
        const keys = Object.keys(value);
        return keys.length > 0 && keys.every(function (key) {
            const article = value[key];
            return ARTICLE_RESERVED_KEYS.indexOf(key) < 0 && (article === null || typeof article === 'object' && !Array.isArray(article));
        });
    };

    // The key of the article a hardware given in a short form - its SKP or
    // its primitives - is - see LadbModalHardwareEditor#hardwareArticles
    const SHORT_ARTICLE_KEY = 'body';

    // The info of the article a short form is : its slot's - the name of the
    // slot names it too, see SmartJoinTool#_get_hardware_definition_name
    const SHORT_ARTICLE_INFO_KEYS = [ 'description', 'price', 'url', 'mass' ];

    // Has the given machining nothing - no SKP, no primitives - ?
    const fnIsEmptyMachining = function (value) {
        if (value === undefined || value === null) return true;
        if (fnIsSkp(value) || typeof value !== 'object') return false;
        return Object.keys(value).every(function (key) { return key !== 'skp' && !(Array.isArray(value[key]) && value[key].length > 0); });
    };

    // Is the given machining SKP value one - true or a path - ?
    const fnIsSkp = function (value) {
        return value === true || typeof value === 'string';
    };

    // The kind of the given article : 'connector' - one of the library, by its 'use' -, 'skp' or 'primitives'.
    const fnArticleKind = function (article) {
        if (article.use !== undefined) return 'connector';
        if (article.skp !== undefined) return 'skp';
        return 'primitives';
    };

    // The given article - { slot, key } - as a key
    const fnArticleId = function (article) {
        return article ? article.slot + '/' + article.key : null;
    };

    // 4x4 matrices, column after column - as THREE.Matrix4#fromArray
    const IDENTITY = [ 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1 ];
    const fnMultiply = function (a, b) {
        const m = [];
        for (let col = 0; col < 4; col++) {
            for (let row = 0; row < 4; row++) {
                let sum = 0;
                for (let k = 0; k < 4; k++) {
                    sum += a[k * 4 + row] * b[col * 4 + k];
                }
                m.push(Math.round(sum * 1e9) / 1e9 + 0);   // + 0 : no -0
            }
        }
        return m;
    };
    const fnIsIdentity = function (m) {
        return m.every(function (v, i) { return Math.abs(v - IDENTITY[i]) < 1e-9; });
    };
    const fnIsSame = function (a, b) {
        return a.every(function (v, i) { return Math.abs(v - b[i]) < 1e-9; });
    };
    // A quarter turn around the given axis (0, 1, 2), counterclockwise if
    // sign is 1 - looking down the axis.
    const fnQuarterTurn = function (axis, sign) {
        const m = IDENTITY.slice();
        const i = (axis + 1) % 3, j = (axis + 2) % 3;
        m[i * 4 + i] = 0;
        m[i * 4 + j] = sign;
        m[j * 4 + i] = -sign;
        m[j * 4 + j] = 0;
        return m;
    };
    // The mirror across the plane normal to the given axis
    const fnMirror = function (axis) {
        const m = IDENTITY.slice();
        m[axis * 5] = -1;
        return m;
    };
    const AXES = [ 'x', 'y', 'z' ];

    // A new descriptor of the given type, its bare numbers in the given
    // length unit - the model's - : empty, its slots to fill - a hinge with
    // its variants, see fnNewHingeComponents.
    const fnNewDescriptor = function (type, lengthUnit) {
        const nameKey = 'core.hardware_editor.new_name_' + type;
        const descriptor = {
            format: 'ocl-hardware',
            version: 1,
            id: fnUuid(),
            type: type,
            length_unit: lengthUnit || 'mm',
            name: i18next.exists(nameKey) ? i18next.t(nameKey) : i18next.t('core.hardware_editor.new_name'),   // Adapted to the type of hardware, when it has its own
            variables: {},
            asserts: [],
            components: {
                a: {},
                b: {}
            }
        };
        if (type === 'hinge') {
            descriptor.components = fnNewHingeComponents();
            descriptor.options = { start_offset: '100mm', end_offset: '100mm', max_spacing: '800mm' };
        }
        return descriptor;
    };

    // The components of a new hinge : no hardware nor machining to start
    // with, only the variants by the kind of door - the form can't add them.
    const fnNewHingeComponents = function () {
        return {
            a: {
                attributes: { hinge_max_angle: 110 },
                variants: {
                    select: { by: 'hinge_kind' },
                    fallback: 'overlay',
                    items: {
                        overlay: {},
                        half_overlay: {},
                        inset: {}
                    }
                }
            },
            b: {}
        };
    };

    const fnUuid = function () {
        return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function (c) {
            const r = Math.random() * 16 | 0;
            return (c === 'x' ? r : (r & 0x3 | 0x8)).toString(16);
        });
    };

    // A file name - no folder, no extension - from the given text.
    const fnSanitizeFileName = function (text) {
        return text.replace(/[\\/:*?"<>|]/g, '-').replace(/\.json$/i, '').trim();
    };

    // The libraries - see Plugin::LIBRARY_REF_PREFIX and LIBRARY_BUNDLED_REF_PREFIX
    const USER_REF_PREFIX = '$LIB/';
    const BUNDLED_REF_PREFIX = '$OCL/';

    const FILE_NAME_REGEX = /^[^.\\/:*?"<>|][^\\/:*?"<>|]*$/;

    // The name of the file of the given ref, without its extension.
    const fnFileStem = function (ref) {
        return ref.substring(ref.lastIndexOf('/') + 1).replace(/\.json$/i, '');
    };

    // The given value as JSON on one line, spaced as the descriptors are written.
    const fnInlineJson = function (value) {
        if (Array.isArray(value)) {
            return value.length === 0 ? '[]' : '[ ' + value.map(fnInlineJson).join(', ') + ' ]';
        }
        if (value !== null && typeof value === 'object') {
            const keys = Object.keys(value);
            return keys.length === 0 ? '{}' : '{ ' + keys.map(function (key) { return JSON.stringify(key) + ': ' + fnInlineJson(value[key]); }).join(', ') + ' }';
        }
        return JSON.stringify(value);
    };

    // The given value if it is an object, else an empty one.
    // Is the given element a length typed in the given primitive editor -
    // not in one nested in it, e.g. a primitive of an article : its own
    // names offered only.
    const fnTypedIn = function ($editor, element) {
        return $(element).hasClass('ladb-hardware-editor-live') && $(element).closest('.ladb-hardware-editor-primitive-editor').is($editor);
    };

    const fnObject = function (value) {
        return value !== null && typeof value === 'object' && !Array.isArray(value) ? value : {};
    };

    // Does the given data have a value at the given path of keys ?
    const fnHasPath = function (data, path) {
        let value = data;
        for (const key of path) {
            value = fnObject(value);
            if (!Object.prototype.hasOwnProperty.call(value, key)) {
                return false;
            }
            value = value[key];
        }
        return true;
    };

    // The value at the given path of keys of the given data, undefined if none.
    const fnPathValue = function (data, path) {
        let value = data;
        for (const key of path) {
            value = fnObject(value)[key];
            if (value === undefined) {
                return undefined;
            }
        }
        return value;
    };

    // The given value as JSON, laid out from the given indent : an object
    // holding objects or arrays on several lines, the rest on one - as the
    // descriptors are written.
    const fnLaidOutJson = function (value, indent) {
        const object = fnObject(value);
        const keys = Object.keys(object);
        if (value !== object || !keys.some(function (key) { return object[key] !== null && typeof object[key] === 'object' && Object.keys(object[key]).length > 0; })) {
            return fnInlineJson(value);
        }
        const inner = indent + '  ';
        return '{\n' + keys.map(function (key) { return inner + JSON.stringify(key) + ': ' + fnLaidOutJson(object[key], inner); }).join(',\n') + '\n' + indent + '}';
    };

    // The options of SmartJoin a descriptor of each type gives the defaults
    // of - its 'options' - by group, as the tool shows them. A text group
    // holds names - materials, layers - not lengths.
    const TOOL_OPTION_TEXT_GROUPS = [
        { group: 'materials', text: true, options: [ 'hardware_material_name', 'machining_material_name' ] },
        { group: 'layers', text: true, options: [ 'hardware_layer_name', 'machining_layer_name' ] },
    ];
    const TOOL_OPTION_GROUPS = {
        connector: [
            { group: 'height', options: [ 'height' ] },
            { group: 'offsets', options: [ 'start_offset', 'end_offset' ] },
            { group: 'spacings', options: [ 'min_spacing', 'max_spacing' ] },
        ].concat(TOOL_OPTION_TEXT_GROUPS),
        fitting: [
            { group: 'offsets', options: [ 'start_offset', 'end_offset' ] },
            { group: 'spacings', options: [ 'min_spacing', 'max_spacing' ] },
        ].concat(TOOL_OPTION_TEXT_GROUPS),
        hinge: [
            { group: 'offsets', options: [ 'start_offset', 'end_offset' ] },
            { group: 'spacings', options: [ 'min_spacing', 'max_spacing' ] },
        ].concat(TOOL_OPTION_TEXT_GROUPS),
    };

    // CodeMirror mode of the descriptor : JSON, its keys apart, the @variables
    // of its expressions spotted.
    CodeMirror.defineSimpleMode('ocl-hardware-json', {
        start: [
            { regex: /"(?:[^\\"]|\\.)*"(?=\s*:)/, token: 'property' },
            { regex: /"/, token: 'string', push: 'string' },
            { regex: /-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?/, token: 'number' },
            { regex: /(?:true|false|null)\b/, token: 'atom' },
            { regex: /[{\[]/, indent: true },
            { regex: /[}\]]/, dedent: true },
        ],
        string: [
            { regex: /"/, token: 'string', pop: true },
            { regex: /@[A-Za-z_]\w*/, token: 'variable-2' },
            { regex: /(?:[^\\"@]|\\.)+/, token: 'string' },
            { regex: /@/, token: 'string' },
        ],
        meta: {
            electricChars: '}]'
        }
    });

    // CLASS DEFINITION
    // ======================

    const LadbModalHardwareEditor = function (element, options, dialog) {
        LadbAbstractModal.call(this, element, options, dialog);

        this.ref = null;
        this.readonly = false;
        this.fileName = null;   // Typed : the file is written - renamed - with it

        this.topology = null;
        this.swapped = false;
        this.response = null;

        this._computeTimeout = null;
        this._computeId = 0;
        this._settingsSignature = null;
        this._benchDef = null;
        this._errorLine = null;
        this._cleanGeneration = null;   // Of the JSON, as loaded

        // SKP files, by ref : their meshes - by source - the ones picked to
        // replace them, and the placement to bake into them at save.
        this.meshes = {};
        this.imports = {};
        this.placements = {};
        this.placementHistories = {};   // The matrices it had, by ref - see renderPlacement
        this.placementOpens = {};       // The transform panel shown, by ref

        this.shaping = null;    // A part edited in SketchUp : { ref, size }

        // The primitive edited - its row open - and the one hovered : { slot, part, key, index }
        this.primitiveOpen = null;
        this.primitiveHovered = null;
        this.articleOpen = null;      // { slot, key }
        this.skpRowClosed = {};       // The SKP rows of parts folded, by slot/part - open by default
        this.articleHovered = null;
        this.connectorBrowser = null; // The library browsed for an article : { slot, key, listing }

    };
    LadbModalHardwareEditor.prototype = Object.create(LadbAbstractModal.prototype);

    LadbModalHardwareEditor.DEFAULTS = {
        ref: null,
        type: null,
        dir_ref: null
    };

    // Compute /////

    LadbModalHardwareEditor.prototype.compute = function (delayed) {
        const that = this;

        clearTimeout(this._computeTimeout);
        if (delayed) {
            this._computeTimeout = setTimeout(function () {
                that.compute(false);
            }, COMPUTE_DELAY);
            return;
        }

        const computeId = ++this._computeId;
        rubyCallCommand('hardware_bench_compute', {
            descriptor: this.cm.getValue(),
            ref: this.ref || this.provisionalRef(),
            topology: this.topology,
            thickness_a: this.$inputThicknessA.val(),
            thickness_b: this.$inputThicknessB.val(),
            swapped: this.swapped
        }, function (response) {
            if (computeId !== that._computeId) {
                return; // An older one, overtaken by an edit
            }
            if (response.type === undefined && that.response && that.response.type !== undefined) {
                // Not a descriptor for now - the JSON is being typed : the last bench stays
                that.renderErrors(response.errors);
                return;
            }
            that.response = response;
            that.topology = response.topology || that.topology;
            $('.ladb-hardware-editor-abstract', that.$element).toggle(response.abstract === true);
            that.renderName();
            that.renderUnit();
            that.renderTopologies();
            that.renderBench();
            that.renderComputations();
            that.renderSettings();
            that.renderParts();
            that.renderErrors();
            that.renderStatus();
            that.fetchMeshes();
        });

    };

    // Focus /////

    // The field focused in the given panel, before it is re-rendered : a
    // field edited then left with Tab is computed once the focus is already
    // on the next one, which the re-rendering destroys. Found again by its rank.
    LadbModalHardwareEditor.prototype.captureFocus = function ($panel) {
        const active = document.activeElement;
        if (!active || !$.contains($panel[0], active)) {
            return null;
        }
        const typed = active.value !== undefined && (active.value !== $(active).data('ladb-focus-value') || $(active).hasClass('ladb-hardware-editor-live'));
        return {
            element: active,
            $panel: $panel,
            index: $(FOCUSABLE_SELECTOR, $panel).index(active),
            value: typed ? active.value : undefined,   // Typed while computing : kept
            selectionStart: typed ? active.selectionStart : null,
            selectionEnd: typed ? active.selectionEnd : null
        };
    };

    LadbModalHardwareEditor.prototype.restoreFocus = function (focus) {
        if (focus === null || focus.index < 0 || $.contains(document.documentElement, focus.element)) {
            return; // Nothing focused, or not re-rendered
        }
        const element = $(FOCUSABLE_SELECTOR, focus.$panel).get(focus.index);
        if (!element || element.disabled || element.tagName !== focus.element.tagName || element.type !== focus.element.type) {
            return; // Not the same field anymore
        }
        element.focus();
        if (focus.value !== undefined) {
            if (element.value !== focus.value) {
                element.value = focus.value;
            }
            try {
                element.setSelectionRange(focus.selectionStart, focus.selectionEnd);
            } catch (e) {
                // Not a text field
            }
        } else if (typeof element.select === 'function' && element.tagName === 'INPUT') {
            element.select();   // As Tab leaves it
        }
    };

    // Render /////

    // Its length unit - see "length_unit" -, its parents' when they have one,
    // over the viewer's top left corner. Kept while the JSON is being edited.
    LadbModalHardwareEditor.prototype.renderUnit = function () {
        let ownUnit;
        try {
            ownUnit = JSON.parse(this.cm.getValue()).length_unit;
        } catch (e) {
            return;
        }
        const parentUnit = fnObject(this.parentData()).length_unit;
        const unit = typeof parentUnit === 'string' ? parentUnit : (typeof ownUnit === 'string' ? ownUnit : '');
        const unitOption = LENGTH_UNIT_OPTIONS.find(function (unitOption) { return unitOption.unit === unit; });
        $('.ladb-hardware-editor-unit', this.$element)
            .text(unitOption ? i18next.t('default.unit_' + unitOption.index) : unit)   // Invalid : shown as is
            .toggle(unit !== '');
    };

    LadbModalHardwareEditor.prototype.renderName = function () {
        let name = null;
        try {
            name = JSON.parse(this.cm.getValue()).name;
        } catch (e) {
            // Keep the previous one while the JSON is being edited
            return;
        }
        const titleKey = 'core.hardware_editor.title_' + (this.response && this.response.type);
        $('.ladb-hardware-editor-title', this.$element).text(i18next.exists(titleKey) ? i18next.t(titleKey) : i18next.t('core.hardware_editor.title'));   // Adapted to the type of hardware, when it has its own
        if (!this.$inputName.is(':focus')) {
            this.$inputName.val(typeof name === 'string' ? name : '');
        }
        this.$inputName.ladbTextinputText(this.readonly || typeof name !== 'string' ? 'disable' : 'enable');
        this.renderFile();
    };

    LadbModalHardwareEditor.prototype.renderFile = function () {
        const dirRef = this.fileDirRef();
        const targetRef = this.targetRef();
        $('.ladb-hardware-editor-file-dir', this.$element)
            .text(dirRef ? '\u200E' + dirRef + '/\u200E' : '')   // LRM : the rtl ellipsis mustn't move '$' and '/' around
            .attr('title', dirRef ? dirRef + '/' : '');
        if (!this.$inputFile.is(':focus')) {
            this.$inputFile.val(this.fileStem());
        }
        this.$inputFile.ladbTextinputText(this.readonly || !dirRef ? 'disable' : 'enable');
        const renamed = this.ref && targetRef && targetRef !== this.ref;
        $('.ladb-hardware-editor-file-renamed', this.$element)
            .text(renamed ? i18next.t('core.hardware_editor.file_renamed', { name: fnFileStem(this.ref) + '.json' }) : '')
            .toggle(!!renamed);
        const parents = this.response && this.response.inheritance ? this.response.inheritance.parents : [];
        $('.ladb-hardware-editor-file-extends', this.$element).toggle(parents.length > 0);
        $('.ladb-hardware-editor-file-extends > span', this.$element)
            .html(parents.length > 0 ? '<i class="ladb-opencutlist-icon-arrow-right-down-box-fill"></i> ' + i18next.t('core.hardware_editor.inherited_from', { ref: $('<a href="#" class="ladb-hardware-editor-file-extends-name">').text(fnFileStem(parents[0]) + '.json').prop('outerHTML'), interpolation: { escapeValue: false } }) : '')   // The name escaped by its span
            .attr('data-original-title', parents.map(function (ref) { return ref.replace(/\//g, '/\u200B'); }).join(' \u2190 '))   // The whole chain, nearest first - wrapping after its slashes
            .tooltip({ container: 'body' });
    };

    LadbModalHardwareEditor.prototype.renderTopologies = function () {
        const that = this;

        const topologies = this.response.topologies || [];
        const signature = topologies.join(',');
        if (this.$topologies.data('signature') !== signature) {
            this.$topologies
                .data('signature', signature)
                .empty();
            for (const topology of topologies) {
                this.$topologies.append(
                    $('<button type="button" class="btn btn-default">')
                        .attr('data-topology', topology)
                        .text(this.topologyLabel(topology))
                        .on('click', function () {
                            this.blur();
                            that.topology = topology;
                            that.compute(false);
                        })
                );
            }
        }
        $('button', this.$topologies).each(function () {
            $(this).toggleClass('active', $(this).data('topology') === that.topology);
        });
        this.$btnSwap
            .toggle(this.response.swappable === true)
            .toggleClass('active', this.response.swapped === true);

    };

    LadbModalHardwareEditor.prototype.renderBench = function () {
        const that = this;

        const supported = this.response.supported === true;
        $('.ladb-hardware-editor-trial', this.$element).toggle(supported);
        this.$viewer.toggle(supported);
        this.$unsupported
            .toggle(!supported)
            .text(this.response.type ? i18next.t('core.hardware_editor.unsupported_type', { type: this.response.type }) : i18next.t('core.hardware_editor.no_descriptor'));
        if (!supported) {
            return;
        }

        this._benchDef = {
            view: this.response.view_transformation,
            panels: this.response.panels,
            solids: (this.response.solids || []).map(function (solid) {
                // What the viewer shows when it is hovered
                if (solid.article) {
                    // An article's : its name and size - see HardwareBenchComputeWorker#_articles -,
                    // red when it is refused
                    return $.extend({}, solid, {
                        label: solid.slot.toUpperCase() + ' · ' + that.articleName(solid.slot, solid.article) + ' · ' + fnPrimitiveSizes(solid.kind, solid.texts),
                        refused: that.articleRefused(solid.slot, solid.article)
                    });
                }
                // The descriptor's own : red when its slot fails an assert
                return $.extend({}, solid, {
                    label: solid.slot.toUpperCase() + ' · ' + i18next.t('core.hardware_editor.primitive_type_' + solid.kind) + ' ' + fnPrimitiveSummary(solid.kind, solid.axis, solid.texts),
                    refused: that.slotRefused(solid.slot)
                });
            }),
            skps: this.benchSkps(),
            hinge: this.response.hinge || null
        };
        const $threeViewer = $('.ladb-three-viewer', this.$viewer);
        if ($threeViewer.length === 0) {

            // First bench : the viewer is created, the bench given once it is loaded
            const $newThreeViewer = $(Twig.twig({ ref: 'components/_hardware-editor-three-viewer.twig' }).render({
                THREE_CAMERA_VIEWS: THREE_CAMERA_VIEWS
            }));
            this.$viewer.append($newThreeViewer);
            $newThreeViewer
                .on('loaded.ladb.threeviewer', function () {
                    $newThreeViewer.ladbThreeViewer('callCommand', [ 'setup_bench', { benchDef: that._benchDef } ]);
                })
                .on('hovered.bench', function (e, data) {
                    that.showBenchHover(data);
                })
                .on('clicked.bench', function (e, primitive) {
                    that.openPrimitive(primitive);
                })
                .ladbThreeViewer({
                    dialog: this.dialog
                });

        } else if ($threeViewer.data('ladb.threeviewer').loaded) {
            $threeViewer.ladbThreeViewer('callCommand', [ 'setup_bench', { benchDef: this._benchDef } ]);
        }

    };

    // Inheritance - see "extends" : its data merged with its parents', null
    // when it extends none.
    LadbModalHardwareEditor.prototype.inheritedData = function () {
        return this.response && this.response.inheritance ? this.response.inheritance.data : null;
    };

    // The data of its parents alone - see "extends" - null when it extends none.
    LadbModalHardwareEditor.prototype.parentData = function () {
        return this.response && this.response.inheritance ? this.response.inheritance.parent_data || null : null;
    };

    // Where the value at the given path comes from - see "extends" - , owned
    // : written in its own data. 'inherited' : its parents' only ;
    // 'overridden' : its own over its parents' ; null : its parents have none.
    LadbModalHardwareEditor.prototype.inheritanceState = function (path, owned) {
        const parentData = this.parentData();
        if (parentData === null || !fnHasPath(parentData, path)) {
            return null;
        }
        return owned ? 'overridden' : 'inherited';
    };

    // The icon at the end of the given row, for the given state - see
    // inheritanceState - the row greyed when inherited. A click on it copies
    // the inherited value at the given path into its own data - or removes
    // the overriding one : inherited again. Without a path, it only tells.
    LadbModalHardwareEditor.prototype.appendInheritanceIcon = function ($row, state, path) {
        const that = this;

        if (state === null) {
            return null;
        }
        const parents = this.response.inheritance.parents;
        const ref = parents.length > 0 ? parents[0].replace(/\//g, '/\u200B') : '';   // Zero width spaces : the long ref wraps after its slashes
        const inherited = state === 'inherited';
        const clickable = path && !this.readonly;
        const title = i18next.t('core.hardware_editor.' + (inherited ? 'inherited' : 'overridden') + '_' + (clickable ? 'click' : 'from'), { ref: ref, interpolation: { escapeValue: false } });   // An attribute : set as text
        const $icon = $(clickable ? '<a href="#">' : '<span>')
            .addClass('ladb-hardware-editor-inheritance-icon')
            .append($('<i>').addClass(inherited ? 'ladb-opencutlist-icon-arrow-left-down-box-fill' : 'ladb-opencutlist-icon-reset').addClass('ladb-opencutlist-icon-lg'))
            .attr('data-toggle', 'tooltip')
            .attr('data-html', 'true')
            .attr('title', title)
            .tooltip({ container: 'body' });
        if (clickable) {
            $icon.on('click', function (e) {
                e.preventDefault();
                $(this).tooltip('hide');
                if (inherited) {
                    that.overrideInherited(path);
                } else {
                    that.resetInherited(path);
                }
            });
        }
        $row
            .addClass('ladb-hardware-editor-inheritance-row')
            .toggleClass('ladb-hardware-editor-inherited', inherited)
            .append($icon);
        return $icon;
    };

    // Copies the value its parents give at the given path into its own data
    // - see "extends" - : edited from there on. A setting by its value alone.
    LadbModalHardwareEditor.prototype.overrideInherited = function (path) {
        let value = fnPathValue(this.parentData(), path);
        if (value === undefined) {
            return;
        }
        if (path.length === 2 && path[0] === 'variables' && fnObject(value).value !== undefined) {
            value = { value: value.value };
        }
        if (this.writeJsonValue(path, value)) {
            this.compute(false);
        }
    };

    // Removes the value at the given path from its own data - see "extends"
    // - : its parents' again. Its containers left empty go too.
    LadbModalHardwareEditor.prototype.resetInherited = function (path) {
        if (!this.setJsonMember(path.slice(0, -1), path[path.length - 1], undefined)) {
            return;
        }
        for (let k = path.length - 1; k > 0; k--) {
            const containerPath = path.slice(0, k);
            const text = this.cm.getValue();
            const range = this.findJsonValueRange(text, containerPath);
            if (range === null || !/^\{\s*\}$/.test(text.substring(range.start, range.end))) {
                break;
            }
            this.setJsonMember(containerPath.slice(0, -1), containerPath[k - 1], undefined);
        }
        this.compute(false);
    };

    // The tooltips of the given panel, before it is emptied : none stays
    // open over nothing.
    LadbModalHardwareEditor.prototype.destroyTooltips = function ($panel) {
        $('[data-toggle="tooltip"]', $panel).tooltip('destroy');
    };

    LadbModalHardwareEditor.prototype.renderComputations = function () {
        const that = this;

        this.showBenchMeasure(null);   // Its row is removed : no mouseleave
        this.destroyTooltips(this.$computations);
        this.$computations.empty();
        if (this.response.supported !== true) {
            return;
        }

        const variables = this.response.variables || [];
        const asserts = this.response.asserts || [];
        const measures = this.response.measures || [];

        const $table = $('<table class="table table-condensed">');

        const fnSlotsLabel = function (results, result) {
            return results.length > 1 ? '<span class="ladb-hardware-editor-slots">' + result.slots.join(', ') + '</span> ' : '';
        };

        // Measures of the bench
        if (measures.length > 0) {
            $table.append($('<tr class="ladb-hardware-editor-computations-header">').append($('<th colspan="3">').text(i18next.t('core.hardware_editor.measures'))));
            for (const measure of measures) {
                const $row = $('<tr>')
                    .append($('<td class="ladb-hardware-editor-computation-name">').text('@' + measure.name))
                    .append($('<td>'))
                    .append($('<td class="ladb-hardware-editor-computation-value">').text(measure.text));
                if (measure.cote) {
                    // Hovered : its cote in the viewer
                    const slot = measure.name.slice(-1);
                    $row
                        .addClass('ladb-hardware-editor-measure')
                        .on('mouseenter', function () {
                            that.showBenchMeasure({ slot: slot, from: measure.cote[0], to: measure.cote[1], text: measure.text });
                        })
                        .on('mouseleave', function () {
                            that.showBenchMeasure(null);
                        });
                }
                $table.append($row);
            }
        }

        // Variables, per group of slots they are the same for
        if (variables.length > 0) {
            $table.append($('<tr class="ladb-hardware-editor-computations-header">').append($('<th colspan="3">').text(i18next.t('core.hardware_editor.variables'))));
            for (const variable of variables) {
                const $value = $('<td class="ladb-hardware-editor-computation-value">');
                for (const result of variable.results) {
                    const $result = $('<div>').html(fnSlotsLabel(variable.results, result));
                    if (result.error) {
                        $result
                            .addClass('text-danger')
                            .append($('<span>').text(this.errorLabel(result.error)));
                    } else {
                        $result.append($('<span>').text(result.text));
                    }
                    $value.append($result);
                }
                $table.append($('<tr>')
                    .append($('<td class="ladb-hardware-editor-computation-name">')
                        .text('@' + variable.name)
                        .append(variable.setting ? ' <i class="ladb-opencutlist-icon-settings" title="' + i18next.t('core.hardware_editor.setting') + '"></i>' : '')
                    )
                    .append($('<td class="ladb-hardware-editor-computation-expression">').text(variable.setting ? '' : variable.expression))
                    .append($value)
                );
            }
        }

        // Asserts, both sides in numbers
        if (asserts.length > 0) {
            $table.append($('<tr class="ladb-hardware-editor-computations-header">').append($('<th colspan="3">').text(i18next.t('core.hardware_editor.asserts'))));
            for (const assert of asserts) {
                const $value = $('<td class="ladb-hardware-editor-computation-value">');
                let ok = true;
                for (const result of assert.results) {
                    ok = ok && result.ok;
                    const $result = $('<div>')
                        .addClass(result.ok ? 'text-success' : 'text-danger')
                        .html(fnSlotsLabel(assert.results, result));
                    $result.append($('<span>').text(this.assertText(result)));
                    $result.append(' <i class="ladb-opencutlist-icon-' + (result.ok ? 'check-mark' : 'warning') + '"></i>');
                    $value.append($result);
                }
                $table.append($('<tr' + (ok ? '' : ' class="danger"') + '>')
                    .append($('<td class="ladb-hardware-editor-computation-expression" colspan="2">').text(assert.expression))
                    .append($value)
                );
            }
        }

        this.$computations.append($table);

    };

    LadbModalHardwareEditor.prototype.renderSettings = function () {
        const that = this;

        const settings = this.response.settings || [];
        let options = {};
        let ownUnit;
        try {
            const data = JSON.parse(this.cm.getValue());
            if (data.options !== null && typeof data.options === 'object' && !Array.isArray(data.options)) {
                options = data.options;
            }
            ownUnit = data.length_unit;
        } catch (e) {
            // The JSON is being typed : the response's type says what to show
        }
        const optionGroups = TOOL_OPTION_GROUPS[this.response.type] || [];
        const inheritedData = this.inheritedData();
        const inheritance = this.response.inheritance || null;
        const inheritedOptions = inheritedData ? fnObject(inheritedData.options) : {};
        const signature = JSON.stringify([
            settings.map(function (setting) { return [ setting.name, setting.raw, setting.inherited ]; }),
            this.response.type,
            options,
            ownUnit,
            inheritedOptions,
            inheritance ? inheritance.parents : null,
            inheritance ? inheritance.parent_data : null,
            this.readonly
        ]);
        if (signature === this._settingsSignature) {
            return;
        }
        this._settingsSignature = signature;

        const focus = this.captureFocus(this.$settings);
        this.destroyTooltips(this.$settings);
        this.$settings.empty();

        this.$settings.append($('<div class="ladb-hardware-editor-settings-title">').text(i18next.t('core.hardware_editor.settings_variables')));

        if (settings.length === 0) {
            this.$settings.append($('<div class="ladb-hardware-editor-empty">').html(i18next.t('core.hardware_editor.no_settings')));
        }

        for (const setting of settings) {

            const raw = setting.raw;
            const $formGroup = $('<div class="form-group">');
            const $label = $('<label class="control-label col-xs-4">').text(setting.label || setting.name);
            const $control = $('<div class="col-xs-7">');
            const $inheritance = $('<div class="col-xs-1 ladb-hardware-editor-inheritance-cell">');
            $formGroup
                .append($label)
                .append($control)
                .append($inheritance);
            const settingPath = [ 'variables', setting.name ];
            this.appendInheritanceIcon($inheritance, this.inheritanceState(settingPath, !setting.inherited), settingPath);   // Set : overridden in its own data
            $formGroup.toggleClass('ladb-hardware-editor-inherited', $inheritance.hasClass('ladb-hardware-editor-inherited'));

            if (Array.isArray(raw.steps)) {

                // A value among its steps
                const $select = $('<select class="form-control">');
                for (const step of raw.steps) {
                    $select.append($('<option>')
                        .attr('value', step)
                        .text(step)
                    );
                }
                $select
                    .val(raw.value)
                    .prop('disabled', this.readonly)
                    .on('change', function () {
                        that.setSettingValue(setting.name, $(this).val());
                    });
                $control.append($select);
                $select.selectpicker(SELECT_PICKER_MODAL_OPTIONS);

            } else {

                // Any length, between its bounds if it has any
                const $input = $('<input type="text" class="form-control">');
                $control.append($input);
                $input
                    .val(typeof raw.value === 'string' ? fnLengthText(raw.value) : '')
                    .ladbTextinputDimension({ resetValue: '' })
                    .on('change', function () {
                        const value = fnLengthJson($(this).val());
                        if (value !== raw.value) {
                            that.setSettingValue(setting.name, value);
                        }
                    });
                if (setting.min || setting.max) {
                    $control.append($('<div class="help-block">').text(i18next.t('core.hardware_editor.setting_bounds', {
                        min: setting.min ? setting.min.text : '-',
                        max: setting.max ? setting.max.text : '-'
                    })));
                }

            }

            if (this.readonly) {
                $('input', $control).prop('disabled', true);
            }

            this.$settings.append($formGroup);

        }

        // The tool's options : their defaults, written in the JSON's 'options'
        if (optionGroups.length > 0) {
            this.$settings
                .append($('<div class="ladb-hardware-editor-settings-title">').text(i18next.t('core.hardware_editor.settings_tool_options')))
                .append($('<div class="help-block ladb-hardware-editor-settings-help">').text(i18next.t('core.hardware_editor.settings_tool_options_help')));
            for (const optionGroup of optionGroups) {
                const $formGroup = $('<div class="form-group">');
                const $control = $('<div class="col-xs-7 ladb-hardware-editor-tool-options">');
                $formGroup
                    .append($('<label class="control-label col-xs-4">').text(i18next.t(optionGroup.text ? 'core.hardware_editor.tool_options_' + optionGroup.group : 'tool.smart_join.action_option_group_' + optionGroup.group)))
                    .append($control);
                for (const name of optionGroup.options) {
                    const value = options[name] === undefined || options[name] === null ? '' : String(options[name]);
                    const inheritedValue = inheritedOptions[name] === undefined || inheritedOptions[name] === null ? '' : String(inheritedOptions[name]);
                    const $input = $('<input type="text" class="form-control">');
                    const $field = $('<div class="ladb-hardware-editor-tool-option-field">').append($input);
                    const $option = $('<div class="ladb-hardware-editor-tool-option">').append($field);
                    this.appendInheritanceIcon($field, this.inheritanceState([ 'options', name ], options[name] !== undefined), [ 'options', name ]);
                    if (optionGroup.text) {
                        // A name : empty, the option removed - inherited again
                        if (value === '' && inheritedValue !== '') {
                            $input.attr('placeholder', inheritedValue);   // Typed : overridden
                        }
                        $input
                            .val(value)
                            .ladbTextinputText({ resetValue: '' })
                            .on('change', function () {
                                const newValue = $(this).val().trim();
                                if (newValue !== value) {
                                    that.setOptionValue(name, newValue);
                                }
                            });
                    } else {
                        if (value === '' && inheritedValue !== '') {
                            $input.attr('placeholder', fnLengthText(inheritedValue));   // Typed : overridden
                        }
                        $input
                            .val(fnLengthText(value))
                            .ladbTextinputDimension({ resetValue: '' })   // Reset : the option removed - inherited again
                            .on('change', function () {
                                const newValue = fnLengthJson($(this).val().trim());
                                if (newValue !== value) {
                                    that.setOptionValue(name, newValue);
                                }
                            });
                    }
                    if (this.readonly) {
                        $('input', $option).prop('disabled', true);
                    }
                    if (optionGroup.text) {
                        $option.append($('<div class="help-block">').text(i18next.t('tool.smart_join.action_option_' + name)));
                    } else if (optionGroup.options.length > 1) {
                        $option.append($('<div class="help-block">').text(i18next.t('tool.smart_join.action_option_' + optionGroup.group + '_' + name)));
                    }
                    $control.append($option);
                }
                this.$settings.append($formGroup);
            }
        }

        // Its properties
        this.$settings.append($('<div class="ladb-hardware-editor-settings-title">').text(i18next.t('core.hardware_editor.settings_properties')));

        // Unit of its bare numbers - see "length_unit" - : read in it, not
        // converted. Its parents' when they have one, which it can't change.
        const parentUnit = fnObject(this.parentData()).length_unit;
        const unitInherited = typeof parentUnit === 'string';
        const unit = unitInherited ? parentUnit : (typeof ownUnit === 'string' ? ownUnit : '');
        const $unitGroup = $('<div class="form-group">');
        const $unitControl = $('<div class="col-xs-7">');
        const $unitInheritance = $('<div class="col-xs-1 ladb-hardware-editor-inheritance-cell">');
        $unitGroup
            .append($('<label class="control-label col-xs-4">').text(i18next.t('core.hardware_editor.length_unit')))
            .append($unitControl)
            .append($unitInheritance);
        this.appendInheritanceIcon($unitInheritance, unitInherited ? 'inherited' : null, null);   // Not clickable : it can't be overridden
        $unitGroup.toggleClass('ladb-hardware-editor-inherited', unitInherited);
        const $unitSelect = $('<select class="form-control">')
            .append($('<option value="">').text(i18next.t('core.hardware_editor.length_unit_none')));
        for (const unitOption of LENGTH_UNIT_OPTIONS) {
            $unitSelect.append($('<option>').attr('value', unitOption.unit).text(i18next.t('default.unit_' + unitOption.index) + ' (' + unitOption.unit + ')'));
        }
        if (unit !== '' && !LENGTH_UNIT_OPTIONS.some(function (unitOption) { return unitOption.unit === unit; })) {
            $unitSelect.append($('<option>').attr('value', unit).text(unit));   // Invalid : shown as is
        }
        $unitSelect
            .val(unit)
            .prop('disabled', this.readonly || unitInherited)
            .on('change', function () {
                const newUnit = $(this).val();
                if (that.setJsonMember([], 'length_unit', newUnit === '' ? undefined : newUnit)) {
                    that.compute(false);
                }
            });
        $unitControl
            .append($unitSelect)
            .append($('<div class="help-block">').append(i18next.t('core.hardware_editor.length_unit_help')));
        this.$settings.append($unitGroup);
        $unitSelect.selectpicker(SELECT_PICKER_MODAL_OPTIONS);

        this.restoreFocus(focus);

    };

    LadbModalHardwareEditor.prototype.renderErrors = function (errors) {

        errors = errors || this.response.errors || [];

        // An invalid JSON : where, as the browser's parser tells it - its line marked
        if (this._errorLine !== null) {
            this.cm.removeLineClass(this._errorLine, 'background', 'ladb-hardware-editor-error-line');
            this._errorLine = null;
        }
        const jsonError = this.jsonError();

        this.$errors.empty();
        if (errors.length > 0) {
            const $list = $('<ul>');
            for (const error of errors) {
                if (jsonError && error.indexOf('json:') === 0) {
                    this._errorLine = this.cm.addLineClass(jsonError.line, 'background', 'ladb-hardware-editor-error-line');
                    $list.append($('<li>').text(i18next.t('core.hardware_editor.error.invalid_json', { line: jsonError.line + 1, error: jsonError.message })));
                } else {
                    $list.append($('<li>').text(error));
                }
            }
            this.$errors.append($('<div class="alert alert-danger">').append($list));
        }
        this.$errorCount
            .text(errors.length)
            .toggle(errors.length > 0);

    };

    // The cote of a measure in the viewer - its row hovered - : { slot, from,
    // to, text }, null for none - see HardwareBenchDef#measure_cotes.
    LadbModalHardwareEditor.prototype.showBenchMeasure = function (measure) {
        const $threeViewer = $('.ladb-three-viewer', this.$viewer);
        if ($threeViewer.length > 0 && $threeViewer.data('ladb.threeviewer').loaded) {
            $threeViewer.ladbThreeViewer('callCommand', [ 'show_bench_measure', { measure: measure } ]);
        }
    };

    // The cotes of the hinge's axis in the viewer - its pivot row hovered or
    // edited - or none.
    LadbModalHardwareEditor.prototype.showBenchHingeCotes = function (visible) {
        const $threeViewer = $('.ladb-three-viewer', this.$viewer);
        if ($threeViewer.length > 0 && $threeViewer.data('ladb.threeviewer').loaded) {
            $threeViewer.ladbThreeViewer('callCommand', [ 'show_bench_hinge_cotes', { visible: visible } ]);
        }
    };

    // The label of the solid hovered in the viewer - { label, rect } - as a
    // tooltip beside it - over it, under when there is no room - , or none.
    LadbModalHardwareEditor.prototype.showBenchHover = function (data) {

        if (!this.$benchHoverAnchor) {
            const that = this;
            this.$benchHoverAnchor = $('<span class="ladb-hardware-editor-hover-anchor">')
                .appendTo(this.$viewer)
                .tooltip({
                    trigger: 'manual',
                    container: this._$modal,   // Removed with it : never left behind
                    placement: 'auto top',
                    viewport: this.$viewer,   // Where 'auto' looks for room
                    animation: false,
                    title: function () { return that._benchHoverLabel; }
                });
        }

        if (data) {
            this._benchHoverLabel = data.label;
            this.$benchHoverAnchor
                .css(data.rect)   // Around the solid - the iframe fills the viewer
                .tooltip('show');
        } else {
            this.$benchHoverAnchor.tooltip('hide');
        }

    };

    LadbModalHardwareEditor.prototype.renderStatus = function () {

        $('.ladb-hardware-editor-readonly-badge', this.$element).toggle(this.readonly);

        // The verdict, over the viewer
        const $verdict = $('.ladb-hardware-editor-verdict', this.$element).empty();
        if (this.response.supported !== true) {
            $verdict.hide();
            return;
        }
        const accepted = this.response.accepted === true;
        $verdict
            .toggleClass('ladb-hardware-editor-verdict-accepted', accepted)
            .toggleClass('ladb-hardware-editor-verdict-refused', !accepted)
            .append(accepted ? '<i class="ladb-opencutlist-icon-check-mark"></i> ' : '<i class="ladb-opencutlist-icon-warning"></i> ')
            .append($('<span>').text(i18next.t(accepted ? 'core.hardware_editor.accepted' : 'core.hardware_editor.refused')))
            .show();

    };

    // Parts /////

    LadbModalHardwareEditor.prototype.renderParts = function () {
        const that = this;

        let data;
        try {
            data = JSON.parse(this.cm.getValue());
        } catch (e) {
            return; // The JSON is being typed : the parts stay
        }

        // Extends another : its merged data is shown, what it only inherits
        // greyed - a part read only until overridden, see appendInheritanceIcon.
        const own = data;
        const inheritedData = this.inheritedData();
        if (inheritedData) {
            data = inheritedData;
        }
        const fnOwns = function (path) {
            return !inheritedData || fnHasPath(own, path);
        };

        const components = data.components && typeof data.components === 'object' ? data.components : {};
        const slots = Object.keys(components);

        const focus = this.captureFocus(this.$parts);
        // Emptied, its pane would scroll back to the top : put back where it was
        const $scroller = this.$parts.closest('.tab-pane');
        const scrollTop = $scroller.scrollTop();
        this.destroyTooltips(this.$parts);
        this.$parts.empty();
        for (const slot of slots) {

            const component = components[slot];
            const slotPath = [ 'components', slot ];
            const slotResponse = (this.response.slots || {})[slot];
            const resolved = slotResponse ? slotResponse.component : null;
            const $slot = $('<div class="ladb-hardware-editor-slot">');
            const $head = $('<div class="ladb-hardware-editor-slot-head">')
                .append($('<span class="ladb-hardware-editor-slot-letter">').text(slot.toUpperCase()))
                .append($('<span class="ladb-hardware-editor-slot-name">').text(resolved && resolved.name ? resolved.name : (data.name || '')));
            $slot.append($head);
            this.$parts.append($slot);

            // Nothing to edit in it : said, and where from
            const fnNote = function (text) {
                const $note = $('<div class="ladb-hardware-editor-slot-note">').append($('<span>').text(text));
                $slot.append($note);
                that.appendInheritanceIcon($note, that.inheritanceState(slotPath, fnOwns(slotPath)) === 'inherited' ? 'inherited' : null, null);
            };
            if (!component || typeof component !== 'object') {
                fnNote(i18next.t('core.hardware_editor.parts_no_component'));
                continue;
            }
            if (component.same_as || component.mirror_of) {
                fnNote(i18next.t('core.hardware_editor.parts_' + (component.same_as ? 'same_as' : 'mirror_of'), { slot: String(component.same_as || component.mirror_of).toUpperCase() }));
                continue;
            }

            // Its name - the descriptor's one if it has none
            $slot.append(this.renderPartName([ 'components', slot ], component, 'part_name', data.name || '', fnOwns));

            // A component with variants : the one on the bench - the others by the trial
            let path = [ 'components', slot ];
            let target = component;
            if (component.variants && typeof component.variants === 'object') {
                const variant = resolved ? resolved.variant : slotResponse ? slotResponse.variant || null : null;   // Empty : not resolved, but on the bench
                if (this.response.type === 'hinge' && component.variants.items) {
                    const $variants = $('<div class="btn-group btn-group-xs">');
                    for (const key of Object.keys(component.variants.items)) {
                        $variants.append($('<button type="button" class="btn btn-default">')
                            .toggleClass('active', key === variant)
                            .text(this.topologyLabel(key))
                            .on('click', function () {
                                this.blur();
                                that.topology = key;
                                that.compute(false);
                            })
                        );
                    }
                    $head.append($variants);
                }
                target = variant && component.variants.items ? component.variants.items[variant] : null;
                if (!target || typeof target !== 'object') {
                    $slot.append($('<div class="ladb-hardware-editor-slot-note">').text(i18next.t('core.hardware_editor.parts_no_variant')));
                    continue;
                }
                path = path.concat([ 'variants', 'items', variant ]);
                $slot.append(this.renderPartName(path, target, 'variant_name', '', fnOwns));
            }

            for (const part of PARTS) {
                const partPath = path.concat([ part ]);
                const $part = this.renderPart(data, slot, path, target, part, slots);
                const state = this.inheritanceState(partPath, fnOwns(partPath));
                this.appendInheritanceIcon($part, state, partPath);
                if (state === 'inherited') {
                    this.disableInherited($('.ladb-hardware-editor-part-body', $part));   // Overridden first, by its icon
                }
                $slot.append($part);
            }

            // A hinge : what the door turns by
            if (this.response.type === 'hinge' && slot === 'a') {
                this.renderHingeKinematics($slot, [ 'components', slot ], component, target === component ? null : path, target);
            }

        }

        $scroller.scrollTop(scrollTop);
        this.restoreFocus(focus);
        this.dialog.setupTooltips(this.$parts);
        this.showBenchPrimitive();

    };

    // Nothing to edit in the given element : what it shows is inherited -
    // see appendInheritanceIcon.
    LadbModalHardwareEditor.prototype.disableInherited = function ($element) {
        $('input, select, button', $element).prop('disabled', true);
        $('select', $element).selectpicker('refresh');
        $('a', $element).not(function () { return $(this).closest('.bootstrap-select').length > 0; }).remove();
    };

    // The given part of a slot : its list - articles, or a machining - empty
    // when it has none, else the slot it is the same as. Linked to another
    // slot while it has nothing of its own.
    LadbModalHardwareEditor.prototype.renderPart = function (data, slot, path, target, part, slots) {
        const that = this;

        const value = target[part];
        const sameAs = value && typeof value === 'object' && value.same_as ? value.same_as : null;

        const $row = $('<div class="ladb-hardware-editor-part">');
        const $body = $('<div class="ladb-hardware-editor-part-body">');
        $row
            .append($('<label class="control-label">').text(i18next.t('core.hardware_descriptor.part_' + part)))
            .append($body);

        const fnLink = function (other) {
            return $('<button type="button" class="btn btn-default btn-xs ladb-hardware-editor-part-link">')
                .append($('<i>').addClass(other === sameAs ? 'ladb-opencutlist-icon-check-box-with-check-sign' : 'ladb-opencutlist-icon-check-box')).append(' ')
                .append(i18next.t('core.hardware_editor.part_kind_same_as', { slot: other.toUpperCase() }))
                .toggleClass('active', other === sameAs)
                .prop('disabled', that.readonly)
                .on('click', function () {
                    this.blur();
                    that.setPartKind(path, part, other === sameAs ? 'none' : 'same_as:' + other);
                });
        };

        // A row in place of a list : "None", or the slot it is the same as
        const fnNoneList = function (text) {
            return $('<div class="ladb-hardware-editor-primitive-list">')
                .append($('<div class="ladb-hardware-editor-primitive-head ladb-hardware-editor-primitive-none">').text(text));
        };

        if (sameAs !== null) {
            $body.append($('<div class="ladb-hardware-editor-primitives">')
                .append(fnNoneList(i18next.t('core.hardware_editor.part_kind_same_as', { slot: sameAs.toUpperCase() })))
                .append($('<div class="ladb-hardware-editor-part-buttons ladb-hardware-editor-add-buttons">')
                    .append(fnLink(sameAs))
                )
            );
            return $row;
        }

        if (part === 'machining') {
            this.renderMachining($body, slot, path.concat([ part ]), value);
        } else {
            $body.append(this.renderArticles(slot, path.concat([ part ]), value));
        }

        // Nothing of its own : a "None" row in place of its list, the slots it
        // can be the same as after the adds
        const empty = part === 'machining' ? fnIsEmptyMachining(value) : Object.keys(this.hardwareArticles(value).articles).length === 0;
        if (empty) {
            const $primitives = $body.children('.ladb-hardware-editor-primitives').first();
            if ($primitives.children('.ladb-hardware-editor-primitive-list').length === 0) {
                $primitives.prepend(fnNoneList(i18next.t('core.hardware_editor.part_kind_none')));
            }
            const $adds = $body.find('.ladb-hardware-editor-add-buttons').first();
            $adds.append(slots.filter(function (s) { return s !== slot; }).map(fnLink));
        }

        return $row;
    };

    // The machining at the given path : its primitives, its SKP file - when
    // it has one - the first of their rows, the button adding one beside
    // theirs.
    LadbModalHardwareEditor.prototype.renderMachining = function ($body, slot, partPath, value) {
        const that = this;

        const skp = fnIsSkp(value) ? value : fnObject(value).skp;
        const $primitives = this.renderPrimitives(slot, partPath, 'machining', fnObject(value));
        if (fnIsSkp(skp)) {
            let $list = $primitives.children('.ladb-hardware-editor-primitive-list');
            if ($list.length === 0) {
                $list = $('<div class="ladb-hardware-editor-primitive-list">');
                $primitives.prepend($list);
            }
            $list.prepend(this.renderSkpRow(slot, 'machining', function () {
                // null over its parents' : not inherited again
                that.setMachiningMember(partPath, 'skp', that.inheritanceState(partPath.concat([ 'skp' ]), false) === null ? undefined : null);
            }));
        } else {
            $('.ladb-hardware-editor-add-buttons', $primitives).prepend($('<button type="button" class="btn btn-default btn-xs">')
                .append('<i class="ladb-opencutlist-icon-plus"></i> ')
                .append(i18next.t('core.hardware_editor.machining_skp_add'))
                .prop('disabled', this.readonly)
                .on('click', function () {
                    this.blur();
                    that.setMachiningMember(partPath, 'skp', true);
                })
            );
        }
        $body.append($primitives);
    };

    // The row of the SKP file of the given part : its head - its name, where
    // it stands, the X removing it by the given function - then, open - by
    // default - what can be done of it, as an article's.
    LadbModalHardwareEditor.prototype.renderSkpRow = function (slot, part, onRemove) {
        const that = this;

        const id = slot + '/' + part;
        const open = !this.skpRowClosed[id];
        const skp = (this.response.skps || []).find(function (skp) { return skp.slot === slot && skp.part === part && !skp.article; });
        const ref = skp ? skp.ref : null;
        const imported = ref ? this.imports[ref] : null;

        const $row = $('<div class="ladb-hardware-editor-primitive ladb-hardware-editor-article">')
            .toggleClass('ladb-hardware-editor-primitive-open', open);

        // Its file, buttons and placement : the chip goes to the head
        const $file = $('<div>');
        this.renderSkpFile($file, skp);
        const $chip = $file.find('.ladb-hardware-editor-file > .label').addClass('ladb-hardware-editor-article-chip');

        // Head
        const $head = $('<div class="ladb-hardware-editor-primitive-head">')
            .append($('<span class="ladb-hardware-editor-primitive-caret">').text('▸'))
            .append($('<span class="ladb-hardware-editor-primitive-name">').text(i18next.t('core.hardware_editor.part_kind_skp')))
            .append($('<span class="ladb-hardware-editor-primitive-summary">')
                // .append(ref ? $('<code>').text(imported ? imported.name : ref.split('/').pop()) : null)
            )
            .append($chip)
            .append($('<span class="ladb-hardware-editor-primitive-tools">')
                .append(fnTooltip($('<button type="button" class="btn btn-default btn-xs">'), i18next.t('default.delete'))
                    .append($('<i class="ladb-opencutlist-icon-clear">'))
                    .prop('disabled', this.readonly)
                    .on('click', function (e) {
                        e.stopPropagation();
                        this.blur();
                        onRemove();
                    })
                )
            )
            .on('click', function () {
                that.skpRowClosed[id] = open;
                that.renderParts();
            });
        $row.append($head);

        if (open) {
            // Its name and buttons in the fields column, its placement below, wide - see renderArticleEditor
            const $editor = $('<div class="ladb-hardware-editor-primitive-editor ladb-hardware-editor-article-editor">');
            $editor
                .append($('<div class="ladb-hardware-editor-primitive-label">').text(i18next.t('core.hardware_editor.article_file')))
                .append($file.children('.ladb-hardware-editor-file'));
            const $buttons = $file.children('.ladb-hardware-editor-part-buttons');
            if ($buttons.length > 0) {
                $editor
                    .append($('<div class="ladb-hardware-editor-primitive-label">'))
                    .append($buttons);
            }
            if ($file.children().length > 0) {
                $editor.append($file.addClass('ladb-hardware-editor-article-wide'));
            }
            $row.append($editor);
        }

        return $row;
    };

    // The SKP file of a part - or an article - on the bench, the given one
    // of the response : its name, where it stands, what can be done of it.
    LadbModalHardwareEditor.prototype.renderSkpFile = function ($body, skp) {
        const that = this;

        const ref = skp ? skp.ref : null;
        const imported = ref ? this.imports[ref] : null;
        const mesh = ref ? this.meshes[this.skpSource(ref)] : null;
        const missing = !mesh || mesh.error;
        const placeable = ref && !this.readonly && mesh && !mesh.error && mesh !== 'loading';

        const $file = $('<div class="ladb-hardware-editor-file">');
        if (ref) {
            $file.append($('<code>').text(imported ? imported.name : ref.split('/').pop()));
        }
        const $chip = $('<span class="label">');
        const $placedDot = $('<span class="ladb-hardware-editor-placement-dot">');
        // Updated in place as the placement changes - see renderPlacement
        const fnUpdateChip = function () {
            const placed = ref && that.placements[ref] && !fnIsIdentity(that.placements[ref]);
            let chip;
            if (!ref) {
                chip = [ 'danger', 'chip_no_folder' ];
            } else if (imported) {
                chip = [ 'warning', imported.edited ? 'chip_edited' : 'chip_imported' ];
            } else if (mesh === undefined || mesh === 'loading') {
                chip = [ 'default', 'chip_loading' ];
            } else if (missing) {
                chip = [ 'danger', 'chip_missing' ];
            } else if (placed) {
                chip = [ 'warning', 'chip_placed' ];
            } else {
                chip = [ 'default', ref.indexOf('$OCL/') === 0 ? 'chip_bundled' : 'chip_user' ];
            }
            $chip
                .attr('class', 'label label-' + chip[0])
                .text(i18next.t('core.hardware_editor.' + chip[1]));
            $placedDot.toggle(!!placed);
        };
        fnUpdateChip();
        $file.append($chip);
        $body.append($file);

        let $placement = null;

        if (ref && !this.readonly) {
            const $buttons = $('<div class="ladb-hardware-editor-part-buttons">');
            $buttons.append($('<button type="button" class="btn btn-default btn-xs">')
                .append(i18next.t('default.' + (missing && !imported ? 'import' : 'replace')) + '...')
                .on('click', function () {
                    this.blur();
                    that.chooseSkp(ref);
                })
            );
            const shapeable = mesh !== undefined && mesh !== 'loading' && (!mesh.error || mesh.error === 'not_found' || mesh.error === 'empty');
            if (shapeable) {
                $buttons.append($('<button type="button" class="btn btn-default btn-xs">')
                    .text(i18next.t('core.hardware_editor.' + (missing ? 'create_in_sketchup' : 'edit_in_sketchup')))
                    .on('click', function () {
                        this.blur();
                        that.startShaping(skp);
                    })
                );
            }
            if (placeable) {
                $buttons.append($('<button type="button" class="btn btn-default btn-xs">')
                    .toggleClass('active', !!this.placementOpens[ref])
                    .append($placedDot)
                    .append(i18next.t('core.hardware_editor.placement_toggle'))
                    .on('click', function () {
                        this.blur();
                        that.placementOpens[ref] = !that.placementOpens[ref];
                        $(this).toggleClass('active', that.placementOpens[ref]);
                        $placement.toggle(that.placementOpens[ref]);
                    })
                );
            }
            $body.append($buttons);
        }
        if (placeable) {
            $placement = this.renderPlacement(ref, fnUpdateChip).toggle(!!this.placementOpens[ref]);
            $body.append($placement);
        }

    };

    // Articles /////

    // The path of the hardware part of the given slot on the bench - of its
    // variant if it has.
    LadbModalHardwareEditor.prototype.articlesPath = function (slot) {
        const slotResponse = (this.response.slots || {})[slot];
        const variant = slotResponse && slotResponse.component ? slotResponse.component.variant : null;
        return [ 'components', slot ].concat(variant ? [ 'variants', 'items', variant ] : []).concat([ 'hardware' ]);
    };

    // A copy of the value at the given path of the JSON - an index for an
    // array item - undefined if there is none or the JSON is being typed.
    LadbModalHardwareEditor.prototype.jsonValue = function (path) {
        let value;
        try {
            value = JSON.parse(this.cm.getValue());
        } catch (e) {
            return undefined;
        }
        for (const key of path) {
            if (value === null || typeof value !== 'object' || !Object.prototype.hasOwnProperty.call(value, key)) {
                return undefined;
            }
            value = value[key];
        }
        return value;
    };

    // What the bench tells of the given article of the given slot - see
    // HardwareBenchComputeWorker#_articles - null if it isn't on it.
    LadbModalHardwareEditor.prototype.articleResponse = function (slot, key) {
        const slotResponse = (this.response.slots || {})[slot];
        const articles = slotResponse && slotResponse.component ? slotResponse.component.articles || [] : [];
        return articles.find(function (article) { return article.key === key; }) || null;
    };

    // The articles of the given hardware part - at the given path - : one
    // row each, the open one edited in place, then the buttons to add one
    // of each kind.
    LadbModalHardwareEditor.prototype.renderArticles = function (slot, partPath, value) {
        const that = this;

        const view = this.hardwareArticles(value);
        const $articles = $('<div class="ladb-hardware-editor-primitives">');
        const $list = $('<div class="ladb-hardware-editor-primitive-list">');
        for (const key of Object.keys(view.articles)) {
            if (view.articles[key] === null || typeof view.articles[key] !== 'object') {
                continue;   // Removed from an inherited one
            }
            $list.append(this.renderArticle(slot, partPath, key, view.articles[key], view.articles, view.implicit));
        }
        if ($list.children().length > 0) {
            $articles.append($list);
        }

        const $adds = $('<div class="ladb-hardware-editor-part-buttons ladb-hardware-editor-add-buttons">');
        for (const kind of [ 'skp', 'primitives', 'connector' ]) {
            if (kind === 'connector' && this.response && this.response.type === 'connector') {
                continue;   // A connector can't use another one
            }
            $adds.append($('<button type="button" class="btn btn-default btn-xs">')
                .append('<i class="ladb-opencutlist-icon-plus"></i> ' + i18next.t('core.hardware_editor.article_add_' + kind))
                .prop('disabled', this.readonly)
                .on('click', function () {
                    this.blur();
                    that.addArticle(slot, partPath, kind);
                })
            );
        }
        $articles.append($adds);

        // A connector to choose for a new one
        if (this.connectorBrowser && this.connectorBrowser.slot === slot && this.connectorBrowser.key === null) {
            $articles.append(this.renderConnectorBrowser());
        }

        return $articles;
    };

    // The row of the given article : its head - name, kind, how many times
    // it is laid, whether the bench refuses it - then, open, its fields.
    LadbModalHardwareEditor.prototype.renderArticle = function (slot, partPath, key, article, articles, implicit) {
        const that = this;

        const id = fnArticleId({ slot: slot, key: key });
        const open = id === fnArticleId(this.articleOpen);
        const kind = fnArticleKind(article);
        const response = implicit ? null : this.articleResponse(slot, key);   // The bench tells of a short form as of a part
        const articlePath = partPath.concat([ key ]);

        const $row = $('<div class="ladb-hardware-editor-primitive ladb-hardware-editor-article">')
            .toggleClass('ladb-hardware-editor-primitive-open', open)
            .attr('data-article', id);

        // Head
        const count = Array.isArray(article.at) ? article.at.length : 1;
        const name = (implicit ? fnObject(this.jsonValue(partPath.slice(0, -1))).name : article.name) || (response ? response.used_name : null);   // A short form : its slot's
        const $head = $('<div class="ladb-hardware-editor-primitive-head">')
            .append($('<span class="ladb-hardware-editor-primitive-caret">').text('▸'))
            .append(name ? $('<span class="ladb-hardware-editor-primitive-name">').text(name) : null)   // Unnamed : the key alone tells it
            .append($('<span class="ladb-hardware-editor-primitive-summary">')
                .append($('<code>').text(key))
                .append(' · ' + i18next.t('core.hardware_editor.article_kind_' + kind) + (count > 1 ? ' × ' + count : ''))
            );
        if (response && response.ok === false) {
            $head.append($('<span class="label label-danger ladb-hardware-editor-article-chip">').text(i18next.t('core.hardware_editor.' + (response.missing ? 'article_missing' : 'article_refused'))));
        }
        $head
            .append($('<span class="ladb-hardware-editor-primitive-tools">')
                .append(fnTooltip($('<button type="button" class="btn btn-default btn-xs">'), i18next.t('default.delete'))
                    .append($('<i class="ladb-opencutlist-icon-clear">'))
                    .prop('disabled', this.readonly)
                    .on('click', function (e) {
                        e.stopPropagation();
                        this.blur();
                        that.deleteArticle(slot, partPath, key);
                    })
                )
            )
            .on('click', function () {
                that.articleOpen = open ? null : { slot: slot, key: key };
                that.connectorBrowser = null;
                that.renderParts();
            })
            .on('mouseenter', function () {
                that.articleHovered = { slot: slot, key: key };
                that.showBenchPrimitive();
            })
            .on('mouseleave', function () {
                that.articleHovered = null;
                that.showBenchPrimitive();
            });
        $row.append($head);

        if (open) {
            $row.append(this.renderArticleEditor(slot, partPath, key, article, articles, response, implicit));
        }

        return $row;
    };

    // A length field of an article : written by the given function as
    // typed, what the bench gives of it beside it - see renderPrimitiveEditor.
    LadbModalHardwareEditor.prototype.renderArticleField = function (value, field, onInput, options) {
        options = options || {};
        const $cell = $('<div class="ladb-hardware-editor-placement-cell ladb-hardware-editor-primitive-cell">')
            .addClass(options.axis ? 'ladb-hardware-editor-placement-' + options.axis : 'ladb-hardware-editor-primitive-neutral')
            .toggleClass('ladb-hardware-editor-primitive-invalid', !!(field && field.error))
            .toggleClass('ladb-hardware-editor-article-overridden', !!options.overridden);
        if (options.tag) {
            $cell.append($('<span class="ladb-hardware-editor-primitive-tag">').text(options.tag));
        }
        const $input = $('<input type="text" class="form-control input-sm ladb-hardware-editor-live" spellcheck="false">')
            .val(fnPrimitiveText(value))
            .attr('placeholder', options.placeholder || '')
            .prop('disabled', this.readonly);
        $cell.append($input);
        $input
            .ladbTextinputDimension({ resetValue: '' })
            .on('input change', function () {
                onInput($(this).val().trim());
            });
        const $value = $('<span class="ladb-hardware-editor-primitive-value">');
        if (field && field.error) {
            $value.html('<i class="ladb-opencutlist-icon-warning"></i>');
            fnTooltip($cell, this.errorLabel(field.error));
        } else if (field && field.text && typeof value === 'string' && !/^-?\d+(?:[.,]\d+)?\s*[a-z"']*$/i.test(value.trim())) {
            $value.text('= ' + field.text);   // An expression : what it gives
        }
        $cell.append($value);
        return $cell;
    };

    // The fields of the given article : its key, what it is - its own file
    // or primitives, or a connector of the library - and where it is laid.
    LadbModalHardwareEditor.prototype.renderArticleEditor = function (slot, partPath, key, article, articles, response, implicit) {
        const that = this;

        const kind = fnArticleKind(article);
        const articlePath = partPath.concat([ key ]);

        const $editor = $('<div class="ladb-hardware-editor-primitive-editor ladb-hardware-editor-article-editor">')
            .on('focusin focusout', function (e) {
                $editor.toggleClass('ladb-hardware-editor-primitive-typing', e.type === 'focusin' && fnTypedIn($editor, e.target));
            });
        // The editor is 2 columns : a label, then its row - a title, and
        // what follows it, on both
        const fnLabel = function (label, params) {
            $editor.append($('<div class="ladb-hardware-editor-primitive-label">').text(label === null ? '' : i18next.t('core.hardware_editor.' + label, params)));
        };
        const fnTitle = function (label) {
            $editor.append($('<div class="ladb-hardware-editor-primitive-label ladb-hardware-editor-article-wide">').text(i18next.t('core.hardware_editor.' + label)));
        };
        const fnRow = function ($content) {
            const $row = $('<div class="ladb-hardware-editor-primitive-fields">').append($content);
            $editor.append($row);
            return $row;
        };
        const fnSeparator = function () {
            $editor.append($('<div class="ladb-hardware-editor-primitive-separator">'));
        };
        const fnSet = function (name, value) {
            that.setArticleMember(partPath, key, name, value);
        };

        // Its key : names its SKP file, unique in the slot
        fnLabel('article_key');
        const $help = $('<div class="help-block text-danger">');
        const $keyCell = $('<div class="ladb-hardware-editor-placement-cell ladb-hardware-editor-primitive-cell ladb-hardware-editor-primitive-neutral ladb-hardware-editor-primitive-text">');
        const $key = $('<input type="text" class="form-control input-sm" spellcheck="false">')
            .val(key)
            .prop('disabled', this.readonly)
            .on('input', function () {
                const error = that.articleKeyError($(this).val().trim(), key, articles);
                $keyCell.toggleClass('ladb-hardware-editor-primitive-invalid', error !== null);
                $help.text(error !== null ? i18next.t('core.hardware_editor.' + error) : '');
            })
            .on('change', function () {
                const newKey = $(this).val().trim();
                if (newKey !== key && that.articleKeyError(newKey, key, articles) === null) {
                    that.renameArticle(slot, partPath, key, newKey);
                }
            });
        fnRow($('<div class="ladb-hardware-editor-article-key">').append($keyCell.append($key)).append($help));

        if (kind === 'connector') {

            // The connector it uses, and how
            fnLabel('article_connector');
            const $connector = $('<div class="ladb-hardware-editor-file">');
            // Its name - its file when it has none, e.g. missing
            if (response && response.used_name) {
                $connector.append($('<span>').text(response.used_name));
            } else {
                $connector.append($('<code>').text(String(article.use).split('/').pop()));
            }
            if (response && response.missing) {
                $connector.append(' ').append($('<span class="label label-danger">').text(i18next.t('core.hardware_editor.article_missing')));
            }
            fnRow($connector.append(' ').append($('<button type="button" class="btn btn-default btn-xs">')
                .append(i18next.t('core.hardware_editor.article_replace') + '...')
                .toggleClass('active', !!(this.connectorBrowser && this.connectorBrowser.key === key && this.connectorBrowser.slot === slot))
                .prop('disabled', this.readonly)
                .on('click', function () {
                    this.blur();
                    if (that.connectorBrowser) {
                        that.connectorBrowser = null;
                        that.renderParts();
                    } else {
                        that.browseConnectors(slot, key, response && response.use ? response.use.substring(0, response.use.lastIndexOf('/')) : null);
                    }
                })
            ));
            if (this.connectorBrowser && this.connectorBrowser.key === key && this.connectorBrowser.slot === slot) {
                $editor.append(this.renderConnectorBrowser(function (file) {
                    that.connectorBrowser = null;
                    fnSet('use', file.use);
                }));
            }

            // Its side our panel is : the other one virtual
            const host = article.host === 'b' ? 'b' : 'a';
            const other = host === 'a' ? 'b' : 'a';
            fnLabel('article_host');
            const $hosts = $('<div class="btn-group btn-group-xs ladb-hardware-editor-primitive-segments">');
            for (const side of [ 'a', 'b' ]) {
                $hosts.append($('<button type="button" class="btn btn-default">')
                    .text(side.toUpperCase())
                    .toggleClass('active', side === host)
                    .prop('disabled', this.readonly)
                    .on('click', function () {
                        this.blur();
                        if (side === host) {
                            return;
                        }
                        // Its virtual side's thickness follows it
                        const measures = fnObject(that.jsonValue(articlePath.concat([ 'measures' ])));
                        const thickness = measures['thickness_' + other];
                        const newMeasures = {};
                        newMeasures['thickness_' + host] = thickness === undefined ? '2mm' : thickness;
                        that.setJsonMember(articlePath, 'host', side);
                        that.setJsonMember(articlePath, 'measures', newMeasures);
                        that.compute(false);
                    })
                );
            }
            fnRow($hosts);

            // The axis it goes into our panel along : by its face, or its edge
            const axis = article.axis === 'y' ? 'y' : 'z';
            fnLabel('article_axis');
            fnRow(fnSegments([ 'z', 'y' ].map(function (value) {
                return { value: value, axis: value };
            }), axis, this.readonly, function (option) {
                fnSet('axis', option.value === 'y' ? 'y' : undefined);
            }));

            fnLabel('article_virtual_thickness', { slot: other.toUpperCase() });
            const measure = 'thickness_' + other;
            fnRow(this.renderArticleField(fnObject(article.measures)[measure], response ? response.virtual : null, function (text) {
                const measures = $.extend({}, fnObject(that.jsonValue(articlePath.concat([ 'measures' ]))));
                measures[measure] = fnPrimitiveValue(text);
                fnSet('measures', measures);
            }, { tag: '@' + measure }));

            // Its settings : the connector's values, overridden for this use only
            const settings = response && Array.isArray(response.settings) ? response.settings : [];
            if (settings.length > 0) {
                fnSeparator();
                fnTitle('article_settings');
                const fnOverride = function (name, text) {
                    const variables = $.extend(true, {}, fnObject(that.jsonValue(articlePath.concat([ 'variables' ]))));
                    if (text === '') {
                        delete variables[name];
                    } else {
                        variables[name] = { value: text };
                    }
                    fnSet('variables', Object.keys(variables).length > 0 ? variables : undefined);
                };
                for (const setting of settings) {
                    const own = fnObject(fnObject(article.variables)[setting.name]).value;
                    const defaultText = setting.default ? setting.default.text : '';
                    let $control;
                    if (Array.isArray(setting.steps)) {
                        $control = $('<select class="form-control input-sm">')
                            .append($('<option value="">').text(i18next.t('core.hardware_editor.article_setting_default', { value: defaultText })));
                        for (const step of setting.steps) {
                            $control.append($('<option>').attr('value', step.raw).text(step.text || step.raw));
                        }
                        $control
                            .val(own === undefined ? '' : own)
                            .prop('disabled', this.readonly)
                            .on('change', function () {
                                fnOverride(setting.name, $(this).val());
                            });
                        $control = $('<div class="ladb-hardware-editor-placement-cell ladb-hardware-editor-primitive-cell ladb-hardware-editor-primitive-neutral">')
                            .toggleClass('ladb-hardware-editor-article-overridden', setting.overridden)
                            .append($control);
                    } else {
                        $control = this.renderArticleField(own, setting.value, function (text) {
                            fnOverride(setting.name, text);
                        }, { placeholder: defaultText, overridden: setting.overridden });
                    }
                    $editor.append($('<div class="ladb-hardware-editor-primitive-label ladb-hardware-editor-article-setting-name">').text(setting.label || setting.name));
                    fnRow($control);
                }
            }

        } else {

            // Its own name, price and mass - for the cut list - one row each.
            // A short form's are its slot's : named above, the slot's name
            const componentPath = partPath.slice(0, -1);
            const info = implicit ? fnObject(this.jsonValue(componentPath)) : article;
            for (const name of ARTICLE_INFO_KEYS) {
                if (implicit && name === 'name') {
                    continue;
                }
                fnLabel('article_' + name);
                fnRow($('<div class="ladb-hardware-editor-placement-cell ladb-hardware-editor-primitive-cell ladb-hardware-editor-primitive-neutral ladb-hardware-editor-article-info">')
                    .toggleClass('ladb-hardware-editor-primitive-text', name === 'name')
                    .append($('<input type="text" class="form-control input-sm" spellcheck="false">')
                        .val(info[name] === undefined || info[name] === null ? '' : String(info[name]))
                        .attr('placeholder', name === 'name' ? (fnObject(this.jsonValue(componentPath)).name || fnObject(this.jsonValue([])).name || '') + ' (' + key + ')' : '')   // Unnamed : its slot's name - see SmartJoinTool#_get_hardware_definition_name
                        .prop('disabled', this.readonly)
                        .on('change', function () {
                            const text = $(this).val().trim();
                            const value = text === '' ? undefined : (name === 'name' ? text : fnPrimitiveValue(text));
                            if (implicit) {
                                that.setJsonMember(componentPath, name, value);
                            } else {
                                fnSet(name, value);
                            }
                        })
                    )
                );
            }

            if (kind === 'skp') {
                // Its name and buttons in the fields column, its placement below, wide
                fnLabel('article_file');
                const $file = $('<div class="ladb-hardware-editor-article-wide">');
                this.renderSkpFile($file, this.articleSkp(slot, key, implicit));
                $editor.append($file.children('.ladb-hardware-editor-file'));
                const $buttons = $file.children('.ladb-hardware-editor-part-buttons');
                if ($buttons.length > 0) {
                    fnLabel(null);
                    $editor.append($buttons);
                }
                if ($file.children().length > 0) {
                    $editor.append($file);
                }
            } else {
                fnTitle('article_primitives');
                // A short form's : the part's own, as the bench tells them
                $editor.append((implicit ? this.renderPrimitives(slot, partPath, 'hardware', article) : this.renderPrimitives(slot, articlePath, 'hardware', article, key, response)).addClass('ladb-hardware-editor-article-wide'));
            }

        }

        // Where it is laid : x, y on the face, z off it, one per position
        const at = Array.isArray(article.at) ? article.at : [ {} ];
        const positions = response && Array.isArray(response.positions) ? response.positions : [];
        const fnWriteAt = function (fn) {
            const current = that.jsonValue(articlePath.concat([ 'at' ]));
            const items = (Array.isArray(current) ? current : [ {} ]).map(function (item) { return $.extend({}, fnObject(item)); });
            fn(items);
            fnSet('at', items.length === 0 || items.length === 1 && Object.keys(items[0]).length === 0 ? undefined : items);
        };
        fnSeparator();
        at.forEach(function (item, index) {
            item = fnObject(item);
            const fields = fnObject(positions[index]);
            fnLabel(index === 0 ? 'article_positions' : null);
            const $position = fnRow([ 'x', 'y', 'z' ].map(function (axis) {
                return that.renderArticleField(item[axis], fields[axis], function (text) {
                    fnWriteAt(function (items) {
                        if (text === '') {
                            delete items[index][axis];
                        } else {
                            items[index][axis] = fnPrimitiveValue(text);
                        }
                    });
                }, { axis: axis, tag: axis.toUpperCase(), placeholder: '0' });
            }));
            if (at.length > 1 && !that.readonly) {
                $position.append(fnTooltip($('<button type="button" class="btn btn-default btn-xs">'), i18next.t('default.delete'))
                    .append($('<i class="ladb-opencutlist-icon-minus">'))
                    .on('click', function () {
                        this.blur();
                        fnWriteAt(function (items) { items.splice(index, 1); });
                    })
                );
            }
        });
        $editor.append($('<div class="ladb-hardware-editor-part-buttons ladb-hardware-editor-add-buttons ladb-hardware-editor-article-wide">')
            .append($('<button type="button" class="btn btn-default btn-xs">')
                .append('<i class="ladb-opencutlist-icon-plus"></i> ' + i18next.t('core.hardware_editor.article_position_add'))
                .prop('disabled', this.readonly)
                .on('click', function () {
                    this.blur();
                    fnWriteAt(function (items) { items.push({}); });
                })
            )
        );

        // What its lengths can use - see appendPrimitiveNames
        this.appendPrimitiveNames($editor, fnObject((this.response.slots || {})[slot]).names);

        // Its asserts, as the bench measures them - at the end
        const asserts = kind === 'connector' && response && Array.isArray(response.asserts) ? response.asserts : [];
        if (asserts.length > 0) {
            fnSeparator();
            fnTitle('article_asserts');
            const $asserts = $('<div class="ladb-hardware-editor-article-asserts ladb-hardware-editor-article-wide">');
            for (const assert of asserts) {
                $asserts.append($('<div class="ladb-hardware-editor-article-assert">')
                    .addClass(assert.ok ? 'text-success' : 'text-danger')
                    .append($('<span class="ladb-hardware-editor-article-assert-state">').append($('<i>').addClass('ladb-opencutlist-icon-' + (assert.ok ? 'check-mark' : 'warning'))))
                    .append($('<code>').text(assert.expression))
                    .append($('<span class="ladb-hardware-editor-article-assert-values">').text(this.assertText(assert, assert.z_text ? (response.axis === 'y' ? 'Y' : 'Z') + ' ' + assert.z_text : null)))
                );
            }
            $editor.append($asserts);
        }

        return $editor;
    };

    // Why the given key can't name an article - renamed from the given one,
    // among the given ones - : an i18n key, null if it can.
    LadbModalHardwareEditor.prototype.articleKeyError = function (newKey, key, articles) {
        if (!ARTICLE_KEY_PATTERN.test(newKey)) return 'article_key_invalid';
        if (ARTICLE_RESERVED_KEYS.indexOf(newKey) >= 0) return 'article_key_reserved';
        if (newKey !== key && Object.prototype.hasOwnProperty.call(articles, newKey)) return 'article_key_taken';
        return null;
    };

    // A key for a new article, from the given one : itself, else numbered.
    LadbModalHardwareEditor.prototype.freeArticleKey = function (base, articles) {
        let key = base;
        for (let i = 2; Object.prototype.hasOwnProperty.call(articles, key); i++) {
            key = base + '-' + i;
        }
        return key;
    };

    // A new article of the given kind, open - one using a connector once it
    // is chosen in the library. The first one, a SKP or primitives, is
    // written in its short form.
    LadbModalHardwareEditor.prototype.addArticle = function (slot, partPath, kind) {
        const that = this;
        const current = this.jsonValue(partPath);
        if (current === undefined && this.findJsonValueRange(this.cm.getValue(), partPath) !== null) {
            return;   // The JSON being typed
        }
        const view = this.hardwareArticles(current);
        const empty = Object.keys(view.articles).length === 0;
        const fnAdd = function (key, article) {
            that.articleOpen = { slot: slot, key: key };
            that.connectorBrowser = null;
            const written = view.implicit
                ? that.writeHardwareArticles(partPath, $.extend(true, {}, view.articles, { [key]: article }), view)
                : that.writeJsonValue(partPath.concat([ key ]), article);
            if (written) {
                that.compute(false);
            }
        };
        if (kind === 'skp') {
            fnAdd(empty ? SHORT_ARTICLE_KEY : this.freeArticleKey('body', view.articles), { skp: true });
        } else if (kind === 'primitives') {
            fnAdd(empty ? SHORT_ARTICLE_KEY : this.freeArticleKey('part', view.articles), { cylinders: [ $.extend({}, PRIMITIVE_DEFAULTS.cylinders) ] });
        } else {
            this.articleOpen = null;
            this.browseConnectors(slot, null, null, function (file) {
                const other = slot === 'a' ? 'b' : 'a';
                const measures = {};
                measures['thickness_' + other] = '2mm';
                fnAdd(that.freeArticleKey(fnFileStem(file.ref).replace(/[^a-z0-9_-]+/g, '-').replace(/^[^a-z]+/, '') || 'connector', view.articles), {
                    use: file.use,
                    host: slot,
                    measures: measures
                });
            });
        }
    };

    // The given article renamed : its key in place, its row kept open - the
    // short form left, or taken, as a whole.
    LadbModalHardwareEditor.prototype.renameArticle = function (slot, partPath, key, newKey) {
        const current = this.jsonValue(partPath);
        const view = this.hardwareArticles(current);
        const fnOpen = function (that) {
            if (that.articleOpen && that.articleOpen.slot === slot && that.articleOpen.key === key) {
                that.articleOpen = { slot: slot, key: newKey };
            }
        };
        const renamed = {};
        for (const k of Object.keys(view.articles)) {
            renamed[k === key ? newKey : k] = view.articles[k];
        }
        if (view.implicit || this.shortHardware(partPath, renamed) !== undefined) {
            const renames = {};
            renames[newKey] = key;
            fnOpen(this);
            if (this.writeHardwareArticles(partPath, renamed, view, renames)) {
                this.compute(false);
            }
            return;
        }
        const text = this.cm.getValue();
        const range = this.findJsonValueRange(text, partPath.concat([ key ]));
        if (range === null) {
            return;
        }
        const start = text.lastIndexOf(JSON.stringify(key), range.start);
        if (start < 0) {
            return;
        }
        // Its own SKP file follows it : written under its new name at the save
        if (fnObject(view.articles[key]).skp === true) {
            const ref = this.articleSkpRef(slot, key, false);
            if (ref !== null) {
                this.moveSkpRef(ref, ref.replace(new RegExp('\\.' + key + '\\.skp$', 'i'), '.' + newKey + '.skp'));
            }
        }
        this.cm.replaceRange(JSON.stringify(newKey), this.cm.posFromIndex(start), this.cm.posFromIndex(start + JSON.stringify(key).length));
        fnOpen(this);
        this.compute(false);
    };

    // The given article removed - null when inherited - the part left
    // empty with the last.
    LadbModalHardwareEditor.prototype.deleteArticle = function (slot, partPath, key) {
        const current = this.jsonValue(partPath);
        const view = this.hardwareArticles(current);
        this.articleHovered = null;
        if (this.articleOpen && this.articleOpen.slot === slot && this.articleOpen.key === key) {
            this.articleOpen = null;
        }
        const path = partPath.concat([ key ]);
        let written;
        const others = Object.keys(view.articles).filter(function (k) { return k !== key && view.articles[k] !== null; });
        if (view.implicit || others.length === 0 && this.inheritanceState(path, false) === null) {
            written = this.writeHardwareArticles(partPath, {}, view);   // The last : none
        } else {
            written = this.setJsonMember(partPath, key, this.inheritanceState(path, false) === null ? undefined : null);
            this.collapseArticles(partPath);
        }
        if (written) {
            this.compute(false);
        }
    };

    // The articles of the given hardware value : its own, else the one its
    // short form - a SKP, or primitives - is, keyed SHORT_ARTICLE_KEY, none
    // when it gives no primitives. { articles, implicit }.
    LadbModalHardwareEditor.prototype.hardwareArticles = function (value) {
        if (fnIsArticles(value)) {
            return { articles: value, implicit: false };
        }
        const articles = {};
        if (fnIsSkp(value)) {
            articles[SHORT_ARTICLE_KEY] = { skp: value };
        } else if (value && typeof value === 'object' && PART_PRIMITIVE_KEYS.hardware.some(function (k) { return Array.isArray(value[k]) && value[k].length > 0; })) {
            articles[SHORT_ARTICLE_KEY] = value;
        }
        return { articles: articles, implicit: true };
    };

    // The short form of the given articles of the hardware at the given
    // path : the SKP or the primitives of its one article keyed
    // SHORT_ARTICLE_KEY that gives nothing else, {} when there are none.
    // undefined when they have none, or when the part overrides its
    // parents', whose articles it would drop.
    LadbModalHardwareEditor.prototype.shortHardware = function (partPath, articles) {
        if (this.inheritanceState(partPath, false) !== null) {
            return undefined;
        }
        const keys = Object.keys(articles);
        if (keys.length === 0) {
            return {};
        }
        if (keys.length > 1 || keys[0] !== SHORT_ARTICLE_KEY) {
            return undefined;
        }
        const article = this.shortArticle(partPath, articles[SHORT_ARTICLE_KEY]);
        if (article === null) {
            return undefined;
        }
        const fields = Object.keys(article);
        if (fnIsSkp(article.skp) && fields.length === 1) {
            return article.skp;
        }
        if (fields.length > 0 && fields.every(function (field) { return PART_PRIMITIVE_KEYS.hardware.indexOf(field) >= 0; })) {
            return article;
        }
        return undefined;
    };

    // The given article keyed SHORT_ARTICLE_KEY without the info its slot
    // would hold in a short form - see SHORT_ARTICLE_INFO_KEYS - null when
    // it isn't an object, or gives one the slot gives otherwise.
    LadbModalHardwareEditor.prototype.shortArticle = function (partPath, article) {
        if (!article || typeof article !== 'object' || Array.isArray(article)) {
            return null;
        }
        const component = fnObject(this.jsonValue(partPath.slice(0, -1)));
        const stripped = {};
        for (const field of Object.keys(article)) {
            if (SHORT_ARTICLE_INFO_KEYS.indexOf(field) < 0) {
                stripped[field] = article[field];
            } else if (component[field] !== undefined && JSON.stringify(component[field]) !== JSON.stringify(article[field])) {
                return null;
            }
        }
        return stripped;
    };

    // Writes the given articles as the hardware at the given path - in its
    // short form when they can be - its articles before given by the given
    // view - see hardwareArticles. The own SKP file of an article follows
    // it - written under its new name at the save - renamed by the given
    // renames : { new key: old key }.
    LadbModalHardwareEditor.prototype.writeHardwareArticles = function (partPath, articles, view, renames) {
        const slot = partPath[1];
        const short = this.shortHardware(partPath, articles);
        for (const key of Object.keys(articles)) {
            const oldKey = renames && renames[key] !== undefined ? renames[key] : key;
            if (fnObject(articles[key]).skp !== true || fnObject(view.articles[oldKey]).skp !== true) {
                continue;
            }
            const oldRef = this.articleSkpRef(slot, oldKey, view.implicit);
            if (oldRef === null) {
                continue;
            }
            const base = view.implicit ? oldRef.replace(/\.skp$/i, '') : oldRef.replace(new RegExp('\\.' + oldKey + '\\.skp$', 'i'), '');
            const newRef = base + (short !== undefined ? '' : '.' + key) + '.skp';
            if (newRef !== oldRef) {
                this.moveSkpRef(oldRef, newRef);
            }
        }
        // The info of the short form's article is its slot's : it moves with it
        const componentPath = partPath.slice(0, -1);
        const body = articles[SHORT_ARTICLE_KEY];
        if (short !== undefined && body && typeof body === 'object') {
            for (const field of SHORT_ARTICLE_INFO_KEYS) {
                if (body[field] !== undefined) {
                    this.setJsonMember(componentPath, field, body[field]);
                }
            }
        } else if (short === undefined && view.implicit && body && typeof body === 'object') {
            const component = fnObject(this.jsonValue(componentPath));
            articles = $.extend({}, articles);
            articles[SHORT_ARTICLE_KEY] = $.extend({}, body);
            for (const field of SHORT_ARTICLE_INFO_KEYS) {
                if (component[field] !== undefined) {
                    if (articles[SHORT_ARTICLE_KEY][field] === undefined) {
                        articles[SHORT_ARTICLE_KEY][field] = component[field];
                    }
                    this.setJsonMember(componentPath, field, undefined);
                }
            }
        }
        if (short !== undefined && Object.keys(articles).length === 0) {
            return this.writeJsonValue(partPath, this.inheritanceState(partPath, false) === null ? undefined : null);   // Nothing left : none
        }
        return this.writeJsonValue(partPath, short !== undefined ? short : articles);
    };

    // The hardware at the given path written in its short form, if its
    // articles can be.
    LadbModalHardwareEditor.prototype.collapseArticles = function (partPath) {
        const current = this.jsonValue(partPath);
        const view = this.hardwareArticles(current);
        if (!view.implicit && this.shortHardware(partPath, view.articles) !== undefined) {
            this.writeHardwareArticles(partPath, view.articles, view);
        }
    };

    // Sets the given member of the given article of the hardware at the
    // given path to the given value, undefined removing it - the short form
    // left, or taken, when it changes.
    LadbModalHardwareEditor.prototype.setArticleMember = function (partPath, key, name, value) {
        const current = this.jsonValue(partPath);
        if (current === undefined) {
            return;   // The JSON being typed
        }
        const view = this.hardwareArticles(current);
        let written;
        if (view.implicit) {
            const articles = $.extend(true, {}, view.articles);
            const article = fnObject(articles[key]);
            if (value === undefined) {
                delete article[name];
            } else {
                article[name] = value;
            }
            articles[key] = article;
            written = this.writeHardwareArticles(partPath, articles, view);
        } else {
            written = this.setJsonMember(partPath.concat([ key ]), name, value);
            this.collapseArticles(partPath);
        }
        if (written) {
            this.compute(false);
        }
    };

    // The SKP of the given article on the bench - of the part when the
    // given one is its short form's.
    LadbModalHardwareEditor.prototype.articleSkp = function (slot, key, implicit) {
        return (this.response.skps || []).find(function (skp) {
            return skp.slot === slot && (implicit ? skp.part === 'hardware' && !skp.article : skp.article === key && skp.position === 0);
        });
    };

    // The ref of the SKP of the given article - see articleSkp - null when
    // the bench has none.
    LadbModalHardwareEditor.prototype.articleSkpRef = function (slot, key, implicit) {
        const skp = this.articleSkp(slot, key, implicit);
        return skp && skp.ref ? skp.ref : null;
    };

    // The SKP file of the given ref, imported or as it is, and its
    // placement, moved to the given ref : written under it at the save -
    // see HardwareDescriptorSaveWorker.
    LadbModalHardwareEditor.prototype.moveSkpRef = function (ref, newRef) {
        const mesh = this.meshes[this.skpSource(ref)];
        if (this.imports[ref]) {
            this.imports[newRef] = this.imports[ref];
        } else if (mesh && mesh !== 'loading' && !mesh.error) {
            this.imports[newRef] = { path: ref, name: newRef.split('/').pop() };   // The file as it is
        }
        delete this.imports[ref];
        if (this.placements[ref]) {
            this.placements[newRef] = this.placements[ref];
            delete this.placements[ref];
        }
        this.updateGuard();
    };

    // The connectors library browsed from the given folder - its roots when
    // none - for the given article, or for a new one given the function
    // the chosen connector goes to.
    LadbModalHardwareEditor.prototype.browseConnectors = function (slot, key, dirRef, onChoose) {
        const that = this;
        rubyCallCommand('hardware_library_list', { dir_ref: dirRef, ref: this.ref || this.provisionalRef() }, function (listing) {
            if (listing.errors) {
                that.dialog.notifyErrors(listing.errors);
                return;
            }
            that.connectorBrowser = { slot: slot, key: key, listing: listing, onChoose: onChoose || null };
            that.renderParts();
        });
    };

    // The browsed folder of the connectors library : its path, its folders,
    // its concrete connectors - one clicked goes to the given function.
    LadbModalHardwareEditor.prototype.renderConnectorBrowser = function (onChoose) {
        const that = this;

        const browser = this.connectorBrowser;
        const listing = browser.listing;
        const fnBrowse = function (ref) {
            return function (e) {
                e.preventDefault();
                that.browseConnectors(browser.slot, browser.key, ref, browser.onChoose);
            };
        };

        const $browser = $('<div class="ladb-hardware-editor-library">');
        const $path = $('<div class="ladb-hardware-editor-library-path">')
            .append($('<a href="#">').text(i18next.t('core.library.libraries')).on('click', fnBrowse(null)));
        for (const dir of listing.path || []) {
            $path.append(' / ').append($('<a href="#">').text(dir.name).on('click', fnBrowse(dir.ref)));
        }
        $browser.append($path);

        const $items = $('<div class="ladb-hardware-editor-library-items">');
        for (const dir of listing.dirs || []) {
            $items.append($('<a href="#" class="ladb-hardware-editor-library-dir">').text('📁 ' + dir.name).on('click', fnBrowse(dir.ref)));
        }
        for (const file of listing.files || []) {
            $items.append($('<a href="#" class="ladb-hardware-editor-library-file">')
                .toggleClass('text-danger', !file.valid)
                .text(file.name)
                .attr('title', file.ref)
                .on('click', function (e) {
                    e.preventDefault();
                    (browser.onChoose || onChoose)(file);
                })
            );
        }
        if (listing.dir_ref && (listing.files || []).length === 0 && (listing.dirs || []).length === 0) {
            $items.append($('<div class="ladb-hardware-editor-empty">').text(i18next.t('core.hardware_editor.library_empty')));
        }
        $browser.append($items);

        return $browser;
    };

    // Primitives /////

    // The primitives of the given part - at the given path - : one row per
    // primitive, the open one edited in place, then a button to add one of
    // each kind the part can be given as. Those of an article : its key,
    // and what the bench tells of it.
    LadbModalHardwareEditor.prototype.renderPrimitives = function (slot, partPath, part, value, article, articleResponse) {
        const that = this;

        const slotResponse = (this.response.slots || {})[slot];
        const componentResponse = slotResponse && slotResponse.component ? slotResponse.component : {};
        const partResponse = article ? fnObject(fnObject(articleResponse).primitives) : fnObject(fnObject(componentResponse.primitives)[part]);

        const $primitives = $('<div class="ladb-hardware-editor-primitives">');
        const $list = $('<div class="ladb-hardware-editor-primitive-list">');
        for (const key of PART_PRIMITIVE_KEYS[part]) {
            const items = Array.isArray(value[key]) ? value[key] : [];
            const responses = Array.isArray(partResponse[key]) ? partResponse[key] : [];
            let rank = 0;
            items.forEach(function (item, index) {
                if (!item || typeof item !== 'object' || Array.isArray(item)) {
                    return;
                }
                rank++;
                const primitive = { slot: slot, part: part, key: key, index: index };
                if (article) primitive.article = article;
                $list.append(that.renderPrimitive(primitive, partPath, item, responses[index] || null, rank, slotResponse ? slotResponse.names : null));
            });
        }
        if ($list.children().length > 0) {
            $primitives.append($list);
        }

        const $adds = $('<div class="ladb-hardware-editor-part-buttons ladb-hardware-editor-add-buttons">');
        for (const key of PART_PRIMITIVE_KEYS[part]) {
            $adds.append($('<button type="button" class="btn btn-default btn-xs">')
                .append('<i class="ladb-opencutlist-icon-plus"></i> ')
                .append($('<span class="ladb-hardware-editor-primitive-icon">').addClass('ladb-hardware-editor-primitive-' + part).html(PRIMITIVE_ICONS[key]))
                .append(' ' + i18next.t('core.hardware_editor.primitive_type_' + key))
                .prop('disabled', this.readonly)
                .on('click', function () {
                    this.blur();
                    that.addPrimitive(slot, partPath, part, key, article);
                })
            );
        }
        $primitives.append($adds);

        return $primitives;
    };

    // The row of the given primitive : its head - name, what it resolves to
    // on the bench, its tools - then, open, its fields.
    LadbModalHardwareEditor.prototype.renderPrimitive = function (primitive, partPath, item, response, rank, names) {
        const that = this;

        const id = fnPrimitiveId(primitive);
        const open = id === fnPrimitiveId(this.primitiveOpen);
        const itemPath = partPath.concat([ primitive.key, primitive.index ]);
        const fields = response ? fnObject(response.fields) : {};
        const errorCount = Object.keys(fields).filter(function (name) { return fields[name].error; }).length;
        const unresolved = response !== null && response.resolved !== true && errorCount === 0;

        const $row = $('<div class="ladb-hardware-editor-primitive">')
            .toggleClass('ladb-hardware-editor-primitive-open', open)
            .attr('data-primitive', id);

        // Head
        const fnTool = function (icon, title, onClick) {
            return fnTooltip($('<button type="button" class="btn btn-default btn-xs">'), title)
                .append($('<i>').addClass('ladb-opencutlist-icon-' + icon))
                .prop('disabled', that.readonly)
                .on('click', function (e) {
                    e.stopPropagation();
                    this.blur();
                    onClick();
                });
        };
        const $head = $('<div class="ladb-hardware-editor-primitive-head">')
            .append($('<span class="ladb-hardware-editor-primitive-caret">').text('▸'))
            .append($('<span class="ladb-hardware-editor-primitive-icon">').addClass('ladb-hardware-editor-primitive-' + primitive.part).html(PRIMITIVE_ICONS[primitive.key]))
            .append($('<span class="ladb-hardware-editor-primitive-name">').text(i18next.t('core.hardware_editor.primitive_type_' + primitive.key) + ' ' + rank))
            .append($('<span class="ladb-hardware-editor-primitive-summary">').text(this.primitiveSummary(primitive.key, item, response, fields)));
        if (errorCount > 0 || unresolved) {
            $head.append($('<span class="ladb-hardware-editor-primitive-errors">').html('<i class="ladb-opencutlist-icon-warning"></i> ' + (errorCount || '')));
        }
        $head
            .append($('<span class="ladb-hardware-editor-primitive-tools">')
                .append(fnTool('copy', i18next.t('default.duplicate'), function () {
                    that.duplicatePrimitive(primitive, partPath);
                }))
                .append(fnTool('clear', i18next.t('default.delete'), function () {
                    that.deletePrimitive(primitive, partPath);
                }))
            )
            .on('click', function () {
                that.primitiveOpen = open ? null : primitive;
                that.renderParts();
            })
            .on('mouseenter', function () {
                that.primitiveHovered = primitive;
                that.showBenchPrimitive();
            })
            .on('mouseleave', function () {
                that.primitiveHovered = null;
                that.showBenchPrimitive();
            });
        $row.append($head);

        if (open) {
            $row.append(this.renderPrimitiveEditor(primitive, itemPath, item, fields, unresolved, names));
        }

        return $row;
    };

    // What the given primitive is, in a few words : its sizes and position
    // as resolved on the bench, worded as the bench tells it when hovered -
    // '?' for what can't be.
    LadbModalHardwareEditor.prototype.primitiveSummary = function (key, item, response, fields) {
        if (response && response.texts) {
            return fnPrimitiveSummary(key, item.axis, response.texts);
        }
        const fnText = function (name) {
            if (fields[name] && fields[name].text) {
                return fields[name].text;
            }
            return item[name] === undefined && /^[xyz]$/.test(name) ? '0' : '?';
        };
        return fnPrimitiveSummary(key, item.axis, {
            diameter: fnText(key === 'mortises' || key === 'oblongs' ? 'width' : 'diameter'),
            length: fnText('length'),
            depth: fnText('depth'),
            x: fnText('x'),
            y: fnText('y'),
            z: fnText('z')
        });
    };

    // The fields of the given primitive : each length typed is written as
    // it goes - the bench follows - its value on the bench beside it.
    LadbModalHardwareEditor.prototype.renderPrimitiveEditor = function (primitive, itemPath, item, fields, unresolved, names) {
        const that = this;

        const key = primitive.key;
        const machining = key === 'drillings' || key === 'mortises';
        const alongY = machining && item.axis === 'y';
        // The axis a cylinder or an oblong goes along, the ones it is placed by - see HardwareDescriptorDef::PRISM_OUTLINE_KEYS
        const shape = key === 'cylinders' || key === 'oblongs';
        const shapeAxis = shape && PRISM_OUTLINE_KEYS[item.axis] ? item.axis : 'z';
        const positionKeys = shape ? PRISM_OUTLINE_KEYS[shapeAxis] : alongY ? [ 'x', 'z' ] : [ 'x', 'y' ];

        const $editor = $('<div class="ladb-hardware-editor-primitive-editor">')
            .on('focusin focusout', function (e) {
                // Its names offered while a length is typed - see .ladb-hardware-editor-primitive-names
                $editor.toggleClass('ladb-hardware-editor-primitive-typing', e.type === 'focusin' && fnTypedIn($editor, e.target));
            });

        const fnLabel = function (label) {
            $editor.append($('<div class="ladb-hardware-editor-primitive-label">').text(i18next.t('core.hardware_editor.' + label)));
        };
        const fnRow = function ($content) {
            $editor.append($('<div class="ladb-hardware-editor-primitive-fields">').append($content));
        };

        // A length of the item - or of its head, at the given path - :
        // written as typed, removed when emptied if it is optional. Reset :
        // an optional one removed, a signed one 0, a positive one emptied.
        const fnField = function (path, name, optional, axis, tag) {
            let responseName = name;
            if (path[itemPath.length] === 'outline') {
                responseName = 'outline_' + path[itemPath.length + 1] + '_' + name;   // A point of a prism
            } else if (path.length > itemPath.length) {
                responseName = 'head_' + name;
            }
            const field = fields[responseName] || null;
            const $cell = $('<div class="ladb-hardware-editor-placement-cell ladb-hardware-editor-primitive-cell">')
                .addClass(axis ? 'ladb-hardware-editor-placement-' + axis : 'ladb-hardware-editor-primitive-neutral')
                .toggleClass('ladb-hardware-editor-primitive-invalid', !!(field && field.error));
            if (tag) {
                $cell.append($('<span class="ladb-hardware-editor-primitive-tag">').text(tag));
            }
            const $input = $('<input type="text" class="form-control input-sm ladb-hardware-editor-live" spellcheck="false">');
            $cell.append($input);
            let target = item;
            for (const k of path.slice(itemPath.length)) {
                target = target !== null && typeof target === 'object' ? target[k] : undefined;   // Through the outline list
            }
            target = fnObject(target);
            $input
                .val(fnPrimitiveText(target[name]))
                .attr('placeholder', optional ? '0' : '')
                .ladbTextinputDimension({ resetValue: !optional && (name === 'from' || name === 'to') ? '0' : '' })
                .on('input change', function () {
                    const text = $(this).val();
                    that.setJsonMember(path, name, text.trim() === '' && optional ? undefined : fnPrimitiveValue(text));
                })
                .on('keydown', function (e) {
                    // ↑ ↓ nudge a plain length - by 0.5 mm, 5 mm with Shift
                    if (e.key !== 'ArrowUp' && e.key !== 'ArrowDown') {
                        return;
                    }
                    const match = /^(-?\d+(?:[.,]\d+)?)(\s*mm)?$/.exec($(this).val().trim() || (optional ? '0' : ''));
                    if (!match) {
                        return;
                    }
                    e.preventDefault();
                    const number = Math.round((parseFloat(match[1].replace(',', '.')) + (e.shiftKey ? 5 : 0.5) * (e.key === 'ArrowUp' ? 1 : -1)) * 100) / 100;
                    $(this).val(String(number) + (match[2] || '')).trigger('input');
                });
            const $value = $('<span class="ladb-hardware-editor-primitive-value">');
            if (field && field.error) {
                $value.html('<i class="ladb-opencutlist-icon-warning"></i>');
                fnTooltip($cell, that.errorLabel(field.error));
            } else if (field && field.text && typeof target[name] === 'string' && !/^-?\d+(?:[.,]\d+)?\s*[a-z"']*$/i.test(target[name].trim())) {
                $value.text('= ' + field.text);   // An expression : what it gives
            }
            $cell.append($value);
            return $cell;
        };

        // Segments rewriting the item - as written now, what was typed since
        // this rendering included - by the one clicked
        const fnItemSegments = function (options, current) {
            return fnSegments(options, current, that.readonly, function (option) {
                const written = that.primitiveItem(itemPath);
                if (written !== null) {
                    const newItem = $.extend(true, {}, written);
                    option.apply(newItem);
                    that.setPrimitive(itemPath, newItem);
                }
            });
        };

        const defaults = PRIMITIVE_DEFAULTS[key];

        // The depth of a machining from the face - through checked beside it
        // when it can be, not along Y : the length greyed, without value.
        const fnDepth = function (throughAllowed) {
            fnLabel('primitive_depth');
            const $field = fnField(itemPath, 'depth', false);
            if (!throughAllowed) {
                fnRow($field);
                return;
            }
            const through = item.depth === 'through';
            if (through) {
                $field.addClass('ladb-hardware-editor-primitive-disabled');
                $field.find('input').val('').ladbTextinputDimension('disable');
                $field.find('.ladb-hardware-editor-primitive-value').remove();
            }
            const $through = $('<input type="checkbox">')
                .prop('checked', through)
                .prop('disabled', that.readonly)
                .on('change', function () {
                    const written = that.primitiveItem(itemPath);
                    if (written !== null) {
                        const newItem = $.extend(true, {}, written);
                        if ($(this).is(':checked')) {
                            newItem.depth = 'through';
                        } else {
                            newItem.depth = defaults.depth;
                            for (const head of PRIMITIVE_HEADS) {
                                if (newItem[head] && typeof newItem[head] === 'object') {
                                    delete newItem[head].face;   // The opposite face needs it through
                                }
                            }
                        }
                        that.setPrimitive(itemPath, newItem);
                    }
                });
            fnRow([
                $field,
                fnTooltip($('<div class="checkbox ladb-hardware-editor-primitive-through">'), i18next.t('core.hardware_editor.primitive_through_help'))
                    .append($('<label>')
                        .append($through)
                        .append(' ' + i18next.t('core.hardware_editor.primitive_through'))
                    )
            ]);
        };

        // Sizes
        if (PRISM_KEYS.includes(key)) {
            this.renderPrismEditor($editor, key, itemPath, item, fnLabel, fnRow, fnField, fnItemSegments, fnDepth);
        } else if (key === 'cylinders' || key === 'drillings') {
            fnLabel('primitive_diameter');
            fnRow(fnField(itemPath, 'diameter', false));
        } else {
            fnLabel('primitive_size');
            fnRow([
                fnField(itemPath, 'length', false, null, 'L'),
                fnField(itemPath, 'width', false, null, 'l')
            ]);
            // Along the first axis across the one it goes along, or the other one
            const [ first, across ] = positionKeys;
            fnLabel('primitive_length_axis');
            fnRow(fnItemSegments([
                { value: first, axis: first, apply: function (newItem) { delete newItem.length_axis; } },
                { value: across, axis: across, apply: function (newItem) { newItem.length_axis = across; } }
            ], item.length_axis === across ? across : first));
        }

        // Axis
        if (machining) {
            fnLabel('primitive_axis');
            fnRow(fnItemSegments([
                { value: 'y', axis: 'y', apply: function (newItem) {
                        newItem.axis = 'y';
                        delete newItem.y;
                        delete newItem.length_axis;
                        if (newItem.depth === 'through') {
                            newItem.depth = '@height';
                        }
                        for (const head of PRIMITIVE_HEADS) {
                            delete newItem[head];   // Not along Y
                        }
                    } },
                { value: 'z', axis: 'z', apply: function (newItem) {
                        delete newItem.axis;
                        delete newItem.z;
                        delete newItem.length_axis;
                    } }
            ], alongY ? 'y' : 'z'));
        } else if (shape) {
            // Its position keeps its values, by the new axes - an oblong long along the first
            fnLabel('primitive_axis');
            fnRow(fnItemSegments(PRISM_AXES.map(function (newAxis) {
                return { value: newAxis, axis: newAxis, apply: function (newItem) {
                        const values = positionKeys.map(function (k) { return newItem[k]; });
                        for (const k of [ 'x', 'y', 'z' ]) {
                            delete newItem[k];
                        }
                        delete newItem.length_axis;
                        PRISM_OUTLINE_KEYS[newAxis].forEach(function (k, i) {
                            if (values[i] !== undefined) newItem[k] = values[i];
                        });
                        if (newAxis === 'z') {
                            delete newItem.axis;
                        } else {
                            newItem.axis = newAxis;
                        }
                    } };
            }), shapeAxis));
        }

        // Extent
        if (PRISM_KEYS.includes(key)) {
            // See renderPrismEditor
        } else if (shape) {
            $editor.append($('<div class="ladb-hardware-editor-primitive-label">').text(i18next.t('core.hardware_editor.primitive_prism_span', { axis: shapeAxis.toUpperCase() })));
            fnRow([
                fnField(itemPath, 'from', false, shapeAxis, i18next.t('core.hardware_editor.primitive_from')),
                fnField(itemPath, 'to', false, shapeAxis, i18next.t('core.hardware_editor.primitive_to'))
            ]);
        } else {
            fnDepth(!alongY);
        }

        // Position - a prism's by its outline
        if (!PRISM_KEYS.includes(key)) {
            fnLabel('primitive_position');
            fnRow(positionKeys.map(function (k) {
                return fnField(itemPath, k, true, k, k.toUpperCase());
            }));
        }

        // Head : a widened end of a drilling - not along Y - or a cylinder
        if (key === 'cylinders' || key === 'drillings' && !alongY) {
            const head = PRIMITIVE_HEADS.find(function (h) { return item[h] && typeof item[h] === 'object'; }) || null;
            const fnSetHead = function (newHead) {
                return function (newItem) {
                    const previousHead = PRIMITIVE_HEADS.find(function (h) { return newItem[h] && typeof newItem[h] === 'object'; });
                    const previous = previousHead ? newItem[previousHead] : {};
                    for (const h of PRIMITIVE_HEADS) {
                        delete newItem[h];
                    }
                    if (newHead) {
                        const value = { diameter: previous.diameter !== undefined ? previous.diameter : '10mm' };
                        if (newHead === 'counterbore') {
                            value.depth = previous.depth !== undefined ? previous.depth : '3mm';
                        } else if (previous.angle !== undefined) {
                            value.angle = previous.angle;
                        }
                        if (key === 'cylinders') {
                            value.end = previous.end || 'to';
                        } else if (previous.face) {
                            value.face = previous.face;
                        }
                        newItem[newHead] = value;
                    }
                };
            };
            $editor.append($('<div class="ladb-hardware-editor-primitive-separator">'));
            fnLabel('primitive_head');
            fnRow(fnItemSegments([
                { value: null, label: 'primitive_head_none', apply: fnSetHead(null) },
                { value: 'countersink', label: 'primitive_head_countersink', apply: fnSetHead('countersink') },
                { value: 'counterbore', label: 'primitive_head_counterbore', apply: fnSetHead('counterbore') }
            ], head));
            if (head) {
                const headPath = itemPath.concat([ head ]);
                const headValue = item[head];
                fnLabel('primitive_head_side');
                if (key === 'drillings') {
                    fnRow(fnItemSegments([
                        { value: 'contact', label: 'primitive_face_contact', apply: function (newItem) { delete fnObject(newItem[head]).face; } },
                        { value: 'opposite', label: 'primitive_face_opposite', help: 'primitive_face_opposite_help', disabled: item.depth !== 'through', apply: function (newItem) { fnObject(newItem[head]).face = 'opposite'; } }
                    ], headValue.face === 'opposite' ? 'opposite' : 'contact'));
                } else {
                    fnRow(fnItemSegments([
                        { value: 'to', label: 'primitive_end_to', apply: function (newItem) { fnObject(newItem[head]).end = 'to'; } },
                        { value: 'from', label: 'primitive_end_from', apply: function (newItem) { fnObject(newItem[head]).end = 'from'; } }
                    ], headValue.end === 'from' ? 'from' : 'to'));
                }
                fnLabel(head === 'countersink' ? 'primitive_head_diameter_angle' : 'primitive_head_diameter_depth');
                const $second = head === 'countersink'
                    ? this.renderPrimitiveAngle(headPath, headValue)
                    : fnField(headPath, 'depth', false);
                fnRow([ fnField(headPath, 'diameter', false, null, 'Ø'), $second ]);
            }
        }

        this.appendPrimitiveNames($editor, names);

        if (unresolved) {
            $editor.append($('<div class="ladb-hardware-editor-primitive-error">').text(i18next.t('core.hardware_editor.primitive_unresolved')));
        }

        if (this.readonly) {
            $('input', $editor).prop('disabled', true);
        }

        return $editor;
    };

    // What the lengths of the given editor can use, offered while one is
    // typed - see .ladb-hardware-editor-primitive-typing - inserted where
    // the caret is.
    LadbModalHardwareEditor.prototype.appendPrimitiveNames = function ($editor, names) {
        if (this.readonly || !Array.isArray(names) || names.length === 0) {
            return;
        }
        const $names = $('<div class="ladb-hardware-editor-primitive-names">')
            .append($('<span class="ladb-hardware-editor-primitive-names-title">').text(i18next.t('core.hardware_editor.primitive_variables')));
        for (const variable of names) {
            $names.append($('<button type="button" class="btn btn-default btn-xs">')
                .append($('<span>').text('@' + variable.name))
                .append(' ')
                .append($('<em>').text(variable.text || ''))
                .on('mousedown', function (e) {
                    e.preventDefault();   // The field keeps the focus
                })
                .on('click', function () {
                    const input = document.activeElement;
                    if (!input || !fnTypedIn($editor, input)) {
                        return;
                    }
                    const text = '@' + variable.name;
                    const start = input.selectionStart, end = input.selectionEnd;
                    input.value = input.value.substring(0, start) + text + input.value.substring(end);
                    input.setSelectionRange(start + text.length, start + text.length);
                    $(input).trigger('input');
                })
            );
        }
        $editor.append($names);
    };

    // The fields of a prism - see renderPrimitiveEditor and its helpers - :
    // the axis it is extruded along, from where to where along it - a
    // pocket's depth from the face - then its outline, one row per point - by the two other axes, and the radius of
    // its rounding - points added and removed whole.
    LadbModalHardwareEditor.prototype.renderPrismEditor = function ($editor, key, itemPath, item, fnLabel, fnRow, fnField, fnItemSegments, fnDepth) {
        const that = this;

        // A pocket goes along Z or Y, depth deep from the face, as a drilling or a mortise
        const pocket = key === 'pockets';
        const axis = PRISM_OUTLINE_KEYS[item.axis] && (!pocket || item.axis !== 'x') ? item.axis : 'z';
        const keys = PRISM_OUTLINE_KEYS[axis];
        const outline = Array.isArray(item.outline) ? item.outline : [];

        // Its outline rewritten - as written now - by the given function
        const fnWriteOutline = function (fn) {
            const written = that.primitiveItem(itemPath);
            if (written === null) {
                return;
            }
            const newItem = $.extend(true, {}, written);
            newItem.outline = (Array.isArray(newItem.outline) ? newItem.outline : []).map(function (point) { return $.extend({}, fnObject(point)); });
            fn(newItem.outline);
            that.setPrimitive(itemPath, newItem);
        };

        // Axis : its points keep their values, by the new axes
        fnLabel('primitive_axis');
        fnRow(fnItemSegments((pocket ? [ 'y', 'z' ] : PRISM_AXES).map(function (newAxis) {
            return { value: newAxis, axis: newAxis, apply: function (newItem) {
                if (newAxis === 'z') {
                    delete newItem.axis;
                } else {
                    newItem.axis = newAxis;
                }
                if (pocket && newAxis === 'y' && newItem.depth === 'through') {
                    newItem.depth = '@height';   // Not through along Y
                }
                const newKeys = PRISM_OUTLINE_KEYS[newAxis];
                newItem.outline = (Array.isArray(newItem.outline) ? newItem.outline : []).map(function (point) {
                    point = fnObject(point);
                    const newPoint = {};
                    keys.forEach(function (k, i) {
                        if (point[k] !== undefined) newPoint[newKeys[i]] = point[k];
                    });
                    if (point.r !== undefined) newPoint.r = point.r;
                    return newPoint;
                });
            } };
        }), axis));

        // Extent along it - a pocket's from the face
        if (pocket) {
            fnDepth(axis !== 'y');
        } else {
            $editor.append($('<div class="ladb-hardware-editor-primitive-label">').text(i18next.t('core.hardware_editor.primitive_prism_span', { axis: axis.toUpperCase() })));
            fnRow([
                fnField(itemPath, 'from', false, axis, i18next.t('core.hardware_editor.primitive_from')),
                fnField(itemPath, 'to', false, axis, i18next.t('core.hardware_editor.primitive_to'))
            ]);
        }

        // Outline
        $editor.append($('<div class="ladb-hardware-editor-primitive-separator">'));
        outline.forEach(function (point, index) {
            const pointPath = itemPath.concat([ 'outline', index ]);
            $editor.append($('<div class="ladb-hardware-editor-primitive-label">').text(index === 0 ? i18next.t('core.hardware_editor.primitive_outline') : ''));
            const $radius = fnField(pointPath, 'r', true, null, 'R');
            if (!$radius.attr('title')) {
                fnTooltip($radius, i18next.t('core.hardware_editor.primitive_outline_radius_help'));   // Unless it tells its error
            }
            const $point = $('<div class="ladb-hardware-editor-primitive-fields ladb-hardware-editor-primitive-point">')
                .append(keys.map(function (k) { return fnField(pointPath, k, true, k, k.toUpperCase()); }))
                .append($radius);
            if (!that.readonly) {
                $point.append(fnTooltip($('<button type="button" class="btn btn-default btn-xs">'), i18next.t('default.delete'))
                    .append($('<i class="ladb-opencutlist-icon-minus">'))
                    .prop('disabled', outline.length <= PRISM_MIN_POINTS)
                    .on('click', function () {
                        this.blur();
                        fnWriteOutline(function (points) { points.splice(index, 1); });
                    })
                );
            }
            $editor.append($point);
        });
        if (!this.readonly) {
            // A point in the middle of the closing side : the outline stays as it is
            $editor.append($('<div class="ladb-hardware-editor-part-buttons ladb-hardware-editor-add-buttons ladb-hardware-editor-article-wide">')
                .append($('<button type="button" class="btn btn-default btn-xs">')
                    .append('<i class="ladb-opencutlist-icon-plus"></i> ' + i18next.t('core.hardware_editor.primitive_outline_add'))
                    .on('click', function () {
                        this.blur();
                        fnWriteOutline(function (points) {
                            const point = {};
                            const first = fnObject(points[0]);
                            const last = fnObject(points[points.length - 1]);
                            keys.forEach(function (k) {
                                const a = fnPrismNumber(last[k]), b = fnPrismNumber(first[k]);
                                point[k] = a !== null && b !== null ? Math.round((a + b) / 2 * 100) / 100 : last[k] === undefined ? 0 : last[k];
                            });
                            points.push(point);
                        });
                    })
                )
            );
        }

    };

    // The angle of a countersink, in degrees - 90 when it has none.
    LadbModalHardwareEditor.prototype.renderPrimitiveAngle = function (headPath, head) {
        const that = this;
        const $cell = $('<div class="ladb-hardware-editor-placement-cell ladb-hardware-editor-primitive-cell ladb-hardware-editor-primitive-neutral">');
        const $input = $('<input type="text" class="form-control input-sm ladb-hardware-editor-live" inputmode="decimal">')
            .val(head.angle === undefined ? '' : String(head.angle))
            .attr('placeholder', String(PRIMITIVE_HEAD_DEFAULT_ANGLE))
            .on('input', function () {
                const text = $(this).val().trim().replace(',', '.');
                const angle = parseFloat(text);
                if (text === '' || angle === PRIMITIVE_HEAD_DEFAULT_ANGLE) {
                    that.setJsonMember(headPath, 'angle', undefined);
                } else if (/^\d+(\.\d+)?$/.test(text)) {
                    that.setJsonMember(headPath, 'angle', angle);
                }
            });
        return $cell
            .append($input)
            .append($('<span class="ladb-hardware-editor-primitive-value">').text('°'));
    };

    // The primitive at the given path, as written - a copy - null when it isn't there.
    LadbModalHardwareEditor.prototype.primitiveItem = function (itemPath) {
        const items = this.primitiveItems(itemPath.slice(0, -2), itemPath[itemPath.length - 2]);
        const item = items ? items[itemPath[itemPath.length - 1]] : null;
        return item && typeof item === 'object' ? item : null;
    };

    // The primitives of the given kind in the part at the given path, as
    // written - a copy - an empty list when it has none.
    LadbModalHardwareEditor.prototype.primitiveItems = function (partPath, key) {
        let data;
        try {
            data = JSON.parse(this.cm.getValue());
        } catch (e) {
            return null;
        }
        let target = data;
        for (const k of partPath) {
            target = fnObject(target)[k];
        }
        return Array.isArray(fnObject(target)[key]) ? $.extend(true, [], target[key]) : [];
    };

    // Writes the given primitives of the given kind in the part at the given
    // path, on one line - a kind left without any removed : an empty list
    // isn't valid.
    LadbModalHardwareEditor.prototype.setPrimitiveItems = function (partPath, key, items) {
        if (partPath[partPath.length - 1] === 'machining') {
            this.setMachiningMember(partPath, key, items.length === 0 ? undefined : items);
        } else if (partPath.length > 1 && partPath[partPath.length - 2] === 'hardware') {
            this.setArticleMember(partPath.slice(0, -1), partPath[partPath.length - 1], key, items.length === 0 ? undefined : items);
        } else if (partPath[partPath.length - 1] === 'hardware') {
            // The primitives of a short form : its article
            const primitives = $.extend(true, {}, fnObject(this.jsonValue(partPath)));
            if (items.length === 0) {
                delete primitives[key];
            } else {
                primitives[key] = items;
            }
            const articles = {};
            if (Object.keys(primitives).length > 0) articles[SHORT_ARTICLE_KEY] = primitives;
            if (this.writeHardwareArticles(partPath, articles, this.hardwareArticles(this.jsonValue(partPath)))) {
                this.compute(false);
            }
        } else if (this.setJsonMember(partPath, key, items.length === 0 ? undefined : items)) {
            this.compute(false);
        }
    };

    // Sets the given member - 'skp' or primitives - of the machining at the
    // given path to the given value, undefined removing it. Written in its
    // short form when it can be - see HardwareDescriptorDef "machining" -
    // its SKP alone : true or its path, unless it overrides its parents'
    // machining, whose primitives it would drop.
    LadbModalHardwareEditor.prototype.setMachiningMember = function (partPath, name, value) {
        const current = this.jsonValue(partPath);
        if (current === undefined && this.findJsonValueRange(this.cm.getValue(), partPath) !== null) {
            return;   // The JSON being typed
        }
        const machining = fnIsSkp(current) ? { skp: current } : $.extend(true, {}, fnObject(current));
        if (value === undefined) {
            delete machining[name];
        } else {
            machining[name] = value;
        }
        const keys = Object.keys(machining);
        const short = keys.length === 1 && fnIsSkp(machining.skp) && this.inheritanceState(partPath, false) === null;
        let written;
        if (fnIsEmptyMachining(machining)) {
            written = this.writeJsonValue(partPath, this.inheritanceState(partPath, false) === null ? undefined : null);   // Nothing left : none
        } else if (short) {
            written = this.writeJsonValue(partPath, machining.skp);
        } else if (current !== null && typeof current === 'object' && !(name === 'skp' && value !== undefined && !Object.prototype.hasOwnProperty.call(current, 'skp'))) {
            written = this.setJsonMember(partPath, name, value);   // Only that member rewritten
        } else {
            // Its SKP first, before its primitives
            const ordered = {};
            if (Object.prototype.hasOwnProperty.call(machining, 'skp')) ordered.skp = machining.skp;
            for (const key of keys) {
                if (key !== 'skp') ordered[key] = machining[key];
            }
            written = this.writeJsonValue(partPath, ordered);
        }
        if (written) {
            this.compute(false);
        }
    };

    // Replaces the primitive at the given path by the given one.
    LadbModalHardwareEditor.prototype.setPrimitive = function (itemPath, item) {
        const range = this.findJsonValueRange(this.cm.getValue(), itemPath);
        if (range === null) {
            return;
        }
        this.cm.replaceRange(fnInlineJson(item), this.cm.posFromIndex(range.start), this.cm.posFromIndex(range.end));
        this.compute(false);
    };

    LadbModalHardwareEditor.prototype.addPrimitive = function (slot, partPath, part, key, article) {
        const items = this.primitiveItems(partPath, key);
        if (items === null) {
            return;
        }
        items.push($.extend(true, {}, PRIMITIVE_DEFAULTS[key]));
        this.primitiveOpen = { slot: slot, part: part, key: key, index: items.length - 1 };
        if (article) this.primitiveOpen.article = article;
        this.setPrimitiveItems(partPath, key, items);
    };

    // A copy of the given primitive after it.
    LadbModalHardwareEditor.prototype.duplicatePrimitive = function (primitive, partPath) {
        const items = this.primitiveItems(partPath, primitive.key);
        if (items === null || !items[primitive.index]) {
            return;
        }
        const copy = $.extend(true, {}, items[primitive.index]);
        items.splice(primitive.index + 1, 0, copy);
        this.primitiveOpen = $.extend({}, primitive, { index: primitive.index + 1 });
        this.setPrimitiveItems(partPath, primitive.key, items);
    };

    LadbModalHardwareEditor.prototype.deletePrimitive = function (primitive, partPath) {
        const items = this.primitiveItems(partPath, primitive.key);
        if (items === null || !items[primitive.index]) {
            return;
        }
        items.splice(primitive.index, 1);
        const open = this.primitiveOpen;
        if (open && open.slot === primitive.slot && open.article === primitive.article && open.part === primitive.part && open.key === primitive.key) {
            if (open.index === primitive.index) {
                this.primitiveOpen = null;
            } else if (open.index > primitive.index) {
                this.primitiveOpen = $.extend({}, open, { index: open.index - 1 });
            }
        }
        this.primitiveHovered = null;
        this.setPrimitiveItems(partPath, primitive.key, items);   // The last one of a component's part : {} left, still primitives
    };

    // The given primitive - clicked in the viewer - edited : its row open.
    LadbModalHardwareEditor.prototype.openPrimitive = function (primitive) {
        if (!primitive || !primitive.key) {
            return;
        }
        if (primitive.article) {
            // One of an article : its row open, and the primitive if it is its own
            this.articleOpen = { slot: primitive.slot, key: primitive.article };
            const article = fnObject(this.jsonValue(this.articlesPath(primitive.slot).concat([ primitive.article ])));
            if (article.use !== undefined || primitive.index === undefined) {
                this.primitiveOpen = null;
                $('a[href="#ladb_hardware_editor_tab_parts"]', this.$element).tab('show');
                this.renderParts();
                const $article = $('.ladb-hardware-editor-article[data-article="' + fnArticleId(this.articleOpen) + '"]', this.$parts);
                if ($article.length > 0) {
                    $article.get(0).scrollIntoView({ block: 'nearest' });
                }
                return;
            }
        }
        this.primitiveOpen = primitive;
        if (!primitive.article && primitive.part === 'hardware') {
            this.articleOpen = { slot: primitive.slot, key: SHORT_ARTICLE_KEY };   // Its short form's
        }
        $('a[href="#ladb_hardware_editor_tab_parts"]', this.$element).tab('show');
        this.renderParts();
        const $row = $('.ladb-hardware-editor-primitive[data-primitive="' + fnPrimitiveId(primitive) + '"]', this.$parts);
        if ($row.length > 0) {
            $row.get(0).scrollIntoView({ block: 'nearest' });
        }
    };

    // The primitive hovered - else the one edited - stands out in the viewer.
    LadbModalHardwareEditor.prototype.showBenchPrimitive = function () {
        const $threeViewer = $('.ladb-three-viewer', this.$viewer);
        if ($threeViewer.length > 0 && $threeViewer.data('ladb.threeviewer').loaded) {
            // An article : all its solids - its part's, of a short form
            const that = this;
            const fnArticle = function (article) {
                if (!article) return null;
                return that.hardwareArticles(that.jsonValue(that.articlesPath(article.slot))).implicit ? { slot: article.slot, part: 'hardware' } : { slot: article.slot, article: article.key };
            };
            $threeViewer.ladbThreeViewer('callCommand', [ 'select_bench_solid', { solid: this.primitiveHovered || fnArticle(this.articleHovered) || this.primitiveOpen || fnArticle(this.articleOpen) } ]);
        }
    };

    // The kinematics of the hinge - see HardwareDescriptorDef::HINGE_ATTRIBUTES
    // - of the component at the given path, and of its variant on the bench
    // at the given path - null when it has no variants. What the variant
    // doesn't give comes from the component ; what is typed goes to the
    // variant, until applied to all.
    LadbModalHardwareEditor.prototype.renderHingeKinematics = function ($slot, componentPath, component, variantPath, variant) {
        const that = this;

        const componentAttributes = fnObject(component.attributes);
        const variantAttributes = variantPath === null ? componentAttributes : fnObject(variant.attributes);
        const fnValue = function (name) {
            return variantAttributes[name] !== undefined ? variantAttributes[name] : componentAttributes[name];
        };
        const fnSet = function (name, value) {
            that.setHingeAttribute(componentPath, component, variantPath, name, value, false);
        };

        $slot
            .append($('<div class="ladb-hardware-editor-slot-subtitle">').text(i18next.t('core.hardware_editor.hinge_kinematics')))
            .append($('<div class="ladb-hardware-editor-slot-note">').text(i18next.t('core.hardware_editor.hinge_kinematics_help')));
        if (fnValue('hinge_max_angle') === undefined || fnValue('hinge_pivot') === undefined) {
            $slot.append($('<div class="ladb-hardware-editor-slot-note text-warning">').text(i18next.t('core.hardware_editor.hinge_kinematics_missing')));
        }

        // A row : its control, and - with variants - where its value comes from
        const fnRow = function (name, $control) {
            const $body = $('<div class="ladb-hardware-editor-part-body">').append($control);
            if (variantPath !== null && fnValue(name) !== undefined) {
                const own = variantAttributes[name] !== undefined;
                const $scope = $('<div class="help-block ladb-hardware-editor-hinge-scope">').text(i18next.t('core.hardware_editor.hinge_scope_' + (own ? 'variant' : 'common')));
                if (own && !that.readonly) {
                    $scope
                        .append(' · ')
                        .append($('<a href="#">')
                            .text(i18next.t('core.hardware_editor.hinge_apply_all'))
                            .on('click', function (e) {
                                e.preventDefault();
                                that.setHingeAttribute(componentPath, component, variantPath, name, variantAttributes[name], true);
                            })
                        );
                }
                $body.append($scope);
            }
            $slot.append($('<div class="ladb-hardware-editor-part">')
                .append($('<label class="control-label">').text(i18next.t('core.hardware_editor.' + name)))
                .append($body)
            );
        };

        // The widest opening, in degrees
        const maxAngle = fnValue('hinge_max_angle');
        const $maxAngle = $('<input type="number" min="1" max="180" step="1" class="form-control input-sm">')
            .val(maxAngle === undefined ? '' : maxAngle)
            .prop('disabled', this.readonly)
            .on('change', function () {
                const value = parseFloat($(this).val());
                fnSet('hinge_max_angle', isFinite(value) ? value : undefined);
            });
        fnRow('hinge_max_angle', $('<div class="input-group input-group-sm">')
            .append($maxAngle)
            .append($('<span class="input-group-addon">').text('°'))
        );

        // The axis it turns around : [ y, z ] lengths
        const pivot = fnValue('hinge_pivot');
        const $pivot = $('<div class="ladb-hardware-editor-hinge-pivot">');
        const $inputs = [ 0, 1 ].map(function (index) {
            const raw = Array.isArray(pivot) && pivot[index] !== undefined && pivot[index] !== null ? String(pivot[index]) : '';
            const $input = $('<input type="text" class="form-control input-sm">');
            $pivot.append($('<div class="ladb-hardware-editor-hinge-pivot-coord">')
                .append($input)
                .append($('<div class="help-block">').text(i18next.t('core.hardware_editor.hinge_pivot_' + (index === 0 ? 'y' : 'z'))))
            );
            $input
                .val(fnLengthText(raw))
                .ladbTextinputDimension({ resetValue: '' });
            return $input;
        });
        for (const $input of $inputs) {
            $input.on('change', function () {
                const values = $inputs.map(function ($i) { return fnLengthJson($i.val().trim()); });
                fnSet('hinge_pivot', values[0] === '' && values[1] === '' ? undefined : values.map(function (v) { return v === '' ? '0' : v; }));
            });
        }
        if (this.readonly) {
            $('input', $pivot).prop('disabled', true);
        }
        // Hovered or edited : where it is on the bench
        let pivotHovered = false;
        let pivotFocused = false;
        const fnShowCotes = function () {
            that.showBenchHingeCotes(pivotHovered || pivotFocused);
        };
        $pivot
            .on('mouseenter', function () { pivotHovered = true; fnShowCotes(); })
            .on('mouseleave', function () { pivotHovered = false; fnShowCotes(); })
            .on('focusin', function () { pivotFocused = true; fnShowCotes(); })
            .on('focusout', function () { pivotFocused = false; fnShowCotes(); });
        fnRow('hinge_pivot', $pivot);

        // A multi-link hinge, whose axis moves while it opens
        const $approximate = $('<input type="checkbox">')
            .prop('checked', fnValue('hinge_pivot_approximate') === true)
            .prop('disabled', this.readonly)
            .on('change', function () {
                // Unchecked : false only to override the component's true
                const inherited = variantPath === null ? undefined : componentAttributes['hinge_pivot_approximate'];
                fnSet('hinge_pivot_approximate', $(this).is(':checked') ? true : (inherited === true ? false : undefined));
            });
        fnRow('hinge_pivot_approximate', $('<div class="checkbox">')
            .append($('<label>')
                .append($approximate)
                .append(' ' + i18next.t('core.hardware_editor.hinge_pivot_approximate_help'))
            )
        );

    };

    // Sets - undefined removes - the given attribute of the hinge : on the
    // variant at the given path, or on the component at the given path when
    // it has no variants - variantPath null - or for all its variants, their
    // own values then removed. An attributes object emptied goes too.
    LadbModalHardwareEditor.prototype.setHingeAttribute = function (componentPath, component, variantPath, name, value, all) {
        const that = this;

        const fnSet = function (path, value) {
            const attributesPath = path.concat([ 'attributes' ]);
            that.setJsonMember(attributesPath, name, value);
            if (value === undefined) {
                const text = that.cm.getValue();
                const range = that.findJsonValueRange(text, attributesPath);
                if (range !== null && /^\{\s*\}$/.test(text.substring(range.start, range.end))) {
                    that.setJsonMember(path, 'attributes', undefined);
                }
            }
        };

        if (variantPath === null || all) {
            fnSet(componentPath, value);
            const items = component.variants && component.variants.items ? fnObject(component.variants.items) : {};
            for (const key of Object.keys(items)) {
                if (fnObject(fnObject(items[key]).attributes)[name] !== undefined) {
                    fnSet(componentPath.concat([ 'variants', 'items', key ]), undefined);
                }
            }
        } else {
            fnSet(variantPath, value);
        }
        this.compute(false);

    };

    // The name of the component - or variant - at the given path, edited in place.
    // fnOwns : whether a path is written in its own data - see "extends" -
    // an inherited name is greyed, typed : overridden.
    LadbModalHardwareEditor.prototype.renderPartName = function (path, target, label, placeholder, fnOwns) {
        const that = this;

        const $input = $('<input type="text" class="form-control input-sm">')
            .val(typeof target.name === 'string' ? target.name : '')
            .attr('placeholder', placeholder)
            .prop('disabled', this.readonly)
            .on('change', function () {
                that.setPartName(path, $(this).val().trim());
            });
        const $row = $('<div class="ladb-hardware-editor-part">')
            .append($('<label class="control-label">').text(i18next.t('core.hardware_editor.' + label)))
            .append($('<div class="ladb-hardware-editor-part-body">').append($input));
        $input.ladbTextinputText();
        if (fnOwns) {
            this.appendInheritanceIcon($row, this.inheritanceState(path.concat([ 'name' ]), fnOwns(path.concat([ 'name' ]))), path.concat([ 'name' ]));
        }
        return $row;
    };

    // Sets the name of the component - or variant - at the given path : only
    // its text if it has one, else the component rewritten, its name first -
    // created when only inherited, see "extends".
    LadbModalHardwareEditor.prototype.setPartName = function (path, name) {

        const text = this.cm.getValue();
        const range = this.findJsonValueRange(text, path.concat([ 'name' ]));
        if (range !== null && name) {
            this.cm.replaceRange(JSON.stringify(name), this.cm.posFromIndex(range.start), this.cm.posFromIndex(range.end));
            this.compute(false);
            return;
        }
        if (this.findJsonValueRange(text, path) === null) {
            if (name && this.setJsonMember(path, 'name', name)) {
                this.compute(false);
            }
            return;
        }

        let data;
        try {
            data = JSON.parse(this.cm.getValue());
        } catch (e) {
            return;
        }
        let target = data;
        for (const key of path) {
            target = target[key];
        }
        const value = name ? { name: name } : {};
        for (const key of Object.keys(target)) {
            if (key !== 'name') {
                value[key] = target[key];
            }
        }
        this.replaceJsonValue(path, value);

    };

    // The tools to lay the SKP file of the given ref in its frame - baked
    // into the file at save, never written in the JSON. A grid : one column
    // per axis, X red, Y green, Z blue. Updated in place, onChange told.
    LadbModalHardwareEditor.prototype.renderPlacement = function (ref, onChange) {
        const that = this;

        const fnMatrix = function () {
            return that.placements[ref] || IDENTITY;
        };
        const fnHistory = function () {
            return that.placementHistories[ref] || (that.placementHistories[ref] = []);
        };

        const $placement = $('<div class="ladb-hardware-editor-placement">');
        const $triad = $('<svg class="ladb-hardware-editor-placement-triad" width="28" height="28" viewBox="-14 -14 28 28">');
        const $undo = fnTooltip($('<button type="button" class="btn btn-default btn-xs">'), i18next.t('core.hardware_editor.placement_undo'))
            .append($('<i class="ladb-opencutlist-icon-undo">'));
        const $inputs = [];

        // The part's own axes, as laid, seen from the front right
        const fnRenderTriad = function () {
            const matrix = fnMatrix();
            const screens = [ [ 1, 0.35 ], [ 0.55, -0.5 ], [ 0, -1 ] ];     // Of X, Y, Z
            const eye = [ 1, -1.5, 1 ];
            const lines = AXES.map(function (axis, index) {
                const d = [ matrix[index * 4], matrix[index * 4 + 1], matrix[index * 4 + 2] ];
                return {
                    axis: axis,
                    x: (d[0] * screens[0][0] + d[1] * screens[1][0] + d[2] * screens[2][0]) * 11,
                    y: (d[0] * screens[0][1] + d[1] * screens[1][1] + d[2] * screens[2][1]) * 11,
                    depth: d[0] * eye[0] + d[1] * eye[1] + d[2] * eye[2]
                };
            });
            lines.sort(function (a, b) { return a.depth - b.depth; });   // The farthest first
            $triad.html(lines.map(function (line) {
                return '<line class="ladb-hardware-editor-placement-' + line.axis + '" x1="0" y1="0" x2="' + line.x.toFixed(1) + '" y2="' + line.y.toFixed(1) + '"/>';
            }).join('') + '<circle r="1.6"/>');
        };

        // The fields from the matrix - in model units - but the one typed in
        const fnRefresh = function (typedInput) {
            $undo.prop('disabled', fnHistory().length === 0);
            fnRenderTriad();
            const matrix = fnMatrix();
            rubyCallCommand('hardware_float_to_length', { x: matrix[12], y: matrix[13], z: matrix[14] }, function (response) {
                AXES.forEach(function (axis, index) {
                    if ($inputs[index][0] !== typedInput) {
                        $inputs[index].val(response[axis]);
                    }
                });
            });
        };

        // Lays the part by the given matrix, previous - if any - kept to undo
        const fnApply = function (matrix, previous, typedInput) {
            if (previous && !fnIsSame(previous, matrix)) {
                fnHistory().push(previous);
            }
            that.placements[ref] = matrix;
            fnRefresh(typedInput);
            that.renderBench();
            that.updateGuard();
            onChange();
        };
        const fnTransform = function (by) {
            fnApply(fnMultiply(by, fnMatrix()), fnMatrix());
        };

        const fnButton = function (label, title, onClick) {   // label : a text or an element
            return fnTooltip($('<button type="button">'), title)
                .append(typeof label === 'string' ? document.createTextNode(label) : label)
                .on('click', function () {
                    this.blur();
                    onClick();
                });
        };
        const fnCell = function (axis) {
            return $('<div class="ladb-hardware-editor-placement-cell ladb-hardware-editor-placement-' + axis + '">');
        };
        const fnLabel = function (key) {
            return $('<div class="ladb-hardware-editor-placement-label">').text(i18next.t('core.hardware_editor.placement_' + key));
        };

        // Head
        $undo.on('click', function () {
            this.blur();
            const previous = fnHistory().pop();
            if (previous) {
                fnApply(previous);
            }
        });
        $placement.append($('<div class="ladb-hardware-editor-placement-head">')
            .append($triad)
            .append($('<strong>').text(i18next.t('core.hardware_editor.placement_title')))
            .append($undo)
            .append($('<button type="button" class="btn btn-default btn-xs">')
                .text(i18next.t('core.hardware_editor.placement_reset'))
                .on('click', function () {
                    this.blur();
                    fnApply(IDENTITY.slice(), fnMatrix());
                })
            )
            .append(fnTooltip($('<i class="ladb-opencutlist-icon-info">'), i18next.t('core.hardware_editor.placement_help')))
        );

        const $grid = $('<div class="ladb-hardware-editor-placement-grid">');
        $grid.append($('<div>'));
        AXES.forEach(function (axis) {
            $grid.append($('<div class="ladb-hardware-editor-placement-axis ladb-hardware-editor-placement-' + axis + '">').text(axis.toUpperCase()));
        });

        // Rotation
        $grid.append(fnLabel('rotation'));
        AXES.forEach(function (axis, index) {
            const params = { axis: axis.toUpperCase() };
            $grid.append(fnCell(axis)
                .append(fnButton($('<i class="ladb-opencutlist-icon-rotate-left">'), i18next.t('core.hardware_editor.placement_rotate_ccw', params), function () { fnTransform(fnQuarterTurn(index, 1)); }))
                .append(fnButton($('<i class="ladb-opencutlist-icon-rotate-right">'), i18next.t('core.hardware_editor.placement_rotate_cw', params), function () { fnTransform(fnQuarterTurn(index, -1)); }))
            );
        });

        // Mirror
        $grid.append(fnLabel('mirror'));
        AXES.forEach(function (axis, index) {
            $grid.append(fnCell(axis)
                .append(fnButton($('<i class="ladb-opencutlist-icon-flipped">'), i18next.t('core.hardware_editor.placement_mirror_help', { axis: axis.toUpperCase() }), function () { fnTransform(fnMirror(index)); }))
            );
        });

        // Position : the bench follows the typing, ↑ ↓ nudge it - by 0.5 mm, 5 mm with Shift
        $grid.append(fnLabel('position'));
        AXES.forEach(function (axis, index) {
            const $input = $('<input type="text" class="form-control input-sm">');
            $grid.append(fnCell(axis).append($input));
            $input.ladbTextinputDimension({ resetValue: '0' });
            $inputs.push($input);

            let typingFrom = null;     // The matrix before the typing
            const fnTyped = function (done) {
                const text = $input.val().trim();
                if (text === '') {
                    return;
                }
                rubyCallCommand('core_length_to_float', { value: text }, function (response) {
                    if (typeof response.value !== 'number' || isNaN(response.value) || $input.val().trim() !== text) {
                        return; // Not a length, or typed on since
                    }
                    if (typingFrom === null) {
                        typingFrom = fnMatrix();
                    }
                    const matrix = fnMatrix().slice();
                    matrix[12 + index] = response.value;
                    if (done) {
                        const previous = typingFrom;
                        typingFrom = null;
                        fnApply(matrix, previous);
                    } else {
                        fnApply(matrix, null, $input[0]);
                    }
                });
            };
            $input
                .on('input', function () {
                    fnTyped(false);
                })
                .on('change', function () {
                    fnTyped(true);
                })
                .on('keydown', function (e) {
                    if (e.key !== 'ArrowUp' && e.key !== 'ArrowDown') {
                        return;
                    }
                    e.preventDefault();
                    const matrix = fnMatrix().slice();
                    matrix[12 + index] = Math.round((matrix[12 + index] + (e.shiftKey ? 5 : 0.5) / 25.4 * (e.key === 'ArrowUp' ? 1 : -1)) * 1e9) / 1e9;
                    const previous = typingFrom || fnMatrix();
                    typingFrom = null;
                    fnApply(matrix, previous);
                });
        });

        // Align : centered on the axis, or seated - its top on z = 0
        $grid.append(fnLabel('align'));
        AXES.forEach(function (axis, index) {
            const $cell = fnCell(axis)
                .append(fnButton(i18next.t('core.hardware_editor.placement_center'), i18next.t('core.hardware_editor.placement_center_help', { axis: axis.toUpperCase() }), function () {
                    const matrix = fnMatrix().slice();
                    const box = that.meshBox(that.meshes[that.skpSource(ref)], matrix);
                    matrix[12 + index] -= (box.min[index] + box.max[index]) / 2;
                    fnApply(matrix, fnMatrix());
                }));
            if (axis === 'z') {
                $cell.append(fnButton(i18next.t('core.hardware_editor.placement_seat'), i18next.t('core.hardware_editor.placement_seat_help'), function () {
                    const matrix = fnMatrix().slice();
                    matrix[14] -= that.meshBox(that.meshes[that.skpSource(ref)], matrix).max[2];
                    fnApply(matrix, fnMatrix());
                }));
            }
            $grid.append($cell);
        });

        $placement.append($grid);

        fnRefresh();

        return $placement;
    };

    // The box of the given mesh laid by the given matrix : { min, max }.
    LadbModalHardwareEditor.prototype.meshBox = function (mesh, matrix) {
        const min = [ Infinity, Infinity, Infinity ];
        const max = [ -Infinity, -Infinity, -Infinity ];
        for (let i = 0; i < mesh.faces.length; i += 3) {
            const x = mesh.faces[i], y = mesh.faces[i + 1], z = mesh.faces[i + 2];
            for (let axis = 0; axis < 3; axis++) {
                const v = matrix[axis] * x + matrix[4 + axis] * y + matrix[8 + axis] * z + matrix[12 + axis];
                min[axis] = Math.min(min[axis], v);
                max[axis] = Math.max(max[axis], v);
            }
        }
        return { min: min, max: max };
    };

    // Sets the given part of the component at the given path to the given
    // kind - rewriting only that part in the JSON. None : removed, or null
    // over its parents' - see "extends".
    LadbModalHardwareEditor.prototype.setPartKind = function (path, part, kind) {

        let value;
        if (kind === 'none') {
            value = this.inheritanceState(path.concat([ part ]), false) === null ? undefined : null;
        } else if (kind.indexOf('same_as:') === 0) {
            value = { same_as: kind.substring(8) };
        }

        if (this.writeJsonValue(path.concat([ part ]), value)) {
            this.compute(false);
        }

    };

    // Replaces the value at the given path of the JSON by the given one -
    // indented as where it stands, the rest of the JSON as written.
    LadbModalHardwareEditor.prototype.replaceJsonValue = function (path, value) {

        const text = this.cm.getValue();
        const range = this.findJsonValueRange(text, path);
        if (range === null) {
            return;
        }
        const lineStart = text.lastIndexOf('\n', range.start - 1) + 1;
        const indent = /^\s*/.exec(text.substring(lineStart, range.start))[0];
        this.cm.replaceRange(
            JSON.stringify(value, null, 2).replace(/\n/g, '\n' + indent),
            this.cm.posFromIndex(range.start),
            this.cm.posFromIndex(range.end)
        );
        this.compute(false);

    };

    // Save /////

    // Writes the descriptor - its SKP files picked or placed - then closes :
    // the tool picks it.
    LadbModalHardwareEditor.prototype.save = function () {
        const that = this;

        const ref = this.targetRef();
        if (!ref) {
            return;
        }
        if (!FILE_NAME_REGEX.test(this.fileStem())) {
            this.dialog.notifyErrors([ [ 'core.hardware_editor.error.invalid_file_name', { name: this.fileStem() } ] ]);
            return;
        }

        const imports = {};
        for (const skpRef of Object.keys(this.imports)) {
            imports[skpRef] = this.imports[skpRef].path;
        }
        const placements = {};
        for (const skpRef of Object.keys(this.placements)) {
            if (!fnIsIdentity(this.placements[skpRef])) {
                placements[skpRef] = this.placements[skpRef];
            }
        }

        this.$btnValidate.prop('disabled', true);
        rubyCallCommand('hardware_descriptor_save', {
            ref: ref,
            new: !this.ref,
            from: this.ref && this.ref !== ref ? this.ref : null,
            text: this.cm.getValue(),
            imports: imports,
            placements: placements
        }, function (response) {
            that.$btnValidate.prop('disabled', false);
            if (response.errors) {
                that.dialog.notifyErrors(response.errors);
                return;
            }
            that.dialog.hide(true);
        });

    };

    // Copies the descriptor of the OCL library - read only - into the
    // user's one, then edits the copy.
    LadbModalHardwareEditor.prototype.duplicate = function () {
        const that = this;

        this.$btnDuplicate.prop('disabled', true);
        rubyCallCommand('hardware_descriptor_duplicate', { ref: this.ref }, function (response) {
            that.$btnDuplicate.prop('disabled', false);
            if (response.errors) {
                that.dialog.notifyErrors(response.errors);
                return;
            }
            that.load(response.ref);
            that.dialog.notifySuccess(i18next.t('core.hardware_editor.duplicated', { ref: response.ref }));
        });

    };

    // Edits a new descriptor that extends this one - see "extends" - and
    // only declares its identity : next to it, in the user's library - at
    // the same place for one of the OCL library. Unsaved changes are
    // discarded once confirmed : the child extends the file.
    LadbModalHardwareEditor.prototype.derive = function () {
        const that = this;

        if (!this.ref || this.shaping) {
            return;
        }
        if (this.isDirty()) {
            this.dialog.confirm(i18next.t('default.caution'), i18next.t('core.hardware_editor.discard_confirm'), function () {
                that._cleanGeneration = null;
                that.fileName = null;
                that.imports = {};
                that.placements = {};
                that.placementHistories = {};
                that.derive();
            }, {
                confirmBtnType: 'danger',
                confirmBtnLabel: i18next.t('core.hardware_editor.discard')
            });
            return;
        }

        const parentRef = this.ref;
        const prefix = parentRef.substring(0, parentRef.indexOf('/') + 1);   // '$LIB/' or '$OCL/'
        const relative = parentRef.substring(prefix.length);
        const bundled = prefix === BUNDLED_REF_PREFIX;
        let name = '';
        try {
            name = JSON.parse(this.cm.getValue()).name;
        } catch (e) {
            // Named after its file
        }
        const child = {
            format: 'ocl-hardware',
            version: 1,
            id: fnUuid(),
            extends: bundled ? parentRef : relative,   // Relative to the root of the same library
            name: i18next.t('core.hardware_editor.derived_name', { name: typeof name === 'string' && name ? name : fnFileStem(parentRef), interpolation: { escapeValue: false } })   // Goes in the JSON
        };
        this.ref = null;
        this.readonly = false;
        this.options.dir_ref = USER_REF_PREFIX + relative.substring(0, relative.lastIndexOf('/'));
        this.start(JSON.stringify(child, null, 2));
        this.dialog.notify(i18next.t('core.hardware_editor.derived', { ref: parentRef }), 'info');

    };

    // Edits the parent this descriptor extends. Unsaved changes are
    // discarded once confirmed.
    LadbModalHardwareEditor.prototype.openParent = function () {
        const that = this;

        const parents = this.response && this.response.inheritance ? this.response.inheritance.parents : [];
        if (parents.length === 0 || this.shaping) {
            return;
        }
        if (this.isDirty()) {
            this.dialog.confirm(i18next.t('default.caution'), i18next.t('core.hardware_editor.discard_confirm'), function () {
                that._cleanGeneration = null;
                that.load(parents[0]);
            }, {
                confirmBtnType: 'danger',
                confirmBtnLabel: i18next.t('core.hardware_editor.discard')
            });
            return;
        }
        this.load(parents[0]);

    };

    // Deletes the descriptor - its file and the folder of its parts - once confirmed.
    LadbModalHardwareEditor.prototype.delete = function () {
        const that = this;

        const ref = this.ref;
        this.dialog.confirm(i18next.t('default.caution'), i18next.t('core.hardware_editor.delete_confirm', { name: fnFileStem(ref) + '.json' }), function () {
            rubyCallCommand('hardware_descriptor_delete', { ref: ref }, function (response) {
                if (response.errors) {
                    that.dialog.notifyErrors(response.errors);
                    return;
                }
                that.dialog.hide(true);
            });
        }, {
            confirmBtnType: 'danger',
            confirmBtnLabel: i18next.t('default.delete')
        });

    };

    // SKP files /////

    // The ref the descriptor will have once saved - where its parts declared
    // true are looked for - for a new one.
    LadbModalHardwareEditor.prototype.provisionalRef = function () {
        return this.ref ? null : this.targetRef();
    };

    // File /////

    // The folder the descriptor lives in - or will be written in.
    LadbModalHardwareEditor.prototype.fileDirRef = function () {
        return this.ref ? this.ref.substring(0, this.ref.lastIndexOf('/')) : this.options.dir_ref;
    };

    // The name the file is written with : typed, else its own, else - a new
    // one - the name of the descriptor.
    LadbModalHardwareEditor.prototype.fileStem = function () {
        if (this.fileName) {
            return this.fileName;
        }
        if (this.ref) {
            return fnFileStem(this.ref);
        }
        let name = '';
        try {
            name = JSON.parse(this.cm.getValue()).name;
        } catch (e) {
            // No name for now
        }
        return fnSanitizeFileName(typeof name === 'string' ? name : '') || i18next.t('core.hardware_editor.new_name');
    };

    // The ref the descriptor is written at.
    LadbModalHardwareEditor.prototype.targetRef = function () {
        const dirRef = this.fileDirRef();
        return dirRef ? dirRef + '/' + this.fileStem() + '.json' : null;
    };

    // Where the mesh of the given ref comes from : the file picked to replace it, or itself.
    LadbModalHardwareEditor.prototype.skpSource = function (ref) {
        return this.imports[ref] ? this.imports[ref].path : ref;
    };

    // The SKP files on the bench, laid by their placement - those loaded.
    LadbModalHardwareEditor.prototype.benchSkps = function () {
        const skps = [];
        for (const skp of this.response.skps || []) {
            const mesh = this.meshes[this.skpSource(skp.ref)];
            if (!mesh || mesh === 'loading' || mesh.error) {
                continue;
            }
            skps.push({
                slot: skp.slot,
                part: skp.part,
                refused: skp.article ? this.articleRefused(skp.slot, skp.article) : this.slotRefused(skp.slot),
                transformation: fnMultiply(skp.transformation, this.placements[skp.ref] || IDENTITY),
                faces: mesh.faces,
                edges: mesh.edges
            });
        }
        return skps;
    };

    // The name of the given article of the given slot on the bench : its
    // own, the one of the connector it uses, or its key.
    LadbModalHardwareEditor.prototype.articleName = function (slot, key) {
        const article = this.benchArticle(slot, key);
        if (!article) return key;
        return article.name || article.used_name || key;
    };

    // Is the given article of the given slot on the bench refused - its
    // asserts failing, its connector missing ?
    LadbModalHardwareEditor.prototype.articleRefused = function (slot, key) {
        const article = this.benchArticle(slot, key);
        return !!article && article.ok === false;
    };

    // Does the given slot on the bench fail one of the descriptor's own
    // asserts - see HardwareBenchComputeWorker#_asserts ? Its articles'
    // aren't : they are refused on their own, see articleRefused.
    LadbModalHardwareEditor.prototype.slotRefused = function (slot) {
        return (this.response && this.response.asserts || []).some(function (assert) {
            return (assert.results || []).some(function (result) {
                return !result.ok && (result.slots || []).indexOf(slot) >= 0;
            });
        });
    };

    // The given article of the given slot on the bench - see
    // HardwareBenchComputeWorker#_articles -, undefined if none.
    LadbModalHardwareEditor.prototype.benchArticle = function (slot, key) {
        const slotDef = this.response && this.response.slots ? this.response.slots[slot] : null;
        const articles = slotDef && slotDef.component ? slotDef.component.articles || [] : [];
        return articles.find(function (article) { return article.key === key; });
    };

    // Loads the meshes of the SKP files the bench shows and doesn't have yet.
    LadbModalHardwareEditor.prototype.fetchMeshes = function () {
        const that = this;

        const sources = [];
        for (const skp of this.response.skps || []) {
            const source = this.skpSource(skp.ref);
            if (this.meshes[source] === undefined && sources.indexOf(source) < 0) {
                sources.push(source);
                this.meshes[source] = 'loading';
            }
        }
        if (sources.length === 0) {
            return;
        }
        rubyCallCommand('hardware_skp_mesh', { refs: sources }, function (response) {
            $.extend(that.meshes, response.meshes || {});
            that.renderBench();
            that.renderParts();
        });

    };

    // Picks a SKP file to replace the one of the given ref - copied there at save.
    LadbModalHardwareEditor.prototype.chooseSkp = function (ref) {
        const that = this;
        rubyCallCommand('hardware_skp_choose', null, function (response) {
            if (response.errors) {
                that.dialog.notifyErrors(response.errors);
                return;
            }
            if (!response.path) {
                return;
            }
            that.imports[ref] = response;
            that.placements[ref] = IDENTITY.slice();
            delete that.placementHistories[ref];
            that.fetchMeshes();
            that.renderBench();
            that.renderParts();
            that.updateGuard();
        });
    };

    // Shaping /////

    // Opens the part of the given SKP of the bench for edit in SketchUp, on
    // a bench laid in the model - its placement baked in. The editor waits, small.
    LadbModalHardwareEditor.prototype.startShaping = function (skp) {
        const that = this;

        const ref = skp.ref;
        const mesh = this.meshes[this.skpSource(ref)];
        const name = ref.split('/').pop();
        rubyCallCommand('hardware_skp_edit_start', {
            source: mesh && !mesh.error ? this.skpSource(ref) : null,
            placement: this.placements[ref] || IDENTITY,
            transformation: skp.transformation,
            panels: this.response.panels,
            view: this.response.view_transformation,
            name: name.replace(/\.skp$/i, '')
        }, function (response) {
            if (response.errors) {
                that.dialog.notifyErrors(response.errors);
                return;
            }
            that.shaping = { ref: ref, size: null };
            that.updateGuard();
            $('.ladb-hardware-editor-shaping-name', that.$element).text(i18next.t('core.hardware_editor.shaping', { name: name }));
            that.$element.addClass('ladb-hardware-editor-shaping');
            rubyCallCommand('hardware_editor_resize', { width: SHAPING_WIDTH, height: SHAPING_HEIGHT, left: SHAPING_LEFT, top: SHAPING_TOP }, function (response) {
                if (that.shaping && response.width) {
                    that.shaping.size = response;
                }
            });
        });

    };

    // The part shaped in SketchUp comes back : imported at save, its
    // placement baked in - or not (cancel).
    LadbModalHardwareEditor.prototype.endShaping = function (finish) {
        const that = this;

        const shaping = this.shaping;
        if (!shaping || shaping.ending) {
            return;
        }
        shaping.ending = true;   // A button and the part left : once
        rubyCallCommand(finish ? 'hardware_skp_edit_finish' : 'hardware_skp_edit_cancel', null, function (response) {
            that.shaping = null;
            that.$element.removeClass('ladb-hardware-editor-shaping');
            that.updateGuard();
            rubyCallCommand('hardware_editor_resize', shaping.size || { width: 1100, height: 760 });
            if (response.errors) {
                that.dialog.notifyErrors(response.errors);
                return;
            }
            if (finish && response.path) {
                that.imports[shaping.ref] = { path: response.path, name: shaping.ref.split('/').pop(), edited: true };
                that.placements[shaping.ref] = IDENTITY.slice();
                delete that.placementHistories[shaping.ref];
                that.fetchMeshes();
                that.renderBench();
                that.renderParts();
            }
        });

    };

    // The parse error of the JSON - { line, message } - null if it is valid
    // or the browser doesn't tell where.
    LadbModalHardwareEditor.prototype.jsonError = function () {
        const text = this.cm.getValue();
        try {
            JSON.parse(text);
        } catch (e) {
            let line = null;
            let match = /position (\d+)/.exec(e.message);
            if (match) {
                line = this.cm.posFromIndex(parseInt(match[1])).line;
            } else if ((match = /line (\d+)/.exec(e.message))) {
                line = parseInt(match[1]) - 1;
            } else if (/end of (JSON|data) input/.test(e.message)) {
                line = this.cm.lastLine();
            }
            if (line === null) {
                return null;
            }
            return { line: line, message: e.message.replace(/\s*(in JSON )?at position \d+.*$/, '') };
        }
        return null;
    };

    // Labels /////

    LadbModalHardwareEditor.prototype.topologyLabel = function (topology) {
        if (this.response && this.response.type === 'hinge') {
            return i18next.t('core.hardware_descriptor.variant_' + topology);
        }
        return i18next.t('core.hardware_editor.topology_' + topology);
    };

    LadbModalHardwareEditor.prototype.errorLabel = function (error) {
        const params = error.params || {};
        switch (error.key) {
            case 'unresolved_variable':
            case 'not_a_length':
                return i18next.t('core.hardware_editor.error.' + error.key, params);
            default:
                return i18next.t('tool.default.error.' + error.key, params);
        }
    };

    // The given evaluated assert - see HardwareBenchComputeWorker#_asserts -
    // both sides in numbers, '?' for one that can't be, followed by why :
    // the variable that fails, traced back. Where it is evaluated after.
    LadbModalHardwareEditor.prototype.assertText = function (assert, where) {
        if (!assert.operator) {
            return i18next.t('core.hardware_editor.assert_unresolved');
        }
        let text = (assert.left_text || '?') + ' ' + assert.operator + ' ' + (assert.right_text || '?');
        if (where) {
            text += ' (' + where + ')';
        }
        if (assert.error) {
            text += ' - ' + (assert.error.variable ? '@' + assert.error.variable + ' : ' : '') + this.errorLabel(assert.error);
        } else if (!assert.left_text || !assert.right_text) {
            text += ' - ' + i18next.t('core.hardware_editor.assert_unresolved');
        }
        return text;
    };

    // Edit /////

    // Rewrites the value of the given setting in the JSON - only its text,
    // the rest of the JSON stays as written. An inherited one - see
    // "extends" - is overridden by its value alone.
    LadbModalHardwareEditor.prototype.setSettingValue = function (name, value) {

        const text = this.cm.getValue();
        const range = this.findJsonValueRange(text, [ 'variables', name, 'value' ]);
        if (range === null) {
            if (this.findJsonValueRange(text, [ 'variables', name ]) === null && this.setJsonMember([ 'variables', name ], 'value', value)) {
                this.compute(false);
            }
            return;
        }
        this.cm.replaceRange(
            JSON.stringify(value),
            this.cm.posFromIndex(range.start),
            this.cm.posFromIndex(range.end)
        );
        this.compute(false);

    };

    // Sets the given option of the tool in the JSON - see TOOL_OPTION_GROUPS -
    // the rest of the text as it is. An empty value removes it.
    LadbModalHardwareEditor.prototype.setOptionValue = function (name, value) {
        if (this.setJsonMember([ 'options' ], name, value === '' ? undefined : value)) {
            this.compute(false);
        }
    };

    // Sets the member of the given name of the object at the given path in
    // the JSON - undefined removes it - the rest of the text as it is. A
    // missing object is created in its parent. Doesn't compute : false when
    // nothing changed.
    LadbModalHardwareEditor.prototype.setJsonMember = function (path, name, value) {

        const text = this.cm.getValue();
        const fnReplace = function (start, end, replacement) {
            this.cm.replaceRange(replacement, this.cm.posFromIndex(start), this.cm.posFromIndex(end));
        }.bind(this);

        const objectRange = this.findJsonValueRange(text, path);
        if (objectRange === null) {
            if (value === undefined || path.length === 0) {
                return false;
            }
            const object = {};
            object[name] = value;
            return this.setJsonMember(path.slice(0, -1), path[path.length - 1], object);
        }
        if (text[objectRange.start] !== '{') {
            return false;
        }

        const range = this.findJsonValueRange(text, path.concat([ name ]));
        if (range !== null) {
            if (value !== undefined) {
                fnReplace(range.start, range.end, fnInlineJson(value));
                return true;
            }
            // The member removed, with a comma around it
            let start = text.lastIndexOf(JSON.stringify(name), range.start);
            let end = range.end;
            let i = start;
            while (i > 0 && /\s/.test(text[i - 1])) i--;
            if (text[i - 1] === ',') {
                start = i - 1;
            } else {
                let j = end;
                while (j < text.length && /\s/.test(text[j])) j++;
                if (text[j] === ',') {
                    end = j + 1;
                    while (end < text.length && /\s/.test(text[end])) end++;
                } else {
                    // The only one : the object emptied
                    start = objectRange.start;
                    end = objectRange.end;
                    fnReplace(start, end, '{}');
                    return true;
                }
            }
            fnReplace(start, end, '');
            return true;
        }
        if (value === undefined) {
            return false;
        }

        // Added after the last member : on a line of its own when they are
        const member = JSON.stringify(name) + ': ' + fnInlineJson(value);
        let end = objectRange.end - 1;
        while (end > objectRange.start && /\s/.test(text[end - 1])) end--;
        if (end === objectRange.start + 1) {
            fnReplace(objectRange.start, objectRange.end, '{ ' + member + ' }');
        } else if (text.substring(objectRange.start, objectRange.end).indexOf('\n') >= 0) {
            const lineStart = text.lastIndexOf('\n', end - 1) + 1;
            fnReplace(end, end, ',\n' + /^[ \t]*/.exec(text.substring(lineStart, end))[0] + member);
        } else {
            fnReplace(end, end, ', ' + member);
        }
        return true;

    };

    // Writes the given value at the given path of the JSON - see
    // setJsonMember - laid out from the first object of the path it creates.
    // Doesn't compute : false when nothing changed.
    LadbModalHardwareEditor.prototype.writeJsonValue = function (path, value) {

        let text = this.cm.getValue();
        let createdPath = path;
        for (let k = 1; k < path.length; k++) {
            if (this.findJsonValueRange(text, path.slice(0, k)) === null) {
                createdPath = path.slice(0, k);
                break;
            }
        }
        if (!this.setJsonMember(path.slice(0, -1), path[path.length - 1], value)) {
            return false;
        }

        text = this.cm.getValue();
        const range = this.findJsonValueRange(text, createdPath);
        if (range !== null) {
            const lineStart = text.lastIndexOf('\n', range.start - 1) + 1;
            const indent = /^[ \t]*/.exec(text.substring(lineStart, range.start))[0];
            const laidOut = fnLaidOutJson(JSON.parse(text.substring(range.start, range.end)), indent);
            if (laidOut !== text.substring(range.start, range.end)) {
                this.cm.replaceRange(laidOut, this.cm.posFromIndex(range.start), this.cm.posFromIndex(range.end));
            }
        }
        return true;

    };

    // The range - { start, end } offsets - of the value at the given path of
    // the given JSON text, null if it isn't there or the JSON is invalid.
    LadbModalHardwareEditor.prototype.findJsonValueRange = function (text, path) {

        let i = 0;
        let found = null;

        const fnSkipSpaces = function () {
            while (i < text.length && /\s/.test(text[i])) i++;
        };
        const fnString = function () {
            const start = i;
            i++;
            while (i < text.length && text[i] !== '"') {
                if (text[i] === '\\') i++;
                i++;
            }
            if (i >= text.length) throw 'unterminated';
            i++;
            return JSON.parse(text.substring(start, i));
        };
        const fnValue = function (depth, onPath) {
            fnSkipSpaces();
            const start = i;
            const c = text[i];
            if (c === '{' || c === '[') {
                const object = c === '{';
                let index = 0;
                i++;
                fnSkipSpaces();
                if (text[i] === (object ? '}' : ']')) {
                    i++;
                } else {
                    for (;;) {
                        let key = index++;
                        if (object) {
                            fnSkipSpaces();
                            if (text[i] !== '"') throw 'key';
                            key = fnString();
                            fnSkipSpaces();
                            if (text[i] !== ':') throw 'colon';
                            i++;
                        }
                        fnValue(depth + 1, onPath && depth < path.length && path[depth] === key);
                        fnSkipSpaces();
                        if (text[i] === ',') {
                            i++;
                        } else if (text[i] === (object ? '}' : ']')) {
                            i++;
                            break;
                        } else {
                            throw 'separator';
                        }
                    }
                }
            } else if (c === '"') {
                fnString();
            } else {
                while (i < text.length && !/[\s,}\]]/.test(text[i])) i++;
                if (i === start) throw 'value';
            }
            if (onPath && depth === path.length) {
                found = { start: start, end: i };
            }
        };

        try {
            fnValue(0, true);
        } catch (e) {
            return null;
        }
        return found;
    };

    // Close /////

    // Something typed, picked, placed or shaped, not saved yet.
    LadbModalHardwareEditor.prototype.isDirty = function () {
        if (this.readonly) {
            return false;
        }
        if (this.shaping) {
            return true;
        }
        if (this._cleanGeneration !== null && !this.cm.isClean(this._cleanGeneration)) {
            return true;
        }
        if (this.fileName !== null || Object.keys(this.imports).length > 0) {
            return true;
        }
        for (const ref of Object.keys(this.placements)) {
            if (!fnIsIdentity(this.placements[ref])) {
                return true;
            }
        }
        return false;
    };

    // Closing the window - its close button, or from Ruby - asks first.
    LadbModalHardwareEditor.prototype.updateGuard = function () {
        this.dialog.setGuarded(this.isDirty());
    };

    // Cancel, Escape or the close button of the window : unsaved changes
    // are discarded once confirmed.
    LadbModalHardwareEditor.prototype.confirmClose = function () {
        const that = this;

        if (!this.isDirty()) {
            this.dialog.hide(true);
            return;
        }
        this.dialog.confirm(i18next.t('default.caution'), i18next.t('core.hardware_editor.discard_confirm'), function () {
            that.dialog.hide(true);
        }, {
            confirmBtnType: 'danger',
            confirmBtnLabel: i18next.t('core.hardware_editor.discard')
        });

    };

    // Load /////

    // Edits the given text - of this.ref, or of a new descriptor.
    LadbModalHardwareEditor.prototype.start = function (text) {
        this.response = null;
        this._settingsSignature = null;
        this.fileName = null;
        this.imports = {};
        this.placements = {};
        this.placementHistories = {};
        this.cm.setValue(text);
        this.cm.clearHistory();
        this._cleanGeneration = this.cm.changeGeneration();
        this.cm.setOption('readOnly', this.readonly);
        this.$btnValidate.toggle(!this.readonly);
        this.$btnValidate.prop('disabled', !this.ref && !this.options.dir_ref);
        this.$btnDuplicate.toggle(this.readonly);
        this.$btnDerive.toggle(!!this.ref);
        $('.ladb-hardware-editor-readonly', this.$element).toggle(this.readonly);
        $('.ladb-hardware-editor-json', this.$element).toggleClass('ladb-hardware-editor-json-readonly', this.readonly);
        this.$btnDelete.toggle(!!this.ref && !this.readonly);
        this.updateGuard();
        this.compute(false);
    };

    // Edits the descriptor of the given ref : its text as written.
    LadbModalHardwareEditor.prototype.load = function (ref) {
        const that = this;
        rubyCallCommand('hardware_descriptor_load', { ref: ref }, function (response) {
            if (response.errors) {
                that.dialog.notifyErrors(response.errors);
                that.start('');
                return;
            }
            that.ref = response.ref;
            that.readonly = response.readonly === true;
            that.start(response.text);
        });
    };

    // Init /////

    LadbModalHardwareEditor.prototype.bind = function () {
        LadbAbstractModal.prototype.bind.call(this);

        const that = this;

        // Cancel - and Escape - : unsaved changes are discarded once confirmed
        $('[data-dismiss="modal"]', this.$element)
            .off('click')
            .on('click', function () {
                this.blur();
                that.confirmClose();
            });

        // Bind tabs
        $('a[data-toggle="tab"]', this.$element).on('shown.bs.tab', function (e) {
            if ($(e.target).attr('href') === '#ladb_hardware_editor_tab_json') {
                that.cm.refresh();
            }
        });

    };

    LadbModalHardwareEditor.prototype.init = function () {
        LadbAbstractModal.prototype.init.call(this);

        const that = this;

        decimalSeparator = this.dialog.options.decimal_separator || '.';

        // Fetch UI elements
        this.$topologies = $('.ladb-hardware-editor-topologies', this.$element);
        this.$btnBenchSettings = $('#ladb_hardware_editor_btn_bench_settings', this.$element);
        this.$btnSwap = $('#ladb_hardware_editor_btn_swap', this.$element);
        this.$inputThicknessA = $('#ladb_hardware_editor_input_thickness_a', this.$element);
        this.$inputThicknessB = $('#ladb_hardware_editor_input_thickness_b', this.$element);
        this.$viewer = $('.ladb-hardware-editor-viewer', this.$element);
        this.$unsupported = $('.ladb-hardware-editor-unsupported', this.$element);
        this.$computations = $('.ladb-hardware-editor-computations', this.$element);
        this.$settings = $('.ladb-hardware-editor-settings', this.$element);
        this.$parts = $('.ladb-hardware-editor-parts', this.$element);
        this.$errors = $('.ladb-hardware-editor-errors', this.$element);
        this.$errorCount = $('.ladb-hardware-editor-error-count', this.$element);

        // The value a field had when focused : what is typed since - see captureFocus
        this.$settings.add(this.$parts).on('focusin', FOCUSABLE_SELECTOR, function () {
            $(this).data('ladb-focus-value', this.value);
        });
        this.$btnValidate = $('#ladb_hardware_editor_btn_validate', this.$element);
        this.$btnDuplicate = $('#ladb_hardware_editor_btn_duplicate', this.$element);
        this.$btnDerive = $('#ladb_hardware_editor_btn_derive', this.$element);
        this.$btnDelete = $('#ladb_hardware_editor_btn_delete', this.$element);
        this.$inputFile = $('#ladb_hardware_editor_input_file', this.$element);
        this.$inputName = $('#ladb_hardware_editor_input_name', this.$element);

        // Name of the descriptor : only its text in the JSON - emptied by its
        // reset button, which only triggers 'change'
        this.$inputName
            .ladbTextinputText()
            .on('input change', function () {
                const range = that.findJsonValueRange(that.cm.getValue(), [ 'name' ]);
                if (range !== null) {
                    that.cm.replaceRange(JSON.stringify($(this).val()), that.cm.posFromIndex(range.start), that.cm.posFromIndex(range.end));
                }
            })
            .on('change', function () {
                that.renderName();
            });

        // Shaping : the part edited in SketchUp comes back, or not
        $('#ladb_hardware_editor_btn_shaping_finish', this.$element).on('click', function () {
            this.blur();
            that.endShaping(true);
        });
        $('#ladb_hardware_editor_btn_shaping_cancel', this.$element).on('click', function () {
            this.blur();
            that.endShaping(false);
        });
        addEventCallback('on_hardware_skp_edit_part_left', function () {
            that.endShaping(true);
        });

        // File name : renames at save - a new one follows its name until typed.
        // Emptied - its reset button only triggers 'change' - : back to its
        // own.
        const fnSetFileName = function (text) {
            that.fileName = fnSanitizeFileName(text) || null;
            that.renderFile();
            that.updateGuard();
            if (!that.ref) {
                that.compute(true);   // Its parts are looked for in the folder named after it
            }
        };
        this.$inputFile
            .ladbTextinputText()
            .on('input', function () {
                fnSetFileName($(this).val());
            })
            .on('change', function () {
                if ($(this).val().trim() === '' && that.fileName !== null) {
                    fnSetFileName('');
                }
                $(this).val(that.fileStem());
            });

        // Save : not for the OCL library, nor without a folder to write in
        this.$btnValidate.on('click', function () {
            this.blur();
            that.save();
        });
        this.$btnDuplicate.on('click', function () {
            this.blur();
            that.duplicate();
        });
        $('.ladb-hardware-editor-file-extends', this.$element).on('click', '.ladb-hardware-editor-file-extends-name', function (e) {
            e.preventDefault();
            $(this).closest('[data-toggle="tooltip"]').tooltip('hide');
            that.openParent();
        });
        this.$btnDerive.on('click', function () {
            this.blur();
            that.derive();
        });
        this.$btnDelete.on('click', function () {
            this.blur();
            that.delete();
        });

        // Trial thicknesses : not saved
        // A and B swapped, where they play different parts
        this.$btnSwap
            .on('click', function () {
                this.blur();
                that.swapped = !that.swapped;
                that.compute(false);
            });

        // Refused : a click on the verdict shows the first assert that fails
        $('.ladb-hardware-editor-verdict', this.$element)
            .on('click', function () {
                const $row = $('tr.danger', that.$computations).first();
                if ($row.length === 0) {
                    return;
                }
                that.$computations.stop().animate({
                    scrollTop: that.$computations.scrollTop() + $row.offset().top - that.$computations.offset().top - 10
                }, 200);
                $row.removeClass('ladb-hardware-editor-flash');
                setTimeout(function () { $row.addClass('ladb-hardware-editor-flash'); }, 0);   // Restarted
            });

        // Settings of the bench, in a panel over the trial
        const $benchSettings = $('.ladb-hardware-editor-bench-settings', this.$element);
        const fnToggleBenchSettings = function (visible) {
            $benchSettings.toggle(visible);
            that.$btnBenchSettings.toggleClass('active', visible);
            if (!visible && (hoveredSlot || focusedSlot)) {
                hoveredSlot = focusedSlot = null;
                fnHighlightBenchPanel();
            }
        };
        this.$btnBenchSettings
            .on('click', function () {
                this.blur();
                fnToggleBenchSettings(!$benchSettings.is(':visible'));
            });
        this.$element.on('mousedown', function (e) {
            if ($benchSettings.is(':visible') && $(e.target).closest('.ladb-hardware-editor-trial').length === 0) {
                fnToggleBenchSettings(false);
            }
        });
        // The panel of the hovered or edited setting stands out in the viewer
        let hoveredSlot = null;
        let focusedSlot = null;
        const fnHighlightBenchPanel = function () {
            const $threeViewer = $('.ladb-three-viewer', that.$viewer);
            if ($threeViewer.length > 0 && $threeViewer.data('ladb.threeviewer').loaded) {
                $threeViewer.ladbThreeViewer('callCommand', [ 'highlight_bench_panel', { slot: focusedSlot || hoveredSlot } ]);
            }
        };
        $('.ladb-hardware-editor-bench-setting', $benchSettings)
            .on('mouseenter', function () {
                hoveredSlot = $(this).data('slot');
                fnHighlightBenchPanel();
            })
            .on('mouseleave', function () {
                hoveredSlot = null;
                fnHighlightBenchPanel();
            })
            .on('focusin', function () {
                focusedSlot = $(this).data('slot');
                fnHighlightBenchPanel();
            })
            .on('focusout', function () {
                focusedSlot = null;
                fnHighlightBenchPanel();
            });

        // A click in the 3D gives the focus to the viewer's iframe : this window loses it
        $(window)
            .off('blur.ladbHardwareEditor')
            .on('blur.ladbHardwareEditor', function () {
                if (!$.contains(document, $benchSettings.get(0))) {
                    $(window).off('blur.ladbHardwareEditor');
                    return;
                }
                if ($benchSettings.is(':visible') && $(document.activeElement).is('iframe') && $.contains(that.$viewer.get(0), document.activeElement)) {
                    fnToggleBenchSettings(false);
                }
            });
        this.$inputThicknessA
            .val('19mm')
            .ladbTextinputDimension({ resetValue: '19mm' })
            .on('change', function () {
                that.compute(false);
            });
        this.$inputThicknessB
            .val('19mm')
            .ladbTextinputDimension({ resetValue: '19mm' })
            .on('change', function () {
                that.compute(false);
            });

        // JSON
        this.cm = CodeMirror.fromTextArea($('#ladb_hardware_editor_input_json', this.$element).get(0), {
            mode: 'ocl-hardware-json',
            indentUnit: 2,
            tabSize: 2,
            lineNumbers: true,
            lineWrapping: false,
            autoCloseBrackets: true,
            matchBrackets: true
        });
        this.cm.on('change', function (cm, change) {
            if (change.origin !== 'setValue') {
                that.compute(true);
                that.updateGuard();
            }
        });

        if (this.options.ref) {
            this.load(this.options.ref);
        } else {
            // A new one of the given type
            this.start(JSON.stringify(fnNewDescriptor(this.options.type || 'connector', this.options.length_unit), null, 2));
        }

    };

    // PLUGIN DEFINITION
    // =======================

    function Plugin(option, params) {
        return this.each(function () {
            const $this = $(this);
            let data = $this.data('ladb.modal.plugin');
            const options = $.extend({}, LadbModalHardwareEditor.DEFAULTS, $this.data(), typeof option === 'object' && option);

            if (!data) {
                if (undefined === options.dialog) {
                    throw 'dialog option is mandatory.';
                }
                $this.data('ladb.modal.plugin', (data = new LadbModalHardwareEditor(this, options, options.dialog)));
            }
            if (typeof option === 'string') {
                data[option].apply(data, Array.isArray(params) ? params : [ params ])
            } else {
                data.init();
            }
        })
    }

    const old = $.fn.ladbModalHardwareEditor;

    $.fn.ladbModalHardwareEditor = Plugin;
    $.fn.ladbModalHardwareEditor.Constructor = LadbModalHardwareEditor;


    // NO CONFLICT
    // =================

    $.fn.ladbModalHardwareEditor.noConflict = function () {
        $.fn.ladbModalHardwareEditor = old;
        return this;
    }

}(jQuery);

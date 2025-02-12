// CONSTANTS
// ======================

var EXTENSION_BUILD = '202502120700';   // /!\ Auto-generated line, do not edit //

// UI /////

var SELECT_PICKER_OPTIONS = {
    size: 10,
    iconBase: 'ladb-opencutlist-icon',
    tickIcon: 'ladb-opencutlist-icon-tick',
    showTick: true,
    dropupAuto: false
};

var TOKENFIELD_OPTIONS = {
    delimiter: ';',
    createTokensOnBlur: true,
    beautify: false,
    minWidth: 250
};

var SORTABLE_OPTIONS = {
    cursor: 'ns-resize',
    handle: '.ladb-handle'
};

var SLIDER_OPTIONS = {
    tooltip: 'hide'
};

var TEXTINPUT_COLOR_OPTIONS = {
    resetValue: null
};

// GraphQL /////

var GRAPHQL_ENDPOINT = 'https://api.opencollective.com/graphql/v2/';
var GRAPHQL_SLUG = 'lairdubois-opencutlist-sketchup-extension';

// Materials /////

var REAL_MATERIALS_FILTER = [
    0,  // TYPE_UNKNOWN
    1,  // TYPE_SOLID_WOOD
    2,  // TYPE_SHEET_GOOD
    3,  // TYPE_DIMENSIONAL
    5,  // TYPE_HARDWARE
]

// Three JS /////

var THREE_CAMERA_VIEWS = {
    none: [ 0, 0, 0 ],
    isometric: [ 0.5774, -0.5774, 0.5774 ],
    top: [ 0, 0, 1 ],
    bottom: [ 0, 0, -1 ],
    front: [ 0, -1, 0 ],
    back: [ 0, 1, 0 ],
    left: [ -1, 0, 0 ],
    right: [ 1, 0, 0 ]
}


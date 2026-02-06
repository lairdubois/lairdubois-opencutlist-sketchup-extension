// CONSTANTS
// ======================

const EXTENSION_BUILD = '202602061514';   // /!\ Auto-generated line, do not edit //

// UI /////

const SELECT_PICKER_OPTIONS = {
    size: 10,
    iconBase: 'ladb-opencutlist-icon',
    tickIcon: 'ladb-opencutlist-icon-tick',
    showTick: true,
    dropupAuto: false
};

const TOKENFIELD_OPTIONS = {
    delimiter: ';',
    createTokensOnBlur: true,
    beautify: false,
    minWidth: 250
};

const SORTABLE_OPTIONS = {
    cursor: 'ns-resize',
    handle: '.ladb-handle',
    items: '> :not(.ladb-state-sticky)'
};

const SLIDER_OPTIONS = {
    tooltip: 'hide'
};

const TEXTINPUT_COLOR_OPTIONS = {
    resetValue: null
};

// Data /////

const FORMAT_D = "d";
const FORMAT_D_Q = "dxq";
const FORMAT_D_D = "dxd";
const FORMAT_D_D_Q = "dxdxq";

// GraphQL /////

const GRAPHQL_ENDPOINT = 'https://api.opencollective.com/graphql/v2/';
const GRAPHQL_SLUG = 'lairdubois-opencutlist-sketchup-extension';

// Materials /////

const REAL_MATERIALS_FILTER = [
    0,  // TYPE_UNKNOWN
    1,  // TYPE_SOLID_WOOD
    2,  // TYPE_SHEET_GOOD
    3,  // TYPE_DIMENSIONAL
    5,  // TYPE_HARDWARE
]

// Three JS /////

const THREE_CAMERA_VIEWS = {
    none: [ 0, 0, 0 ],
    isometric: [ 0.5774, -0.5774, 0.5774 ],
    top: [ 0, 0, 1 ],
    bottom: [ 0, 0, -1 ],
    front: [ 0, -1, 0 ],
    back: [ 0, 1, 0 ],
    left: [ -1, 0, 0 ],
    right: [ 1, 0, 0 ]
}


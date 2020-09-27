// CONSTANTS
// ======================

var EW_URL = 'https://extensions.sketchup.com/extension/00f0bf69-7a42-4295-9e1c-226080814e3e/opencutlist';

var GRAPHQL_SLUG = 'lairdubois-opencutlist-sketchup-extension';
var GRAPHQL_ENDPOINT = 'https://api.opencollective.com/graphql/v2/';
var GRAPHQL_PAGE_SIZE = 16;

var SELECT_PICKER_OPTIONS = {
    size: 10,
    iconBase: 'ladb-opencutlist-icon',
    tickIcon: 'ladb-opencutlist-icon-tick',
    showTick: true
};

var TOKENFIELD_OPTIONS = {
    delimiter: ';',
    createTokensOnBlur: true,
    beautify: false,
    minWidth: 250
};

var REGEX_DECIMAL = '[\\d]*(?:(?:\\.|,)[\\d]+)?';
var REGEX_DIMENSION = '(' + REGEX_DECIMAL + '\\s*(?:mm|cm|m|\'|"|)|(?:' + REGEX_DECIMAL + ')*\\s*[\\d]+\/[\\d]+\\s*(?:\'|"|))';
var REGEX_QUANTITY = '(?:\\s*x\\s*([\\d]+)|)';


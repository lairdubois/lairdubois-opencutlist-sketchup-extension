+function ($) {
    'use strict';

    var FORMAT_DEFAULT = 'default';
    var FORMAT_D = 'd';
    var FORMAT_DXQ = 'dxq';
    var FORMAT_DXD = 'dxd';
    var FORMAT_DXDXQ = 'dxdxq';

    var REGEXP_PATTERN_MULTIPLICATOR = '[×xX*]';
    var REGEXP_PATTERN_LENGTH = '(\\d*\\s*\'\\s*\\d*\\s*\\d+\/\\d+\\s*"|\\d*\\s*\\d+\/\\d+(?:\\s*(?:\'|"))?|(?:\\d*[\.,]?)?\\d+(?:\\s*(?:mm|cm|m|\'|"))?)';   // Fractional or Decimal
    var REGEXP_PATTERN_QUANTITY = '(?:\\s*' + REGEXP_PATTERN_MULTIPLICATOR + '\\s*(\\d+))?';

    // CLASS DEFINITION
    // ======================

    var LadbTextinputTokenfield = function (element, options) {
        this.options = options;
        this.$element = $(element);
    };

    LadbTextinputTokenfield.DEFAULTS = $.extend(TOKENFIELD_OPTIONS, {
        format: FORMAT_DEFAULT,     // Define waiting format value
        unique: false               // Define if value must be unique
    });

    LadbTextinputTokenfield.prototype.getTokenRegExp = function() {
        var pattern;
        switch (this.options.format) {
            case FORMAT_D:
                pattern = REGEXP_PATTERN_LENGTH;
                break;
            case FORMAT_DXQ:
                pattern = REGEXP_PATTERN_LENGTH + REGEXP_PATTERN_QUANTITY;
                break;
            case FORMAT_DXD:
                pattern = REGEXP_PATTERN_LENGTH + '\\s*' + REGEXP_PATTERN_MULTIPLICATOR + '\\s*' + REGEXP_PATTERN_LENGTH;
                break;
            case FORMAT_DXDXQ:
                pattern = REGEXP_PATTERN_LENGTH + '\\s*' + REGEXP_PATTERN_MULTIPLICATOR + '\\s*' + REGEXP_PATTERN_LENGTH + REGEXP_PATTERN_QUANTITY;
                break;
            default:
                pattern = '.+';
        }
        return new RegExp('^' + pattern + '$');
    }

    LadbTextinputTokenfield.prototype.getValidTokensList = function () {
        var re = this.getTokenRegExp();
        var validTokens = [];
        var tokens = this.$element.tokenfield('getTokens');
        for (var i = 0; i < tokens.length; i++) {
            if (re.test(tokens[i].value)) {
                validTokens.push(tokens[i].value);
            }
        }
        return validTokens.join(';');
    };

    LadbTextinputTokenfield.prototype.setTokens = function (tokens) {
        this.$element.tokenfield('setTokens', tokens);
    };

    LadbTextinputTokenfield.prototype.tokenfieldSanitizer = function (e) {
        var re = this.getTokenRegExp();
        var m;
        if ((m = re.exec(e.attrs.value)) !== null) {

            switch (this.options.format) {
                case FORMAT_DXQ:
                    e.attrs.value = m[1].trim() + (m[2] ? ' x ' + m[2].trim() : '');
                    e.attrs.label = m[1].trim() + (m[2] ? ' ( x' + m[2].trim() + ' )' : '');
                    break;
                case FORMAT_DXD:
                    e.attrs.value = m[1].trim() + ' x ' + m[2].trim();
                    e.attrs.label = m[1].trim() + ' x ' + m[2].trim();
                    break;
                case FORMAT_DXDXQ:
                    e.attrs.value = m[1].trim() + ' x ' + m[2].trim() + (m[3] ? ' x ' + m[3].trim() : '');
                    e.attrs.label = m[1].trim() + ' x ' + m[2].trim() + (m[3] ? ' ( x' + m[3].trim() + ' )' : '');
                    break;
            }
        }
    };

    LadbTextinputTokenfield.prototype.tokenfieldValidator = function (e) {
        var re = this.getTokenRegExp();
        var valid = re.test(e.attrs.value);
        if (!valid) {
            $(e.relatedTarget)
                .addClass('invalid')
                .prepend('<i class="ladb-opencutlist-icon-warning"></i>')
            ;
        }
        return valid;
    };

    LadbTextinputTokenfield.prototype.destroy = function () {
        this.$element.tokenfield('destroy');
    };

    LadbTextinputTokenfield.prototype.init = function () {
        var that = this;

        this.$element.tokenfield(this.options)
            .on('tokenfield:createtoken', function (e) {
                that.tokenfieldSanitizer(e);
                if (that.options.unique) {
                    var existingTokens = $(this).tokenfield('getTokens');
                    $.each(existingTokens, function (index, token) {
                        if (token.value === e.attrs.value) {
                            e.preventDefault();
                        }
                    });
                }
            })
            .on('tokenfield:createdtoken', function (e) {
                that.tokenfieldValidator(e);
            })
        ;

    };


    // PLUGIN DEFINITION
    // =======================

    function Plugin(option, params) {
        var value;
        var elements = this.each(function () {
            var $this = $(this);
            var data = $this.data('ladb.textinputTokenfield');
            var options = $.extend({}, LadbTextinputTokenfield.DEFAULTS, $this.data(), typeof option === 'object' && option);

            if (!data) {
                $this.data('ladb.textinputTokenfield', (data = new LadbTextinputTokenfield(this, options)));
            }
            if (typeof option === 'string') {
                value = data[option].apply(data, Array.isArray(params) ? params : [ params ])
            } else {
                data.init();
            }
        });
        return typeof value !== 'undefined' ? value : elements;
    }

    var old = $.fn.ladbTextinputTokenfield;

    $.fn.ladbTextinputTokenfield = Plugin;
    $.fn.ladbTextinputTokenfield.Constructor = LadbTextinputTokenfield;


    // NO CONFLICT
    // =================

    $.fn.ladbTextinputTokenfield.noConflict = function () {
        $.fn.ladbTextinputTokenfield = old;
        return this;
    }

}(jQuery);
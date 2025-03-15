+function ($) {
    'use strict';

    const FORMAT_DEFAULT = 'default';
    const FORMAT_D = 'd';
    const FORMAT_DXQ = 'dxq';
    const FORMAT_DXD = 'dxd';
    const FORMAT_DXDXQ = 'dxdxq';

    const REGEXP_PATTERN_MULTIPLICATOR = '[×xX*]';
    const REGEXP_PATTERN_LENGTH = '(\\d*\\s*\'\\s*\\d*\\s*\\d+\/\\d+\\s*"|\\d*\\s*\\d+\/\\d+(?:\\s*(?:\'|"))?|(?:\\d*[\.,]?)?\\d+(?:\\s*(?:mm|cm|m|\'|"))?)';   // Fractional or Decimal
    const REGEXP_PATTERN_QUANTITY = '(?:\\s*' + REGEXP_PATTERN_MULTIPLICATOR + '\\s*(\\d+))?';

    // CLASS DEFINITION
    // ======================

    const LadbTextinputTokenfield = function (element, options) {
        this.options = options;
        this.$element = $(element);
    };

    LadbTextinputTokenfield.DEFAULTS = $.extend({
        format: FORMAT_DEFAULT,     // Define waiting format value
        unique: false               // Define if value must be unique
    }, TOKENFIELD_OPTIONS);

    LadbTextinputTokenfield.prototype.getTokenRegExp = function() {
        let pattern;
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
        const re = this.getTokenRegExp();
        const validTokens = [];
        const tokens = this.$element.tokenfield('getTokens');
        for (let i = 0; i < tokens.length; i++) {
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
        const re = this.getTokenRegExp();
        let m;
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
        const re = this.getTokenRegExp();
        const valid = re.test(e.attrs.value);
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
        const that = this;

        this.$element.tokenfield(this.options)
            .on('tokenfield:createtoken', function (e) {
                that.tokenfieldSanitizer(e);
                if (that.options.unique) {
                    const existingTokens = $(this).tokenfield('getTokens');
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
        let value;
        const elements = this.each(function () {
            const $this = $(this);
            let data = $this.data('ladb.textinputTokenfield');
            if (!data) {
                const options = $.extend({}, LadbTextinputTokenfield.DEFAULTS, $this.data(), typeof option === 'object' && option);
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

    const old = $.fn.ladbTextinputTokenfield;

    $.fn.ladbTextinputTokenfield = Plugin;
    $.fn.ladbTextinputTokenfield.Constructor = LadbTextinputTokenfield;


    // NO CONFLICT
    // =================

    $.fn.ladbTextinputTokenfield.noConflict = function () {
        $.fn.ladbTextinputTokenfield = old;
        return this;
    }

}(jQuery);
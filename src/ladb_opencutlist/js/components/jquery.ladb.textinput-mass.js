+function ($) {
    'use strict';

    // CLASS DEFINITION
    // ======================

    var LadbTextinputMass = function (element, options) {
        LadbAbstractSimpleTextinput.call(this, element, options, '');
    };
    LadbTextinputMass.prototype = new LadbAbstractSimpleTextinput;

    LadbTextinputMass.DEFAULTS = {
        unit: 'kg'
    };

    LadbTextinputMass.prototype.init = function () {
        LadbAbstractSimpleTextinput.prototype.init.call(this);

        this.$element.before('<span class="input-group-addon">' + this.options.unit + '</span>');

    };


    // PLUGIN DEFINITION
    // =======================

    function Plugin(option, params) {
        return this.each(function () {
            var $this = $(this);
            var data = $this.data('ladb.textinputMass');
            var options = $.extend({}, LadbTextinputMass.DEFAULTS, $this.data(), typeof option == 'object' && option);

            if (!data) {
                $this.data('ladb.textinputMass', (data = new LadbTextinputMass(this, options)));
            }
            if (typeof option == 'string') {
                data[option].apply(data, Array.isArray(params) ? params : [ params ])
            } else {
                data.init();
            }
        })
    }

    var old = $.fn.ladbTextinputMass;

    $.fn.ladbTextinputMass = Plugin;
    $.fn.ladbTextinputMass.Constructor = LadbTextinputMass;


    // NO CONFLICT
    // =================

    $.fn.ladbTextinputMass.noConflict = function () {
        $.fn.ladbTextinputMass = old;
        return this;
    }

}(jQuery);
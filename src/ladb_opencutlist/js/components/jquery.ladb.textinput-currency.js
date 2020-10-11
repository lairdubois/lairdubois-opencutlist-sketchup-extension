+function ($) {
    'use strict';

    // CLASS DEFINITION
    // ======================

    var LadbTextinputCurrency = function (element, options) {
        this.options = options;
        this.$element = $(element);
    };

    LadbTextinputCurrency.DEFAULTS = {
        currency: '€'
    };

    LadbTextinputCurrency.prototype.init = function () {
        var that = this;

        this.$element.wrap('<div class="input-group">').before('<span class="input-group-addon">' + this.options.currency + '</span>');

    };


    // PLUGIN DEFINITION
    // =======================

    function Plugin(option, params) {
        return this.each(function () {
            var $this = $(this);
            var data = $this.data('ladb.textinputCurrency');
            var options = $.extend({}, LadbTextinputCurrency.DEFAULTS, $this.data(), typeof option == 'object' && option);

            if (!data) {
                $this.data('ladb.textinputCurrency', (data = new LadbTextinputCurrency(this, options)));
            }
            if (typeof option == 'string') {
                data[option].apply(data, Array.isArray(params) ? params : [ params ])
            } else {
                data.init();
            }
        })
    }

    var old = $.fn.ladbTextinputCurrency;

    $.fn.ladbTextinputCurrency = Plugin;
    $.fn.ladbTextinputCurrency.Constructor = LadbTextinputCurrency;


    // NO CONFLICT
    // =================

    $.fn.ladbTextinputCurrency.noConflict = function () {
        $.fn.ladbTextinputCurrency = old;
        return this;
    }

}(jQuery);
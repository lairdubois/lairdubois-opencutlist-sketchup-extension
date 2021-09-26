+function ($) {
    'use strict';

    // CLASS DEFINITION
    // ======================

    var LadbTextinputDimension = function (element, options) {
        LadbTextinputAbstract.call(this, element, options);
    };
    LadbTextinputDimension.prototype = new LadbTextinputAbstract;

    LadbTextinputDimension.DEFAULTS = {
        resetValue: '0'
    };

    LadbTextinputDimension.prototype.createLeftToolsContainer = function ($toolContainer) {
        // Do not create left tools container
    };


    // PLUGIN DEFINITION
    // =======================

    function Plugin(option, params) {
        var value;
        var elements = this.each(function () {
            var $this = $(this);
            var data = $this.data('ladb.textinputDimension');
            var options = $.extend({}, LadbTextinputDimension.DEFAULTS, $this.data(), typeof option === 'object' && option);

            if (!data) {
                $this.data('ladb.textinputDimension', (data = new LadbTextinputDimension(this, options)));
            }
            if (typeof option === 'string') {
                value = data[option].apply(data, Array.isArray(params) ? params : [ params ])
            } else {
                data.init();
            }
        });
        return typeof value !== 'undefined' ? value : elements;
    }

    var old = $.fn.ladbTextinputDimension;

    $.fn.ladbTextinputDimension = Plugin;
    $.fn.ladbTextinputDimension.Constructor = LadbTextinputDimension;


    // NO CONFLICT
    // =================

    $.fn.ladbTextinputDimension.noConflict = function () {
        $.fn.ladbTextinputDimension = old;
        return this;
    }

}(jQuery);
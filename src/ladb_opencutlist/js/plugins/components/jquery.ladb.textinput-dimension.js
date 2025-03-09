+function ($) {
    'use strict';

    // CLASS DEFINITION
    // ======================

    const LadbTextinputDimension = function (element, options) {
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
        let value;
        const elements = this.each(function () {
            const $this = $(this);
            let data = $this.data('ladb.textinputDimension');
            if (!data) {
                const options = $.extend({}, LadbTextinputDimension.DEFAULTS, $this.data(), typeof option === 'object' && option);
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

    const old = $.fn.ladbTextinputDimension;

    $.fn.ladbTextinputDimension = Plugin;
    $.fn.ladbTextinputDimension.Constructor = LadbTextinputDimension;


    // NO CONFLICT
    // =================

    $.fn.ladbTextinputDimension.noConflict = function () {
        $.fn.ladbTextinputDimension = old;
        return this;
    }

}(jQuery);
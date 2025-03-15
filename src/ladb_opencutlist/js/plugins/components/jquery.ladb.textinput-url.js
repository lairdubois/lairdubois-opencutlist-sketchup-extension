+function ($) {
    'use strict';

    // CLASS DEFINITION
    // ======================

    const LadbTextinputUrl = function(element, options) {
        LadbTextinputAbstract.call(this, element, options);
    };
    LadbTextinputUrl.prototype = new LadbTextinputAbstract;

    LadbTextinputUrl.DEFAULTS = $.extend({
    }, LadbTextinputAbstract.DEFAULTS);

    LadbTextinputUrl.prototype.createLeftToolsContainer = function ($toolContainer) {
        // Do not create left tools container
    };


    // PLUGIN DEFINITION
    // =======================

    function Plugin(option, params) {
        let value;
        const elements = this.each(function () {
            const $this = $(this);
            let data = $this.data('ladb.textinputUrl');
            if (!data) {
                const options = $.extend({}, LadbTextinputUrl.DEFAULTS, $this.data(), typeof option === 'object' && option);
                $this.data('ladb.textinputUrl', (data = new LadbTextinputUrl(this, options)));
            }
            if (typeof option === 'string') {
                value = data[option].apply(data, Array.isArray(params) ? params : [ params ])
            } else {
                data.init();
            }
        });
        return typeof value !== 'undefined' ? value : elements;
    }

    const old = $.fn.ladbTextinputUrl;

    $.fn.ladbTextinputUrl             = Plugin;
    $.fn.ladbTextinputUrl.Constructor = LadbTextinputUrl;


    // NO CONFLICT
    // =================

    $.fn.ladbTextinputUrl.noConflict = function () {
        $.fn.ladbTextinputUrl = old;
        return this;
    }

}(jQuery);
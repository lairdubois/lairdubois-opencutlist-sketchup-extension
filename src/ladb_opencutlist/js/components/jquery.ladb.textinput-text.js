+function ($) {
    'use strict';

    // CLASS DEFINITION
    // ======================

    var LadbTextinputText = function(element, options) {
        LadbTextinputAbstract.call(this, element, options);
    };
    LadbTextinputText.prototype = new LadbTextinputAbstract;

    LadbTextinputText.DEFAULTS = $.extend(LadbTextinputAbstract.DEFAULTS, {
    });

    LadbTextinputText.prototype.createLeftToolsContainer = function ($toolContainer) {
        // Do not create left tools container
    };


    // PLUGIN DEFINITION
    // =======================

    function Plugin(option, params) {
        var value;
        var elements = this.each(function () {
            var $this = $(this);
            var data = $this.data('ladb.textinputText');
            var options = $.extend({}, LadbTextinputText.DEFAULTS, $this.data(), typeof option === 'object' && option);

            if (!data) {
                $this.data('ladb.textinputText', (data = new LadbTextinputText(this, options)));
            }
            if (typeof option === 'string') {
                value = data[option].apply(data, Array.isArray(params) ? params : [ params ])
            } else {
                data.init();
            }
        });
        return typeof value !== 'undefined' ? value : elements;
    }

    var old = $.fn.ladbTextinputText;

    $.fn.ladbTextinputText             = Plugin;
    $.fn.ladbTextinputText.Constructor = LadbTextinputText;


    // NO CONFLICT
    // =================

    $.fn.ladbTextinputText.noConflict = function () {
        $.fn.ladbTextinputText = old;
        return this;
    }

}(jQuery);
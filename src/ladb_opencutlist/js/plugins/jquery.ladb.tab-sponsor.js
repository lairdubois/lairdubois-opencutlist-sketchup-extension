+function ($) {
    'use strict';

    // CLASS DEFINITION
    // ======================

    var LadbTabSponsor = function (element, options, opencutlist) {
        LadbAbstractTab.call(this, element, options, opencutlist);
    };
    LadbTabSponsor.prototype = new LadbAbstractTab;

    LadbTabSponsor.DEFAULTS = {};

    LadbTabSponsor.prototype.init = function (initializedCallback) {
        var that = this;

        // Callback
        if (initializedCallback && typeof(initializedCallback) == 'function') {
            initializedCallback(that.$element);
        }

    };


    // PLUGIN DEFINITION
    // =======================

    function Plugin(option, params) {
        return this.each(function () {
            var $this = $(this);
            var data = $this.data('ladb.tabSponsor');
            var options = $.extend({}, LadbTabSponsor.DEFAULTS, $this.data(), typeof option == 'object' && option);

            if (!data) {
                if (undefined === options.opencutlist) {
                    throw 'opencutlist option is mandatory.';
                }
                $this.data('ladb.tabSponsor', (data = new LadbTabSponsor(this, options, options.opencutlist)));
            }
            if (typeof option == 'string') {
                data[option].apply(data, Array.isArray(params) ? params : [ params ])
            } else {
                data.init(option.initializedCallback);
            }
        })
    }

    var old = $.fn.ladbTabSponsor;

    $.fn.ladbTabSponsor = Plugin;
    $.fn.ladbTabSponsor.Constructor = LadbTabSponsor;


    // NO CONFLICT
    // =================

    $.fn.ladbTabSponsor.noConflict = function () {
        $.fn.ladbTabSponsor = old;
        return this;
    }

}(jQuery);
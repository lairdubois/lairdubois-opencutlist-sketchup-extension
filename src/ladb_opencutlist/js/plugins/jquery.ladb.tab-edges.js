+function ($) {
    'use strict';

    // CLASS DEFINITION
    // ======================

    var LadbTabEdges = function (element, options, opencutlist) {
        LadbAbstractTab.call(this, element, options, opencutlist);

    };
    LadbTabEdges.prototype = new LadbAbstractTab;

    LadbTabEdges.DEFAULTS = {};

    // Internals /////

    LadbTabEdges.prototype.bind = function () {
        LadbAbstractTab.prototype.bind.call(this);

        var that = this;

    };

    LadbTabEdges.prototype.init = function (initializedCallback) {
        var that = this;

        this.bind();

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
            var data = $this.data('ladb.tabEdges');
            var options = $.extend({}, LadbTabEdges.DEFAULTS, $this.data(), typeof option == 'object' && option);

            if (!data) {
                if (undefined === options.opencutlist) {
                    throw 'opencutlist option is mandatory.';
                }
                $this.data('ladb.tabEdges', (data = new LadbTabEdges(this, options, options.opencutlist)));
            }
            if (typeof option == 'string') {
                data[option].apply(data, Array.isArray(params) ? params : [ params ])
            } else {
                data.init(option.initializedCallback);
            }
        })
    }

    var old = $.fn.ladbTabEdges;

    $.fn.ladbTabEdges = Plugin;
    $.fn.ladbTabEdges.Constructor = LadbTabEdges;


    // NO CONFLICT
    // =================

    $.fn.ladbTabEdges.noConflict = function () {
        $.fn.ladbTabEdges = old;
        return this;
    }

}(jQuery);
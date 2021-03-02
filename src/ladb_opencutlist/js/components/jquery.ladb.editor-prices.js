+function ($) {
    'use strict';

    // CLASS DEFINITION
    // ======================

    var LadbEditorPrices = function (element, options) {
        this.options = options;
        this.$element = $(element);

    };

    LadbEditorPrices.DEFAULTS = {
        stds: []
    };
    

    LadbEditorPrices.prototype.init = function () {
    };

    // PLUGIN DEFINITION
    // =======================

    function Plugin(option, params) {
        var value;
        var elements = this.each(function () {
            var $this = $(this);
            var data = $this.data('ladb.editorPrices');
            var options = $.extend({}, LadbEditorPrices.DEFAULTS, $this.data(), typeof option == 'object' && option);

            if (!data) {
                if (undefined === options.dialog) {
                    throw 'dialog option is mandatory.';
                }
                $this.data('ladb.editorPrices', (data = new LadbEditorPrices(this, options)));
            }
            if (typeof option == 'string') {
                value = data[option].apply(data, Array.isArray(params) ? params : [ params ])
            } else {
                data.init();
            }
        });
        return typeof value !== 'undefined' ? value : elements;
    }

    var old = $.fn.ladbEditorPrices;

    $.fn.ladbEditorPrices = Plugin;
    $.fn.ladbEditorPrices.Constructor = LadbEditorPrices;


    // NO CONFLICT
    // =================

    $.fn.ladbEditorPrices.noConflict = function () {
        $.fn.ladbEditorPrices = old;
        return this;
    }

}(jQuery);
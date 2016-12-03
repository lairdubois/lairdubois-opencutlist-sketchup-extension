+function ($) {
    'use strict';

    // CLASS DEFINITION
    // ======================

    var LadbTabMaterials = function (element, options) {
        this.options = options;
        this.$element = $(element);
    };

    LadbTabMaterials.DEFAULTS = {};

    LadbTabMaterials.prototype.init = function () {
    };


    // PLUGIN DEFINITION
    // =======================

    function Plugin(option, params) {
        return this.each(function () {
            var $this = $(this);
            var data = $this.data('ladb.tabMaterials');
            var options = $.extend({}, LadbTabMaterials.DEFAULTS, $this.data(), typeof option == 'object' && option);

            if (!data) {
                $this.data('ladb.tabMaterials', (data = new LadbTabMaterials(this, options)));
            }
            if (typeof option == 'string') {
                data[option](params);
            } else {
                data.init();
            }
        })
    }

    var old = $.fn.ladbTabMaterials;

    $.fn.ladbTabMaterials = Plugin;
    $.fn.ladbTabMaterials.Constructor = LadbTabMaterials;


    // NO CONFLICT
    // =================

    $.fn.ladbTabMaterials.noConflict = function () {
        $.fn.ladbTabMaterials = old;
        return this;
    }

}(jQuery);
+function ($) {
    'use strict';

    // CLASS DEFINITION
    // ======================

    var LadbTabAbout = function (element, options, toolbox) {
        this.options = options;
        this.$element = $(element);
        this.toolbox = toolbox;
    };

    LadbTabAbout.DEFAULTS = {};

    LadbTabAbout.prototype.init = function () {
    };


    // PLUGIN DEFINITION
    // =======================

    function Plugin(option, params) {
        return this.each(function () {
            var $this = $(this);
            var data = $this.data('ladb.tabAbout');
            var options = $.extend({}, LadbTabAbout.DEFAULTS, $this.data(), typeof option == 'object' && option);

            if (!data) {
                if (undefined === options.toolbox) {
                    throw 'toolbox option is mandatory.';
                }
                $this.data('ladb.tabAbout', (data = new LadbTabAbout(this, options, options.toolbox)));
            }
            if (typeof option == 'string') {
                data[option](params);
            } else {
                data.init();
            }
        })
    }

    var old = $.fn.ladbTabAbout;

    $.fn.ladbTabAbout = Plugin;
    $.fn.ladbTabAbout.Constructor = LadbTabAbout;


    // NO CONFLICT
    // =================

    $.fn.ladbTabAbout.noConflict = function () {
        $.fn.ladbTabAbout = old;
        return this;
    }

}(jQuery);
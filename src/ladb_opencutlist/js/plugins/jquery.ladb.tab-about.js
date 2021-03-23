+function ($) {
    'use strict';

    // CLASS DEFINITION
    // ======================

    var LadbTabAbout = function (element, options, opencutlist) {
        LadbAbstractTab.call(this, element, options, opencutlist);
    };
    LadbTabAbout.prototype = new LadbAbstractTab;

    LadbTabAbout.DEFAULTS = {};


    // PLUGIN DEFINITION
    // =======================

    function Plugin(option, params) {
        return this.each(function () {
            var $this = $(this);
            var data = $this.data('ladb.tab.plugin');
            var options = $.extend({}, LadbTabAbout.DEFAULTS, $this.data(), typeof option === 'object' && option);

            if (!data) {
                if (undefined === options.dialog) {
                    throw 'dialog option is mandatory.';
                }
                $this.data('ladb.tab.plugin', (data = new LadbTabAbout(this, options, options.dialog)));
            }
            if (typeof option === 'string') {
                data[option].apply(data, Array.isArray(params) ? params : [ params ])
            } else {
                data.init(option.initializedCallback);
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
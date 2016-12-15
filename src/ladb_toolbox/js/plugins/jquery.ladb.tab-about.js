+function ($) {
    'use strict';

    // CLASS DEFINITION
    // ======================

    var LadbTabAbout = function (element, settings, toolbox) {
        this.settings = settings;
        this.$element = $(element);
        this.toolbox = toolbox;

    };

    LadbTabAbout.DEFAULTS = {};

    LadbTabAbout.prototype.bind = function () {
        var that = this;

    };

    LadbTabAbout.prototype.init = function () {
        this.bind();
    };


    // PLUGIN DEFINITION
    // =======================

    function Plugin(setting, params) {
        return this.each(function () {
            var $this = $(this);
            var data = $this.data('ladg.tabAbout');
            var settings = $.extend({}, LadbTabAbout.DEFAULTS, $this.data(), typeof setting == 'object' && setting);

            if (!data) {
                if (settings.toolbox == undefined) {
                    throw 'toolbox option is mandatory.';
                }
                $this.data('ladg.tabAbout', (data = new LadbTabAbout(this, settings, settings.toolbox)));
            }
            if (typeof setting == 'string') {
                data[setting](params);
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
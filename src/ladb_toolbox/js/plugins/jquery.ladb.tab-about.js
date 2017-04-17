+function ($) {
    'use strict';

    // CLASS DEFINITION
    // ======================

    var LadbTabAbout = function (element, options, toolbox) {
        this.options = options;
        this.$element = $(element);
        this.toolbox = toolbox;

        this.$btnCheckForUpdate = $('#ladb_btn_check_for_update', this.$header);
        this.$btnUpgrade = $('#ladb_btn_upgrade', this.$header);

    };

    LadbTabAbout.DEFAULTS = {};

    LadbTabAbout.prototype.bind = function () {
        var that = this;

        // Bind buttons
        this.$btnCheckForUpdate.on('click', function () {

            rubyCallCommand('check_for_update', {}, function(response) {});

            this.blur();
        });
        this.$btnUpgrade.on('click', function () {

            rubyCallCommand('upgrade', {}, function(response) {});

            this.blur();
        });

    };

    LadbTabAbout.prototype.init = function () {
        this.bind();
    };


    // PLUGIN DEFINITION
    // =======================

    function Plugin(option, params) {
        return this.each(function () {
            var $this = $(this);
            var data = $this.data('ladb.tabAbout');
            var options = $.extend({}, LadbTabAbout.DEFAULTS, $this.data(), typeof option == 'object' && option);

            if (!data) {
                if (options.toolbox == undefined) {
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
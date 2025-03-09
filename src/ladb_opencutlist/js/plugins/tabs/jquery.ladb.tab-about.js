+function ($) {
    'use strict';

    // CLASS DEFINITION
    // ======================

    const LadbTabAbout = function (element, options, dialog) {
        LadbAbstractTab.call(this, element, options, dialog);

        this.$linkChangelog = $('#ladb_link_changelog', this.$element);

    };
    LadbTabAbout.prototype = Object.create(LadbAbstractTab.prototype);

    LadbTabAbout.DEFAULTS = {};

    // Init ///

    LadbTabAbout.prototype.bind = function () {
        LadbAbstractTab.prototype.bind.call(this);

        const that = this;

        // Bind buttons
        this.$linkChangelog.on('click', function () {
            rubyCallCommand('core_open_url', { url: that.dialog.getChangelogUrl() });
        });

    };

    // PLUGIN DEFINITION
    // =======================

    function Plugin(option, params) {
        return this.each(function () {
            const $this = $(this);
            let data = $this.data('ladb.tab.plugin');
            if (!data) {
                const options = $.extend({}, LadbTabAbout.DEFAULTS, $this.data(), typeof option === 'object' && option);
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

    const old = $.fn.ladbTabAbout;

    $.fn.ladbTabAbout = Plugin;
    $.fn.ladbTabAbout.Constructor = LadbTabAbout;


    // NO CONFLICT
    // =================

    $.fn.ladbTabAbout.noConflict = function () {
        $.fn.ladbTabAbout = old;
        return this;
    }

}(jQuery);
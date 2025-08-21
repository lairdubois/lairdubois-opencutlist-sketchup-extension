+function ($) {
    'use strict';

    // CLASS DEFINITION
    // ======================

    const LadbBottombar = function (element, options, dialog) {
        this.options = options;
        this.$element = $(element);
        this.dialog = dialog;
    };

    LadbBottombar.DEFAULTS = {};

    LadbBottombar.prototype.notifyLastNews = function (title) {
        const that = this;

        let $btn = $('<a href="#">')
            .html('<i class="ladb-opencutlist-icon-news-fill"></i> ' + title)
            .on('click', function (e) {
                that.dialog.selectTab('news');
            })
        ;

        $('.ladb-last-news', this.$element).html($btn);

    };

    LadbBottombar.prototype.init = function () {
    };

    // PLUGIN DEFINITION
    // =======================

    function Plugin(option, params) {
        return this.each(function () {
            const $this = $(this);
            let data = $this.data('ladb.bottombar');
            if (!data) {
                const options = $.extend({}, LadbBottombar.DEFAULTS, $this.data(), typeof option === 'object' && option);
                $this.data('ladb.bottombar', (data = new LadbBottombar(this, options, options.dialog)));
            }
            if (typeof option === 'string') {
                data[option].apply(data, Array.isArray(params) ? params : [ params ])
            } else {
                data.init();
            }
        })
    }

    const old = $.fn.ladbBottombar;

    $.fn.ladbBottombar = Plugin;
    $.fn.ladbBottombar.Constructor = LadbBottombar;


    // NO CONFLICT
    // =================

    $.fn.ladbBottombar.noConflict = function () {
        $.fn.ladbBottombar = old;
        return this;
    }

}(jQuery);
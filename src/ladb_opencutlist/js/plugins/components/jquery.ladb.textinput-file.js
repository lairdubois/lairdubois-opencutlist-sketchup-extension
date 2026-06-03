+function ($) {
    'use strict';

    // CLASS DEFINITION
    // ======================

    const LadbTextinputFile = function(element, options) {
        LadbTextinputAbstract.call(this, element, options);
    };
    LadbTextinputFile.prototype = new LadbTextinputAbstract;

    LadbTextinputFile.DEFAULTS = $.extend( {
    }, LadbTextinputAbstract.DEFAULTS);

    LadbTextinputFile.prototype.val = function (value) {
        const val =  LadbTextinputAbstract.prototype.val.call(this, value);
        if (value !== undefined) {
            this.$element[0].scrollLeft = this.$element[0].scrollWidth;
        }
        return val;
    };

    LadbTextinputFile.prototype.createLeftToolsContainer = function ($toolContainer) {
        // Do not create left tools container
    };

    LadbTextinputFile.prototype.init = function () {
        LadbTextinputAbstract.prototype.init.call(this);

        let that = this;

    };

    LadbTextinputFile.prototype.appendRightTools = function ($toolsContainer) {
        const that = this;

        const $browseBtn =
            $('<div class="ladb-textinput-tool ladb-textinput-tool-btn ladb-btn-browse" tabindex="-1" data-toggle="tooltip" title="' + i18next.t('core.component.textinput.browse') + '"><i class="ladb-opencutlist-icon-folder-open"></i></div>')
                .on('click', function() {
                    rubyCallCommand('core_browse_file', {  title: i18next.t('default.open'),  file_path: that.val() }, function (response) {
                        if (response.file_path !== '') {
                           that.val(response.file_path);
                        }
                    });
                })
        ;

        $toolsContainer.append($browseBtn);

        LadbTextinputAbstract.prototype.appendRightTools.call(this, $toolsContainer);
    };

    LadbTextinputFile.prototype.init = function () {
        LadbTextinputAbstract.prototype.init.call(this);

        this.$element[0].scrollLeft = this.$element[0].scrollWidth;

    };


    // PLUGIN DEFINITION
    // =======================

    function Plugin(option, params) {
        let value;
        const elements = this.each(function () {
            const $this = $(this);
            let data = $this.data('ladb.textinputText');
            if (!data) {
                const options = $.extend({}, LadbTextinputFile.DEFAULTS, $this.data(), typeof option === 'object' && option);
                $this.data('ladb.textinputText', (data = new LadbTextinputFile(this, options)));
            }
            if (typeof option === 'string') {
                value = data[option].apply(data, Array.isArray(params) ? params : [ params ])
            } else {
                data.init();
            }
        });
        return typeof value !== 'undefined' ? value : elements;
    }

    const old = $.fn.ladbTextinputFile;

    $.fn.ladbTextinputFile             = Plugin;
    $.fn.ladbTextinputFile.Constructor = LadbTextinputFile;


    // NO CONFLICT
    // =================

    $.fn.ladbTextinputFile.noConflict = function () {
        $.fn.ladbTextinputFile = old;
        return this;
    }

}(jQuery);
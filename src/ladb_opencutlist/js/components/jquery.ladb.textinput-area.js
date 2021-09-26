+function ($) {
    'use strict';

    // CLASS DEFINITION
    // ======================

    var LadbTextinputArea = function(element, options) {
        LadbTextinputAbstract.call(this, element, options);
        this.$preview = null;
    };
    LadbTextinputArea.prototype = new LadbTextinputAbstract;

    LadbTextinputArea.DEFAULTS = {
    };

    LadbTextinputArea.prototype.autoHeight = function() {
        this.$element
            .css('height', 'auto')
            .css('height', (this.$element[0].scrollHeight) + 'px')
        ;
    };

    LadbTextinputArea.prototype.init = function() {
        LadbTextinputAbstract.prototype.init.call(this);

        var that = this;

        this.$element
            .css('overflow-y', 'hidden')
            .css('resize', 'none')
            .attr('rows', 2)
        ;
        this.$element
            .on('input change focus', function () {
                that.autoHeight();
            })
        ;

    };


    // PLUGIN DEFINITION
    // =======================

    function Plugin(option, params) {
        var value;
        var elements = this.each(function () {
            var $this = $(this);
            var data = $this.data('ladb.textinputArea');
            var options = $.extend({}, LadbTextinputArea.DEFAULTS, $this.data(), typeof option === 'object' && option);

            if (!data) {
                $this.data('ladb.textinputArea', (data = new LadbTextinputArea(this, options)));
            }
            if (typeof option === 'string') {
                value = data[option].apply(data, Array.isArray(params) ? params : [ params ])
            } else {
                data.init();
            }
        });
        return typeof value !== 'undefined' ? value : elements;
    }

    var old = $.fn.LadbTextarea;

    $.fn.ladbTextinputArea             = Plugin;
    $.fn.ladbTextinputArea.Constructor = LadbTextinputArea;


    // NO CONFLICT
    // =================

    $.fn.ladbTextinputArea.noConflict = function () {
        $.fn.ladbTextinputArea = old;
        return this;
    }

}(jQuery);
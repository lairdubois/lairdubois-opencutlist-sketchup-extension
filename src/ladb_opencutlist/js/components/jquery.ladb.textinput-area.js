+function ($) {
    'use strict';

    // CLASS DEFINITION
    // ======================

    var LadbTextinputArea = function(element, options) {
        LadbTextinputAbstract.call(this, element, options);
    };
    LadbTextinputArea.prototype = new LadbTextinputAbstract;

    LadbTextinputArea.DEFAULTS = $.extend(LadbTextinputAbstract.DEFAULTS, {
    });

    LadbTextinputArea.prototype.getParentOverflows = function(el) {

        var arr = [];

        while (el && el.parentNode && el.parentNode instanceof Element) {
            if (el.parentNode.scrollTop) {
                arr.push({
                    node: el.parentNode,
                    scrollTop: el.parentNode.scrollTop,
                })
            }
            el = el.parentNode;
        }

        return arr;
    }

    LadbTextinputArea.prototype.autoHeight = function() {

        var overflows = this.getParentOverflows(this.$element[0]);

        this.$element
            .css('height', '')
            .css('height', (this.$element[0].scrollHeight) + 'px')
        ;

        // Prevents scroll-position jumping
        overflows.forEach(function(el) {
            el.node.scrollTop = el.scrollTop
        });

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

    var old = $.fn.ladbTextinputArea;

    $.fn.ladbTextinputArea             = Plugin;
    $.fn.ladbTextinputArea.Constructor = LadbTextinputArea;


    // NO CONFLICT
    // =================

    $.fn.ladbTextinputArea.noConflict = function () {
        $.fn.ladbTextinputArea = old;
        return this;
    }

}(jQuery);
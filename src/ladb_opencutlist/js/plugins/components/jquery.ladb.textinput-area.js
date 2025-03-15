+function ($) {
    'use strict';

    // CLASS DEFINITION
    // ======================

    const LadbTextinputArea = function(element, options) {
        LadbTextinputAbstract.call(this, element, options);
    };
    LadbTextinputArea.prototype = new LadbTextinputAbstract;

    LadbTextinputArea.DEFAULTS = $.extend({
    }, LadbTextinputAbstract.DEFAULTS);

    LadbTextinputArea.prototype.getParentOverflows = function(el) {

        const arr = [];

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

        const overflows = this.getParentOverflows(this.$element[0]);

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

        const that = this;

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
        let value;
        const elements = this.each(function () {
            const $this = $(this);
            let data = $this.data('ladb.textinputArea');
            if (!data) {
                const options = $.extend({}, LadbTextinputArea.DEFAULTS, $this.data(), typeof option === 'object' && option);
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

    const old = $.fn.ladbTextinputArea;

    $.fn.ladbTextinputArea             = Plugin;
    $.fn.ladbTextinputArea.Constructor = LadbTextinputArea;


    // NO CONFLICT
    // =================

    $.fn.ladbTextinputArea.noConflict = function () {
        $.fn.ladbTextinputArea = old;
        return this;
    }

}(jQuery);
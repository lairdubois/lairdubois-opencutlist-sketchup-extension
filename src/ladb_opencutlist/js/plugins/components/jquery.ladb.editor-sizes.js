+function ($) {
    'use strict';

    // CLASS DEFINITION
    // ======================

    const LadbEditorSizes = function (element, options) {
        this.options = options;
        this.$element = $(element);

        this.$rows = $('.ladb-editor-sizes-rows', this.$element);

        this.sizes = [];

    };

    LadbEditorSizes.DEFAULTS = {
        format: 'dxdxq',
        availableSizes: {}
    };

    LadbEditorSizes.prototype.appendRow = function (size) {

        const $row = $(Twig.twig({ref: 'components/_editor-sizes-row.twig'}).render({
            size: size,
        }));
        $row.data('size', size);
        this.$rows.append($row);

        // Fetch UI elements
        const $select = $('select', $row);
        const $inputD1 = $('input.d1', $row);
        const $inputD2 = $('input.d2', $row);
        const $inputQ = $('input.q', $row);

        // Bind
        $inputD1
            .ladbTextinputDimension()
            .ladbTextinputDimension('val', size.d1)
        ;
        $inputD2
            .ladbTextinputDimension()
            .ladbTextinputDimension('val', size.d2)
        ;
        $inputQ
            .ladbTextinputNumberWithUnit()
            .ladbTextinputNumberWithUnit('val', size.q)
        ;

    };

    LadbEditorSizes.prototype.renderRows = function () {

        this.$rows.empty();
        for (let i = 0; i < this.sizes.length; i++) {
            const size = this.sizes[i];
            this.appendRow(size);
        }

    };

    LadbEditorSizes.prototype.setSizes = function (stringSizes) {

        this.sizes = [];
        const arraySizes = stringSizes.split(';');
        for (let i = 0; i < arraySizes.length; i++) {
            const values = arraySizes[i].split('x')
            const size = {
                d1: values[0],
                d2: values[1],
                q: values[2]
            }
            this.sizes.push(size);
        }
        this.renderRows();

    };

    LadbEditorSizes.prototype.getSizes = function () {
        const arraySizes = [];
        for (let i = 0; i < this.sizes.length; i++) {
            const size = this.sizes[i];
            arraySizes.push(size.d1 + 'x' + size.d2 + 'x' + size.q);
        }
        return arraySizes.join(';');
    };

    LadbEditorSizes.prototype.init = function () {
        const that = this;

        // Bind button
        $('button', this.$element).on('click', function () {
            console.log('ADD SIZE', that.options.format, that.options.availableSizes);
            this.blur();
        });

    };

    // PLUGIN DEFINITION
    // =======================

    function Plugin(option, params) {
        let value;
        const elements = this.each(function () {
            const $this = $(this);
            let data = $this.data('ladb.editorStdAttributes');
            const options = $.extend({}, LadbEditorSizes.DEFAULTS, $this.data(), typeof option === 'object' && option);

            if (!data) {
                $this.data('ladb.editorStdAttributes', (data = new LadbEditorSizes(this, options)));
            }
            if (typeof option === 'string') {
                value = data[option].apply(data, Array.isArray(params) ? params : [ params ])
            } else {
                data.init();
            }
        });
        return typeof value !== 'undefined' ? value : elements;
    }

    const old = $.fn.ladbEditorSizes;

    $.fn.ladbEditorSizes = Plugin;
    $.fn.ladbEditorSizes.Constructor = LadbEditorSizes;


    // NO CONFLICT
    // =================

    $.fn.ladbEditorSizes.noConflict = function () {
        $.fn.ladbEditorSizes = old;
        return this;
    }

}(jQuery);
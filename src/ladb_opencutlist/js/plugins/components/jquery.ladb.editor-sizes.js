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
            rowIndex: this.$rows.children().length,
            size: size,
        }));
        $row.data('size', size);
        this.$rows.append($row);

        // Fetch UI elements
        const $input = $('input', $row);

        // Bind button
        $('.ladb-editor-sizes-row-remove', $row).on('click', function () {
            $row.remove();
        });

        let value = '';
        if (size.d1) value += size.d1;
        if (size.d2) value += ' x ' + size.d2;
        if (size.q) value += ' x' + size.q;

        // Bind
        $input
            .ladbTextinputDimension()
            .ladbTextinputDimension('val', value)
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
            that.appendRow({});
            this.blur();
        });

        // Bind sortable
        this.$rows.sortable(SORTABLE_OPTIONS);

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
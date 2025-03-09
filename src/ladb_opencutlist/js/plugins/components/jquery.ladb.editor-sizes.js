+function ($) {
    'use strict';

    // CLASS DEFINITION
    // ======================

    const LadbEditorSizes = function (element, options) {
        this.options = options;
        this.$element = $(element);

        this.$rows = $('.ladb-editor-sizes-rows', this.$element);
        this.$minitools = $('.ladb-editor-sizes-rows-minitools', this.$element);

        this.sizes = [];

    };

    LadbEditorSizes.DEFAULTS = {
        format: 'dxdxq',
        availableSizes: {}
    };

    LadbEditorSizes.prototype.updateToolsVisibility = function () {
        if (this.$rows.children('.ladb-editor-sizes-row').length < 2) {
            $('.ladb-handle', this.$rows).hide();
            $('.ladb-minitools', this.$minitools).hide();
        } else {
            $('.ladb-handle', this.$rows).show();
            $('.ladb-minitools', this.$minitools).show();
        }
    };

    LadbEditorSizes.prototype.appendRow = function (size) {
        const that = this;

        if (this.$rows.children('.ladb-editor-sizes-row').length === 0) {
            this.$rows.empty();
        }

        // Row /////

        const $row = $(Twig.twig({ref: 'components/_editor-sizes-row.twig'}).render({}));
        $row.data('size', size);
        this.$rows.append($row);

        // Fetch UI elements
        const $input = $('input', $row);

        // Bind
        $input
            .ladbTextinputSize()
            .ladbTextinputSize('val', size.val)
        ;
        $input
            .on('change', function () {
                size.val = $(this).ladbTextinputSize('val');
            })
        ;

        // Minitool /////

        const $minitool = $(
            '<div class="ladb-minitools">' +
                '<a href="#" tabindex="-1" class="ladb-editor-sizes-row-remove"><i class="ladb-opencutlist-icon-clear"></i></a>' +
            '</div>'
        );
        this.$minitools.append($minitool);

        // Bind button
        $('.ladb-editor-sizes-row-remove', $minitool).on('click', function () {
            const index = $minitool.index();
            that.removeRow(index);
            $(this).blur();
        });

        this.updateToolsVisibility();

        return $row;
    };

    LadbEditorSizes.prototype.removeRow = function (index) {
        const $row = this.$rows.children('.ladb-editor-sizes-row')[index];
        if ($row) {
            $row.remove();
        }
        const $minitool = this.$minitools.children()[index];
        if ($minitool) {
            $minitool.remove();
        }
        this.updateToolsVisibility();
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
            const val = arraySizes[i];
            const size = { val: val };
            this.sizes.push(size);
        }
        this.renderRows();

    };

    LadbEditorSizes.prototype.getSizes = function () {

        const sizes = [];
        this.$rows.children('.ladb-editor-sizes-row').each(function () {
            const size = $(this).data('size');
            if (size !== undefined && (size.val != null && size.val.length > 0)) {
                sizes.push(size.val);
            }
        });

        return sizes.join(';');
    };

    LadbEditorSizes.prototype.init = function () {
        const that = this;

        // Bind button
        $('button', this.$element).on('click', function () {
            const $row = that.appendRow({});
            $('input', $row).focus();
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
            let data = $this.data('ladb.editorSizes');
            if (!data) {
                const options = $.extend({}, LadbEditorSizes.DEFAULTS, $this.data(), typeof option === 'object' && option);
                $this.data('ladb.editorSizes', (data = new LadbEditorSizes(this, options)));
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
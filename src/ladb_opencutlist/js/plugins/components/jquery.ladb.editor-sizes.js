+function ($) {
    'use strict';

    // CLASS DEFINITION
    // ======================

    const LadbEditorSizes = function (element, options) {
        this.options = options;
        this.$element = $(element);

        this.$rows = $('.ladb-editor-sizes-rows', this.$element);
        this.$removeRows = $('.ladb-editor-sizes-remove-rows', this.$element);

        this.sizes = [];

    };

    LadbEditorSizes.DEFAULTS = {
        format: FORMAT_D_D_Q,
        d1Placeholder: 'Longueur',
        d2Placeholder: 'Largeur',
        qPlaceholder: '1',
        qHidden: false,
        availableSizes: {}
    };

    LadbEditorSizes.prototype.updateToolsVisibility = function () {
        if (this.$rows.children('.ladb-editor-sizes-row').length < 2) {
            $('.ladb-handle', this.$rows).hide();
            $('.ladb-editor-sizes-remove-row', this.$removeRows).hide();
        } else {
            $('.ladb-handle', this.$rows).show();
            $('.ladb-editor-sizes-remove-row', this.$removeRows).show();
        }
    };

    LadbEditorSizes.prototype.appendRow = function (size, autoFocus = false) {
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

        let options = {
            d1Placeholder: this.options.d1Placeholder,
            d2Placeholder: this.options.d2Placeholder,
            qPlaceholder: this.options.qPlaceholder,
            d2Disabled: this.options.format === FORMAT_D || this.options.format === FORMAT_D_Q,
            qDisabled: this.options.format === FORMAT_D || this.options.format === FORMAT_D_D,
            d2Hidden: this.options.format === FORMAT_D || this.options.format === FORMAT_D_Q,
            qHidden: this.options.qHidden && (this.options.format === FORMAT_D || this.options.format === FORMAT_D_D),
            separator1Label: this.options.format === FORMAT_D || this.options.format === FORMAT_D_Q ? '' : 'x',
            separator2Label: !this.options.qHidden || this.options.format === FORMAT_D_Q || this.options.format === FORMAT_D_D_Q ? 'Qte' : '',
        }

        // Bind
        $input
            .ladbTextinputSize(options)
            .ladbTextinputSize('val', size.val)
        ;
        $input
            .on('change', function () {
                size.val = $(this).ladbTextinputSize('val');
            })
        ;
        if (autoFocus) {
            $input.ladbTextinputSize('focus');
        }

        // Remove row /////

        const $removeRow = $(
            '<div class="ladb-editor-sizes-remove-row">' +
                '<button tabindex="-1" class="btn btn-default btn-xs"><i class="ladb-opencutlist-icon-minus"></i></button>' +
            '</div>'
        );
        this.$removeRows.append($removeRow);

        // Bind button
        $('button', $removeRow).on('click', function () {
            const index = $removeRow.index();
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
        const $removeRow = this.$removeRows.children('.ladb-editor-sizes-remove-row')[index];
        if ($removeRow) {
            $removeRow.remove();
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
            that.appendRow({}, true);
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
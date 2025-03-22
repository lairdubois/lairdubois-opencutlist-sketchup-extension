+function ($) {
    'use strict';

    // CLASS DEFINITION
    // ======================

    const LadbEditorSizes = function (element, options) {
        this.options = options;
        this.$element = $(element);

        this.$empty = $('.ladb-editor-sizes-empty', this.$element);
        this.$rows = $('.ladb-editor-sizes-rows', this.$element);
        this.$removeRows = $('.ladb-editor-sizes-remove-rows', this.$element);

        this.sizes = [];

        this.availableSizes = null;

    };

    LadbEditorSizes.DEFAULTS = {
        format: FORMAT_D_D_Q,
        d1Placeholder: i18next.t('default.length'),
        d2Placeholder: i18next.t('default.width'),
        qPlaceholder: '1',
        qHidden: false,
        emptyDisplayed: true,
        emptyVal: '',
        dropdownActionCallback: null,
        dropdownActionLabel: null
    };

    LadbEditorSizes.prototype.updateToolsVisibility = function () {
        let rowCount = this.$rows.children('.ladb-editor-sizes-row').length;
        if (rowCount === 0) {
            if (this.options.emptyDisplayed) {
                this.$empty.show();
            } else {
                this.appendRow({});
                this.$empty.hide();
            }
        } else {
            this.$empty.hide();
        }
        const $handle = $('.ladb-handle', this.$rows);
        if (rowCount < 2) {
            $handle.hide();
        } else {
            $handle.show();
        }
    };

    LadbEditorSizes.prototype.appendRow = function (size, options = { autoFocus: false, autoFill: false }) {
        const that = this;

        if (this.$rows.children('.ladb-editor-sizes-row').length === 0) {
            this.$rows.empty();
        }

        // Row /////

        const $row = $(
            '<div class="ladb-editor-sizes-row">' +
                '<input type="hidden">' +
                '<div class="ladb-textinput-tool ladb-handle"><i class="ladb-opencutlist-icon-reorder"></i></div>' +
            '</div>')
        ;
        $row.data('size', size);
        this.$rows.append($row);

        // Fetch UI elements
        const $input = $('input', $row);

        // Bind
        $input
            .ladbTextinputSize({
                d1Placeholder: this.options.d1Placeholder,
                d2Placeholder: this.options.d2Placeholder,
                qPlaceholder: this.options.qPlaceholder,
                d2Disabled: this.options.format === FORMAT_D || this.options.format === FORMAT_D_Q,
                qDisabled: this.options.format === FORMAT_D || this.options.format === FORMAT_D_D,
                d2Hidden: this.options.format === FORMAT_D || this.options.format === FORMAT_D_Q,
                qHidden: this.options.qHidden && (this.options.format === FORMAT_D || this.options.format === FORMAT_D_D),
                dSeparatorLabel: this.options.format === FORMAT_D || this.options.format === FORMAT_D_Q ? '' : 'x',
                qSeparatorLabel: !this.options.qHidden || this.options.format === FORMAT_D_Q || this.options.format === FORMAT_D_D_Q ? i18next.t('core.component.textinput_size.quantity') : '',
                feeder: that.availableSizes ? function () { return that.getAvailableVals(); } : null,
                dropdownActionLabel: that.options.dropdownActionLabel,
                dropdownActionCallback: that.options.dropdownActionCallback
            })
            .ladbTextinputSize('val', size.val)
        ;
        $input
            .on('change', function () {
                size.val = $(this).ladbTextinputSize('val');

                // Convert size to inch float representation
                rubyCallCommand('core_length_to_float', { dim: size.val }, function (response) {

                    size.dim = Array.isArray(response.dim) ? response.dim.join('x') : response.dim;

                });

            })
        ;
        if (options.autoFocus) {
            $input.ladbTextinputSize('focus');
        }
        if (options.autoFill) {
            $input.ladbTextinputSize('val', that.getAvailableVals()[0]);
            $input.trigger('change');
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
        this.$removeRows.empty();
        for (let i = 0; i < this.sizes.length; i++) {
            const size = this.sizes[i];
            this.appendRow(size);
        }
        this.updateToolsVisibility();

    };

    LadbEditorSizes.prototype.getCurrentSizes = function () {

        const sizes = [];
        this.$rows.children('.ladb-editor-sizes-row').each(function () {
            const size = $(this).data('size');
            if (size !== undefined && (size.val != null && size.val.length > 0)) {
                sizes.push(size);
            }
        });

        return sizes;
    };

    LadbEditorSizes.prototype.getCurrentDims = function () {

        const dims = [];
        this.getCurrentSizes().forEach(function (size) {
            dims.push(size.dim);
        });

        return dims;
    };

    LadbEditorSizes.prototype.getCurrentVals = function () {

        const vals = [];
        this.getCurrentSizes().forEach(function (size) {
            vals.push(size.val);
        });
        if (vals.length === 0) {
            vals.push(this.options.emptyVal);
        }

        return vals;
    };

    LadbEditorSizes.prototype.isAvailableDim = function (dim) {
        if (this.availableSizes === null) {
            return true;
        }
        for (let i = 0; i < this.availableSizes.length; i++) {
            if  (this.availableSizes[i].dim === dim) {
                return true;
            }
        }
        return false;
    }

    LadbEditorSizes.prototype.getAvailableVals = function () {

        const vals = [];
        const dims = this.getCurrentDims();

        this.availableSizes.forEach(function (size) {
            if (!dims.includes(size.dim)) {
                vals.push(size.val);
            }
        });

        return vals;
    };

    LadbEditorSizes.prototype.setAvailableSizesAndSizes = function (stringAvailableSizes, stringSizes) {
        var that = this;

        this.availableSizes = [];

        const sizes = {};
        const arraySizes = stringAvailableSizes.split(';');
        for (let i = 0; i < arraySizes.length; i++) {
            const val = arraySizes[i];
            sizes[val] = val;
        }

        // Convert size to inch float representation
        rubyCallCommand('core_length_to_float', sizes, function (response) {

            for (let key in response) {
                that.availableSizes.push({
                    val: key,
                    dim: Array.isArray(response[key]) ? response[key].join('x') : response[key]
                });
            }

            that.setSizes(stringSizes);

        });

    };

    LadbEditorSizes.prototype.setSizes = function (stringSizes) {
        var that = this;

        this.sizes = [];

        const toConvertSizes = {};
        const vals = stringSizes.split(';');
        for (let i = 0; i < vals.length; i++) {
            const val = vals[i];
            if (val !== '') {
                toConvertSizes[val] = val;
            }
        }

        if (Object.keys(toConvertSizes).length === 0 && that.availableSizes !== null) {
            toConvertSizes[that.availableSizes[0].val] = that.availableSizes[0].val;
        }

        // Convert size to inch float representation
        rubyCallCommand('core_length_to_float', toConvertSizes, function (response) {

            for (let key in response) {

                // Exclude '0' or '0x0' values
                if ((/^\s*0\s*x*\s*0*\s*$/.exec(key)) !== null) {
                    continue;
                }

                const val = key;
                const dim = Array.isArray(response[key]) ? response[key].join('x') : response[key];

                if (that.availableSizes === null || that.isAvailableDim(dim)) {    // May exclude unavailable sizes
                    that.sizes.push({
                        val: val,
                        dim: dim
                    });
                }

            }
            that.renderRows();

        });

    };

    LadbEditorSizes.prototype.getSizes = function () {
        return this.getCurrentVals().join(';');
    };

    LadbEditorSizes.prototype.init = function () {
        const that = this;

        // Bind button
        $('button', this.$element).on('click', function () {
            $(this).blur();
            that.appendRow({}, { autoFocus: that.availableSizes === null, autoFill: that.availableSizes !== null });
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
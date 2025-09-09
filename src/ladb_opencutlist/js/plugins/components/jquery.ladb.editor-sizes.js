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
        this.$btnAppend = $('.ladb-editor-sizes-btn-append', this.$element);

        this.availableSizeDefs = null;

        this.val = '';

    };

    LadbEditorSizes.DEFAULTS = {
        format: FORMAT_D_D_Q,
        d1Placeholder: '',
        d2Placeholder: '',
        qPlaceholder: '1',
        qHidden: false,
        emptyDisplayed: true,
        emptyVal: '',
        dropdownActionCallback: null,
        dropdownActionLabel: null
    };

    LadbEditorSizes.prototype.updateVal = function () {
        this.val = this.getCurrentVals().join(';');
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

    LadbEditorSizes.prototype.appendRow = function (sizeDef, options = { autoFocus: false, autoFill: false }) {
        const that = this;

        // Default empty size def
        if (typeof sizeDef !== 'object') {
            sizeDef = {};
        }

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
        $row.data('size-def', sizeDef);
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
                feederCallback: that.availableSizeDefs ? function () { return that.getAvailableVals(); } : null,
                dropdownActionLabel: that.options.dropdownActionLabel,
                dropdownActionCallback: that.options.dropdownActionCallback
            })
            .ladbTextinputSize('val', sizeDef.val)
        ;
        $input
            .on('change', function () {
                sizeDef.val = $(this).ladbTextinputSize('val');

                // Convert size to inch float representation
                rubyCallCommand('core_length_to_float', { dim: sizeDef.val }, function (response) {

                    sizeDef.dim = Array.isArray(response.dim) ? response.dim.join('x') : response.dim;

                });

                that.updateVal();

            })
            .on('plusminusdown', function (e) {
                if (e.key === '+') {
                    that.appendRow({}, { autoFocus: that.availableSizeDefs === null, autoFill: that.availableSizeDefs !== null });
                    e.preventDefault();
                    return false;
                } else if (e.key === '-') {
                    that.removeRow($row.index());
                    $('input[type="hidden"]', that.$rows.children().last()).ladbTextinputSize('focus');
                    e.preventDefault();
                    return false;
                }
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
        this.updateVal();
    };

    LadbEditorSizes.prototype.getCurrentSizeDefs = function () {

        const sizes = [];
        this.$rows.children('.ladb-editor-sizes-row').each(function () {
            const sizeDef = $(this).data('size-def');
            if (sizeDef !== undefined && (sizeDef.val != null && sizeDef.val.length > 0)) {
                sizes.push(sizeDef);
            }
        });

        return sizes;
    };

    LadbEditorSizes.prototype.getCurrentDims = function () {

        const dims = [];
        this.getCurrentSizeDefs().forEach(function (sizeDef) {
            dims.push(sizeDef.dim);
        });

        return dims;
    };

    LadbEditorSizes.prototype.getCurrentVals = function () {

        const vals = [];
        this.getCurrentSizeDefs().forEach(function (sizeDef) {
            vals.push(sizeDef.val);
        });
        if (vals.length === 0) {
            vals.push(this.options.emptyVal);
        }

        return vals;
    };

    LadbEditorSizes.prototype.isAvailableDim = function (dim) {
        if (this.availableSizeDefs === null) {
            return true;
        }
        for (let i = 0; i < this.availableSizeDefs.length; i++) {
            if  (this.availableSizeDefs[i].dim === dim) {
                return true;
            }
        }
        return false;
    }

    LadbEditorSizes.prototype.getAvailableVals = function () {

        const vals = [];
        const dims = this.getCurrentDims();

        this.availableSizeDefs.forEach(function (sizeDef) {
            if (!dims.includes(sizeDef.dim)) {
                vals.push(sizeDef.val);
            }
        });

        return vals;
    };

    LadbEditorSizes.prototype.setAvailableSizesAndSizes = function (availableSizes, sizes) {
        const that = this;

        this.availableSizeDefs = [];

        const toConvertSizes = {};
        const arraySizes = availableSizes.split(';');
        for (let i = 0; i < arraySizes.length; i++) {
            const val = arraySizes[i];
            toConvertSizes[val] = val;
        }

        // Convert size to inch float representation
        rubyCallCommand('core_length_to_float', toConvertSizes, function (response) {

            for (let key in response) {
                that.availableSizeDefs.push({
                    val: key,
                    dim: Array.isArray(response[key]) ? response[key].join('x') : response[key]
                });
            }

            that.setSizes(sizes);

        });

    };

    LadbEditorSizes.prototype.setSizes = function (sizes) {
        const that = this;

        // Sanitize
        if (typeof sizes !== 'string') {
            sizes = '';
        }

        // Keep given value for instant valid getter
        this.val = sizes;

        let sizeDefs = [];

        const toConvertSizes = {};
        const vals = sizes.split(';');
        for (let i = 0; i < vals.length; i++) {
            const val = vals[i];
            if (val !== '') {
                toConvertSizes[val] = val;
            }
        }

        // Convert size to inch float representation
        rubyCallCommand('core_length_to_float', toConvertSizes, function (response) {

            let forcedToBeEmpty = false;

            for (let key in response) {

                // Exclude '0' or '0x0' values
                if ((/^\s*0\s*x*\s*0*\s*$/.exec(key)) !== null) {
                    forcedToBeEmpty = true;
                    continue;
                }

                const val = key;
                const dim = Array.isArray(response[key]) ? response[key].join('x') : response[key];

                if (that.availableSizeDefs === null || that.isAvailableDim(dim)) {    // May exclude unavailable sizes
                    sizeDefs.push({
                        val: val,
                        dim: dim
                    });
                }

            }

            // Auto select first available size if needed
            if (!forcedToBeEmpty && sizeDefs.length === 0 && that.availableSizeDefs !== null) {
                sizeDefs.push(that.availableSizeDefs[0]);
            }

            // Render rows
            that.$rows.empty();
            that.$removeRows.empty();
            for (let i = 0; i < sizeDefs.length; i++) {
                const size = sizeDefs[i];
                that.appendRow(size);
            }
            that.updateToolsVisibility();
            that.updateVal();

        });

    };

    LadbEditorSizes.prototype.getSizes = function () {
        return this.val;
    };

    LadbEditorSizes.prototype.init = function () {
        const that = this;

        // Bind empty
        this.$empty.on('click', function (e) {
            $(this).blur();
            that.appendRow({}, { autoFocus: that.availableSizeDefs === null, autoFill: that.availableSizeDefs !== null });
        });

        // Bind button
        this.$btnAppend.on('click', function () {
            $(this).blur();
            that.appendRow({}, { autoFocus: that.availableSizeDefs === null, autoFill: that.availableSizeDefs !== null });
        });

        // Bind sortable
        this.$rows.sortable($.extend({
            update: function (event, ui) {
                that.updateVal();
            }
        }, SORTABLE_OPTIONS));

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
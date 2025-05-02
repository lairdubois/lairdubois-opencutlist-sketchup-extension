+function ($) {
    'use strict';

    // CLASS DEFINITION
    // ======================

    const LadbEditorStdAttributes = function (element, options) {
        this.options = options;
        this.$element = $(element);

        this.$rows = $('.ladb-editor-std-attributes-rows', this.$element);

        this.type = 0;
        this.stds = null;
        this.stdsA = [];
        this.stdsB = [];
        this.defaultUnit = null;
        this.enabledUnitsRow0 = [];
        this.enabledUnitsRowN = [];

        this.stdAttributes = [];

    };

    LadbEditorStdAttributes.DEFAULTS = {
        strippedName: '',
        units: [],
        defaultUnitByTypeCallback: null,
        enabledUnitsByTypeCallback: null,
        inputChangeCallback: null
    };

    LadbEditorStdAttributes.prototype.prependAttributeRow0 = function (stdAttribute) {
        const that = this;

        const $row = $(Twig.twig({ref: 'components/_editor-std-attributes-row-0.twig'}).render({
            strippedName: this.options.strippedName
        }));
        $row.data('std-attribute', stdAttribute);
        this.$rows.prepend($row);

        // Fetch UI elements
        const $input = $('input', $row);

        // Bind
        $input
            .ladbTextinputNumberWithUnit({
                defaultUnit: this.defaultUnit,
                units: this.enabledUnitsRow0
            })
            .ladbTextinputNumberWithUnit('val', stdAttribute.val)
        ;
        $input
            .on('change', function () {
                stdAttribute.val = $(this).ladbTextinputNumberWithUnit('val');

                // Change callback
                if (that.options.inputChangeCallback) {
                    that.options.inputChangeCallback();
                }

            })
        ;

        return $row;
    };

    LadbEditorStdAttributes.prototype.appendAttributeRowN = function (stdAttribute) {
        const that = this;

        const $row = $(Twig.twig({ref: 'components/_editor-std-attributes-row-n.twig'}).render({
            stdsA: this.stdsA,
            stdsB: this.stdsB,
        }));
        $row.data('std-attribute', stdAttribute);
        this.$rows.append($row);

        // Fetch UI elements
        const $select = $('select', $row);
        const $input = $('input', $row);

        // Bind button
        $('.ladb-editor-std-attributes-row-remove', $row).on('click', function () {
           $row.remove();
           const index = that.stdAttributes.indexOf(stdAttribute);
           if (index > -1) {
               that.stdAttributes.splice(index, 1);
           }
        });

        // Bind
        $select
            .selectpicker(SELECT_PICKER_OPTIONS)
            .selectpicker('val', stdAttribute.dim)
        ;
        $select
            .on('change', function () {
                const newDim = $(this).selectpicker('val');
                $('select', that.$element).each(function () {
                    if (this === $select[0]) {
                        return;
                    }
                    const $tmpSelect = $(this);
                    $('option', $(this)).each(function () {
                        const $option = $(this);
                        if ($option.html() === stdAttribute.dim) {
                            $option.prop('disabled', false);
                        } else if ($option.html() === newDim) {
                            $option.prop('disabled', true);
                        }
                        $tmpSelect.selectpicker('refresh');
                    });
                });
                stdAttribute.dim = newDim;

                // Change callback
                if (that.options.inputChangeCallback) {
                    that.options.inputChangeCallback();
                }

            })
        ;
        $input
            .ladbTextinputNumberWithUnit({
                defaultUnit: this.defaultUnit,
                units: this.enabledUnitsRowN,
            })
            .ladbTextinputNumberWithUnit('val', stdAttribute.val)
        ;
        $input
            .on('change', function () {
                stdAttribute.val = $(this).ladbTextinputNumberWithUnit('val');

                // Change callback
                if (that.options.inputChangeCallback) {
                    that.options.inputChangeCallback();
                }

            })
        ;

        // Disable used options
        const $options = $('option', $select);
        for (let i = 0; i < this.stdAttributes.length; i++) {
            const tmpStdAttribute = this.stdAttributes[i];
            if (tmpStdAttribute !== stdAttribute) {
                $options.each(function () {
                    const $option = $(this);
                    if ($option.html() === tmpStdAttribute.dim) {
                        $option.prop('disabled', true);
                    }
                });
            }
        }
        $select.selectpicker('refresh');

        return $row;
    };

    LadbEditorStdAttributes.prototype.renderRows = function () {

        // Render rows
        this.$rows.empty();
        for (let i = 0; i < this.stdAttributes.length; i++) {
            const stdAttribute = this.stdAttributes[i];
            if (stdAttribute.dim == null) {
                this.prependAttributeRow0(stdAttribute);
            } else {
                this.appendAttributeRowN(stdAttribute);
            }
        }

    };

    LadbEditorStdAttributes.prototype.setTypeAndStds = function (type, stds) {
        this.type = type;
        this.setStds(stds);
    };

    LadbEditorStdAttributes.prototype.setStds = function (stds) {
        const that = this;

        this.stds = stds;
        this.stdsA = [];
        this.stdsB = [];

        const stdsA = {};
        const stdsB = {};
        let i;
        switch (this.type) {

            case 1: /* TYPE_SOLID_WOOD */
                for (i = 0; i < stds.stdThicknesses.length; i++) {
                    stdsA[stds.stdThicknesses[i]] = stds.stdThicknesses[i];
                }
                break;

            case 2: /* TYPE_SHEET_GOOD */
                for (i = 0; i < stds.stdThicknesses.length; i++) {
                    stdsA[stds.stdThicknesses[i]] = stds.stdThicknesses[i];
                }
                for (i = 0; i < stds.stdSizes.length; i++) {
                    stdsB[stds.stdSizes[i]] = stds.stdSizes[i];
                }
                break;

            case 3: /* TYPE_DIMENSIONAL */
                for (i = 0; i < stds.stdSections.length; i++) {
                    stdsA[stds.stdSections[i]] = stds.stdSections[i];
                }
                for (i = 0; i < stds.stdLengths.length; i++) {
                    stdsB[stds.stdLengths[i]] = stds.stdLengths[i];
                }
                break;

            case 4: /* TYPE_EDGE */
                for (i = 0; i < stds.stdWidths.length; i++) {
                    stdsA[stds.stdWidths[i]] = stds.stdWidths[i];
                }
                for (i = 0; i < stds.stdLengths.length; i++) {
                    stdsB[stds.stdLengths[i]] = stds.stdLengths[i];
                }
                break;

            case 6: /* TYPE_VENEER */
                for (i = 0; i < stds.stdSizes.length; i++) {
                    stdsA[stds.stdSizes[i]] = stds.stdSizes[i];
                }
                break;

        }

        this.defaultUnit = this.options.defaultUnitByTypeCallback(this.type);

        let enabledUnitKeys;
        this.enabledUnitsRow0 = [];
        enabledUnitKeys = this.options.enabledUnitsByTypeCallback(this.type, '0');
        if (enabledUnitKeys) {
            $.each(this.options.units, function (index, unitGroup) {
                const g = {};
                $.each(unitGroup, function (key, value) {
                    if (enabledUnitKeys.includes(key)) {
                        g[key] = value;
                    }
                });
                if (Object.keys(g).length > 0) {
                    that.enabledUnitsRow0.push(g);
                }
            });
        }
        this.enabledUnitsRowN = [];
        enabledUnitKeys = this.options.enabledUnitsByTypeCallback(this.type, 'N');
        if (enabledUnitKeys) {
            $.each(this.options.units, function (index, unitGroup) {
                const g = {};
                $.each(unitGroup, function (key, value) {
                    if (enabledUnitKeys.includes(key)) {
                        g[key] = value;
                    }
                });
                if (Object.keys(g).length > 0) {
                    that.enabledUnitsRowN.push(g);
                }
            });
        }

        // Convert stds to inch float representation
        rubyCallCommand('core_length_to_float', stdsA, function (responseA) {

            $.each(responseA, function (k, v) {
               if (Array.isArray(v)) {
                   responseA[k] = v[0] + 'x' + v[1];
               } else {
                   responseA[k] = v
               }
            });
            that.stdsA = responseA;

            rubyCallCommand('core_length_to_float', stdsB, function (responseB) {

                $.each(responseB, function (k, v) {
                    if (Array.isArray(v)) {
                        responseB[k] = v[0] + 'x' + v[1];
                    } else {
                        responseB[k] = v
                    }
                });
                that.stdsB = Object.keys(responseB).length === 0 ? {} : responseB;

                // Render rows
                that.renderRows();

            });
        });

    };

    LadbEditorStdAttributes.prototype.setStdAttributes = function (stdAttributes) {
        if (!Array.isArray(stdAttributes)) {
            stdAttributes = [];
        }

        // Cleanup input
        this.stdAttributes = [];
        let stdAttribute;
        let has0 = false;
        for (let i = 0; i < stdAttributes.length; i++) {
            stdAttribute = stdAttributes[i];
            if (stdAttribute != null) {
                if (stdAttribute.dim == null) {
                    if (!has0) {
                        this.stdAttributes.unshift(stdAttribute);
                        has0 = true;
                    }
                } else if (stdAttribute.val != null && stdAttribute.val.length > 0 && stdAttribute.dim.length > 0) {
                    this.stdAttributes.push(stdAttribute);
                }
            }
        }
        if (!has0) {
            this.stdAttributes.unshift({
                val: '',
                dim: null
            });
        }

        // Render rows if "stds" are ready
        if (Object.keys(this.stdsA).length > 0 && Object.keys(this.stdsB).length > 0) {
            this.renderRows();
        }

    };

    LadbEditorStdAttributes.prototype.getStdAttributes = function () {

        const stdAttributes = [];
        this.$rows.children().each(function () {
            const stdAttribute = $(this).data('std-attribute');
            if (stdAttribute !== undefined && (stdAttribute.dim == null || stdAttribute.val != null && stdAttribute.val.length > 0 && stdAttribute.dim.length > 0)) {
                stdAttributes.push(stdAttribute);
            }
        });

        return stdAttributes;
    };

    LadbEditorStdAttributes.prototype.init = function () {
        const that = this;

        // Bind button
        $('button', this.$element).on('click', function () {
            const stdAttribute = {
                val: '',
                dim: ''
            }
            that.stdAttributes.push(stdAttribute);
            const $row = that.appendAttributeRowN(stdAttribute);
            $('input', $row).focus();
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
            if (!data) {
                const options = $.extend({}, LadbEditorStdAttributes.DEFAULTS, $this.data(), typeof option === 'object' && option);
                $this.data('ladb.editorStdAttributes', (data = new LadbEditorStdAttributes(this, options)));
            }
            if (typeof option === 'string') {
                value = data[option].apply(data, Array.isArray(params) ? params : [ params ])
            } else {
                data.init();
            }
        });
        return typeof value !== 'undefined' ? value : elements;
    }

    const old = $.fn.ladbEditorStdAttributes;

    $.fn.ladbEditorStdAttributes = Plugin;
    $.fn.ladbEditorStdAttributes.Constructor = LadbEditorStdAttributes;


    // NO CONFLICT
    // =================

    $.fn.ladbEditorStdAttributes.noConflict = function () {
        $.fn.ladbEditorStdAttributes = old;
        return this;
    }

}(jQuery);
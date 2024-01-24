+function ($) {
    'use strict';

    // CLASS DEFINITION
    // ======================

    var LadbEditorStdAttributes = function (element, options) {
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
        var that = this;

        var $row = $(Twig.twig({ref: 'components/_editor-std-attributes-row-0.twig'}).render({
            strippedName: this.options.strippedName
        }));
        this.$rows.prepend($row);

        // Fetch UI elements
        var $input = $('input', $row);

        // Bind
        $input
            .ladbTextinputNumberWithUnit({
                defaultUnit: this.defaultUnit,
                units: this.enabledUnitsRow0,
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
        var that = this;

        var $row = $(Twig.twig({ref: 'components/_editor-std-attributes-row-n.twig'}).render({
            stdsA: this.stdsA,
            stdsB: this.stdsB,
        }));
        this.$rows.append($row);

        // Fetch UI elements
        var $select = $('select', $row);
        var $input = $('input', $row);

        // Bind button
        $('.ladb-editor-std-attributes-row-remove', $row).on('click', function () {
           $row.remove();
           var index = that.stdAttributes.indexOf(stdAttribute);
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
                var newDim = $(this).selectpicker('val');
                $('select', that.$element).each(function () {
                    if (this === $select[0]) {
                        return;
                    }
                    var $tmpSelect = $(this);
                    $('option', $(this)).each(function () {
                        var $option = $(this);
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
        var $options = $('option', $select);
        for (var i = 0; i < this.stdAttributes.length; i++) {
            var tmpStdAttribute = this.stdAttributes[i];
            if (tmpStdAttribute !== stdAttribute) {
                $options.each(function () {
                    var $option = $(this);
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
        for (var i = 0; i < this.stdAttributes.length; i++) {
            var stdAttribute = this.stdAttributes[i];
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
        var that = this;

        this.stds = stds;
        this.stdsA = [];
        this.stdsB = [];

        var stdsA = {};
        var stdsB = {};
        var i;
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

        this.enabledUnitsRow0 = [];
        var enabledUnitKeys = this.options.enabledUnitsByTypeCallback(this.type, '0');
        if (enabledUnitKeys) {
            $.each(this.options.units, function (index, unitGroup) {
                var g = {};
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
        var enabledUnitKeys = this.options.enabledUnitsByTypeCallback(this.type, 'N');
        if (enabledUnitKeys) {
            $.each(this.options.units, function (index, unitGroup) {
                var g = {};
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
                that.stdsB = Object.keys(responseB).length === 0 ? { '':'' } : responseB;

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
        var stdAttribute;
        var has0 = false;
        for (var i = 0; i < stdAttributes.length; i++) {
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

        // Cleanup input
        var stdAttributes = [];
        for (var i = 0; i < this.stdAttributes.length; i++) {
            var stdAttribute = this.stdAttributes[i];
            if (stdAttribute.dim == null || stdAttribute.val != null && stdAttribute.val.length > 0 && stdAttribute.dim.length > 0) {
                stdAttributes.push(stdAttribute);
            }
        }

        return stdAttributes;
    };

    LadbEditorStdAttributes.prototype.init = function () {
        var that = this;

        // Bind button
        $('button', this.$element).on('click', function () {
            var stdAttribute = {
                val: '',
                dim: ''
            }
            that.stdAttributes.push(stdAttribute);
            var $row = that.appendAttributeRowN(stdAttribute);
            $('input', $row).focus();
            this.blur();
        });

    };

    // PLUGIN DEFINITION
    // =======================

    function Plugin(option, params) {
        var value;
        var elements = this.each(function () {
            var $this = $(this);
            var data = $this.data('ladb.editorStdAttributes');
            var options = $.extend({}, LadbEditorStdAttributes.DEFAULTS, $this.data(), typeof option === 'object' && option);

            if (!data) {
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

    var old = $.fn.ladbEditorStdAttributes;

    $.fn.ladbEditorStdAttributes = Plugin;
    $.fn.ladbEditorStdAttributes.Constructor = LadbEditorStdAttributes;


    // NO CONFLICT
    // =================

    $.fn.ladbEditorStdAttributes.noConflict = function () {
        $.fn.ladbEditorStdAttributes = old;
        return this;
    }

}(jQuery);
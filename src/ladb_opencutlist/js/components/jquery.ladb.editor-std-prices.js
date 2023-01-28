+function ($) {
    'use strict';

    // CLASS DEFINITION
    // ======================

    var LadbEditorStdPrices = function (element, options) {
        this.options = options;
        this.$element = $(element);

        this.$rows = $('.ladb-editor-std-prices-rows', this.$element);

        this.type = 0;
        this.stds = null;
        this.stdsA = [];
        this.stdsB = [];
        this.defaultUnit = null;
        this.units = [
            {
                $_m: options.currencySymbol + ' / m',
                $_m2: options.currencySymbol + ' / m²',
                $_m3: options.currencySymbol + ' / m³',
            },
            {
                $_fbm: options.currencySymbol + ' / fbm',
                $_ft: options.currencySymbol + ' / ft',
                $_ft2: options.currencySymbol + ' / ft²',
                $_ft3: options.currencySymbol + ' / ft³',
            },
            {
                $_i: options.currencySymbol + ' / ' + i18next.t('default.instance_single')
            }
        ];
        this.enabledUnits = [];

        this.stdPrices = [];

    };

    LadbEditorStdPrices.DEFAULTS = {
        lengthUnitStrippedname: '',
        currencySymbol: '',
        inputChangeCallback: null
    };

    LadbEditorStdPrices.prototype.prependPriceRow0 = function (stdPrice) {
        var that = this;

        var $row = $(Twig.twig({ref: 'components/_editor-std-prices-row-0.twig'}).render());
        this.$rows.prepend($row);

        // Fetch UI elements
        var $input = $('input', $row);

        // Bind
        $input
            .ladbTextinputNumberWithUnit({
                defaultUnit: this.defaultUnit,
                units: this.enabledUnits,
            })
            .ladbTextinputNumberWithUnit('val', stdPrice.val)
        ;
        $input
            .on('change', function () {
                stdPrice.val = $(this).ladbTextinputNumberWithUnit('val');

                // Change callback
                if (that.options.inputChangeCallback) {
                    that.options.inputChangeCallback();
                }

            })
        ;

        return $row;
    };

    LadbEditorStdPrices.prototype.appendPriceRowN = function (stdPrice) {
        var that = this;

        var $row = $(Twig.twig({ref: 'components/_editor-std-prices-row-n.twig'}).render({
            stdsA: this.stdsA,
            stdsB: this.stdsB,
        }));
        this.$rows.append($row);

        // Fetch UI elements
        var $select = $('select', $row);
        var $input = $('input', $row);

        // Bind button
        $('.ladb-editor-std-prices-row-remove', $row).on('click', function () {
           $row.remove();
           var index = that.stdPrices.indexOf(stdPrice);
           if (index > -1) {
               that.stdPrices.splice(index, 1);
           }
        });

        // Bind
        $select
            .selectpicker(SELECT_PICKER_OPTIONS)
            .selectpicker('val', stdPrice.dim)
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
                        if ($option.html() === stdPrice.dim) {
                            $option.prop('disabled', false);
                        } else if ($option.html() === newDim) {
                            $option.prop('disabled', true);
                        }
                        $tmpSelect.selectpicker('refresh');
                    });
                });
                stdPrice.dim = newDim;

                // Change callback
                if (that.options.inputChangeCallback) {
                    that.options.inputChangeCallback();
                }

            })
        ;
        $input
            .ladbTextinputNumberWithUnit({
                defaultUnit: this.defaultUnit,
                units: this.enabledUnits,
            })
            .ladbTextinputNumberWithUnit('val', stdPrice.val)
        ;
        $input
            .on('change', function () {
                stdPrice.val = $(this).ladbTextinputNumberWithUnit('val');

                // Change callback
                if (that.options.inputChangeCallback) {
                    that.options.inputChangeCallback();
                }

            })
        ;

        // Disable used options
        var $options = $('option', $select);
        for (var i = 0; i < this.stdPrices.length; i++) {
            var tmpStdPrice = this.stdPrices[i];
            if (tmpStdPrice !== stdPrice) {
                $options.each(function () {
                    var $option = $(this);
                    if ($option.html() === tmpStdPrice.dim) {
                        $option.prop('disabled', true);
                    }
                });
            }
        }
        $select.selectpicker('refresh');

        return $row;
    };

    LadbEditorStdPrices.prototype.renderRows = function () {

        // Render rows
        this.$rows.empty();
        for (var i = 0; i < this.stdPrices.length; i++) {
            var stdPrice = this.stdPrices[i];
            if (stdPrice.dim == null) {
                this.prependPriceRow0(stdPrice);
            } else {
                this.appendPriceRowN(stdPrice);
            }
        }

    };

    LadbEditorStdPrices.prototype.setTypeAndStds = function (type, stds) {
        this.type = type;
        this.setStds(stds);
    };

    LadbEditorStdPrices.prototype.setStds = function (stds) {
        var that = this;

        this.stds = stds;
        this.stdsA = [];
        this.stdsB = [];

        var stdsA = {};
        var stdsB = {};
        var i;
        var enabledUnitKeys;
        switch (this.type) {

            case 1: /* TYPE_SOLID_WOOD */
                for (i = 0; i < stds.stdThicknesses.length; i++) {
                    stdsA[stds.stdThicknesses[i]] = stds.stdThicknesses[i];
                }
                this.defaultUnit = '$_' + (that.options.lengthUnitStrippedname === 'ft' ? 'fbm' : that.options.lengthUnitStrippedname + '3');
                enabledUnitKeys = [ '$_m3', '$_ft3', '$_fbm' ];
                break;

            case 2: /* TYPE_SHEET_GOOD */
                for (i = 0; i < stds.stdThicknesses.length; i++) {
                    stdsA[stds.stdThicknesses[i]] = stds.stdThicknesses[i];
                }
                for (i = 0; i < stds.stdSizes.length; i++) {
                    stdsB[stds.stdSizes[i]] = stds.stdSizes[i];
                }
                this.defaultUnit = '$_' + that.options.lengthUnitStrippedname + '2';
                enabledUnitKeys = [ '$_m2', '$_m3', '$_ft2', '$_ft3', '$_ft2', '$_i' ];
                break;

            case 3: /* TYPE_DIMENSIONAL */
                for (i = 0; i < stds.stdSections.length; i++) {
                    stdsA[stds.stdSections[i]] = stds.stdSections[i];
                }
                for (i = 0; i < stds.stdLengths.length; i++) {
                    stdsB[stds.stdLengths[i]] = stds.stdLengths[i];
                }
                this.defaultUnit = '$_' + that.options.lengthUnitStrippedname;
                enabledUnitKeys = [ '$_m', '$_m2', '$_m3', '$_ft', '$_ft2', '$_ft3', '$_i' ];
                break;

            case 4: /* TYPE_EDGE */
                for (i = 0; i < stds.stdWidths.length; i++) {
                    stdsA[stds.stdWidths[i]] = stds.stdWidths[i];
                }
                for (i = 0; i < stds.stdLengths.length; i++) {
                    stdsB[stds.stdLengths[i]] = stds.stdLengths[i];
                }
                this.defaultUnit = '$_' + that.options.lengthUnitStrippedname;
                enabledUnitKeys = [ '$_m', '$_ft', '$_i' ];
                break;

            case 6: /* TYPE_VENEER */
                for (i = 0; i < stds.stdSizes.length; i++) {
                    stdsA[stds.stdSizes[i]] = stds.stdSizes[i];
                }
                this.defaultUnit = '$_' + that.options.lengthUnitStrippedname + '2';
                enabledUnitKeys = [ '$_m2', '$_m3', '$_ft2', '$_ft3', '$_ft2', '$_i' ];
                break;

        }

        this.enabledUnits = [];
        if (enabledUnitKeys) {
            $.each(this.units, function (index, unitGroup) {
                var g = {};
                $.each(unitGroup, function (key, value) {
                    if (enabledUnitKeys.includes(key)) {
                        g[key] = value;
                    }
                });
                if (Object.keys(g).length > 0) {
                    that.enabledUnits.push(g);
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

    LadbEditorStdPrices.prototype.setStdPrices = function (stdPrices) {
        if (!Array.isArray(stdPrices)) {
            stdPrices = [];
        }

        // Cleanup input
        this.stdPrices = [];
        var stdPrice;
        var has0 = false;
        for (var i = 0; i < stdPrices.length; i++) {
            stdPrice = stdPrices[i];
            if (stdPrice != null) {
                if (stdPrice.dim == null) {
                    if (!has0) {
                        this.stdPrices.unshift(stdPrice);
                        has0 = true;
                    }
                } else if (stdPrice.val != null && stdPrice.val.length > 0 && stdPrice.dim.length > 0) {
                    this.stdPrices.push(stdPrice);
                }
            }
        }
        if (!has0) {
            this.stdPrices.unshift({
                val: '',
                dim: null
            });
        }

        // Render rows if "stds" are ready
        if (Object.keys(this.stdsA).length > 0 && Object.keys(this.stdsB).length > 0) {
            this.renderRows();
        }

    };

    LadbEditorStdPrices.prototype.getStdPrices = function () {

        // Cleanup input
        var stdPrices = [];
        for (var i = 0; i < this.stdPrices.length; i++) {
            var stdPrice = this.stdPrices[i];
            if (stdPrice.dim == null || stdPrice.val != null && stdPrice.val.length > 0 && stdPrice.dim.length > 0) {
                stdPrices.push(stdPrice);
            }
        }

        return stdPrices;
    };

    LadbEditorStdPrices.prototype.init = function () {
        var that = this;

        // Bind button
        $('button', this.$element).on('click', function () {
            var stdPrice = {
                val: '',
                dim: ''
            }
            that.stdPrices.push(stdPrice);
            var $row = that.appendPriceRowN(stdPrice);
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
            var data = $this.data('ladb.editorStdPrices');
            var options = $.extend({}, LadbEditorStdPrices.DEFAULTS, $this.data(), typeof option === 'object' && option);

            if (!data) {
                $this.data('ladb.editorStdPrices', (data = new LadbEditorStdPrices(this, options)));
            }
            if (typeof option === 'string') {
                value = data[option].apply(data, Array.isArray(params) ? params : [ params ])
            } else {
                data.init();
            }
        });
        return typeof value !== 'undefined' ? value : elements;
    }

    var old = $.fn.ladbEditorStdPrices;

    $.fn.ladbEditorStdPrices = Plugin;
    $.fn.ladbEditorStdPrices.Constructor = LadbEditorStdPrices;


    // NO CONFLICT
    // =================

    $.fn.ladbEditorStdPrices.noConflict = function () {
        $.fn.ladbEditorStdPrices = old;
        return this;
    }

}(jQuery);
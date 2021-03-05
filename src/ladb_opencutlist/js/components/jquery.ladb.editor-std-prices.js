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
        this.unit = null;

        this.stdPrices = [];

    };

    LadbEditorStdPrices.DEFAULTS = {
        inputChangeCallback: null
    };

    LadbEditorStdPrices.prototype.prependPriceRow0 = function (stdPrice) {
        var that = this;

        var $row = $(Twig.twig({ref: 'components/_editor-std-prices-row-0.twig'}).render({
            unit: this.unit,
            stdPrice: stdPrice
        }));
        this.$rows.prepend($row);

        // Fetch UI elements
        var $input = $('input', $row);

        // Bind
        $input
            .on('change', function () {
                stdPrice.val = $(this).val();

                // Change callback
                if (that.options.inputChangeCallback) {
                    that.options.inputChangeCallback();
                }

            })
        ;

    };

    LadbEditorStdPrices.prototype.appendPriceRowN = function (stdPrice) {
        var that = this;

        var $row = $(Twig.twig({ref: 'components/_editor-std-prices-row-n.twig'}).render({
            stdsA: this.stdsA,
            stdsB: this.stdsB,
            unit: this.unit,
            stdPrice: stdPrice
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
        var previousValue = null;
        $select
            .selectpicker($.extend(SELECT_PICKER_OPTIONS, {
                noneSelectedText: 'Toutes les tailles'
            }))
            .on('change', function () {
                var newRange = $(this).selectpicker('val');
                $('select', that.$element).each(function () {
                    if (this === $select[0]) {
                        return;
                    }
                    var $tmpSelect = $(this);
                    $('option', $(this)).each(function () {
                        var $option = $(this);
                        if ($option.html() === stdPrice.dim) {
                            $option.prop('disabled', false);
                        } else if ($option.html() === newRange) {
                            $option.prop('disabled', true);
                        }
                        $tmpSelect.selectpicker('refresh');
                    });
                });
                stdPrice.dim = newRange;

                // Change callback
                if (that.options.inputChangeCallback) {
                    that.options.inputChangeCallback();
                }

            })
        ;
        $input
            .on('change', function () {
                stdPrice.val = $(this).val();

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
        switch (this.type) {

            case 1: /* TYPE_SOLID_WOOD */
                for (i = 0; i < stds.stdThicknesses.length; i++) {
                    stdsA[stds.stdThicknesses[i]] = stds.stdThicknesses[i];
                }
                this.unit = 'm<sup>3</sup>';
                break;

            case 2: /* TYPE_SHEET_GOOD */
                for (i = 0; i < stds.stdThicknesses.length; i++) {
                    stdsA[stds.stdThicknesses[i]] = stds.stdThicknesses[i];
                }
                for (i = 0; i < stds.stdSizes.length; i++) {
                    stdsB[stds.stdSizes[i]] = stds.stdSizes[i];
                }
                this.unit = 'm<sup>2</sup>';
                break;

            case 3: /* TYPE_DIMENSIONAL */
                for (i = 0; i < stds.stdSections.length; i++) {
                    stdsA[stds.stdSections[i]] = stds.stdSections[i];
                }
                for (i = 0; i < stds.stdLengths.length; i++) {
                    stdsB[stds.stdLengths[i]] = stds.stdLengths[i];
                }
                this.unit = 'm';
                break;

            case 4: /* TYPE_EDGE */
                for (i = 0; i < stds.stdWidths.length; i++) {
                    stdsA[stds.stdWidths[i]] = stds.stdWidths[i];
                }
                this.unit = 'm';
                break;

        }

        // Convert stds to inch fload representation
        rubyCallCommand('core_length_to_float', stdsA, function (responseA) {

            $.each(responseA, function (k, v) {
               if (Array.isArray(v)) {
                   responseA[k] = v[0] + '"x' + v[1] + '"';
               } else {
                   responseA[k] = v + '"'
               }
            });
            that.stdsA = responseA;

            rubyCallCommand('core_length_to_float', stdsB, function (responseB) {

                $.each(responseB, function (k, v) {
                    if (Array.isArray(v)) {
                        responseB[k] = v[0] + '"x' + v[1] + '"';
                    } else {
                        responseB[k] = v + '"'
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
            that.appendPriceRowN(stdPrice);
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
            var options = $.extend({}, LadbEditorStdPrices.DEFAULTS, $this.data(), typeof option == 'object' && option);

            if (!data) {
                $this.data('ladb.editorStdPrices', (data = new LadbEditorStdPrices(this, options)));
            }
            if (typeof option == 'string') {
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
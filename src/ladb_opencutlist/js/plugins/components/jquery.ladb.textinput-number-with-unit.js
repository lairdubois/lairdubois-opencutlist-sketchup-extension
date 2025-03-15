+function ($) {
    'use strict';

    // CLASS DEFINITION
    // ======================

    const LadbTextinputNumberWithUnit = function (element, options) {
        LadbTextinputAbstract.call(this, element, options, /^\d*[.,]?\d*$/);

        this.$spanUnit = null;

        this.unit = '';

    };
    LadbTextinputNumberWithUnit.prototype = new LadbTextinputAbstract;

    LadbTextinputNumberWithUnit.DEFAULTS = $.extend({
        units: null
    }, LadbTextinputAbstract.DEFAULTS);

    LadbTextinputNumberWithUnit.prototype.resetUnit = function () {

        this.unit = this.options.defaultUnit;
        if (this.$spanUnit) {
            this.$spanUnit.html(this.getUnitLabel(this.unit));
        }

    };

    LadbTextinputNumberWithUnit.prototype.reset = function () {
        this.resetUnit();
        LadbTextinputAbstract.prototype.reset.call(this);
    };

    LadbTextinputNumberWithUnit.prototype.val = function (value) {
        if (value === undefined) {
            let val = this.$element.val();
            if (val !== undefined) {
                val = val.trim();
            }
            return val ? val + ' ' + this.unit : '';
        }

        let unit = this.options.defaultUnit;
        const valueAndUnit = value.split(' ');
        if (valueAndUnit.length > 1) {
            unit = valueAndUnit[valueAndUnit.length - 1];
            if (unit === undefined || this.getUnitLabel(unit) === '') {
                unit = this.options.defaultUnit;
            }
            valueAndUnit.pop();
            value = valueAndUnit.join(' ');
        }

        this.unit = unit;
        if (this.$spanUnit) {
            this.$spanUnit.html(this.getUnitLabel(unit));
        }

        return LadbTextinputAbstract.prototype.val.call(this, value);
    };

    /////

    LadbTextinputNumberWithUnit.prototype.hasUnit = function () {
        return this.options.units !== null && Object.keys(this.options.units).length > 0;
    };

    LadbTextinputNumberWithUnit.prototype.getUnitLabel = function (unit) {
        let label = '';
        if (this.hasUnit()) {
            $.each(this.options.units, function (index, unitGroup) {
                if (unitGroup[unit]) {
                    label = unitGroup[unit];
                    return false;
                }
            });
        }
        return label;
    };

    LadbTextinputNumberWithUnit.prototype.createLeftToolsContainer = function () {
        if (this.hasUnit()) {
            LadbTextinputAbstract.prototype.createLeftToolsContainer.call(this);
        }
    };

    LadbTextinputNumberWithUnit.prototype.appendLeftTools = function ($toolsContainer) {
        const that = this;

        const $span = $('<span />')
        const $dropdown = $('<ul class="dropdown-menu" />');
        $.each(this.options.units, function (index, unitGroup) {
            if (index > 0) {
                $dropdown.append('<li class="divider" />');
            }
            $.each(unitGroup, function (key, value) {
                $dropdown.append(
                    $('<li />')
                        .append('<a href="#">' + value + '</a></li>')
                        .on('click', function () {
                            $span.html(value);
                            that.unit = key;
                            that.$element.trigger('change');
                        })
                );
            });
        });
        this.$spanUnit = $span;

        $toolsContainer.append($('<div class="ladb-textinput-tool btn-group" />')
            .append(
                $('<button type="button" class="btn btn-infield btn-xs dropdown-toggle" data-toggle="dropdown" />')
                    .append($span)
                    .append(this.options.units.length > 1 ? '&nbsp;<span class="caret" />' : '')
            )
            .append($dropdown)
        );

    };

    LadbTextinputNumberWithUnit.prototype.init = function () {
        LadbTextinputAbstract.prototype.init.call(this);

        const value = this.$element.val();
        if (!value) {
            this.resetUnit();
        }

    };


    // PLUGIN DEFINITION
    // =======================

    function Plugin(option, params) {
        let value;
        const elements = this.each(function () {
            const $this = $(this);
            let data = $this.data('ladb.textinputNumberWithUnit');
            if (!data) {
                const options = $.extend({}, LadbTextinputNumberWithUnit.DEFAULTS, $this.data(), typeof option === 'object' && option);
                $this.data('ladb.textinputNumberWithUnit', (data = new LadbTextinputNumberWithUnit(this, options)));
            }
            if (typeof option === 'string') {
                value = data[option].apply(data, Array.isArray(params) ? params : [ params ])
            } else {
                data.init();
            }
        });
        return typeof value !== 'undefined' ? value : elements;
    }

    const old = $.fn.ladbTextinputNumberWithUnit;

    $.fn.ladbTextinputNumberWithUnit = Plugin;
    $.fn.ladbTextinputNumberWithUnit.Constructor = LadbTextinputNumberWithUnit;


    // NO CONFLICT
    // =================

    $.fn.ladbTextinputNumberWithUnit.noConflict = function () {
        $.fn.ladbTextinputNumberWithUnit = old;
        return this;
    }

}(jQuery);
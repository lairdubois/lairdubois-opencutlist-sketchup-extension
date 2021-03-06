+function ($) {
    'use strict';

    // CLASS DEFINITION
    // ======================

    var LadbTextinputWithUnit = function (element, options) {
        LadbTextinputAbstract.call(this, element, options, '');

        this.$spanUnit = null;

        this.unit = '';

    };
    LadbTextinputWithUnit.prototype = new LadbTextinputAbstract;

    LadbTextinputWithUnit.DEFAULTS = {
        defaultUnit: '',
        units: {}
    };

    LadbTextinputWithUnit.prototype.reset = function () {

        this.unit = this.options.defaultUnit;
        this.$spanUnit.html(this.getUnitLabel(this.unit));

        LadbTextinputAbstract.prototype.reset.call(this);
    };

    LadbTextinputWithUnit.prototype.val = function (value) {
        if (value === undefined) {
            var val = this.$element.val();
            return val ? val + ' ' + this.unit : '';
        }

        var unit = this.options.defaultUnit;
        var valueAndUnit = value.split(' ');
        if (valueAndUnit.length > 1) {
            unit = valueAndUnit[valueAndUnit.length - 1];
            if (unit === undefined || this.getUnitLabel(unit) === '') {
                unit = this.options.defaultUnit;
            }
            valueAndUnit.pop();
            value = valueAndUnit.join(' ');
        }

        this.unit = unit;
        this.$spanUnit.html(this.getUnitLabel(unit));

        return LadbTextinputAbstract.prototype.val.call(this, value);
    };

    /////

    LadbTextinputWithUnit.prototype.getUnitLabel = function (unit) {
        var label = '';
        $.each(this.options.units, function (index, unitGroup) {
            if (unitGroup[unit]) {
                label = unitGroup[unit];
                return false;
            }
        });
        return label;
    };

    LadbTextinputWithUnit.prototype.appendLeftTools = function ($toolContainer) {
        var that = this;

        var $span = $('<span />')
        var $dropdown = $('<ul class="dropdown-menu" />');
        $.each(this.options.units, function (index, unitGroup) {
            if (index > 0) {
                $dropdown.append('<li class="divider" />');
            }
            $.each(unitGroup, function (key, value) {
                $dropdown.append(
                    $('<li />')
                        .append ('<a href="#">' + value + '</a></li>')
                        .on('click', function () {
                            $span.html(value);
                            that.unit = key;
                            that.$element.trigger('change');
                        })
                );
            });
        });
        this.$spanUnit = $span;

        var $btnGroup = $('<div class="ladb-textinput-tool btn-group" />')
            .append(
                $('<button type="button" class="btn btn-infield btn-xs dropdown-toggle" data-toggle="dropdown" />')
                    .append($span)
                    .append('&nbsp;')
                    .append('<span class="caret" />')
            )
            .append($dropdown)
        ;

        $toolContainer.append($btnGroup);

    };

    LadbTextinputWithUnit.prototype.init = function () {
        LadbTextinputAbstract.prototype.init.call(this);
    };


    // PLUGIN DEFINITION
    // =======================

    function Plugin(option, params) {
        var value;
        var elements = this.each(function () {
            var $this = $(this);
            var data = $this.data('ladb.textinputWithUnit');
            var options = $.extend({}, LadbTextinputWithUnit.DEFAULTS, $this.data(), typeof option == 'object' && option);

            if (!data) {
                $this.data('ladb.textinputWithUnit', (data = new LadbTextinputWithUnit(this, options)));
            }
            if (typeof option == 'string') {
                value = data[option].apply(data, Array.isArray(params) ? params : [ params ])
            } else {
                data.init();
            }
        });
        return typeof value !== 'undefined' ? value : elements;
    }

    var old = $.fn.ladbTextinputWithUnit;

    $.fn.ladbTextinputWithUnit = Plugin;
    $.fn.ladbTextinputWithUnit.Constructor = LadbTextinputWithUnit;


    // NO CONFLICT
    // =================

    $.fn.ladbTextinputWithUnit.noConflict = function () {
        $.fn.ladbTextinputWithUnit = old;
        return this;
    }

}(jQuery);
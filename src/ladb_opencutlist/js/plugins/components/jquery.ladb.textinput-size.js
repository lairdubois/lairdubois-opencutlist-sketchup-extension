+function ($) {
    'use strict';

    // CLASS DEFINITION
    // ======================

    const LadbTextinputSize = function(element, options) {
        LadbTextinputAbstract.call(this, element, options);
    };
    LadbTextinputSize.prototype = new LadbTextinputAbstract;

    LadbTextinputSize.DEFAULTS = $.extend({
        resetValue: 'xx',
        d1Placeholder: '',
        d2Placeholder: '',
        qPlaceholder: '',
        d1Disabled: false,
        d2Disabled: false,
        qDisabled: false,
        d1Hidden: false,
        d2Hidden: false,
        qHidden: false,
        separator1Label: 'x',
        separator2Label: 'x',
    }, LadbTextinputAbstract.DEFAULTS);

    LadbTextinputSize.prototype.updateElementInputValue = function () {

        let value1 = this.options.d1Disabled ? '' : this.$input1.val();
        let value2 = this.options.d2Disabled ? '' : this.$input2.val();
        let value3 = this.options.qDisabled ? '' : this.$input3.val();

        let values = [];
        if (value1) values.push(value1);
        if (value2) values.push(value2);
        if (value3) values.push(value3);

        LadbTextinputAbstract.prototype.val.call(this, values.join('x'));
        this.$element.trigger('change');
    };

    LadbTextinputSize.prototype.setInputValues = function (value) {

        const values = value.split('x');
        if (!this.options.d1Disabled) this.$input1.val(values.shift());
        if (!this.options.d2Disabled) this.$input2.val(values.shift());
        if (!this.options.qDisabled) this.$input3.val(values.shift());

    };

    LadbTextinputSize.prototype.focus = function () {
        this.$input1.focus();
    };

    LadbTextinputSize.prototype.reset = function () {
        LadbTextinputAbstract.prototype.reset.call(this);

        this.setInputValues(this.$element.val());

    };

    LadbTextinputSize.prototype.val = function (value) {

        if (value === undefined) {
            let val = LadbTextinputAbstract.prototype.val.call(this);
            return val;
        }

        this.setInputValues(value);

        const r = LadbTextinputAbstract.prototype.val.call(this, value);
        return r;
    };

    LadbTextinputSize.prototype.init = function() {
        LadbTextinputAbstract.prototype.init.call(this);

        const that = this;

        this.$element.attr('type', 'hidden');

        this.$input1 = $('<input type="text" class="form-control text-right" style="width: 50%;' + (this.options.d1Hidden ? ' opacity: 0;' : '') + '" placeholder="' + this.options.d1Placeholder + '"' + (this.options.d1Disabled ? ' disabled' : '') + '>')
            .on('change', function () {
                that.updateElementInputValue();
            })
        ;
        this.$inputWrapper.append(this.$input1);

        this.$inputWrapper.append('<div style="padding: 0 10px; color: #ccc;">' + this.options.separator1Label + '</div>');

        this.$input2 = $('<input type="text" class="form-control text-right" style="width: 50%;' + (this.options.d2Hidden ? ' opacity: 0;' : '') + '" placeholder="' + this.options.d2Placeholder + '"' + (this.options.d2Disabled ? ' disabled' : '') + '>')
            .on('change', function () {
                that.updateElementInputValue();
            })
        ;
        this.$inputWrapper.append(this.$input2);

        this.$inputWrapper.append('<div style="padding: 0 5px 0 20px; color: #ccc;">' + this.options.separator2Label + '</div>');

        this.$input3 = $('<input type="text" class="form-control text-right" style="width: 25%;' + (this.options.qHidden ? ' opacity: 0;' : '') + '" placeholder="' + this.options.qPlaceholder + '"' + (this.options.qDisabled ? ' disabled' : '') + '>')
            .on('change', function () {
                that.updateElementInputValue();
            })
        ;
        this.$inputWrapper.append(this.$input3);

    };


    // PLUGIN DEFINITION
    // =======================

    function Plugin(option, params) {
        let value;
        const elements = this.each(function () {
            const $this = $(this);
            let data = $this.data('ladb.textinputSize');
            if (!data) {
                const options = $.extend({}, LadbTextinputSize.DEFAULTS, $this.data(), typeof option === 'object' && option);
                $this.data('ladb.textinputSize', (data = new LadbTextinputSize(this, options)));
            }
            if (typeof option === 'string') {
                value = data[option].apply(data, Array.isArray(params) ? params : [ params ])
            } else {
                data.init();
            }
        });
        return typeof value !== 'undefined' ? value : elements;
    }

    const old = $.fn.ladbTextinputSize;

    $.fn.ladbTextinputSize             = Plugin;
    $.fn.ladbTextinputSize.Constructor = LadbTextinputSize;


    // NO CONFLICT
    // =================

    $.fn.ladbTextinputSize.noConflict = function () {
        $.fn.ladbTextinputSize = old;
        return this;
    }

}(jQuery);
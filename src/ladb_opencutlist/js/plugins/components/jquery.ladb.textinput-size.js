+function ($) {
    'use strict';

    // CLASS DEFINITION
    // ======================

    const LadbTextinputSize = function(element, options) {
        LadbTextinputAbstract.call(this, element, options);
    };
    LadbTextinputSize.prototype = new LadbTextinputAbstract;

    LadbTextinputSize.DEFAULTS = $.extend(LadbTextinputAbstract.DEFAULTS, {});

    LadbTextinputSize.prototype.updateInputValue = function () {

        let value1 = this.$input1.val();
        let value2 = this.$input2.val();
        let value3 = this.$input3.val();

        let values = [];
        if (value1) values.push(value1);
        if (value2) values.push(value2);
        if (value3) values.push(value3);

        LadbTextinputAbstract.prototype.val.call(this, values.join('x'));
        this.$element.trigger('change');
    };

    LadbTextinputSize.prototype.reset = function () {
        LadbTextinputAbstract.prototype.reset.call(this);

        const values = this.$element.val().split('x');
        this.$input1.val(values[0]);
        this.$input2.val(values[1]);
        this.$input3.val(values[2]);

    };

    LadbTextinputSize.prototype.val = function (value) {

        if (value === undefined) {
            let val = LadbTextinputAbstract.prototype.val.call(this);
            return val;
        }

        const values = value.split('x');
        this.$input1.val(values[0]);
        this.$input2.val(values[1]);
        this.$input3.val(values[2]);

        const r = LadbTextinputAbstract.prototype.val.call(this, value);
        return r;
    };

    LadbTextinputSize.prototype.init = function() {
        LadbTextinputAbstract.prototype.init.call(this);

        const that = this;

        this.$element.attr('type', 'hidden');

        this.$input1 = $('<input type="text" class="form-control text-right" style="width: 50%;" placeholder="Longueur">')
            .on('change', function () {
                that.updateInputValue();
            })
        ;
        this.$inputWrapper.append(this.$input1);

        this.$inputWrapper.append('<div style="padding: 0 10px; color: #ccc;">x</div>');

        this.$input2 = $('<input type="text" class="form-control text-right" style="width: 50%;" placeholder="Largeur">')
            .on('change', function () {
                that.updateInputValue();
            })
        ;
        this.$inputWrapper.append(this.$input2);

        this.$inputWrapper.append('<div style="padding: 0 5px 0 20px; color: #ccc;">Qte.</div>');

        this.$input3 = $('<input type="text" class="form-control text-right" style="width: 25%;" placeholder="1">')
            .on('change', function () {
                that.updateInputValue();
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
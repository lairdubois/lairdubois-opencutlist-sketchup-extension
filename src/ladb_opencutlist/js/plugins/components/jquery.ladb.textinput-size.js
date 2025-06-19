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
        dSeparatorLabel: '',
        qSeparatorLabel: '',
        feederCallback: null,
        dropdownActionLabel: '',
        dropdownActionCallback: null
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

    /////

    LadbTextinputSize.prototype.focus = function () {
        this.$input1.focus();
    };

    LadbTextinputSize.prototype.reset = function () {
        LadbTextinputAbstract.prototype.reset.call(this);

        this.setInputValues(this.$element.val());

    };

    LadbTextinputSize.prototype.val = function (value) {

        if (value === undefined) {
            return LadbTextinputAbstract.prototype.val.call(this);
        }

        this.setInputValues(value);

        return LadbTextinputAbstract.prototype.val.call(this, value);
    };

    LadbTextinputSize.prototype.appendRightTools = function ($toolsContainer) {
        if (this.options.feederCallback) {

            const $caret =
                $('<div class="ladb-textinput-tool ladb-textinput-tool-black ladb-textinput-tool-btn" tabindex="-1"><span class="bs-caret"><span class="caret"></span></span></div>')
            ;
            $toolsContainer.append($caret);

        } else {
            LadbTextinputAbstract.prototype.appendRightTools.call(this, $toolsContainer);
        }
    };

    LadbTextinputSize.prototype.init = function() {
        LadbTextinputAbstract.prototype.init.call(this);

        const that = this;

        this.$wrapper.addClass('ladb-textinput-size');

        this.$element.attr('type', 'hidden');

        this.$input3 = $('<input type="text" class="form-control ladb-textinput-size-q" style="' + (this.options.qHidden ? ' display: none;' : '') + '" placeholder="' + this.options.qPlaceholder + '"' + (this.options.qDisabled ? ' disabled' : '') + ' autocomplete="off">')
            .on('change', function () {
                that.updateElementInputValue();
            })
            .on('keydown', function (e) {
                if (e.key.match(/[xX;,]/)) {
                    e.preventDefault();
                    return false;
                }
                if (e.key.match(/[+-]/)) {
                    that.$element.trigger($.Event('plusminusdown', { key: e.key }));
                    e.preventDefault();
                    return false;
                }
            })
        ;
        this.$input2 = $('<input type="text" class="form-control ladb-textinput-size-d2" style="' + (this.options.d2Hidden ? ' display: none;' : '') + '" placeholder="' + this.options.d2Placeholder + '"' + (this.options.d2Disabled ? ' disabled' : '') + ' autocomplete="off">')
            .on('change', function () {
                that.updateElementInputValue();
            })
            .on('keydown', function (e) {
                if (e.key.match(/[xX;]/)) {
                    e.preventDefault();
                    if (!that.options.qDisabled && !that.options.qHidden) {
                        that.$input3
                            .focus()
                            .select()
                        ;
                        return false;
                    }
                }
                if (e.key.match(/[+-]/)) {
                    that.$element.trigger($.Event('plusminusdown', { key: e.key }));
                    e.preventDefault();
                    return false;
                }
            })
        ;
        this.$input1 = $('<input type="text" class="form-control ladb-textinput-size-d1" style="' + (this.options.d1Hidden ? ' display: none;' : '') + '" placeholder="' + this.options.d1Placeholder + '"' + (this.options.d1Disabled ? ' disabled' : '') + ' autocomplete="off">')
            .on('change', function () {
                that.updateElementInputValue();
            })
            .on('keydown', function (e) {
                if (e.key.match(/[xX;]/)) {
                    e.preventDefault();
                    if (!that.options.d2Disabled && !that.options.d2Hidden) {
                        that.$input2
                            .focus()
                            .select()
                        ;
                        return false;
                    } else if (!that.options.qDisabled && !that.options.qHidden) {
                        that.$input3
                            .focus()
                            .select()
                        ;
                        return false;
                    }
                }
                if (e.key.match(/[+-]/)) {
                    that.$element.trigger($.Event('plusminusdown', { key: e.key }));
                    e.preventDefault();
                    return false;
                }
            })
        ;

        this.$inputWrapper.append(this.$input1);
        this.$inputWrapper.append('<div class=" ladb-textinput-size-d-separator">' + this.options.dSeparatorLabel + '</div>');
        this.$inputWrapper.append(this.$input2);
        this.$inputWrapper.append('<div class="ladb-textinput-size-q-separator">' + this.options.qSeparatorLabel + '</div>');
        this.$inputWrapper.append(this.$input3);

        this.$inputWrapper.on('click', function (e) {
            if (e.target.tagName !== 'INPUT') {
                that.$input1.focus();
            }
        })

        // Set up the feeder (function that returns an array of sizes D1xD2xQ)

        if ((typeof this.options.feederCallback) === 'function') {

            this.$wrapper
                .wrap('<button data-toggle="dropdown" class="btn-dropdown-toggle" />')
            ;
            let $dropdownToggle = this.$wrapper.parent();

            $dropdownToggle
                .wrap('<div class="dropdown ladb-textinput-select" />')
            ;
            let $dropdown = $dropdownToggle.parent();

            let $dropdownMenu = $('<ul class="dropdown-menu" />');
            $dropdown.append($dropdownMenu);

            $dropdown.on('show.bs.dropdown', function (e) {
                $dropdownMenu.empty();
                let sizes = that.options.feederCallback();
                for  (let i = 0; i < sizes.length; i++) {
                    $dropdownMenu.append(
                        $('<li />')
                            .append('<a href="#">' + sizes[i] + '</a>')
                            .on('click', function () {
                                that
                                    .val(sizes[i])
                                    .trigger('change')
                                ;
                            })
                    );
                }
                if ((typeof that.options.dropdownActionCallback) === 'function') {
                    if (sizes.length > 0) {
                        $dropdownMenu.append('<li role="separator" class="divider"></li>');
                    }
                    $dropdownMenu.append(
                        $('<li />')
                            .append('<a href="#">' + that.options.dropdownActionLabel + '</a>')
                            .on('click', function () {
                                that.options.dropdownActionCallback();
                            })
                    );
                }
            });

        }

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
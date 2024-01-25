+function ($) {
    'use strict';

    // CLASS DEFINITION
    // ======================

    var LadbTextinputColor = function(element, options) {
        LadbTextinputAbstract.call(this, element, options, /^#[0-9a-f]*$/i);

        this.$inputColor = null;
        this.$preview = null;
        this.$storeBtn = null;
        this.$removeBtn = null;
        this.$picker = null;

    };
    LadbTextinputColor.prototype = new LadbTextinputAbstract;

    LadbTextinputColor.DEFAULTS = {
        resetValue: '#000000',
        colors: ['#000000', '#ffffff'],
        colorsPerLine: 6
    };

    LadbTextinputColor.prototype.disable = function () {
        LadbTextinputAbstract.prototype.disable.call(this);
        if (this.$inputColor) this.$inputColor.prop('disabled', true);
        if (this.$preview) this.$preview.css('opacity', '0.2')
        if (this.$storeBtn) this.$storeBtn.hide();
        if (this.$removeBtn) this.$removeBtn.hide();
        this.hidePicker();
    };

    LadbTextinputColor.prototype.enable = function () {
        LadbTextinputAbstract.prototype.enable.call(this);
        if (this.$inputColor) this.$inputColor.prop('disabled', false);
        if (this.$preview) this.$preview.css('opacity', '1')
        this.updatePreviewAndButtons();
    };

    LadbTextinputColor.prototype.val = function (value) {

        if (value === undefined) {
            var val = LadbTextinputAbstract.prototype.val.call(this);
            if (val.match(/^#[0-9a-f]{6}$/i)) {
                return val;
            }
            return this.options.resetValue;
        }

        var r = LadbTextinputAbstract.prototype.val.call(this, value);
        this.updatePreviewAndButtons();
        return r;
    };

    LadbTextinputColor.prototype.sanitizeColor = function(color) {
        if (color && typeof(color) === 'string') {
            return color.toLowerCase();
        }
        return color;
    };

    LadbTextinputColor.prototype.blendColors = function (color1, color2, percentage) {

        // Code from : https://coderwall.com/p/z8uxzw/javascript-color-blender

        /*
            convert a Number to a two character hex string
            must round, or we will end up with more digits than expected (2)
            note: can also result in single digit, which will need to be padded with a 0 to the left
            @param: num         => the number to conver to hex
            @returns: string    => the hex representation of the provided number
        */
        var fnIntToHex = function (num) {
            var hex = Math.round(num).toString(16);
            if (hex.length === 1)
                hex = '0' + hex;
            return hex;
        }


        // check input
        color1 = color1 || '#000000';
        color2 = color2 || '#ffffff';
        percentage = Math.max(0, Math.min(percentage, 1.0)) || 0.5;

        // 1: validate input, make sure we have provided a valid hex
        if (color1.length !== 4 && color1.length !== 7) {
            throw new Error('colors must be provided as hexes');
        }

        if (color2.length !== 4 && color2.length !== 7) {
            throw new Error('colors must be provided as hexes');
        }

        // 2: check to see if we need to convert 3 char hex to 6 char hex, else slice off hash
        //      the three character hex is just a representation of the 6 hex where each character is repeated
        //      ie: #060 => #006600 (green)
        if (color1.length === 4)
            color1 = color1[1] + color1[1] + color1[2] + color1[2] + color1[3] + color1[3];
        else
            color1 = color1.substring(1);
        if (color2.length === 4)
            color2 = color2[1] + color2[1] + color2[2] + color2[2] + color2[3] + color2[3];
        else
            color2 = color2.substring(1);

        // 3: we have valid input, convert colors to rgb
        color1 = [parseInt(color1[0] + color1[1], 16), parseInt(color1[2] + color1[3], 16), parseInt(color1[4] + color1[5], 16)];
        color2 = [parseInt(color2[0] + color2[1], 16), parseInt(color2[2] + color2[3], 16), parseInt(color2[4] + color2[5], 16)];

        // 4: blend
        var color3 = [
            (1 - percentage) * color1[0] + percentage * color2[0],
            (1 - percentage) * color1[1] + percentage * color2[1],
            (1 - percentage) * color1[2] + percentage * color2[2]
        ];

        // 5: convert to hex
        color3 = '#' + fnIntToHex(color3[0]) + fnIntToHex(color3[1]) + fnIntToHex(color3[2]);

        // return hex
        return color3;
    }

    LadbTextinputColor.prototype.updatePreviewAndButtons = function() {
        var color = this.sanitizeColor(this.$element.val());
        if (color) {

            // Preview
            if (color.match(/^#[0-9a-f]{6}$/i)) {
                if (this.$inputColor) {
                    this.$inputColor.val(color);
                }
                if (this.$preview) {
                    try {
                        this.$preview.css('border-color', this.blendColors(color, '#000000', 0.2));
                        this.$preview.css('border-style', 'solid');
                    } catch (e) {}
                }
            } else {
                if (this.$inputColor) {
                    this.$inputColor.val('#ffffff');
                }
                if (this.$preview) {
                    this.$preview.css('border-color', '#ffffff');
                    this.$preview.css('border-style', 'solid');
                }
            }

            // Buttons
            var index = this.options.colors.indexOf(color);
            if (this.$storeBtn) {
                if (index === -1) {
                    this.$storeBtn.show();
                } else {
                    this.$storeBtn.hide();
                }
            }
            if (this.$removeBtn) {
                if (index !== -1) {
                    this.$removeBtn.show();
                } else {
                    this.$removeBtn.hide();
                }
            }

        } else {
            if (this.$inputColor) {
                this.$inputColor.val('#ffffff');
            }
            if (this.$preview) {
                this.$preview.css('border-color', '#cccccc');
                this.$preview.css('border-style', 'dotted');
            }
            if (this.$storeBtn) {
                this.$storeBtn.hide();
            }
            if (this.$removeBtn) {
                this.$removeBtn.hide();
            }
        }
    };

    LadbTextinputColor.prototype.generatePicker = function() {
        var that = this;

        this.removePicker();

        this.$picker = $(Twig.twig({ref: 'components/_textinput-color-picker.twig'}).render(that.options));
        this.$wrapper.prepend(this.$picker);
        this.$picker.hide();    // By default picker is hidden. Focus $element to show it

        $('li.ladb-color-box', this.$picker)
            .on('mousedown', function (e) {
                e.preventDefault(); // Prevent gain focus
            })
            .on('click', function () {
                that.$element
                    .val(that.options.colors[$(this).data('ladb-color-index')])
                    .trigger('change')
                    .blur()
                ;
                that.updatePreviewAndButtons();
                that.hidePicker();
            })
        ;

        this.$picker.click(function (e) {
            e.stopPropagation();
        });

    };

    LadbTextinputColor.prototype.showPicker = function() {
        if (this.$picker) {
            var pos = this.$wrapper.position();
            this.$picker.css({
                top: this.$wrapper.outerHeight(false)
            });
            this.$picker.show();
        }
    };

    LadbTextinputColor.prototype.hidePicker = function() {
        if (this.$picker) {
            this.$picker.hide();
        }
    };

    LadbTextinputColor.prototype.removePicker = function() {
        if (this.$picker) {
            this.$picker.remove();
            this.$picker = null;
        }
    };

    LadbTextinputColor.prototype.appendLeftTools = function($toolsContainer) {
        LadbTextinputAbstract.prototype.appendLeftTools.call(this, $toolsContainer);

        this.$preview = $('<div class="ladb-textinput-color-preview ladb-textinput-tool" />');
        $toolsContainer.append(this.$preview);

        this.$inputColor = $('<input type="color" class="input-color" value="' + (this.options.resetValue ? this.options.resetValue : '#ffffff') + '" tabindex="-1">');
        this.$preview.append(this.$inputColor);

    };

    LadbTextinputColor.prototype.appendRightTools = function($toolsContainer) {
        LadbTextinputAbstract.prototype.appendRightTools.call(this, $toolsContainer);

        var that = this;

        this.$storeBtn = $('<div class="ladb-textinput-tool ladb-textinput-tool-btn" tabindex="-1" data-toggle="tooltip" title="' + i18next.t('core.component.textinput_color.store') + '"><i class="ladb-opencutlist-icon-plus"></i></div>')
            .on('mousedown', function (e) {
                e.preventDefault(); // Prevent gain focus
            })
            .on('click', function() {

                var color = that.sanitizeColor(that.$element.val());
                var index = that.options.colors.indexOf(color);
                if (index === -1) {

                    that.options.colors.push(color);
                    that.generatePicker();
                    that.updatePreviewAndButtons();
                    that.$element.focus();

                    rubyCallCommand('core_set_global_preset', {
                        dictionary: 'component_textinput_color',
                        values: {
                            colors: that.options.colors
                        }
                    });

                }

                $(this).blur();
            })
        ;
        this.$storeBtn.hide();
        $toolsContainer.prepend(this.$storeBtn);

        this.$removeBtn = $('<div class="ladb-textinput-tool ladb-textinput-tool-btn" tabindex="-1" data-toggle="tooltip" title="' + i18next.t('core.component.textinput_color.remove') + '"><i class="ladb-opencutlist-icon-minus"></i></div>')
            .on('mousedown', function (e) {
                e.preventDefault(); // Prevent gain focus
            })
            .on('click', function() {

                var color = that.sanitizeColor(that.$element.val());
                var index = that.options.colors.indexOf(color);
                if (index !== -1) {

                    that.options.colors.splice(index, 1);
                    that.generatePicker();
                    that.updatePreviewAndButtons();
                    that.$element.focus();

                    rubyCallCommand('core_set_global_preset', {
                        dictionary: 'component_textinput_color',
                        values: {
                            colors: that.options.colors
                        }
                    });

                }

                $(this).blur();
            })
        ;
        this.$removeBtn.hide();
        $toolsContainer.prepend(this.$removeBtn);

    };

    LadbTextinputColor.prototype.init = function() {
        LadbTextinputAbstract.prototype.init.call(this);

        var that = this;

        // Retrieve options
        rubyCallCommand('core_get_global_preset', { dictionary: 'component_textinput_color' }, function (response) {

            that.options = $.extend(that.options, response.preset);

            that.generatePicker();
            that.updatePreviewAndButtons();

            // Bind UI
            that.$inputColor.on('change', function () {
                that.$element.val($(this).val());
                that.$element.trigger('change');
            });
            that.$element
                .on('focus', function () {
                    that.showPicker();
                })
                .on('blur', function (e) {
                    that.hidePicker();
                })
                .on('change', function () {
                    that.updatePreviewAndButtons();
                })
                .on('keyup', function () {
                    that.updatePreviewAndButtons();
                })
            ;

        });

    };


    // PLUGIN DEFINITION
    // =======================

    function Plugin(option, params) {
        var value;
        var elements = this.each(function () {
            var $this = $(this);
            var data = $this.data('ladb.textinputColor');
            var options = $.extend({}, LadbTextinputColor.DEFAULTS, $this.data(), typeof option === 'object' && option);

            if (!data) {
                $this.data('ladb.textinputColor', (data = new LadbTextinputColor(this, options)));
            }
            if (typeof option === 'string') {
                value = data[option].apply(data, Array.isArray(params) ? params : [ params ])
            } else {
                data.init();
            }
        });
        return typeof value !== 'undefined' ? value : elements;
    }

    var old = $.fn.LadbTextinputColor;

    $.fn.ladbTextinputColor             = Plugin;
    $.fn.ladbTextinputColor.Constructor = LadbTextinputColor;


    // NO CONFLICT
    // =================

    $.fn.ladbTextinputColor.noConflict = function () {
        $.fn.ladbTextinputColor = old;
        return this;
    }

}(jQuery);
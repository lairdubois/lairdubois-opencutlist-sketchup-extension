+function ($) {
    'use strict';

    // CLASS DEFINITION
    // ======================

    var LadbTextinputColor = function(element, options) {
        LadbTextinputAbstract.call(this, element, options, /^#[0-9a-f]*$/i);
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

    LadbTextinputColor.prototype.sanitizeColor = function(color) {
        if (color && typeof(color) === 'string') {
            return color.toLowerCase();
        }
        return color;
    };

    LadbTextinputColor.prototype.updatePreviewAndButtons = function() {
        var color = this.sanitizeColor(this.$element.val());
        if (color) {

            // Preview
            if (this.$preview) {
                this.$preview.css('background', color);
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

        }
    };

    LadbTextinputColor.prototype.generatePicker = function() {
        var that = this;

        this.removePicker();

        this.$picker = $(Twig.twig({ref: 'components/_textinput-color-picker.twig'}).render(that.options));
        this.$element.parent().append(this.$picker);
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
                left: pos.left,
                top: pos.top + this.$wrapper.outerHeight(false)
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
            that.$preview.on('click', function(e) {
                e.stopPropagation();
                that.$element.focus();
            });
            that.$element
                .on('click', function (e) {
                    e.stopPropagation();
                })
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
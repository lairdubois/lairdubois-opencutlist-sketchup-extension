+function ($) {
    'use strict';

    // CLASS DEFINITION
    // ======================

    var LadbTextinputColor = function(element, options) {
        LadbTextinputAbstract.call(this, element, options, /^#[0-9a-f]*$/i);
        this.$preview = null;
    };
    LadbTextinputColor.prototype = new LadbTextinputAbstract;

    LadbTextinputColor.DEFAULTS = {
        resetValue: '#000000',
        colors: ['#000000', '#FFFFFF'],
        colorsPerLine: 6
    };

    LadbTextinputColor.prototype.updatePreview = function() {
        var color = this.$element.val();
        if (color) {
            this.$preview.css('background', color);
        }
    };

    LadbTextinputColor.prototype.refreshPicker = function(autoShow) {
        var that = this;

        var $body = $('body');
        var $inputGroup = this.$element.parent();

        var $picker = $(Twig.twig({ref: 'components/_textinput-color-picker.twig'}).render(that.options));
        $inputGroup.append($picker);
        $picker.hide();

        $('li.ladb-color-box', $picker).on('click', function() {
            if (that.$element.is('input')) {
                that.$element
                    .val(that.options.colors[$(this).data('ladb-color-index')])
                    .trigger('change')
                    .blur()
                ;
            }
            that.updatePreview();
            $picker.hide();
        });

        $body.on('click', function() {
            $picker.hide();
        });

        $picker.click(function (e) {
            e.stopPropagation();
        });

        var fnPositionAndShowPicker = function($picker) {
            var pos = that.$wrapper.position();
            $picker.css({ left: pos.left, top: (pos.top + that.$wrapper.outerHeight(false)) });
            $picker.show();
        };

        that.$preview.on('click', function(e) {
            e.stopPropagation();
            fnPositionAndShowPicker($picker);
        });

        that.$element
            .on('click', function (e) {
                e.stopPropagation();
            })
            .on('focus', function () {
                fnPositionAndShowPicker($picker);
            })
            .on('change', function () {
                that.updatePreview();
            })
            .on('keyup', function () {
                that.updatePreview();
            })
        ;

        if (autoShow) {
            fnPositionAndShowPicker($picker);
        }
    };

    LadbTextinputColor.prototype.appendLeftTools = function($toolsContainer) {
        LadbTextinputAbstract.prototype.appendLeftTools.call(this, $toolsContainer);

        var $preview = $('<div class="ladb-textinput-color-preview ladb-textinput-tool" />');
        $toolsContainer.append($preview);

        this.$preview = $('.ladb-textinput-color-preview', $toolsContainer);

    };

    LadbTextinputColor.prototype.init = function() {
        LadbTextinputAbstract.prototype.init.call(this);

        var that = this;

        // Retrieve options
        rubyCallCommand('core_get_global_preset', { dictionary: 'component_textinput_color' }, function (response) {

            that.options = $.extend(that.options, response.preset);

            that.refreshPicker();
            that.updatePreview();

        });

    };


    // PLUGIN DEFINITION
    // =======================

    function Plugin(option, params) {
        return this.each(function () {
            var $this   = $(this);
            var data    = $this.data('ladb.textinputColor');
            var options = $.extend({}, LadbTextinputColor.DEFAULTS, $this.data(), typeof option === 'object' && option);

            if (!data) {
                $this.data('ladb.textinputColor', (data = new LadbTextinputColor(this, options)));
            }
            if (typeof option === 'string') {
                data[option].apply(data, Array.isArray(params) ? params : [ params ]);
            } else {
                data.init();
            }
        })
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
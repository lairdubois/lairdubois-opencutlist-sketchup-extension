+function ($) {
    'use strict';

    // CLASS DEFINITION
    // ======================

    var LadbTextinputColor = function(element, options) {
        LadbAbstractSimpleTextinput.call(this, element, options, '#000000');
        this.$previewAddOn = null;
        this.$preview = null;
    };
    LadbTextinputColor.prototype = new LadbAbstractSimpleTextinput;

    LadbTextinputColor.DEFAULTS = {
        colors: ['#61BD4F', '#F2D600', '#FFAB4A', '#EB5A46', '#C377E0', '#0079BF', '#00C2E0', '#51E898', '#FF80CE', '#4D4D4D'],
        colorsPerLine: 5,
        includeMargins: false
    };

    LadbTextinputColor.prototype.updatePreview = function() {
        var color = this.$element.val();
        if (color) {
            this.$preview.css('background', color);
        }
    };

    LadbTextinputColor.prototype.init = function() {
        LadbAbstractSimpleTextinput.prototype.init.call(this);

        var that = this;

        var $body = $('body');

        // Decorate input

        this.$previewAddOn = $('<div class="ladb-textinput-color-preview-addon input-group-addon"></div>');
        this.$preview = $('<div class="ladb-textinput-color-preview"></div>');

        this.$previewAddOn.append(this.$preview);

        var $inputGroup = this.$element.parent();
        $inputGroup.addClass('ladb-textinput-color')
        $inputGroup.prepend(this.$previewAddOn);

        // Create the color box

        var colorsMarkup = '';

        for (var i = 0; i < this.options.colors.length; i++) {

            var color = this.options.colors[i];

            var breakLine = '';
            if ((i % this.options.colorsPerLine) === 0) {
                breakLine = 'clear: both; ';
            }

            colorsMarkup += '<li data-ladb-color-index="' + i + '" class="ladb-color-box" style="' + breakLine + 'background-color: ' + color + '" title="' + color + '"></li>';
        }

        var $box = $('<div class="ladb-textinput-color-picker"><ul>' + colorsMarkup + '</ul><div style="clear: both;"></div></div>');
        $inputGroup.append($box);
        $box.hide();

        $('li.ladb-color-box', $box).click(function() {
            if (that.$element.is('input')) {
                that.$element
                    .val(that.options.colors[$(this).data('ladb-color-index')])
                    .trigger('change')
                    .blur()
                ;
            }
            that.updatePreview();
            $box.hide();
        });

        $body.on('click', function() {
            $box.hide();
        });

        $box.click(function (e) {
            e.stopPropagation();
        });

        var fnPositionAndShowBox = function($box) {
            var pos = that.$previewAddOn.position();
            $box.css({ left: pos.left, top: (pos.top + that.$element.outerHeight(that.options.includeMargins)) });
            $box.show();
        };

        this.$previewAddOn.on('click', function(e) {
            e.stopPropagation();
            fnPositionAndShowBox($box);
        });

        this.$element
            .on('click', function (e) {
                e.stopPropagation();
            })
            .on('focus', function () {
                fnPositionAndShowBox($box);
            })
            .on('change', function () {
                that.updatePreview();
            })
            .on('keyup', function () {
                that.updatePreview();
            })
        ;

        this.updatePreview();
    };


    // PLUGIN DEFINITION
    // =======================

    function Plugin(option, _parameter) {
        return this.each(function () {
            var $this   = $(this);
            var data    = $this.data('ladb.textinputColor');
            var options = $.extend({}, LadbTextinputColor.DEFAULTS, $this.data(), typeof option == 'object' && option);

            if (!data) {
                $this.data('ladb.textinputColor', (data = new LadbTextinputColor(this, options)));
            }
            if (typeof option == 'string') {
                data[option](_parameter);
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
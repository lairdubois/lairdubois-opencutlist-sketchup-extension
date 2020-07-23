+function ($) {
    'use strict';

    // CLASS DEFINITION
    // ======================

    var LadbTextinputDimension = function (element, options) {
        this.options = options;
        this.$element = $(element);
    };

    LadbTextinputDimension.DEFAULTS = {};

    LadbTextinputDimension.prototype.init = function () {
        var that = this;

        var $resetButton = $('<div><i class="ladb-opencutlist-icon-clear"></i></div>');
        $resetButton.on('click', function() {
            that.$element
                .val('0')
                .trigger('change')
            ;
        });
        this.$element.wrap('<div class="ladb-textinput-dimension" />').after($resetButton);

    };


    // PLUGIN DEFINITION
    // =======================

    function Plugin(option, params) {
        return this.each(function () {
            var $this = $(this);
            var data = $this.data('ladb.textinputDimension');
            var options = $.extend({}, LadbTextinputDimension.DEFAULTS, $this.data(), typeof option == 'object' && option);

            if (!data) {
                $this.data('ladb.textinputDimension', (data = new LadbTextinputDimension(this, options)));
            }
            if (typeof option == 'string') {
                data[option].apply(data, Array.isArray(params) ? params : [ params ])
            } else {
                data.init();
            }
        })
    }

    var old = $.fn.ladbTextinputDimension;

    $.fn.ladbTextinputDimension = Plugin;
    $.fn.ladbTextinputDimension.Constructor = LadbTextinputDimension;


    // NO CONFLICT
    // =================

    $.fn.ladbTextinputDimension.noConflict = function () {
        $.fn.ladbTextinputDimension = old;
        return this;
    }

}(jQuery);
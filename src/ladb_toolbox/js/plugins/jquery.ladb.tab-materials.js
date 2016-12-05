+function ($) {
    'use strict';

    // CLASS DEFINITION
    // ======================

    var LadbTabMaterials = function (element, options) {
        this.options = options;
        this.$element = $(element);

        this.$btnList = $('#ladb_btn_list', this.$element);
        this.$list = $('#materials_list', this.$element);
    };

    LadbTabMaterials.DEFAULTS = {};

    LadbTabMaterials.prototype.rubyCall = function (fn, params) {
        console.log('rubyCall ' + fn);
        window.location.href = "skp:" + fn + "@" + JSON.stringify(params);
    };

    LadbTabMaterials.prototype.onList = function (jsonData) {

        var materials = JSON.parse(jsonData);

        this.$list.append(Twig.twig({ ref: "tabs/materials/_list.twig" }).render({
            materials: materials
        }));

    };

    LadbTabMaterials.prototype.bind = function () {
        var that = this;

        // Bind buttons
        this.$btnList.on('click', function () {
            that.rubyCall('ladb_materials_list', null);
        });

    };

    LadbTabMaterials.prototype.init = function () {
        this.bind();
    };


    // PLUGIN DEFINITION
    // =======================

    function Plugin(option, params) {
        return this.each(function () {
            var $this = $(this);
            var data = $this.data('twig2js.tabMaterials');
            var options = $.extend({}, LadbTabMaterials.DEFAULTS, $this.data(), typeof option == 'object' && option);

            if (!data) {
                $this.data('twig2js.tabMaterials', (data = new LadbTabMaterials(this, options)));
            }
            if (typeof option == 'string') {
                data[option](params);
            } else {
                data.init();
            }
        })
    }

    var old = $.fn.ladbTabMaterials;

    $.fn.ladbTabMaterials = Plugin;
    $.fn.ladbTabMaterials.Constructor = LadbTabMaterials;


    // NO CONFLICT
    // =================

    $.fn.ladbTabMaterials.noConflict = function () {
        $.fn.ladbTabMaterials = old;
        return this;
    }

}(jQuery);
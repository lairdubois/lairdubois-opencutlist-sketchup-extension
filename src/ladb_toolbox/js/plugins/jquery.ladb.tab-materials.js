+function ($) {
    'use strict';

    // CLASS DEFINITION
    // ======================

    var LadbTabMaterials = function (element, options, toolbox) {
        this.options = options;
        this.$element = $(element);
        this.toolbox = toolbox;

        this.$btnList = $('#ladb_btn_list', this.$element);
        this.$list = $('#materials_list', this.$element);
    };

    LadbTabMaterials.DEFAULTS = {};

    LadbTabMaterials.prototype.onList = function (materials) {

        // Update list
        this.$list.empty();
        this.$list.append(Twig.twig({ ref: "tabs/materials/_list.twig" }).render({
            materials: materials
        }));

    };

    LadbTabMaterials.prototype.bind = function () {
        var that = this;

        // Bind buttons
        this.$btnList.on('click', function () {
            rubyCall('ladb_materials_list', null);
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
            var data = $this.data('ladb.tabMaterials');
            var options = $.extend({}, LadbTabMaterials.DEFAULTS, $this.data(), typeof option == 'object' && option);

            if (!data) {
                if (options.toolbox == undefined) {
                    throw 'toolbox option is mandatory.';
                }
                $this.data('ladb.tabMaterials', (data = new LadbTabMaterials(this, options, options.toolbox)));
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
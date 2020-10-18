+function ($) {
    'use strict';

    // CLASS DEFINITION
    // ======================

    var LadbTabTutorials = function (element, options, opencutlist) {
        LadbAbstractTab.call(this, element, options, opencutlist);

        this.$page = $('.ladb-page', this.$element);
    };
    LadbTabTutorials.prototype = new LadbAbstractTab;

    LadbTabTutorials.DEFAULTS = {};

    LadbTabTutorials.prototype.loadTutorials = function () {
        var that = this;

        $.getJSON('https://github.com/lairdubois/lairdubois-opencutlist-sketchup-extension/raw/master/docs/tutorials.json', function (data) {

            that.$page.empty();
            that.$page.append(Twig.twig({ ref: "tabs/tutorials/_list.twig" }).render({
                tutorials: data.tutorials
            }));

            // Bind
            $('.ladb-tutorial-box', that.$page).on('click', function () {
                var tutorialId = $(this).data('tutorial-id');
                var tutorial = data.tutorials[tutorialId];

                var $modal = that.appendModalInside('ladb_tutorial_play', 'tabs/tutorials/_modal-play.twig', {
                    tutorial: tutorial
                });

                // Show modal
                $modal.modal('show');

            });

        });

    }

    LadbTabTutorials.prototype.defaultInitializedCallback = function () {
        LadbAbstractTab.prototype.defaultInitializedCallback.call(this);

        this.loadTutorials();

    };

    // PLUGIN DEFINITION
    // =======================

    function Plugin(option, params) {
        return this.each(function () {
            var $this = $(this);
            var data = $this.data('ladb.tab.plugin');
            var options = $.extend({}, LadbTabTutorials.DEFAULTS, $this.data(), typeof option == 'object' && option);

            if (!data) {
                if (undefined === options.dialog) {
                    throw 'dialog option is mandatory.';
                }
                $this.data('ladb.tab.plugin', (data = new LadbTabTutorials(this, options, options.dialog)));
            }
            if (typeof option == 'string') {
                data[option].apply(data, Array.isArray(params) ? params : [ params ])
            } else {
                data.init(option.initializedCallback);
            }
        })
    }

    var old = $.fn.ladbTabTutorials;

    $.fn.ladbTabTutorials = Plugin;
    $.fn.ladbTabTutorials.Constructor = LadbTabTutorials;


    // NO CONFLICT
    // =================

    $.fn.ladbTabTutorials.noConflict = function () {
        $.fn.ladbTabTutorials = old;
        return this;
    }

}(jQuery);
+function ($) {
    'use strict';

    // CONSTANTS
    // ======================

    const TUTORIALS_URL = 'https://www.lairdubois.fr/opencutlist/tutorials'
    const TUTORIALS_DEV_URL = 'https://www.lairdubois.fr/opencutlist/tutorials-dev'

    // CLASS DEFINITION
    // ======================

    const LadbTabTutorials = function (element, options, dialog) {
        LadbAbstractTab.call(this, element, options, dialog);

        this.$btnSubmit = $('#ladb_btn_submit', this.$element);

        this.$page = $('.ladb-page', this.$element);

        this.tutorials = null;

    };
    LadbTabTutorials.prototype = Object.create(LadbAbstractTab.prototype);

    LadbTabTutorials.DEFAULTS = {};

    LadbTabTutorials.prototype.loadTutorials = function () {
        const that = this;

        $.getJSON(this.dialog.appendOclMetasToUrlQueryParams(this.dialog.capabilities.is_dev ? TUTORIALS_DEV_URL : TUTORIALS_URL), function (data) {

            that.tutorials = data.tutorials;

            // Sort tutorials according to native index and corresponding language
            for (let index = 0; index < that.tutorials.length; index++) {
                const tutorial = that.tutorials[index];
                tutorial.native_index = index;
                tutorial.prefered = tutorial.language === that.dialog.capabilities.language ? 1 : 0;
            }
            const sortBy = [{
                prop: 'prefered',
                dir: -1
            }, {
                prop: 'native_index',
                dir: 1
            }];
            that.tutorials.sort(function (a, b) {
                let i = 0, result = 0;
                while (i < sortBy.length && result === 0) {
                    result = sortBy[i].dir * (a[sortBy[i].prop] < b[sortBy[i].prop] ? -1 : (a[sortBy[i].prop] > b[sortBy[i].prop] ? 1 : 0));
                    i++;
                }
                return result;
            });

            that.$page.empty();
            that.$page.append(Twig.twig({ ref: "tabs/tutorials/_list.twig" }).render({
                tutorials: that.tutorials,
            }));

            // Bind
            $('.ladb-tutorial-box', that.$page).each(function (index) {
                const $box = $(this);
                $box.on('click', function (e) {
                    if (e.target.tagName !== 'A') {
                        $(this).blur();
                        $('.ladb-click-tool', $(this)).click();
                        return false;
                    }
                });
            });
            $('.ladb-btn-play', that.$page).on('click', function () {
                $(this).blur();
                const tutorialId = $(this).closest('.ladb-tutorial-box').data('tutorial-id');
                that.playTutorials(tutorialId);
                return false;
            });

        }).fail(function() {
            that.$page.empty();
            that.$page.append(Twig.twig({ ref: "core/_alert-errors.twig" }).render({
                errors: [ 'tab.tutorials.error.fail_to_load_list' ]
            }));
        });

    }

    LadbTabTutorials.prototype.playTutorials = function (id) {
        const tutorial = this.tutorials[id];

        const $modal = this.appendModalInside('ladb_tutorial_play', 'tabs/tutorials/_modal-play.twig', {
            tutorial: tutorial
        });

        // Show modal
        $modal.modal('show');

    };

    LadbTabTutorials.prototype.bind = function () {
        LadbAbstractTab.prototype.bind.call(this);

        const that = this;

        // Bind buttons
        this.$btnSubmit.on('click', function () {

            const $modal = that.appendModalInside('ladb_tutorials_modal_submit', 'tabs/tutorials/_modal-submit.twig');

            // Show modal
            $modal.modal('show');

        });

    };

    LadbTabTutorials.prototype.defaultInitializedCallback = function () {
        LadbAbstractTab.prototype.defaultInitializedCallback.call(this);

        this.loadTutorials();

    };

    // PLUGIN DEFINITION
    // =======================

    function Plugin(option, params) {
        return this.each(function () {
            const $this = $(this);
            let data = $this.data('ladb.tab.plugin');
            const options = $.extend({}, LadbTabTutorials.DEFAULTS, $this.data(), typeof option === 'object' && option);

            if (!data) {
                if (undefined === options.dialog) {
                    throw 'dialog option is mandatory.';
                }
                $this.data('ladb.tab.plugin', (data = new LadbTabTutorials(this, options, options.dialog)));
            }
            if (typeof option === 'string') {
                data[option].apply(data, Array.isArray(params) ? params : [ params ])
            } else {
                data.init(option.initializedCallback);
            }
        })
    }

    const old = $.fn.ladbTabTutorials;

    $.fn.ladbTabTutorials = Plugin;
    $.fn.ladbTabTutorials.Constructor = LadbTabTutorials;


    // NO CONFLICT
    // =================

    $.fn.ladbTabTutorials.noConflict = function () {
        $.fn.ladbTabTutorials = old;
        return this;
    }

}(jQuery);
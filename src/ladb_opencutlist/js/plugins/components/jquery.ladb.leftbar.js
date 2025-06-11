+function ($) {
    'use strict';

    // CLASS DEFINITION
    // ======================

    const LadbLeftbar = function (element, options, dialog) {
        this.options = options;
        this.$element = $(element);
        this.dialog = dialog;

        this.$bottom = $('#ladb_leftbar_bottom', this.$element);

        this.$btnMinimize = $('#ladb_leftbar_btn_minimize', this.$element);
        this.$btnMaximize = $('#ladb_leftbar_btn_maximize', this.$element);
        this.$btnNews = $('#ladb_leftbar_btn_news', this.$element);
        this.$btnUpgrade = $('#ladb_leftbar_btn_upgrade', this.$element);

    };

    LadbLeftbar.DEFAULTS = {};

    LadbLeftbar.prototype.pushNotification = function (btnSelector, options) {

        const muted = options ? options['muted'] : false;
        const silent = muted || (options ? options['silent'] : false);

        let isNew = false;

        // Notification on target btn /////

        const $btn = $(btnSelector, this.$element);
        let $btnBadge = $('.badge.badge-notification', $btn);
        if ($btnBadge.length === 0) {

            // Append badge to btn
            $btnBadge = $(Twig.twig({ref: 'core/_notification-badge.twig'}).render());
            $btn.append($btnBadge);

            // Initialize count
            $btnBadge.data('count', 0);

            isNew = true;

        }
        $btnBadge.data('count', $btnBadge.data('count') + 1);

        // Display count value
        $btnBadge.html($btnBadge.data('count'));

        // Notification on subar handle if it exists /////

        const $subbar = $btn.closest('.ladb-leftbar-subbar');
        const $subbarHandle = $('.ladb-toggle-handle', $subbar);
        if ($subbarHandle.length > 0) {

            let $handleBadge = $('.badge.badge-notification', $subbarHandle);
            if ($handleBadge.length === 0) {

                // Append badge to subbar handle
                $handleBadge = $(Twig.twig({ref: 'core/_notification-badge.twig'}).render());
                $subbarHandle.append($handleBadge);

                // Initialize count
                $handleBadge.data('count', 0);
                $handleBadge.data('count-muted', 0);

                isNew = true;

            } else {
                isNew = false;
            }
            $handleBadge.data('count', $handleBadge.data('count') + 1);

            // Display count value
            $handleBadge.html($handleBadge.data('count'));

            if (!muted) {
                $handleBadge.removeClass('badge-notification-muted');
            }

            if (isNew && !silent) {
                // Bounce
                $handleBadge.addClass('ladb-bounce-y');
            }

        }

        if (isNew && !silent) {
            rubyCallCommand('core_play_sound', {
                filename: 'notification.wav'
            });
        }

        if (muted) {
            this.muteNotification(btnSelector);
        }

    };

    LadbLeftbar.prototype.muteNotification = function (btnSelector) {

        const $btn = $(btnSelector, this.$element);
        const $btnBadge = $('.badge.badge-notification', $btn);
        if ($btnBadge.length > 0) {

            $btnBadge.addClass('badge-notification-muted');

            const $subbar = $btn.closest('.ladb-leftbar-subbar');
            const $subbarHandle = $('.ladb-toggle-handle', $subbar);
            if ($subbarHandle.length > 0) {

                const $handleBadge = $('.badge.badge-notification', $subbarHandle);
                if ($handleBadge.length > 0) {

                    $handleBadge.data('count-muted', $handleBadge.data('count-muted') + $btnBadge.data('count'));

                    // Check if muted
                    if ($handleBadge.data('count') === $handleBadge.data('count-muted')) {
                        $handleBadge.addClass('badge-notification-muted');
                    }

                }

            }

        }

    };

    LadbLeftbar.prototype.clearNotification = function (btnSelector) {

        const $btn = $(btnSelector, this.$element);
        const $btnBadge = $('.badge.badge-notification', $btn);
        if ($btnBadge.length > 0) {

            const count = $btnBadge.data('count');

            // Remove badge
            $btnBadge.remove();

            const $subbar = $btn.closest('.ladb-leftbar-subbar');
            const $subbarHandle = $('.ladb-toggle-handle', $subbar);
            if ($subbarHandle.length > 0) {

                const $handleBadge = $('.badge.badge-notification', $subbarHandle);
                if ($handleBadge.length > 0) {

                    $handleBadge.data('count', $handleBadge.data('count') - count);
                    if ($handleBadge.data('count') > 0) {

                        // Display count value
                        $handleBadge.html($handleBadge.data('count'));

                        // Check if muted
                        if ($handleBadge.data('count') === $handleBadge.data('count-muted')) {
                            $handleBadge.addClass('badge-notification-muted');
                        }

                    } else {
                        // Remove badge
                        $handleBadge.remove();
                    }

                }

            }

        }

    };

    LadbLeftbar.prototype.bind = function () {
        const that = this;

        // Bind buttons
        this.$btnMinimize.on('click', function () {
            that.dialog.minimize();
        });
        this.$btnMaximize.on('click', function () {
            that.dialog.maximize();
            if (!that.dialog.activeTabName) {
                that.dialog.selectTab(that.dialog.options.defaultTabName);
            }
        });
        this.$btnNews.on('click', function() {
            that.clearNotification('#' + $(this).attr('id'));
        });
        this.$btnUpgrade.on('click', function() {
            that.clearNotification('#' + $(this).attr('id'));
            that.dialog.showUpgradeModal();
        });

        // Bind dialog maximized events
        this.dialog.$element.on('minimizing.ladb.dialog', function() {
            that.$bottom.hide();
        });
        this.dialog.$element.on('minimized.ladb.dialog', function() {
            that.$element.addClass('ladb-full-width');
            that.$btnMinimize.hide();
            that.$btnMaximize.show();
        });
        this.dialog.$element.on('maximizing.ladb.dialog', function() {
            that.$element.removeClass('ladb-full-width');
        });
        this.dialog.$element.on('maximized.ladb.dialog', function() {
            that.$btnMinimize.show();
            that.$btnMaximize.hide();
            that.$bottom.show();
        });

        // Bind subbar toggles
        $('.ladb-subbar-toggle', this.$element).mouseover(function () {
            $('.badge.badge-notification', this).removeClass('ladb-bounce-y');
        });

    };

    LadbLeftbar.prototype.init = function () {
        this.bind();
    };

    // PLUGIN DEFINITION
    // =======================

    function Plugin(option, params) {
        return this.each(function () {
            const $this = $(this);
            let data = $this.data('ladb.leftbar');
            if (!data) {
                const options = $.extend({}, LadbLeftbar.DEFAULTS, $this.data(), typeof option === 'object' && option);
                $this.data('ladb.leftbar', (data = new LadbLeftbar(this, options, options.dialog)));
            }
            if (typeof option === 'string') {
                data[option].apply(data, Array.isArray(params) ? params : [ params ])
            } else {
                data.init();
            }
        })
    }

    const old = $.fn.ladbLeftbar;

    $.fn.ladbLeftbar = Plugin;
    $.fn.ladbLeftbar.Constructor = LadbLeftbar;


    // NO CONFLICT
    // =================

    $.fn.ladbLeftbar.noConflict = function () {
        $.fn.ladbLeftbar = old;
        return this;
    }

}(jQuery);
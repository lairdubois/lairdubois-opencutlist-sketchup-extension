+function ($) {
    'use strict';

    var SELECT_PICKER_OPTIONS = {
        size: 10,
        iconBase: 'ladb-opencutlist-icon',
        tickIcon: 'ladb-opencutlist-icon-tick',
        showTick: true
    };

    // CLASS DEFINITION
    // ======================

    var LadbTabSettings = function (element, options, opencutlist) {
        LadbAbstractTab.call(this, element, options, opencutlist);

        this.initialLanguage = this.opencutlist.capabilities.language;

        this.$btnReset = $('#ladb_btn_reset', this.$element);

        this.$selectLanguage = $('#ladb_select_language', this.$element);
        this.$btnWidthUp = $('#ladb_btn_width_up', this.$element);
        this.$btnWidthDown = $('#ladb_btn_width_down', this.$element);
        this.$btnHeightUp = $('#ladb_btn_height_up', this.$element);
        this.$btnHeightDown = $('#ladb_btn_height_down', this.$element);
        this.$btnLeftUp = $('#ladb_btn_left_up', this.$element);
        this.$btnLeftDown = $('#ladb_btn_left_down', this.$element);
        this.$btnTopUp = $('#ladb_btn_top_up', this.$element);
        this.$btnTopDown = $('#ladb_btn_top_down', this.$element);

    };
    LadbTabSettings.prototype = new LadbAbstractTab;

    LadbTabSettings.DEFAULTS = {};

    LadbTabSettings.prototype.showReloadAlert = function () {
        var $reloadAlert = $('#ladb_reload_alert', this.$element);
        $reloadAlert.show();
        $('.ladb-reaload-msg', $reloadAlert).hide();
        var language = this.opencutlist.capabilities.language === 'auto' ? this.initialLanguage : this.opencutlist.capabilities.language;
        $('.ladb-reaload-msg-' + language, $reloadAlert).show();
    };

    LadbTabSettings.prototype.bind = function () {
        LadbAbstractTab.prototype.bind.call(this);

        var that = this;

        var fnUpdate = function () {

            // Adjust min limits
            that.opencutlist.capabilities.dialogMaximizedWidth = Math.max(580, that.opencutlist.capabilities.dialogMaximizedWidth);
            that.opencutlist.capabilities.dialogMaximizedHeight = Math.max(480, that.opencutlist.capabilities.dialogMaximizedHeight);
            that.opencutlist.capabilities.dialogLeft = Math.max(0, that.opencutlist.capabilities.dialogLeft);
            that.opencutlist.capabilities.dialogTop = Math.max(0, that.opencutlist.capabilities.dialogTop);

            // Send to ruby
            rubyCallCommand('settings_dialog_settings', {
                language: that.opencutlist.capabilities.language,
                width: that.opencutlist.capabilities.dialogMaximizedWidth,
                height: that.opencutlist.capabilities.dialogMaximizedHeight,
                left: that.opencutlist.capabilities.dialogLeft,
                top: that.opencutlist.capabilities.dialogTop
            });

        };

        this.$selectLanguage.val(this.opencutlist.capabilities.language);
        this.$selectLanguage.selectpicker(SELECT_PICKER_OPTIONS);

        this.$selectLanguage.on('change', function () {
            that.opencutlist.capabilities.language = that.$selectLanguage.val();
            fnUpdate();
            that.showReloadAlert();
        });
        this.$btnReset.on('click', function () {
            $(this).blur();
            that.opencutlist.capabilities.language = 'auto';
            that.opencutlist.capabilities.dialogMaximizedWidth = 1100;
            that.opencutlist.capabilities.dialogMaximizedHeight = 640;
            that.opencutlist.capabilities.dialogLeft = 60;
            that.opencutlist.capabilities.dialogTop = 100;
            fnUpdate();
            that.showReloadAlert();
            return false;
        });
        this.$btnWidthUp.on('click', function () {
            $(this).blur();
            that.opencutlist.capabilities.dialogMaximizedWidth += 20;
            fnUpdate();
            return false;
        });
        this.$btnWidthDown.on('click', function () {
            $(this).blur();
            that.opencutlist.capabilities.dialogMaximizedWidth -= 20;
            fnUpdate();
            return false;
        });
        this.$btnHeightUp.on('click', function () {
            $(this).blur();
            that.opencutlist.capabilities.dialogMaximizedHeight += 20;
            fnUpdate();
            return false;
        });
        this.$btnHeightDown.on('click', function () {
            $(this).blur();
            that.opencutlist.capabilities.dialogMaximizedHeight -= 20;
            fnUpdate();
            return false;
        });
        this.$btnLeftUp.on('click', function () {
            $(this).blur();
            that.opencutlist.capabilities.dialogLeft += 20;
            fnUpdate();
            return false;
        });
        this.$btnLeftDown.on('click', function () {
            $(this).blur();
            that.opencutlist.capabilities.dialogLeft -= 20;
            fnUpdate();
            return false;
        });
        this.$btnTopUp.on('click', function () {
            $(this).blur();
            that.opencutlist.capabilities.dialogTop += 20;
            fnUpdate();
            return false;
        });
        this.$btnTopDown.on('click', function () {
            $(this).blur();
            that.opencutlist.capabilities.dialogTop -= 20;
            fnUpdate();
            return false;
        });

    };

    LadbTabSettings.prototype.init = function (initializedCallback) {
        var that = this;

        this.bind();

        // Callback
        if (initializedCallback && typeof(initializedCallback) == 'function') {
            initializedCallback(that.$element);
        }

    };


    // PLUGIN DEFINITION
    // =======================

    function Plugin(option, params) {
        return this.each(function () {
            var $this = $(this);
            var data = $this.data('ladb.tabSettings');
            var options = $.extend({}, LadbTabSettings.DEFAULTS, $this.data(), typeof option == 'object' && option);

            if (!data) {
                if (undefined === options.opencutlist) {
                    throw 'opencutlist option is mandatory.';
                }
                $this.data('ladb.tabSettings', (data = new LadbTabSettings(this, options, options.opencutlist)));
            }
            if (typeof option == 'string') {
                data[option].apply(data, Array.isArray(params) ? params : [ params ])
            } else {
                data.init(option.initializedCallback);
            }
        })
    }

    var old = $.fn.ladbTabSettings;

    $.fn.ladbTabSettings = Plugin;
    $.fn.ladbTabSettings.Constructor = LadbTabSettings;


    // NO CONFLICT
    // =================

    $.fn.ladbTabSettings.noConflict = function () {
        $.fn.ladbTabSettings = old;
        return this;
    }

}(jQuery);
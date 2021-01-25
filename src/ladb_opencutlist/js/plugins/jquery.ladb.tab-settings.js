+function ($) {
    'use strict';

    // CLASS DEFINITION
    // ======================

    var LadbTabSettings = function (element, options, opencutlist) {
        LadbAbstractTab.call(this, element, options, opencutlist);

        this.initialLanguage = this.dialog.capabilities.language;

        this.$btnReset = $('#ladb_btn_reset', this.$element);

        this.$selectLanguage = $('#ladb_select_language', this.$element);
        this.$selectZoom = $('#ladb_select_zoom', this.$element);
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
        $reloadAlert
            .show()
            .effect('highlight', {}, 1500);
        $('.ladb-reaload-msg', $reloadAlert).hide();
        var language = this.dialog.capabilities.language === 'auto' ? this.initialLanguage : this.dialog.capabilities.language;
        $('.ladb-reaload-msg-' + language, $reloadAlert).show();
    };

    LadbTabSettings.prototype.bind = function () {
        LadbAbstractTab.prototype.bind.call(this);

        var that = this;

        var fnUpdate = function () {

            // Adjust min limits
            that.dialog.capabilities.dialogMaximizedWidth = Math.max(580, that.dialog.capabilities.dialogMaximizedWidth);
            that.dialog.capabilities.dialogMaximizedHeight = Math.max(480, that.dialog.capabilities.dialogMaximizedHeight);
            that.dialog.capabilities.dialogLeft = Math.max(0, that.dialog.capabilities.dialogLeft);
            that.dialog.capabilities.dialogTop = Math.max(0, that.dialog.capabilities.dialogTop);

            // Send to ruby
            rubyCallCommand('settings_dialog_settings', {
                language: that.dialog.capabilities.language,
                width: that.dialog.capabilities.dialogMaximizedWidth,
                height: that.dialog.capabilities.dialogMaximizedHeight,
                left: that.dialog.capabilities.dialogLeft,
                top: that.dialog.capabilities.dialogTop,
                zoom: that.dialog.capabilities.dialogZoom
            });

        };

        this.$selectLanguage.val(this.dialog.capabilities.language);
        this.$selectLanguage.selectpicker(SELECT_PICKER_OPTIONS);
        this.$selectZoom.val(this.dialog.capabilities.dialogZoom);
        this.$selectZoom.selectpicker(SELECT_PICKER_OPTIONS);

        this.$selectLanguage.on('change', function () {
            that.dialog.capabilities.language = that.$selectLanguage.val();
            fnUpdate();
            that.showReloadAlert();
        });
        this.$selectZoom.on('change', function () {
            that.dialog.capabilities.dialogZoom = that.$selectZoom.val();
            fnUpdate();
        });
        this.$btnReset.on('click', function () {
            $(this).blur();
            that.dialog.capabilities.language = 'auto';
            that.dialog.capabilities.dialogMaximizedWidth = 1100;
            that.dialog.capabilities.dialogMaximizedHeight = 640;
            that.dialog.capabilities.dialogLeft = 60;
            that.dialog.capabilities.dialogTop = 100;
            fnUpdate();
            that.showReloadAlert();
            return false;
        });
        this.$btnWidthUp.on('click', function () {
            $(this).blur();
            that.dialog.capabilities.dialogMaximizedWidth += 20;
            fnUpdate();
            return false;
        });
        this.$btnWidthDown.on('click', function () {
            $(this).blur();
            that.dialog.capabilities.dialogMaximizedWidth -= 20;
            fnUpdate();
            return false;
        });
        this.$btnHeightUp.on('click', function () {
            $(this).blur();
            that.dialog.capabilities.dialogMaximizedHeight += 20;
            fnUpdate();
            return false;
        });
        this.$btnHeightDown.on('click', function () {
            $(this).blur();
            that.dialog.capabilities.dialogMaximizedHeight -= 20;
            fnUpdate();
            return false;
        });
        this.$btnLeftUp.on('click', function () {
            $(this).blur();
            that.dialog.capabilities.dialogLeft += 20;
            fnUpdate();
            return false;
        });
        this.$btnLeftDown.on('click', function () {
            $(this).blur();
            that.dialog.capabilities.dialogLeft -= 20;
            fnUpdate();
            return false;
        });
        this.$btnTopUp.on('click', function () {
            $(this).blur();
            that.dialog.capabilities.dialogTop += 20;
            fnUpdate();
            return false;
        });
        this.$btnTopDown.on('click', function () {
            $(this).blur();
            that.dialog.capabilities.dialogTop -= 20;
            fnUpdate();
            return false;
        });

    };

    // PLUGIN DEFINITION
    // =======================

    function Plugin(option, params) {
        return this.each(function () {
            var $this = $(this);
            var data = $this.data('ladb.tab.plugin');
            var options = $.extend({}, LadbTabSettings.DEFAULTS, $this.data(), typeof option == 'object' && option);

            if (!data) {
                if (undefined === options.dialog) {
                    throw 'dialog option is mandatory.';
                }
                $this.data('ladb.tab.plugin', (data = new LadbTabSettings(this, options, options.dialog)));
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
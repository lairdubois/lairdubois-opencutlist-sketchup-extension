+function ($) {
    'use strict';

    // CLASS DEFINITION
    // ======================

    var LadbTabSettings = function (element, options, opencutlist) {
        LadbAbstractTab.call(this, element, options, opencutlist);

        this.$btnReset = $('#ladb_btn_reset', this.$element);

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

    LadbTabSettings.prototype.bind = function () {
        var that = this;

        var fnUpdate = function() {

            // Adjust min limits
            that.opencutlist.capabilities.dialogMaximizedWidth = Math.max(580, that.opencutlist.capabilities.dialogMaximizedWidth);
            that.opencutlist.capabilities.dialogMaximizedHeight = Math.max(480, that.opencutlist.capabilities.dialogMaximizedHeight);
            that.opencutlist.capabilities.dialogLeft = Math.max(0, that.opencutlist.capabilities.dialogLeft);
            that.opencutlist.capabilities.dialogTop = Math.max(0, that.opencutlist.capabilities.dialogTop);

            // Send to ruby
            rubyCallCommand('settings_dialog_settings', {
                width: that.opencutlist.capabilities.dialogMaximizedWidth,
                height: that.opencutlist.capabilities.dialogMaximizedHeight,
                left: that.opencutlist.capabilities.dialogLeft,
                top: that.opencutlist.capabilities.dialogTop
            });

        };

        this.$btnReset.on('click', function() {
            $(this).blur();
            that.opencutlist.capabilities.dialogMaximizedWidth = 1100;
            that.opencutlist.capabilities.dialogMaximizedHeight = 800;
            that.opencutlist.capabilities.dialogLeft = 100;
            that.opencutlist.capabilities.dialogTop = 100;
            fnUpdate();
            return false;
        });
        this.$btnWidthUp.on('click', function() {
            $(this).blur();
            that.opencutlist.capabilities.dialogMaximizedWidth += 20;
            fnUpdate();
            return false;
        });
        this.$btnWidthDown.on('click', function() {
            $(this).blur();
            that.opencutlist.capabilities.dialogMaximizedWidth -= 20;
            fnUpdate();
            return false;
        });
        this.$btnHeightUp.on('click', function() {
            $(this).blur();
            that.opencutlist.capabilities.dialogMaximizedHeight += 20;
            fnUpdate();
            return false;
        });
        this.$btnHeightDown.on('click', function() {
            $(this).blur();
            that.opencutlist.capabilities.dialogMaximizedHeight -= 20;
            fnUpdate();
            return false;
        });
        this.$btnLeftUp.on('click', function() {
            $(this).blur();
            that.opencutlist.capabilities.dialogLeft += 20;
            fnUpdate();
            return false;
        });
        this.$btnLeftDown.on('click', function() {
            $(this).blur();
            that.opencutlist.capabilities.dialogLeft -= 20;
            fnUpdate();
            return false;
        });
        this.$btnTopUp.on('click', function() {
            $(this).blur();
            that.opencutlist.capabilities.dialogTop += 20;
            fnUpdate();
            return false;
        });
        this.$btnTopDown.on('click', function() {
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
                data[option](params);
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
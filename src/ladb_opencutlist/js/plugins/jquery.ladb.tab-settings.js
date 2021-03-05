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

        // Global settings /////

        var fnUpdate = function () {

            // Adjust min limits
            that.dialog.capabilities.dialog_maximized_width = Math.max(580, that.dialog.capabilities.dialog_maximized_width);
            that.dialog.capabilities.dialog_maximized_height = Math.max(480, that.dialog.capabilities.dialog_maximized_height);
            that.dialog.capabilities.dialog_left = Math.max(0, that.dialog.capabilities.dialog_left);
            that.dialog.capabilities.dialog_top = Math.max(0, that.dialog.capabilities.dialog_top);

            // Send to ruby
            rubyCallCommand('settings_dialog_settings', {
                language: that.dialog.capabilities.language,
                width: that.dialog.capabilities.dialog_maximized_width,
                height: that.dialog.capabilities.dialog_maximized_height,
                left: that.dialog.capabilities.dialog_left,
                top: that.dialog.capabilities.dialog_top,
                zoom: that.dialog.capabilities.dialog_zoom
            });

        };

        this.$selectLanguage.val(this.dialog.capabilities.language);
        this.$selectLanguage.selectpicker(SELECT_PICKER_OPTIONS);

        this.$selectZoom.prop('disabled', $('body').hasClass('ie'));    // Disable zoom feature on IE
        this.$selectZoom.val(this.dialog.capabilities.dialog_zoom);
        this.$selectZoom.selectpicker(SELECT_PICKER_OPTIONS);

        this.$selectLanguage.on('change', function () {
            that.dialog.capabilities.language = that.$selectLanguage.val();
            fnUpdate();
            that.showReloadAlert();
        });
        this.$selectZoom.on('change', function () {
            that.dialog.capabilities.dialog_zoom = that.$selectZoom.val();
            fnUpdate();
        });
        this.$btnReset.on('click', function () {
            $(this).blur();
            that.dialog.capabilities.language = 'auto';
            that.dialog.capabilities.dialog_maximized_width = 1100;
            that.dialog.capabilities.dialog_maximized_height = 640;
            that.dialog.capabilities.dialog_left = 60;
            that.dialog.capabilities.dialog_top = 100;
            that.dialog.capabilities.dialog_zoom = '100%';
            fnUpdate();
            that.showReloadAlert();
            return false;
        });
        this.$btnWidthUp.on('click', function () {
            $(this).blur();
            that.dialog.capabilities.dialog_maximized_width += 20;
            fnUpdate();
            return false;
        });
        this.$btnWidthDown.on('click', function () {
            $(this).blur();
            that.dialog.capabilities.dialog_maximized_width -= 20;
            fnUpdate();
            return false;
        });
        this.$btnHeightUp.on('click', function () {
            $(this).blur();
            that.dialog.capabilities.dialog_maximized_height += 20;
            fnUpdate();
            return false;
        });
        this.$btnHeightDown.on('click', function () {
            $(this).blur();
            that.dialog.capabilities.dialog_maximized_height -= 20;
            fnUpdate();
            return false;
        });
        this.$btnLeftUp.on('click', function () {
            $(this).blur();
            that.dialog.capabilities.dialog_left += 20;
            fnUpdate();
            return false;
        });
        this.$btnLeftDown.on('click', function () {
            $(this).blur();
            that.dialog.capabilities.dialog_left -= 20;
            fnUpdate();
            return false;
        });
        this.$btnTopUp.on('click', function () {
            $(this).blur();
            that.dialog.capabilities.dialog_top += 20;
            fnUpdate();
            return false;
        });
        this.$btnTopDown.on('click', function () {
            $(this).blur();
            that.dialog.capabilities.dialog_top -= 20;
            fnUpdate();
            return false;
        });

        // Model Settings /////

        var modelSettings = {};

        // Fetch UI elements
        var $widgetPreset = $('.ladb-widget-preset', that.$element);
        var $inputCurrencySymbol = $('#ladb_model_input_currency_symbol', that.$element);
        var $selectMassUnitSymbol = $('#ladb_model_select_mass_unit_symbol', that.$element);
        var $btnSave = $('#ladb_model_btn_save', that.$element);

        var fnFetchOptions = function (options) {
            options.currency_symbol = $inputCurrencySymbol.val();
            options.mass_unit_symbol = $selectMassUnitSymbol.selectpicker('val');
        };
        var fnFillInputs = function (options) {
            $inputCurrencySymbol.val(options.currency_symbol);
            $selectMassUnitSymbol.selectpicker('val', options.mass_unit_symbol);
        };
        var retrieveModelOptions = function () {

            // Retrieve label options
            rubyCallCommand('core_get_model_preset', { dictionary: 'settings_model' }, function (response) {

                var modelOptions = response.preset;
                fnFillInputs(modelOptions);

            });

        };

        $widgetPreset.ladbWidgetPreset({
            dialog: that.dialog,
            dictionary: 'settings_model',
            fnFetchOptions: fnFetchOptions,
            fnFillInputs: fnFillInputs
        });
        $selectMassUnitSymbol.selectpicker(SELECT_PICKER_OPTIONS);

        retrieveModelOptions();

        // Bin button
        $btnSave.on('click', function () {
            $(this).blur();

            // Fetch options
            fnFetchOptions(modelSettings);

            // Store options
            rubyCallCommand('core_set_model_preset', { dictionary: 'settings_model', values: modelSettings, fire_event:true });

            // Notification
            that.dialog.notify(i18next.t('tab.settings.save_to_model_success'), 'success');

        });

        // Events

        addEventCallback([ 'on_new_model', 'on_open_model', 'on_activate_model' ], function (params) {
            retrieveModelOptions();
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
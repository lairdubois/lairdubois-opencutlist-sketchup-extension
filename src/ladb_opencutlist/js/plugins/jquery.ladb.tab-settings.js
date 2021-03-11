+function ($) {
    'use strict';

    // CLASS DEFINITION
    // ======================

    var LadbTabSettings = function (element, options, opencutlist) {
        LadbAbstractTab.call(this, element, options, opencutlist);

        this.initialLanguage = this.dialog.capabilities.language;

        this.$panelGlobal = $('#ladb_settings_panel_global', this.$element);
        this.$panelModel = $('#ladb_settings_panel_modal', this.$element);

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

    // Init /////

    LadbTabSettings.prototype.registerCommands = function () {
        LadbAbstractTab.prototype.registerCommands.call(this);

        var that = this;

        this.registerCommand('highlight_panel', function (parameters) {
            setTimeout(function () {     // Use setTimeout to give time to UI to refresh
                switch (parameters.panel) {
                    case 'global':
                        that.$panelGlobal.effect('highlight', {}, 1500);
                        break;
                    case 'model':
                        that.$panelModel.effect('highlight', {}, 1500);
                        break;
                }
            }, 1);
        });
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
        if (this.dialog.capabilities.dialog_zoom !== '100%') {
            this.$selectZoom.show();
        }
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
        var modelLengthFormat = 0;

        // Fetch UI elements
        var $widgetPreset = $('.ladb-widget-preset', that.$element);
        var $selectLengthUnit = $('#ladb_model_select_length_unit', that.$element);
        var $selectLengthFormat = $('#ladb_model_select_length_format', that.$element);
        var $selectLengthPrecision = $('#ladb_model_select_length_precision', that.$element);
        var $inputSuppressUnitsDisplay = $('#ladb_model_input_suppress_units_display', that.$element);
        var $selectMassUnit = $('#ladb_model_select_mass_unit', that.$element);
        var $inputCurrencySymbol = $('#ladb_model_input_currency_symbol', that.$element);

        var fnFetchOptions = function (options) {
            options.mass_unit = parseInt($selectMassUnit.selectpicker('val'));
            options.currency_symbol = $inputCurrencySymbol.val();
        };
        var fnFillInputs = function (options) {
            $selectMassUnit.selectpicker('val', options.mass_unit);
            $inputCurrencySymbol.val(options.currency_symbol);
        };
        var fnAdaptLengthPrecisionToFormat = function () {
            if (modelLengthFormat === 0 /* DECIMAL */ || modelLengthFormat === 2 /* ENGINEERING */) {
                $('.length-unit-decimal', that.$element).show();
                $('.length-unit-fractional', that.$element).hide();
            } else {
                $('.length-unit-decimal', that.$element).hide();
                $('.length-unit-fractional', that.$element).show();
            }
        }
        var fnFillLengthSettings = function(settings) {

            $selectLengthUnit
                .selectpicker('val', settings.length_unit)
                .prop('disabled', settings.length_unit_disabled)
                .selectpicker('refresh')
            ;
            $selectLengthFormat.selectpicker('val', settings.length_format);
            $selectLengthPrecision.selectpicker('val', settings.length_precision);
            $inputSuppressUnitsDisplay
                .prop('checked', !settings.suppress_units_display)
                .prop('disabled', settings.suppress_units_display_disabled)
            ;

            modelLengthFormat = settings.length_format;
            fnAdaptLengthPrecisionToFormat(modelLengthFormat);

        }
        var fnRetrieveModelOptions = function () {

            // Retrieve SU options
            rubyCallCommand('settings_get_length_settings', null, fnFillLengthSettings);

            // Retrieve OCL options
            rubyCallCommand('core_get_model_preset', { dictionary: 'settings_model' }, function (response) {

                var modelOptions = response.preset;
                fnFillInputs(modelOptions);

            });

        };
        var fnSaveOptions = function () {

            // Fetch options
            fnFetchOptions(modelSettings);

            // Store options
            rubyCallCommand('core_set_model_preset', { dictionary: 'settings_model', values: modelSettings, fire_event:true });

        };

        $widgetPreset.ladbWidgetPreset({
            dialog: that.dialog,
            dictionary: 'settings_model',
            fnFetchOptions: fnFetchOptions,
            fnFillInputs: function (options) {
                fnFillInputs(options);
                fnSaveOptions();
            }
        });
        $selectLengthUnit.selectpicker(SELECT_PICKER_OPTIONS);
        $selectLengthFormat.selectpicker(SELECT_PICKER_OPTIONS);
        $selectLengthPrecision.selectpicker(SELECT_PICKER_OPTIONS);
        $selectMassUnit.selectpicker(SELECT_PICKER_OPTIONS);

        fnRetrieveModelOptions();

        // Bind input & select
        $selectLengthUnit
            .on('change', function () {
                var lengthUnit = parseInt($selectLengthUnit.selectpicker('val'));

                rubyCallCommand('settings_set_length_settings', { length_unit: lengthUnit }, fnFillLengthSettings);

            })
        ;
        $selectLengthFormat
            .on('change', function () {
                var lengthFormat = parseInt($selectLengthFormat.selectpicker('val'));

                rubyCallCommand('settings_set_length_settings', { length_format: lengthFormat }, fnFillLengthSettings);

            })
        ;
        $selectLengthPrecision
            .on('change', function () {
                var lengthPrecision = parseInt($selectLengthPrecision.selectpicker('val'));

                rubyCallCommand('settings_set_length_settings', { length_precision: lengthPrecision }, fnFillLengthSettings);

            })
            .on('show.bs.select', function (e, clickedIndex, isSelected, previousValue) {
                fnAdaptLengthPrecisionToFormat(modelLengthFormat);
            })
        ;
        $inputSuppressUnitsDisplay
            .on('change', function () {
                var suppressUnitsDisplay = !($inputSuppressUnitsDisplay.is(':checked'));

                rubyCallCommand('settings_set_length_settings', { suppress_units_display: suppressUnitsDisplay }, fnFillLengthSettings);

            })
        ;
        $selectMassUnit.on('change', fnSaveOptions);
        $inputCurrencySymbol.on('change', fnSaveOptions);

        // Events

        addEventCallback([ 'on_new_model', 'on_open_model', 'on_activate_model' ], function (params) {
            fnRetrieveModelOptions();
        });
        addEventCallback('on_options_provider_changed', function (params) {
            fnRetrieveModelOptions();
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
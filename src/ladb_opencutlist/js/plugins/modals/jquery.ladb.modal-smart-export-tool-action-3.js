+function ($) {
    'use strict';

    // CLASS DEFINITION
    // ======================

    var LadbModalSmartExportToolAction3 = function (element, options, dialog) {
        LadbAbstractModal.call(this, element, options, dialog);

    };
    LadbModalSmartExportToolAction3.prototype = Object.create(LadbAbstractModal.prototype);

    LadbModalSmartExportToolAction3.DEFAULTS = {};

    // Init ///

    LadbModalSmartExportToolAction3.prototype.init = function () {
        LadbAbstractModal.prototype.init.call(this);

        var that = this;

        var dictonary = 'tool_smart_export_options';
        var section = 'action_3';

        // Retrieve options
        rubyCallCommand('core_get_global_preset', { dictionary: dictonary, section: section }, function (response) {

            var options = response.preset;

            // Fetch UI elements
            var $widgetPreset = $('.ladb-widget-preset', that.$element);
            var $selectFileFormat = $('#ladb_select_file_format', that.$element);
            var $selectUnit = $('#ladb_select_unit', that.$element);
            var $selectSmoothing = $('#ladb_select_smoothing', that.$element);
            var $inputPartsPathsStrokeColor = $('#ladb_input_parts_paths_stroke_color', that.$element);
            var $btnValidate = $('#ladb_btn_validate', that.$element);

            var fnFetchOptions = function (options) {
                options.file_format = $selectFileFormat.val();
                options.unit = parseInt($selectUnit.val());
                options.smoothing = $selectSmoothing.val() === '1';
                options.parts_paths_stroke_color = $inputPartsPathsStrokeColor.ladbTextinputColor('val');
            };
            var fnFillInputs = function (options) {
                $selectFileFormat.selectpicker('val', options.file_format);
                $selectUnit.selectpicker('val', options.unit);
                $selectSmoothing.selectpicker('val', options.smoothing ? '1' : '0');
                $inputPartsPathsStrokeColor.ladbTextinputColor('val', options.parts_paths_stroke_color);
            };

            $widgetPreset.ladbWidgetPreset({
                dialog: that.dialog,
                dictionary: 'tool_smart_export_options',
                section: 'action_2',
                fnFetchOptions: fnFetchOptions,
                fnFillInputs: fnFillInputs
            });
            $selectFileFormat.selectpicker(SELECT_PICKER_OPTIONS);
            $selectUnit.selectpicker(SELECT_PICKER_OPTIONS);
            $selectSmoothing.selectpicker(SELECT_PICKER_OPTIONS);
            $inputPartsPathsStrokeColor.ladbTextinputColor(TEXTINPUT_COLOR_OPTIONS);

            fnFillInputs(options);

            // Bind buttons
            $btnValidate.on('click', function () {

                // Fetch options
                fnFetchOptions(options);

                // Store options
                rubyCallCommand('core_set_global_preset', { dictionary: dictonary, values: options, section: section, fire_event: true });

                // Hide modal
                that.dialog.hide();

            });

        });

    };

    // PLUGIN DEFINITION
    // =======================

    function Plugin(option, params) {
        return this.each(function () {
            var $this = $(this);
            var data = $this.data('ladb.tab.plugin');
            var options = $.extend({}, LadbModalSmartExportToolAction3.DEFAULTS, $this.data(), typeof option === 'object' && option);

            if (!data) {
                if (undefined === options.dialog) {
                    throw 'dialog option is mandatory.';
                }
                $this.data('ladb.tab.plugin', (data = new LadbModalSmartExportToolAction3(this, options, options.dialog)));
            }
            if (typeof option === 'string') {
                data[option].apply(data, Array.isArray(params) ? params : [ params ])
            } else {
                data.init();
            }
        })
    }

    var old = $.fn.ladbModalSmartExportToolAction3;

    $.fn.ladbModalSmartExportToolAction3 = Plugin;
    $.fn.ladbModalSmartExportToolAction3.Constructor = LadbModalSmartExportToolAction3;


    // NO CONFLICT
    // =================

    $.fn.ladbModalSmartExportToolAction3.noConflict = function () {
        $.fn.ladbModalSmartExportToolAction3 = old;
        return this;
    }

}(jQuery);
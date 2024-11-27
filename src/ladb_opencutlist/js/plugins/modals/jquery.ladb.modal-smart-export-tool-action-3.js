+function ($) {
    'use strict';

    // CLASS DEFINITION
    // ======================

    const LadbModalSmartExportToolAction3 = function (element, options, dialog) {
        LadbAbstractModal.call(this, element, options, dialog);

    };
    LadbModalSmartExportToolAction3.prototype = Object.create(LadbAbstractModal.prototype);

    LadbModalSmartExportToolAction3.DEFAULTS = {};

    // Init ///

    LadbModalSmartExportToolAction3.prototype.init = function () {
        LadbAbstractModal.prototype.init.call(this);

        const that = this;

        const dictonary = 'tool_smart_export_options';
        const section = 'action_3';

        // Retrieve options
        rubyCallCommand('core_get_global_preset', { dictionary: dictonary, section: section }, function (response) {

            const options = response.preset;

            // Fetch UI elements
            const $widgetPreset = $('.ladb-widget-preset', that.$element);
            const $selectFileFormat = $('#ladb_select_file_format', that.$element);
            const $selectUnit = $('#ladb_select_unit', that.$element);
            const $selectSmoothing = $('#ladb_select_smoothing', that.$element);
            const $inputPartsPathsStrokeColor = $('#ladb_input_parts_paths_stroke_color', that.$element);
            const $inputPartsPathsFillColor = $('#ladb_input_parts_paths_fill_color', that.$element);
            const $btnValidate = $('#ladb_btn_validate', that.$element);

            const fnFetchOptions = function (options) {
                options.file_format = $selectFileFormat.val();
                options.unit = parseInt($selectUnit.val());
                options.smoothing = $selectSmoothing.val() === '1';
                options.parts_paths_stroke_color = $inputPartsPathsStrokeColor.ladbTextinputColor('val');
                options.parts_paths_fill_color = $inputPartsPathsFillColor.ladbTextinputColor('val');
            };
            const fnFillInputs = function (options) {
                $selectFileFormat.selectpicker('val', options.file_format);
                $selectUnit.selectpicker('val', options.unit);
                $selectSmoothing.selectpicker('val', options.smoothing ? '1' : '0');
                $inputPartsPathsStrokeColor.ladbTextinputColor('val', options.parts_paths_stroke_color);
                $inputPartsPathsFillColor.ladbTextinputColor('val', options.parts_paths_fill_color);
                fnUpdateFieldsVisibility();
            };
            const fnUpdateFieldsVisibility = function () {
                const isDxf = $selectFileFormat.val() === 'dxf';
                $inputPartsPathsFillColor.ladbTextinputColor(isDxf ? 'disable' : 'enable');
                $('.ladb-form-fill-color').css('opacity', isDxf ? 0.3 : 1);
            };

            $widgetPreset.ladbWidgetPreset({
                dialog: that.dialog,
                dictionary: 'tool_smart_export_options',
                section: 'action_3',
                fnFetchOptions: fnFetchOptions,
                fnFillInputs: fnFillInputs
            });
            $selectFileFormat
                .selectpicker(SELECT_PICKER_OPTIONS)
                .on('changed.bs.select', fnUpdateFieldsVisibility)
            ;
            $selectUnit.selectpicker(SELECT_PICKER_OPTIONS);
            $selectSmoothing.selectpicker(SELECT_PICKER_OPTIONS);
            $inputPartsPathsStrokeColor.ladbTextinputColor(TEXTINPUT_COLOR_OPTIONS);
            $inputPartsPathsFillColor.ladbTextinputColor(TEXTINPUT_COLOR_OPTIONS);

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
            const $this = $(this);
            let data = $this.data('ladb.tab.plugin');
            const options = $.extend({}, LadbModalSmartExportToolAction3.DEFAULTS, $this.data(), typeof option === 'object' && option);

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

    const old = $.fn.ladbModalSmartExportToolAction3;

    $.fn.ladbModalSmartExportToolAction3 = Plugin;
    $.fn.ladbModalSmartExportToolAction3.Constructor = LadbModalSmartExportToolAction3;


    // NO CONFLICT
    // =================

    $.fn.ladbModalSmartExportToolAction3.noConflict = function () {
        $.fn.ladbModalSmartExportToolAction3 = old;
        return this;
    }

}(jQuery);
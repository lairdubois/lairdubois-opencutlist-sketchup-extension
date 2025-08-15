+function ($) {
    'use strict';

    // CLASS DEFINITION
    // ======================

    const LadbModalSmartExportToolAction2 = function (element, options, dialog) {
        LadbAbstractModal.call(this, element, options, dialog);

    };
    LadbModalSmartExportToolAction2.prototype = Object.create(LadbAbstractModal.prototype);

    LadbModalSmartExportToolAction2.DEFAULTS = {};

    // Init ///

    LadbModalSmartExportToolAction2.prototype.init = function () {
        LadbAbstractModal.prototype.init.call(this);

        const that = this;

        const dictonary = 'tool_smart_export_options';
        const section = 'action_2';

        // Retrieve options
        rubyCallCommand('core_get_global_preset', { dictionary: dictonary, section: section }, function (response) {

            const options = response.preset;

            // Fetch UI elements
            const $widgetPreset = $('.ladb-widget-preset', that.$element);
            const $selectFileFormat = $('#ladb_select_file_format', that.$element);
            const $selectUnit = $('#ladb_select_unit', that.$element);
            const $selectSmoothing = $('#ladb_select_smoothing', that.$element);
            const $inputPartsStrokeColor = $('#ladb_input_parts_stroke_color', that.$element);
            const $inputPartsFillColor = $('#ladb_input_parts_fill_color', that.$element);
            const $btnValidate = $('#ladb_btn_validate', that.$element);

            const fnFetchOptions = function (options) {
                options.file_format = $selectFileFormat.val();
                options.unit = parseInt($selectUnit.val());
                options.smoothing = $selectSmoothing.val() === '1';
                options.parts_stroke_color = $inputPartsStrokeColor.ladbTextinputColor('val');
                options.parts_fill_color = $inputPartsFillColor.ladbTextinputColor('val');
            };
            const fnFillInputs = function (options) {
                $selectFileFormat.selectpicker('val', options.file_format);
                $selectUnit.selectpicker('val', options.unit);
                $selectSmoothing.selectpicker('val', options.smoothing ? '1' : '0');
                $inputPartsStrokeColor.ladbTextinputColor('val', options.parts_stroke_color);
                $inputPartsFillColor.ladbTextinputColor('val', options.parts_fill_color);
                fnUpdateFieldsVisibility();
            };
            const fnUpdateFieldsVisibility = function () {
                const isDxf = $selectFileFormat.val() === 'dxf';
                $inputPartsFillColor.ladbTextinputColor(isDxf ? 'disable' : 'enable');
                $('.ladb-form-fill-color').css('opacity', isDxf ? 0.3 : 1);
            };

            $widgetPreset.ladbWidgetPreset({
                dialog: that.dialog,
                dictionary: dictonary,
                section: section,
                fnFetchOptions: fnFetchOptions,
                fnFillInputs: fnFillInputs
            });
            $selectFileFormat
                .selectpicker(SELECT_PICKER_OPTIONS)
                .on('changed.bs.select', fnUpdateFieldsVisibility)
            ;
            $selectUnit.selectpicker(SELECT_PICKER_OPTIONS);
            $selectSmoothing.selectpicker(SELECT_PICKER_OPTIONS);
            $inputPartsStrokeColor.ladbTextinputColor(TEXTINPUT_COLOR_OPTIONS);
            $inputPartsFillColor.ladbTextinputColor(TEXTINPUT_COLOR_OPTIONS);

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
            const options = $.extend({}, LadbModalSmartExportToolAction2.DEFAULTS, $this.data(), typeof option === 'object' && option);

            if (!data) {
                if (undefined === options.dialog) {
                    throw 'dialog option is mandatory.';
                }
                $this.data('ladb.tab.plugin', (data = new LadbModalSmartExportToolAction2(this, options, options.dialog)));
            }
            if (typeof option === 'string') {
                data[option].apply(data, Array.isArray(params) ? params : [ params ])
            } else {
                data.init();
            }
        })
    }

    const old = $.fn.ladbModalSmartExportToolAction2;

    $.fn.ladbModalSmartExportToolAction2 = Plugin;
    $.fn.ladbModalSmartExportToolAction2.Constructor = LadbModalSmartExportToolAction2;


    // NO CONFLICT
    // =================

    $.fn.ladbModalSmartExportToolAction2.noConflict = function () {
        $.fn.ladbModalSmartExportToolAction2 = old;
        return this;
    }

}(jQuery);
+function ($) {
    'use strict';

    // CLASS DEFINITION
    // ======================

    const LadbModalSmartDrawToolAction1 = function (element, options, dialog) {
        LadbAbstractModal.call(this, element, options, dialog);

    };
    LadbModalSmartDrawToolAction1.prototype = Object.create(LadbAbstractModal.prototype);

    LadbModalSmartDrawToolAction1.DEFAULTS = {};

    // Init ///

    LadbModalSmartDrawToolAction1.prototype.init = function () {
        LadbAbstractModal.prototype.init.call(this);

        const that = this;

        const dictonary = 'tool_smart_draw_options';
        const section = 'action_1';

        // Retrieve options
        rubyCallCommand('core_get_global_preset', { dictionary: dictonary, section: section }, function (response) {

            const options = response.preset;

            // Fetch UI elements
            const $widgetPreset = $('.ladb-widget-preset', that.$element);
            const $inputSectionOffset = $('#ladb_input_shape_offset', that.$element);
            const $inputShapeOffset = $('#ladb_input_segment_count', that.$element);
            const $selectConstrution = $('#ladb_select_construction', that.$element);
            const $selectSmoothing = $('#ladb_select_smoothing', that.$element);
            const $selectMeasureFromDiameter = $('#ladb_select_measure_from_diameter', that.$element);
            const $selectPullCentered = $('#ladb_select_pull_centered', that.$element);
            const $selectDrawIn = $('#ladb_select_draw_in', that.$element);
            const $selectAskName = $('#ladb_select_ask_name', that.$element);
            const $btnValidate = $('#ladb_btn_validate', that.$element);

            const fnFetchOptions = function (options) {
                options.shape_offset = $inputSectionOffset.val();
                options.segment_count = parseInt($inputShapeOffset.val());
                options.construction = $selectConstrution.val() === '1';
                options.smoothing = $selectSmoothing.val() === '1';
                options.measure_from_diameter = $selectMeasureFromDiameter.val() === '1';
                options.pull_centered = $selectPullCentered.val() === '1';
                options.draw_in = $selectDrawIn.val() === '1';
                options.ask_name = $selectAskName.val() === '1';
            };
            const fnFillInputs = function (options) {
                $inputSectionOffset.val(options.shape_offset);
                $inputShapeOffset.val(options.segment_count);
                $selectConstrution.selectpicker('val', options.construction ? '1' : '0');
                $selectSmoothing.selectpicker('val', options.smoothing ? '1' : '0');
                $selectMeasureFromDiameter.selectpicker('val', options.measure_from_diameter ? '1' : '0');
                $selectPullCentered.selectpicker('val', options.pull_centered ? '1' : '0');
                $selectDrawIn.selectpicker('val', options.draw_in ? '1' : '0');
                $selectAskName.selectpicker('val', options.ask_name ? '1' : '0');
            };

            $widgetPreset.ladbWidgetPreset({
                dialog: that.dialog,
                dictionary: 'tool_smart_draw_options',
                section: 'action_0',
                fnFetchOptions: fnFetchOptions,
                fnFillInputs: fnFillInputs
            });
            $inputSectionOffset.ladbTextinputDimension();
            $inputShapeOffset.ladbTextinputNumberWithUnit({
                resetValue: '24'
            });
            $selectConstrution.selectpicker(SELECT_PICKER_OPTIONS);
            $selectSmoothing.selectpicker(SELECT_PICKER_OPTIONS);
            $selectMeasureFromDiameter.selectpicker(SELECT_PICKER_OPTIONS);
            $selectPullCentered.selectpicker(SELECT_PICKER_OPTIONS);
            $selectDrawIn.selectpicker(SELECT_PICKER_OPTIONS);
            $selectAskName.selectpicker(SELECT_PICKER_OPTIONS);

            fnFillInputs(options);

            // Bind buttons
            $btnValidate.on('click', function () {

                // Fetch options
                fnFetchOptions(options);

                // Store options
                rubyCallCommand('core_set_global_preset', {
                    dictionary: dictonary,
                    values: options,
                    section: section,
                    fire_event: true
                });

                // Hide modal
                that.dialog.hide();

            });

            // Focus
            if (that.options.focused_field) {
                if (that.options.focused_field.option === 'shape_offset') {
                    $inputSectionOffset.focus();
                    $inputSectionOffset.select();
                } else if (that.options.focused_field.option === 'segment_count') {
                    $inputShapeOffset.focus();
                    $inputShapeOffset.select();
                }
            }

        });

    };

    // PLUGIN DEFINITION
    // =======================

    function Plugin(option, params) {
        return this.each(function () {
            const $this = $(this);
            let data = $this.data('ladb.tab.plugin');
            const options = $.extend({}, LadbModalSmartDrawToolAction1.DEFAULTS, $this.data(), typeof option === 'object' && option);

            if (!data) {
                if (undefined === options.dialog) {
                    throw 'dialog option is mandatory.';
                }
                $this.data('ladb.tab.plugin', (data = new LadbModalSmartDrawToolAction1(this, options, options.dialog)));
            }
            if (typeof option === 'string') {
                data[option].apply(data, Array.isArray(params) ? params : [ params ])
            } else {
                data.init();
            }
        })
    }

    const old = $.fn.ladbModalSmartDrawToolAction1;

    $.fn.ladbModalSmartDrawToolAction1 = Plugin;
    $.fn.ladbModalSmartDrawToolAction1.Constructor = LadbModalSmartDrawToolAction1;


    // NO CONFLICT
    // =================

    $.fn.ladbModalSmartDrawToolAction1.noConflict = function () {
        $.fn.ladbModalSmartDrawToolAction1 = old;
        return this;
    }

}(jQuery);
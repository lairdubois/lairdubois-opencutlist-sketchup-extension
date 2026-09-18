+function ($) {
    'use strict';

    // CLASS DEFINITION
    // ======================

    const LadbModalSmartBuildToolAction2 = function (element, options, dialog) {
        LadbAbstractModal.call(this, element, options, dialog);

    };
    LadbModalSmartBuildToolAction2.prototype = Object.create(LadbAbstractModal.prototype);

    LadbModalSmartBuildToolAction2.DEFAULTS = {};

    // Init ///

    LadbModalSmartBuildToolAction2.prototype.init = function () {
        LadbAbstractModal.prototype.init.call(this);

        const that = this;

        const dictionary = 'tool_smart_build_options';
        const section = 'action_2';

        // Retrieve options
        rubyCallCommand('core_get_global_preset', { dictionary: dictionary, section: section }, function (response) {

            const options = response.preset;

            // Fetch UI elements
            const $widgetPreset = $('.ladb-widget-preset', that.$element);
            const $inputThickness = $('#ladb_input_thickness', that.$element);
            const $inputGrooveDepth = $('#ladb_input_groove_depth', that.$element);
            const $inputGrooveSetback = $('#ladb_input_groove_setback', that.$element);
            const $selectGrooveThrough = $('#ladb_select_groove_through', that.$element);
            const $selectAxes = $('#ladb_select_axes', that.$element);
            const $selectMeasureReversed = $('#ladb_select_measure_reversed', that.$element);
            const $selectReduceEnvelope = $('#ladb_select_reduce_envelope', that.$element);
            const $selectAskName = $('#ladb_select_ask_name', that.$element);
            const $inputLayerName = $('#ladb_input_layer_name', that.$element);
            const $btnValidate = $('#ladb_btn_validate', that.$element);

            const fnFetchOptions = function (options) {
                options.thickness = $inputThickness.val();
                options.groove_depth = $inputGrooveDepth.val();
                options.groove_setback = $inputGrooveSetback.val();
                options.groove_through = $selectGrooveThrough.val() === '1';
                options.axes = $selectAxes.val();
                options.measure_reversed = $selectMeasureReversed.val() === '1';
                options.reduce_envelope = $selectReduceEnvelope.val() === '1';
                options.ask_name = $selectAskName.val() === '1';
                options.layer_name = $inputLayerName.val();
            };
            const fnFillInputs = function (options) {
                $inputThickness.val(options.thickness);
                $inputGrooveDepth.val(options.groove_depth);
                $inputGrooveSetback.val(options.groove_setback);
                $selectGrooveThrough.selectpicker('val', options.groove_through ? '1' : '0');
                $selectAxes.selectpicker('val', options.axes);
                $selectMeasureReversed.selectpicker('val', options.measure_reversed ? '1' : '0');
                $selectReduceEnvelope.selectpicker('val', options.reduce_envelope ? '1' : '0');
                $selectAskName.selectpicker('val', options.ask_name ? '1' : '0');
                $inputLayerName.val(options.layer_name);
            };

            $widgetPreset.ladbWidgetPreset({
                dialog: that.dialog,
                dictionary: dictionary,
                section: section,
                fnFetchOptions: fnFetchOptions,
                fnFillInputs: fnFillInputs
            });
            $inputThickness.ladbTextinputDimension();
            $inputGrooveDepth.ladbTextinputDimension();
            $inputGrooveSetback.ladbTextinputDimension();
            $selectGrooveThrough.selectpicker(SELECT_PICKER_MODAL_OPTIONS);
            $selectAxes.selectpicker(SELECT_PICKER_MODAL_OPTIONS);
            $selectMeasureReversed.selectpicker(SELECT_PICKER_MODAL_OPTIONS);
            $selectReduceEnvelope.selectpicker(SELECT_PICKER_MODAL_OPTIONS);
            $selectAskName.selectpicker(SELECT_PICKER_MODAL_OPTIONS);

            fnFillInputs(options);

            // Bind buttons
            $btnValidate.on('click', function () {

                // Fetch options
                fnFetchOptions(options);

                // Store options
                rubyCallCommand('core_set_global_preset', {
                    dictionary: dictionary,
                    values: options,
                    section: section,
                    fire_event: true
                });

                // Hide modal
                that.dialog.hide();

            });

            // Focus
            if (that.options.focused_field) {
                if (that.options.focused_field.option === 'thickness') {
                    $inputThickness.focus();
                    $inputThickness.select();
                } else if (that.options.focused_field.option === 'groove_depth') {
                    $inputGrooveDepth.focus();
                    $inputGrooveDepth.select();
                } else if (that.options.focused_field.option === 'groove_setback') {
                    $inputGrooveSetback.focus();
                    $inputGrooveSetback.select();
                }
            }

        });

    };

    // PLUGIN DEFINITION
    // =======================

    function Plugin(option, params) {
        return this.each(function () {
            const $this = $(this);
            let data = $this.data('ladb.modal.plugin');
            const options = $.extend({}, LadbModalSmartBuildToolAction2.DEFAULTS, $this.data(), typeof option === 'object' && option);

            if (!data) {
                if (undefined === options.dialog) {
                    throw 'dialog option is mandatory.';
                }
                $this.data('ladb.modal.plugin', (data = new LadbModalSmartBuildToolAction2(this, options, options.dialog)));
            }
            if (typeof option === 'string') {
                data[option].apply(data, Array.isArray(params) ? params : [ params ])
            } else {
                data.init();
            }
        })
    }

    const old = $.fn.ladbModalSmartBuildToolAction2;

    $.fn.ladbModalSmartBuildToolAction2 = Plugin;
    $.fn.ladbModalSmartBuildToolAction2.Constructor = LadbModalSmartBuildToolAction2;


    // NO CONFLICT
    // =================

    $.fn.ladbModalSmartBuildToolAction2.noConflict = function () {
        $.fn.ladbModalSmartBuildToolAction2 = old;
        return this;
    }

}(jQuery);

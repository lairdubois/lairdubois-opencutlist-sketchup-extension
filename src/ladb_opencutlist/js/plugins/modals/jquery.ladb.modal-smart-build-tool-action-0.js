+function ($) {
    'use strict';

    // CLASS DEFINITION
    // ======================

    const LadbModalSmartBuildToolAction0 = function (element, options, dialog) {
        LadbAbstractModal.call(this, element, options, dialog);

    };
    LadbModalSmartBuildToolAction0.prototype = Object.create(LadbAbstractModal.prototype);

    LadbModalSmartBuildToolAction0.DEFAULTS = {};

    // Init ///

    LadbModalSmartBuildToolAction0.prototype.init = function () {
        LadbAbstractModal.prototype.init.call(this);

        const that = this;

        const dictionary = 'tool_smart_build_options';
        const section = 'action_0';

        // Retrieve options
        rubyCallCommand('core_get_global_preset', { dictionary: dictionary, section: section }, function (response) {

            const options = response.preset;

            // Fetch UI elements
            const $widgetPreset = $('.ladb-widget-preset', that.$element);
            const $inputThickness = $('#ladb_input_thickness', that.$element);
            const $selectMeasureType = $('#ladb_select_measure_type', that.$element);
            const $selectAxes = $('#ladb_select_axes', that.$element);
            const $selectConstruction = $('#ladb_select_construction', that.$element);
            const $selectMeasureReversed = $('#ladb_select_measure_reversed', that.$element);
            const $selectReduceEnvelope = $('#ladb_select_reduce_envelope', that.$element);
            const $selectAskName = $('#ladb_select_ask_name', that.$element);
            const $btnValidate = $('#ladb_btn_validate', that.$element);

            const fnFetchOptions = function (options) {
                options.thickness = $inputThickness.val();
                options.measure_type = $selectMeasureType.val();
                options.axes = $selectAxes.val();
                options.construction = $selectConstruction.val() === '1';
                options.measure_reversed = $selectMeasureReversed.val() === '1';
                options.reduce_envelope = $selectReduceEnvelope.val() === '1';
                options.ask_name = $selectAskName.val() === '1';
            };
            const fnFillInputs = function (options) {
                $inputThickness.val(options.thickness);
                $selectMeasureType.selectpicker('val', options.measure_type);
                $selectAxes.selectpicker('val', options.axes);
                $selectConstruction.selectpicker('val', options.construction ? '1' : '0');
                $selectMeasureReversed.selectpicker('val', options.measure_reversed ? '1' : '0');
                $selectReduceEnvelope.selectpicker('val', options.reduce_envelope ? '1' : '0');
                $selectAskName.selectpicker('val', options.ask_name ? '1' : '0');
            };

            $widgetPreset.ladbWidgetPreset({
                dialog: that.dialog,
                dictionary: dictionary,
                section: section,
                fnFetchOptions: fnFetchOptions,
                fnFillInputs: fnFillInputs
            });
            $inputThickness.ladbTextinputDimension();
            $selectMeasureType.selectpicker(SELECT_PICKER_MODAL_OPTIONS);
            $selectAxes.selectpicker(SELECT_PICKER_MODAL_OPTIONS);
            $selectConstruction.selectpicker(SELECT_PICKER_MODAL_OPTIONS);
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
            const options = $.extend({}, LadbModalSmartBuildToolAction0.DEFAULTS, $this.data(), typeof option === 'object' && option);

            if (!data) {
                if (undefined === options.dialog) {
                    throw 'dialog option is mandatory.';
                }
                $this.data('ladb.modal.plugin', (data = new LadbModalSmartBuildToolAction0(this, options, options.dialog)));
            }
            if (typeof option === 'string') {
                data[option].apply(data, Array.isArray(params) ? params : [ params ])
            } else {
                data.init();
            }
        })
    }

    const old = $.fn.ladbModalSmartBuildToolAction0;

    $.fn.ladbModalSmartBuildToolAction0 = Plugin;
    $.fn.ladbModalSmartBuildToolAction0.Constructor = LadbModalSmartBuildToolAction0;


    // NO CONFLICT
    // =================

    $.fn.ladbModalSmartBuildToolAction0.noConflict = function () {
        $.fn.ladbModalSmartBuildToolAction0 = old;
        return this;
    }

}(jQuery);
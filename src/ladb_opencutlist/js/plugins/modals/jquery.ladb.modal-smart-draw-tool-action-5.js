+function ($) {
    'use strict';

    // CLASS DEFINITION
    // ======================

    const LadbModalSmartDrawToolAction5 = function (element, options, dialog) {
        LadbAbstractModal.call(this, element, options, dialog);

    };
    LadbModalSmartDrawToolAction5.prototype = Object.create(LadbAbstractModal.prototype);

    LadbModalSmartDrawToolAction5.DEFAULTS = {};

    // Init ///

    LadbModalSmartDrawToolAction5.prototype.init = function () {
        LadbAbstractModal.prototype.init.call(this);

        const that = this;

        const dictionary = 'tool_smart_draw_options';
        const section = 'action_5';

        // Retrieve options
        rubyCallCommand('core_get_global_preset', { dictionary: dictionary, section: section }, function (response) {

            const options = response.preset;

            // Fetch UI elements
            const $widgetPreset = $('.ladb-widget-preset', that.$element);
            const $inputThickness = $('#ladb_input_thickness', that.$element);
            const $inputBackPanelDepth = $('#ladb_input_back_panel_depth', that.$element);
            const $inputBackPanelSetback = $('#ladb_input_back_panel_setback', that.$element);
            const $selectAxes = $('#ladb_select_axes', that.$element);
            const $selectConstrution = $('#ladb_select_construction', that.$element);
            const $selectMeasureReversed = $('#ladb_select_measure_reversed', that.$element);
            const $selectReduceEnvelope = $('#ladb_select_reduce_envelope', that.$element);
            const $selectAskName = $('#ladb_select_ask_name', that.$element);
            const $inputLayerName = $('#ladb_input_layer_name', that.$element);
            const $inputMachiningMaterialName = $('#ladb_input_machining_material_name', that.$element);
            const $inputMachiningLayerName = $('#ladb_input_machining_layer_name', that.$element);
            const $btnValidate = $('#ladb_btn_validate', that.$element);

            const fnFetchOptions = function (options) {
                options.thickness = $inputThickness.val();
                options.back_panel_depth = $inputBackPanelDepth.val();
                options.back_panel_setback = $inputBackPanelSetback.val();
                options.axes = $selectAxes.val();
                options.construction = $selectConstrution.val() === '1';
                options.measure_reversed = $selectMeasureReversed.val() === '1';
                options.reduce_envelope = $selectReduceEnvelope.val() === '1';
                options.ask_name = $selectAskName.val() === '1';
                options.layer_name = $inputLayerName.val();
                options.machining_material_name = $inputMachiningMaterialName.val();
                options.machining_layer_name = $inputMachiningLayerName.val();
            };
            const fnFillInputs = function (options) {
                $inputThickness.val(options.thickness);
                $inputBackPanelDepth.val(options.back_panel_depth);
                $inputBackPanelSetback.val(options.back_panel_setback);
                $selectAxes.selectpicker('val', options.axes);
                $selectConstrution.selectpicker('val', options.construction ? '1' : '0');
                $selectMeasureReversed.selectpicker('val', options.measure_reversed ? '1' : '0');
                $selectReduceEnvelope.selectpicker('val', options.reduce_envelope ? '1' : '0');
                $selectAskName.selectpicker('val', options.ask_name ? '1' : '0');
                $inputLayerName.val(options.layer_name);
                $inputMachiningMaterialName.val(options.machining_material_name);
                $inputMachiningLayerName.val(options.machining_layer_name);
            };

            $widgetPreset.ladbWidgetPreset({
                dialog: that.dialog,
                dictionary: 'tool_smart_draw_options',
                section: 'action_5',
                fnFetchOptions: fnFetchOptions,
                fnFillInputs: fnFillInputs
            });
            $inputThickness.ladbTextinputDimension();
            $inputBackPanelDepth.ladbTextinputDimension();
            $inputBackPanelSetback.ladbTextinputDimension();
            $selectAxes.selectpicker(SELECT_PICKER_MODAL_OPTIONS);
            $selectConstrution.selectpicker(SELECT_PICKER_MODAL_OPTIONS);
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
                } else if (that.options.focused_field.option === 'back_panel_depth') {
                    $inputBackPanelDepth.focus();
                    $inputBackPanelDepth.select();
                } else if (that.options.focused_field.option === 'back_panel_setback') {
                    $inputBackPanelSetback.focus();
                    $inputBackPanelSetback.select();
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
            const options = $.extend({}, LadbModalSmartDrawToolAction5.DEFAULTS, $this.data(), typeof option === 'object' && option);

            if (!data) {
                if (undefined === options.dialog) {
                    throw 'dialog option is mandatory.';
                }
                $this.data('ladb.modal.plugin', (data = new LadbModalSmartDrawToolAction5(this, options, options.dialog)));
            }
            if (typeof option === 'string') {
                data[option].apply(data, Array.isArray(params) ? params : [ params ])
            } else {
                data.init();
            }
        })
    }

    const old = $.fn.ladbModalSmartDrawToolAction5;

    $.fn.ladbModalSmartDrawToolAction5 = Plugin;
    $.fn.ladbModalSmartDrawToolAction5.Constructor = LadbModalSmartDrawToolAction5;


    // NO CONFLICT
    // =================

    $.fn.ladbModalSmartDrawToolAction5.noConflict = function () {
        $.fn.ladbModalSmartDrawToolAction5 = old;
        return this;
    }

}(jQuery);

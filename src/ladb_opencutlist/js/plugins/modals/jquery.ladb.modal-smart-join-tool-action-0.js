+function ($) {
    'use strict';

    // CLASS DEFINITION
    // ======================

    const LadbModalSmartJoinToolAction0 = function (element, options, dialog) {
        LadbAbstractModal.call(this, element, options, dialog);

    };
    LadbModalSmartJoinToolAction0.prototype = Object.create(LadbAbstractModal.prototype);

    LadbModalSmartJoinToolAction0.DEFAULTS = {};

    // Init ///

    LadbModalSmartJoinToolAction0.prototype.init = function () {
        LadbAbstractModal.prototype.init.call(this);

        const that = this;

        const dictionary = 'tool_smart_join_options';
        const section = 'action_0';

        // Retrieve options
        rubyCallCommand('core_get_global_preset', { dictionary: dictionary, section: section }, function (response) {

            const options = response.preset;

            // Fetch UI elements
            const $tabs = $('a[data-toggle="tab"]', that.$element);
            const $widgetPreset = $('.ladb-widget-preset', that.$element);
            const $inputStartOffset = $('#ladb_input_start_offset', that.$element);
            const $inputEndOffset = $('#ladb_input_end_offset', that.$element);
            const $inputMinSpacing = $('#ladb_input_min_spacing', that.$element);
            const $inputMaxSpacing = $('#ladb_input_max_spacing', that.$element);
            const $inputHeightDistance = $('#ladb_input_height_distance', that.$element);
            const $inputHardwareA = $('#ladb_input_hardware_a', that.$element);
            const $inputHardwareB = $('#ladb_input_hardware_b', that.$element);
            const $inputMachiningA = $('#ladb_input_machining_a', that.$element);
            const $inputMachiningB = $('#ladb_input_machining_b', that.$element);
            const $inputHardwareMaterialName = $('#ladb_input_hardware_material_name', that.$element);
            const $inputMachiningMaterialName = $('#ladb_input_machining_material_name', that.$element);
            const $btnValidate = $('#ladb_btn_validate', that.$element);

            const fnFetchOptions = function (options) {
                options.start_offset = $inputStartOffset.val();
                options.end_offset = $inputEndOffset.val();
                options.min_spacing = $inputMinSpacing.val();
                options.max_spacing = $inputMaxSpacing.val();
                options.height_distance = $inputHeightDistance.val();
                options.hardware_a = $inputHardwareA.val();
                options.hardware_b = $inputHardwareB.val();
                options.machining_a = $inputMachiningA.val();
                options.machining_b = $inputMachiningB.val();
                options.hardware_material_name = $inputHardwareMaterialName.val();
                options.machining_material_name = $inputMachiningMaterialName.val();
            };
            const fnFillInputs = function (options) {
                $inputStartOffset.val(options.start_offset);
                $inputEndOffset.val(options.end_offset);
                $inputMinSpacing.val(options.min_spacing);
                $inputMaxSpacing.val(options.max_spacing);
                $inputHeightDistance.val(options.height_distance);
                $inputHardwareA.val(options.hardware_a);
                $inputHardwareB.val(options.hardware_b);
                $inputMachiningA.val(options.machining_a);
                $inputMachiningB.val(options.machining_b);
                $inputHardwareMaterialName.val(options.hardware_material_name);
                $inputMachiningMaterialName.val(options.machining_material_name);
            };

            $widgetPreset.ladbWidgetPreset({
                dialog: that.dialog,
                dictionary: dictionary,
                section: section,
                fnFetchOptions: fnFetchOptions,
                fnFillInputs: fnFillInputs
            });
            $inputStartOffset.ladbTextinputDimension();
            $inputEndOffset.ladbTextinputDimension();
            $inputMinSpacing.ladbTextinputDimension();
            $inputMaxSpacing.ladbTextinputDimension();
            $inputHeightDistance.ladbTextinputDimension();
            $inputHardwareA.ladbTextinputFile();
            $inputHardwareB.ladbTextinputFile();
            $inputMachiningA.ladbTextinputFile();
            $inputMachiningB.ladbTextinputFile();
            $inputHardwareMaterialName.ladbTextinputFile();
            $inputMachiningMaterialName.ladbTextinputFile();

            fnFillInputs(options);

            // Bind buttons
            $btnValidate.on('click', function () {

                // Fetch options
                fnFetchOptions(options);

                // Store options
                rubyCallCommand('core_set_global_preset', { dictionary: dictionary, values: options, section: section, fire_event: true });

                // Hide modal
                that.dialog.hide();

            });

            // Bond tab
            $tabs.on('shown.bs.tab', function (e) {
                if ($(e.target).attr('href') === '#tab_geometries') {
                    $inputHardwareA.ladbTextinputFile('scrollToTheEnd');
                    $inputHardwareB.ladbTextinputFile('scrollToTheEnd');
                    $inputMachiningA.ladbTextinputFile('scrollToTheEnd');
                    $inputMachiningB.ladbTextinputFile('scrollToTheEnd');
                    $inputHardwareMaterialName.ladbTextinputFile('scrollToTheEnd');
                    $inputMachiningMaterialName.ladbTextinputFile('scrollToTheEnd');
                }
            })

            // Focus
            if (that.options.focused_field) {
                if (that.options.focused_field.option === 'start_offset') {
                    $inputStartOffset.focus();
                    $inputStartOffset.select();
                }
                else if (that.options.focused_field.option === 'end_offset') {
                    $inputEndOffset.focus();
                    $inputEndOffset.select();
                }
                else if (that.options.focused_field.option === 'min_spacing') {
                    $inputMinSpacing.focus();
                    $inputMinSpacing.select();
                }
                else if (that.options.focused_field.option === 'max_spacing') {
                    $inputMaxSpacing.focus();
                    $inputMaxSpacing.select();
                }
                else if (that.options.focused_field.option === 'height_distance') {
                    $inputHeightDistance.focus();
                    $inputHeightDistance.select();
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
            const options = $.extend({}, LadbModalSmartJoinToolAction0.DEFAULTS, $this.data(), typeof option === 'object' && option);

            if (!data) {
                if (undefined === options.dialog) {
                    throw 'dialog option is mandatory.';
                }
                $this.data('ladb.modal.plugin', (data = new LadbModalSmartJoinToolAction0(this, options, options.dialog)));
            }
            if (typeof option === 'string') {
                data[option].apply(data, Array.isArray(params) ? params : [ params ])
            } else {
                data.init();
            }
        })
    }

    const old = $.fn.ladbModalSmartJoinToolAction0;

    $.fn.ladbModalSmartJoinToolAction0 = Plugin;
    $.fn.ladbModalSmartJoinToolAction0.Constructor = LadbModalSmartJoinToolAction0;


    // NO CONFLICT
    // =================

    $.fn.ladbModalSmartJoinToolAction0.noConflict = function () {
        $.fn.ladbModalSmartJoinToolAction0 = old;
        return this;
    }

}(jQuery);
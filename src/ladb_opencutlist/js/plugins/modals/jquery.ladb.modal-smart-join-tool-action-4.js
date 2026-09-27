+function ($) {
    'use strict';

    // CLASS DEFINITION
    // ======================

    const LadbModalSmartJoinToolAction4 = function (element, options, dialog) {
        LadbAbstractModal.call(this, element, options, dialog);

    };
    LadbModalSmartJoinToolAction4.prototype = Object.create(LadbAbstractModal.prototype);

    LadbModalSmartJoinToolAction4.DEFAULTS = {};

    // Init ///

    LadbModalSmartJoinToolAction4.prototype.init = function () {
        LadbAbstractModal.prototype.init.call(this);

        const that = this;

        const dictionary = 'tool_smart_join_options';
        const section = 'action_4';

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
            const $inputHardwareMaterialName = $('#ladb_input_hardware_material_name', that.$element);
            const $inputMachiningMaterialName = $('#ladb_input_machining_material_name', that.$element);
            const $inputHardwareLayerName = $('#ladb_input_hardware_layer_name', that.$element);
            const $inputMachiningLayerName = $('#ladb_input_machining_layer_name', that.$element);
            const $btnValidate = $('#ladb_btn_validate', that.$element);

            const fnFetchOptions = function (options) {
                options.start_offset = $inputStartOffset.val();
                options.end_offset = $inputEndOffset.val();
                options.min_spacing = $inputMinSpacing.val();
                options.max_spacing = $inputMaxSpacing.val();
                options.hardware_material_name = $inputHardwareMaterialName.val();
                options.machining_material_name = $inputMachiningMaterialName.val();
                options.hardware_layer_name = $inputHardwareLayerName.val();
                options.machining_layer_name = $inputMachiningLayerName.val();
            };
            const fnFillInputs = function (options) {
                $inputStartOffset.val(options.start_offset);
                $inputEndOffset.val(options.end_offset);
                $inputMinSpacing.val(options.min_spacing);
                $inputMaxSpacing.val(options.max_spacing);
                $inputHardwareMaterialName.ladbTextinputFile('val', options.hardware_material_name ? options.hardware_material_name : '');
                $inputMachiningMaterialName.ladbTextinputFile('val', options.machining_material_name ? options.machining_material_name : '');
                $inputHardwareLayerName.val(options.hardware_layer_name);
                $inputMachiningLayerName.val(options.machining_layer_name);
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
            $inputHardwareMaterialName.ladbTextinputFile({ library: true });
            $inputMachiningMaterialName.ladbTextinputFile({ library: true });
            $inputHardwareLayerName.ladbTextinputText();
            $inputMachiningLayerName.ladbTextinputText();

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
            }

        });

    };

    // PLUGIN DEFINITION
    // =======================

    function Plugin(option, params) {
        return this.each(function () {
            const $this = $(this);
            let data = $this.data('ladb.modal.plugin');
            const options = $.extend({}, LadbModalSmartJoinToolAction4.DEFAULTS, $this.data(), typeof option === 'object' && option);

            if (!data) {
                if (undefined === options.dialog) {
                    throw 'dialog option is mandatory.';
                }
                $this.data('ladb.modal.plugin', (data = new LadbModalSmartJoinToolAction4(this, options, options.dialog)));
            }
            if (typeof option === 'string') {
                data[option].apply(data, Array.isArray(params) ? params : [ params ])
            } else {
                data.init();
            }
        })
    }

    const old = $.fn.ladbModalSmartJoinToolAction4;

    $.fn.ladbModalSmartJoinToolAction4 = Plugin;
    $.fn.ladbModalSmartJoinToolAction4.Constructor = LadbModalSmartJoinToolAction4;


    // NO CONFLICT
    // =================

    $.fn.ladbModalSmartJoinToolAction4.noConflict = function () {
        $.fn.ladbModalSmartJoinToolAction4 = old;
        return this;
    }

}(jQuery);
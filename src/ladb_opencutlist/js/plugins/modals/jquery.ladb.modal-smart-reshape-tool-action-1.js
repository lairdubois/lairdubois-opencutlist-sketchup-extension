+function ($) {
    'use strict';

    // CLASS DEFINITION
    // ======================

    const LadbModalSmartReshapeToolAction1 = function (element, options, dialog) {
        LadbAbstractModal.call(this, element, options, dialog);

    };
    LadbModalSmartReshapeToolAction1.prototype = Object.create(LadbAbstractModal.prototype);

    LadbModalSmartReshapeToolAction1.DEFAULTS = {};

    // Init ///

    LadbModalSmartReshapeToolAction1.prototype.init = function () {
        LadbAbstractModal.prototype.init.call(this);

        const that = this;

        const dictonary = 'tool_smart_reshape_options';
        const section = 'action_1';

        // Retrieve options
        rubyCallCommand('core_get_global_preset', { dictionary: dictonary, section: section }, function (response) {

            const options = response.preset;

            // Fetch UI elements
            const $widgetPreset = $('.ladb-widget-preset', that.$element);
            const $inputThickness = $('#ladb_input_thickness', that.$element);
            const $selectPanelingDirection = $('#ladb_select_paneling_direction', that.$element);
            const $selectPanelingJointType = $('#ladb_select_paneling_joint_type', that.$element);
            const $btnValidate = $('#ladb_btn_validate', that.$element);

            const fnFetchOptions = function (options) {
                options.thickness = $inputThickness.val();
                options.paneling_direction = $selectPanelingDirection.val();
                options.paneling_joint_type = $selectPanelingJointType.val();
            };
            const fnFillInputs = function (options) {
                $inputThickness.val(options.thickness);
                $selectPanelingDirection.selectpicker('val', options.paneling_direction);
                $selectPanelingJointType.selectpicker('val', options.paneling_joint_type);
            };

            $widgetPreset.ladbWidgetPreset({
                dialog: that.dialog,
                dictionary: 'tool_smart_reshape_options',
                section: 'action_1',
                fnFetchOptions: fnFetchOptions,
                fnFillInputs: fnFillInputs
            });
            $inputThickness.ladbTextinputDimension();
            $selectPanelingDirection.selectpicker(SELECT_PICKER_OPTIONS);
            $selectPanelingJointType.selectpicker(SELECT_PICKER_OPTIONS);

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
            const options = $.extend({}, LadbModalSmartReshapeToolAction1.DEFAULTS, $this.data(), typeof option === 'object' && option);

            if (!data) {
                if (undefined === options.dialog) {
                    throw 'dialog option is mandatory.';
                }
                $this.data('ladb.modal.plugin', (data = new LadbModalSmartReshapeToolAction1(this, options, options.dialog)));
            }
            if (typeof option === 'string') {
                data[option].apply(data, Array.isArray(params) ? params : [ params ])
            } else {
                data.init();
            }
        })
    }

    const old = $.fn.ladbModalSmartReshapeToolAction1;

    $.fn.ladbModalSmartReshapeToolAction1 = Plugin;
    $.fn.ladbModalSmartReshapeToolAction1.Constructor = LadbModalSmartReshapeToolAction1;


    // NO CONFLICT
    // =================

    $.fn.ladbModalSmartReshapeToolAction1.noConflict = function () {
        $.fn.ladbModalSmartReshapeToolAction1 = old;
        return this;
    }

}(jQuery);
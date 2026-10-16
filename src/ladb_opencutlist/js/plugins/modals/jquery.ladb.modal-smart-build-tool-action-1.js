+function ($) {
    'use strict';

    // CLASS DEFINITION
    // ======================

    const LadbModalSmartBuildToolAction1 = function (element, options, dialog) {
        LadbAbstractModal.call(this, element, options, dialog);

    };
    LadbModalSmartBuildToolAction1.prototype = Object.create(LadbAbstractModal.prototype);

    LadbModalSmartBuildToolAction1.DEFAULTS = {};

    // Init ///

    LadbModalSmartBuildToolAction1.prototype.init = function () {
        LadbAbstractModal.prototype.init.call(this);

        const that = this;

        const dictionary = 'tool_smart_build_options';
        const section = 'action_1';

        // Retrieve options
        rubyCallCommand('core_get_global_preset', { dictionary: dictionary, section: section }, function (response) {

            const options = response.preset;

            // Fetch UI elements
            const $widgetPreset = $('.ladb-widget-preset', that.$element);
            const $inputThickness = $('#ladb_input_thickness', that.$element);
            const $btnValidate = $('#ladb_btn_validate', that.$element);

            const fnFetchOptions = function (options) {
                options.thickness = $inputThickness.val();
            };
            const fnFillInputs = function (options) {
                $inputThickness.val(options.thickness);
            };

            $widgetPreset.ladbWidgetPreset({
                dialog: that.dialog,
                dictionary: dictionary,
                section: section,
                fnFetchOptions: fnFetchOptions,
                fnFillInputs: fnFillInputs
            });
            $inputThickness.ladbTextinputDimension();

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
            const options = $.extend({}, LadbModalSmartBuildToolAction1.DEFAULTS, $this.data(), typeof option === 'object' && option);

            if (!data) {
                if (undefined === options.dialog) {
                    throw 'dialog option is mandatory.';
                }
                $this.data('ladb.modal.plugin', (data = new LadbModalSmartBuildToolAction1(this, options, options.dialog)));
            }
            if (typeof option === 'string') {
                data[option].apply(data, Array.isArray(params) ? params : [ params ])
            } else {
                data.init();
            }
        })
    }

    const old = $.fn.ladbModalSmartBuildToolAction1;

    $.fn.ladbModalSmartBuildToolAction1 = Plugin;
    $.fn.ladbModalSmartBuildToolAction1.Constructor = LadbModalSmartBuildToolAction1;


    // NO CONFLICT
    // =================

    $.fn.ladbModalSmartBuildToolAction1.noConflict = function () {
        $.fn.ladbModalSmartBuildToolAction1 = old;
        return this;
    }

}(jQuery);
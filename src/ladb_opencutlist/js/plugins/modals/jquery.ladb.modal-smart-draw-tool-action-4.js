+function ($) {
    'use strict';

    // CLASS DEFINITION
    // ======================

    const LadbModalSmartDrawToolAction4 = function (element, options, dialog) {
        LadbAbstractModal.call(this, element, options, dialog);

    };
    LadbModalSmartDrawToolAction4.prototype = Object.create(LadbAbstractModal.prototype);

    LadbModalSmartDrawToolAction4.DEFAULTS = {};

    // Init ///

    LadbModalSmartDrawToolAction4.prototype.init = function () {
        LadbAbstractModal.prototype.init.call(this);

        const that = this;

        const dictionary = 'tool_smart_draw_options';
        const section = 'action_4';

        // Retrieve options
        rubyCallCommand('core_get_global_preset', { dictionary: dictionary, section: section }, function (response) {

            const options = response.preset;

            // Fetch UI elements
            const $widgetPreset = $('.ladb-widget-preset', that.$element);
            const $inputFacadeOffset = $('#ladb_input_facade_offset', that.$element);
            const $inputThickness = $('#ladb_input_thickness', that.$element);
            const $selectConstrution = $('#ladb_select_construction', that.$element);
            const $selectAskName = $('#ladb_select_ask_name', that.$element);
            const $btnValidate = $('#ladb_btn_validate', that.$element);

            const fnFetchOptions = function (options) {
                options.facade_offset = $inputFacadeOffset.val();
                options.thickness = $inputThickness.val();
                options.construction = $selectConstrution.val() === '1';
                options.ask_name = $selectAskName.val() === '1';
            };
            const fnFillInputs = function (options) {
                $inputThickness.val(options.thickness);
                $inputFacadeOffset.val(options.facade_offset);
                $selectConstrution.selectpicker('val', options.construction ? '1' : '0');
                $selectAskName.selectpicker('val', options.ask_name ? '1' : '0');
            };

            $widgetPreset.ladbWidgetPreset({
                dialog: that.dialog,
                dictionary: 'tool_smart_draw_options',
                section: 'action_4',
                fnFetchOptions: fnFetchOptions,
                fnFillInputs: fnFillInputs
            });
            $inputThickness.ladbTextinputDimension();
            $inputFacadeOffset.ladbTextinputDimension();
            $selectConstrution.selectpicker(SELECT_PICKER_MODAL_OPTIONS);
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
                } else if (that.options.focused_field.option === 'facade_offset') {
                    $inputFacadeOffset.focus();
                    $inputFacadeOffset.select();
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
            const options = $.extend({}, LadbModalSmartDrawToolAction4.DEFAULTS, $this.data(), typeof option === 'object' && option);

            if (!data) {
                if (undefined === options.dialog) {
                    throw 'dialog option is mandatory.';
                }
                $this.data('ladb.modal.plugin', (data = new LadbModalSmartDrawToolAction4(this, options, options.dialog)));
            }
            if (typeof option === 'string') {
                data[option].apply(data, Array.isArray(params) ? params : [ params ])
            } else {
                data.init();
            }
        })
    }

    const old = $.fn.ladbModalSmartDrawToolAction4;

    $.fn.ladbModalSmartDrawToolAction4 = Plugin;
    $.fn.ladbModalSmartDrawToolAction4.Constructor = LadbModalSmartDrawToolAction4;


    // NO CONFLICT
    // =================

    $.fn.ladbModalSmartDrawToolAction4.noConflict = function () {
        $.fn.ladbModalSmartDrawToolAction4 = old;
        return this;
    }

}(jQuery);
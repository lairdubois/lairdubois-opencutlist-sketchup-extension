+function ($) {
    'use strict';

    // CLASS DEFINITION
    // ======================

    const LadbModalSmartDrawToolAction3 = function (element, options, dialog) {
        LadbAbstractModal.call(this, element, options, dialog);

    };
    LadbModalSmartDrawToolAction3.prototype = Object.create(LadbAbstractModal.prototype);

    LadbModalSmartDrawToolAction3.DEFAULTS = {};

    // Init ///

    LadbModalSmartDrawToolAction3.prototype.init = function () {
        LadbAbstractModal.prototype.init.call(this);

        const that = this;

        const dictionary = 'tool_smart_draw_options';
        const section = 'action_3';

        // Retrieve options
        rubyCallCommand('core_get_global_preset', { dictionary: dictionary, section: section }, function (response) {

            const options = response.preset;

            // Fetch UI elements
            const $widgetPreset = $('.ladb-widget-preset', that.$element);
            const $inputMaxOpeningPlanes = $('#ladb_input_max_opening_planes', that.$element);
            const $selectConstrution = $('#ladb_select_construction', that.$element);
            const $selectDrawIn = $('#ladb_select_draw_in', that.$element);
            const $selectAskName = $('#ladb_select_ask_name', that.$element);
            const $btnValidate = $('#ladb_btn_validate', that.$element);

            const fnFetchOptions = function (options) {
                options.max_opening_planes = $inputMaxOpeningPlanes.val();
                options.construction = $selectConstrution.val() === '1';
                options.draw_in = $selectDrawIn.val() === '1';
                options.ask_name = $selectAskName.val() === '1';
            };
            const fnFillInputs = function (options) {
                $inputMaxOpeningPlanes.val(options.max_opening_planes);
                $selectConstrution.selectpicker('val', options.construction ? '1' : '0');
                $selectDrawIn.selectpicker('val', options.draw_in ? '1' : '0');
                $selectAskName.selectpicker('val', options.ask_name ? '1' : '0');
            };

            $widgetPreset.ladbWidgetPreset({
                dialog: that.dialog,
                dictionary: 'tool_smart_draw_options',
                section: 'action_3',
                fnFetchOptions: fnFetchOptions,
                fnFillInputs: fnFillInputs
            });
            $inputMaxOpeningPlanes.ladbTextinputDimension();
            $selectConstrution.selectpicker(SELECT_PICKER_MODAL_OPTIONS);
            $selectDrawIn.selectpicker(SELECT_PICKER_MODAL_OPTIONS);
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
                if (that.options.focused_field.option === 'max_opening_planes') {
                    $inputMaxOpeningPlanes.focus();
                    $inputMaxOpeningPlanes.select();
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
            const options = $.extend({}, LadbModalSmartDrawToolAction3.DEFAULTS, $this.data(), typeof option === 'object' && option);

            if (!data) {
                if (undefined === options.dialog) {
                    throw 'dialog option is mandatory.';
                }
                $this.data('ladb.modal.plugin', (data = new LadbModalSmartDrawToolAction3(this, options, options.dialog)));
            }
            if (typeof option === 'string') {
                data[option].apply(data, Array.isArray(params) ? params : [ params ])
            } else {
                data.init();
            }
        })
    }

    const old = $.fn.ladbModalSmartDrawToolAction3;

    $.fn.ladbModalSmartDrawToolAction3 = Plugin;
    $.fn.ladbModalSmartDrawToolAction3.Constructor = LadbModalSmartDrawToolAction3;


    // NO CONFLICT
    // =================

    $.fn.ladbModalSmartDrawToolAction3.noConflict = function () {
        $.fn.ladbModalSmartDrawToolAction3 = old;
        return this;
    }

}(jQuery);
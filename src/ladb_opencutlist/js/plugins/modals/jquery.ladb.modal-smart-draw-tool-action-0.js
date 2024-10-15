+function ($) {
    'use strict';

    // CLASS DEFINITION
    // ======================

    var LadbModalSmartDrawToolAction0 = function (element, options, dialog) {
        LadbAbstractModal.call(this, element, options, dialog);

    };
    LadbModalSmartDrawToolAction0.prototype = Object.create(LadbAbstractModal.prototype);

    LadbModalSmartDrawToolAction0.DEFAULTS = {};

    // Init ///

    LadbModalSmartDrawToolAction0.prototype.init = function () {
        LadbAbstractModal.prototype.init.call(this);

        var that = this;

        var dictonary = 'tool_smart_draw_options';
        var section = 'action_0';

        // Retrieve options
        rubyCallCommand('core_get_global_preset', { dictionary: dictonary, section: section }, function (response) {

            var options = response.preset;

            // Fetch UI elements
            var $widgetPreset = $('.ladb-widget-preset', that.$element);
            var $inputSectionOffset = $('#ladb_input_section_offset', that.$element);
            var $selectConstrution = $('#ladb_select_construction', that.$element);
            var $selectRectangleCentered = $('#ladb_select_rectangle_centered', that.$element);
            var $selectBoxCentered = $('#ladb_select_box_centered', that.$element);
            var $btnValidate = $('#ladb_btn_validate', that.$element);

            var fnFetchOptions = function (options) {
                options.section_offset = $inputSectionOffset.val();
                options.construction = $selectConstrution.val() === '1';
                options.rectangle_centered = $selectRectangleCentered.val() === '1';
                options.box_centered = $selectBoxCentered.val() === '1';
            };
            var fnFillInputs = function (options) {
                $inputSectionOffset.val(options.section_offset);
                $selectConstrution.selectpicker('val', options.construction ? '1' : '0');
                $selectRectangleCentered.selectpicker('val', options.rectangle_centered ? '1' : '0');
                $selectBoxCentered.selectpicker('val', options.box_centered ? '1' : '0');
            };

            $widgetPreset.ladbWidgetPreset({
                dialog: that.dialog,
                dictionary: 'tool_smart_draw_options',
                section: 'action_0',
                fnFetchOptions: fnFetchOptions,
                fnFillInputs: fnFillInputs
            });
            $inputSectionOffset.ladbTextinputDimension();
            $selectConstrution.selectpicker(SELECT_PICKER_OPTIONS);
            $selectRectangleCentered.selectpicker(SELECT_PICKER_OPTIONS);
            $selectBoxCentered.selectpicker(SELECT_PICKER_OPTIONS);

            fnFillInputs(options);

            // Bind buttons
            $btnValidate.on('click', function () {

                // Fetch options
                fnFetchOptions(options);

                // Store options
                rubyCallCommand('core_set_global_preset', { dictionary: dictonary, values: options, section: section, fire_event: true });

                // Hide modal
                that.dialog.hide();

            });

        });

    };

    // PLUGIN DEFINITION
    // =======================

    function Plugin(option, params) {
        return this.each(function () {
            var $this = $(this);
            var data = $this.data('ladb.tab.plugin');
            var options = $.extend({}, LadbModalSmartDrawToolAction0.DEFAULTS, $this.data(), typeof option === 'object' && option);

            if (!data) {
                if (undefined === options.dialog) {
                    throw 'dialog option is mandatory.';
                }
                $this.data('ladb.tab.plugin', (data = new LadbModalSmartDrawToolAction0(this, options, options.dialog)));
            }
            if (typeof option === 'string') {
                data[option].apply(data, Array.isArray(params) ? params : [ params ])
            } else {
                data.init();
            }
        })
    }

    var old = $.fn.ladbModalSmartDrawToolAction0;

    $.fn.ladbModalSmartDrawToolAction0 = Plugin;
    $.fn.ladbModalSmartDrawToolAction0.Constructor = LadbModalSmartDrawToolAction0;


    // NO CONFLICT
    // =================

    $.fn.ladbModalSmartDrawToolAction0.noConflict = function () {
        $.fn.ladbModalSmartDrawToolAction0 = old;
        return this;
    }

}(jQuery);
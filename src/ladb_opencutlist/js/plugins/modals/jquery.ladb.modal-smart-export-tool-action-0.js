+function ($) {
    'use strict';

    // CLASS DEFINITION
    // ======================

    const LadbModalSmartExportToolAction0 = function (element, options, dialog) {
        LadbAbstractModal.call(this, element, options, dialog);

    };
    LadbModalSmartExportToolAction0.prototype = Object.create(LadbAbstractModal.prototype);

    LadbModalSmartExportToolAction0.DEFAULTS = {};

    // Init ///

    LadbModalSmartExportToolAction0.prototype.init = function () {
        LadbAbstractModal.prototype.init.call(this);

        const that = this;

        const dictonary = 'tool_smart_export_options';
        const section = 'action_0';

        // Retrieve options
        rubyCallCommand('core_get_global_preset', { dictionary: dictonary, section: section }, function (response) {

            const options = response.preset;

            // Fetch UI elements
            const $widgetPreset = $('.ladb-widget-preset', that.$element);
            const $selectFileFormat = $('#ladb_select_file_format', that.$element);
            const $selectUnit = $('#ladb_select_unit', that.$element);
            const $selectAnchor = $('#ladb_select_anchor', that.$element);
            const $selectSwitchYZ = $('#ladb_select_switch_yz', that.$element);
            const $btnValidate = $('#ladb_btn_validate', that.$element);

            const fnFetchOptions = function (options) {
                options.file_format = $selectFileFormat.val();
                options.unit = parseInt($selectUnit.val());
                options.anchor = $selectAnchor.val() === '1';
                options.switch_yz = $selectSwitchYZ.val() === '1';
            };
            const fnFillInputs = function (options) {
                $selectFileFormat.selectpicker('val', options.file_format);
                $selectUnit.selectpicker('val', options.unit);
                $selectAnchor.selectpicker('val', options.anchor ? '1' : '0');
                $selectSwitchYZ.selectpicker('val', options.switch_yz ? '1' : '0');
            };

            $widgetPreset.ladbWidgetPreset({
                dialog: that.dialog,
                dictionary: 'tool_smart_export_options',
                section: 'action_0',
                fnFetchOptions: fnFetchOptions,
                fnFillInputs: fnFillInputs
            });
            $selectFileFormat.selectpicker(SELECT_PICKER_OPTIONS);
            $selectUnit.selectpicker(SELECT_PICKER_OPTIONS);
            $selectAnchor.selectpicker(SELECT_PICKER_OPTIONS);
            $selectSwitchYZ.selectpicker(SELECT_PICKER_OPTIONS);

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
            const $this = $(this);
            let data = $this.data('ladb.tab.plugin');
            const options = $.extend({}, LadbModalSmartExportToolAction0.DEFAULTS, $this.data(), typeof option === 'object' && option);

            if (!data) {
                if (undefined === options.dialog) {
                    throw 'dialog option is mandatory.';
                }
                $this.data('ladb.tab.plugin', (data = new LadbModalSmartExportToolAction0(this, options, options.dialog)));
            }
            if (typeof option === 'string') {
                data[option].apply(data, Array.isArray(params) ? params : [ params ])
            } else {
                data.init();
            }
        })
    }

    const old = $.fn.ladbModalSmartExportToolAction0;

    $.fn.ladbModalSmartExportToolAction0 = Plugin;
    $.fn.ladbModalSmartExportToolAction0.Constructor = LadbModalSmartExportToolAction0;


    // NO CONFLICT
    // =================

    $.fn.ladbModalSmartExportToolAction0.noConflict = function () {
        $.fn.ladbModalSmartExportToolAction0 = old;
        return this;
    }

}(jQuery);
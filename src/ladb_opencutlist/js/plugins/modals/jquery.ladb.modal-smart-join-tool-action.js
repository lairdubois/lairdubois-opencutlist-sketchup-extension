'use strict';

// The options dialog of a SmartJoin add action. The options a hardware can
// give the default of are read and written through the Ruby
// HardwareOptionsDef : an input shows the value in effect, and a value
// the picked hardware defines is stored as the user's override for it -
// the others as the action's base values.
function LadbAbstractModalSmartJoinToolAction(element, options, dialog, section) {
    LadbAbstractModal.call(this, element, options, dialog);

    this.section = section;

}
LadbAbstractModalSmartJoinToolAction.prototype = Object.create(LadbAbstractModal.prototype);

LadbAbstractModalSmartJoinToolAction.DICTIONARY = 'tool_smart_join_options';

// The options of the dialog - a missing input is skipped.
LadbAbstractModalSmartJoinToolAction.FIELDS = [
    { name: 'height', kind: 'dimension' },
    { name: 'start_offset', kind: 'dimension' },
    { name: 'end_offset', kind: 'dimension' },
    { name: 'min_spacing', kind: 'dimension' },
    { name: 'max_spacing', kind: 'dimension' },
    { name: 'hardware_material_name', kind: 'file' },
    { name: 'machining_material_name', kind: 'file' },
    { name: 'hardware_layer_name', kind: 'text' },
    { name: 'machining_layer_name', kind: 'text' },
];

// Init ///

LadbAbstractModalSmartJoinToolAction.prototype.init = function () {
    LadbAbstractModal.prototype.init.call(this);

    const that = this;

    rubyCallCommand('hardware_action_options_get', { section: this.section }, function (response) {

        const base = response.preset;
        const hardware = response.hardware;   // null : no picked hardware
        const hardwareValues = hardware ? hardware.values : {};
        const overrides = hardware ? hardware.overrides : {};

        // Fetch UI elements
        const $tabs = $('a[data-toggle="tab"]', that.$element);
        const $widgetPreset = $('.ladb-widget-preset', that.$element);
        const $btnValidate = $('#ladb_btn_validate', that.$element);

        const fields = LadbAbstractModalSmartJoinToolAction.FIELDS
            .map(function (field) { return $.extend({ $input: $('#ladb_input_' + field.name, that.$element) }, field); })
            .filter(function (field) { return field.$input.length > 0; });

        const fnDefined = function (field) {
            return Object.prototype.hasOwnProperty.call(hardwareValues, field.name);
        };
        const fnValue = function (value) {
            return value === undefined || value === null ? '' : String(value);
        };
        const fnGetValue = function (field) {
            return field.$input.val();
        };
        const fnSetValue = function (field, value) {
            if (field.kind === 'file') {
                field.$input.ladbTextinputFile('val', fnValue(value));
            } else {
                field.$input.val(fnValue(value));
            }
        };

        // Under an option the hardware defines : where its value comes from,
        // and the way back to the hardware's
        const fnRenderHardwareHelp = function (field) {
            if (!field.$help) {
                field.$help = $('<div class="help-block">');
                field.$input.closest('.col-xs-7').append(field.$help);
            }
            const value = fnGetValue(field);
            const params = {
                name: hardware.name,
                value: hardwareValues[field.name],
                base: fnValue(base[field.name]) === '' ? i18next.t('tool.smart_join.action_option_hardware_none') : base[field.name]
            };
            field.$help.empty();
            if (value === '' || value === hardwareValues[field.name]) {
                field.$help.append($('<small>').append(i18next.t('tool.smart_join.action_option_hardware_value_help', params)));
            } else {
                field.$help
                    .append($('<small>').append(i18next.t('tool.smart_join.action_option_hardware_override_help', params) + ' '))
                    .append($('<a href="#">')
                        .append('<i class="ladb-opencutlist-icon-reset"></i> ' + i18next.t('tool.smart_join.action_option_hardware_reset'))
                        .on('click', function () {
                            fnSetValue(field, hardwareValues[field.name]);
                            fnRenderHardwareHelp(field);
                            return false;
                        })
                    );
            }
        };

        // The presets of the widget hold the base values : the options the
        // hardware defines keep theirs
        const fnFetchOptions = function (options) {
            for (const field of fields) {
                options[field.name] = fnDefined(field) ? base[field.name] : fnGetValue(field);
            }
        };
        const fnFillInputs = function (options) {
            for (const field of fields) {
                if (!fnDefined(field)) {
                    fnSetValue(field, options[field.name]);
                }
            }
        };

        $widgetPreset.ladbWidgetPreset({
            dialog: that.dialog,
            dictionary: LadbAbstractModalSmartJoinToolAction.DICTIONARY,
            section: that.section,
            fnFetchOptions: fnFetchOptions,
            fnFillInputs: fnFillInputs
        });
        for (const field of fields) {
            if (field.kind === 'dimension') {
                field.$input.ladbTextinputDimension();
            } else if (field.kind === 'file') {
                field.$input.ladbTextinputFile({ library: true });
            } else {
                field.$input.ladbTextinputText();
            }
        }

        // The values in effect
        for (const field of fields) {
            if (Object.prototype.hasOwnProperty.call(overrides, field.name)) {
                fnSetValue(field, overrides[field.name]);
            } else if (fnDefined(field)) {
                fnSetValue(field, hardwareValues[field.name]);
            } else {
                fnSetValue(field, base[field.name]);
            }
            if (fnDefined(field)) {
                fnRenderHardwareHelp(field);
                field.$input.on('change', function () {
                    fnRenderHardwareHelp(field);
                });
            }
        }

        // Bind buttons
        $btnValidate.on('click', function () {

            // Each value at its level - see HardwareOptionsDef
            const values = {};
            for (const field of fields) {
                values[field.name] = fnGetValue(field);
            }
            rubyCallCommand('hardware_action_options_set', { section: that.section, values: values });

            // Hide modal
            that.dialog.hide();

        });

        // Bind tabs
        $tabs.on('shown.bs.tab', function (e) {
            if ($(e.target).attr('href') === '#tab_geometries') {
                for (const field of fields) {
                    if (field.kind === 'file') {
                        field.$input.ladbTextinputFile('scrollToTheEnd');
                    }
                }
            }
        });

        // Focus
        if (that.options.focused_field) {
            const field = fields.find(function (field) { return field.name === that.options.focused_field.option; });
            if (field) {
                field.$input.focus();
                field.$input.select();
            }
        }

    });

};

+function ($) {
    'use strict';

    // CLASS DEFINITION
    // ======================

    const LadbModalSmartExportToolAction1 = function (element, options, dialog) {
        LadbAbstractModal.call(this, element, options, dialog);

    };
    LadbModalSmartExportToolAction1.prototype = Object.create(LadbAbstractModal.prototype);

    LadbModalSmartExportToolAction1.DEFAULTS = {};

    // Init ///

    LadbModalSmartExportToolAction1.prototype.init = function () {
        LadbAbstractModal.prototype.init.call(this);

        const that = this;

        const dictonary = 'tool_smart_export_options';
        const section = 'action_1';

        // Retrieve options
        rubyCallCommand('core_get_global_preset', { dictionary: dictonary, section: section }, function (response) {

            const options = response.preset;

            // Fetch UI elements
            const $widgetPreset = $('.ladb-widget-preset', that.$element);
            const $selectFileFormat = $('#ladb_select_file_format', that.$element);
            const $selectUnit = $('#ladb_select_unit', that.$element);
            const $selectFaces = $('#ladb_select_faces', that.$element);
            const $selectAnchor = $('#ladb_select_anchor', that.$element);
            const $selectSmoothing = $('#ladb_select_smoothing', that.$element);
            const $formGroupMergeHolesOverflow = $('#ladb_form_group_merge_holes_overflow', that.$element);
            const $selectMergeHoles = $('#ladb_select_merge_holes', that.$element);
            const $inputMergeHolesOverflow = $('#ladb_input_merge_holes_overflow', that.$element);
            const $selectIncludePaths = $('#ladb_select_include_paths', that.$element);
            const $inputPartsStrokeColor = $('#ladb_input_parts_stroke_color', that.$element);
            const $inputPartsFillColor = $('#ladb_input_parts_fill_color', that.$element);
            const $formGroupPartsHoles = $('#ladb_form_group_parts_holes', that.$element);
            const $inputPartsDepthsStrokeColor = $('#ladb_input_parts_depths_stroke_color', that.$element);
            const $inputPartsDepthsFillColor = $('#ladb_input_parts_depths_fill_color', that.$element);
            const $inputPartsHolesStrokeColor = $('#ladb_input_parts_holes_stroke_color', that.$element);
            const $inputPartsHolesFillColor = $('#ladb_input_parts_holes_fill_color', that.$element);
            const $formGroupPartsPaths = $('#ladb_form_group_parts_paths', that.$element);
            const $inputPartsPathsStrokeColor = $('#ladb_input_parts_paths_stroke_color', that.$element);
            const $inputPartsPathsFillColor = $('#ladb_input_parts_paths_fill_color', that.$element);
            const $btnValidate = $('#ladb_btn_validate', that.$element);

            const fnFetchOptions = function (options) {
                options.file_format = $selectFileFormat.val();
                options.unit = parseInt($selectUnit.val());
                options.faces = parseInt($selectFaces.val());
                options.anchor = $selectAnchor.val() === '1';
                options.smoothing = $selectSmoothing.val() === '1';
                options.merge_holes = $selectMergeHoles.val() === '1';
                options.merge_holes_overflow = $inputMergeHolesOverflow.val();
                options.include_paths = $selectIncludePaths.val() === '1';
                options.parts_stroke_color = $inputPartsStrokeColor.ladbTextinputColor('val');
                options.parts_fill_color = $inputPartsFillColor.ladbTextinputColor('val');
                options.parts_depths_stroke_color = $inputPartsDepthsStrokeColor.ladbTextinputColor('val');
                options.parts_depths_fill_color = $inputPartsDepthsFillColor.ladbTextinputColor('val');
                options.parts_holes_stroke_color = $inputPartsHolesStrokeColor.ladbTextinputColor('val');
                options.parts_holes_fill_color = $inputPartsHolesFillColor.ladbTextinputColor('val');
                options.parts_paths_stroke_color = $inputPartsPathsStrokeColor.ladbTextinputColor('val');
                options.parts_paths_fill_color = $inputPartsPathsFillColor.ladbTextinputColor('val');
            };
            const fnFillInputs = function (options) {
                $selectFileFormat.selectpicker('val', options.file_format);
                $selectUnit.selectpicker('val', options.unit);
                $selectFaces.selectpicker('val', options.faces);
                $selectAnchor.selectpicker('val', options.anchor ? '1' : '0');
                $selectSmoothing.selectpicker('val', options.smoothing ? '1' : '0');
                $selectMergeHoles.selectpicker('val', options.merge_holes ? '1' : '0');
                $inputMergeHolesOverflow.val(options.merge_holes_overflow);
                $selectIncludePaths.selectpicker('val', options.include_paths ? '1' : '0');
                $inputPartsStrokeColor.ladbTextinputColor('val', options.parts_stroke_color);
                $inputPartsFillColor.ladbTextinputColor('val', options.parts_fill_color);
                $inputPartsDepthsStrokeColor.ladbTextinputColor('val', options.parts_depths_stroke_color);
                $inputPartsDepthsFillColor.ladbTextinputColor('val', options.parts_depths_fill_color);
                $inputPartsHolesStrokeColor.ladbTextinputColor('val', options.parts_holes_stroke_color);
                $inputPartsHolesFillColor.ladbTextinputColor('val', options.parts_holes_fill_color);
                $inputPartsPathsStrokeColor.ladbTextinputColor('val', options.parts_paths_stroke_color);
                $inputPartsPathsFillColor.ladbTextinputColor('val', options.parts_paths_fill_color);
                fnUpdateFieldsVisibility();
            };
            const fnUpdateFieldsVisibility = function () {
                const isDxf = $selectFileFormat.val() === 'dxf';
                const isMergeHoles = $selectMergeHoles.val() === '1';
                const isIncludePaths = $selectIncludePaths.val() === '1';
                if (isMergeHoles) $formGroupMergeHolesOverflow.show(); else $formGroupMergeHolesOverflow.hide();
                if (!isMergeHoles) $formGroupPartsHoles.hide(); else $formGroupPartsHoles.show();
                if (!isIncludePaths) $formGroupPartsPaths.hide(); else $formGroupPartsPaths.show();
                $inputPartsFillColor.ladbTextinputColor(isDxf ? 'disable' : 'enable');
                $inputPartsHolesStrokeColor.ladbTextinputColor(!isMergeHoles ? 'disable' : 'enable');
                $inputPartsHolesFillColor.ladbTextinputColor(!isMergeHoles || isDxf ? 'disable' : 'enable');
                $inputPartsPathsStrokeColor.ladbTextinputColor(!isIncludePaths ? 'disable' : 'enable');
                $inputPartsPathsFillColor.ladbTextinputColor(!isIncludePaths || isDxf ? 'disable' : 'enable');
                $('.ladb-form-fill-color').css('opacity', isDxf ? 0.3 : 1);
            };

            $widgetPreset.ladbWidgetPreset({
                dialog: that.dialog,
                dictionary: 'tool_smart_export_options',
                section: 'action_1',
                fnFetchOptions: fnFetchOptions,
                fnFillInputs: fnFillInputs
            });
            $selectFileFormat
                .selectpicker(SELECT_PICKER_OPTIONS)
                .on('changed.bs.select', fnUpdateFieldsVisibility)
            ;
            $selectUnit.selectpicker(SELECT_PICKER_OPTIONS);
            $selectFaces.selectpicker(SELECT_PICKER_OPTIONS);
            $selectAnchor.selectpicker(SELECT_PICKER_OPTIONS);
            $selectSmoothing.selectpicker(SELECT_PICKER_OPTIONS);
            $selectMergeHoles
                .selectpicker(SELECT_PICKER_OPTIONS)
                .on('changed.bs.select', fnUpdateFieldsVisibility)
            ;
            $inputMergeHolesOverflow.ladbTextinputDimension();
            $selectIncludePaths
                .selectpicker(SELECT_PICKER_OPTIONS)
                .on('changed.bs.select', fnUpdateFieldsVisibility)
            ;
            $inputPartsStrokeColor.ladbTextinputColor(TEXTINPUT_COLOR_OPTIONS);
            $inputPartsFillColor.ladbTextinputColor(TEXTINPUT_COLOR_OPTIONS);
            $inputPartsDepthsStrokeColor.ladbTextinputColor(TEXTINPUT_COLOR_OPTIONS);
            $inputPartsDepthsFillColor.ladbTextinputColor(TEXTINPUT_COLOR_OPTIONS);
            $inputPartsHolesStrokeColor.ladbTextinputColor(TEXTINPUT_COLOR_OPTIONS);
            $inputPartsHolesFillColor.ladbTextinputColor(TEXTINPUT_COLOR_OPTIONS);
            $inputPartsPathsStrokeColor.ladbTextinputColor(TEXTINPUT_COLOR_OPTIONS);
            $inputPartsPathsFillColor.ladbTextinputColor(TEXTINPUT_COLOR_OPTIONS);

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
            const options = $.extend({}, LadbModalSmartExportToolAction1.DEFAULTS, $this.data(), typeof option === 'object' && option);

            if (!data) {
                if (undefined === options.dialog) {
                    throw 'dialog option is mandatory.';
                }
                $this.data('ladb.tab.plugin', (data = new LadbModalSmartExportToolAction1(this, options, options.dialog)));
            }
            if (typeof option === 'string') {
                data[option].apply(data, Array.isArray(params) ? params : [ params ])
            } else {
                data.init();
            }
        })
    }

    const old = $.fn.ladbModalSmartExportToolAction1;

    $.fn.ladbModalSmartExportToolAction1 = Plugin;
    $.fn.ladbModalSmartExportToolAction1.Constructor = LadbModalSmartExportToolAction1;


    // NO CONFLICT
    // =================

    $.fn.ladbModalSmartExportToolAction1.noConflict = function () {
        $.fn.ladbModalSmartExportToolAction1 = old;
        return this;
    }

}(jQuery);
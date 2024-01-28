+function ($) {
    'use strict';

    // CLASS DEFINITION
    // ======================

    var LadbModalSmartExportToolAction1 = function (element, options, dialog) {
        LadbAbstractModal.call(this, element, options, dialog);

    };
    LadbModalSmartExportToolAction1.prototype = Object.create(LadbAbstractModal.prototype);

    LadbModalSmartExportToolAction1.DEFAULTS = {};

    // Init ///

    LadbModalSmartExportToolAction1.prototype.init = function () {
        LadbAbstractModal.prototype.init.call(this);

        var that = this;

        var dictonary = 'tool_smart_export_options';
        var section = 'action_1';

        // Retrieve options
        rubyCallCommand('core_get_global_preset', { dictionary: dictonary, section: section }, function (response) {

            var options = response.preset;

            // Fetch UI elements
            var $widgetPreset = $('.ladb-widget-preset', that.$element);
            var $selectFileFormat = $('#ladb_select_file_format', that.$element);
            var $selectUnit = $('#ladb_select_unit', that.$element);
            var $selectFaces = $('#ladb_select_faces', that.$element);
            var $selectAnchor = $('#ladb_select_anchor', that.$element);
            var $selectSmoothing = $('#ladb_select_smoothing', that.$element);
            var $selectMergeHoles = $('#ladb_select_merge_holes', that.$element);
            var $selectIncludePaths = $('#ladb_select_include_paths', that.$element);
            var $inputPartsStrokeColor = $('#ladb_input_parts_stroke_color', that.$element);
            var $inputPartsFillColor = $('#ladb_input_parts_fill_color', that.$element);
            var $formGroupPartsHoles = $('#ladb_form_group_parts_holes', that.$element);
            var $inputPartsHolesStrokeColor = $('#ladb_input_parts_holes_stroke_color', that.$element);
            var $inputPartsHolesFillColor = $('#ladb_input_parts_holes_fill_color', that.$element);
            var $formGroupPartsPaths = $('#ladb_form_group_parts_paths', that.$element);
            var $inputPartsPathsStrokeColor = $('#ladb_input_parts_paths_stroke_color', that.$element);
            var $btnValidate = $('#ladb_btn_validate', that.$element);

            var fnFetchOptions = function (options) {
                options.file_format = $selectFileFormat.val();
                options.unit = parseInt($selectUnit.val());
                options.faces = parseInt($selectFaces.val());
                options.anchor = $selectAnchor.val() === '1';
                options.smoothing = $selectSmoothing.val() === '1';
                options.merge_holes = $selectMergeHoles.val() === '1';
                options.include_paths = $selectIncludePaths.val() === '1';
                options.parts_stroke_color = $inputPartsStrokeColor.ladbTextinputColor('val');
                options.parts_fill_color = $inputPartsFillColor.ladbTextinputColor('val');
                options.parts_holes_stroke_color = $inputPartsHolesStrokeColor.ladbTextinputColor('val');
                options.parts_holes_fill_color = $inputPartsHolesFillColor.ladbTextinputColor('val');
                options.parts_paths_stroke_color = $inputPartsPathsStrokeColor.ladbTextinputColor('val');
            };
            var fnFillInputs = function (options) {
                $selectFileFormat.selectpicker('val', options.file_format);
                $selectUnit.selectpicker('val', options.unit);
                $selectFaces.selectpicker('val', options.faces);
                $selectAnchor.selectpicker('val', options.anchor ? '1' : '0');
                $selectSmoothing.selectpicker('val', options.smoothing ? '1' : '0');
                $selectMergeHoles.selectpicker('val', options.merge_holes ? '1' : '0');
                $selectIncludePaths.selectpicker('val', options.include_paths ? '1' : '0');
                $inputPartsStrokeColor.ladbTextinputColor('val', options.parts_stroke_color);
                $inputPartsFillColor.ladbTextinputColor('val', options.parts_fill_color);
                $inputPartsHolesStrokeColor.ladbTextinputColor('val', options.parts_holes_stroke_color);
                $inputPartsHolesFillColor.ladbTextinputColor('val', options.parts_holes_fill_color);
                $inputPartsPathsStrokeColor.ladbTextinputColor('val', options.parts_paths_stroke_color);
                fnUpdateFieldsVisibility();
            };
            var fnUpdateFieldsVisibility = function () {
                var isDxf = $selectFileFormat.val() === 'dxf';
                var isMergeHoles = $selectMergeHoles.val() === '1';
                var isPaths = $selectIncludePaths.val() === '1';
                if (!isMergeHoles) $formGroupPartsHoles.hide(); else $formGroupPartsHoles.show();
                if (!isPaths) $formGroupPartsPaths.hide(); else $formGroupPartsPaths.show();
                $inputPartsFillColor.ladbTextinputColor(isDxf ? 'disable' : 'enable');
                $inputPartsHolesStrokeColor.ladbTextinputColor(!isMergeHoles ? 'disable' : 'enable');
                $inputPartsHolesFillColor.ladbTextinputColor(!isMergeHoles || isDxf ? 'disable' : 'enable');
                $inputPartsPathsStrokeColor.ladbTextinputColor(!isPaths ? 'disable' : 'enable');
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
            $selectIncludePaths
                .selectpicker(SELECT_PICKER_OPTIONS)
                .on('changed.bs.select', fnUpdateFieldsVisibility)
            ;
            $inputPartsStrokeColor.ladbTextinputColor(TEXTINPUT_COLOR_OPTIONS);
            $inputPartsFillColor.ladbTextinputColor(TEXTINPUT_COLOR_OPTIONS);
            $inputPartsHolesStrokeColor.ladbTextinputColor(TEXTINPUT_COLOR_OPTIONS);
            $inputPartsHolesFillColor.ladbTextinputColor(TEXTINPUT_COLOR_OPTIONS);
            $inputPartsPathsStrokeColor.ladbTextinputColor(TEXTINPUT_COLOR_OPTIONS);

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
            var options = $.extend({}, LadbModalSmartExportToolAction1.DEFAULTS, $this.data(), typeof option === 'object' && option);

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

    var old = $.fn.ladbModalSmartExportToolAction1;

    $.fn.ladbModalSmartExportToolAction1 = Plugin;
    $.fn.ladbModalSmartExportToolAction1.Constructor = LadbModalSmartExportToolAction1;


    // NO CONFLICT
    // =================

    $.fn.ladbModalSmartExportToolAction1.noConflict = function () {
        $.fn.ladbModalSmartExportToolAction1 = old;
        return this;
    }

}(jQuery);
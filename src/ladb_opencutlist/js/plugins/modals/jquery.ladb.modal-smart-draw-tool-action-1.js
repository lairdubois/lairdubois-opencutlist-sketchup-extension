+function ($) {
    'use strict';

    // CLASS DEFINITION
    // ======================

    var LadbModalSmartDrawToolAction1 = function (element, options, dialog) {
        LadbAbstractModal.call(this, element, options, dialog);

    };
    LadbModalSmartDrawToolAction1.prototype = Object.create(LadbAbstractModal.prototype);

    LadbModalSmartDrawToolAction1.DEFAULTS = {};

    // Init ///

    LadbModalSmartDrawToolAction1.prototype.init = function () {
        LadbAbstractModal.prototype.init.call(this);

        var that = this;

        var dictonary = 'tool_smart_draw_options';
        var section = 'action_1';

        // Retrieve options
        rubyCallCommand('core_get_global_preset', { dictionary: dictonary, section: section }, function (response) {

            var options = response.preset;

            // Fetch UI elements
            var $widgetPreset = $('.ladb-widget-preset', that.$element);
            var $selectPushPull = $('#ladb_select_pushpull', that.$element);
            var $selectMove = $('#ladb_select_move', that.$element);
            var $inputSectionOffset = $('#ladb_input_section_offset', that.$element);
            var $inputSegmentCount = $('#ladb_input_segment_count', that.$element);
            var $selectConstrution = $('#ladb_select_construction', that.$element);
            var $selectBoxCentered = $('#ladb_select_box_centered', that.$element);
            var $btnValidate = $('#ladb_btn_validate', that.$element);

            var fnFetchOptions = function (options) {
                options.pushpull = $selectPushPull.val() === '1';
                options.move = $selectMove.val() === '1';
                options.section_offset = $inputSectionOffset.val();
                options.segment_count = parseInt($inputSegmentCount.val());
                options.construction = $selectConstrution.val() === '1';
                options.box_centered = $selectBoxCentered.val() === '1';
            };
            var fnFillInputs = function (options) {
                $selectPushPull.selectpicker('val', options.pushpull ? '1' : '0');
                $selectMove.selectpicker('val', options.move ? '1' : '0');
                $inputSectionOffset.val(options.section_offset);
                $inputSegmentCount.val(options.segment_count);
                $selectConstrution.selectpicker('val', options.construction ? '1' : '0');
                $selectBoxCentered.selectpicker('val', options.box_centered ? '1' : '0');
            };

            $widgetPreset.ladbWidgetPreset({
                dialog: that.dialog,
                dictionary: 'tool_smart_draw_options',
                section: 'action_0',
                fnFetchOptions: fnFetchOptions,
                fnFillInputs: fnFillInputs
            });
            $selectPushPull.selectpicker(SELECT_PICKER_OPTIONS);
            $selectMove.selectpicker(SELECT_PICKER_OPTIONS);
            $inputSectionOffset.ladbTextinputDimension();
            $inputSegmentCount.ladbTextinputNumberWithUnit({
                resetValue: '24'
            });
            $selectConstrution.selectpicker(SELECT_PICKER_OPTIONS);
            $selectBoxCentered.selectpicker(SELECT_PICKER_OPTIONS);

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
                if (that.options.focused_field.option === 'section_offset') {
                    $inputSectionOffset.focus();
                    $inputSectionOffset.select();
                } else if (that.options.focused_field.option === 'segment_count') {
                    $inputSegmentCount.focus();
                    $inputSegmentCount.select();
                }
            }

        });

    };

    // PLUGIN DEFINITION
    // =======================

    function Plugin(option, params) {
        return this.each(function () {
            var $this = $(this);
            var data = $this.data('ladb.tab.plugin');
            var options = $.extend({}, LadbModalSmartDrawToolAction1.DEFAULTS, $this.data(), typeof option === 'object' && option);

            if (!data) {
                if (undefined === options.dialog) {
                    throw 'dialog option is mandatory.';
                }
                $this.data('ladb.tab.plugin', (data = new LadbModalSmartDrawToolAction1(this, options, options.dialog)));
            }
            if (typeof option === 'string') {
                data[option].apply(data, Array.isArray(params) ? params : [ params ])
            } else {
                data.init();
            }
        })
    }

    var old = $.fn.ladbModalSmartDrawToolAction1;

    $.fn.ladbModalSmartDrawToolAction1 = Plugin;
    $.fn.ladbModalSmartDrawToolAction1.Constructor = LadbModalSmartDrawToolAction1;


    // NO CONFLICT
    // =================

    $.fn.ladbModalSmartDrawToolAction1.noConflict = function () {
        $.fn.ladbModalSmartDrawToolAction1 = old;
        return this;
    }

}(jQuery);
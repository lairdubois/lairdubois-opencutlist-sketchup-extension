+function ($) {
    'use strict';

    // CLASS DEFINITION
    // ======================

    var LadbModalSmartDrawToolAction2 = function (element, options, dialog) {
        LadbAbstractModal.call(this, element, options, dialog);

    };
    LadbModalSmartDrawToolAction2.prototype = Object.create(LadbAbstractModal.prototype);

    LadbModalSmartDrawToolAction2.DEFAULTS = {};

    // Init ///

    LadbModalSmartDrawToolAction2.prototype.init = function () {
        LadbAbstractModal.prototype.init.call(this);

        var that = this;

        var dictonary = 'tool_smart_draw_options';
        var section = 'action_2';

        // Retrieve options
        rubyCallCommand('core_get_global_preset', { dictionary: dictonary, section: section }, function (response) {

            var options = response.preset;

            // Fetch UI elements
            var $widgetPreset = $('.ladb-widget-preset', that.$element);
            var $selectPushPull = $('#ladb_select_pushpull', that.$element);
            var $selectMove = $('#ladb_select_move', that.$element);
            var $inputShapeOffset = $('#ladb_input_shape_offset', that.$element);
            var $selectConstrution = $('#ladb_select_construction', that.$element);
            var $selectSolidCentered = $('#ladb_select_solid_centered', that.$element);
            var $selectMoveArray = $('#ladb_select_move_array', that.$element);
            var $btnValidate = $('#ladb_btn_validate', that.$element);

            var fnFetchOptions = function (options) {
                options.pushpull = $selectPushPull.val() === '1';
                options.move = $selectMove.val() === '1';
                options.shape_offset = $inputShapeOffset.val();
                options.construction = $selectConstrution.val() === '1';
                options.solid_centered = $selectSolidCentered.val() === '1';
                options.move_array = $selectMoveArray.val() === '1';
            };
            var fnFillInputs = function (options) {
                $selectPushPull.selectpicker('val', options.pushpull ? '1' : '0');
                $selectMove.selectpicker('val', options.move ? '1' : '0');
                $inputShapeOffset.val(options.shape_offset);
                $selectConstrution.selectpicker('val', options.construction ? '1' : '0');
                $selectSolidCentered.selectpicker('val', options.solid_centered ? '1' : '0');
                $selectMoveArray.selectpicker('val', options.move_array ? '1' : '0');
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
            $inputShapeOffset.ladbTextinputDimension();
            $selectConstrution.selectpicker(SELECT_PICKER_OPTIONS);
            $selectSolidCentered.selectpicker(SELECT_PICKER_OPTIONS);
            $selectMoveArray.selectpicker(SELECT_PICKER_OPTIONS);

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
                if (that.options.focused_field.option === 'shape_offset') {
                    $inputShapeOffset.focus();
                    $inputShapeOffset.select();
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
            var options = $.extend({}, LadbModalSmartDrawToolAction2.DEFAULTS, $this.data(), typeof option === 'object' && option);

            if (!data) {
                if (undefined === options.dialog) {
                    throw 'dialog option is mandatory.';
                }
                $this.data('ladb.tab.plugin', (data = new LadbModalSmartDrawToolAction2(this, options, options.dialog)));
            }
            if (typeof option === 'string') {
                data[option].apply(data, Array.isArray(params) ? params : [ params ])
            } else {
                data.init();
            }
        })
    }

    var old = $.fn.ladbModalSmartDrawToolAction2;

    $.fn.ladbModalSmartDrawToolAction2 = Plugin;
    $.fn.ladbModalSmartDrawToolAction2.Constructor = LadbModalSmartDrawToolAction2;


    // NO CONFLICT
    // =================

    $.fn.ladbModalSmartDrawToolAction2.noConflict = function () {
        $.fn.ladbModalSmartDrawToolAction2 = old;
        return this;
    }

}(jQuery);
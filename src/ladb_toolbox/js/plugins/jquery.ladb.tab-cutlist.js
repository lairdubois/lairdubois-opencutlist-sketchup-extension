+function ($) {
    'use strict';

    // CONSTANTS
    // ======================

    // Options keys

    var SETTING_KEY_OPTION_AUTO_ORIENT = 'cutlist_option_auto_orient';
    var SETTING_KEY_OPTION_SMART_MATERIAL = 'cutlist_option_smart_material';
    var SETTING_KEY_OPTION_PART_NUMBER_WITH_LETTERS = 'cutlist_option_part_number_with_letters';
    var SETTING_KEY_OPTION_PART_NUMBER_SEQUENCE_BY_GROUP = 'cutlist_option_part_number_sequence_by_group';
    var SETTING_KEY_OPTION_PART_ORDER_STRATEGY = 'cutlist_option_part_order_strategy';

    var SETTING_KEY_OPTION_HIDE_RAW_DIMENSIONS = 'cutlist_option_hide_raw_dimensions';
    var SETTING_KEY_OPTION_HIDE_FINAL_DIMENSIONS = 'cutlist_option_hide_final_dimensions';
    var SETTING_KEY_OPTION_HIDE_UNTYPED_MATERIAL_DIMENSIONS = 'cutlist_option_hide_untyped_material_dimensions';
    var SETTING_KEY_OPTION_SUMMARY_NO_PRINT = 'cutlist_option_summary_hidden';

    // Options defaults

    var OPTION_DEFAULT_AUTO_ORIENT = true;
    var OPTION_DEFAULT_SMART_MATERIAL = true;
    var OPTION_DEFAULT_PART_NUMBER_WITH_LETTERS = true;
    var OPTION_DEFAULT_PART_NUMBER_SEQUENCE_BY_GROUP = true;
    var OPTION_DEFAULT_PART_ORDER_STRATEGY = '-thickness>-length>-width>-count>name';

    var OPTION_DEFAULT_SUMMARY_NO_PRINT = false;
    var OPTION_DEFAULT_HIDE_RAW_DIMENSIONS = false;
    var OPTION_DEFAULT_HIDE_FINAL_DIMENSIONS = false;
    var OPTION_DEFAULT_HIDE_UNTYPED_MATERIAL_DIMENSIONS = true;

    // CLASS DEFINITION
    // ======================

    var LadbTabCutlist = function (element, options, toolbox) {
        this.options = options;
        this.$element = $(element);
        this.toolbox = toolbox;

        this.groups = [];
        this.materialUsages = [];
        this.editedPart = null;

        this.$fileTabs = $('.ladb-file-tabs', this.$element);
        this.$btnGenerate = $('#ladb_btn_generate', this.$element);
        this.$btnPrint = $('#ladb_btn_print', this.$element);
        this.$panelHelp = $('.ladb-panel-help', this.$element);

        this.$page = $('.ladb-page', this.$element);

        this.$modalOptions = $('#ladb_cutlist_modal_options', this.$element);
        this.$inputAutoOrient = $('#ladb_input_auto_orient', this.$modalOptions);
        this.$inputSmartMaterial = $('#ladb_input_smart_material', this.$modalOptions);
        this.$inputPartNumberWithLetters = $('#ladb_input_part_number_with_letters', this.$modalOptions);
        this.$inputPartNumberSequenceByGroup = $('#ladb_input_part_number_sequence_by_group', this.$modalOptions);
        this.$inputHideRawDimensions = $('#ladb_input_hide_raw_dimensions', this.$modalOptions);
        this.$inputHideFinalDimensions = $('#ladb_input_hide_final_dimensions', this.$modalOptions);
        this.$inputHideUntypedMaterialDimensions = $('#ladb_input_hide_untyped_material_dimensions', this.$modalOptions);
        this.$sortablePartOrderStrategy = $('#ladb_sortable_part_order_strategy', this.$modalOptions);
        this.$btnReset = $('#ladb_cutlist_options_reset', this.$modalOptions);

        this.$modalEditPart = $('#ladb_cutlist_modal_part', this.$element);
        this.$btnPartUpdate = $('#ladb_cutlist_part_update', this.$modalEditPart);
        this.$selectMaterialName = $('#ladb_cutlist_part_select_material_name', this.$modalEditPart);
        this.$inputPartName = $('#ladb_cutlist_part_input_name', this.$modalEditPart);
        this.$divMaterialOrigins = $('.ladb-material-origins', this.$modalEditPart);
    };

    LadbTabCutlist.DEFAULTS = {};

    LadbTabCutlist.prototype.generateCutlist = function () {
        var that = this;

        this.groups = [];
        this.$page.empty();
        this.$btnGenerate.prop('disabled', true);

        rubyCallCommand('cutlist_generate', this.generateOptions, function(data) {

            var errors = data.errors;
            var warnings = data.warnings;
            var tips = data.tips;
            var filename = data.filename;
            var pageLabel = data.page_label;
            var materialUsages = data.material_usages;
            var groups = data.groups;

            // Keep usefull data
            that.groups = groups;
            that.materialUsages = materialUsages;

            // Update filename
            that.$fileTabs.empty();
            that.$fileTabs.append(Twig.twig({ ref: "tabs/cutlist/_file-tab.twig" }).render({
                filename: filename,
                pageLabel: pageLabel
            }));

            // Hide help panel
            that.$panelHelp.hide();

            // Update print button state
            that.$btnPrint.prop('disabled', groups.length == 0);

            // Update page
            that.$page.empty();
            that.$page.append(Twig.twig({ ref: "tabs/cutlist/_list.twig" }).render({
                showThicknessSeparators: that.generateOptions.part_order_strategy.startsWith('thickness') || that.generateOptions.part_order_strategy.startsWith('-thickness'),
                uiOptions: that.uiOptions,
                errors: errors,
                warnings: warnings,
                tips: tips,
                groups: groups
            }));

            // Setup tooltips
            that.toolbox.setupTooltips();

            // Bind buttons
            $('.ladb-btn-toggle-no-print', that.$page).on('click', function() {
                var $i = $('i', $(this));
                var groupId = $(this).data('group-id');
                var $group = $('#' + groupId);
                $group.toggleClass('no-print');
                if ($group.hasClass('no-print')) {
                    $i.removeClass('ladb-toolbox-icon-eye-close');
                    $i.addClass('ladb-toolbox-icon-eye-open');
                } else {
                    $i.addClass('ladb-toolbox-icon-eye-close');
                    $i.removeClass('ladb-toolbox-icon-eye-open');
                }
                $(this).blur();
                if (groupId == 'ladb_summary') {
                    that.uiOptions.summary_no_print = $group.hasClass('no-print');
                    that.toolbox.setSetting(SETTING_KEY_OPTION_SUMMARY_NO_PRINT, that.uiOptions.summary_no_print);
                }
            });
            $('a.ladb-btn-scrollto', that.$page).on('click', function() {
                var target = $(this).attr('href');
                $('html, body').animate({ scrollTop: $(target).offset().top - 20 }, 500).promise().then(function() {
                    $(target).effect("highlight", {}, 1500);
                });
                $(this).blur();
                return false;
            });
            $('a.ladb-btn-edit', that.$page).on('click', function() {
                var partGuid = $(this).data('part-id');
                that.editPart(partGuid);
                $(this).blur();
                return false;
            });

            // Restore button state
            that.$btnGenerate.prop('disabled', false);

        });

    };

    LadbTabCutlist.prototype.findPartById = function (id) {
        for (var i = 0 ; i < this.groups.length; i++) {
            var group = this.groups[i];
            for (var j = 0; j < group.parts.length; j++) {
                var part = group.parts[j];
                if (part.id == id) {
                    return part;
                }
            }
        }
        return null;
    };

    LadbTabCutlist.prototype.editPart = function (id) {
        var that = this;

        var part = this.findPartById(id);
        if (part) {

            rubyCallCommand('cutlist_part_get_thumbnail', part, function(data) {

                var thumbnailFile = data['thumbnail_file'];

                var $imgThumbnail = $('.ladb-part-thumbnail', that.$modalEditPart);
                $imgThumbnail.attr('src', thumbnailFile);

                // Keep the edited part
                that.editedPart = part;

                // Populate material select
                that.$selectMaterialName.empty();
                that.$selectMaterialName.append(Twig.twig({ref: "tabs/cutlist/_material-usages.twig"}).render({
                    materialUsages: that.materialUsages
                }));

                // Form fields
                that.$inputPartName.val(part.name);
                that.$selectMaterialName.val(part.material_name);

                // Refresh select
                that.$selectMaterialName.selectpicker('refresh');

                // Material origins
                that.$divMaterialOrigins.empty();
                if (part.material_name) {
                    that.$divMaterialOrigins.append(Twig.twig({ref: "tabs/cutlist/_material-origins.twig"}).render({
                        materialOrigins: part.material_origins,
                        displayOwned: true,
                        flat: true
                    }));
                }

                that.$modalEditPart.modal('show');

            });

        }
    };

    LadbTabCutlist.prototype.resetOptions = function () {

        // Reset local options
        this.generateOptions = {
            auto_orient: OPTION_DEFAULT_AUTO_ORIENT,
            smart_material: OPTION_DEFAULT_SMART_MATERIAL,
            part_number_with_letters: OPTION_DEFAULT_PART_NUMBER_WITH_LETTERS,
            part_number_sequence_by_group: OPTION_DEFAULT_PART_NUMBER_SEQUENCE_BY_GROUP,
            part_order_strategy: OPTION_DEFAULT_PART_ORDER_STRATEGY
        };

        this.uiOptions.hide_raw_dimensions = OPTION_DEFAULT_HIDE_RAW_DIMENSIONS;
        this.uiOptions.hide_final_dimensions = OPTION_DEFAULT_HIDE_FINAL_DIMENSIONS;
        this.uiOptions.hide_untyped_material_dimensions = OPTION_DEFAULT_HIDE_UNTYPED_MATERIAL_DIMENSIONS;

        // Sync with SU
        this.toolbox.setSettings([

            { key: SETTING_KEY_OPTION_AUTO_ORIENT, value:this.generateOptions.auto_orient },
            { key: SETTING_KEY_OPTION_SMART_MATERIAL, value:this.generateOptions.smart_material },
            { key: SETTING_KEY_OPTION_PART_NUMBER_WITH_LETTERS, value:this.generateOptions.part_number_with_letters },
            { key: SETTING_KEY_OPTION_PART_NUMBER_SEQUENCE_BY_GROUP, value:this.generateOptions.part_number_sequence_by_group },
            { key: SETTING_KEY_OPTION_PART_ORDER_STRATEGY, value:this.generateOptions.part_order_strategy },

            { key: SETTING_KEY_OPTION_HIDE_RAW_DIMENSIONS, value:this.uiOptions.hide_raw_dimensions },
            { key: SETTING_KEY_OPTION_HIDE_FINAL_DIMENSIONS, value:this.uiOptions.hide_final_dimensions },
            { key: SETTING_KEY_OPTION_HIDE_UNTYPED_MATERIAL_DIMENSIONS, value:this.uiOptions.hide_untyped_material_dimensions }

        ]);

        this.refreshOptionsInputs();

    };

    LadbTabCutlist.prototype.refreshOptionsInputs = function () {
        var that = this;

        // Checkboxes

        this.$inputAutoOrient.prop('checked', this.generateOptions.auto_orient);
        this.$inputSmartMaterial.prop('checked', this.generateOptions.smart_material);
        this.$inputPartNumberWithLetters.prop('checked', this.generateOptions.part_number_with_letters);
        this.$inputPartNumberSequenceByGroup.prop('checked', this.generateOptions.part_number_sequence_by_group);
        this.$inputHideRawDimensions.prop('checked', this.uiOptions.hide_raw_dimensions);
        this.$inputHideFinalDimensions.prop('checked', this.uiOptions.hide_final_dimensions);
        this.$inputHideUntypedMaterialDimensions.prop('checked', this.uiOptions.hide_untyped_material_dimensions);
        this.$inputHideUntypedMaterialDimensions.prop('disabled', this.uiOptions.hide_final_dimensions);

        // Part order sortables

        var properties = this.generateOptions.part_order_strategy.split('>');
        var onSortableChange = function() {
            var properties = [];
            that.$sortablePartOrderStrategy.children('li').each(function () {
                properties.push($(this).data('property'));
            });
            that.generateOptions.part_order_strategy = properties.join('>');
            that.toolbox.setSetting(SETTING_KEY_OPTION_PART_ORDER_STRATEGY, that.generateOptions.part_order_strategy);
        };

        this.$sortablePartOrderStrategy.empty();
        for (var i = 0; i < properties.length; i++) {
            var property = properties[i];
            this.$sortablePartOrderStrategy.append(Twig.twig({ref: "tabs/cutlist/_option-part-order-strategy-property.twig"}).render({
                order: property.startsWith('-') ? '-' : '',
                property: property.startsWith('-') ? property.substr(1) : property
            }));
        }
        this.$sortablePartOrderStrategy.find('a').on('click', function() {
            var $item = $(this).parent().parent();
            var $icon = $('i', $(this));
            var property = $item.data('property');
            if (property.startsWith('-')) {
                property = property.substr(1);
                $icon.addClass('ladb-toolbox-icon-sort-asc');
                $icon.removeClass('ladb-toolbox-icon-sort-desc');
            } else {
                property = '-' + property;
                $icon.removeClass('ladb-toolbox-icon-sort-asc');
                $icon.addClass('ladb-toolbox-icon-sort-desc');
            }
            $item.data('property', property);
            onSortableChange()
        });
        this.$sortablePartOrderStrategy.sortable({
            cursor: 'ns-resize',
            handle: '.ladb-handle',
            update: function (event, ui) {
                onSortableChange();
            }
        });

    };

    LadbTabCutlist.prototype.bind = function () {
        var that = this;

        // Bind buttons
        this.$btnGenerate.on('click', function () {
            that.generateCutlist();
            this.blur();
        });
        this.$btnPrint.on('click', function () {
            window.print();
            this.blur();
        });
        this.$btnPartUpdate.on('click', function () {

            that.editedPart.name = that.$inputPartName.val();
            that.editedPart.material_name = that.$selectMaterialName.val();

            rubyCallCommand('cutlist_part_update', that.editedPart, function() {

                // Reset edited part
                that.editedPart = null;

                // Hide modal
                that.$modalEditPart.modal('hide');

                // Refresh the list
                that.generateCutlist();

            });

        });
        this.$btnReset.on('click', function() {
           that.resetOptions();
        });

        // Bind inputs
        this.$inputAutoOrient.on('change', function () {
            that.generateOptions.auto_orient = that.$inputAutoOrient.is(':checked');
            that.toolbox.setSetting(SETTING_KEY_OPTION_AUTO_ORIENT, that.generateOptions.auto_orient);
        });
        this.$inputSmartMaterial.on('change', function () {
            that.generateOptions.smart_material = that.$inputSmartMaterial.is(':checked');
            that.toolbox.setSetting(SETTING_KEY_OPTION_SMART_MATERIAL, that.generateOptions.smart_material);
        });
        this.$inputPartNumberWithLetters.on('change', function () {
            that.generateOptions.part_number_with_letters = that.$inputPartNumberWithLetters.is(':checked');
            that.toolbox.setSetting(SETTING_KEY_OPTION_PART_NUMBER_WITH_LETTERS, that.generateOptions.part_number_with_letters);
        });
        this.$inputPartNumberSequenceByGroup.on('change', function () {
            that.generateOptions.part_number_sequence_by_group = that.$inputPartNumberSequenceByGroup.is(':checked');
            that.toolbox.setSetting(SETTING_KEY_OPTION_PART_NUMBER_SEQUENCE_BY_GROUP, that.generateOptions.part_number_sequence_by_group);
        });
        this.$inputHideRawDimensions.on('change', function () {
            that.uiOptions.hide_raw_dimensions = that.$inputHideRawDimensions.is(':checked');
            that.toolbox.setSetting(SETTING_KEY_OPTION_HIDE_RAW_DIMENSIONS, that.uiOptions.hide_raw_dimensions);
        });
        this.$inputHideFinalDimensions.on('change', function () {
            that.uiOptions.hide_final_dimensions = that.$inputHideFinalDimensions.is(':checked');
            that.toolbox.setSetting(SETTING_KEY_OPTION_HIDE_FINAL_DIMENSIONS, that.uiOptions.hide_final_dimensions);
            that.$inputHideUntypedMaterialDimensions.prop('disabled', that.uiOptions.hide_final_dimensions);
        });
        this.$inputHideUntypedMaterialDimensions.on('change', function () {
            that.uiOptions.hide_untyped_material_dimensions = that.$inputHideUntypedMaterialDimensions.is(':checked');
            that.toolbox.setSetting(SETTING_KEY_OPTION_HIDE_UNTYPED_MATERIAL_DIMENSIONS, that.uiOptions.hide_untyped_material_dimensions);
        });

    };

    LadbTabCutlist.prototype.init = function () {
        var that = this;

        this.toolbox.pullSettings([

            SETTING_KEY_OPTION_AUTO_ORIENT,
            SETTING_KEY_OPTION_SMART_MATERIAL,
            SETTING_KEY_OPTION_PART_NUMBER_WITH_LETTERS,
            SETTING_KEY_OPTION_PART_NUMBER_SEQUENCE_BY_GROUP,
            SETTING_KEY_OPTION_PART_ORDER_STRATEGY,

            SETTING_KEY_OPTION_HIDE_UNTYPED_MATERIAL_DIMENSIONS,
            SETTING_KEY_OPTION_HIDE_RAW_DIMENSIONS,
            SETTING_KEY_OPTION_HIDE_FINAL_DIMENSIONS,
            SETTING_KEY_OPTION_SUMMARY_NO_PRINT

        ], function() {

            that.generateOptions = {
                auto_orient: that.toolbox.getSetting(SETTING_KEY_OPTION_AUTO_ORIENT, OPTION_DEFAULT_AUTO_ORIENT),
                smart_material: that.toolbox.getSetting(SETTING_KEY_OPTION_SMART_MATERIAL, OPTION_DEFAULT_SMART_MATERIAL),
                part_number_with_letters: that.toolbox.getSetting(SETTING_KEY_OPTION_PART_NUMBER_WITH_LETTERS, OPTION_DEFAULT_PART_NUMBER_WITH_LETTERS),
                part_number_sequence_by_group: that.toolbox.getSetting(SETTING_KEY_OPTION_PART_NUMBER_SEQUENCE_BY_GROUP, OPTION_DEFAULT_PART_NUMBER_SEQUENCE_BY_GROUP),
                part_order_strategy: that.toolbox.getSetting(SETTING_KEY_OPTION_PART_ORDER_STRATEGY, OPTION_DEFAULT_PART_ORDER_STRATEGY)
            };

            that.uiOptions = {
                hide_raw_dimensions: that.toolbox.getSetting(SETTING_KEY_OPTION_HIDE_RAW_DIMENSIONS, OPTION_DEFAULT_HIDE_RAW_DIMENSIONS),
                hide_final_dimensions: that.toolbox.getSetting(SETTING_KEY_OPTION_HIDE_FINAL_DIMENSIONS, OPTION_DEFAULT_HIDE_FINAL_DIMENSIONS),
                hide_untyped_material_dimensions: that.toolbox.getSetting(SETTING_KEY_OPTION_HIDE_UNTYPED_MATERIAL_DIMENSIONS, OPTION_DEFAULT_HIDE_UNTYPED_MATERIAL_DIMENSIONS),
                summary_no_print: that.toolbox.getSetting(SETTING_KEY_OPTION_SUMMARY_NO_PRINT, OPTION_DEFAULT_SUMMARY_NO_PRINT)
            };

            // Init options inputs
            that.refreshOptionsInputs();

            // Init selects
            that.$selectMaterialName.selectpicker({
                size: 10,
                iconBase: 'ladb-toolbox-icon',
                tickIcon: 'ladb-toolbox-icon-tick',
                showTick: true
            });

            that.bind();
        });

    };


    // PLUGIN DEFINITION
    // =======================

    function Plugin(option, params) {
        return this.each(function () {
            var $this = $(this);
            var data = $this.data('ladb.tabCutlist');
            var options = $.extend({}, LadbTabCutlist.DEFAULTS, $this.data(), typeof option == 'object' && option);

            if (!data) {
                if (options.toolbox == undefined) {
                    throw 'toolbox option is mandatory.';
                }
                $this.data('ladb.tabCutlist', (data = new LadbTabCutlist(this, options, options.toolbox)));
            }
            if (typeof option == 'string') {
                data[option](params);
            } else {
                data.init();
            }
        })
    }

    var old = $.fn.ladbTabCutlist;

    $.fn.ladbTabCutlist = Plugin;
    $.fn.ladbTabCutlist.Constructor = LadbTabCutlist;


    // NO CONFLICT
    // =================

    $.fn.ladbTabCutlist.noConflict = function () {
        $.fn.ladbTabCutlist = old;
        return this;
    }

}(jQuery);
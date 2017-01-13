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
    var SETTING_KEY_OPTION_HIDDEN_GROUP_IDS = 'cutlist_option_hidden_group_ids';

    // Options defaults

    var OPTION_DEFAULT_AUTO_ORIENT = true;
    var OPTION_DEFAULT_SMART_MATERIAL = true;
    var OPTION_DEFAULT_PART_NUMBER_WITH_LETTERS = true;
    var OPTION_DEFAULT_PART_NUMBER_SEQUENCE_BY_GROUP = true;
    var OPTION_DEFAULT_PART_ORDER_STRATEGY = '-thickness>-length>-width>-count>name';

    var OPTION_DEFAULT_HIDE_RAW_DIMENSIONS = false;
    var OPTION_DEFAULT_HIDE_FINAL_DIMENSIONS = false;
    var OPTION_DEFAULT_HIDE_UNTYPED_MATERIAL_DIMENSIONS = true;
    var OPTION_DEFAULT_HIDDEN_GROUP_IDS = [];

    // Select picker options

    var SELECT_PICKER_OPTIONS = {
        size: 10,
        iconBase: 'ladb-toolbox-icon',
        tickIcon: 'ladb-toolbox-icon-tick',
        showTick: true
    };

    // CLASS DEFINITION
    // ======================

    var LadbTabCutlist = function (element, options, toolbox) {
        this.options = options;
        this.$element = $(element);
        this.toolbox = toolbox;

        this.groups = [];
        this.materialUsages = [];
        this.editedPart = null;
        this.editedGroup = null;

        this.$fileTabs = $('.ladb-file-tabs', this.$element);
        this.$btnGenerate = $('#ladb_btn_generate', this.$element);
        this.$btnPrint = $('#ladb_btn_print', this.$element);
        this.$itemShowAllGroups = $('#ladb_item_show_all_groups', this.$element);
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
        this.$btnOptionsReset = $('#ladb_cutlist_options_reset', this.$modalOptions);

    };

    LadbTabCutlist.DEFAULTS = {};

    // Cutlist /////

    LadbTabCutlist.prototype.generateCutlist = function (callback) {
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

            // Update buttons and items state
            that.$btnPrint.prop('disabled', groups.length == 0);
            that.$itemShowAllGroups.closest('li').toggleClass('disabled', groups.length == 0);

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

            // Cleanup nonexistent hidden group ids
            var hiddenGroupIdsLength = that.uiOptions.hidden_group_ids.length;
            for (var i = hiddenGroupIdsLength - 1 ; i >= 0; i--) {
                if (that.uiOptions.hidden_group_ids[i] == 'summary') {
                    continue;
                }
                var exists = false;
                for (var j = 0; j < groups.length; j++) {
                    if (that.uiOptions.hidden_group_ids[i] == groups[j].id) {
                        exists = true;
                        break;
                    }
                }
                if (!exists) {
                    that.uiOptions.hidden_group_ids.splice(i, 1);
                }
            }
            if (hiddenGroupIdsLength > that.uiOptions.hidden_group_ids.length) {
                that.toolbox.setSetting(SETTING_KEY_OPTION_HIDDEN_GROUP_IDS, that.uiOptions.hidden_group_ids);
            }

            // Bind buttons
            $('.ladb-btn-toggle-no-print', that.$page).on('click', function() {
                var $group = $(this).closest('.ladb-cutlist-group');
                if ($group.hasClass('no-print')) {
                    that.showGroup($group);
                } else {
                    that.hideGroup($group);
                }
                $(this).blur();
            });
            $('a.ladb-btn-scrollto', that.$page).on('click', function() {
                var target = $(this).attr('href');
                $('html, body').animate({ scrollTop: $(target).offset().top - 20 }, 200).promise().then(function() {
                    $(target).effect("highlight", {}, 1500);
                });
                $(this).blur();
            });
            $('a.ladb-item-edit-material', that.$page).on('click', function() {
                $(this).blur();
            });
            $('a.ladb-item-edit-group', that.$page).on('click', function() {
                var $group = $(this).closest('.ladb-cutlist-group');
                var groupId = $group.data('group-id');
                that.editGroup(groupId);
                $(this).blur();
            });
            $('a.ladb-item-hide-all-other-groups', that.$page).on('click', function() {
                var $group = $(this).closest('.ladb-cutlist-group');
                var groupId = $group.data('group-id');
                that.hideAllGroups(groupId);
                $('html, body').animate({ scrollTop: $group.offset().top - 20 }, 200).promise();
                $(this).blur();
            });
            $('a.ladb-btn-edit-part', that.$page).on('click', function() {
                var partId = $(this).data('part-id');
                that.editPart(partId);
                $(this).blur();
                return false;
            });

            // Restore button state
            that.$btnGenerate.prop('disabled', false);

            // Callback
            if (callback && typeof callback == 'function') {
                callback();
            }

        });

    };

    // Parts /////

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

                // Keep the edited part
                that.editedPart = part;

                // Render modal
                that.$element.append(Twig.twig({ref: "tabs/cutlist/_modal-part.twig"}).render({
                    part: part,
                    thumbnailFile: thumbnailFile,
                    materialUsages: that.materialUsages
                }));

                // Fetch UI elements
                var $modalEditPart = $('#ladb_cutlist_modal_part', that.$element);
                var $inputPartName = $('#ladb_cutlist_part_input_name', $modalEditPart);
                var $selectPartMaterialName = $('#ladb_cutlist_part_select_material_name', $modalEditPart);
                var $btnPartUpdate = $('#ladb_cutlist_part_update', $modalEditPart);

                // Bind modal
                $modalEditPart.on('hidden.bs.modal', function () {
                    $(this)
                        .data('bs.modal', null)
                        .remove();
                });

                // Bind select
                $selectPartMaterialName.val(part.material_name);
                $selectPartMaterialName.selectpicker(SELECT_PICKER_OPTIONS);

                // Bind buttons
                $btnPartUpdate.on('click', function () {

                    that.editedPart.name = $inputPartName.val();
                    that.editedPart.material_name = $selectPartMaterialName.val();

                    rubyCallCommand('cutlist_part_update', that.editedPart, function() {

                        var partId = that.editedPart.id;
                        var wTop = $('#ladb_part_' + partId).offset().top - $(window).scrollTop();

                        // Reset edited part
                        that.editedPart = null;

                        // Hide modal
                        $modalEditPart.modal('hide');

                        // Refresh the list
                        that.generateCutlist(function() {

                            // Try to scroll to the edited part's row
                            var $part = $('#ladb_part_' + partId).effect("highlight", {}, 1500);
                            $('html, body').animate({ scrollTop: $part.offset().top - wTop }, 0);

                        });

                    });

                });

                // Show modal
                $modalEditPart.modal('show');

            });

        }
    };

    // Groups /////

    LadbTabCutlist.prototype.findGroupById = function (id) {
        for (var i = 0 ; i < this.groups.length; i++) {
            var group = this.groups[i];
            if (group.id == id) {
                return group;
            }
        }
        return null;
    };

    LadbTabCutlist.prototype.editGroup = function (id) {
        var that = this;

        var group = this.findGroupById(id);
        if (group) {

            // Keep the edited group
            that.editedGroup = group;

            // Render modal
            that.$element.append(Twig.twig({ref: "tabs/cutlist/_modal-group.twig"}).render({
                group: group,
                materialUsages: that.materialUsages
            }));

            // Fetch UI elements
            var $modalEditGroup = $('#ladb_cutlist_modal_group', that.$element);
            var $selectGroupMaterialName = $('#ladb_cutlist_group_select_material_name', $modalEditGroup);
            var $btnGroupUpdate = $('#ladb_cutlist_group_update', $modalEditGroup);

            // Bind modal
            $modalEditGroup.on('hidden.bs.modal', function () {
                $(this)
                    .data('bs.modal', null)
                    .remove();
            });

            // Bind select
            $selectGroupMaterialName.val(group.material_name);
            $selectGroupMaterialName.selectpicker(SELECT_PICKER_OPTIONS);

            // Bind buttons
            $btnGroupUpdate.on('click', function () {

                // Fetch form values
                that.editedGroup.material_name = $selectGroupMaterialName.val();

                rubyCallCommand('cutlist_group_update', that.editedGroup, function() {

                    // Reset edited group
                    that.editedGroup = null;

                    // Hide modal
                    $modalEditGroup.modal('hide');

                    // Refresh the list
                    that.generateCutlist();

                });

            });

            // Show modal
            $modalEditGroup.modal('show');

        }
    };

    LadbTabCutlist.prototype.showGroup = function ($group) {
        var groupId = $group.data('group-id');
        var $btn = $('.ladb-btn-toggle-no-print', $group);
        var $i = $('i', $btn);

        $group.removeClass('no-print');
        $i.addClass('ladb-toolbox-icon-eye-close');
        $i.removeClass('ladb-toolbox-icon-eye-open');

        var idx = this.uiOptions.hidden_group_ids.indexOf(groupId);
        if (idx != -1) {
            this.uiOptions.hidden_group_ids.splice(idx, 1);
            this.toolbox.setSetting(SETTING_KEY_OPTION_HIDDEN_GROUP_IDS, this.uiOptions.hidden_group_ids);
        }

    };

    LadbTabCutlist.prototype.hideGroup = function ($group) {
        var groupId = $group.data('group-id');
        var $btn = $('.ladb-btn-toggle-no-print', $group);
        var $i = $('i', $btn);

        $group.addClass('no-print');
        $i.removeClass('ladb-toolbox-icon-eye-close');
        $i.addClass('ladb-toolbox-icon-eye-open');

        var idx = this.uiOptions.hidden_group_ids.indexOf(groupId);
        if (idx == -1) {
            this.uiOptions.hidden_group_ids.push(groupId);
            this.toolbox.setSetting(SETTING_KEY_OPTION_HIDDEN_GROUP_IDS, this.uiOptions.hidden_group_ids);
        }

    };

    LadbTabCutlist.prototype.showAllGroups = function () {
        var that = this;
        $('.ladb-cutlist-group', this.$page).each(function() {
            that.showGroup($(this));
        });
    };

    LadbTabCutlist.prototype.hideAllGroups = function (exceptGroupId) {
        var that = this;
        $('.ladb-cutlist-group', this.$page).each(function() {
            var groupId = $(this).data('group-id');
            if (exceptGroupId && groupId != exceptGroupId) {
                that.hideGroup($(this));
            }
        });
    };

    // Options /////

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
        this.$inputHideUntypedMaterialDimensions
            .prop('checked', this.uiOptions.hide_untyped_material_dimensions)
            .prop('disabled', this.uiOptions.hide_final_dimensions);

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

    // Internals /////

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
        this.$itemShowAllGroups.on('click', function () {
            that.showAllGroups();
            this.blur();
        });
        this.$btnOptionsReset.on('click', function() {
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
            SETTING_KEY_OPTION_HIDDEN_GROUP_IDS

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
                hidden_group_ids: that.toolbox.getSetting(SETTING_KEY_OPTION_HIDDEN_GROUP_IDS, OPTION_DEFAULT_HIDDEN_GROUP_IDS)
            };

            // Init options inputs
            that.refreshOptionsInputs();

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
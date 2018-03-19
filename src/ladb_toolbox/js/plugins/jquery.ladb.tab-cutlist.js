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

    var SETTING_KEY_OPTION_COL_SEP = 'cutlist_option_col_sep';
    var SETTING_KEY_OPTION_ENCODING = 'cutlist_option_encoding';

    var SETTING_KEY_OPTION_HIDE_RAW_DIMENSIONS = 'cutlist_option_hide_raw_dimensions';
    var SETTING_KEY_OPTION_HIDE_FINAL_DIMENSIONS = 'cutlist_option_hide_final_dimensions';
    var SETTING_KEY_OPTION_HIDE_UNTYPED_MATERIAL_DIMENSIONS = 'cutlist_option_hide_untyped_material_dimensions';
    var SETTING_KEY_OPTION_HIDDEN_GROUP_IDS = 'cutlist_option_hidden_group_ids';
    var SETTING_KEY_OPTION_DIMENSION_COLUMN_ORDER_STRATEGY = 'cutlist_option_dimension_column_order_strategy';

    // Options defaults

    var OPTION_DEFAULT_AUTO_ORIENT = true;
    var OPTION_DEFAULT_SMART_MATERIAL = true;
    var OPTION_DEFAULT_PART_NUMBER_WITH_LETTERS = true;
    var OPTION_DEFAULT_PART_NUMBER_SEQUENCE_BY_GROUP = true;
    var OPTION_DEFAULT_PART_ORDER_STRATEGY = '-thickness>-length>-width>-count>name';

    var OPTION_DEFAULT_COL_SEP = 0;     // \t
    var OPTION_DEFAULT_ENCODING = 0;    // UTF-8

    var OPTION_DEFAULT_HIDE_RAW_DIMENSIONS = false;
    var OPTION_DEFAULT_HIDE_FINAL_DIMENSIONS = false;
    var OPTION_DEFAULT_HIDE_UNTYPED_MATERIAL_DIMENSIONS = false;
    var OPTION_DEFAULT_HIDDEN_GROUP_IDS = [];
    var OPTION_DEFAULT_DIMENSION_COLUMN_ORDER_STRATEGY = 'length>width>thickness';

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
        LadbAbstractTab.call(this, element, options, toolbox);

        this.generateAt = null;
        this.filename = null;
        this.groups = [];
        this.materialUsages = [];
        this.editedPart = null;
        this.editedGroup = null;

        this.$header = $('.ladb-header', this.$element);
        this.$fileTabs = $('.ladb-file-tabs', this.$header);
        this.$btnGenerate = $('#ladb_btn_generate', this.$header);
        this.$btnPrint = $('#ladb_btn_print', this.$header);
        this.$btnExport = $('#ladb_btn_export', this.$header);
        this.$itemShowAllGroups = $('#ladb_item_show_all_groups', this.$header);
        this.$itemNumbersSave = $('#ladb_item_numbers_save', this.$header);
        this.$itemNumbersReset = $('#ladb_item_numbers_reset', this.$header);
        this.$itemOptions = $('#ladb_item_options', this.$header);

        this.$panelHelp = $('.ladb-panel-help', this.$element);
        this.$page = $('.ladb-page', this.$element);

    };
    LadbTabCutlist.prototype = new LadbAbstractTab;

    LadbTabCutlist.DEFAULTS = {};

    // Cutlist /////

    LadbTabCutlist.prototype.generateCutlist = function (callback) {
        var that = this;

        this.groups = [];
        this.$page.empty();
        this.$btnGenerate.prop('disabled', true);

        rubyCallCommand('cutlist_generate', this.generateOptions, function(response) {

            that.generateAt = new Date().getTime() / 1000;

            var errors = response.errors;
            var warnings = response.warnings;
            var tips = response.tips;
            var is_metric = response.is_metric;
            var filename = response.filename;
            var pageLabel = response.page_label;
            var materialUsages = response.material_usages;
            var groups = response.groups;

            // Keep usefull data
            that.filename = filename;
            that.groups = groups;
            that.materialUsages = materialUsages;

            // Update filename
            that.$fileTabs.empty();
            that.$fileTabs.append(Twig.twig({ ref: "tabs/cutlist/_file-tab.twig" }).render({
                filename: filename,
                pageLabel: pageLabel,
                generateAt: that.generateAt
            }));

            // Hide help panel
            that.$panelHelp.hide();

            // Update buttons and items state
            that.$btnPrint.prop('disabled', groups.length == 0);
            that.$btnExport.prop('disabled', groups.length == 0);
            that.$itemShowAllGroups.closest('li').toggleClass('disabled', groups.length == 0);
            that.$itemNumbersSave.closest('li').toggleClass('disabled', groups.length == 0);
            that.$itemNumbersReset.closest('li').toggleClass('disabled', groups.length == 0);

            // Update page
            that.$page.empty();
            that.$page.append(Twig.twig({ ref: "tabs/cutlist/_list.twig" }).render({
                showThicknessSeparators: that.generateOptions.part_order_strategy.startsWith('thickness') || that.generateOptions.part_order_strategy.startsWith('-thickness'),
                dimensionColumnOrderStrategy: that.uiOptions.dimension_column_order_strategy.split('>'),
                uiOptions: that.uiOptions,
                errors: errors,
                warnings: warnings,
                tips: tips,
                is_metric: is_metric,
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
                $('html, body').animate({ scrollTop: $(target).offset().top - that.$header.outerHeight(true) - 20 }, 200).promise().then(function() {
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
            $('a.ladb-item-numbers-save', that.$page).on('click', function() {
                var $group = $(this).closest('.ladb-cutlist-group');
                var groupId = $group.data('group-id');
                var wTop = $group.offset().top - $(window).scrollTop();
                that.numbersSave({ group_id: groupId }, function() {
                    $('html, body').animate({ scrollTop: $('#ladb_group_' + groupId).offset().top - wTop }, 0);
                });
                $(this).blur();
            });
            $('a.ladb-item-numbers-reset', that.$page).on('click', function() {
                var $group = $(this).closest('.ladb-cutlist-group');
                var groupId = $group.data('group-id');
                var wTop = $group.offset().top - $(window).scrollTop();
                that.numbersReset({ group_id: groupId }, function() {
                    $('html, body').animate({ scrollTop: $('#ladb_group_' + groupId).offset().top - wTop }, 0);
                });
                $(this).blur();
            });
            $('a.ladb-item-hide-all-other-groups', that.$page).on('click', function() {
                var $group = $(this).closest('.ladb-cutlist-group');
                var groupId = $group.data('group-id');
                that.hideAllGroups(groupId);
                $('html, body').animate({ scrollTop: $group.offset().top - that.$header.outerHeight(true) - 20 }, 200).promise();
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

            // Stick header
            that.$header.stick_in_parent();

            // Callback
            if (callback && typeof callback == 'function') {
                callback();
            }

        });

    };

    LadbTabCutlist.prototype.exportCutlist = function () {
        var that = this;

        var $modal = that.appendModalInside('ladb_cutlist_modal_export', 'tabs/cutlist/_modal-export.twig');

        // Fetch UI elements
        var $selectColSep = $('#ladb_cutlist_export_select_col_sep', $modal);
        var $selectEncoding = $('#ladb_cutlist_export_select_encoding', $modal);
        var $btnExport = $('#ladb_cutlist_export', $modal);

        // Bind select
        $selectColSep.val(that.exportOptions.col_sep);
        $selectColSep.selectpicker(SELECT_PICKER_OPTIONS);
        $selectEncoding.val(that.exportOptions.encoding);
        $selectEncoding.selectpicker(SELECT_PICKER_OPTIONS);

        // Bind buttons
        $btnExport.on('click', function() {

            that.exportOptions.col_sep = $selectColSep.val();
            that.exportOptions.encoding = $selectEncoding.val();

            // Store options
            that.toolbox.setSettings([
                { key:SETTING_KEY_OPTION_COL_SEP, value:that.exportOptions.col_sep },
                { key:SETTING_KEY_OPTION_ENCODING, value:that.exportOptions.encoding }
            ]);

            rubyCallCommand('cutlist_export', $.extend(that.exportOptions, that.uiOptions), function(response) {

                var i;

                if (response.errors) {
                    for (i = 0; i < response.errors.length; i++) {
                        that.toolbox.notify('<i class="ladb-toolbox-icon-warning"></i> ' + i18next.t(response.errors[i]), 'error');
                    }
                }
                if (response.warnings) {
                    for (i = 0; i < response.warnings.length; i++) {
                        that.toolbox.notify('<i class="ladb-toolbox-icon-warning"></i> ' + i18next.t(response.warnings[i]), 'warning');
                    }
                }
                if (response.export_path) {
                    that.toolbox.notify(i18next.t('tab.cutlist.success.exported_to', { export_path: response.export_path }), 'success', [
                        Noty.button(i18next.t('default.open'), 'btn btn-default', function () {

                            rubyCallCommand('core_open_external_file', {
                                path: response.export_path
                            });

                        })
                    ]);
                }

            });

            // Hide modal
            $modal.modal('hide');

        });

        // Show modal
        $modal.modal('show');

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

            rubyCallCommand('cutlist_part_get_thumbnail', part, function(response) {

                var thumbnailFile = response['thumbnail_file'];

                // Keep the edited part
                that.editedPart = part;

                var $modal = that.appendModalInside('ladb_cutlist_modal_part', 'tabs/cutlist/_modal-part.twig', {
                    part: part,
                    thumbnailFile: thumbnailFile,
                    materialUsages: that.materialUsages
                });

                var isOwnedMaterial = true;
                for (var i = 0; i < part.material_origins.length; i++) {
                    if (part.material_origins[i] != 1) {    // 1 = MATERIAL_ORIGIN_OWNED
                        isOwnedMaterial = false;
                        break;
                    }
                }

                // Fetch UI elements
                var $inputName = $('#ladb_cutlist_part_input_name', $modal);
                var $selectMaterialName = $('#ladb_cutlist_part_select_material_name', $modal);
                var $selectCumulable = $('#ladb_cutlist_part_select_cumulable', $modal);
                var $inputOrientationLockedOnAxis = $('#ladb_cutlist_part_input_orientation_locked_on_axis', $modal);
                var $btnUpdate = $('#ladb_cutlist_part_update', $modal);

                // Bind select
                if (isOwnedMaterial) {
                    $selectMaterialName.val(part.material_name);
                }
                $selectMaterialName.selectpicker(SELECT_PICKER_OPTIONS);
                $selectCumulable.val(part.cumulable);
                $selectCumulable.selectpicker(SELECT_PICKER_OPTIONS);

                // Bind buttons
                $btnUpdate.on('click', function () {

                    that.editedPart.name = $inputName.val();
                    that.editedPart.material_name = $selectMaterialName.val();
                    that.editedPart.cumulable = $selectCumulable.val();
                    that.editedPart.orientation_locked_on_axis = $inputOrientationLockedOnAxis.is(':checked');

                    rubyCallCommand('cutlist_part_update', that.editedPart, function() {

                        var partId = that.editedPart.id;
                        var wTop = $('#ladb_part_' + partId).offset().top - $(window).scrollTop();

                        // Reset edited part
                        that.editedPart = null;

                        // Hide modal
                        $modal.modal('hide');

                        // Refresh the list
                        that.generateCutlist(function() {

                            // Try to scroll to the edited part's row
                            var $part = $('#ladb_part_' + partId);
                            if ($part.length > 0) {
                                $part.effect("highlight", {}, 1500);
                                $('html, body').animate({ scrollTop: $part.offset().top - wTop }, 0);
                            }

                        });

                    });

                });

                // Show modal
                $modal.modal('show');

                // Setup popovers
                that.toolbox.setupPopovers();

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

            var $modal = that.appendModalInside('ladb_cutlist_modal_group', 'tabs/cutlist/_modal-group.twig', {
                group: group,
                materialUsages: that.materialUsages
            });

            // Fetch UI elements
            var $selectMaterialName = $('#ladb_cutlist_group_select_material_name', $modal);
            var $btnUpdate = $('#ladb_cutlist_group_update', $modal);

            // Bind select
            $selectMaterialName.val(group.material_name);
            $selectMaterialName.selectpicker(SELECT_PICKER_OPTIONS);

            // Bind buttons
            $btnUpdate.on('click', function () {

                // Fetch form values
                that.editedGroup.material_name = $selectMaterialName.val();

                rubyCallCommand('cutlist_group_update', that.editedGroup, function() {

                    // Reset edited group
                    that.editedGroup = null;

                    // Hide modal
                    $modal.modal('hide');

                    // Refresh the list
                    that.generateCutlist();

                });

            });

            // Show modal
            $modal.modal('show');

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

    LadbTabCutlist.prototype.hideAllGroups = function (exceptedGroupId) {
        var that = this;
        $('.ladb-cutlist-group', this.$page).each(function() {
            var groupId = $(this).data('group-id');
            if (exceptedGroupId && groupId != exceptedGroupId) {
                that.hideGroup($(this));
            }
        });
    };

    // Numbers /////

    LadbTabCutlist.prototype.numbersSave = function (params, callback) {
        var that = this;

        rubyCallCommand('cutlist_numbers_save', params ? params : {}, function() {
            that.generateCutlist(callback);
        });

    };

    LadbTabCutlist.prototype.numbersReset = function (params, callback) {
        var that = this;

        rubyCallCommand('cutlist_numbers_reset', params ? params : {}, function() {
            that.generateCutlist(callback);
        });

    };

    // Options /////

    LadbTabCutlist.prototype.editOptions = function () {
        var that = this;

        var $modal = that.appendModalInside('ladb_cutlist_modal_options', 'tabs/cutlist/_modal-options.twig');

        // Fetch UI elements
        var $inputAutoOrient = $('#ladb_input_auto_orient', $modal);
        var $inputSmartMaterial = $('#ladb_input_smart_material', $modal);
        var $inputPartNumberWithLetters = $('#ladb_input_part_number_with_letters', $modal);
        var $inputPartNumberSequenceByGroup = $('#ladb_input_part_number_sequence_by_group', $modal);
        var $inputHideRawDimensions = $('#ladb_input_hide_raw_dimensions', $modal);
        var $inputHideFinalDimensions = $('#ladb_input_hide_final_dimensions', $modal);
        var $inputHideUntypedMaterialDimensions = $('#ladb_input_hide_untyped_material_dimensions', $modal);
        var $sortablePartOrderStrategy = $('#ladb_sortable_part_order_strategy', $modal);
        var $sortableDimensionColumnOrderStrategy = $('#ladb_sortable_dimension_column_order_strategy', $modal);
        var $btnReset = $('#ladb_cutlist_options_reset', $modal);
        var $btnUpdate = $('#ladb_cutlist_options_update', $modal);

        // Define useful functions
        var populateOptionsInputs = function (generateOptions, uiOptions) {

            // Checkboxes

            $inputAutoOrient.prop('checked', generateOptions.auto_orient);
            $inputSmartMaterial.prop('checked', generateOptions.smart_material);
            $inputPartNumberWithLetters.prop('checked', generateOptions.part_number_with_letters);
            $inputPartNumberSequenceByGroup.prop('checked', generateOptions.part_number_sequence_by_group);
            $inputHideRawDimensions.prop('checked', uiOptions.hide_raw_dimensions);
            $inputHideFinalDimensions.prop('checked', uiOptions.hide_final_dimensions);
            $inputHideUntypedMaterialDimensions
                .prop('checked', uiOptions.hide_untyped_material_dimensions)
                .prop('disabled', uiOptions.hide_final_dimensions);

            // Sortables
            
            var properties, property, i;
            
            // Part order sortables

            properties = generateOptions.part_order_strategy.split('>');
            $sortablePartOrderStrategy.empty();
            for (i = 0; i < properties.length; i++) {
                property = properties[i];
                $sortablePartOrderStrategy.append(Twig.twig({ref: "tabs/cutlist/_option-part-order-strategy-property.twig"}).render({
                    order: property.startsWith('-') ? '-' : '',
                    property: property.startsWith('-') ? property.substr(1) : property
                }));
            }
            $sortablePartOrderStrategy.find('a').on('click', function() {
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
            });
            $sortablePartOrderStrategy.sortable({
                cursor: 'ns-resize',
                handle: '.ladb-handle'
            });

            // Dimension column order sortables

            properties = uiOptions.dimension_column_order_strategy.split('>');
            $sortableDimensionColumnOrderStrategy.empty();
            for (i = 0; i < properties.length; i++) {
                property = properties[i];
                $sortableDimensionColumnOrderStrategy.append(Twig.twig({ref: "tabs/cutlist/_option-dimension-column-order-strategy-property.twig"}).render({
                    property: property
                }));
            }
            $sortableDimensionColumnOrderStrategy.sortable({
                cursor: 'ns-resize',
                handle: '.ladb-handle'
            });

        };

        // Bind inputs
        $inputHideFinalDimensions.on('change', function () {
            $inputHideUntypedMaterialDimensions.prop('disabled', $(this).is(':checked'));
        });

        // Bind buttons
        $btnReset.on('click', function() {
            var generateOptions = $.extend($.extend({}, that.generateOptions), {
                auto_orient: OPTION_DEFAULT_AUTO_ORIENT,
                smart_material: OPTION_DEFAULT_SMART_MATERIAL,
                part_number_with_letters: OPTION_DEFAULT_PART_NUMBER_WITH_LETTERS,
                part_number_sequence_by_group: OPTION_DEFAULT_PART_NUMBER_SEQUENCE_BY_GROUP,
                part_order_strategy: OPTION_DEFAULT_PART_ORDER_STRATEGY
            });
            var uiOptions = $.extend($.extend({}, that.uiOptions), {
                hide_raw_dimensions: OPTION_DEFAULT_HIDE_RAW_DIMENSIONS,
                hide_final_dimensions: OPTION_DEFAULT_HIDE_FINAL_DIMENSIONS,
                hide_untyped_material_dimensions: OPTION_DEFAULT_HIDE_UNTYPED_MATERIAL_DIMENSIONS,
                dimension_column_order_strategy: OPTION_DEFAULT_DIMENSION_COLUMN_ORDER_STRATEGY
            });
            populateOptionsInputs(generateOptions, uiOptions);
        });
        $btnUpdate.on('click', function() {

            // Fetch options

            that.generateOptions.auto_orient = $inputAutoOrient.is(':checked');
            that.generateOptions.smart_material = $inputSmartMaterial.is(':checked');
            that.generateOptions.part_number_with_letters = $inputPartNumberWithLetters.is(':checked');
            that.generateOptions.part_number_sequence_by_group = $inputPartNumberSequenceByGroup.is(':checked');
            that.uiOptions.hide_raw_dimensions = $inputHideRawDimensions.is(':checked');
            that.uiOptions.hide_final_dimensions = $inputHideFinalDimensions.is(':checked');
            that.uiOptions.hide_untyped_material_dimensions = $inputHideUntypedMaterialDimensions.is(':checked');

            var properties = [];
            $sortablePartOrderStrategy.children('li').each(function () {
                properties.push($(this).data('property'));
            });
            that.generateOptions.part_order_strategy = properties.join('>');

            properties = [];
            $sortableDimensionColumnOrderStrategy.children('li').each(function () {
                properties.push($(this).data('property'));
            });
            that.uiOptions.dimension_column_order_strategy = properties.join('>');

            // Store options
            that.toolbox.setSettings([
                { key:SETTING_KEY_OPTION_AUTO_ORIENT, value:that.generateOptions.auto_orient },
                { key:SETTING_KEY_OPTION_SMART_MATERIAL, value:that.generateOptions.smart_material },
                { key:SETTING_KEY_OPTION_PART_NUMBER_WITH_LETTERS, value:that.generateOptions.part_number_with_letters },
                { key:SETTING_KEY_OPTION_PART_NUMBER_SEQUENCE_BY_GROUP, value:that.generateOptions.part_number_sequence_by_group },
                { key:SETTING_KEY_OPTION_PART_ORDER_STRATEGY, value:that.generateOptions.part_order_strategy },
                { key:SETTING_KEY_OPTION_HIDE_RAW_DIMENSIONS, value:that.uiOptions.hide_raw_dimensions },
                { key:SETTING_KEY_OPTION_HIDE_FINAL_DIMENSIONS, value:that.uiOptions.hide_final_dimensions },
                { key:SETTING_KEY_OPTION_HIDE_UNTYPED_MATERIAL_DIMENSIONS, value:that.uiOptions.hide_untyped_material_dimensions },
                { key:SETTING_KEY_OPTION_DIMENSION_COLUMN_ORDER_STRATEGY, value:that.uiOptions.dimension_column_order_strategy }
            ]);

            // Hide modal
            $modal.modal('hide');

            // Refresh the list if it has already been generated
            if (that.groups.length > 0) {
                that.generateCutlist();
            }

        });

        // Populate inputs
        populateOptionsInputs(that.generateOptions, that.uiOptions);

        // Show modal
        $modal.modal('show');

        // Setup popovers
        this.toolbox.setupPopovers();

    };

    // Internals /////

    LadbTabCutlist.prototype.showOutdated = function (messageI18nKey) {
        var that = this;

        var $modal = this.appendModalInside('ladb_cutlist_modal_outdated', 'tabs/cutlist/_modal-outdated.twig', {
            messageI18nKey: messageI18nKey
        });

        // Fetch UI elements
        var $btnGenerate = $('#ladb_cutlist_outdated_generate', $modal);

        // Bind buttons
        $btnGenerate.on('click', function () {
            $modal.modal('hide');
            that.generateCutlist();
        });

        // Show modal
        $modal.modal('show');

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
        this.$btnExport.on('click', function () {
            that.exportCutlist();
            this.blur();
        });
        this.$itemShowAllGroups.on('click', function () {
            that.showAllGroups();
            this.blur();
        });
        this.$itemNumbersSave.on('click', function () {
            that.numbersSave();
            this.blur();
        });
        this.$itemNumbersReset.on('click', function () {
            that.numbersReset();
            this.blur();
        });
        this.$itemOptions.on('click', function () {
            that.editOptions();
            this.blur();
        });

        // Events

        addEventCallback([ 'on_new_model', 'on_open_model', 'on_activate_model' ], function(params) {
            if (that.generateAt) {
                that.showOutdated('core.event.model_change');
            }
        });
        addEventCallback('on_material_change', function() {
            if (that.generateAt) {
                that.showOutdated('core.event.material_change');
            }
        });
        addEventCallback([ 'on_selection_bulk_change', 'on_selection_cleared' ], function() {
            if (that.generateAt) {
                that.showOutdated('core.event.selection_change');
            }
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

            SETTING_KEY_OPTION_COL_SEP,
            SETTING_KEY_OPTION_ENCODING,

            SETTING_KEY_OPTION_HIDE_UNTYPED_MATERIAL_DIMENSIONS,
            SETTING_KEY_OPTION_HIDE_RAW_DIMENSIONS,
            SETTING_KEY_OPTION_HIDE_FINAL_DIMENSIONS,
            SETTING_KEY_OPTION_HIDDEN_GROUP_IDS,
            SETTING_KEY_OPTION_DIMENSION_COLUMN_ORDER_STRATEGY

        ], function() {

            that.generateOptions = {
                auto_orient: that.toolbox.getSetting(SETTING_KEY_OPTION_AUTO_ORIENT, OPTION_DEFAULT_AUTO_ORIENT),
                smart_material: that.toolbox.getSetting(SETTING_KEY_OPTION_SMART_MATERIAL, OPTION_DEFAULT_SMART_MATERIAL),
                part_number_with_letters: that.toolbox.getSetting(SETTING_KEY_OPTION_PART_NUMBER_WITH_LETTERS, OPTION_DEFAULT_PART_NUMBER_WITH_LETTERS),
                part_number_sequence_by_group: that.toolbox.getSetting(SETTING_KEY_OPTION_PART_NUMBER_SEQUENCE_BY_GROUP, OPTION_DEFAULT_PART_NUMBER_SEQUENCE_BY_GROUP),
                part_order_strategy: that.toolbox.getSetting(SETTING_KEY_OPTION_PART_ORDER_STRATEGY, OPTION_DEFAULT_PART_ORDER_STRATEGY)
            };

            that.exportOptions = {
                col_sep: that.toolbox.getSetting(SETTING_KEY_OPTION_COL_SEP, OPTION_DEFAULT_COL_SEP),
                encoding: that.toolbox.getSetting(SETTING_KEY_OPTION_ENCODING, OPTION_DEFAULT_ENCODING)
            };

            that.uiOptions = {
                hide_raw_dimensions: that.toolbox.getSetting(SETTING_KEY_OPTION_HIDE_RAW_DIMENSIONS, OPTION_DEFAULT_HIDE_RAW_DIMENSIONS),
                hide_final_dimensions: that.toolbox.getSetting(SETTING_KEY_OPTION_HIDE_FINAL_DIMENSIONS, OPTION_DEFAULT_HIDE_FINAL_DIMENSIONS),
                hide_untyped_material_dimensions: that.toolbox.getSetting(SETTING_KEY_OPTION_HIDE_UNTYPED_MATERIAL_DIMENSIONS, OPTION_DEFAULT_HIDE_UNTYPED_MATERIAL_DIMENSIONS),
                hidden_group_ids: that.toolbox.getSetting(SETTING_KEY_OPTION_HIDDEN_GROUP_IDS, OPTION_DEFAULT_HIDDEN_GROUP_IDS),
                dimension_column_order_strategy: that.toolbox.getSetting(SETTING_KEY_OPTION_DIMENSION_COLUMN_ORDER_STRATEGY, OPTION_DEFAULT_DIMENSION_COLUMN_ORDER_STRATEGY)
            };

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
                if (undefined === options.toolbox) {
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
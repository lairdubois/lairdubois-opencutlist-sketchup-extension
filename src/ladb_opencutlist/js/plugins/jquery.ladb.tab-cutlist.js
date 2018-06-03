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

    var SETTING_KEY_OPTION_KERF = 'cutlist_option_kerf';
    var SETTING_KEY_OPTION_TRIMMING = 'cutlist_option_trimming';
    var SETTING_KEY_OPTION_BASE_SHEET_LENGTH = 'cutlist_option_base_sheet_length';
    var SETTING_KEY_OPTION_BASE_SHEET_WIDTH = 'cutlist_option_base_sheet_width';
    var SETTING_KEY_OPTION_ROTATABLE = 'cutlist_option_rotatable';
    var SETTING_KEY_OPTION_PRESORT = 'cutlist_option_presort';
    var SETTING_KEY_OPTION_STACKING = 'cutlist_option_stacking';

    var SETTING_KEY_OPTION_HIDE_RAW_DIMENSIONS = 'cutlist_option_hide_raw_dimensions';
    var SETTING_KEY_OPTION_HIDE_FINAL_DIMENSIONS = 'cutlist_option_hide_final_dimensions';
    var SETTING_KEY_OPTION_HIDE_UNTYPED_MATERIAL_DIMENSIONS = 'cutlist_option_hide_untyped_material_dimensions';
    var SETTING_KEY_OPTION_DIMENSION_COLUMN_ORDER_STRATEGY = 'cutlist_option_dimension_column_order_strategy';
    var SETTING_KEY_OPTION_HIDDEN_GROUP_IDS = 'cutlist_option_hidden_group_ids';

    // Options defaults

    var OPTION_DEFAULT_AUTO_ORIENT = true;
    var OPTION_DEFAULT_SMART_MATERIAL = true;
    var OPTION_DEFAULT_PART_NUMBER_WITH_LETTERS = true;
    var OPTION_DEFAULT_PART_NUMBER_SEQUENCE_BY_GROUP = true;
    var OPTION_DEFAULT_PART_ORDER_STRATEGY = '-thickness>-length>-width>-count>name';

    var OPTION_DEFAULT_COL_SEP = 0;     // \t
    var OPTION_DEFAULT_ENCODING = 0;    // UTF-8

    var OPTION_DEFAULT_KERF = '3mm';
    var OPTION_DEFAULT_TRIMMING = '10mm';
    var OPTION_DEFAULT_BASE_SHEET_LENGTH = '2800mm';
    var OPTION_DEFAULT_BASE_SHEET_WIDTH = '2070mm';
    var OPTION_DEFAULT_ROTATABLE = false;
    var OPTION_DEFAULT_PRESORT = 1;     // PRESORT_WIDTH_DECR
    var OPTION_DEFAULT_STACKING = 0;    // STACKING_NONE

    var OPTION_DEFAULT_HIDE_RAW_DIMENSIONS = false;
    var OPTION_DEFAULT_HIDE_FINAL_DIMENSIONS = false;
    var OPTION_DEFAULT_HIDE_UNTYPED_MATERIAL_DIMENSIONS = false;
    var OPTION_DEFAULT_DIMENSION_COLUMN_ORDER_STRATEGY = 'length>width>thickness';
    var OPTION_DEFAULT_HIDDEN_GROUP_IDS = [];

    // Select picker options

    var SELECT_PICKER_OPTIONS = {
        size: 10,
        iconBase: 'ladb-opencutlist-icon',
        tickIcon: 'ladb-opencutlist-icon-tick',
        showTick: true
    };

    // CLASS DEFINITION
    // ======================

    var LadbTabCutlist = function (element, options, opencutlist) {
        LadbAbstractTab.call(this, element, options, opencutlist);

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
            var length_unit = response.length_unit;
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
                generateAt: that.generateAt,
                length_unit: length_unit
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
            that.opencutlist.setupTooltips();

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
                that.opencutlist.setSetting(SETTING_KEY_OPTION_HIDDEN_GROUP_IDS, that.uiOptions.hidden_group_ids, 2 /* SETTINGS_RW_STRATEGY_MODEL */);
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
                that.$baseSlide.animate({ scrollTop: $(target).offset().top - that.$header.outerHeight(true) - 20 }, 200).promise().then(function() {
                    $(target).effect("highlight", {}, 1500);
                });
                $(this).blur();
                return false;
            });
            $('a.ladb-item-edit-material', that.$page).on('click', function() {
                var $group = $(this).closest('.ladb-cutlist-group');
                var groupId = $group.data('group-id');
                var group = that.findGroupById(groupId);
                if (group) {
                    that.opencutlist.executeCommandOnTab('materials', 'edit_material', {
                        material_id: group.material_id
                    });
                }
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
                that.$baseSlide.animate({ scrollTop: $group.offset().top - that.$header.outerHeight(true) - 20 }, 200).promise();
                $(this).blur();
            });
            $('a.ladb-item-numbers-save', that.$page).on('click', function() {
                var $group = $(this).closest('.ladb-cutlist-group');
                var groupId = $group.data('group-id');
                var wTop = $group.offset().top - $(window).scrollTop();
                that.numbersSave({ group_id: groupId }, function() {
                    that.$baseSlide.animate({ scrollTop: $('#ladb_group_' + groupId).offset().top - wTop }, 0);
                });
                $(this).blur();
            });
            $('a.ladb-item-numbers-reset', that.$page).on('click', function() {
                var $group = $(this).closest('.ladb-cutlist-group');
                var groupId = $group.data('group-id');
                var wTop = $group.offset().top - $(window).scrollTop();
                that.numbersReset({ group_id: groupId }, function() {
                    that.$baseSlide.animate({ scrollTop: $('#ladb_group_' + groupId).offset().top - wTop }, 0);
                });
                $(this).blur();
            });
            $('button.ladb-btn-group-cuttingdiagram', that.$page).on('click', function() {
                var $group = $(this).closest('.ladb-cutlist-group');
                var groupId = $group.data('group-id');
                that.cuttingdiagramGroup(groupId);
                $(this).blur();
            });
            $('a.ladb-btn-highlight-part', that.$page).on('click', function() {
                $(this).blur();
                var partId = $(this).data('part-id');
                that.highlightPart(partId);
                return false;
            });
            $('a.ladb-btn-edit-part', that.$page).on('click', function() {
                var partId = $(this).data('part-id');
                that.editPart(partId);
                $(this).blur();
                return false;
            });
            $('.ladb-cutlist-row', that.$page).on('click', function() {
                $('.ladb-click-tool', $(this)).click();
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

            // Fetch options

            that.exportOptions.col_sep = $selectColSep.val();
            that.exportOptions.encoding = $selectEncoding.val();

            // Store options
            that.opencutlist.setSettings([
                { key:SETTING_KEY_OPTION_COL_SEP, value:that.exportOptions.col_sep },
                { key:SETTING_KEY_OPTION_ENCODING, value:that.exportOptions.encoding }
            ], 0 /* SETTINGS_RW_STRATEGY_GLOBAL */);

            rubyCallCommand('cutlist_export', $.extend(that.exportOptions, that.uiOptions), function(response) {

                var i;

                if (response.errors) {
                    for (i = 0; i < response.errors.length; i++) {
                        that.opencutlist.notify('<i class="ladb-opencutlist-icon-warning"></i> ' + i18next.t(response.errors[i]), 'error');
                    }
                }
                if (response.warnings) {
                    for (i = 0; i < response.warnings.length; i++) {
                        that.opencutlist.notify('<i class="ladb-opencutlist-icon-warning"></i> ' + i18next.t(response.warnings[i]), 'warning');
                    }
                }
                if (response.export_path) {
                    that.opencutlist.notify(i18next.t('tab.cutlist.success.exported_to', { export_path: response.export_path }), 'success', [
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

    LadbTabCutlist.prototype.highlightPart = function (id) {
        var that = this;

        var part = this.findPartById(id);
        if (part) {

            rubyCallCommand('cutlist_part_highlight', part, function (response) {

                if (response['errors']) {
                    that.opencutlist.notify('<i class="ladb-opencutlist-icon-warning"></i> ' + i18next.t('tab.cutlist.highlight_error', {'name': part.name}), 'error');
                } else {
                    that.opencutlist.minimize();
                }

            });

        }

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
                var $btnHighlight = $('#ladb_cutlist_part_highlight', $modal);
                var $btnUpdate = $('#ladb_cutlist_part_update', $modal);

                // Bind select
                if (isOwnedMaterial) {
                    $selectMaterialName.val(part.material_name);
                }
                $selectMaterialName.selectpicker(SELECT_PICKER_OPTIONS);
                $selectCumulable.val(part.cumulable);
                $selectCumulable.selectpicker(SELECT_PICKER_OPTIONS);

                // Bind buttons
                $btnHighlight.on('click', function () {
                    this.blur();
                    that.highlightPart(id);
                    return false;
                });
                $btnUpdate.on('click', function () {

                    that.editedPart.name = $inputName.val();
                    that.editedPart.material_name = $selectMaterialName.val();
                    that.editedPart.cumulable = $selectCumulable.val();
                    that.editedPart.orientation_locked_on_axis = $inputOrientationLockedOnAxis.is(':checked');

                    rubyCallCommand('cutlist_part_update', that.editedPart, function(response) {

                        if (response['errors']) {

                            that.opencutlist.notifyErrors(response['errors']);

                        } else {

                            var partId = that.editedPart.id;
                            var wTop = $('#ladb_part_' + partId).offset().top - $(window).scrollTop();

                            // Refresh the list
                            that.generateCutlist(function() {

                                // Try to scroll to the edited part's row
                                var $part = $('#ladb_part_' + partId);
                                if ($part.length > 0) {
                                    $part.effect("highlight", {}, 1500);
                                    that.$baseSlide.animate({ scrollTop: $part.offset().top - wTop }, 0);
                                }

                            });

                        }

                        // Reset edited part
                        that.editedPart = null;

                        // Hide modal
                        $modal.modal('hide');

                    });

                });

                // Show modal
                $modal.modal('show');

                // Setup popovers
                that.opencutlist.setupPopovers();

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

                rubyCallCommand('cutlist_group_update', that.editedGroup, function(response) {

                    if (response['errors']) {

                        that.opencutlist.notifyErrors(response['errors']);

                    } else {

                        // Refresh the list
                        that.generateCutlist();

                    }

                    // Reset edited group
                    that.editedGroup = null;

                    // Hide modal
                    $modal.modal('hide');

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
        $i.addClass('ladb-opencutlist-icon-eye-close');
        $i.removeClass('ladb-opencutlist-icon-eye-open');

        var idx = this.uiOptions.hidden_group_ids.indexOf(groupId);
        if (idx != -1) {
            this.uiOptions.hidden_group_ids.splice(idx, 1);
            this.opencutlist.setSetting(SETTING_KEY_OPTION_HIDDEN_GROUP_IDS, this.uiOptions.hidden_group_ids, 2 /* SETTINGS_RW_STRATEGY_MODEL */);
        }

    };

    LadbTabCutlist.prototype.hideGroup = function ($group) {
        var groupId = $group.data('group-id');
        var $btn = $('.ladb-btn-toggle-no-print', $group);
        var $i = $('i', $btn);

        $group.addClass('no-print');
        $i.removeClass('ladb-opencutlist-icon-eye-close');
        $i.addClass('ladb-opencutlist-icon-eye-open');

        var idx = this.uiOptions.hidden_group_ids.indexOf(groupId);
        if (idx == -1) {
            this.uiOptions.hidden_group_ids.push(groupId);
            this.opencutlist.setSetting(SETTING_KEY_OPTION_HIDDEN_GROUP_IDS, this.uiOptions.hidden_group_ids, 2 /* SETTINGS_RW_STRATEGY_MODEL */);
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

    LadbTabCutlist.prototype.cuttingdiagramGroup = function (groupId) {
        var that = this;

        var group = this.findGroupById(groupId);

        rubyCallCommand('materials_get_attributes_command', { name: group.material_name }, function (response) {

            var $modal = that.appendModalInside('ladb_cutlist_modal_cuttingdiagram', 'tabs/cutlist/_modal-cuttingdiagram.twig', $.extend({ material_attributes: response }, { group: group }));

            // Fetch UI elements
            var $selectSizes = $('#ladb_select_sizes', $modal);
            var $inputBaseSheetLength = $('#ladb_input_base_sheet_length', $modal);
            var $inputBaseSheetWidth = $('#ladb_input_base_sheet_width', $modal);
            var $inputKerf = $('#ladb_input_kerf', $modal);
            var $inputTrimming = $('#ladb_input_trimming', $modal);
            var $inputRotatable = $('#ladb_input_rotatable', $modal);
            var $selectPresort = $('#ladb_select_presort', $modal);
            var $selectStacking = $('#ladb_select_stacking', $modal);
            var $btnEditMaterial = $('#ladb_edit_material', $modal);
            var $btnCuttingdiagram = $('#ladb_cutlist_cuttingdiagram', $modal);

            $inputKerf.val(that.cuttingdiagramOptions.kerf);
            $inputTrimming.val(that.cuttingdiagramOptions.trimming);
            $selectPresort.val(that.cuttingdiagramOptions.presort);
            $selectStacking.val(that.cuttingdiagramOptions.stacking);

            // Bind select
            $selectSizes.selectpicker(SELECT_PICKER_OPTIONS);
            $selectPresort.selectpicker(SELECT_PICKER_OPTIONS);
            $selectStacking.selectpicker(SELECT_PICKER_OPTIONS);

            var fnSelectSize = function() {
                var value = $selectSizes.val();
                if (value == '0x0') {
                    $('#ladb_base_sheet_values').show();
                    $inputBaseSheetLength.val(that.cuttingdiagramOptions.base_sheet_length);
                    $inputBaseSheetWidth.val(that.cuttingdiagramOptions.base_sheet_width);
                    $inputRotatable.prop('checked', that.cuttingdiagramOptions.rotatable);
                } else {
                    $('#ladb_base_sheet_values').hide();
                    console.log(value);
                    var sizeAndGrained = value.split('|');
                    var size = sizeAndGrained[0].split('x');
                    $inputBaseSheetLength.val(size[0]);
                    $inputBaseSheetWidth.val(size[1]);
                    var grained = sizeAndGrained[1] === 'true';
                    $inputRotatable.prop('checked', !grained);
                }
            };

            $selectSizes.on('changed.bs.select', function (e) {
                fnSelectSize();
            });
            fnSelectSize();

            // Bind buttons
            $btnEditMaterial.on('click', function() {
                that.opencutlist.executeCommandOnTab('materials', 'edit_material', {
                    material_id: group.material_id
                });
            });
            $btnCuttingdiagram.on('click', function() {

                // Fetch options

                that.cuttingdiagramOptions.kerf = $inputKerf.val();
                that.cuttingdiagramOptions.trimming = $inputTrimming.val();
                that.cuttingdiagramOptions.base_sheet_length = $inputBaseSheetLength.val();
                that.cuttingdiagramOptions.base_sheet_width = $inputBaseSheetWidth.val();
                that.cuttingdiagramOptions.rotatable = $inputRotatable.is(':checked');
                that.cuttingdiagramOptions.presort = $selectPresort.val();
                that.cuttingdiagramOptions.stacking = $selectStacking.val();

                // Store options
                that.opencutlist.setSettings([
                    { key:SETTING_KEY_OPTION_KERF, value:that.cuttingdiagramOptions.kerf },
                    { key:SETTING_KEY_OPTION_TRIMMING, value:that.cuttingdiagramOptions.trimming },
                    { key:SETTING_KEY_OPTION_BASE_SHEET_LENGTH, value:that.cuttingdiagramOptions.base_sheet_length },
                    { key:SETTING_KEY_OPTION_BASE_SHEET_WIDTH, value:that.cuttingdiagramOptions.base_sheet_width },
                    { key:SETTING_KEY_OPTION_ROTATABLE, value:that.cuttingdiagramOptions.rotatable },
                    { key:SETTING_KEY_OPTION_PRESORT, value:that.cuttingdiagramOptions.presort },
                    { key:SETTING_KEY_OPTION_STACKING, value:that.cuttingdiagramOptions.stacking }
                ], 0 /* SETTINGS_RW_STRATEGY_GLOBAL */);

                rubyCallCommand('cutlist_group_cuttingdiagram', $.extend({ group_id: groupId }, that.cuttingdiagramOptions, that.uiOptions), function (response) {

                    var $slide = that.pushSlide('ladb_cutlist_slide_cuttingdiagram', 'tabs/cutlist/_slide-cuttingdiagram.twig', $.extend({ group: group }, response));

                    var $page = $('.ladb-page', $slide);
                    $page.load(response.cuttingdiagram_path);

                    var $btnBack = $('#ladb_btn_back', $slide);
                    $btnBack.on('click', function() {
                        that.popSlide();
                    });
                    var $btnPrint = $('#ladb_btn_print', $slide);
                    $btnPrint.on('click', function() {
                        window.print();
                    });

                    // if (response.cuttingdiagram_path) {
                    //     that.opencutlist.notify('DONE !', 'success', [
                    //         Noty.button(i18next.t('default.open'), 'btn btn-default', function () {
                    //
                    //             rubyCallCommand('core_open_external_file', {
                    //                 path: response.cuttingdiagram_path
                    //             });
                    //
                    //         })
                    //     ]);
                    // } else {
                    //     alert('blop ?');
                    // }

                });

                // Hide modal
                $modal.modal('hide');

            });

            // Show modal
            $modal.modal('show');

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

    LadbTabCutlist.prototype.loadOptions = function (callback) {
        var that = this;

        this.opencutlist.pullSettings([

                SETTING_KEY_OPTION_AUTO_ORIENT,
                SETTING_KEY_OPTION_SMART_MATERIAL,
                SETTING_KEY_OPTION_PART_NUMBER_WITH_LETTERS,
                SETTING_KEY_OPTION_PART_NUMBER_SEQUENCE_BY_GROUP,
                SETTING_KEY_OPTION_PART_ORDER_STRATEGY,

                SETTING_KEY_OPTION_COL_SEP,
                SETTING_KEY_OPTION_ENCODING,

                SETTING_KEY_OPTION_KERF,
                SETTING_KEY_OPTION_TRIMMING,
                SETTING_KEY_OPTION_BASE_SHEET_LENGTH,
                SETTING_KEY_OPTION_BASE_SHEET_WIDTH,
                SETTING_KEY_OPTION_ROTATABLE,
                SETTING_KEY_OPTION_PRESORT,
                SETTING_KEY_OPTION_STACKING,

                SETTING_KEY_OPTION_HIDE_UNTYPED_MATERIAL_DIMENSIONS,
                SETTING_KEY_OPTION_HIDE_RAW_DIMENSIONS,
                SETTING_KEY_OPTION_HIDE_FINAL_DIMENSIONS,
                SETTING_KEY_OPTION_DIMENSION_COLUMN_ORDER_STRATEGY,
                SETTING_KEY_OPTION_HIDDEN_GROUP_IDS

            ],
            3 /* SETTINGS_RW_STRATEGY_MODEL_GLOBAL */,
            function () {

                that.generateOptions = {
                    auto_orient: that.opencutlist.getSetting(SETTING_KEY_OPTION_AUTO_ORIENT, OPTION_DEFAULT_AUTO_ORIENT),
                    smart_material: that.opencutlist.getSetting(SETTING_KEY_OPTION_SMART_MATERIAL, OPTION_DEFAULT_SMART_MATERIAL),
                    part_number_with_letters: that.opencutlist.getSetting(SETTING_KEY_OPTION_PART_NUMBER_WITH_LETTERS, OPTION_DEFAULT_PART_NUMBER_WITH_LETTERS),
                    part_number_sequence_by_group: that.opencutlist.getSetting(SETTING_KEY_OPTION_PART_NUMBER_SEQUENCE_BY_GROUP, OPTION_DEFAULT_PART_NUMBER_SEQUENCE_BY_GROUP),
                    part_order_strategy: that.opencutlist.getSetting(SETTING_KEY_OPTION_PART_ORDER_STRATEGY, OPTION_DEFAULT_PART_ORDER_STRATEGY)
                };

                that.exportOptions = {
                    col_sep: that.opencutlist.getSetting(SETTING_KEY_OPTION_COL_SEP, OPTION_DEFAULT_COL_SEP),
                    encoding: that.opencutlist.getSetting(SETTING_KEY_OPTION_ENCODING, OPTION_DEFAULT_ENCODING)
                };

                that.cuttingdiagramOptions = {
                    kerf: that.opencutlist.getSetting(SETTING_KEY_OPTION_KERF, OPTION_DEFAULT_KERF),
                    trimming: that.opencutlist.getSetting(SETTING_KEY_OPTION_TRIMMING, OPTION_DEFAULT_TRIMMING),
                    base_sheet_length: that.opencutlist.getSetting(SETTING_KEY_OPTION_BASE_SHEET_LENGTH, OPTION_DEFAULT_BASE_SHEET_LENGTH),
                    base_sheet_width: that.opencutlist.getSetting(SETTING_KEY_OPTION_BASE_SHEET_WIDTH, OPTION_DEFAULT_BASE_SHEET_WIDTH),
                    rotatable: that.opencutlist.getSetting(SETTING_KEY_OPTION_ROTATABLE, OPTION_DEFAULT_ROTATABLE),
                    presort: that.opencutlist.getSetting(SETTING_KEY_OPTION_PRESORT, OPTION_DEFAULT_PRESORT),
                    stacking: that.opencutlist.getSetting(SETTING_KEY_OPTION_STACKING, OPTION_DEFAULT_STACKING)
                };

                that.uiOptions = {
                    hide_raw_dimensions: that.opencutlist.getSetting(SETTING_KEY_OPTION_HIDE_RAW_DIMENSIONS, OPTION_DEFAULT_HIDE_RAW_DIMENSIONS),
                    hide_final_dimensions: that.opencutlist.getSetting(SETTING_KEY_OPTION_HIDE_FINAL_DIMENSIONS, OPTION_DEFAULT_HIDE_FINAL_DIMENSIONS),
                    hide_untyped_material_dimensions: that.opencutlist.getSetting(SETTING_KEY_OPTION_HIDE_UNTYPED_MATERIAL_DIMENSIONS, OPTION_DEFAULT_HIDE_UNTYPED_MATERIAL_DIMENSIONS),
                    dimension_column_order_strategy: that.opencutlist.getSetting(SETTING_KEY_OPTION_DIMENSION_COLUMN_ORDER_STRATEGY, OPTION_DEFAULT_DIMENSION_COLUMN_ORDER_STRATEGY),
                    hidden_group_ids: that.opencutlist.getSetting(SETTING_KEY_OPTION_HIDDEN_GROUP_IDS, OPTION_DEFAULT_HIDDEN_GROUP_IDS)
                };

                // Callback
                if (callback && typeof(callback) == 'function') {
                    callback();
                }

            });

    };

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
                    $icon.addClass('ladb-opencutlist-icon-sort-asc');
                    $icon.removeClass('ladb-opencutlist-icon-sort-desc');
                } else {
                    property = '-' + property;
                    $icon.removeClass('ladb-opencutlist-icon-sort-asc');
                    $icon.addClass('ladb-opencutlist-icon-sort-desc');
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
            that.opencutlist.setSettings([
                { key:SETTING_KEY_OPTION_AUTO_ORIENT, value:that.generateOptions.auto_orient },
                { key:SETTING_KEY_OPTION_SMART_MATERIAL, value:that.generateOptions.smart_material },
                { key:SETTING_KEY_OPTION_PART_NUMBER_WITH_LETTERS, value:that.generateOptions.part_number_with_letters },
                { key:SETTING_KEY_OPTION_PART_NUMBER_SEQUENCE_BY_GROUP, value:that.generateOptions.part_number_sequence_by_group },
                { key:SETTING_KEY_OPTION_PART_ORDER_STRATEGY, value:that.generateOptions.part_order_strategy },
                { key:SETTING_KEY_OPTION_HIDE_RAW_DIMENSIONS, value:that.uiOptions.hide_raw_dimensions },
                { key:SETTING_KEY_OPTION_HIDE_FINAL_DIMENSIONS, value:that.uiOptions.hide_final_dimensions },
                { key:SETTING_KEY_OPTION_HIDE_UNTYPED_MATERIAL_DIMENSIONS, value:that.uiOptions.hide_untyped_material_dimensions },
                { key:SETTING_KEY_OPTION_DIMENSION_COLUMN_ORDER_STRATEGY, value:that.uiOptions.dimension_column_order_strategy }
            ], 3 /* SETTINGS_RW_STRATEGY_MODEL_GLOBAL */);

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
        this.opencutlist.setupPopovers();

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

            // Hide edit option model (if it exists)
            $('#ladb_cutlist_modal_options').modal('hide');

            // Reload options (from new active model)
            that.loadOptions();

        });
        addEventCallback('on_options_provider_changed', function() {
            if (that.generateAt) {
                that.showOutdated('core.event.options_change');
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

    LadbTabCutlist.prototype.init = function (initializedCallback) {
        var that = this;

        // Load Options
        this.loadOptions(function() {

            that.bind();

            // Callback
            if (initializedCallback && typeof(initializedCallback) == 'function') {
                initializedCallback(that.$element);
            }

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
                if (undefined === options.opencutlist) {
                    throw 'opencutlist option is mandatory.';
                }
                $this.data('ladb.tabCutlist', (data = new LadbTabCutlist(this, options, options.opencutlist)));
            }
            if (typeof option == 'string') {
                data[option](params);
            } else {
                data.init(option.initializedCallback);
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
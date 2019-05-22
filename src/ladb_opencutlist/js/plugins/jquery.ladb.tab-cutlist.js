+function ($) {
    'use strict';

    // CONSTANTS
    // ======================

    // Options keys

    var SETTING_KEY_OPTION_HIDE_LABELS = 'cutlist.option.hide_labels';
    var SETTING_KEY_OPTION_HIDE_RAW_DIMENSIONS = 'cutlist.option.hide_raw_dimensions';
    var SETTING_KEY_OPTION_HIDE_FINAL_DIMENSIONS = 'cutlist.option.hide_final_dimensions';
    var SETTING_KEY_OPTION_HIDE_UNTYPED_MATERIAL_DIMENSIONS = 'cutlist.option.hide_untyped_material_dimensions';
    var SETTING_KEY_OPTION_DIMENSION_COLUMN_ORDER_STRATEGY = 'cutlist.option.dimension_column_order_strategy';
    var SETTING_KEY_OPTION_HIDDEN_GROUP_IDS = 'cutlist.option.hidden_group_ids';

    var SETTING_KEY_OPTION_AUTO_ORIENT = 'cutlist.option.auto_orient';
    var SETTING_KEY_OPTION_SMART_MATERIAL = 'cutlist.option.smart_material';
    var SETTING_KEY_OPTION_PART_NUMBER_WITH_LETTERS = 'cutlist.option.part_number_with_letters';
    var SETTING_KEY_OPTION_PART_NUMBER_SEQUENCE_BY_GROUP = 'cutlist.option.part_number_sequence_by_group';
    var SETTING_KEY_OPTION_PART_ORDER_STRATEGY = 'cutlist.option.part_order_strategy';

    var SETTING_KEY_EXPORT_OPTION_SOURCE = 'cutlist.export.option.source';
    var SETTING_KEY_EXPORT_OPTION_COL_SEP = 'cutlist.export.option.col_sep';
    var SETTING_KEY_EXPORT_OPTION_ENCODING = 'cutlist.export.option.encoding';

    var SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_STD_SHEET = 'cutlist.cuttingdiagram2d.option.std_sheet';
    var SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_STD_SHEET_LENGTH = 'cutlist.cuttingdiagram2d.option.std_sheet_length';
    var SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_STD_SHEET_WIDTH = 'cutlist.cuttingdiagram2d.option.std_sheet_width';
    var SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_SCRAP_SHEET_SIZES = 'cutlist.cuttingdiagram2d.option.scrap_sheet_sizes';
    var SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_GRAINED = 'cutlist.cuttingdiagram2d.option.grained';
    var SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_SAW_KERF = 'cutlist.cuttingdiagram2d.option.saw_kerf';
    var SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_TRIMMING = 'cutlist.cuttingdiagram2d.option.trimming';
    var SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_PRESORT = 'cutlist.cuttingdiagram2d.option.presort';
    var SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_STACKING = 'cutlist.cuttingdiagram2d.option.stacking';
    var SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_BBOX_OPTIMIZATION = 'cutlist.cuttingdiagram2d.option.bbox_optimization';

    // Options defaults

    var OPTION_DEFAULT_HIDE_LABELS = false;
    var OPTION_DEFAULT_HIDE_RAW_DIMENSIONS = false;
    var OPTION_DEFAULT_HIDE_FINAL_DIMENSIONS = false;
    var OPTION_DEFAULT_HIDE_UNTYPED_MATERIAL_DIMENSIONS = false;
    var OPTION_DEFAULT_DIMENSION_COLUMN_ORDER_STRATEGY = 'length>width>thickness';
    var OPTION_DEFAULT_HIDDEN_GROUP_IDS = [];

    var OPTION_DEFAULT_AUTO_ORIENT = true;
    var OPTION_DEFAULT_SMART_MATERIAL = true;
    var OPTION_DEFAULT_PART_NUMBER_WITH_LETTERS = true;
    var OPTION_DEFAULT_PART_NUMBER_SEQUENCE_BY_GROUP = true;
    var OPTION_DEFAULT_PART_ORDER_STRATEGY = '-thickness>-length>-width>-count>name';

    var OPTION_DEFAULT_SOURCE = 0;     // cutlist
    var OPTION_DEFAULT_COL_SEP = 0;     // \t
    var OPTION_DEFAULT_ENCODING = 0;    // UTF-8

    var OPTION_DEFAULT_STD_SHEET = '';
    var OPTION_DEFAULT_STD_SHEET_LENGTH = '2800mm';
    var OPTION_DEFAULT_STD_SHEET_WIDTH = '2070mm';
    var OPTION_DEFAULT_GRAINED = false;
    var OPTION_DEFAULT_SCRAP_SHEET_SIZES = '';
    var OPTION_DEFAULT_SAW_KERF = '3mm';
    var OPTION_DEFAULT_TRIMMING = '10mm';
    var OPTION_DEFAULT_PRESORT = 1;             // PRESORT_WIDTH_DECR
    var OPTION_DEFAULT_STACKING = 0;            // STACKING_NONE
    var OPTION_DEFAULT_BBOX_OPTIMIZATION = 0;   // BBOX_OPTIMIZATION_NONE

    // Select picker options

    var SELECT_PICKER_OPTIONS = {
        size: 10,
        iconBase: 'ladb-opencutlist-icon',
        tickIcon: 'ladb-opencutlist-icon-tick',
        showTick: true
    };

    // Tokenfield options

    var TOKENFIELD_OPTIONS = {
        delimiter: ';',
        createTokensOnBlur: true,
        beautify: false
    };

    // CLASS DEFINITION
    // ======================

    var LadbTabCutlist = function (element, options, opencutlist) {
        LadbAbstractTab.call(this, element, options, opencutlist);

        this.generateFilters = {
          labels_filter: []
        };

        this.generateAt = null;
        this.isMetric = false;
        this.filename = null;
        this.pageLabel = null;
        this.lengthUnit = null;
        this.usedLabels = [];
        this.materialUsages = [];
        this.groups = [];
        this.editedPart = null;
        this.editedGroup = null;

        this.$header = $('.ladb-header', this.$element);
        this.$fileTabs = $('.ladb-file-tabs', this.$header);
        this.$btnGenerate = $('#ladb_btn_generate', this.$header);
        this.$btnPrint = $('#ladb_btn_print', this.$header);
        this.$btnExport = $('#ladb_btn_export', this.$header);
        this.$itemHighlightAllParts = $('#ladb_item_highlight_all_parts', this.$header);
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
        this.popSlide();

        rubyCallCommand('cutlist_generate', $.extend(this.generateOptions, this.generateFilters), function(response) {

            that.generateAt = new Date().getTime() / 1000;

            var errors = response.errors;
            var warnings = response.warnings;
            var tips = response.tips;
            var lengthUnit = response.length_unit;
            var isMetric = response.is_metric;
            var filename = response.filename;
            var pageLabel = response.page_label;
            var instanceCount = response.instance_count;
            var ignoredInstanceCount = response.ignored_instance_count;
            var usedLabels = response.used_labels;
            var materialUsages = response.material_usages;
            var groups = response.groups;

            // Keep usefull data
            that.isMetric = isMetric;
            that.filename = filename;
            that.pageLabel = pageLabel;
            that.lengthUnit = lengthUnit;
            that.usedLabels = usedLabels;
            that.materialUsages = materialUsages;
            that.groups = groups;

            // Update filename
            that.$fileTabs.empty();
            that.$fileTabs.append(Twig.twig({ ref: "tabs/cutlist/_file-tab.twig" }).render({
                filename: filename,
                pageLabel: pageLabel,
                generateAt: that.generateAt,
                lengthUnit: lengthUnit
            }));

            // Hide help panel
            that.$panelHelp.hide();

            // Update buttons and items state
            that.$btnPrint.prop('disabled', groups.length == 0);
            that.$btnExport.prop('disabled', groups.length == 0);
            that.$itemHighlightAllParts.closest('li').toggleClass('disabled', groups.length == 0);
            that.$itemShowAllGroups.closest('li').toggleClass('disabled', groups.length == 0);
            that.$itemNumbersSave.closest('li').toggleClass('disabled', groups.length == 0);
            that.$itemNumbersReset.closest('li').toggleClass('disabled', groups.length == 0);

            // Update page
            that.$page.empty();
            that.$page.append(Twig.twig({ ref: "tabs/cutlist/_list.twig" }).render({
                showThicknessSeparators: that.generateOptions.part_order_strategy.startsWith('thickness') || that.generateOptions.part_order_strategy.startsWith('-thickness'),
                showWidthSeparators: that.generateOptions.part_order_strategy.startsWith('width') || that.generateOptions.part_order_strategy.startsWith('-width'),
                dimensionColumnOrderStrategy: that.uiOptions.dimension_column_order_strategy.split('>'),
                uiOptions: that.uiOptions,
                generateFilters: that.generateFilters,
                errors: errors,
                warnings: warnings,
                tips: tips,
                isMetric: isMetric,
                instanceCount: instanceCount,
                ignoredInstanceCount: ignoredInstanceCount,
                usedLabels: usedLabels,
                groups: groups
            }));

            // Setup tooltips
            that.opencutlist.setupTooltips();

            // Cleanup nonexistent hidden group ids
            var hiddenGroupIdsLength = that.uiOptions.hidden_group_ids.length;
            for (var i = hiddenGroupIdsLength - 1 ; i >= 0; i--) {
                if (that.uiOptions.hidden_group_ids[i].endsWith('summary')) {
                    continue;
                }
                var exists = false;
                for (var j = 0; j < groups.length; j++) {
                    if (that.uiOptions.hidden_group_ids[i] === groups[j].id) {
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

            // Bind inputs
            $('#ladb_cutlist_labels_filter', that.$page)
                .tokenfield($.extend(TOKENFIELD_OPTIONS, {
                    autocomplete: {
                        source: that.usedLabels,
                        delay: 100
                    },
                    showAutocompleteOnFocus: false
                }))
                .on('tokenfield:createtoken', function(e) {

                    // Unique token
                    var existingTokens = $(this).tokenfield('getTokens');
                    $.each(existingTokens, function(index, token) {
                        if (token.value === e.attrs.value) {
                            e.preventDefault();
                        }
                    });

                    // Available token only
                    var available = false;
                    $.each(that.usedLabels, function(index, token) {
                        if (token === e.attrs.value) {
                            available = true;
                            return false;
                        }
                    });
                    if (!available) {
                        e.preventDefault();
                    }

                })
                .on('tokenfield:createdtoken tokenfield:removedtoken', function(e) {
                    var tokenList = $(this).tokenfield('getTokensList');
                    that.generateFilters.labels_filter = tokenList.length === 0 ? [] : tokenList.split(';');
                    that.generateCutlist(function() {
                        $('#ladb_cutlist_labels_filter-tokenfield', that.$page).focus();
                    });
                })
            ;

            // Bind buttons
            $('#ladb_cutlist_btn_labels_filter_clear', that.$page).on('click', function() {
                that.generateFilters.labels_filter = [];
                that.generateCutlist();
                $(this).blur();
            });
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
                that.$rootSlide.animate({ scrollTop: $(target).offset().top - that.$header.outerHeight(true) - 20 }, 200).promise().then(function() {
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
            $('a.ladb-item-highlight-group-parts', that.$page).on('click', function() {
                var $group = $(this).closest('.ladb-cutlist-group');
                var groupId = $group.data('group-id');
                that.highlightGroupParts(groupId);
                $(this).blur();
            });
            $('a.ladb-item-group-numbers', that.$page).on('click', function() {
                var $group = $(this).closest('.ladb-cutlist-group');
                var groupId = $group.data('group-id');
                that.groupNumbers(groupId);
                $(this).blur();
            });
            $('a.ladb-item-hide-all-other-groups', that.$page).on('click', function() {
                var $group = $(this).closest('.ladb-cutlist-group');
                var groupId = $group.data('group-id');
                that.hideAllGroups(groupId);
                that.$rootSlide.animate({ scrollTop: $group.offset().top - that.$header.outerHeight(true) - 20 }, 200).promise();
                $(this).blur();
            });
            $('a.ladb-item-numbers-save', that.$page).on('click', function() {
                var $group = $(this).closest('.ladb-cutlist-group');
                var groupId = $group.data('group-id');
                var wTop = $group.offset().top - $(window).scrollTop();
                that.numbersSave({ group_id: groupId }, function() {
                    that.$rootSlide.animate({ scrollTop: $('#ladb_group_' + groupId).offset().top - wTop }, 0);
                });
                $(this).blur();
            });
            $('a.ladb-item-numbers-reset', that.$page).on('click', function() {
                var $group = $(this).closest('.ladb-cutlist-group');
                var groupId = $group.data('group-id');
                var wTop = $group.offset().top - $(window).scrollTop();
                that.numbersReset({ group_id: groupId }, function() {
                    that.$rootSlide.animate({ scrollTop: $('#ladb_group_' + groupId).offset().top - wTop }, 0);
                });
                $(this).blur();
            });
            $('button.ladb-btn-group-cuttingdiagram2d', that.$page).on('click', function() {
                var $group = $(this).closest('.ladb-cutlist-group');
                var groupId = $group.data('group-id');
                that.cuttingdiagram2dGroup(groupId);
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
            $('a.ladb-btn-label-filter', that.$page).on('click', function() {
                var labelFilter = $(this).html();
                var indexOf = that.generateFilters.labels_filter.indexOf(labelFilter);
                if (indexOf > -1) {
                    that.generateFilters.labels_filter.splice(indexOf, 1);
                } else {
                    that.generateFilters.labels_filter.push(labelFilter);
                }
                that.generateCutlist();
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
            that.stickSlideHeader(that.$rootSlide);

            // Callback
            if (callback && typeof callback == 'function') {
                callback();
            }

        });

    };

    LadbTabCutlist.prototype.exportCutlist = function () {
        var that = this;

        // Retrieve export option options
        this.opencutlist.pullSettings([

                SETTING_KEY_EXPORT_OPTION_SOURCE,
                SETTING_KEY_EXPORT_OPTION_COL_SEP,
                SETTING_KEY_EXPORT_OPTION_ENCODING

            ],
            3 /* SETTINGS_RW_STRATEGY_MODEL_GLOBAL */,
            function () {

                var exportOptions = {
                    source: that.opencutlist.getSetting(SETTING_KEY_EXPORT_OPTION_SOURCE, OPTION_DEFAULT_SOURCE),
                    col_sep: that.opencutlist.getSetting(SETTING_KEY_EXPORT_OPTION_COL_SEP, OPTION_DEFAULT_COL_SEP),
                    encoding: that.opencutlist.getSetting(SETTING_KEY_EXPORT_OPTION_ENCODING, OPTION_DEFAULT_ENCODING)
                };

                var $modal = that.appendModalInside('ladb_cutlist_modal_export', 'tabs/cutlist/_modal-export.twig');

                // Fetch UI elements
                var $selectSource = $('#ladb_cutlist_export_select_source', $modal);
                var $selectColSep = $('#ladb_cutlist_export_select_col_sep', $modal);
                var $selectEncoding = $('#ladb_cutlist_export_select_encoding', $modal);
                var $btnExport = $('#ladb_cutlist_export', $modal);

                // Bind select
                $selectSource.val(exportOptions.source);
                $selectSource.selectpicker(SELECT_PICKER_OPTIONS);
                $selectColSep.val(exportOptions.col_sep);
                $selectColSep.selectpicker(SELECT_PICKER_OPTIONS);
                $selectEncoding.val(exportOptions.encoding);
                $selectEncoding.selectpicker(SELECT_PICKER_OPTIONS);

                // Bind buttons
                $btnExport.on('click', function() {

                    // Fetch options

                    exportOptions.source = $selectSource.val();
                    exportOptions.col_sep = $selectColSep.val();
                    exportOptions.encoding = $selectEncoding.val();

                    // Store options
                    that.opencutlist.setSettings([
                        { key:SETTING_KEY_EXPORT_OPTION_SOURCE, value:exportOptions.source },
                        { key:SETTING_KEY_EXPORT_OPTION_COL_SEP, value:exportOptions.col_sep },
                        { key:SETTING_KEY_EXPORT_OPTION_ENCODING, value:exportOptions.encoding }
                    ], 0 /* SETTINGS_RW_STRATEGY_GLOBAL */);

                    rubyCallCommand('cutlist_export', $.extend(exportOptions, that.uiOptions), function(response) {

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

            });

    };

    // Highlight /////

    LadbTabCutlist.prototype.highlightAllParts = function () {
        var that = this;

        rubyCallCommand('cutlist_highlight_all_parts', null, function (response) {

            if (response['errors']) {
                var errMessages = [];
                for (var i = 0; i < response['errors'].length; i++) {
                    errMessages.push('<i class="ladb-opencutlist-icon-warning"></i> ' + i18next.t(response['errors']))
                }
                that.opencutlist.notify(errMessages.join('\n'), 'error');
            } else {
                that.opencutlist.minimize();
            }

        });

    };

    LadbTabCutlist.prototype.highlightGroupParts = function (group_id) {
        var that = this;

        rubyCallCommand('cutlist_highlight_group_parts', group_id, function (response) {

            if (response['errors']) {
                var errMessages = [];
                for (var i = 0; i < response['errors'].length; i++) {
                    errMessages.push('<i class="ladb-opencutlist-icon-warning"></i> ' + i18next.t(response['errors']))
                }
                that.opencutlist.notify(errMessages.join('\n'), 'error');
            } else {
                that.opencutlist.minimize();
            }

        });

    };

    LadbTabCutlist.prototype.highlightPart = function (part_id) {
        var that = this;

        rubyCallCommand('cutlist_highlight_part', part_id, function (response) {

            if (response['errors']) {
                var errMessages = [];
                for (var i = 0; i < response['errors'].length; i++) {
                    errMessages.push('<i class="ladb-opencutlist-icon-warning"></i> ' + i18next.t(response['errors']))
                }
                that.opencutlist.notify(errMessages.join('\n'), 'error');
            } else {
                that.opencutlist.minimize();
            }

        });

    };

    // Parts /////

    LadbTabCutlist.prototype.findPartById = function (id) {
        for (var i = 0 ; i < this.groups.length; i++) {
            var group = this.groups[i];
            for (var j = 0; j < group.parts.length; j++) {
                var part = group.parts[j];
                if (part.id === id) {
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
                var $inputLabels = $('#ladb_cutlist_part_input_labels', $modal);
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
                    that.editedPart.labels = $inputLabels.tokenfield('getTokensList').split(';');

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
                                    that.$rootSlide.animate({ scrollTop: $part.offset().top - wTop }, 0);
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

                // Init tokenfields (this must done after modal shown for correct token label max width measurement)
                $inputLabels
                    .tokenfield($.extend(TOKENFIELD_OPTIONS, {
                        autocomplete: {
                            source: that.usedLabels,
                            delay: 100
                        }
                    }))
                    .on('tokenfield:createtoken', function (e) {
                        var existingTokens = $(this).tokenfield('getTokens');
                        $.each(existingTokens, function (index, token) {
                            if (token.value === e.attrs.value) {
                                e.preventDefault();
                            }
                        });
                    });

                // Setup popovers
                that.opencutlist.setupPopovers();

            });

        }
    };

    // Groups /////

    LadbTabCutlist.prototype.findGroupById = function (id) {
        for (var i = 0 ; i < this.groups.length; i++) {
            var group = this.groups[i];
            if (group.id === id) {
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
        if (idx !== -1) {
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
        if (idx === -1) {
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

    LadbTabCutlist.prototype.cuttingdiagram2dGroup = function (groupId) {
        var that = this;

        var group = this.findGroupById(groupId);

        // Retrieve cutting diagram options
        this.opencutlist.pullSettings([

                // Defaults
                SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_SAW_KERF,
                SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_TRIMMING,
                SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_PRESORT,
                SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_STACKING,
                SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_BBOX_OPTIMIZATION,

                SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_STD_SHEET + '_' + groupId,
                SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_STD_SHEET_LENGTH + '_' + groupId,
                SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_STD_SHEET_WIDTH + '_' + groupId,
                SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_SCRAP_SHEET_SIZES + '_' + groupId,
                SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_GRAINED + '_' + groupId,
                SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_SAW_KERF + '_' + groupId,
                SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_TRIMMING + '_' + groupId,
                SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_PRESORT + '_' + groupId,
                SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_STACKING + '_' + groupId,
                SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_BBOX_OPTIMIZATION + '_' + groupId

            ],
            2 /* SETTINGS_RW_STRATEGY_MODEL */,
            function () {

                var cuttingdiagram2dOptions = {
                    std_sheet: that.opencutlist.getSetting(SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_STD_SHEET + '_' + groupId, OPTION_DEFAULT_STD_SHEET),
                    std_sheet_length: that.opencutlist.getSetting(SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_STD_SHEET_LENGTH + '_' + groupId, OPTION_DEFAULT_STD_SHEET_LENGTH),
                    std_sheet_width: that.opencutlist.getSetting(SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_STD_SHEET_WIDTH + '_' + groupId, OPTION_DEFAULT_STD_SHEET_WIDTH),
                    scrap_sheet_sizes: that.opencutlist.getSetting(SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_SCRAP_SHEET_SIZES + '_' + groupId, OPTION_DEFAULT_SCRAP_SHEET_SIZES),
                    grained: that.opencutlist.getSetting(SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_GRAINED + '_' + groupId, OPTION_DEFAULT_GRAINED),
                    saw_kerf: that.opencutlist.getSetting(SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_SAW_KERF + '_' + groupId, that.opencutlist.getSetting(SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_SAW_KERF, OPTION_DEFAULT_SAW_KERF)),
                    trimming: that.opencutlist.getSetting(SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_TRIMMING + '_' + groupId, that.opencutlist.getSetting(SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_TRIMMING, OPTION_DEFAULT_TRIMMING)),
                    presort: that.opencutlist.getSetting(SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_PRESORT + '_' + groupId, that.opencutlist.getSetting(SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_PRESORT, OPTION_DEFAULT_PRESORT)),
                    stacking: that.opencutlist.getSetting(SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_STACKING + '_' + groupId, that.opencutlist.getSetting(SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_STACKING, OPTION_DEFAULT_STACKING)),
                    bbox_optimization: that.opencutlist.getSetting(SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_BBOX_OPTIMIZATION + '_' + groupId, that.opencutlist.getSetting(SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_BBOX_OPTIMIZATION, OPTION_DEFAULT_BBOX_OPTIMIZATION))
                };

                rubyCallCommand('materials_get_attributes_command', { name: group.material_name }, function (response) {

                    var $modal = that.appendModalInside('ladb_cutlist_modal_cuttingdiagram_2d', 'tabs/cutlist/_modal-cuttingdiagram-2d.twig', $.extend({ material_attributes: response }, { group: group }));

                    // Fetch UI elements
                    var $inputStdSheet = $('#ladb_select_std_sheet', $modal);
                    var $inputStdSheetLength = $('#ladb_input_std_sheet_length', $modal);
                    var $inputStdSheetWidth = $('#ladb_input_std_sheet_width', $modal);
                    var $inputScrapSheetSizes = $('#ladb_input_scrap_sheet_sizes', $modal);
                    var $selectGrained = $('#ladb_select_grained', $modal);
                    var $inputSawKerf = $('#ladb_input_saw_kerf', $modal);
                    var $inputTrimming = $('#ladb_input_trimming', $modal);
                    var $selectPresort = $('#ladb_select_presort', $modal);
                    var $selectStacking = $('#ladb_select_stacking', $modal);
                    var $selectBBoxOptimization = $('#ladb_select_bbox_optimization', $modal);
                    var $btnCuttingdiagramOptionsDefaultsSave = $('#ladb_btn_cuttingdiagram_options_defaults_save', $modal);
                    var $btnCuttingdiagramOptionsDefaultsReset = $('#ladb_btn_cuttingdiagram_options_defaults_reset', $modal);
                    var $btnEditMaterial = $('#ladb_btn_edit_material', $modal);
                    var $btnCuttingdiagram = $('#ladb_btn_cuttingdiagram', $modal);

                    var $formGroupGrained = $('#ladb_form_group_grained', $modal);

                    if (cuttingdiagram2dOptions.std_sheet) {
                        $inputStdSheet.val(cuttingdiagram2dOptions.std_sheet);
                        if ($inputStdSheet.val() == null && response.std_sizes.length === 0) {
                            $inputStdSheet.val('0x0|' + response.grained);  // Special case if the std_sheet is not present anymore in the list and no std size defined. Select "none" by default.
                        }
                    }
                    $inputScrapSheetSizes.val(cuttingdiagram2dOptions.scrap_sheet_sizes);
                    $inputStdSheet.selectpicker(SELECT_PICKER_OPTIONS);
                    $selectGrained.selectpicker(SELECT_PICKER_OPTIONS);
                    $inputSawKerf.val(cuttingdiagram2dOptions.saw_kerf);
                    $inputTrimming.val(cuttingdiagram2dOptions.trimming);
                    $selectPresort.val(cuttingdiagram2dOptions.presort);
                    $selectPresort.selectpicker(SELECT_PICKER_OPTIONS);
                    $selectStacking.val(cuttingdiagram2dOptions.stacking);
                    $selectStacking.selectpicker(SELECT_PICKER_OPTIONS);
                    $selectBBoxOptimization.val(cuttingdiagram2dOptions.bbox_optimization);
                    $selectBBoxOptimization.selectpicker(SELECT_PICKER_OPTIONS);

                    var fnEditMaterial = function(callback) {

                        // Hide modal
                        $modal.modal('hide');

                        // Edit material and focus std_sizes input field
                        that.opencutlist.executeCommandOnTab('materials', 'edit_material', {
                            material_id: group.material_id,
                            callback: callback
                        });

                    };
                    var fnSelectSize = function() {
                        var value = $inputStdSheet.val();
                        if (value === 'add') {
                            fnEditMaterial(function($editMaterialModal) {
                                $('#ladb_materials_input_std_sizes', $editMaterialModal).siblings('.token-input').focus();
                            });
                        } else {
                            var sizeAndGrained = value.split('|');
                            var size = sizeAndGrained[0].split('x');
                            var stdSheetLength = size[0].trim();
                            var stdSheetWidth = size[1].trim();
                            var grained = sizeAndGrained[1] === 'true';
                            $inputStdSheetLength.val(stdSheetLength);
                            $inputStdSheetWidth.val(stdSheetWidth);
                            $selectGrained.selectpicker('val', grained ? '1' : '0');
                            if (stdSheetLength === '0' && stdSheetWidth === '0') {
                                $formGroupGrained.show();
                            } else {
                                $formGroupGrained.hide();
                            }
                        }
                    };

                    $inputStdSheet.on('changed.bs.select', function (e) {
                        fnSelectSize();
                    });
                    fnSelectSize();

                    // Bind buttons
                    $btnCuttingdiagramOptionsDefaultsSave.on('click', function() {

                        var saw_kerf = $inputSawKerf.val();
                        var trimming = $inputTrimming.val();
                        var presort = $selectPresort.val();
                        var stacking = $selectStacking.val();
                        var bbox_optimization = $selectBBoxOptimization.val();

                        // Update default cut options for specific type to last used
                        that.opencutlist.setSettings([
                            { key:SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_SAW_KERF, value:saw_kerf, preprocessor:1 /* SETTINGS_PREPROCESSOR_D */ },
                            { key:SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_TRIMMING, value:trimming, preprocessor:1 /* SETTINGS_PREPROCESSOR_D */ },
                            { key:SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_PRESORT, value:presort },
                            { key:SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_STACKING, value:stacking },
                            { key:SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_BBOX_OPTIMIZATION, value:bbox_optimization }
                        ], 0 /* SETTINGS_RW_STRATEGY_GLOBAL */);

                        that.opencutlist.notify(i18next.t('tab.cutlist.cuttingdiagram.options_defaults.save_success'), 'success');

                        this.blur();

                    });
                    $btnCuttingdiagramOptionsDefaultsReset.on('click', function() {

                        var saw_kerf = that.opencutlist.getSetting(SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_SAW_KERF, OPTION_DEFAULT_SAW_KERF);
                        var trimming = that.opencutlist.getSetting(SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_TRIMMING, OPTION_DEFAULT_TRIMMING);
                        var presort = that.opencutlist.getSetting(SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_PRESORT, OPTION_DEFAULT_PRESORT);
                        var stacking = that.opencutlist.getSetting(SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_STACKING, OPTION_DEFAULT_STACKING);
                        var bbox_optimization = that.opencutlist.getSetting(SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_BBOX_OPTIMIZATION, OPTION_DEFAULT_BBOX_OPTIMIZATION);

                        $inputSawKerf.val(saw_kerf);
                        $inputTrimming.val(trimming);
                        $selectPresort.selectpicker('val', presort);
                        $selectStacking.selectpicker('val', stacking);
                        $selectBBoxOptimization.selectpicker('val', bbox_optimization);

                        this.blur();

                    });
                    $btnEditMaterial.on('click', function() {
                        fnEditMaterial();
                    });
                    $btnCuttingdiagram.on('click', function() {

                        // Fetch options

                        cuttingdiagram2dOptions.std_sheet = $inputStdSheet.val();
                        cuttingdiagram2dOptions.std_sheet_length = $inputStdSheetLength.val();
                        cuttingdiagram2dOptions.std_sheet_width = $inputStdSheetWidth.val();
                        cuttingdiagram2dOptions.scrap_sheet_sizes = $inputScrapSheetSizes.val();
                        cuttingdiagram2dOptions.grained = $selectGrained.val() === '1';
                        cuttingdiagram2dOptions.saw_kerf = $inputSawKerf.val();
                        cuttingdiagram2dOptions.trimming = $inputTrimming.val();
                        cuttingdiagram2dOptions.presort = $selectPresort.val();
                        cuttingdiagram2dOptions.stacking = $selectStacking.val();
                        cuttingdiagram2dOptions.bbox_optimization = $selectBBoxOptimization.val();

                        // Store options
                        that.opencutlist.setSettings([
                            { key:SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_STD_SHEET + '_' + groupId, value:cuttingdiagram2dOptions.std_sheet },
                            { key:SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_STD_SHEET_LENGTH + '_' + groupId, value:cuttingdiagram2dOptions.std_sheet_length, preprocessor:1 /* SETTINGS_PREPROCESSOR_D */ },
                            { key:SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_STD_SHEET_WIDTH + '_' + groupId, value:cuttingdiagram2dOptions.std_sheet_width, preprocessor:1 /* SETTINGS_PREPROCESSOR_D */ },
                            { key:SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_SCRAP_SHEET_SIZES + '_' + groupId, value:cuttingdiagram2dOptions.scrap_sheet_sizes, preprocessor:2 /* SETTINGS_PREPROCESSOR_DXD */ },
                            { key:SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_GRAINED + '_' + groupId, value:cuttingdiagram2dOptions.grained },
                            { key:SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_SAW_KERF + '_' + groupId, value:cuttingdiagram2dOptions.saw_kerf, preprocessor:1 /* SETTINGS_PREPROCESSOR_D */ },
                            { key:SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_TRIMMING + '_' + groupId, value:cuttingdiagram2dOptions.trimming, preprocessor:1 /* SETTINGS_PREPROCESSOR_D */ },
                            { key:SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_PRESORT + '_' + groupId, value:cuttingdiagram2dOptions.presort },
                            { key:SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_STACKING + '_' + groupId, value:cuttingdiagram2dOptions.stacking },
                            { key:SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_BBOX_OPTIMIZATION + '_' + groupId, value:cuttingdiagram2dOptions.bbox_optimization }

                        ], 2 /* SETTINGS_RW_STRATEGY_MODEL */);

                        rubyCallCommand('cutlist_group_cuttingdiagram_2d', $.extend({ group_id: groupId }, cuttingdiagram2dOptions, that.uiOptions), function(response) {

                            var $slide = that.pushNewSlide('ladb_cutlist_slide_cuttingdiagram_2d', 'tabs/cutlist/_slide-cuttingdiagram-2d.twig', $.extend({
                                uiOptions: that.uiOptions,
                                isMetric: that.isMetric,
                                filename: that.filename,
                                pageLabel: that.pageLabel,
                                lengthUnit: that.lengthUnit,
                                generatedAt: new Date().getTime() / 1000,
                                group: group
                            }, response), function() {
                                that.opencutlist.setupTooltips();
                            });

                            // Fetch UI elements
                            var $btnCuttingDiagram = $('#ladb_btn_cuttingdiagram', $slide);
                            var $btnPrint = $('#ladb_btn_print', $slide);
                            var $btnClose = $('#ladb_btn_close', $slide);

                            // Bind buttons
                            $btnCuttingDiagram.on('click', function() {
                                that.cuttingdiagram2dGroup(groupId);
                            });
                            $btnPrint.on('click', function() {
                                window.print();
                            });
                            $btnClose.on('click', function() {
                                that.popSlide();
                            });

                            $('.ladb-btn-toggle-no-print', $slide).on('click', function() {
                                var $group = $(this).closest('.ladb-cutlist-group');
                                if ($group.hasClass('no-print')) {
                                    that.showGroup($group);
                                } else {
                                    that.hideGroup($group);
                                }
                                $(this).blur();
                            });
                            $('.ladb-btn-scrollto-prev-group', $slide).on('click', function() {
                                var $group = $(this).closest('.ladb-cutlist-group');
                                var groupId = $group.data('sheet-index');
                                var $target = $('#ladb_cuttingdiagram_group_' + (parseInt(groupId) - 1));
                                $slide.animate({ scrollTop: $slide.scrollTop() + $target.position().top - $('.ladb-header', $slide).outerHeight(true) - 20 }, 200).promise().then(function() {
                                    $target.effect("highlight", {}, 1500);
                                });
                                $(this).blur();
                                return false;
                            });
                            $('.ladb-btn-scrollto-next-group', $slide).on('click', function() {
                                var $group = $(this).closest('.ladb-cutlist-group');
                                var groupId = $group.data('sheet-index');
                                var $target = $('#ladb_cuttingdiagram_group_' + (parseInt(groupId) + 1));
                                $slide.animate({ scrollTop: $slide.scrollTop() + $target.position().top - $('.ladb-header', $slide).outerHeight(true) - 20 }, 200).promise().then(function() {
                                    $target.effect("highlight", {}, 1500);
                                });
                                $(this).blur();
                                return false;
                            });
                            $('a.ladb-btn-highlight-part', $slide).on('click', function() {
                                $(this).blur();
                                var partId = $(this).data('part-id');
                                that.highlightPart(partId);
                                return false;
                            });
                            $('a.ladb-btn-scrollto', $slide).on('click', function() {
                                var target = $(this).attr('href');
                                $slide.animate({ scrollTop: $slide.scrollTop() + $(target).position().top - $('.ladb-header', $slide).outerHeight(true) - 20 }, 200).promise().then(function() {
                                    $(target).effect("highlight", {}, 1500);
                                });
                                $(this).blur();
                                return false;
                            });
                            $('.ladb-cutlist-row', $slide).on('click', function() {
                                $('.ladb-click-tool', $(this)).click();
                                $(this).blur();
                                return false;
                            });

                            // SVG
                            $('SVG .part', $slide).on('click', function() {
                                var partId = $(this).data('part-id');
                                that.highlightPart(partId);
                                $(this).blur();
                                return false;
                            });

                        });

                        // Hide modal
                        $modal.modal('hide');

                    });

                    // Show modal
                    $modal.modal('show');

                    // Init tokenfields (this must done after modal shown for correct token label max width measurement)
                    $inputScrapSheetSizes.tokenfield(TOKENFIELD_OPTIONS).on('tokenfield:createdtoken', that.tokenfieldValidatorFn_dxd);

                    // Setup popovers
                    that.opencutlist.setupPopovers();

                });

            });

    };

    LadbTabCutlist.prototype.slide = function() {

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

                SETTING_KEY_OPTION_HIDE_LABELS,
                SETTING_KEY_OPTION_HIDE_RAW_DIMENSIONS,
                SETTING_KEY_OPTION_HIDE_FINAL_DIMENSIONS,
                SETTING_KEY_OPTION_HIDE_UNTYPED_MATERIAL_DIMENSIONS,
                SETTING_KEY_OPTION_DIMENSION_COLUMN_ORDER_STRATEGY,
                SETTING_KEY_OPTION_HIDDEN_GROUP_IDS,

                SETTING_KEY_OPTION_AUTO_ORIENT,
                SETTING_KEY_OPTION_SMART_MATERIAL,
                SETTING_KEY_OPTION_PART_NUMBER_WITH_LETTERS,
                SETTING_KEY_OPTION_PART_NUMBER_SEQUENCE_BY_GROUP,
                SETTING_KEY_OPTION_PART_ORDER_STRATEGY

            ],
            3 /* SETTINGS_RW_STRATEGY_MODEL_GLOBAL */,
            function () {

                that.uiOptions = {
                    hide_labels: that.opencutlist.getSetting(SETTING_KEY_OPTION_HIDE_LABELS, OPTION_DEFAULT_HIDE_LABELS),
                    hide_raw_dimensions: that.opencutlist.getSetting(SETTING_KEY_OPTION_HIDE_RAW_DIMENSIONS, OPTION_DEFAULT_HIDE_RAW_DIMENSIONS),
                    hide_final_dimensions: that.opencutlist.getSetting(SETTING_KEY_OPTION_HIDE_FINAL_DIMENSIONS, OPTION_DEFAULT_HIDE_FINAL_DIMENSIONS),
                    hide_untyped_material_dimensions: that.opencutlist.getSetting(SETTING_KEY_OPTION_HIDE_UNTYPED_MATERIAL_DIMENSIONS, OPTION_DEFAULT_HIDE_UNTYPED_MATERIAL_DIMENSIONS),
                    dimension_column_order_strategy: that.opencutlist.getSetting(SETTING_KEY_OPTION_DIMENSION_COLUMN_ORDER_STRATEGY, OPTION_DEFAULT_DIMENSION_COLUMN_ORDER_STRATEGY),
                    hidden_group_ids: that.opencutlist.getSetting(SETTING_KEY_OPTION_HIDDEN_GROUP_IDS, OPTION_DEFAULT_HIDDEN_GROUP_IDS)
                };

                that.generateOptions = {
                    auto_orient: that.opencutlist.getSetting(SETTING_KEY_OPTION_AUTO_ORIENT, OPTION_DEFAULT_AUTO_ORIENT),
                    smart_material: that.opencutlist.getSetting(SETTING_KEY_OPTION_SMART_MATERIAL, OPTION_DEFAULT_SMART_MATERIAL),
                    part_number_with_letters: that.opencutlist.getSetting(SETTING_KEY_OPTION_PART_NUMBER_WITH_LETTERS, OPTION_DEFAULT_PART_NUMBER_WITH_LETTERS),
                    part_number_sequence_by_group: that.opencutlist.getSetting(SETTING_KEY_OPTION_PART_NUMBER_SEQUENCE_BY_GROUP, OPTION_DEFAULT_PART_NUMBER_SEQUENCE_BY_GROUP),
                    part_order_strategy: that.opencutlist.getSetting(SETTING_KEY_OPTION_PART_ORDER_STRATEGY, OPTION_DEFAULT_PART_ORDER_STRATEGY)
                };

                // Callback
                if (callback && typeof(callback) === 'function') {
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
        var $inputHideLabels = $('#ladb_input_hide_labels', $modal);
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
            $inputHideLabels.prop('checked', uiOptions.hide_labels);
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
                hide_labels: OPTION_DEFAULT_HIDE_LABELS,
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
            that.uiOptions.hide_labels = $inputHideLabels.is(':checked');
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
                { key:SETTING_KEY_OPTION_HIDE_LABELS, value:that.uiOptions.hide_labels },
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
        LadbAbstractTab.prototype.bind.call(this);

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
        this.$itemHighlightAllParts.on('click', function () {
            if (!$(this).closest('li').hasClass('disabled')) {
                that.highlightAllParts();
            }
            this.blur();
        });
        this.$itemShowAllGroups.on('click', function () {
            if (!$(this).closest('li').hasClass('disabled')) {
                that.showAllGroups();
            }
            this.blur();
        });
        this.$itemNumbersSave.on('click', function () {
            if (!$(this).closest('li').hasClass('disabled')) {
                that.numbersSave();
            }
            this.blur();
        });
        this.$itemNumbersReset.on('click', function () {
            if (!$(this).closest('li').hasClass('disabled')) {
                that.numbersReset();
            }
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
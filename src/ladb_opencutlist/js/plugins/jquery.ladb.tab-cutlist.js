+function ($) {
    'use strict';

    // CONSTANTS
    // ======================

    // Options keys

    var SETTING_KEY_OPTION_AUTO_ORIENT = 'cutlist.option.auto_orient';
    var SETTING_KEY_OPTION_SMART_MATERIAL = 'cutlist.option.smart_material';
    var SETTING_KEY_OPTION_DYNAMIC_ATTRIBUTES_NAME = 'cutlist.option.dynamic_attributes_name';
    var SETTING_KEY_OPTION_PART_NUMBER_WITH_LETTERS = 'cutlist.option.part_number_with_letters';
    var SETTING_KEY_OPTION_PART_NUMBER_SEQUENCE_BY_GROUP = 'cutlist.option.part_number_sequence_by_group';
    var SETTING_KEY_OPTION_PART_FOLDING = 'cutlist.option.part_folding';
    var SETTING_KEY_OPTION_HIDE_ENTITY_NAMES = 'cutlist.option.hide_entity_names';
    var SETTING_KEY_OPTION_HIDE_LABELS = 'cutlist.option.hide_labels';
    var SETTING_KEY_OPTION_HIDE_CUTTING_DIMENSIONS = 'cutlist.option.hide_cutting_dimensions';
    var SETTING_KEY_OPTION_HIDE_BBOX_DIMENSIONS = 'cutlist.option.hide_bbox_dimensions';
    var SETTING_KEY_OPTION_HIDE_UNTYPED_MATERIAL_DIMENSIONS = 'cutlist.option.hide_untyped_material_dimensions';
    var SETTING_KEY_OPTION_HIDE_FINAL_AREAS = 'cutlist.option.hide_final_areas';
    var SETTING_KEY_OPTION_HIDE_EDGES = 'cutlist.option.hide_edges';
    var SETTING_KEY_OPTION_MINIMIZE_ON_HIGHLIGHT = 'cutlist.option.minimize_on_highlight';
    var SETTING_KEY_OPTION_PART_ORDER_STRATEGY = 'cutlist.option.part_order_strategy';
    var SETTING_KEY_OPTION_DIMENSION_COLUMN_ORDER_STRATEGY = 'cutlist.option.dimension_column_order_strategy';
    var SETTING_KEY_OPTION_HIDDEN_GROUP_IDS = 'cutlist.option.hidden_group_ids';

    var SETTING_KEY_EXPORT_OPTION_SOURCE = 'cutlist.export.option.source';
    var SETTING_KEY_EXPORT_OPTION_COL_SEP = 'cutlist.export.option.col_sep';
    var SETTING_KEY_EXPORT_OPTION_ENCODING = 'cutlist.export.option.encoding';

    var SETTING_KEY_CUTTINGDIAGRAM1D_OPTION_STD_BAR = 'cutlist.cuttingdiagram1d.option.std_bar';
    var SETTING_KEY_CUTTINGDIAGRAM1D_OPTION_STD_BAR_LENGTH = 'cutlist.cuttingdiagram1d.option.std_bar_length';
    var SETTING_KEY_CUTTINGDIAGRAM1D_OPTION_SCRAP_BAR_LENGTHS = 'cutlist.cuttingdiagram1d.option.scrap_bar_lengths';
    var SETTING_KEY_CUTTINGDIAGRAM1D_OPTION_BAR_FOLDING = 'cutlist.cuttingdiagram1d.option.bar_folding';
    var SETTING_KEY_CUTTINGDIAGRAM1D_OPTION_HIDE_PART_LIST = 'cutlist.cuttingdiagram1d.option.hide_part_list';
    var SETTING_KEY_CUTTINGDIAGRAM1D_OPTION_BREAK_LENGTH = 'cutlist.cuttingdiagram1d.option.break_length';
    var SETTING_KEY_CUTTINGDIAGRAM1D_OPTION_SAW_KERF = 'cutlist.cuttingdiagram1d.option.saw_kerf';
    var SETTING_KEY_CUTTINGDIAGRAM1D_OPTION_TRIMMING = 'cutlist.cuttingdiagram1d.option.trimming';

    var SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_STD_SHEET = 'cutlist.cuttingdiagram2d.option.std_sheet';
    var SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_STD_SHEET_LENGTH = 'cutlist.cuttingdiagram2d.option.std_sheet_length';
    var SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_STD_SHEET_WIDTH = 'cutlist.cuttingdiagram2d.option.std_sheet_width';
    var SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_SCRAP_SHEET_SIZES = 'cutlist.cuttingdiagram2d.option.scrap_sheet_sizes';
    var SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_GRAINED = 'cutlist.cuttingdiagram2d.option.grained';
    var SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_SHEET_FOLDING = 'cutlist.cuttingdiagram1d.option.sheet_folding';
    var SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_HIDE_PART_LIST = 'cutlist.cuttingdiagram2d.option.hide_part_list';
    var SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_SAW_KERF = 'cutlist.cuttingdiagram2d.option.saw_kerf';
    var SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_TRIMMING = 'cutlist.cuttingdiagram2d.option.trimming';
    var SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_PRESORT = 'cutlist.cuttingdiagram2d.option.presort';
    var SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_STACKING = 'cutlist.cuttingdiagram2d.option.stacking';
    var SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_BBOX_OPTIMIZATION = 'cutlist.cuttingdiagram2d.option.bbox_optimization';

    // Options defaults

    var OPTION_DEFAULT_AUTO_ORIENT = true;
    var OPTION_DEFAULT_SMART_MATERIAL = true;
    var OPTION_DEFAULT_DYNAMIC_ATTRIBUTES_NAME = false;
    var OPTION_DEFAULT_PART_NUMBER_WITH_LETTERS = true;
    var OPTION_DEFAULT_PART_NUMBER_SEQUENCE_BY_GROUP = true;
    var OPTION_DEFAULT_PART_FOLDING = false;
    var OPTION_DEFAULT_HIDE_ENTITY_NAMES = false;
    var OPTION_DEFAULT_HIDE_LABELS = false;
    var OPTION_DEFAULT_HIDE_CUTTING_DIMENSIONS = false;
    var OPTION_DEFAULT_HIDE_BBOX_DIMENSIONS = false;
    var OPTION_DEFAULT_HIDE_UNTYPED_MATERIAL_DIMENSIONS = false;
    var OPTION_DEFAULT_HIDE_FINAL_AREAS = true;
    var OPTION_DEFAULT_HIDE_EDGES = false;
    var OPTION_DEFAULT_MINIMIZE_ON_HIGHLIGHT = true;
    var OPTION_DEFAULT_PART_ORDER_STRATEGY = '-thickness>-length>-width>-count>name>-edge_pattern';
    var OPTION_DEFAULT_DIMENSION_COLUMN_ORDER_STRATEGY = 'length>width>thickness';
    var OPTION_DEFAULT_HIDDEN_GROUP_IDS = [];

    var EXPORT_OPTION_DEFAULT_SOURCE = 1;      // cutlist
    var EXPORT_OPTION_DEFAULT_COL_SEP = 0;     // \t
    var EXPORT_OPTION_DEFAULT_ENCODING = 0;    // UTF-8

    var CUTTINGDIAGRAM1D_OPTION_DEFAULT_STD_BAR = '';
    var CUTTINGDIAGRAM1D_OPTION_DEFAULT_STD_BAR_LENGTH = '2500mm';
    var CUTTINGDIAGRAM1D_OPTION_DEFAULT_BAR_FOLDING = true;
    var CUTTINGDIAGRAM1D_OPTION_DEFAULT_HIDE_PART_LIST = false;
    var CUTTINGDIAGRAM1D_OPTION_DEFAULT_BREAK_LENGTH = '3000mm';
    var CUTTINGDIAGRAM1D_OPTION_DEFAULT_SCRAP_BAR_LENGTHS = '';
    var CUTTINGDIAGRAM1D_OPTION_DEFAULT_SAW_KERF = '3mm';
    var CUTTINGDIAGRAM1D_OPTION_DEFAULT_TRIMMING = '20mm';

    var CUTTINGDIAGRAM2D_OPTION_DEFAULT_STD_SHEET = '';
    var CUTTINGDIAGRAM2D_OPTION_DEFAULT_STD_SHEET_LENGTH = '2800mm';
    var CUTTINGDIAGRAM2D_OPTION_DEFAULT_STD_SHEET_WIDTH = '2070mm';
    var CUTTINGDIAGRAM2D_OPTION_DEFAULT_GRAINED = false;
    var CUTTINGDIAGRAM2D_OPTION_DEFAULT_SHEET_FOLDING = true;
    var CUTTINGDIAGRAM2D_OPTION_DEFAULT_HIDE_PART_LIST = false;
    var CUTTINGDIAGRAM2D_OPTION_DEFAULT_SCRAP_SHEET_SIZES = '';
    var CUTTINGDIAGRAM2D_OPTION_DEFAULT_SAW_KERF = '3mm';
    var CUTTINGDIAGRAM2D_OPTION_DEFAULT_TRIMMING = '10mm';
    var CUTTINGDIAGRAM2D_OPTION_DEFAULT_PRESORT = 1;             // PRESORT_WIDTH_DECR
    var CUTTINGDIAGRAM2D_OPTION_DEFAULT_STACKING = 0;            // STACKING_NONE
    var CUTTINGDIAGRAM2D_OPTION_DEFAULT_BBOX_OPTIMIZATION = 0;   // BBOX_OPTIMIZATION_NONE

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

    // Various Consts

    var MULTIPLE_VALUE = '-1';

    // CLASS DEFINITION
    // ======================

    var LadbTabCutlist = function (element, options, opencutlist) {
        LadbAbstractTab.call(this, element, options, opencutlist);

        this.generateFilters = {
          labels_filter: [],
          edge_material_names_filter: []
        };

        this.generateAt = null;
        this.filename = null;
        this.pageLabel = null;
        this.lengthUnit = null;
        this.usedLabels = [];
        this.usedEdgeMaterialDisplayNames = [];
        this.materialUsages = [];
        this.groups = [];
        this.ignoreNextMaterialEvents = false;
        this.selectionGroupId = null;
        this.selectionPartIds = [];

        this.$header = $('.ladb-header', this.$element);
        this.$fileTabs = $('.ladb-file-tabs', this.$header);
        this.$btnGenerate = $('#ladb_btn_generate', this.$header);
        this.$btnPrint = $('#ladb_btn_print', this.$header);
        this.$btnExport = $('#ladb_btn_export', this.$header);
        this.$itemHighlightAllParts = $('#ladb_item_highlight_all_parts', this.$header);
        this.$itemShowAllGroups = $('#ladb_item_show_all_groups', this.$header);
        this.$itemNumbersSave = $('#ladb_item_numbers_save', this.$header);
        this.$itemNumbersReset = $('#ladb_item_numbers_reset', this.$header);
        this.$itemExpendAll = $('#ladb_item_expand_all', this.$header);
        this.$itemCollapseAll = $('#ladb_item_collapse_all', this.$header);
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

        rubyCallCommand('cutlist_generate', $.extend(this.generateOptions, this.generateFilters), function (response) {

            that.generateAt = new Date().getTime() / 1000;
            that.setObsolete(false);

            var errors = response.errors;
            var warnings = response.warnings;
            var tips = response.tips;
            var selectionOnly = response.selection_only;
            var lengthUnit = response.length_unit;
            var filename = response.filename;
            var pageLabel = response.page_label;
            var instanceCount = response.instance_count;
            var ignoredInstanceCount = response.ignored_instance_count;
            var usedLabels = response.used_labels;
            var materialUsages = response.material_usages;
            var groups = response.groups;

            // Keep usefull data
            that.filename = filename;
            that.pageLabel = pageLabel;
            that.lengthUnit = lengthUnit;
            that.usedLabels = usedLabels;
            that.usedEdgeMaterialDisplayNames = [];
            that.materialUsages = materialUsages;
            that.groups = groups;

            // Compute usedEdgeMaterialDisplayNames
            for (var i = 0; i < materialUsages.length; i++) {
                if (materialUsages[i].type === 4 && materialUsages[i].use_count > 0) {     // 4 = TYPE_EDGE
                    that.usedEdgeMaterialDisplayNames.push(materialUsages[i].display_name);
                }
            }

            // Update filename
            that.$fileTabs.empty();
            that.$fileTabs.append(Twig.twig({ ref: "tabs/cutlist/_file-tab.twig" }).render({
                selectionOnly: selectionOnly,
                filename: filename,
                pageLabel: pageLabel,
                generateAt: that.generateAt,
                lengthUnit: lengthUnit
            }));

            // Hide help panel
            that.$panelHelp.hide();

            // Update buttons and items state
            that.$btnPrint.prop('disabled', groups.length === 0);
            that.$btnExport.prop('disabled', groups.length === 0);
            that.$itemHighlightAllParts.parents('li').toggleClass('disabled', groups.length === 0);
            that.$itemShowAllGroups.parents('li').toggleClass('disabled', groups.length === 0);
            that.$itemNumbersSave.parents('li').toggleClass('disabled', groups.length === 0);
            that.$itemNumbersReset.parents('li').toggleClass('disabled', groups.length === 0);
            that.$itemExpendAll.parents('li').toggleClass('disabled', groups.length === 0 || !that.generateOptions.part_folding);
            that.$itemCollapseAll.parents('li').toggleClass('disabled', groups.length === 0 || !that.generateOptions.part_folding);

            // Update page
            that.$page.empty();
            that.$page.append(Twig.twig({ ref: "tabs/cutlist/_list.twig" }).render({
                showThicknessSeparators: that.generateOptions.part_order_strategy.startsWith('thickness') || that.generateOptions.part_order_strategy.startsWith('-thickness'),
                showWidthSeparators: that.generateOptions.part_order_strategy.startsWith('width') || that.generateOptions.part_order_strategy.startsWith('-width'),
                dimensionColumnOrderStrategy: that.generateOptions.dimension_column_order_strategy.split('>'),
                generateOptions: that.generateOptions,
                generateFilters: that.generateFilters,
                errors: errors,
                warnings: warnings,
                tips: tips,
                instanceCount: instanceCount,
                ignoredInstanceCount: ignoredInstanceCount,
                usedLabels: usedLabels,
                usedEdgeMaterialDisplayNames: that.usedEdgeMaterialDisplayNames,
                groups: groups
            }));

            // Setup tooltips
            that.opencutlist.setupTooltips();

            // Cleanup and Render selection
            that.cleanupSelection();
            that.renderSelection();

            // Cleanup nonexistent hidden group ids
            var hiddenGroupIdsLength = that.generateOptions.hidden_group_ids.length;
            for (var i = hiddenGroupIdsLength - 1 ; i >= 0; i--) {
                if (that.generateOptions.hidden_group_ids[i].endsWith('summary')) {
                    continue;
                }
                var exists = false;
                for (var j = 0; j < groups.length; j++) {
                    if (that.generateOptions.hidden_group_ids[i] === groups[j].id) {
                        exists = true;
                        break;
                    }
                }
                if (!exists) {
                    that.generateOptions.hidden_group_ids.splice(i, 1);
                }
            }
            if (hiddenGroupIdsLength > that.generateOptions.hidden_group_ids.length) {
                that.opencutlist.setSetting(SETTING_KEY_OPTION_HIDDEN_GROUP_IDS, that.generateOptions.hidden_group_ids, 2 /* SETTINGS_RW_STRATEGY_MODEL */);
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
                .on('tokenfield:createtoken', function (e) {

                    // Unique token
                    var existingTokens = $(this).tokenfield('getTokens');
                    $.each(existingTokens, function (index, token) {
                        if (token.value === e.attrs.value) {
                            e.preventDefault();
                        }
                    });

                    // Available token only
                    var available = false;
                    $.each(that.usedLabels, function (index, token) {
                        if (token === e.attrs.value) {
                            available = true;
                            return false;
                        }
                    });
                    if (!available) {
                        e.preventDefault();
                    }

                })
                .on('tokenfield:createdtoken tokenfield:removedtoken', function (e) {
                    var tokenList = $(this).tokenfield('getTokensList');
                    that.generateFilters.labels_filter = tokenList.length === 0 ? [] : tokenList.split(';');
                    that.generateCutlist(function () {
                        $('#ladb_cutlist_labels_filter-tokenfield', that.$page).focus();
                    });
                })
            ;
            $('#ladb_cutlist_edge_material_names_filter', that.$page)
                .tokenfield($.extend(TOKENFIELD_OPTIONS, {
                    autocomplete: {
                        source: that.usedEdgeMaterialDisplayNames,
                        delay: 100
                    },
                    showAutocompleteOnFocus: false
                }))
                .on('tokenfield:createtoken', function (e) {

                    // Unique token
                    var existingTokens = $(this).tokenfield('getTokens');
                    $.each(existingTokens, function (index, token) {
                        if (token.value === e.attrs.value) {
                            e.preventDefault();
                        }
                    });

                    // Available token only
                    var available = false;
                    $.each(that.usedEdgeMaterialDisplayNames, function (index, token) {
                        if (token === e.attrs.value) {
                            available = true;
                            return false;
                        }
                    });
                    if (!available) {
                        e.preventDefault();
                    }
                })
                .on('tokenfield:createdtoken tokenfield:removedtoken', function (e) {
                    var tokenList = $(this).tokenfield('getTokensList');
                    that.generateFilters.edge_material_names_filter = tokenList.length === 0 ? [] : tokenList.split(';');
                    that.generateCutlist(function () {
                        $('#ladb_cutlist_edge_material_names_filter-tokenfield', that.$page).focus();
                    });
                })
            ;

            // Bind buttons
            $('.ladb-btn-setup-model-units', that.$header).on('click', function() {
                $(this).blur();
                rubyCallCommand('core_open_model_info_page', {
                    page: i18next.t('core.model_info_page.units')
                });
            });
            $('#ladb_cutlist_btn_labels_filter_clear', that.$page).on('click', function () {
                $(this).blur();
                that.generateFilters.labels_filter = [];
                that.generateCutlist();
            });
            $('#ladb_cutlist_btn_edge_material_names_filter_clear', that.$page).on('click', function () {
                $(this).blur();
                that.generateFilters.edge_material_names_filter = [];
                that.generateCutlist();
            });
            $('.ladb-btn-toggle-no-print', that.$page).on('click', function () {
                $(this).blur();
                var $group = $(this).parents('.ladb-cutlist-group');
                if ($group.hasClass('no-print')) {
                    that.showGroup($group);
                } else {
                    that.hideGroup($group);
                }
            });
            $('a.ladb-btn-scrollto', that.$page).on('click', function () {
                $(this).blur();
                var $target = $($(this).attr('href'));
                if ($target.data('group-id')) {
                    that.showGroup($target);
                }
                that.scrollSlideToTarget(null, $target, true, true);
                return false;
            });
            $('a.ladb-btn-material-filter', that.$page).on('click', function () {
                $(this).blur();
                var materialFilter = $(this).data('material-display-name');
                var indexOf = that.generateFilters.edge_material_names_filter.indexOf(materialFilter);
                if (indexOf > -1) {
                    that.generateFilters.edge_material_names_filter.splice(indexOf, 1);
                } else {
                    that.generateFilters.edge_material_names_filter.push(materialFilter);
                }
                that.generateCutlist();
                return false;
            });
            $('a.ladb-btn-edit-material', that.$page).on('click', function () {
                $(this).blur();
                var materialId = $(this).data('material-id');
                that.opencutlist.executeCommandOnTab('materials', 'edit_material', {
                    material_id: materialId
                });
                return false;
            });
            $('a.ladb-btn-add-std-dimension-to-material', that.$page).on('click', function () {
                $(this).blur();
                var $group = $(this).parents('.ladb-cutlist-group');
                var groupId = $group.data('group-id');
                var group = that.findGroupById(groupId);
                if (group) {

                    // Flag to ignore next material change event
                    that.ignoreNextMaterialEvents = true;

                    rubyCallCommand('materials_add_std_dimension_command', { material_name: group.material_name, std_dimension: group.std_dimension }, function (response) {

                        // Flag to stop ignoring next material change event
                        that.ignoreNextMaterialEvents = false;

                        if (response['errors']) {
                            that.opencutlist.notifyErrors(response['errors']);
                        } else {

                            var wTop = $group.offset().top - $(window).scrollTop();

                            // Refresh the list
                            that.generateCutlist(function () {

                                // Try to scroll to the edited group's block
                                var $group = $('#ladb_group_' + groupId, that.$page);
                                if ($group.length > 0) {
                                    that.$rootSlide.animate({ scrollTop: $group.offset().top - wTop }, 0).promise().then(function () {
                                        $group.effect("highlight", {}, 1500);
                                    });
                                }

                            });

                        }
                    });
                }
                return false;
            });
            $('a.ladb-item-edit-material', that.$page).on('click', function () {
                $(this).blur();
                var $group = $(this).parents('.ladb-cutlist-group');
                var groupId = $group.data('group-id');
                var group = that.findGroupById(groupId);
                if (group) {
                    that.opencutlist.executeCommandOnTab('materials', 'edit_material', {
                        material_id: group.material_id
                    });
                }
            });
            $('a.ladb-item-edit-group', that.$page).on('click', function () {
                $(this).blur();
                var $group = $(this).parents('.ladb-cutlist-group');
                var groupId = $group.data('group-id');
                that.editGroup(groupId);
            });
            $('a.ladb-item-highlight-group-parts', that.$page).on('click', function () {
                var $group = $(this).parents('.ladb-cutlist-group');
                var groupId = $group.data('group-id');
                that.highlightGroupParts(groupId);
                $(this).blur();
            });
            $('a.ladb-item-hide-all-other-groups', that.$page).on('click', function () {
                $(this).blur();
                var $group = $(this).parents('.ladb-cutlist-group');
                var groupId = $group.data('group-id');
                that.hideAllGroups(groupId);
                that.scrollSlideToTarget(null, $group, true, false);
            });
            $('a.ladb-item-numbers-save', that.$page).on('click', function () {
                $(this).blur();
                var $group = $(this).parents('.ladb-cutlist-group');
                var groupId = $group.data('group-id');
                var wTop = $group.offset().top - $(window).scrollTop();
                that.numbersSave({ group_id: groupId }, function () {
                    that.$rootSlide.animate({ scrollTop: $('#ladb_group_' + groupId).offset().top - wTop }, 0);
                });
            });
            $('a.ladb-item-numbers-reset', that.$page).on('click', function () {
                $(this).blur();
                var $group = $(this).parents('.ladb-cutlist-group');
                var groupId = $group.data('group-id');
                var wTop = $group.offset().top - $(window).scrollTop();
                that.numbersReset({ group_id: groupId }, function () {
                    that.$rootSlide.animate({ scrollTop: $('#ladb_group_' + groupId).offset().top - wTop }, 0);
                });
            });
            $('button.ladb-btn-group-cuttingdiagram1d', that.$page).on('click', function () {
                $(this).blur();
                var $group = $(this).parents('.ladb-cutlist-group');
                var groupId = $group.data('group-id');
                that.cuttingdiagram1dGroup(groupId);
            });
            $('button.ladb-btn-group-cuttingdiagram2d', that.$page).on('click', function () {
                $(this).blur();
                var $group = $(this).parents('.ladb-cutlist-group');
                var groupId = $group.data('group-id');
                that.cuttingdiagram2dGroup(groupId);
            });
            $('button.ladb-btn-group-dimensions-help', that.$page).on('click', function () {
                $(this).blur();
                var $group = $(this).parents('.ladb-cutlist-group');
                var groupId = $group.data('group-id');
                that.dimensionsHelpGroup(groupId);
            });
            $('.ladb-minitools a[data-tab]', that.$page).on('click', function () {
                $(this).blur();
                var $part = $(this).parents('.ladb-cutlist-row');
                var partId = $part.data('part-id');
                var tab = $(this).data('tab');
                that.editPart(partId, undefined, tab);
                return false;
            });
            $('a.ladb-btn-select-group-parts', that.$page).on('click', function () {
                $(this).blur();
                var $group = $(this).parents('.ladb-cutlist-group');
                var groupId = $group.data('group-id');
                that.selectGroupParts(groupId);
                return false;
            });
            $('a.ladb-btn-select-part, td.ladb-btn-select-part', that.$page)
                .on('click', function () {
                    $(this).blur();
                    var $part = $(this).parents('.ladb-cutlist-row');
                    var partId = $part.data('part-id');
                    that.selectPart(partId);
                    return false;
                })
                .on('dblclick', function() {
                    $(this).blur();
                    var $group = $(this).parents('.ladb-cutlist-group');
                    var groupId = $group.data('group-id');
                    that.selectGroupParts(groupId);
                    return false;
                })
            ;
            $('a.ladb-btn-highlight-part', that.$page).on('click', function () {
                $(this).blur();
                var $part = $(this).parents('.ladb-cutlist-row');
                var partId = $part.data('part-id');
                that.highlightPart(partId);
                return false;
            });
            $('a.ladb-btn-edit-part', that.$page).on('click', function () {
                $(this).blur();
                var $part = $(this).parents('.ladb-cutlist-row');
                var partId = $part.data('part-id');
                that.editPart(partId);
                return false;
            });
            $('a.ladb-btn-folding-toggle-part', that.$page).on('click', function () {
                $(this).blur();
                var $part = $(this).parents('.ladb-cutlist-row-folder');
                that.toggleFoldingPart($part);
                return false;
            });
            $('a.ladb-btn-label-filter', that.$page).on('click', function () {
                $(this).blur();
                var labelFilter = $(this).html();
                var indexOf = that.generateFilters.labels_filter.indexOf(labelFilter);
                if (indexOf > -1) {
                    that.generateFilters.labels_filter.splice(indexOf, 1);
                } else {
                    that.generateFilters.labels_filter.push(labelFilter);
                }
                that.generateCutlist();
                return false;
            });
            $('.ladb-cutlist-row', that.$page).on('click', function () {
                $(this).blur();
                $('.ladb-click-tool', $(this)).first().click();
                return false;
            });

            // Restore button state
            that.$btnGenerate.prop('disabled', false);

            // Stick header
            that.stickSlideHeader(that.$rootSlide);

            // Callback
            if (callback && typeof callback == 'function') {
                callback();
            } else {
                if (errors.length === 0 && warnings.length === 0 && tips.length === 0) {
                    // No callback -> scroll to the first printable group
                    that.scrollSlideToTarget(null, $('.ladb-cutlist-group:not(.no-print)', that.$page).first())
                }
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
                    source: that.opencutlist.getSetting(SETTING_KEY_EXPORT_OPTION_SOURCE, EXPORT_OPTION_DEFAULT_SOURCE),
                    col_sep: that.opencutlist.getSetting(SETTING_KEY_EXPORT_OPTION_COL_SEP, EXPORT_OPTION_DEFAULT_COL_SEP),
                    encoding: that.opencutlist.getSetting(SETTING_KEY_EXPORT_OPTION_ENCODING, EXPORT_OPTION_DEFAULT_ENCODING)
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
                $btnExport.on('click', function () {

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

                    rubyCallCommand('cutlist_export', $.extend(exportOptions, that.generateOptions), function (response) {

                        var i;

                        if (response.errors) {
                            that.opencutlist.notifyErrors(response.errors);
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

        rubyCallCommand('cutlist_highlight_parts', { minimize_on_highlight: that.generateOptions.minimize_on_highlight }, function (response) {

            if (response['errors']) {
                that.opencutlist.notifyErrors(response['errors']);
            } else if (that.generateOptions.minimize_on_highlight) {
                that.opencutlist.minimize();
            }

        });

    };

    LadbTabCutlist.prototype.highlightGroupParts = function (groupId) {
        var that = this;

        rubyCallCommand('cutlist_highlight_parts', { minimize_on_highlight: that.generateOptions.minimize_on_highlight, group_id: groupId }, function (response) {

            if (response['errors']) {
                that.opencutlist.notifyErrors(response['errors']);
            } else if (that.generateOptions.minimize_on_highlight) {
                that.opencutlist.minimize();
            }

        });

    };

    LadbTabCutlist.prototype.highlightPart = function (partId) {
        var that = this;

        var groupAndPart = this.findGroupAndPartById(partId);
        if (groupAndPart) {

            var group = groupAndPart.group;
            var part = groupAndPart.part;

            var isFolder = part.children && part.children.length > 0;
            var isSelected = this.selectionGroupId === group.id && this.selectionPartIds.includes(partId) && this.selectionPartIds.length > 1;
            var multiple = isFolder || isSelected;

            var partIds;
            if (isFolder) {
                partIds = [ partId ];
            } else if (isSelected) {
                partIds = this.selectionPartIds;
            } else {
                partIds = [ partId ];
            }

            rubyCallCommand('cutlist_highlight_parts', { minimize_on_highlight: that.generateOptions.minimize_on_highlight, part_ids: partIds }, function (response) {

                if (response['errors']) {
                    that.opencutlist.notifyErrors(response['errors']);
                } else if (that.generateOptions.minimize_on_highlight) {
                    that.opencutlist.minimize();
                }

            });

        }

    };

    // Parts /////

    LadbTabCutlist.prototype.findGroupAndPartById = function (id) {
        for (var i = 0; i < this.groups.length; i++) {
            var group = this.groups[i];
            for (var j = 0; j < group.parts.length; j++) {
                var part = group.parts[j];
                if (part.id === id) {
                    return { group: group, part: part };
                } else if (part.children !== undefined) {
                    for (var k = 0; k < part.children.length; k++) {
                        var childPart = part.children[k];
                        if (childPart.id === id) {
                            return { group: group, part: childPart };
                        }
                    }
                }
            }
        }
        return null;
    };

    LadbTabCutlist.prototype.findGroupAndPartBySerializedPath = function (serializedPath) {
        for (var i = 0; i < this.groups.length; i++) {
            var group = this.groups[i];
            for (var j = 0; j < group.parts.length; j++) {
                var part = group.parts[j];
                if (part.children !== undefined) {
                    for (var k = 0; k < part.children.length; k++) {
                        var childPart = part.children[k];
                        if (childPart.entity_serialized_paths.includes(serializedPath)) {
                            return { group: group, part: childPart };
                        }
                    }
                } else {
                    if (part.entity_serialized_paths.includes(serializedPath)) {
                        return { group: group, part: part };
                    }
                }
            }
        }
        return null;
    };

    LadbTabCutlist.prototype.renderSelectionOnPart = function (id, selected) {
        var $row = $('#ladb_part_' + id, this.$page);
        var $highlightPartBtn = $('a.ladb-btn-highlight-part', $row);
        var $editPartBtn = $('a.ladb-btn-edit-part', $row);
        var $selectPartBtn = $('a.ladb-btn-select-part', $row);

        if (selected) {
            $selectPartBtn.addClass('ladb-active');
            $highlightPartBtn
                .prop('title', i18next.t('tab.cutlist.tooltip.highlight_parts'))
                .tooltip('fixTitle');
            $editPartBtn
                .prop('title', i18next.t('tab.cutlist.tooltip.edit_parts_properties'))
                .tooltip('fixTitle');
            $('i', $highlightPartBtn).addClass('ladb-opencutlist-icon-magnifier-multiple');
            $('i', $editPartBtn).addClass('ladb-opencutlist-icon-edit-multiple');
            $('i', $selectPartBtn).addClass('ladb-opencutlist-icon-check-box-with-check-sign');
        } else {
            $selectPartBtn.removeClass('ladb-active');
            if ($('i', $highlightPartBtn).hasClass('ladb-opencutlist-icon-magnifier')) {
                $highlightPartBtn
                    .prop('title', i18next.t('tab.cutlist.tooltip.highlight_part'))
                    .tooltip('fixTitle');
                $('i', $highlightPartBtn).removeClass('ladb-opencutlist-icon-magnifier-multiple');
            }
            if ($('i', $editPartBtn).hasClass('ladb-opencutlist-icon-edit')) {
                $editPartBtn
                    .prop('title', i18next.t('tab.cutlist.tooltip.edit_part_properties'))
                    .tooltip('fixTitle');
                $('i', $editPartBtn).removeClass('ladb-opencutlist-icon-edit-multiple');
            }
            $('i', $selectPartBtn).removeClass('ladb-opencutlist-icon-check-box-with-check-sign');
        }
    };

    LadbTabCutlist.prototype.renderSelection = function () {
        for (var i = 0; i < this.selectionPartIds.length; i++) {
            this.renderSelectionOnPart(this.selectionPartIds[i], true);
        }
    };

    LadbTabCutlist.prototype.cleanupSelection = function () {
        for (var i = this.selectionPartIds.length - 1; i >= 0 ; i--) {
            if (!this.findGroupAndPartById(this.selectionPartIds[i])) {
                this.selectionPartIds.splice(i, 1)
            }
        }
    };

    LadbTabCutlist.prototype.selectPart = function (partId, state /* undefined = TOGGLE, true = SELECT, false = UNSELECT */) {
        var groupAndPart = this.findGroupAndPartById(partId);
        if (groupAndPart) {

            // Unselect other group selection
            if (this.selectionGroupId !== null && this.selectionGroupId !== groupAndPart.group.id) {
                this.selectGroupParts(this.selectionGroupId, false);
            }

            // Manage selection
            var selected = this.selectionGroupId === groupAndPart.group.id && this.selectionPartIds.includes(partId);
            if (selected) {
                if (state === undefined || state === false) {
                    this.selectionPartIds.splice(this.selectionPartIds.indexOf(partId), 1);
                    if (this.selectionPartIds.length === 0) {
                        this.selectionGroupId = null;
                    }
                    selected = false;
                }
            } else {
                if (state === undefined || state === true) {
                    this.selectionPartIds.push(partId);
                    this.selectionGroupId = groupAndPart.group.id;
                    selected = true;
                }
            }

            // Apply selection
            this.renderSelectionOnPart(partId, selected);

        }
    };

    LadbTabCutlist.prototype.selectGroupParts = function (groupId, state /* undefined = TOGGLE, true = SELECT, false = UNSELECT */) {
        var group = this.findGroupById(groupId);
        if (group) {

            if (state === undefined) {
                state = !(this.selectionGroupId === group.id && this.selectionPartIds.length > 0);
            }
            for (var i = 0 ; i < group.parts.length; i++) {
                this.selectPart(group.parts[i].id, state);
            }

        }
    };

    LadbTabCutlist.prototype.editPart = function (id, serializedPath, tab) {
        var that = this;

        var groupAndPart = id ? this.findGroupAndPartById(id) : (serializedPath ? this.findGroupAndPartBySerializedPath(serializedPath) : null);
        if (groupAndPart) {

            var group = groupAndPart.group;
            var part = groupAndPart.part;

            var isFolder = part.children && part.children.length > 0;
            var isSelected = this.selectionGroupId === group.id && this.selectionPartIds.includes(id) && this.selectionPartIds.length > 1;
            var multiple = isFolder || isSelected;

            var editedPart = JSON.parse(JSON.stringify(isFolder ? part.children[0] : part));
            var editedParts = [];
            if (multiple) {
                if (isFolder && !isSelected) {
                    for (var i = 0; i < part.children.length; i++) {
                        editedParts.push(part.children[i]);
                    }
                } else if (isSelected) {
                    for (var i = 0; i < this.selectionPartIds.length; i++) {
                        var groupAndPart = that.findGroupAndPartById(this.selectionPartIds[i]);
                        if (groupAndPart) {
                            if (groupAndPart.part.children) {
                                for (var j = 0; j < groupAndPart.part.children.length; j++) {
                                    editedParts.push(groupAndPart.part.children[j]);
                                }
                            } else {
                                editedParts.push(groupAndPart.part);
                            }
                        }
                    }
                }
            } else {
                editedParts.push(editedPart);
            }

            for (var i = 0; i < editedParts.length; i++) {
                if (editedPart.cumulable !== editedParts[i].cumulable) {
                    editedPart.cumulable = MULTIPLE_VALUE;
                }
                editedPart.labels = editedPart.labels.filter(function(label) {  // Extract only commun labels
                    return -1 !== editedParts[i].labels.indexOf(label);
                });
                if (editedPart.edge_material_names.ymin !== editedParts[i].edge_material_names.ymin) {
                    editedPart.edge_material_names.ymin = MULTIPLE_VALUE;
                }
                if (editedPart.edge_material_names.ymax !== editedParts[i].edge_material_names.ymax) {
                    editedPart.edge_material_names.ymax = MULTIPLE_VALUE;
                }
                if (editedPart.edge_material_names.xmin !== editedParts[i].edge_material_names.xmin) {
                    editedPart.edge_material_names.xmin = MULTIPLE_VALUE;
                }
                if (editedPart.edge_material_names.xmax !== editedParts[i].edge_material_names.xmax) {
                    editedPart.edge_material_names.xmax = MULTIPLE_VALUE;
                }
            }

            var fnOpenModal = function(thumbnailFile) {

                var $modal = that.appendModalInside('ladb_cutlist_modal_part', 'tabs/cutlist/_modal-part.twig', {
                    group: group,
                    part: editedPart,
                    part_count: editedParts.length,
                    multiple: multiple,
                    thumbnailFile: thumbnailFile,
                    materialUsages: that.materialUsages,
                    tab: tab === undefined || tab.length === 0 ? 'general' : tab
                }, true);

                var isOwnedMaterial = true;
                for (var i = 0; i < editedPart.material_origins.length; i++) {
                    if (editedPart.material_origins[i] !== 1) {    // 1 = MATERIAL_ORIGIN_OWNED
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
                var $inputPartAxes = $('#ladb_cutlist_part_input_axes', $modal);
                var $sortablePartAxes = $('#ladb_sortable_part_axes', $modal);
                var $sortablePartAxesExtra = $('#ladb_sortable_part_axes_extra', $modal);
                var $selectPartAxesOriginPosition = $('#ladb_cutlist_part_select_axes_origin_position', $modal);
                var $selectEdgeYmaxMaterialName = $('#ladb_cutlist_part_select_edge_ymax_material_name', $modal);
                var $selectEdgeYminMaterialName = $('#ladb_cutlist_part_select_edge_ymin_material_name', $modal);
                var $selectEdgeXminMaterialName = $('#ladb_cutlist_part_select_edge_xmin_material_name', $modal);
                var $selectEdgeXmaxMaterialName = $('#ladb_cutlist_part_select_edge_xmax_material_name', $modal);
                var $rectEdgeYmax = $('svg .edge-ymax', $modal);
                var $rectEdgeYmin = $('svg .edge-ymin', $modal);
                var $rectEdgeXmin = $('svg .edge-xmin', $modal);
                var $rectEdgeXmax = $('svg .edge-xmax', $modal);
                var $labelEdgeYmax = $('#ladb_cutlist_part_label_edge_ymax', $modal);
                var $labelEdgeYmin = $('#ladb_cutlist_part_label_edge_ymin', $modal);
                var $labelEdgeXmin = $('#ladb_cutlist_part_label_edge_xmin', $modal);
                var $labelEdgeXmax = $('#ladb_cutlist_part_label_edge_xmax', $modal);
                var $btnHighlight = $('#ladb_cutlist_part_highlight', $modal);
                var $btnUpdate = $('#ladb_cutlist_part_update', $modal);

                // Utils function
                var fnComputeAxesOrder = function () {
                    var axes = [];
                    $sortablePartAxes.children('li').each(function () {
                        axes.push($(this).data('axis'));
                    });
                    $inputPartAxes.val(axes);

                    // By default check Orientation Lokked On Axis option
                    $inputOrientationLockedOnAxis.prop('checked', true);
                    fnDisplayAxisDimensions();

                };
                var fnDisplayAxisDimensions = function () {
                    if (!that.generateOptions.auto_orient || $inputOrientationLockedOnAxis.is(':checked')) {
                        $sortablePartAxes.closest('div').switchClass('col-xs-12', 'col-xs-10', 0);
                        $sortablePartAxesExtra.closest('div').show();
                        $('li .ladb-info', $sortablePartAxes).each(function () {
                            $(this).hide();
                        });
                    } else {
                        $sortablePartAxes.closest('div').switchClass('col-xs-10', 'col-xs-12', 0);
                        $sortablePartAxesExtra.closest('div').hide();
                        $('li .ladb-info', $sortablePartAxes).each(function () {
                            $(this).show();
                        });
                    }
                };
                fnDisplayAxisDimensions();

                var fnUpdateEdgesPreview = function() {
                    if ($selectEdgeYmaxMaterialName.val() === '') {
                        $rectEdgeYmax.removeClass('ladb-active');
                    } else {
                        $rectEdgeYmax.addClass('ladb-active');
                    }
                    if ($selectEdgeYminMaterialName.val() === '') {
                        $rectEdgeYmin.removeClass('ladb-active');
                    } else {
                        $rectEdgeYmin.addClass('ladb-active');
                    }
                    if ($selectEdgeXminMaterialName.val() === '') {
                        $rectEdgeXmin.removeClass('ladb-active');
                    } else {
                        $rectEdgeXmin.addClass('ladb-active');
                    }
                    if ($selectEdgeXmaxMaterialName.val() === '') {
                        $rectEdgeXmax.removeClass('ladb-active');
                    } else {
                        $rectEdgeXmax.addClass('ladb-active');
                    }
                };

                var fnNewCheck = function($select, type) {
                    if ($select.val() === 'new') {
                        that.opencutlist.executeCommandOnTab('materials', 'new_material', { type: type });
                        $modal.modal('hide');
                        return true;
                    }
                    return false;
                };

                var fnMaterialNameCopyToAllEdges = function(materialName) {
                    if (materialName !== MULTIPLE_VALUE) {
                        if (!$selectEdgeYmaxMaterialName.prop( "disabled")) {
                            $selectEdgeYmaxMaterialName.selectpicker('val', materialName);
                        }
                        if (!$selectEdgeYminMaterialName.prop( "disabled")) {
                            $selectEdgeYminMaterialName.selectpicker('val', materialName);
                        }
                        if (!$selectEdgeXminMaterialName.prop( "disabled")) {
                            $selectEdgeXminMaterialName.selectpicker('val', materialName);
                        }
                        if (!$selectEdgeXmaxMaterialName.prop( "disabled")) {
                            $selectEdgeXmaxMaterialName.selectpicker('val', materialName);
                        }
                        fnUpdateEdgesPreview();
                    }
                };

                // Bind select
                if (isOwnedMaterial) {
                    $selectMaterialName.val(editedPart.material_name);
                }
                $selectMaterialName
                    .selectpicker(SELECT_PICKER_OPTIONS)
                    .on('changed.bs.select', function (e, clickedIndex, isSelected, previousValue) {
                        fnNewCheck($(this));
                    });
                $selectCumulable.val(editedPart.cumulable);
                $selectCumulable.selectpicker(SELECT_PICKER_OPTIONS);
                $selectPartAxesOriginPosition
                    .selectpicker(SELECT_PICKER_OPTIONS)
                    .on('changed.bs.select', function (e, clickedIndex, isSelected, previousValue) {
                        fnComputeAxesOrder();
                    });
                $selectEdgeYminMaterialName.val(editedPart.edge_material_names.ymin);
                $selectEdgeYminMaterialName
                    .selectpicker(SELECT_PICKER_OPTIONS)
                    .on('changed.bs.select', function (e, clickedIndex, isSelected, previousValue) {
                        if (!fnNewCheck($(this), 4 /* TYPE_EDGE */)) {
                            fnUpdateEdgesPreview();
                        }
                    });
                $selectEdgeYmaxMaterialName.val(editedPart.edge_material_names.ymax);
                $selectEdgeYmaxMaterialName
                    .selectpicker(SELECT_PICKER_OPTIONS)
                    .on('changed.bs.select', function (e, clickedIndex, isSelected, previousValue) {
                        if (!fnNewCheck($(this), 4 /* TYPE_EDGE */)) {
                            fnUpdateEdgesPreview();
                        }
                    });
                $selectEdgeXminMaterialName.val(editedPart.edge_material_names.xmin);
                $selectEdgeXminMaterialName
                    .selectpicker(SELECT_PICKER_OPTIONS)
                    .on('changed.bs.select', function (e, clickedIndex, isSelected, previousValue) {
                        if (!fnNewCheck($(this), 4 /* TYPE_EDGE */)) {
                            fnUpdateEdgesPreview();
                        }
                    });
                $selectEdgeXmaxMaterialName.val(editedPart.edge_material_names.xmax);
                $selectEdgeXmaxMaterialName
                    .selectpicker(SELECT_PICKER_OPTIONS)
                    .on('changed.bs.select', function (e, clickedIndex, isSelected, previousValue) {
                        if (!fnNewCheck($(this), 4 /* TYPE_EDGE */)) {
                            fnUpdateEdgesPreview();
                        }
                    });

                // Bind edges
                $rectEdgeYmin.on('click', function() {
                    $selectEdgeYminMaterialName.selectpicker('toggle');
                });
                $rectEdgeYmax.on('click', function() {
                    $selectEdgeYmaxMaterialName.selectpicker('toggle');
                });
                $rectEdgeXmin.on('click', function() {
                    $selectEdgeXminMaterialName.selectpicker('toggle');
                });
                $rectEdgeXmax.on('click', function() {
                    $selectEdgeXmaxMaterialName.selectpicker('toggle');
                });

                // Bind sorter
                $sortablePartAxes.sortable({
                    cursor: 'ns-resize',
                    handle: '.ladb-handle',
                    stop: function (event, ui) {
                        fnComputeAxesOrder();
                    }
                });

                // Bind checkbox
                $inputOrientationLockedOnAxis.on('change', fnDisplayAxisDimensions);

                // Bind labels
                $labelEdgeYmax.on('dblclick', function() {
                    fnMaterialNameCopyToAllEdges($selectEdgeYmaxMaterialName.val());
                });
                $labelEdgeYmin.on('dblclick', function() {
                    fnMaterialNameCopyToAllEdges($selectEdgeYminMaterialName.val());
                });
                $labelEdgeXmin.on('dblclick', function() {
                    fnMaterialNameCopyToAllEdges($selectEdgeXminMaterialName.val());
                });
                $labelEdgeXmax.on('dblclick', function() {
                    fnMaterialNameCopyToAllEdges($selectEdgeXmaxMaterialName.val());
                });

                // Bind buttons
                $btnHighlight.on('click', function () {
                    this.blur();
                    that.highlightPart(id);
                    return false;
                });
                $btnUpdate.on('click', function () {

                    for (var i = 0; i < editedParts.length; i++) {

                        if (!multiple) {

                            editedParts[i].name = $inputName.val();

                            editedParts[i].orientation_locked_on_axis = $inputOrientationLockedOnAxis.is(':checked');
                            editedParts[i].axes_order = $inputPartAxes.val().length > 0 ? $inputPartAxes.val().split(',') : [];
                            editedParts[i].axes_origin_position = $selectPartAxesOriginPosition.val();

                        }

                        editedParts[i].material_name = $selectMaterialName.val();
                        if ($selectCumulable.val() !== MULTIPLE_VALUE) {
                            editedParts[i].cumulable = $selectCumulable.val();
                        }

                        var untouchLabels = editedParts[i].labels.filter(function (label) { return !editedPart.labels.includes(label) });
                        editedParts[i].labels = untouchLabels.concat($inputLabels.tokenfield('getTokensList').split(';'));

                        if ($selectEdgeYminMaterialName.val() !== MULTIPLE_VALUE) {
                            editedParts[i].edge_material_names.ymin = $selectEdgeYminMaterialName.val();
                        }
                        if ($selectEdgeYmaxMaterialName.val() !== MULTIPLE_VALUE) {
                            editedParts[i].edge_material_names.ymax = $selectEdgeYmaxMaterialName.val();
                        }
                        if ($selectEdgeXminMaterialName.val() !== MULTIPLE_VALUE) {
                            editedParts[i].edge_material_names.xmin = $selectEdgeXminMaterialName.val();
                        }
                        if ($selectEdgeXmaxMaterialName.val() !== MULTIPLE_VALUE) {
                            editedParts[i].edge_material_names.xmax = $selectEdgeXmaxMaterialName.val();
                        }

                    }

                    rubyCallCommand('cutlist_part_update', { parts_data: editedParts }, function (response) {

                        if (response['errors']) {

                            that.opencutlist.notifyErrors(response['errors']);

                        } else {

                            var partId = editedPart.id;
                            var wTop = $('#ladb_part_' + partId).offset().top - $(window).scrollTop();

                            // Refresh the list
                            that.generateCutlist(function () {

                                // Try to scroll to the edited part's row
                                var $part = $('#ladb_part_' + partId, that.$page);
                                if ($part.length > 0) {
                                    if ($part.hasClass('hide')) {
                                        that.expandFoldingPart($('#ladb_part_' + $part.data('folder-id')));
                                    }
                                    $part.effect("highlight", {}, 1500);
                                    that.$rootSlide.animate({ scrollTop: $part.offset().top - wTop }, 0);
                                }

                            });

                            // Hide modal
                            $modal.modal('hide');

                        }

                    });

                });

                // Init edges preview
                fnUpdateEdgesPreview();

                // Show modal
                $modal.modal('show');

                // Focus
                $inputName.focus();

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

                // Setup popovers and tooltips
                that.opencutlist.setupPopovers();
                that.opencutlist.setupTooltips();

            };

            if (multiple) {
                fnOpenModal();
            } else {

                // Generate and Retrieve part thumbnail file
                rubyCallCommand('cutlist_part_get_thumbnail', part, function (response) {
                    var thumbnailFile = response['thumbnail_file'];
                    fnOpenModal(thumbnailFile);
                });

            }

        } else {

            var $modal = this.appendModalInside('ladb_cutlist_modal_unknow_part', 'tabs/cutlist/_modal-unknow-part.twig');

            // Show modal
            $modal.modal('show');

        }
    };

    LadbTabCutlist.prototype.toggleFoldingPart = function ($part) {
        var $btn = $('.ladb-btn-folding-toggle-part', $part);
        var $i = $('i', $btn);

        if ($i.hasClass('ladb-opencutlist-icon-arrow-down')) {
            this.expandFoldingPart($part);
        } else {
            this.collapseFoldingPart($part);
        }
    };

    LadbTabCutlist.prototype.expandFoldingPart = function ($part) {
        var partId = $part.data('part-id');
        var $btn = $('.ladb-btn-folding-toggle-part', $part);
        var $i = $('i', $btn);

        $i.addClass('ladb-opencutlist-icon-arrow-up');
        $i.removeClass('ladb-opencutlist-icon-arrow-down');

        // Show children
        $('tr[data-folder-id=' + partId + ']', this.$page).removeClass('hide');

    };

    LadbTabCutlist.prototype.collapseFoldingPart = function ($part) {
        var partId = $part.data('part-id');
        var $btn = $('.ladb-btn-folding-toggle-part', $part);
        var $i = $('i', $btn);

        $i.addClass('ladb-opencutlist-icon-arrow-down');
        $i.removeClass('ladb-opencutlist-icon-arrow-up');

        // Hide children
        $('tr[data-folder-id=' + partId + ']', this.$page).addClass('hide');

    };

    LadbTabCutlist.prototype.expandAllFoldingPart = function () {
        var that = this;
        $('.ladb-cutlist-row-folder', this.$page).each(function () {
            that.expandFoldingPart($(this));
        });
    };

    LadbTabCutlist.prototype.collapseAllFoldingPart = function () {
        var that = this;
        $('.ladb-cutlist-row-folder', this.$page).each(function () {
            that.collapseFoldingPart($(this));
        });
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

    LadbTabCutlist.prototype.saveUIOptionsHiddenGroupIds = function () {
        this.opencutlist.setSetting(SETTING_KEY_OPTION_HIDDEN_GROUP_IDS, this.generateOptions.hidden_group_ids, 2 /* SETTINGS_RW_STRATEGY_MODEL */);
    };

    LadbTabCutlist.prototype.showGroup = function ($group, doNotFlushSettings) {
        var groupId = $group.data('group-id');
        var $btn = $('.ladb-btn-toggle-no-print', $group);
        var $i = $('i', $btn);
        var $summaryRow = $('#' + $group.attr('id') + '_summary');

        $group.removeClass('no-print');
        $i.addClass('ladb-opencutlist-icon-eye-close');
        $i.removeClass('ladb-opencutlist-icon-eye-open');
        $summaryRow.removeClass('ladb-mute');

        var idx = this.generateOptions.hidden_group_ids.indexOf(groupId);
        if (idx !== -1) {
            this.generateOptions.hidden_group_ids.splice(idx, 1);
            if (doNotFlushSettings === undefined || !doNotFlushSettings) {
                this.saveUIOptionsHiddenGroupIds();
            }
        }

    };

    LadbTabCutlist.prototype.hideGroup = function ($group, doNotFlushSettings) {
        var groupId = $group.data('group-id');
        var $btn = $('.ladb-btn-toggle-no-print', $group);
        var $i = $('i', $btn);
        var $summaryRow = $('#' + $group.attr('id') + '_summary');

        $group.addClass('no-print');
        $i.removeClass('ladb-opencutlist-icon-eye-close');
        $i.addClass('ladb-opencutlist-icon-eye-open');
        $summaryRow.addClass('ladb-mute');

        var idx = this.generateOptions.hidden_group_ids.indexOf(groupId);
        if (idx === -1) {
            this.generateOptions.hidden_group_ids.push(groupId);
            if (doNotFlushSettings === undefined || !doNotFlushSettings) {
                this.saveUIOptionsHiddenGroupIds();
            }
        }

    };

    LadbTabCutlist.prototype.showAllGroups = function () {
        var that = this;
        $('.ladb-cutlist-group', this.$page).each(function () {
            that.showGroup($(this), true);
        }).promise().done( function (){
            that.saveUIOptionsHiddenGroupIds();
        });
    };

    LadbTabCutlist.prototype.hideAllGroups = function (exceptedGroupId) {
        var that = this;
        $('.ladb-cutlist-group', this.$page).each(function () {
            var groupId = $(this).data('group-id');
            if (exceptedGroupId && groupId !== exceptedGroupId) {
                that.hideGroup($(this), true);
            }
        }).promise().done( function (){
            that.saveUIOptionsHiddenGroupIds();
        });
    };

    LadbTabCutlist.prototype.cuttingdiagram1dGroup = function (groupId) {
        var that = this;

        var group = this.findGroupById(groupId);

        // Retrieve cutting diagram options
        this.opencutlist.pullSettings([

                // Defaults
                SETTING_KEY_CUTTINGDIAGRAM1D_OPTION_BAR_FOLDING,
                SETTING_KEY_CUTTINGDIAGRAM1D_OPTION_HIDE_PART_LIST,
                SETTING_KEY_CUTTINGDIAGRAM1D_OPTION_BREAK_LENGTH,
                SETTING_KEY_CUTTINGDIAGRAM1D_OPTION_SAW_KERF,
                SETTING_KEY_CUTTINGDIAGRAM1D_OPTION_TRIMMING,

                SETTING_KEY_CUTTINGDIAGRAM1D_OPTION_STD_BAR + '_' + groupId,
                SETTING_KEY_CUTTINGDIAGRAM1D_OPTION_STD_BAR_LENGTH + '_' + groupId,
                SETTING_KEY_CUTTINGDIAGRAM1D_OPTION_SCRAP_BAR_LENGTHS + '_' + groupId,
                SETTING_KEY_CUTTINGDIAGRAM1D_OPTION_BAR_FOLDING + '_' + groupId,
                SETTING_KEY_CUTTINGDIAGRAM1D_OPTION_HIDE_PART_LIST + '_' + groupId,
                SETTING_KEY_CUTTINGDIAGRAM1D_OPTION_BREAK_LENGTH + '_' + groupId,
                SETTING_KEY_CUTTINGDIAGRAM1D_OPTION_SAW_KERF + '_' + groupId,
                SETTING_KEY_CUTTINGDIAGRAM1D_OPTION_TRIMMING + '_' + groupId,

            ],
            2 /* SETTINGS_RW_STRATEGY_MODEL */,
            function () {

                var cuttingdiagram1dOptions = {
                    std_bar: that.opencutlist.getSetting(SETTING_KEY_CUTTINGDIAGRAM1D_OPTION_STD_BAR + '_' + groupId, CUTTINGDIAGRAM1D_OPTION_DEFAULT_STD_BAR),
                    std_bar_length: that.opencutlist.getSetting(SETTING_KEY_CUTTINGDIAGRAM1D_OPTION_STD_BAR_LENGTH + '_' + groupId, CUTTINGDIAGRAM1D_OPTION_DEFAULT_STD_BAR_LENGTH),
                    scrap_bar_lengths: that.opencutlist.getSetting(SETTING_KEY_CUTTINGDIAGRAM1D_OPTION_SCRAP_BAR_LENGTHS + '_' + groupId, CUTTINGDIAGRAM1D_OPTION_DEFAULT_SCRAP_BAR_LENGTHS),
                    bar_folding: that.opencutlist.getSetting(SETTING_KEY_CUTTINGDIAGRAM1D_OPTION_BAR_FOLDING + '_' + groupId, that.opencutlist.getSetting(SETTING_KEY_CUTTINGDIAGRAM1D_OPTION_BAR_FOLDING, CUTTINGDIAGRAM1D_OPTION_DEFAULT_BAR_FOLDING)),
                    hide_part_list: that.opencutlist.getSetting(SETTING_KEY_CUTTINGDIAGRAM1D_OPTION_HIDE_PART_LIST + '_' + groupId, that.opencutlist.getSetting(SETTING_KEY_CUTTINGDIAGRAM1D_OPTION_HIDE_PART_LIST, CUTTINGDIAGRAM1D_OPTION_DEFAULT_HIDE_PART_LIST)),
                    break_length: that.opencutlist.getSetting(SETTING_KEY_CUTTINGDIAGRAM1D_OPTION_BREAK_LENGTH + '_' + groupId, that.opencutlist.getSetting(SETTING_KEY_CUTTINGDIAGRAM1D_OPTION_BREAK_LENGTH, CUTTINGDIAGRAM1D_OPTION_DEFAULT_BREAK_LENGTH)),
                    saw_kerf: that.opencutlist.getSetting(SETTING_KEY_CUTTINGDIAGRAM1D_OPTION_SAW_KERF + '_' + groupId, that.opencutlist.getSetting(SETTING_KEY_CUTTINGDIAGRAM1D_OPTION_SAW_KERF, CUTTINGDIAGRAM1D_OPTION_DEFAULT_SAW_KERF)),
                    trimming: that.opencutlist.getSetting(SETTING_KEY_CUTTINGDIAGRAM1D_OPTION_TRIMMING + '_' + groupId, that.opencutlist.getSetting(SETTING_KEY_CUTTINGDIAGRAM1D_OPTION_TRIMMING, CUTTINGDIAGRAM1D_OPTION_DEFAULT_TRIMMING)),
                };

                rubyCallCommand('materials_get_attributes_command', { name: group.material_name }, function (response) {

                    var $modal = that.appendModalInside('ladb_cutlist_modal_cuttingdiagram_1d', 'tabs/cutlist/_modal-cuttingdiagram-1d.twig', { material_attributes: response, group: group });

                    // Fetch UI elements
                    var $inputStdBar = $('#ladb_select_std_bar', $modal);
                    var $inputStdBarLength = $('#ladb_input_std_bar_length', $modal);
                    var $inputScrapBarLengths = $('#ladb_input_scrap_bar_lengths', $modal);
                    var $selectBarFolding = $('#ladb_select_bar_folding', $modal);
                    var $selectHidePartList = $('#ladb_select_hide_part_list', $modal);
                    var $inputBreakLength = $('#ladb_input_break_length', $modal);
                    var $inputSawKerf = $('#ladb_input_saw_kerf', $modal);
                    var $inputTrimming = $('#ladb_input_trimming', $modal);
                    var $btnCuttingdiagramOptionsDefaultsSave = $('#ladb_btn_cuttingdiagram_options_defaults_save', $modal);
                    var $btnCuttingdiagramOptionsDefaultsReset = $('#ladb_btn_cuttingdiagram_options_defaults_reset', $modal);
                    var $btnEditMaterial = $('#ladb_btn_edit_material', $modal);
                    var $btnCuttingdiagram = $('#ladb_btn_cuttingdiagram', $modal);

                    if (cuttingdiagram1dOptions.std_bar) {
                        $inputStdBar.val(cuttingdiagram1dOptions.std_bar);
                        if ($inputStdBar.val() == null && response.std_lengths.length === 0) {
                            $inputStdBar.val('0');  // Special case if the std_sheet is not present anymore in the list and no std size defined. Select "none" by default.
                        }
                    }
                    $inputScrapBarLengths.val(cuttingdiagram1dOptions.scrap_bar_lengths);
                    $inputStdBar.selectpicker(SELECT_PICKER_OPTIONS);
                    $selectBarFolding.val(cuttingdiagram1dOptions.bar_folding ? '1' : '0');
                    $selectBarFolding.selectpicker(SELECT_PICKER_OPTIONS);
                    $selectHidePartList.val(cuttingdiagram1dOptions.hide_part_list ? '1' : '0');
                    $selectHidePartList.selectpicker(SELECT_PICKER_OPTIONS);
                    $inputBreakLength.val(cuttingdiagram1dOptions.break_length);
                    $inputSawKerf.val(cuttingdiagram1dOptions.saw_kerf);
                    $inputTrimming.val(cuttingdiagram1dOptions.trimming);

                    var fnEditMaterial = function (callback) {

                        // Hide modal
                        $modal.modal('hide');

                        // Edit material and focus std_sizes input field
                        that.opencutlist.executeCommandOnTab('materials', 'edit_material', {
                            material_id: group.material_id,
                            callback: callback
                        });

                    };
                    var fnSelectSize = function () {
                        var value = $inputStdBar.val();
                        if (value === 'add') {
                            fnEditMaterial(function ($editMaterialModal) {
                                $('#ladb_materials_input_std_lengths', $editMaterialModal).siblings('.token-input').focus();
                            });
                        } else {
                            $inputStdBarLength.val(value);
                        }
                    };

                    $inputStdBar.on('changed.bs.select', function (e) {
                        fnSelectSize();
                    });
                    fnSelectSize();

                    // Bind buttons
                    $btnCuttingdiagramOptionsDefaultsSave.on('click', function () {

                        var saw_kerf = $inputSawKerf.val();
                        var trimming = $inputTrimming.val();

                        // Update default cut options for specific type to last used
                        that.opencutlist.setSettings([
                            { key:SETTING_KEY_CUTTINGDIAGRAM1D_OPTION_SAW_KERF, value:saw_kerf, preprocessor:1 /* SETTINGS_PREPROCESSOR_D */ },
                            { key:SETTING_KEY_CUTTINGDIAGRAM1D_OPTION_TRIMMING, value:trimming, preprocessor:1 /* SETTINGS_PREPROCESSOR_D */ },
                        ], 0 /* SETTINGS_RW_STRATEGY_GLOBAL */);

                        that.opencutlist.notify(i18next.t('tab.cutlist.cuttingdiagram.options_defaults.save_success'), 'success');

                        this.blur();

                    });
                    $btnCuttingdiagramOptionsDefaultsReset.on('click', function () {

                        var bar_folding = that.opencutlist.getSetting(SETTING_KEY_CUTTINGDIAGRAM1D_OPTION_BAR_FOLDING, CUTTINGDIAGRAM1D_OPTION_DEFAULT_BAR_FOLDING);
                        var hide_part_list = that.opencutlist.getSetting(SETTING_KEY_CUTTINGDIAGRAM1D_OPTION_HIDE_PART_LIST, CUTTINGDIAGRAM1D_OPTION_DEFAULT_HIDE_PART_LIST);
                        var break_length = that.opencutlist.getSetting(SETTING_KEY_CUTTINGDIAGRAM1D_OPTION_BREAK_LENGTH, CUTTINGDIAGRAM1D_OPTION_DEFAULT_BREAK_LENGTH);
                        var saw_kerf = that.opencutlist.getSetting(SETTING_KEY_CUTTINGDIAGRAM1D_OPTION_SAW_KERF, CUTTINGDIAGRAM1D_OPTION_DEFAULT_SAW_KERF);
                        var trimming = that.opencutlist.getSetting(SETTING_KEY_CUTTINGDIAGRAM1D_OPTION_TRIMMING, CUTTINGDIAGRAM1D_OPTION_DEFAULT_TRIMMING);

                        $selectBarFolding.selectpicker('val', bar_folding ? '1' : '0');
                        $selectHidePartList.selectpicker('val', hide_part_list ? '1' : '0');
                        $inputBreakLength.val(break_length);
                        $inputSawKerf.val(saw_kerf);
                        $inputTrimming.val(trimming);

                        this.blur();

                    });
                    $btnEditMaterial.on('click', function () {
                        fnEditMaterial();
                    });
                    $btnCuttingdiagram.on('click', function () {

                        // Fetch options

                        cuttingdiagram1dOptions.std_bar = $inputStdBar.val();
                        cuttingdiagram1dOptions.std_bar_length = $inputStdBarLength.val();
                        cuttingdiagram1dOptions.scrap_bar_lengths = $inputScrapBarLengths.val();
                        cuttingdiagram1dOptions.bar_folding = $selectBarFolding.val() === '1';
                        cuttingdiagram1dOptions.hide_part_list = $selectHidePartList.val() === '1';
                        cuttingdiagram1dOptions.break_length = $inputBreakLength.val();
                        cuttingdiagram1dOptions.saw_kerf = $inputSawKerf.val();
                        cuttingdiagram1dOptions.trimming = $inputTrimming.val();

                        // Store options
                        that.opencutlist.setSettings([
                            { key:SETTING_KEY_CUTTINGDIAGRAM1D_OPTION_STD_BAR + '_' + groupId, value:cuttingdiagram1dOptions.std_bar },
                            { key:SETTING_KEY_CUTTINGDIAGRAM1D_OPTION_STD_BAR_LENGTH + '_' + groupId, value:cuttingdiagram1dOptions.std_bar_length, preprocessor:1 /* SETTINGS_PREPROCESSOR_D */ },
                            { key:SETTING_KEY_CUTTINGDIAGRAM1D_OPTION_SCRAP_BAR_LENGTHS + '_' + groupId, value:cuttingdiagram1dOptions.scrap_bar_lengths, preprocessor:1 /* SETTINGS_PREPROCESSOR_D */ },
                            { key:SETTING_KEY_CUTTINGDIAGRAM1D_OPTION_BAR_FOLDING + '_' + groupId, value:cuttingdiagram1dOptions.bar_folding },
                            { key:SETTING_KEY_CUTTINGDIAGRAM1D_OPTION_HIDE_PART_LIST + '_' + groupId, value:cuttingdiagram1dOptions.hide_part_list },
                            { key:SETTING_KEY_CUTTINGDIAGRAM1D_OPTION_BREAK_LENGTH + '_' + groupId, value:cuttingdiagram1dOptions.break_length, preprocessor:1 /* SETTINGS_PREPROCESSOR_D */ },
                            { key:SETTING_KEY_CUTTINGDIAGRAM1D_OPTION_SAW_KERF + '_' + groupId, value:cuttingdiagram1dOptions.saw_kerf, preprocessor:1 /* SETTINGS_PREPROCESSOR_D */ },
                            { key:SETTING_KEY_CUTTINGDIAGRAM1D_OPTION_TRIMMING + '_' + groupId, value:cuttingdiagram1dOptions.trimming, preprocessor:1 /* SETTINGS_PREPROCESSOR_D */ },

                        ], 2 /* SETTINGS_RW_STRATEGY_MODEL */);

                        rubyCallCommand('cutlist_group_cuttingdiagram_1d', $.extend({ group_id: groupId }, cuttingdiagram1dOptions, that.generateOptions), function (response) {

                            var $slide = that.pushNewSlide('ladb_cutlist_slide_cuttingdiagram_1d', 'tabs/cutlist/_slide-cuttingdiagram-1d.twig', $.extend({
                                generateOptions: that.generateOptions,
                                dimensionColumnOrderStrategy: that.generateOptions.dimension_column_order_strategy.split('>'),
                                filename: that.filename,
                                pageLabel: that.pageLabel,
                                lengthUnit: that.lengthUnit,
                                generatedAt: new Date().getTime() / 1000,
                                group: group
                            }, response), function () {
                                that.opencutlist.setupTooltips();
                            });

                            // Fetch UI elements
                            var $btnCuttingDiagram = $('#ladb_btn_cuttingdiagram', $slide);
                            var $btnPrint = $('#ladb_btn_print', $slide);
                            var $btnClose = $('#ladb_btn_close', $slide);

                            // Bind buttons
                            $btnCuttingDiagram.on('click', function () {
                                that.cuttingdiagram1dGroup(groupId);
                            });
                            $btnPrint.on('click', function () {
                                window.print();
                            });
                            $btnClose.on('click', function () {
                                that.popSlide();
                            });
                            $('.ladb-btn-setup-model-units', $slide).on('click', function() {
                                $(this).blur();
                                rubyCallCommand('core_open_model_info_page', {
                                    page: i18next.t('core.model_info_page.units')
                                });
                            });

                            $('.ladb-btn-toggle-no-print', $slide).on('click', function () {
                                var $group = $(this).parents('.ladb-cutlist-group');
                                if ($group.hasClass('no-print')) {
                                    that.showGroup($group);
                                } else {
                                    that.hideGroup($group);
                                }
                                $(this).blur();
                            });
                            $('.ladb-btn-scrollto-prev-group', $slide).on('click', function () {
                                var $group = $(this).parents('.ladb-cutlist-group');
                                var groupId = $group.data('bar-index');
                                var $target = $('.ladb-cuttingdiagram-group[data-bar-index=' + (parseInt(groupId) - 1) + ']');
                                $slide.animate({ scrollTop: $slide.scrollTop() + $target.position().top - $('.ladb-header', $slide).outerHeight(true) - 20 }, 200).promise().then(function () {
                                    $target.effect("highlight", {}, 1500);
                                });
                                $(this).blur();
                                return false;
                            });
                            $('.ladb-btn-scrollto-next-group', $slide).on('click', function () {
                                var $group = $(this).parents('.ladb-cutlist-group');
                                var groupId = $group.data('bar-index');
                                var $target = $('.ladb-cuttingdiagram-group[data-bar-index=' + (parseInt(groupId) + 1) + ']');
                                $slide.animate({ scrollTop: $slide.scrollTop() + $target.position().top - $('.ladb-header', $slide).outerHeight(true) - 20 }, 200).promise().then(function () {
                                    $target.effect("highlight", {}, 1500);
                                });
                                $(this).blur();
                                return false;
                            });
                            $('a.ladb-btn-highlight-part', $slide).on('click', function () {
                                $(this).blur();
                                var $part = $(this).parents('.ladb-cutlist-row');
                                var partId = $part.data('part-id');
                                that.highlightPart(partId);
                                return false;
                            });
                            $('a.ladb-btn-scrollto', $slide).on('click', function () {
                                var $target = $($(this).attr('href'));
                                if ($target.data('group-id')) {
                                    that.showGroup($target);
                                }
                                $slide.animate({ scrollTop: $slide.scrollTop() + $target.position().top - $('.ladb-header', $slide).outerHeight(true) - 20 }, 200).promise().then(function () {
                                    $target.effect("highlight", {}, 1500);
                                });
                                $(this).blur();
                                return false;
                            });
                            $('.ladb-cutlist-row', $slide).on('click', function () {
                                $('.ladb-click-tool', $(this)).click();
                                $(this).blur();
                                return false;
                            });

                            // SVG
                            $('SVG .part', $slide).on('click', function () {
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
                    $inputScrapBarLengths.tokenfield(TOKENFIELD_OPTIONS).on('tokenfield:createdtoken', that.tokenfieldValidatorFn_d);

                    // Setup popovers
                    that.opencutlist.setupPopovers();

                });

            });

    };

    LadbTabCutlist.prototype.cuttingdiagram2dGroup = function (groupId) {
        var that = this;

        var group = this.findGroupById(groupId);

        // Retrieve cutting diagram options
        this.opencutlist.pullSettings([

                // Defaults
                SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_SHEET_FOLDING,
                SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_HIDE_PART_LIST,
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
                SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_SHEET_FOLDING + '_' + groupId,
                SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_HIDE_PART_LIST + '_' + groupId,
                SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_SAW_KERF + '_' + groupId,
                SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_TRIMMING + '_' + groupId,
                SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_PRESORT + '_' + groupId,
                SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_STACKING + '_' + groupId,
                SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_BBOX_OPTIMIZATION + '_' + groupId

            ],
            2 /* SETTINGS_RW_STRATEGY_MODEL */,
            function () {

                var cuttingdiagram2dOptions = {
                    std_sheet: that.opencutlist.getSetting(SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_STD_SHEET + '_' + groupId, CUTTINGDIAGRAM2D_OPTION_DEFAULT_STD_SHEET),
                    std_sheet_length: that.opencutlist.getSetting(SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_STD_SHEET_LENGTH + '_' + groupId, CUTTINGDIAGRAM2D_OPTION_DEFAULT_STD_SHEET_LENGTH),
                    std_sheet_width: that.opencutlist.getSetting(SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_STD_SHEET_WIDTH + '_' + groupId, CUTTINGDIAGRAM2D_OPTION_DEFAULT_STD_SHEET_WIDTH),
                    scrap_sheet_sizes: that.opencutlist.getSetting(SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_SCRAP_SHEET_SIZES + '_' + groupId, CUTTINGDIAGRAM2D_OPTION_DEFAULT_SCRAP_SHEET_SIZES),
                    grained: that.opencutlist.getSetting(SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_GRAINED + '_' + groupId, CUTTINGDIAGRAM2D_OPTION_DEFAULT_GRAINED),
                    sheet_folding: that.opencutlist.getSetting(SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_SHEET_FOLDING + '_' + groupId, that.opencutlist.getSetting(SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_SHEET_FOLDING, CUTTINGDIAGRAM2D_OPTION_DEFAULT_SHEET_FOLDING)),
                    hide_part_list: that.opencutlist.getSetting(SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_HIDE_PART_LIST + '_' + groupId, that.opencutlist.getSetting(SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_HIDE_PART_LIST, CUTTINGDIAGRAM2D_OPTION_DEFAULT_HIDE_PART_LIST)),
                    saw_kerf: that.opencutlist.getSetting(SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_SAW_KERF + '_' + groupId, that.opencutlist.getSetting(SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_SAW_KERF, CUTTINGDIAGRAM2D_OPTION_DEFAULT_SAW_KERF)),
                    trimming: that.opencutlist.getSetting(SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_TRIMMING + '_' + groupId, that.opencutlist.getSetting(SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_TRIMMING, CUTTINGDIAGRAM2D_OPTION_DEFAULT_TRIMMING)),
                    presort: that.opencutlist.getSetting(SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_PRESORT + '_' + groupId, that.opencutlist.getSetting(SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_PRESORT, CUTTINGDIAGRAM2D_OPTION_DEFAULT_PRESORT)),
                    stacking: that.opencutlist.getSetting(SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_STACKING + '_' + groupId, that.opencutlist.getSetting(SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_STACKING, CUTTINGDIAGRAM2D_OPTION_DEFAULT_STACKING)),
                    bbox_optimization: that.opencutlist.getSetting(SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_BBOX_OPTIMIZATION + '_' + groupId, that.opencutlist.getSetting(SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_BBOX_OPTIMIZATION, CUTTINGDIAGRAM2D_OPTION_DEFAULT_BBOX_OPTIMIZATION))
                };

                rubyCallCommand('materials_get_attributes_command', { name: group.material_name }, function (response) {

                    var $modal = that.appendModalInside('ladb_cutlist_modal_cuttingdiagram_2d', 'tabs/cutlist/_modal-cuttingdiagram-2d.twig', { material_attributes: response, group: group });

                    // Fetch UI elements
                    var $inputStdSheet = $('#ladb_select_std_sheet', $modal);
                    var $inputStdSheetLength = $('#ladb_input_std_sheet_length', $modal);
                    var $inputStdSheetWidth = $('#ladb_input_std_sheet_width', $modal);
                    var $inputScrapSheetSizes = $('#ladb_input_scrap_sheet_sizes', $modal);
                    var $selectGrained = $('#ladb_select_grained', $modal);
                    var $selectSheetFolding = $('#ladb_select_sheet_folding', $modal);
                    var $selectHidePartList = $('#ladb_select_hide_part_list', $modal);
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
                    $selectSheetFolding.val(cuttingdiagram2dOptions.sheet_folding ? '1' : '0');
                    $selectSheetFolding.selectpicker(SELECT_PICKER_OPTIONS);
                    $selectHidePartList.val(cuttingdiagram2dOptions.hide_part_list ? '1' : '0');
                    $selectHidePartList.selectpicker(SELECT_PICKER_OPTIONS);
                    $inputSawKerf.val(cuttingdiagram2dOptions.saw_kerf);
                    $inputTrimming.val(cuttingdiagram2dOptions.trimming);
                    $selectPresort.val(cuttingdiagram2dOptions.presort);
                    $selectPresort.selectpicker(SELECT_PICKER_OPTIONS);
                    $selectStacking.val(cuttingdiagram2dOptions.stacking);
                    $selectStacking.selectpicker(SELECT_PICKER_OPTIONS);
                    $selectBBoxOptimization.val(cuttingdiagram2dOptions.bbox_optimization);
                    $selectBBoxOptimization.selectpicker(SELECT_PICKER_OPTIONS);

                    var fnEditMaterial = function (callback) {

                        // Hide modal
                        $modal.modal('hide');

                        // Edit material and focus std_sizes input field
                        that.opencutlist.executeCommandOnTab('materials', 'edit_material', {
                            material_id: group.material_id,
                            callback: callback
                        });

                    };
                    var fnSelectSize = function () {
                        var value = $inputStdSheet.val();
                        if (value === 'add') {
                            fnEditMaterial(function ($editMaterialModal) {
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
                    $btnCuttingdiagramOptionsDefaultsSave.on('click', function () {

                        var sheet_folding = $selectSheetFolding.val();
                        var hide_part_list = $selectHidePartList.val();
                        var saw_kerf = $inputSawKerf.val();
                        var trimming = $inputTrimming.val();
                        var presort = $selectPresort.val();
                        var stacking = $selectStacking.val();
                        var bbox_optimization = $selectBBoxOptimization.val();

                        // Update default cut options for specific type to last used
                        that.opencutlist.setSettings([
                            { key:SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_SHEET_FOLDING, value:sheet_folding },
                            { key:SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_HIDE_PART_LIST, value:hide_part_list },
                            { key:SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_SAW_KERF, value:saw_kerf, preprocessor:1 /* SETTINGS_PREPROCESSOR_D */ },
                            { key:SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_TRIMMING, value:trimming, preprocessor:1 /* SETTINGS_PREPROCESSOR_D */ },
                            { key:SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_PRESORT, value:presort },
                            { key:SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_STACKING, value:stacking },
                            { key:SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_BBOX_OPTIMIZATION, value:bbox_optimization }
                        ], 0 /* SETTINGS_RW_STRATEGY_GLOBAL */);

                        that.opencutlist.notify(i18next.t('tab.cutlist.cuttingdiagram.options_defaults.save_success'), 'success');

                        this.blur();

                    });
                    $btnCuttingdiagramOptionsDefaultsReset.on('click', function () {

                        var sheet_folding = that.opencutlist.getSetting(SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_SHEET_FOLDING, CUTTINGDIAGRAM2D_OPTION_DEFAULT_SHEET_FOLDING);
                        var hide_part_list = that.opencutlist.getSetting(SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_HIDE_PART_LIST, CUTTINGDIAGRAM2D_OPTION_DEFAULT_HIDE_PART_LIST);
                        var saw_kerf = that.opencutlist.getSetting(SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_SAW_KERF, CUTTINGDIAGRAM2D_OPTION_DEFAULT_SAW_KERF);
                        var trimming = that.opencutlist.getSetting(SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_TRIMMING, CUTTINGDIAGRAM2D_OPTION_DEFAULT_TRIMMING);
                        var presort = that.opencutlist.getSetting(SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_PRESORT, CUTTINGDIAGRAM2D_OPTION_DEFAULT_PRESORT);
                        var stacking = that.opencutlist.getSetting(SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_STACKING, CUTTINGDIAGRAM2D_OPTION_DEFAULT_STACKING);
                        var bbox_optimization = that.opencutlist.getSetting(SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_BBOX_OPTIMIZATION, CUTTINGDIAGRAM2D_OPTION_DEFAULT_BBOX_OPTIMIZATION);

                        $selectHidePartList.selectpicker('val', sheet_folding ? '1' : '0');
                        $selectHidePartList.selectpicker('val', hide_part_list ? '1' : '0');
                        $inputSawKerf.val(saw_kerf);
                        $inputTrimming.val(trimming);
                        $selectPresort.selectpicker('val', presort);
                        $selectStacking.selectpicker('val', stacking);
                        $selectBBoxOptimization.selectpicker('val', bbox_optimization);

                        this.blur();

                    });
                    $btnEditMaterial.on('click', function () {
                        fnEditMaterial();
                    });
                    $btnCuttingdiagram.on('click', function () {

                        // Fetch options

                        cuttingdiagram2dOptions.std_sheet = $inputStdSheet.val();
                        cuttingdiagram2dOptions.std_sheet_length = $inputStdSheetLength.val();
                        cuttingdiagram2dOptions.std_sheet_width = $inputStdSheetWidth.val();
                        cuttingdiagram2dOptions.scrap_sheet_sizes = $inputScrapSheetSizes.val();
                        cuttingdiagram2dOptions.grained = $selectGrained.val() === '1';
                        cuttingdiagram2dOptions.sheet_folding = $selectSheetFolding.val() === '1';
                        cuttingdiagram2dOptions.hide_part_list = $selectHidePartList.val() === '1';
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
                            { key:SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_SHEET_FOLDING + '_' + groupId, value:cuttingdiagram2dOptions.sheet_folding },
                            { key:SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_HIDE_PART_LIST + '_' + groupId, value:cuttingdiagram2dOptions.hide_part_list },
                            { key:SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_SAW_KERF + '_' + groupId, value:cuttingdiagram2dOptions.saw_kerf, preprocessor:1 /* SETTINGS_PREPROCESSOR_D */ },
                            { key:SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_TRIMMING + '_' + groupId, value:cuttingdiagram2dOptions.trimming, preprocessor:1 /* SETTINGS_PREPROCESSOR_D */ },
                            { key:SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_PRESORT + '_' + groupId, value:cuttingdiagram2dOptions.presort },
                            { key:SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_STACKING + '_' + groupId, value:cuttingdiagram2dOptions.stacking },
                            { key:SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_BBOX_OPTIMIZATION + '_' + groupId, value:cuttingdiagram2dOptions.bbox_optimization }

                        ], 2 /* SETTINGS_RW_STRATEGY_MODEL */);

                        rubyCallCommand('cutlist_group_cuttingdiagram_2d', $.extend({ group_id: groupId }, cuttingdiagram2dOptions, that.generateOptions), function (response) {

                            var $slide = that.pushNewSlide('ladb_cutlist_slide_cuttingdiagram_2d', 'tabs/cutlist/_slide-cuttingdiagram-2d.twig', $.extend({
                                generateOptions: that.generateOptions,
                                dimensionColumnOrderStrategy: that.generateOptions.dimension_column_order_strategy.split('>'),
                                filename: that.filename,
                                pageLabel: that.pageLabel,
                                lengthUnit: that.lengthUnit,
                                generatedAt: new Date().getTime() / 1000,
                                group: group
                            }, response), function () {
                                that.opencutlist.setupTooltips();
                            });

                            // Fetch UI elements
                            var $btnCuttingDiagram = $('#ladb_btn_cuttingdiagram', $slide);
                            var $btnPrint = $('#ladb_btn_print', $slide);
                            var $btnClose = $('#ladb_btn_close', $slide);

                            // Bind buttons
                            $btnCuttingDiagram.on('click', function () {
                                that.cuttingdiagram2dGroup(groupId);
                            });
                            $btnPrint.on('click', function () {
                                window.print();
                            });
                            $btnClose.on('click', function () {
                                that.popSlide();
                            });
                            $('.ladb-btn-setup-model-units', $slide).on('click', function() {
                                $(this).blur();
                                rubyCallCommand('core_open_model_info_page', {
                                    page: i18next.t('core.model_info_page.units')
                                });
                            });

                            $('.ladb-btn-toggle-no-print', $slide).on('click', function () {
                                var $group = $(this).parents('.ladb-cutlist-group');
                                if ($group.hasClass('no-print')) {
                                    that.showGroup($group);
                                } else {
                                    that.hideGroup($group);
                                }
                                $(this).blur();
                            });
                            $('.ladb-btn-scrollto-prev-group', $slide).on('click', function () {
                                var $group = $(this).parents('.ladb-cutlist-group');
                                var groupId = $group.data('sheet-index');
                                var $target = $('.ladb-cuttingdiagram-group[data-sheet-index=' + (parseInt(groupId) - 1) + ']');
                                that.scrollSlideToTarget($slide, $target, true, true);
                                $(this).blur();
                                return false;
                            });
                            $('.ladb-btn-scrollto-next-group', $slide).on('click', function () {
                                var $group = $(this).parents('.ladb-cutlist-group');
                                var groupId = $group.data('sheet-index');
                                var $target = $('.ladb-cuttingdiagram-group[data-sheet-index=' + (parseInt(groupId) + 1) + ']');
                                that.scrollSlideToTarget($slide, $target, true, true);
                                $(this).blur();
                                return false;
                            });
                            $('a.ladb-btn-highlight-part', $slide).on('click', function () {
                                $(this).blur();
                                var $part = $(this).parents('.ladb-cutlist-row');
                                var partId = $part.data('part-id');
                                that.highlightPart(partId);
                                return false;
                            });
                            $('a.ladb-btn-scrollto', $slide).on('click', function () {
                                var $target = $($(this).attr('href'));
                                if ($target.data('group-id')) {
                                    that.showGroup($target);
                                }
                                that.scrollSlideToTarget($slide, $target, true, true);
                                $(this).blur();
                                return false;
                            });
                            $('.ladb-cutlist-row', $slide).on('click', function () {
                                $('.ladb-click-tool', $(this)).click();
                                $(this).blur();
                                return false;
                            });

                            // SVG
                            $('SVG .part', $slide).on('click', function () {
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

    LadbTabCutlist.prototype.dimensionsHelpGroup = function (groupId) {
        var that = this;

        var group = this.findGroupById(groupId);

        rubyCallCommand('materials_get_attributes_command', { name: group.material_name }, function (response) {

            var $modal = that.appendModalInside('ladb_cutlist_modal_help', 'tabs/cutlist/_modal-dimensions-help.twig', { material_attributes: response, group: group, generateOptions: that.generateOptions });

            // Fetch UI elements
            var $btnCuttingToggle = $('#ladb_btn_cutting_toggle', $modal);
            var $btnBboxToggle = $('#ladb_btn_bbox_toggle', $modal);
            var $btnFinalToggle = $('#ladb_btn_final_toggle', $modal);

            // Bind buttons
            $btnCuttingToggle.on('click', function () {
                $('i', $(this)).toggleClass('ladb-opacity-hide');
                $('svg .cutting', $modal).toggleClass('hide');
                $(this).blur();
                return false;
            });
            $btnBboxToggle.on('click', function () {
                $('i', $(this)).toggleClass('ladb-opacity-hide');
                $('svg .bbox', $modal).toggleClass('hide');
                $(this).blur();
                return false;
            });
            $btnFinalToggle.on('click', function () {
                $('i', $(this)).toggleClass('ladb-opacity-hide');
                $('svg .final', $modal).toggleClass('hide');
                $(this).blur();
                return false;
            });

            // Show modal
            $modal.modal('show');

        });

    };

    // Numbers /////

    LadbTabCutlist.prototype.numbersSave = function (params, callback) {
        var that = this;

        rubyCallCommand('cutlist_numbers_save', params ? params : {}, function (response) {

            if (response['errors']) {
                that.opencutlist.notifyErrors(response['errors']);
            } else {
                that.generateCutlist(callback);
            }

        });

    };

    LadbTabCutlist.prototype.numbersReset = function (params, callback) {
        var that = this;

        rubyCallCommand('cutlist_numbers_reset', params ? params : {}, function (response) {

            if (response['errors']) {
                that.opencutlist.notifyErrors(response['errors']);
            } else {
                that.generateCutlist(callback);
            }

        });

    };

    // Options /////

    LadbTabCutlist.prototype.loadOptions = function (callback) {
        var that = this;

        this.opencutlist.pullSettings([

                SETTING_KEY_OPTION_AUTO_ORIENT,
                SETTING_KEY_OPTION_SMART_MATERIAL,
                SETTING_KEY_OPTION_DYNAMIC_ATTRIBUTES_NAME,
                SETTING_KEY_OPTION_PART_NUMBER_WITH_LETTERS,
                SETTING_KEY_OPTION_PART_NUMBER_SEQUENCE_BY_GROUP,
                SETTING_KEY_OPTION_PART_FOLDING,
                SETTING_KEY_OPTION_HIDE_ENTITY_NAMES,
                SETTING_KEY_OPTION_HIDE_LABELS,
                SETTING_KEY_OPTION_HIDE_CUTTING_DIMENSIONS,
                SETTING_KEY_OPTION_HIDE_BBOX_DIMENSIONS,
                SETTING_KEY_OPTION_HIDE_UNTYPED_MATERIAL_DIMENSIONS,
                SETTING_KEY_OPTION_HIDE_FINAL_AREAS,
                SETTING_KEY_OPTION_HIDE_EDGES,
                SETTING_KEY_OPTION_MINIMIZE_ON_HIGHLIGHT,
                SETTING_KEY_OPTION_PART_ORDER_STRATEGY,
                SETTING_KEY_OPTION_DIMENSION_COLUMN_ORDER_STRATEGY,
                SETTING_KEY_OPTION_HIDDEN_GROUP_IDS

            ],
            3 /* SETTINGS_RW_STRATEGY_MODEL_GLOBAL */,
            function () {

                that.generateOptions = {
                    auto_orient: that.opencutlist.getSetting(SETTING_KEY_OPTION_AUTO_ORIENT, OPTION_DEFAULT_AUTO_ORIENT),
                    smart_material: that.opencutlist.getSetting(SETTING_KEY_OPTION_SMART_MATERIAL, OPTION_DEFAULT_SMART_MATERIAL),
                    dynamic_attributes_name: that.opencutlist.getSetting(SETTING_KEY_OPTION_DYNAMIC_ATTRIBUTES_NAME, OPTION_DEFAULT_DYNAMIC_ATTRIBUTES_NAME),
                    part_number_with_letters: that.opencutlist.getSetting(SETTING_KEY_OPTION_PART_NUMBER_WITH_LETTERS, OPTION_DEFAULT_PART_NUMBER_WITH_LETTERS),
                    part_number_sequence_by_group: that.opencutlist.getSetting(SETTING_KEY_OPTION_PART_NUMBER_SEQUENCE_BY_GROUP, OPTION_DEFAULT_PART_NUMBER_SEQUENCE_BY_GROUP),
                    part_folding: that.opencutlist.getSetting(SETTING_KEY_OPTION_PART_FOLDING, OPTION_DEFAULT_PART_FOLDING),
                    hide_entity_names: that.opencutlist.getSetting(SETTING_KEY_OPTION_HIDE_ENTITY_NAMES, OPTION_DEFAULT_HIDE_ENTITY_NAMES),
                    hide_labels: that.opencutlist.getSetting(SETTING_KEY_OPTION_HIDE_LABELS, OPTION_DEFAULT_HIDE_LABELS),
                    hide_cutting_dimensions: that.opencutlist.getSetting(SETTING_KEY_OPTION_HIDE_CUTTING_DIMENSIONS, OPTION_DEFAULT_HIDE_CUTTING_DIMENSIONS),
                    hide_bbox_dimensions: that.opencutlist.getSetting(SETTING_KEY_OPTION_HIDE_BBOX_DIMENSIONS, OPTION_DEFAULT_HIDE_BBOX_DIMENSIONS),
                    hide_untyped_material_dimensions: that.opencutlist.getSetting(SETTING_KEY_OPTION_HIDE_UNTYPED_MATERIAL_DIMENSIONS, OPTION_DEFAULT_HIDE_UNTYPED_MATERIAL_DIMENSIONS),
                    hide_final_areas: that.opencutlist.getSetting(SETTING_KEY_OPTION_HIDE_FINAL_AREAS, OPTION_DEFAULT_HIDE_FINAL_AREAS),
                    hide_edges: that.opencutlist.getSetting(SETTING_KEY_OPTION_HIDE_EDGES, OPTION_DEFAULT_HIDE_EDGES),
                    minimize_on_highlight: that.opencutlist.getSetting(SETTING_KEY_OPTION_MINIMIZE_ON_HIGHLIGHT, OPTION_DEFAULT_MINIMIZE_ON_HIGHLIGHT),
                    part_order_strategy: that.opencutlist.getSetting(SETTING_KEY_OPTION_PART_ORDER_STRATEGY, OPTION_DEFAULT_PART_ORDER_STRATEGY),
                    dimension_column_order_strategy: that.opencutlist.getSetting(SETTING_KEY_OPTION_DIMENSION_COLUMN_ORDER_STRATEGY, OPTION_DEFAULT_DIMENSION_COLUMN_ORDER_STRATEGY),
                    hidden_group_ids: that.opencutlist.getSetting(SETTING_KEY_OPTION_HIDDEN_GROUP_IDS, OPTION_DEFAULT_HIDDEN_GROUP_IDS)
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
        var $inputDynamicAttributesName = $('#ladb_input_dynamic_attributes_name', $modal);
        var $inputPartNumberWithLetters = $('#ladb_input_part_number_with_letters', $modal);
        var $inputPartNumberSequenceByGroup = $('#ladb_input_part_number_sequence_by_group', $modal);
        var $inputPartFolding = $('#ladb_input_part_folding', $modal);
        var $inputHideInstanceNames = $('#ladb_input_hide_entity_names', $modal);
        var $inputHideLabels = $('#ladb_input_hide_labels', $modal);
        var $inputHideCuttingDimensions = $('#ladb_input_hide_cutting_dimensions', $modal);
        var $inputHideBBoxDimensions = $('#ladb_input_hide_bbox_dimensions', $modal);
        var $inputHideUntypedMaterialDimensions = $('#ladb_input_hide_untyped_material_dimensions', $modal);
        var $inputHideFinalAreas = $('#ladb_input_hide_final_areas', $modal);
        var $inputHideEdges = $('#ladb_input_hide_edges', $modal);
        var $inputMinimizeOnHighlight = $('#ladb_input_minimize_on_highlight', $modal);
        var $sortablePartOrderStrategy = $('#ladb_sortable_part_order_strategy', $modal);
        var $sortableDimensionColumnOrderStrategy = $('#ladb_sortable_dimension_column_order_strategy', $modal);
        var $btnReset = $('#ladb_cutlist_options_reset', $modal);
        var $btnUpdate = $('#ladb_cutlist_options_update', $modal);

        // Define useful functions
        var populateOptionsInputs = function (generateOptions) {

            // Checkboxes

            $inputAutoOrient.prop('checked', generateOptions.auto_orient);
            $inputSmartMaterial.prop('checked', generateOptions.smart_material);
            $inputDynamicAttributesName.prop('checked', generateOptions.dynamic_attributes_name);
            $inputPartNumberWithLetters.prop('checked', generateOptions.part_number_with_letters);
            $inputPartNumberSequenceByGroup.prop('checked', generateOptions.part_number_sequence_by_group);
            $inputPartFolding.prop('checked', generateOptions.part_folding);
            $inputHideInstanceNames.prop('checked', generateOptions.hide_entity_names);
            $inputHideLabels.prop('checked', generateOptions.hide_labels);
            $inputHideCuttingDimensions.prop('checked', generateOptions.hide_cutting_dimensions);
            $inputHideBBoxDimensions.prop('checked', generateOptions.hide_bbox_dimensions);
            $inputHideUntypedMaterialDimensions
                .prop('checked', generateOptions.hide_untyped_material_dimensions)
                .prop('disabled', generateOptions.hide_bbox_dimensions);
            $inputHideFinalAreas.prop('checked', generateOptions.hide_final_areas);
            $inputHideEdges.prop('checked', generateOptions.hide_edges);
            $inputMinimizeOnHighlight.prop('checked', generateOptions.minimize_on_highlight);

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
            $sortablePartOrderStrategy.find('a').on('click', function () {
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

            properties = generateOptions.dimension_column_order_strategy.split('>');
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
        $inputHideBBoxDimensions.on('change', function () {
            $inputHideUntypedMaterialDimensions.prop('disabled', $(this).is(':checked'));
        });

        // Bind buttons
        $btnReset.on('click', function () {
            $(this).blur();

            var generateOptions = $.extend($.extend({}, that.generateOptions), {
                auto_orient: OPTION_DEFAULT_AUTO_ORIENT,
                smart_material: OPTION_DEFAULT_SMART_MATERIAL,
                dynamic_attributes_name: OPTION_DEFAULT_DYNAMIC_ATTRIBUTES_NAME,
                part_number_with_letters: OPTION_DEFAULT_PART_NUMBER_WITH_LETTERS,
                part_number_sequence_by_group: OPTION_DEFAULT_PART_NUMBER_SEQUENCE_BY_GROUP,
                part_folding: OPTION_DEFAULT_PART_FOLDING,
                hide_entity_names: OPTION_DEFAULT_HIDE_ENTITY_NAMES,
                hide_labels: OPTION_DEFAULT_HIDE_LABELS,
                hide_cutting_dimensions: OPTION_DEFAULT_HIDE_CUTTING_DIMENSIONS,
                hide_bbox_dimensions: OPTION_DEFAULT_HIDE_BBOX_DIMENSIONS,
                hide_untyped_material_dimensions: OPTION_DEFAULT_HIDE_UNTYPED_MATERIAL_DIMENSIONS,
                hide_final_areas: OPTION_DEFAULT_HIDE_FINAL_AREAS,
                hide_edges: OPTION_DEFAULT_HIDE_EDGES,
                minimize_on_highlight: OPTION_DEFAULT_MINIMIZE_ON_HIGHLIGHT,
                part_order_strategy: OPTION_DEFAULT_PART_ORDER_STRATEGY,
                dimension_column_order_strategy: OPTION_DEFAULT_DIMENSION_COLUMN_ORDER_STRATEGY
            });
            populateOptionsInputs(generateOptions);
        });
        $btnUpdate.on('click', function () {

            // Fetch options

            that.generateOptions.auto_orient = $inputAutoOrient.is(':checked');
            that.generateOptions.smart_material = $inputSmartMaterial.is(':checked');
            that.generateOptions.dynamic_attributes_name = $inputDynamicAttributesName.is(':checked');
            that.generateOptions.part_number_with_letters = $inputPartNumberWithLetters.is(':checked');
            that.generateOptions.part_number_sequence_by_group = $inputPartNumberSequenceByGroup.is(':checked');
            that.generateOptions.part_folding = $inputPartFolding.is(':checked');
            that.generateOptions.hide_entity_names = $inputHideInstanceNames.is(':checked');
            that.generateOptions.hide_labels = $inputHideLabels.is(':checked');
            that.generateOptions.hide_cutting_dimensions = $inputHideCuttingDimensions.is(':checked');
            that.generateOptions.hide_bbox_dimensions = $inputHideBBoxDimensions.is(':checked');
            that.generateOptions.hide_untyped_material_dimensions = $inputHideUntypedMaterialDimensions.is(':checked');
            that.generateOptions.hide_final_areas = $inputHideFinalAreas.is(':checked');
            that.generateOptions.hide_edges = $inputHideEdges.is(':checked');
            that.generateOptions.minimize_on_highlight = $inputMinimizeOnHighlight.is(':checked');

            var properties = [];
            $sortablePartOrderStrategy.children('li').each(function () {
                properties.push($(this).data('property'));
            });
            that.generateOptions.part_order_strategy = properties.join('>');

            properties = [];
            $sortableDimensionColumnOrderStrategy.children('li').each(function () {
                properties.push($(this).data('property'));
            });
            that.generateOptions.dimension_column_order_strategy = properties.join('>');

            // Store options
            that.opencutlist.setSettings([
                { key:SETTING_KEY_OPTION_AUTO_ORIENT, value:that.generateOptions.auto_orient },
                { key:SETTING_KEY_OPTION_SMART_MATERIAL, value:that.generateOptions.smart_material },
                { key:SETTING_KEY_OPTION_DYNAMIC_ATTRIBUTES_NAME, value:that.generateOptions.dynamic_attributes_name },
                { key:SETTING_KEY_OPTION_PART_NUMBER_WITH_LETTERS, value:that.generateOptions.part_number_with_letters },
                { key:SETTING_KEY_OPTION_PART_NUMBER_SEQUENCE_BY_GROUP, value:that.generateOptions.part_number_sequence_by_group },
                { key:SETTING_KEY_OPTION_PART_FOLDING, value:that.generateOptions.part_folding },
                { key:SETTING_KEY_OPTION_HIDE_ENTITY_NAMES, value:that.generateOptions.hide_entity_names },
                { key:SETTING_KEY_OPTION_HIDE_LABELS, value:that.generateOptions.hide_labels },
                { key:SETTING_KEY_OPTION_HIDE_CUTTING_DIMENSIONS, value:that.generateOptions.hide_cutting_dimensions },
                { key:SETTING_KEY_OPTION_HIDE_BBOX_DIMENSIONS, value:that.generateOptions.hide_bbox_dimensions },
                { key:SETTING_KEY_OPTION_HIDE_UNTYPED_MATERIAL_DIMENSIONS, value:that.generateOptions.hide_untyped_material_dimensions },
                { key:SETTING_KEY_OPTION_HIDE_FINAL_AREAS, value:that.generateOptions.hide_final_areas },
                { key:SETTING_KEY_OPTION_HIDE_EDGES, value:that.generateOptions.hide_edges },
                { key:SETTING_KEY_OPTION_MINIMIZE_ON_HIGHLIGHT, value:that.generateOptions.minimize_on_highlight },
                { key:SETTING_KEY_OPTION_PART_ORDER_STRATEGY, value:that.generateOptions.part_order_strategy },
                { key:SETTING_KEY_OPTION_DIMENSION_COLUMN_ORDER_STRATEGY, value:that.generateOptions.dimension_column_order_strategy }
            ], 3 /* SETTINGS_RW_STRATEGY_MODEL_GLOBAL */);

            // Hide modal
            $modal.modal('hide');

            // Refresh the list if it has already been generated
            if (that.groups.length > 0) {
                that.generateCutlist();
            }

        });

        // Populate inputs
        populateOptionsInputs(that.generateOptions);

        // Show modal
        $modal.modal('show');

        // Setup popovers
        this.opencutlist.setupPopovers();

    };

    // Internals /////

    LadbTabCutlist.prototype.showObsolete = function (messageI18nKey, forced) {
        if (!this.isObsolete() || forced) {

            var that = this;

            // Set tab as obsolete
            this.setObsolete(true);

            var $modal = this.appendModalInside('ladb_cutlist_modal_obsolete', 'tabs/cutlist/_modal-obsolete.twig', {
                messageI18nKey: messageI18nKey
            });

            // Fetch UI elements
            var $btnGenerate = $('#ladb_cutlist_obsolete_generate', $modal);

            // Bind buttons
            $btnGenerate.on('click', function () {
                $modal.modal('hide');
                that.generateCutlist();
            });

            // Show modal
            $modal.modal('show');

        }
    };

    LadbTabCutlist.prototype.bind = function () {
        LadbAbstractTab.prototype.bind.call(this);

        var that = this;

        // Bind buttons
        this.$btnGenerate.on('click', function () {
            that.selectionGroupId = null;
            that.selectionPartIds = [];
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
            if (!$(this).parents('li').hasClass('disabled')) {
                that.highlightAllParts();
            }
            this.blur();
        });
        this.$itemShowAllGroups.on('click', function () {
            if (!$(this).parents('li').hasClass('disabled')) {
                that.showAllGroups();
            }
            this.blur();
        });
        this.$itemNumbersSave.on('click', function () {
            if (!$(this).parents('li').hasClass('disabled')) {
                that.numbersSave();
            }
            this.blur();
        });
        this.$itemNumbersReset.on('click', function () {
            if (!$(this).parents('li').hasClass('disabled')) {
                that.numbersReset();
            }
            this.blur();
        });
        this.$itemExpendAll.on('click', function () {
            that.expandAllFoldingPart();
            $(this).blur();
        });
        this.$itemCollapseAll.on('click', function () {
            that.collapseAllFoldingPart();
            $(this).blur();
        });
        this.$itemOptions.on('click', function () {
            that.editOptions();
            this.blur();
        });

        // Events

        addEventCallback([ 'on_new_model', 'on_open_model', 'on_activate_model' ], function (params) {
            if (that.generateAt) {
                that.showObsolete('core.event.model_change', true);
            }

            // Hide edit option model (if it exists)
            $('#ladb_cutlist_modal_options').modal('hide');

            // Reload options (from new active model)
            that.loadOptions();

        });
        addEventCallback('on_options_provider_changed', function () {
            if (that.generateAt) {
                that.showObsolete('core.event.options_change', true);
            }
        });
        addEventCallback([ 'on_material_remove', 'on_material_change' ], function () {
            if (!that.ignoreNextMaterialEvents) {
                if (that.generateAt) {
                    that.showObsolete('core.event.material_change', true);
                }
            }
        });
        addEventCallback([ 'on_selection_bulk_change', 'on_selection_cleared' ], function () {
            if (that.generateAt) {
                that.showObsolete('core.event.selection_change');
            }
        });

    };

    LadbTabCutlist.prototype.init = function (initializedCallback) {
        var that = this;

        // Register commands
        this.registerCommand('generate_cutlist', function (parameters) {
            var callback = parameters ? parameters.callback : null;
            setTimeout(function () {     // Use setTimer to give time tu UI to refresh
                that.generateCutlist(callback);
            }, 1);
        });
        this.registerCommand('edit_part', function (parameters) {
            var partId = parameters.part_id;
            var partSerializedPath = parameters.part_serialized_path;
            var tab = parameters.tab;
            setTimeout(function () {     // Use setTimer to give time tu UI to refresh
                that.generateCutlist(function () {
                    that.editPart(partId, partSerializedPath, tab);
                });
            }, 1);
        });

        // Load Options
        this.loadOptions(function () {

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
                data[option].apply(data, Array.isArray(params) ? params : [ params ])
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
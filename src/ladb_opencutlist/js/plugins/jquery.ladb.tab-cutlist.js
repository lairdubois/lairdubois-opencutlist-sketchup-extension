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
    var SETTING_KEY_OPTION_HIDE_TAGS = 'cutlist.option.hide_tags';
    var SETTING_KEY_OPTION_HIDE_CUTTING_DIMENSIONS = 'cutlist.option.hide_cutting_dimensions';
    var SETTING_KEY_OPTION_HIDE_BBOX_DIMENSIONS = 'cutlist.option.hide_bbox_dimensions';
    var SETTING_KEY_OPTION_HIDE_FINAL_AREAS = 'cutlist.option.hide_final_areas';
    var SETTING_KEY_OPTION_HIDE_EDGES = 'cutlist.option.hide_edges';
    var SETTING_KEY_OPTION_MINIMIZE_ON_HIGHLIGHT = 'cutlist.option.minimize_on_highlight';
    var SETTING_KEY_OPTION_PART_ORDER_STRATEGY = 'cutlist.option.part_order_strategy';
    var SETTING_KEY_OPTION_DIMENSION_COLUMN_ORDER_STRATEGY = 'cutlist.option.dimension_column_order_strategy';
    var SETTING_KEY_OPTION_HIDDEN_GROUP_IDS = 'cutlist.option.hidden_group_ids';

    var SETTING_KEY_EXPORT_OPTION_SOURCE = 'cutlist.export.option.source';
    var SETTING_KEY_EXPORT_OPTION_COL_SEP = 'cutlist.export.option.col_sep';
    var SETTING_KEY_EXPORT_OPTION_ENCODING = 'cutlist.export.option.encoding';
    var SETTING_KEY_EXPORT_COLDEFS_SUMMARY = 'cutlist.export.coldefs.summary';
    var SETTING_KEY_EXPORT_COLDEFS_CUTLIST = 'cutlist.export.coldefs.cutlist';
    var SETTING_KEY_EXPORT_COLDEFS_INSTANCES_LIST = 'cutlist.export.coldefs.instances_list';

    var SETTING_KEY_CUTTINGDIAGRAM1D_OPTION_STD_BAR = 'cutlist.cuttingdiagram1d.option.std_bar';
    var SETTING_KEY_CUTTINGDIAGRAM1D_OPTION_SCRAP_BAR_LENGTHS = 'cutlist.cuttingdiagram1d.option.scrap_bar_lengths';
    var SETTING_KEY_CUTTINGDIAGRAM1D_OPTION_SAW_KERF = 'cutlist.cuttingdiagram1d.option.saw_kerf';
    var SETTING_KEY_CUTTINGDIAGRAM1D_OPTION_TRIMMING = 'cutlist.cuttingdiagram1d.option.trimming';
    var SETTING_KEY_CUTTINGDIAGRAM1D_OPTION_BAR_FOLDING = 'cutlist.cuttingdiagram1d.option.bar_folding';
    var SETTING_KEY_CUTTINGDIAGRAM1D_OPTION_HIDE_CROSS = 'cutlist.cuttingdiagram1d.option.hide_cross';
    var SETTING_KEY_CUTTINGDIAGRAM1D_OPTION_HIDE_PART_LIST = 'cutlist.cuttingdiagram1d.option.hide_part_list';
    var SETTING_KEY_CUTTINGDIAGRAM1D_OPTION_WRAP_LENGTH = 'cutlist.cuttingdiagram1d.option.wrap_length';

    var SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_STD_SHEET = 'cutlist.cuttingdiagram2d.option.std_sheet';
    var SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_SCRAP_SHEET_SIZES = 'cutlist.cuttingdiagram2d.option.scrap_sheet_sizes';
    var SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_SAW_KERF = 'cutlist.cuttingdiagram2d.option.saw_kerf';
    var SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_TRIMMING = 'cutlist.cuttingdiagram2d.option.trimming';
    var SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_OPTIMIZATION = 'cutlist.cuttingdiagram2d.option.optimization';
    var SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_STACKING = 'cutlist.cuttingdiagram2d.option.stacking';
    var SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_SHEET_FOLDING = 'cutlist.cuttingdiagram1d.option.sheet_folding';
    var SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_HIDE_CROSS = 'cutlist.cuttingdiagram2d.option.hide_cross';
    var SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_HIDE_PART_LIST = 'cutlist.cuttingdiagram2d.option.hide_part_list';
    var SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_ORIGIN_CORNER = 'cutlist.cuttingdiagram2d.option.origin_corner';

    var EXPORT_DEFAULT_COLUMNS = {
        0 /* EXPORT_OPTION_SOURCE_SUMMARY */        : [ 'material_type', 'material_thickness', 'part_count', 'total_cutting_length', 'total_cutting_area', 'total_cutting_volume', 'total_final_area' ],
        1 /* EXPORT_OPTION_SOURCE_CUTLIST */        : [ 'number', 'name', 'count', 'cutting_length', 'cutting_width', 'cutting_thickness', 'bbox_length', 'bbox_width', 'bbox_thickness', 'final_area', 'material_name', 'entity_names', 'tags', 'edge_ymin', 'edge_ymax', 'edge_xmin', 'edge_xmax' ],
        2 /* EXPORT_OPTION_SOURCE_INSTANCES_LIST */ : [ 'number', 'path', 'instance_name', 'definition_name', 'cutting_length', 'cutting_width', 'cutting_thickness', 'bbox_length', 'bbox_width', 'bbox_thickness', 'final_area', 'material_name', 'tags', 'edge_ymin', 'edge_ymax', 'edge_xmin', 'edge_xmax' ],
    };

    // Various Consts

    var MULTIPLE_VALUE = '-1';

    // CLASS DEFINITION
    // ======================

    var LadbTabCutlist = function (element, options, opencutlist) {
        LadbAbstractTab.call(this, element, options, opencutlist);

        this.generateFilters = {
          tags_filter: [],
          edge_material_names_filter: []
        };

        this.generateAt = null;
        this.filename = null;
        this.pageLabel = null;
        this.lengthUnit = null;
        this.usedTags = [];
        this.usedEdgeMaterialDisplayNames = [];
        this.materialUsages = [];
        this.groups = [];
        this.ignoreNextMaterialEvents = false;
        this.selectionGroupId = null;
        this.selectionPartIds = [];
        this.lastEditPartTab = null;
        this.lastCuttingdiagram1dOptionsTab = null;
        this.lastCuttingdiagram2dOptionsTab = null;

        this.$header = $('.ladb-header', this.$element);
        this.$fileTabs = $('.ladb-file-tabs', this.$header);
        this.$btnGenerate = $('#ladb_btn_generate', this.$header);
        this.$btnPrint = $('#ladb_btn_print', this.$header);
        this.$btnExport = $('#ladb_btn_export', this.$header);
        this.$btnReport = $('#ladb_btn_report', this.$header);
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
            var usedTags = response.used_tags;
            var materialUsages = response.material_usages;
            var groups = response.groups;

            // Keep usefull data
            that.filename = filename;
            that.pageLabel = pageLabel;
            that.lengthUnit = lengthUnit;
            that.usedTags = usedTags;
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
            that.$btnReport.prop('disabled', groups.length === 0);
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
                usedTags: usedTags,
                usedEdgeMaterialDisplayNames: that.usedEdgeMaterialDisplayNames,
                groups: groups
            }));

            // Setup tooltips
            that.dialog.setupTooltips();

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
                that.dialog.setSetting(SETTING_KEY_OPTION_HIDDEN_GROUP_IDS, that.generateOptions.hidden_group_ids, 2 /* SETTINGS_RW_STRATEGY_MODEL */);
            }

            // Bind inputs
            $('#ladb_cutlist_tags_filter', that.$page)
                .tokenfield($.extend(TOKENFIELD_OPTIONS, {
                    autocomplete: {
                        source: that.usedTags,
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
                    $.each(that.usedTags, function (index, token) {
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
                    that.generateFilters.tags_filter = tokenList.length === 0 ? [] : tokenList.split(';');
                    that.generateCutlist(function () {
                        $('#ladb_cutlist_tags_filter-tokenfield', that.$page).focus();
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
            $('#ladb_cutlist_btn_tags_filter_clear', that.$page).on('click', function () {
                $(this).blur();
                that.generateFilters.tags_filter = [];
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
                that.dialog.executeCommandOnTab('materials', 'edit_material', {
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

                    // Use real std dimension if dimension is rounded
                    var std_dimension = group.std_dimension_rounded ? group.std_dimension_real : group.std_dimension;

                    rubyCallCommand('materials_add_std_dimension_command', { material_name: group.material_name, std_dimension: std_dimension }, function (response) {

                        // Flag to stop ignoring next material change event
                        that.ignoreNextMaterialEvents = false;

                        if (response['errors']) {
                            that.dialog.notifyErrors(response['errors']);
                        } else {

                            var wTop = $group.offset().top - $(window).scrollTop();

                            // Refresh the list
                            that.generateCutlist(function () {

                                // Try to scroll to the edited group's block
                                var $group = $('#ladb_group_' + groupId, that.$page);
                                if ($group.length > 0) {
                                    that.$rootSlide.animate({ scrollTop: $group.offset().top - wTop }, 0).promise().then(function () {
                                        $group.effect('highlight', {}, 1500);
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
                    that.dialog.executeCommandOnTab('materials', 'edit_material', {
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
                that.cuttingdiagram1dGroup(groupId, true);
            });
            $('button.ladb-btn-group-cuttingdiagram2d', that.$page).on('click', function () {
                $(this).blur();
                var $group = $(this).parents('.ladb-cutlist-group');
                var groupId = $group.data('group-id');
                that.cuttingdiagram2dGroup(groupId, true);
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
                var indexOf = that.generateFilters.tags_filter.indexOf(labelFilter);
                if (indexOf > -1) {
                    that.generateFilters.tags_filter.splice(indexOf, 1);
                } else {
                    that.generateFilters.tags_filter.push(labelFilter);
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
        this.dialog.pullSettings([

                SETTING_KEY_EXPORT_OPTION_SOURCE,
                SETTING_KEY_EXPORT_OPTION_COL_SEP,
                SETTING_KEY_EXPORT_OPTION_ENCODING,
                SETTING_KEY_EXPORT_COLDEFS_SUMMARY,
                SETTING_KEY_EXPORT_COLDEFS_CUTLIST,
                SETTING_KEY_EXPORT_COLDEFS_INSTANCES_LIST

            ],
            3 /* SETTINGS_RW_STRATEGY_MODEL_GLOBAL */,
            function () {

                rubyCallCommand('core_get_app_defaults', { dictionary: 'cutlist_export_options' }, function (response) {

                    if (response.errors && response.errors.length > 0) {
                        that.dialog.notifyErrors(response.errors);
                    } else {

                        var appDefaults = response.defaults;

                        var exportOptions = {
                            source: that.dialog.getSetting(SETTING_KEY_EXPORT_OPTION_SOURCE, appDefaults.source),
                            col_sep: that.dialog.getSetting(SETTING_KEY_EXPORT_OPTION_COL_SEP, appDefaults.col_sep),
                            encoding: that.dialog.getSetting(SETTING_KEY_EXPORT_OPTION_ENCODING, appDefaults.encoding)
                        };

                        var fnDefaultColDefs = function (source) {
                            var cols = EXPORT_DEFAULT_COLUMNS[source];
                            var colDefs = [];
                            for (var i = 0; i < cols.length; i++) {
                                colDefs.push({
                                    name: cols[i],
                                    hidden: false,
                                    formula: '',
                                });
                            }
                            return colDefs;
                        }

                        var exportColDefs = {
                            0 /* EXPORT_OPTION_SOURCE_SUMMARY */        : that.dialog.getSetting(SETTING_KEY_EXPORT_COLDEFS_SUMMARY, fnDefaultColDefs(0 /* EXPORT_OPTION_SOURCE_SUMMARY */)),
                            1 /* EXPORT_OPTION_SOURCE_CUTLIST */        : that.dialog.getSetting(SETTING_KEY_EXPORT_COLDEFS_CUTLIST, fnDefaultColDefs(1 /* EXPORT_OPTION_SOURCE_CUTLIST */)),
                            2 /* EXPORT_OPTION_SOURCE_INSTANCES_LIST */ : that.dialog.getSetting(SETTING_KEY_EXPORT_COLDEFS_INSTANCES_LIST, fnDefaultColDefs(2 /* EXPORT_OPTION_SOURCE_INSTANCES_LIST */))
                        };

                        var $modal = that.appendModalInside('ladb_cutlist_modal_export', 'tabs/cutlist/_modal-export.twig');

                        // Fetch UI elements
                        var $selectSource = $('#ladb_cutlist_export_select_source', $modal);
                        var $selectColSep = $('#ladb_cutlist_export_select_col_sep', $modal);
                        var $selectEncoding = $('#ladb_cutlist_export_select_encoding', $modal);
                        var $sortableColumnOrderSummary = $('#ladb_sortable_column_order_summary', $modal);
                        var $sortableColumnOrderCutlist = $('#ladb_sortable_column_order_cutlist', $modal);
                        var $sortableColumnOrderInstancesList = $('#ladb_sortable_column_order_instances_list', $modal);
                        var $btnDefaultsReset = $('#ladb_cutlist_export_btn_defaults_reset', $modal);
                        var $btnExport = $('#ladb_cutlist_export_btn_export', $modal);

                        // Define useful functions

                        var fnPopulateAndBindSorter = function ($sorter, colDefs) {

                            // Generate wordDefs
                            var wordDefs = [];
                            for (var i = 0; i < colDefs.length; i++) {
                                wordDefs.push({
                                    value: colDefs[i].name,
                                    label: i18next.t('tab.cutlist.export.' + colDefs[i].name),
                                    class: 'variable'
                                });
                            }

                            // Populate rows
                            $sorter.empty();
                            for (var i = 0; i < colDefs.length; i++) {

                                // Create ans append row
                                $sorter.append(Twig.twig({ref: "tabs/cutlist/_export-col-def.twig"}).render({
                                    colDef: colDefs[i]
                                }));

                                // Setup formula editor
                                $('li:last-child .ladb-formula-editor', $sorter)
                                    .ladbFormulaEditor({
                                        wordDefs: wordDefs
                                    })
                                    .ladbFormulaEditor('setFormula', [ colDefs[i].formula ])
                                ;

                            }

                            // Bind buttons
                            $('a.ladb-cutlist-export-col-formula-btn', $sorter).on('click', function () {
                                var $item = $(this).closest('li');
                                var $formula = $('.ladb-cutlist-export-col-formula', $item);
                                $formula.toggleClass('hidden');
                            });
                            $('a.ladb-cutlist-export-col-visibility-btn', $sorter).on('click', function () {
                                var $item = $(this).closest('li');
                                var $icon = $('i', $(this));
                                var hidden = $item.data('hidden');
                                if (hidden === true) {
                                    hidden = false;
                                    $item.removeClass('ladb-inactive');
                                    $icon.removeClass('ladb-opencutlist-icon-eye-close');
                                    $icon.addClass('ladb-opencutlist-icon-eye-open');
                                } else {
                                    hidden = true;
                                    $item.addClass('ladb-inactive');
                                    $icon.addClass('ladb-opencutlist-icon-eye-close');
                                    $icon.removeClass('ladb-opencutlist-icon-eye-open');
                                }
                                $item.data('hidden', hidden);
                                return false;
                            });

                            // Bind sorter
                            $sorter.sortable(SORTABLE_OPTIONS);

                        }
                        fnPopulateAndBindSorter($sortableColumnOrderSummary, exportColDefs[0]);
                        fnPopulateAndBindSorter($sortableColumnOrderCutlist, exportColDefs[1]);
                        fnPopulateAndBindSorter($sortableColumnOrderInstancesList, exportColDefs[2]);

                        var fnComputeSorterVisibility = function (source) {
                            switch (parseInt(source)) {
                                case 0: // EXPORT_OPTION_SOURCE_SUMMARY
                                    $sortableColumnOrderSummary.show();
                                    $sortableColumnOrderCutlist.hide();
                                    $sortableColumnOrderInstancesList.hide();
                                    break;
                                case 1: // EXPORT_OPTION_SOURCE_CUTLIST
                                    $sortableColumnOrderSummary.hide();
                                    $sortableColumnOrderCutlist.show();
                                    $sortableColumnOrderInstancesList.hide();
                                    break;
                                case 2: // EXPORT_OPTION_SOURCE_INSTANCES_LIST
                                    $sortableColumnOrderSummary.hide();
                                    $sortableColumnOrderCutlist.hide();
                                    $sortableColumnOrderInstancesList.show();
                                    break;
                            }
                        };

                        // Bind select
                        $selectSource.val(exportOptions.source);
                        $selectSource.selectpicker(SELECT_PICKER_OPTIONS);
                        $selectSource.on('change', function () {
                            fnComputeSorterVisibility($(this).val());
                        });
                        fnComputeSorterVisibility(exportOptions.source);
                        $selectColSep.val(exportOptions.col_sep);
                        $selectColSep.selectpicker(SELECT_PICKER_OPTIONS);
                        $selectEncoding.val(exportOptions.encoding);
                        $selectEncoding.selectpicker(SELECT_PICKER_OPTIONS);

                        // Bind buttons
                        $btnDefaultsReset.on('click', function () {
                            $selectSource.selectpicker('val', appDefaults.source);
                            $selectColSep.selectpicker('val', appDefaults.col_sep);
                            $selectEncoding.selectpicker('val', appDefaults.encoding);
                            $(this).blur();
                        });
                        $btnExport.on('click', function () {

                            // Fetch options

                            exportOptions.source = $selectSource.val();
                            exportOptions.col_sep = $selectColSep.val();
                            exportOptions.encoding = $selectEncoding.val();

                            var fnFetchColumnDefs = function ($sorter) {
                                var columnDefs = [];
                                $sorter.children('li').each(function () {
                                    columnDefs.push({
                                        name: $(this).data('name'),
                                        hidden: $(this).data('hidden'),
                                        formula: $('.ladb-formula-editor', $(this)).ladbFormulaEditor('getFormula'),
                                    });
                                });
                                return columnDefs;
                            }
                            exportColDefs[0] = fnFetchColumnDefs($sortableColumnOrderSummary);
                            exportColDefs[1] = fnFetchColumnDefs($sortableColumnOrderCutlist);
                            exportColDefs[2] = fnFetchColumnDefs($sortableColumnOrderInstancesList);

                            // Store options
                            that.dialog.setSettings([
                                {key: SETTING_KEY_EXPORT_OPTION_SOURCE, value: exportOptions.source},
                                {key: SETTING_KEY_EXPORT_OPTION_COL_SEP, value: exportOptions.col_sep},
                                {key: SETTING_KEY_EXPORT_OPTION_ENCODING, value: exportOptions.encoding},
                                {key: SETTING_KEY_EXPORT_COLDEFS_SUMMARY, value: exportColDefs[0]},
                                {key: SETTING_KEY_EXPORT_COLDEFS_CUTLIST, value: exportColDefs[1]},
                                {key: SETTING_KEY_EXPORT_COLDEFS_INSTANCES_LIST, value: exportColDefs[2]},
                            ], 0 /* SETTINGS_RW_STRATEGY_GLOBAL */);

                            rubyCallCommand('cutlist_export', $.extend(exportOptions, { col_defs: exportColDefs[exportOptions.source] }, that.generateOptions), function (response) {

                                var i;

                                if (response.errors) {
                                    that.dialog.notifyErrors(response.errors);
                                }
                                if (response.export_path) {
                                    that.dialog.notify(i18next.t('tab.cutlist.success.exported_to', { export_path: response.export_path }), 'success', [
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

                    }


                });

            });

    };

    LadbTabCutlist.prototype.reportCutlist = function () {

        // Show Objective modal
        this.dialog.executeCommandOnTab('sponsor', 'show_objective_modal', { objectiveStrippedName: 'report' }, null, true);

    };

    // Highlight /////

    LadbTabCutlist.prototype.highlightAllParts = function () {
        var that = this;

        rubyCallCommand('cutlist_highlight_parts', { minimize_on_highlight: that.generateOptions.minimize_on_highlight }, function (response) {

            if (response['errors']) {
                that.dialog.notifyErrors(response['errors']);
            } else if (that.generateOptions.minimize_on_highlight) {
                that.dialog.minimize();
            }

        });

    };

    LadbTabCutlist.prototype.highlightGroupParts = function (groupId) {
        var that = this;

        rubyCallCommand('cutlist_highlight_parts', { minimize_on_highlight: that.generateOptions.minimize_on_highlight, group_id: groupId }, function (response) {

            if (response['errors']) {
                that.dialog.notifyErrors(response['errors']);
            } else if (that.generateOptions.minimize_on_highlight) {
                that.dialog.minimize();
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
                    that.dialog.notifyErrors(response['errors']);
                } else if (that.generateOptions.minimize_on_highlight) {
                    that.dialog.minimize();
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

    LadbTabCutlist.prototype.renderSelectionOnGroup = function (id) {
        var $group = $('#ladb_group_' + id, this.$page);
        var $cuttingdiagram1dBtn = $('button.ladb-btn-group-cuttingdiagram1d', $group);
        var $cuttingdiagram2dBtn = $('button.ladb-btn-group-cuttingdiagram2d', $group);
        if (this.selectionPartIds.length > 0) {
            $('i', $cuttingdiagram1dBtn).addClass('ladb-opencutlist-icon-cuttingdiagram-1d-selection');
            $('i', $cuttingdiagram2dBtn).addClass('ladb-opencutlist-icon-cuttingdiagram-2d-selection');
        } else {
            $('i', $cuttingdiagram1dBtn).removeClass('ladb-opencutlist-icon-cuttingdiagram-1d-selection');
            $('i', $cuttingdiagram2dBtn).removeClass('ladb-opencutlist-icon-cuttingdiagram-2d-selection');
        }
        $cuttingdiagram1dBtn.effect('highlight', {}, 1500);
        $cuttingdiagram2dBtn.effect('highlight', {}, 1500);
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
        this.renderSelectionOnGroup(this.selectionGroupId);
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
                        this.renderSelectionOnGroup(groupAndPart.group.id);
                        this.selectionGroupId = null;
                    }
                    selected = false;
                }
            } else {
                if (state === undefined || state === true) {
                    this.selectionPartIds.push(partId);
                    if (this.selectionGroupId !== groupAndPart.group.id) {
                        this.renderSelectionOnGroup(groupAndPart.group.id);
                    }
                    this.selectionGroupId = groupAndPart.group.id;
                    selected = true;
                }
            }

            // Render selection
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
            var isSelected = this.selectionGroupId === group.id && this.selectionPartIds.includes(part.id) && this.selectionPartIds.length > 1;
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
                var ownedMaterialCount = 0;
                for (var j = 0; j < editedParts[i].material_origins.length; j++) {
                    if (editedParts[i].material_origins[j] === 1) {    // 1 = MATERIAL_ORIGIN_OWNED
                        ownedMaterialCount++;
                    }
                }
                var material_name = null;
                if (ownedMaterialCount === editedParts[i].material_origins.length) {
                    material_name = editedPart.material_name;
                } else if (ownedMaterialCount > 0) {
                    material_name = MULTIPLE_VALUE;
                }
                if (i === 0) {
                    editedPart.material_name = material_name;
                } else {
                    if (editedPart.material_name !== material_name) {
                        editedPart.material_name = MULTIPLE_VALUE;
                    }
                }
                if (editedPart.cumulable !== editedParts[i].cumulable) {
                    editedPart.cumulable = MULTIPLE_VALUE;
                }
                if (editedPart.unit_price !== editedParts[i].unit_price) {
                    editedPart.unit_price = MULTIPLE_VALUE;
                }
                if (editedPart.unit_mass !== editedParts[i].unit_mass) {
                    editedPart.unit_mass = MULTIPLE_VALUE;
                }
                editedPart.tags = editedPart.tags.filter(function(tag) {  // Extract only commun tags
                    return -1 !== editedParts[i].tags.indexOf(tag);
                });
                if (editedPart.length_increase !== editedParts[i].length_increase) {
                    editedPart.length_increase = MULTIPLE_VALUE;
                }
                if (editedPart.width_increase !== editedParts[i].width_increase) {
                    editedPart.width_increase = MULTIPLE_VALUE;
                }
                if (editedPart.thickness_increase !== editedParts[i].thickness_increase) {
                    editedPart.thickness_increase = MULTIPLE_VALUE;
                }
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

            if (tab === undefined) {
                tab = this.lastEditPartTab;
            }
            if (tab === null || tab.length === 0
                || tab === 'axes' && multiple
                || tab === 'edges' && group.material_type !== 2 /* 2 = TYPE_SHEET_GOOD */
                || tab === 'infos'
                || tab === 'warnings'
            ) {
                tab = 'general';
            }
            this.lastEditPartTab = tab;

            var fnOpenModal = function(thumbnailFile) {

                var $modal = that.appendModalInside('ladb_cutlist_modal_part', 'tabs/cutlist/_modal-part.twig', {
                    group: group,
                    part: editedPart,
                    part_count: editedParts.length,
                    multiple: multiple,
                    thumbnailFile: thumbnailFile,
                    materialUsages: that.materialUsages,
                    tab: tab
                }, true);

                // Fetch UI elements
                var $tabs = $('a[data-toggle="tab"]', $modal);
                var $inputName = $('#ladb_cutlist_part_input_name', $modal);
                var $selectMaterialName = $('#ladb_cutlist_part_select_material_name', $modal);
                var $selectCumulable = $('#ladb_cutlist_part_select_cumulable', $modal);
                var $inputOrientationLockedOnAxis = $('#ladb_cutlist_part_input_orientation_locked_on_axis', $modal);
                var $inputUnitPrice = $('#ladb_cutlist_part_input_unit_price', $modal);
                var $inputUnitMass = $('#ladb_cutlist_part_input_unit_mass', $modal);
                var $inputTags = $('#ladb_cutlist_part_input_tags', $modal);
                var $inputLengthIncrease = $('#ladb_cutlist_part_input_length_increase', $modal);
                var $inputWidthIncrease = $('#ladb_cutlist_part_input_width_increase', $modal);
                var $inputThicknessIncrease = $('#ladb_cutlist_part_input_thickness_increase', $modal);
                var $inputPartAxes = $('#ladb_cutlist_part_input_axes', $modal);
                var $sortablePartAxes = $('#ladb_sortable_part_axes', $modal);
                var $sortablePartAxesExtra = $('#ladb_sortable_part_axes_extra', $modal);
                var $selectPartAxesOriginPosition = $('#ladb_cutlist_part_select_axes_origin_position', $modal);
                var $selectEdgeYmaxMaterialName = $('#ladb_cutlist_part_select_edge_ymax_material_name', $modal);
                var $selectEdgeYminMaterialName = $('#ladb_cutlist_part_select_edge_ymin_material_name', $modal);
                var $selectEdgeXminMaterialName = $('#ladb_cutlist_part_select_edge_xmin_material_name', $modal);
                var $selectEdgeXmaxMaterialName = $('#ladb_cutlist_part_select_edge_xmax_material_name', $modal);
                var $rectIncreaseLength = $('svg .increase-length', $modal);
                var $rectIncreaseWidth = $('svg .increase-width', $modal);
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
                    return axes;
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
                var fnUpdateIncreasesPreview = function() {
                    if ($inputLengthIncrease.val() == null || $inputLengthIncrease.val().length === 0 || $inputLengthIncrease.val().match(/^0([.,]{0,1}[0]*)(m|cm|mm|yd|'|")*$/g)) {
                        $rectIncreaseLength.removeClass('ladb-active');
                    } else {
                        $rectIncreaseLength.addClass('ladb-active');
                    }
                    if ($inputWidthIncrease.val() == null || $inputWidthIncrease.val().length === 0 || $inputWidthIncrease.val().match(/^0([.,]{0,1}[0]*)(m|cm|mm|yd|'|")*$/g)) {
                        $rectIncreaseWidth.removeClass('ladb-active');
                    } else {
                        $rectIncreaseWidth.addClass('ladb-active');
                    }
                };
                fnUpdateIncreasesPreview();

                var fnNewCheck = function($select, type) {
                    if ($select.val() === 'new') {
                        that.dialog.executeCommandOnTab('materials', 'new_material', { type: type });
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

                // Bind tabs
                $tabs.on('shown.bs.tab', function (e) {
                    that.lastEditPartTab = $(e.target).attr('href').substring('#tab_edit_part_'.length);
                })

                // Bind input
                $inputUnitPrice.ladbTextinputCurrency();
                $inputUnitMass.ladbTextinputMass();
                $inputLengthIncrease.on('change', function() {
                    fnUpdateIncreasesPreview();
                });
                $inputLengthIncrease.ladbTextinputDimension();
                $inputWidthIncrease.on('change', function() {
                    fnUpdateIncreasesPreview();
                });
                $inputWidthIncrease.ladbTextinputDimension();

                // Bind select
                $selectMaterialName.val(editedPart.material_name);
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

                // Bind increases
                $rectIncreaseLength.on('click', function() {
                    $inputLengthIncrease.focus();
                });
                $rectIncreaseWidth.on('click', function() {
                    $inputWidthIncrease.focus();
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
                        var axes = fnComputeAxesOrder();

                        var oriented = editedPart.normals_to_values[axes[0]] >= editedPart.normals_to_values[axes[1]]
                            &&  editedPart.normals_to_values[axes[1]] >= editedPart.normals_to_values[axes[2]];

                        // Check Orientation Locked On Axis option if needed
                        $inputOrientationLockedOnAxis.prop('checked', !oriented);
                        fnDisplayAxisDimensions();

                        // By default set origin position to 'min'
                        $selectPartAxesOriginPosition.selectpicker('val', 'min');

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
                    that.highlightPart(part.id);
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

                        if ($selectMaterialName.val() !== MULTIPLE_VALUE) {
                            editedParts[i].material_name = $selectMaterialName.val();
                        }
                        if ($selectCumulable.val() !== MULTIPLE_VALUE) {
                            editedParts[i].cumulable = $selectCumulable.val();
                        }
                        if ($inputUnitPrice.val() !== MULTIPLE_VALUE) {
                            editedParts[i].unit_price = $inputUnitPrice.val();
                        }
                        if ($inputUnitMass.val() !== MULTIPLE_VALUE) {
                            editedParts[i].unit_mass = $inputUnitMass.val();
                        }

                        var untouchTags = editedParts[i].tags.filter(function (tag) { return !editedPart.tags.includes(tag) });
                        editedParts[i].tags = untouchTags.concat($inputTags.tokenfield('getTokensList').split(';'));

                        if ($inputLengthIncrease.val() !== MULTIPLE_VALUE) {
                            editedParts[i].length_increase = $inputLengthIncrease.val();
                        }
                        if ($inputWidthIncrease.val() !== MULTIPLE_VALUE) {
                            editedParts[i].width_increase = $inputWidthIncrease.val();
                        }
                        if ($inputThicknessIncrease.val() !== MULTIPLE_VALUE) {
                            editedParts[i].thickness_increase = $inputThicknessIncrease.val();
                        }

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

                            that.dialog.notifyErrors(response['errors']);

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
                                    $part.effect('highlight', {}, 1500);
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

                // Init tokenfields (this must done after modal shown for correct token tag max width measurement)
                $inputTags
                    .tokenfield($.extend(TOKENFIELD_OPTIONS, {
                        autocomplete: {
                            source: that.usedTags,
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
                that.dialog.setupPopovers();
                that.dialog.setupTooltips();

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
        this.dialog.setSetting(SETTING_KEY_OPTION_HIDDEN_GROUP_IDS, this.generateOptions.hidden_group_ids, 2 /* SETTINGS_RW_STRATEGY_MODEL */);
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

    LadbTabCutlist.prototype.cuttingdiagram1dGroup = function (groupId, forceDefaultTab) {
        var that = this;

        // Reset lastCuttingdiagram1dOptionsTab if new group
        if (groupId !== this.lastCuttingdiagram1dGroupId) {
            this.lastCuttingdiagram1dOptionsTab = null;
        }
        this.lastCuttingdiagram1dGroupId = groupId;

        var group = this.findGroupById(groupId);
        var selectionOnly = this.selectionGroupId === groupId && this.selectionPartIds.length > 0;

        // Retrieve cutting diagram options
        this.dialog.pullSettings([

                // Defaults
                SETTING_KEY_CUTTINGDIAGRAM1D_OPTION_SAW_KERF,
                SETTING_KEY_CUTTINGDIAGRAM1D_OPTION_TRIMMING,
                SETTING_KEY_CUTTINGDIAGRAM1D_OPTION_BAR_FOLDING,
                SETTING_KEY_CUTTINGDIAGRAM1D_OPTION_HIDE_CROSS,
                SETTING_KEY_CUTTINGDIAGRAM1D_OPTION_HIDE_PART_LIST,
                SETTING_KEY_CUTTINGDIAGRAM1D_OPTION_WRAP_LENGTH,

                SETTING_KEY_CUTTINGDIAGRAM1D_OPTION_STD_BAR + '_' + groupId,
                SETTING_KEY_CUTTINGDIAGRAM1D_OPTION_SCRAP_BAR_LENGTHS + '_' + groupId,
                SETTING_KEY_CUTTINGDIAGRAM1D_OPTION_SAW_KERF + '_' + groupId,
                SETTING_KEY_CUTTINGDIAGRAM1D_OPTION_TRIMMING + '_' + groupId,
                SETTING_KEY_CUTTINGDIAGRAM1D_OPTION_BAR_FOLDING + '_' + groupId,
                SETTING_KEY_CUTTINGDIAGRAM1D_OPTION_HIDE_CROSS + '_' + groupId,
                SETTING_KEY_CUTTINGDIAGRAM1D_OPTION_HIDE_PART_LIST + '_' + groupId,
                SETTING_KEY_CUTTINGDIAGRAM1D_OPTION_WRAP_LENGTH + '_' + groupId,

            ],
            2 /* SETTINGS_RW_STRATEGY_MODEL */,
            function () {

                rubyCallCommand('core_get_app_defaults', { dictionary: 'cutlist_cuttingdiagram1d_options' }, function (response) {

                    if (response.errors && response.errors.length > 0) {
                        that.dialog.notifyErrors(response.errors);
                    } else {

                        var appDefaults = response.defaults;

                        var cuttingdiagram1dOptions = {
                            std_bar: that.dialog.getSetting(SETTING_KEY_CUTTINGDIAGRAM1D_OPTION_STD_BAR + '_' + groupId, ''),
                            scrap_bar_lengths: that.dialog.getSetting(SETTING_KEY_CUTTINGDIAGRAM1D_OPTION_SCRAP_BAR_LENGTHS + '_' + groupId, appDefaults.scrap_bar_lengths),
                            saw_kerf: that.dialog.getSetting(SETTING_KEY_CUTTINGDIAGRAM1D_OPTION_SAW_KERF + '_' + groupId, that.dialog.getSetting(SETTING_KEY_CUTTINGDIAGRAM1D_OPTION_SAW_KERF, appDefaults.saw_kerf)),
                            trimming: that.dialog.getSetting(SETTING_KEY_CUTTINGDIAGRAM1D_OPTION_TRIMMING + '_' + groupId, that.dialog.getSetting(SETTING_KEY_CUTTINGDIAGRAM1D_OPTION_TRIMMING, appDefaults.trimming)),
                            bar_folding: that.dialog.getSetting(SETTING_KEY_CUTTINGDIAGRAM1D_OPTION_BAR_FOLDING + '_' + groupId, that.dialog.getSetting(SETTING_KEY_CUTTINGDIAGRAM1D_OPTION_BAR_FOLDING, appDefaults.bar)),
                            hide_cross: that.dialog.getSetting(SETTING_KEY_CUTTINGDIAGRAM1D_OPTION_HIDE_CROSS + '_' + groupId, that.dialog.getSetting(SETTING_KEY_CUTTINGDIAGRAM1D_OPTION_HIDE_CROSS, appDefaults.hide_cross)),
                            hide_part_list: that.dialog.getSetting(SETTING_KEY_CUTTINGDIAGRAM1D_OPTION_HIDE_PART_LIST + '_' + groupId, that.dialog.getSetting(SETTING_KEY_CUTTINGDIAGRAM1D_OPTION_HIDE_PART_LIST, appDefaults.hide_part_list)),
                            wrap_length: that.dialog.getSetting(SETTING_KEY_CUTTINGDIAGRAM1D_OPTION_WRAP_LENGTH + '_' + groupId, that.dialog.getSetting(SETTING_KEY_CUTTINGDIAGRAM1D_OPTION_WRAP_LENGTH, appDefaults.wrap_length)),
                        };

                        rubyCallCommand('materials_get_attributes_command', { name: group.material_name }, function (response) {

                            var $modal = that.appendModalInside('ladb_cutlist_modal_cuttingdiagram_1d', 'tabs/cutlist/_modal-cuttingdiagram-1d.twig', {
                                material_attributes: response,
                                group: group,
                                selection_only: selectionOnly,
                                tab: forceDefaultTab || that.lastCuttingdiagram1dOptionsTab == null ? 'material' : that.lastCuttingdiagram1dOptionsTab
                            }, true);

                            // Fetch UI elements
                            var $inputStdBar = $('#ladb_select_std_bar', $modal);
                            var $inputStdBarLength = $('#ladb_input_std_bar_length', $modal);
                            var $inputScrapBarLengths = $('#ladb_input_scrap_bar_lengths', $modal);
                            var $inputSawKerf = $('#ladb_input_saw_kerf', $modal);
                            var $inputTrimming = $('#ladb_input_trimming', $modal);
                            var $selectBarFolding = $('#ladb_select_bar_folding', $modal);
                            var $selectHideCross = $('#ladb_select_hide_cross', $modal);
                            var $selectHidePartList = $('#ladb_select_hide_part_list', $modal);
                            var $inputWrapLength = $('#ladb_input_wrap_length', $modal);
                            var $btnCuttingdiagramOptionsDefaultsSave = $('#ladb_btn_cuttingdiagram_options_defaults_save', $modal);
                            var $btnCuttingdiagramOptionsDefaultsReset = $('#ladb_btn_cuttingdiagram_options_defaults_reset', $modal);
                            var $btnCuttingdiagramOptionsDefaultsResetNative = $('#ladb_btn_cuttingdiagram_options_defaults_reset_native', $modal);
                            var $btnEditMaterial = $('#ladb_btn_edit_material', $modal);
                            var $btnCuttingdiagram = $('#ladb_btn_cuttingdiagram', $modal);

                            if (cuttingdiagram1dOptions.std_bar) {
                                var defaultValue = $inputStdBar.val();
                                $inputStdBar.val(cuttingdiagram1dOptions.std_bar);
                                if ($inputStdBar.val() == null) {
                                    if (response.std_lengths.length === 0) {
                                        $inputStdBar.val('0');  // Special case if the std_bar is not present anymore in the list and no std size defined. Select "none" by default.
                                    } else {
                                        $inputStdBar.val(defaultValue);
                                    }
                                }
                            }
                            $inputScrapBarLengths.ladbTextinputTokenfield({ format: 'dxq' });
                            $inputScrapBarLengths.ladbTextinputTokenfield('setTokens', cuttingdiagram1dOptions.scrap_bar_lengths);
                            $inputStdBar.selectpicker(SELECT_PICKER_OPTIONS);
                            $inputSawKerf.val(cuttingdiagram1dOptions.saw_kerf);
                            $inputSawKerf.ladbTextinputDimension();
                            $inputTrimming.val(cuttingdiagram1dOptions.trimming);
                            $inputTrimming.ladbTextinputDimension();
                            $selectBarFolding.val(cuttingdiagram1dOptions.bar_folding ? '1' : '0');
                            $selectBarFolding.selectpicker(SELECT_PICKER_OPTIONS);
                            $selectHideCross.val(cuttingdiagram1dOptions.hide_cross ? '1' : '0');
                            $selectHideCross.selectpicker(SELECT_PICKER_OPTIONS);
                            $selectHidePartList.val(cuttingdiagram1dOptions.hide_part_list ? '1' : '0');
                            $selectHidePartList.selectpicker(SELECT_PICKER_OPTIONS);
                            $inputWrapLength.val(cuttingdiagram1dOptions.wrap_length);
                            $inputWrapLength.ladbTextinputDimension();

                            var fnEditMaterial = function (callback) {

                                // Hide modal
                                $modal.modal('hide');

                                // Edit material and focus std_sizes input field
                                that.dialog.executeCommandOnTab('materials', 'edit_material', {
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
                                } else if (value) {
                                    $inputStdBarLength.val(value);
                                }
                            };
                            var fnSetFieldValuesToDefaults = function (isAppDefaults) {
                                $inputSawKerf.val(isAppDefaults ? appDefaults.saw_kerf : that.dialog.getSetting(SETTING_KEY_CUTTINGDIAGRAM1D_OPTION_SAW_KERF, appDefaults.saw_kerf));
                                $inputTrimming.val(isAppDefaults ? appDefaults.trimming : that.dialog.getSetting(SETTING_KEY_CUTTINGDIAGRAM1D_OPTION_TRIMMING, appDefaults.trimming));
                                $selectBarFolding.selectpicker('val', (isAppDefaults ? appDefaults.bar_folding : that.dialog.getSetting(SETTING_KEY_CUTTINGDIAGRAM1D_OPTION_BAR_FOLDING, appDefaults.bar_folding)) ? '1' : '0');
                                $selectHideCross.selectpicker('val', (isAppDefaults ? appDefaults.hide_cross : that.dialog.getSetting(SETTING_KEY_CUTTINGDIAGRAM1D_OPTION_HIDE_CROSS, appDefaults.hide_cross)) ? '1' : '0');
                                $selectHidePartList.selectpicker('val', (isAppDefaults ? appDefaults.hide_part_list : that.dialog.getSetting(SETTING_KEY_CUTTINGDIAGRAM1D_OPTION_HIDE_PART_LIST, appDefaults.hide_part_list)) ? '1' : '0');
                                $inputWrapLength.val(isAppDefaults ? appDefaults.wrap_length : that.dialog.getSetting(SETTING_KEY_CUTTINGDIAGRAM1D_OPTION_WRAP_LENGTH, appDefaults.wrap_length));
                            };

                            $inputStdBar.on('changed.bs.select', function (e) {
                                fnSelectSize();
                            });
                            fnSelectSize();

                            // Bind tabs
                            $('a[data-toggle=tab]').on('shown.bs.tab', function (e) {
                                var tabId = $(e.target).attr('href');
                                that.lastCuttingdiagram1dOptionsTab = tabId.substring('#tab_cuttingdiagram_options_'.length);
                                if (tabId === '#tab_cuttingdiagram_options_material') {
                                    $('#ladb_panel_cuttingdiagram_options_defaults', $modal).hide();
                                } else {
                                    $('#ladb_panel_cuttingdiagram_options_defaults', $modal).show();
                                }
                            })

                            // Bind buttons
                            $btnCuttingdiagramOptionsDefaultsSave.on('click', function () {

                                var saw_kerf = $inputSawKerf.val();
                                var trimming = $inputTrimming.val();
                                var bar_folding = $selectBarFolding.val();
                                var hide_cross = $selectHideCross.val();
                                var hide_part_list = $selectHidePartList.val();
                                var wrap_length = $inputWrapLength.val();

                                // Update default cut options for specific type to last used
                                that.dialog.setSettings([
                                    { key:SETTING_KEY_CUTTINGDIAGRAM1D_OPTION_SAW_KERF, value:saw_kerf, preprocessor:1 /* SETTINGS_PREPROCESSOR_D */ },
                                    { key:SETTING_KEY_CUTTINGDIAGRAM1D_OPTION_TRIMMING, value:trimming, preprocessor:1 /* SETTINGS_PREPROCESSOR_D */ },
                                    { key:SETTING_KEY_CUTTINGDIAGRAM1D_OPTION_BAR_FOLDING, value:bar_folding },
                                    { key:SETTING_KEY_CUTTINGDIAGRAM1D_OPTION_HIDE_CROSS, value:hide_cross },
                                    { key:SETTING_KEY_CUTTINGDIAGRAM1D_OPTION_HIDE_PART_LIST, value:hide_part_list },
                                    { key:SETTING_KEY_CUTTINGDIAGRAM1D_OPTION_WRAP_LENGTH, value:wrap_length, preprocessor:1 /* SETTINGS_PREPROCESSOR_D */ },
                                ], 0 /* SETTINGS_RW_STRATEGY_GLOBAL */);

                                that.dialog.notify(i18next.t('tab.cutlist.cuttingdiagram.options_defaults.save_success'), 'success');

                                this.blur();

                            });
                            $btnCuttingdiagramOptionsDefaultsReset.on('click', function () {
                                fnSetFieldValuesToDefaults(false);
                                this.blur();
                            });
                            $btnCuttingdiagramOptionsDefaultsResetNative.on('click', function () {
                                fnSetFieldValuesToDefaults(true);
                                this.blur();
                            });
                            $btnEditMaterial.on('click', function () {
                                fnEditMaterial();
                            });
                            $btnCuttingdiagram.on('click', function () {

                                // Fetch options

                                cuttingdiagram1dOptions.std_bar = $inputStdBar.val();
                                cuttingdiagram1dOptions.std_bar_length = $inputStdBarLength.val();
                                cuttingdiagram1dOptions.scrap_bar_lengths = $inputScrapBarLengths.ladbTextinputTokenfield('getValidTokensList');
                                cuttingdiagram1dOptions.saw_kerf = $inputSawKerf.val();
                                cuttingdiagram1dOptions.trimming = $inputTrimming.val();
                                cuttingdiagram1dOptions.bar_folding = $selectBarFolding.val() === '1';
                                cuttingdiagram1dOptions.hide_cross = $selectHideCross.val() === '1';
                                cuttingdiagram1dOptions.hide_part_list = $selectHidePartList.val() === '1';
                                cuttingdiagram1dOptions.wrap_length = $inputWrapLength.val();

                                // Store options
                                that.dialog.setSettings([
                                    { key:SETTING_KEY_CUTTINGDIAGRAM1D_OPTION_STD_BAR + '_' + groupId, value:cuttingdiagram1dOptions.std_bar },
                                    { key:SETTING_KEY_CUTTINGDIAGRAM1D_OPTION_SCRAP_BAR_LENGTHS + '_' + groupId, value:cuttingdiagram1dOptions.scrap_bar_lengths, preprocessor:2 /* SETTINGS_PREPROCESSOR_DXQ */ },
                                    { key:SETTING_KEY_CUTTINGDIAGRAM1D_OPTION_SAW_KERF + '_' + groupId, value:cuttingdiagram1dOptions.saw_kerf, preprocessor:1 /* SETTINGS_PREPROCESSOR_D */ },
                                    { key:SETTING_KEY_CUTTINGDIAGRAM1D_OPTION_TRIMMING + '_' + groupId, value:cuttingdiagram1dOptions.trimming, preprocessor:1 /* SETTINGS_PREPROCESSOR_D */ },
                                    { key:SETTING_KEY_CUTTINGDIAGRAM1D_OPTION_BAR_FOLDING + '_' + groupId, value:cuttingdiagram1dOptions.bar_folding },
                                    { key:SETTING_KEY_CUTTINGDIAGRAM1D_OPTION_HIDE_CROSS + '_' + groupId, value:cuttingdiagram1dOptions.hide_cross },
                                    { key:SETTING_KEY_CUTTINGDIAGRAM1D_OPTION_HIDE_PART_LIST + '_' + groupId, value:cuttingdiagram1dOptions.hide_part_list },
                                    { key:SETTING_KEY_CUTTINGDIAGRAM1D_OPTION_WRAP_LENGTH + '_' + groupId, value:cuttingdiagram1dOptions.wrap_length, preprocessor:1 /* SETTINGS_PREPROCESSOR_D */ },
                                ], 2 /* SETTINGS_RW_STRATEGY_MODEL */);

                                rubyCallCommand('cutlist_group_cuttingdiagram_1d', $.extend({ group_id: groupId, part_ids: that.selectionGroupId === groupId ? that.selectionPartIds : null }, cuttingdiagram1dOptions, that.generateOptions), function (response) {

                                    var $slide = that.pushNewSlide('ladb_cutlist_slide_cuttingdiagram_1d', 'tabs/cutlist/_slide-cuttingdiagram-1d.twig', $.extend({
                                        generateOptions: that.generateOptions,
                                        dimensionColumnOrderStrategy: that.generateOptions.dimension_column_order_strategy.split('>'),
                                        filename: that.filename,
                                        pageLabel: that.pageLabel,
                                        lengthUnit: that.lengthUnit,
                                        generatedAt: new Date().getTime() / 1000,
                                        group: group
                                    }, response), function () {
                                        that.dialog.setupTooltips();
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
                                            $target.effect('highlight', {}, 1500);
                                        });
                                        $(this).blur();
                                        return false;
                                    });
                                    $('.ladb-btn-scrollto-next-group', $slide).on('click', function () {
                                        var $group = $(this).parents('.ladb-cutlist-group');
                                        var groupId = $group.data('bar-index');
                                        var $target = $('.ladb-cuttingdiagram-group[data-bar-index=' + (parseInt(groupId) + 1) + ']');
                                        $slide.animate({ scrollTop: $slide.scrollTop() + $target.position().top - $('.ladb-header', $slide).outerHeight(true) - 20 }, 200).promise().then(function () {
                                            $target.effect('highlight', {}, 1500);
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
                                            $target.effect('highlight', {}, 1500);
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

                            // Setup popovers
                            that.dialog.setupPopovers();

                        });

                    }

                });

            });

    };

    LadbTabCutlist.prototype.cuttingdiagram2dGroup = function (groupId, forceDefaultTab) {
        var that = this;

        var group = this.findGroupById(groupId);
        var selectionOnly = this.selectionGroupId === groupId && this.selectionPartIds.length > 0;

        // Retrieve cutting diagram options
        this.dialog.pullSettings([

                // Defaults
                SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_SAW_KERF,
                SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_TRIMMING,
                SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_OPTIMIZATION,
                SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_STACKING,
                SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_SHEET_FOLDING,
                SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_HIDE_CROSS,
                SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_HIDE_CROSS,
                SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_HIDE_PART_LIST,
                SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_ORIGIN_CORNER,

                SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_STD_SHEET + '_' + groupId,
                SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_SCRAP_SHEET_SIZES + '_' + groupId,
                SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_SAW_KERF + '_' + groupId,
                SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_TRIMMING + '_' + groupId,
                SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_OPTIMIZATION + '_' + groupId,
                SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_STACKING + '_' + groupId,
                SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_SHEET_FOLDING + '_' + groupId,
                SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_HIDE_CROSS + '_' + groupId,
                SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_HIDE_PART_LIST + '_' + groupId,
                SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_ORIGIN_CORNER + '_' + groupId,

            ],
            2 /* SETTINGS_RW_STRATEGY_MODEL */,
            function () {

                rubyCallCommand('core_get_app_defaults', { dictionary: 'cutlist_cuttingdiagram2d_options' }, function (response) {

                    if (response.errors && response.errors.length > 0) {
                        that.dialog.notifyErrors(response.errors);
                    } else {

                        var appDefaults = response.defaults;

                        console.log(appDefaults);

                        var cuttingdiagram2dOptions = {
                            std_sheet: that.dialog.getSetting(SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_STD_SHEET + '_' + groupId, ''),
                            std_sheet_length: '',
                            std_sheet_width: '',
                            grained: false,
                            scrap_sheet_sizes: that.dialog.getSetting(SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_SCRAP_SHEET_SIZES + '_' + groupId, appDefaults.scrap_sheet_sizes),
                            saw_kerf: that.dialog.getSetting(SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_SAW_KERF + '_' + groupId, that.dialog.getSetting(SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_SAW_KERF, appDefaults.saw_kerf)),
                            trimming: that.dialog.getSetting(SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_TRIMMING + '_' + groupId, that.dialog.getSetting(SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_TRIMMING, appDefaults.trimming)),
                            optimization: that.dialog.getSetting(SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_OPTIMIZATION + '_' + groupId, that.dialog.getSetting(SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_OPTIMIZATION, appDefaults.optimization)),
                            stacking: that.dialog.getSetting(SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_STACKING + '_' + groupId, that.dialog.getSetting(SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_STACKING, appDefaults.stacking)),
                            sheet_folding: that.dialog.getSetting(SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_SHEET_FOLDING + '_' + groupId, that.dialog.getSetting(SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_SHEET_FOLDING, appDefaults.sheet_folding)),
                            hide_cross: that.dialog.getSetting(SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_HIDE_CROSS + '_' + groupId, that.dialog.getSetting(SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_HIDE_CROSS, appDefaults.hide_cross)),
                            hide_part_list: that.dialog.getSetting(SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_HIDE_PART_LIST + '_' + groupId, that.dialog.getSetting(SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_HIDE_PART_LIST, appDefaults.hide_part_list)),
                            origin_corner: that.dialog.getSetting(SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_ORIGIN_CORNER + '_' + groupId, that.dialog.getSetting(SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_ORIGIN_CORNER, appDefaults.origin_corner)),
                        };

                        rubyCallCommand('materials_get_attributes_command', { name: group.material_name }, function (response) {

                            var $modal = that.appendModalInside('ladb_cutlist_modal_cuttingdiagram_2d', 'tabs/cutlist/_modal-cuttingdiagram-2d.twig', {
                                material_attributes: response,
                                group: group,
                                selection_only: selectionOnly,
                                tab: forceDefaultTab || that.lastCuttingdiagram2dOptionsTab == null ? 'material' : that.lastCuttingdiagram2dOptionsTab
                            }, true);

                            // Fetch UI elements
                            var $inputStdSheet = $('#ladb_select_std_sheet', $modal);
                            var $inputStdSheetLength = $('#ladb_input_std_sheet_length', $modal);
                            var $inputStdSheetWidth = $('#ladb_input_std_sheet_width', $modal);
                            var $inputGrained = $('#ladb_input_grained', $modal);
                            var $inputScrapSheetSizes = $('#ladb_input_scrap_sheet_sizes', $modal);
                            var $inputSawKerf = $('#ladb_input_saw_kerf', $modal);
                            var $inputTrimming = $('#ladb_input_trimming', $modal);
                            var $selectOptimization = $('#ladb_select_optimization', $modal);
                            var $selectStacking = $('#ladb_select_stacking', $modal);
                            var $selectSheetFolding = $('#ladb_select_sheet_folding', $modal);
                            var $selectHideCross = $('#ladb_select_hide_cross', $modal);
                            var $selectHidePartList = $('#ladb_select_hide_part_list', $modal);
                            var $selectOriginCorner = $('#ladb_select_origin_corner', $modal);
                            var $btnCuttingdiagramOptionsDefaultsSave = $('#ladb_btn_cuttingdiagram_options_defaults_save', $modal);
                            var $btnCuttingdiagramOptionsDefaultsReset = $('#ladb_btn_cuttingdiagram_options_defaults_reset', $modal);
                            var $btnCuttingdiagramOptionsDefaultsResetNative = $('#ladb_btn_cuttingdiagram_options_defaults_reset_native', $modal);
                            var $btnEditMaterial = $('#ladb_btn_edit_material', $modal);
                            var $btnCuttingdiagram = $('#ladb_btn_cuttingdiagram', $modal);

                            if (cuttingdiagram2dOptions.std_sheet) {
                                var defaultValue = $inputStdSheet.val();
                                $inputStdSheet.val(cuttingdiagram2dOptions.std_sheet);
                                if ($inputStdSheet.val() == null) {
                                    if (response.std_sizes.length === 0) {
                                        $inputStdSheet.val('0x0|' + response.grained);  // Special case if the std_sheet is not present anymore in the list and no std size defined. Select "none" by default.
                                    } else {
                                        $inputStdSheet.val(defaultValue);
                                    }
                                }
                            }
                            $inputScrapSheetSizes.ladbTextinputTokenfield({ format: 'dxdxq' });
                            $inputScrapSheetSizes.ladbTextinputTokenfield('setTokens', cuttingdiagram2dOptions.scrap_sheet_sizes);
                            $inputStdSheet.selectpicker(SELECT_PICKER_OPTIONS);
                            $inputSawKerf.val(cuttingdiagram2dOptions.saw_kerf);
                            $inputSawKerf.ladbTextinputDimension();
                            $inputTrimming.val(cuttingdiagram2dOptions.trimming);
                            $inputTrimming.ladbTextinputDimension();
                            $selectOptimization.val(cuttingdiagram2dOptions.optimization);
                            $selectOptimization.selectpicker(SELECT_PICKER_OPTIONS);
                            $selectStacking.val(cuttingdiagram2dOptions.stacking);
                            $selectStacking.selectpicker(SELECT_PICKER_OPTIONS);
                            $selectSheetFolding.val(cuttingdiagram2dOptions.sheet_folding ? '1' : '0');
                            $selectSheetFolding.selectpicker(SELECT_PICKER_OPTIONS);
                            $selectHideCross.val(cuttingdiagram2dOptions.hide_cross ? '1' : '0');
                            $selectHideCross.selectpicker(SELECT_PICKER_OPTIONS);
                            $selectHidePartList.val(cuttingdiagram2dOptions.hide_part_list ? '1' : '0');
                            $selectHidePartList.selectpicker(SELECT_PICKER_OPTIONS);
                            $selectOriginCorner.val(cuttingdiagram2dOptions.origin_corner);
                            $selectOriginCorner.selectpicker(SELECT_PICKER_OPTIONS);

                            var fnEditMaterial = function (callback) {

                                // Hide modal
                                $modal.modal('hide');

                                // Edit material and focus std_sizes input field
                                that.dialog.executeCommandOnTab('materials', 'edit_material', {
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
                                } else if (value) {
                                    var sizeAndGrained = value.split('|');
                                    var size = sizeAndGrained[0].split('x');
                                    var stdSheetLength = size[0].trim();
                                    var stdSheetWidth = size[1].trim();
                                    var grained = sizeAndGrained[1] === 'true';
                                    $inputStdSheetLength.val(stdSheetLength);
                                    $inputStdSheetWidth.val(stdSheetWidth);
                                    $inputGrained.val(grained ? '1' : '0');
                                }
                            };
                            var fnSetFieldValuesToDefaults = function (isAppDefaults) {
                                $inputSawKerf.val(isAppDefaults ? appDefaults.saw_kerf : that.dialog.getSetting(SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_SAW_KERF, appDefaults.saw_kerf));
                                $inputTrimming.val(isAppDefaults ? appDefaults.trimming : that.dialog.getSetting(SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_TRIMMING, appDefaults.trimming));
                                $selectOptimization.selectpicker('val', isAppDefaults ? appDefaults.optimization : that.dialog.getSetting(SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_OPTIMIZATION, appDefaults.optimization));
                                $selectStacking.selectpicker('val', isAppDefaults ? appDefaults.stacking : that.dialog.getSetting(SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_STACKING, appDefaults.stacking));
                                $selectSheetFolding.selectpicker('val', (isAppDefaults ? appDefaults.sheet_folding : that.dialog.getSetting(SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_SHEET_FOLDING, appDefaults.sheet_folding)) ? '1' : '0');
                                $selectHideCross.selectpicker('val', (isAppDefaults ? appDefaults.hide_cross : that.dialog.getSetting(SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_HIDE_CROSS, appDefaults.hide_cross)) ? '1' : '0');
                                $selectHidePartList.selectpicker('val', (isAppDefaults ? appDefaults.hide_part_list : that.dialog.getSetting(SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_HIDE_PART_LIST, appDefaults.hide_part_list)) ? '1' : '0');
                                $selectOriginCorner.selectpicker('val', isAppDefaults ? appDefaults.origin_corner : that.dialog.getSetting(SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_ORIGIN_CORNER, appDefaults.origin_corner));
                            };

                            $inputStdSheet.on('changed.bs.select', function (e) {
                                fnSelectSize();
                            });
                            fnSelectSize();

                            // Bind tabs
                            $('a[data-toggle=tab]').on('shown.bs.tab', function (e) {
                                var tabId = $(e.target).attr('href');
                                that.lastCuttingdiagram2dOptionsTab = tabId.substring('#tab_cuttingdiagram_options_'.length);
                                if (tabId === '#tab_cuttingdiagram_options_material') {
                                    $('#ladb_panel_cuttingdiagram_options_defaults', $modal).hide();
                                } else {
                                    $('#ladb_panel_cuttingdiagram_options_defaults', $modal).show();
                                }
                            })

                            // Bind buttons
                            $btnCuttingdiagramOptionsDefaultsSave.on('click', function () {

                                var saw_kerf = $inputSawKerf.val();
                                var trimming = $inputTrimming.val();
                                var optimization = $selectOptimization.val();
                                var stacking = $selectStacking.val();
                                var sheet_folding = $selectSheetFolding.val();
                                var hide_cross = $selectHideCross.val();
                                var hide_part_list = $selectHidePartList.val();
                                var origin_corner = $selectOriginCorner.val();

                                // Update default cut options for specific type to last used
                                that.dialog.setSettings([
                                    { key:SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_SAW_KERF, value:saw_kerf, preprocessor:1 /* SETTINGS_PREPROCESSOR_D */ },
                                    { key:SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_TRIMMING, value:trimming, preprocessor:1 /* SETTINGS_PREPROCESSOR_D */ },
                                    { key:SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_OPTIMIZATION, value:optimization },
                                    { key:SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_STACKING, value:stacking },
                                    { key:SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_SHEET_FOLDING, value:sheet_folding },
                                    { key:SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_HIDE_CROSS, value:hide_cross },
                                    { key:SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_HIDE_PART_LIST, value:hide_part_list },
                                    { key:SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_ORIGIN_CORNER, value:origin_corner },
                                ], 0 /* SETTINGS_RW_STRATEGY_GLOBAL */);

                                that.dialog.notify(i18next.t('tab.cutlist.cuttingdiagram.options_defaults.save_success'), 'success');

                                this.blur();

                            });
                            $btnCuttingdiagramOptionsDefaultsReset.on('click', function () {
                                fnSetFieldValuesToDefaults(false);
                                this.blur();
                            });
                            $btnCuttingdiagramOptionsDefaultsResetNative.on('click', function () {
                                fnSetFieldValuesToDefaults(true);
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
                                cuttingdiagram2dOptions.grained = $inputGrained.val() === '1';
                                cuttingdiagram2dOptions.scrap_sheet_sizes = $inputScrapSheetSizes.ladbTextinputTokenfield('getValidTokensList');
                                cuttingdiagram2dOptions.saw_kerf = $inputSawKerf.val();
                                cuttingdiagram2dOptions.trimming = $inputTrimming.val();
                                cuttingdiagram2dOptions.optimization = $selectOptimization.val();
                                cuttingdiagram2dOptions.stacking = $selectStacking.val();
                                cuttingdiagram2dOptions.sheet_folding = $selectSheetFolding.val() === '1';
                                cuttingdiagram2dOptions.hide_cross = $selectHideCross.val() === '1';
                                cuttingdiagram2dOptions.hide_part_list = $selectHidePartList.val() === '1';
                                cuttingdiagram2dOptions.origin_corner = $selectOriginCorner.val();

                                // Store options
                                that.dialog.setSettings([
                                    { key:SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_STD_SHEET + '_' + groupId, value:cuttingdiagram2dOptions.std_sheet },
                                    { key:SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_SCRAP_SHEET_SIZES + '_' + groupId, value:cuttingdiagram2dOptions.scrap_sheet_sizes, preprocessor:4 /* SETTINGS_PREPROCESSOR_DXDXQ */ },
                                    { key:SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_SAW_KERF + '_' + groupId, value:cuttingdiagram2dOptions.saw_kerf, preprocessor:1 /* SETTINGS_PREPROCESSOR_D */ },
                                    { key:SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_TRIMMING + '_' + groupId, value:cuttingdiagram2dOptions.trimming, preprocessor:1 /* SETTINGS_PREPROCESSOR_D */ },
                                    { key:SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_OPTIMIZATION + '_' + groupId, value:cuttingdiagram2dOptions.optimization },
                                    { key:SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_STACKING + '_' + groupId, value:cuttingdiagram2dOptions.stacking },
                                    { key:SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_SHEET_FOLDING + '_' + groupId, value:cuttingdiagram2dOptions.sheet_folding },
                                    { key:SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_HIDE_CROSS + '_' + groupId, value:cuttingdiagram2dOptions.hide_cross },
                                    { key:SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_HIDE_PART_LIST + '_' + groupId, value:cuttingdiagram2dOptions.hide_part_list },
                                    { key:SETTING_KEY_CUTTINGDIAGRAM2D_OPTION_ORIGIN_CORNER + '_' + groupId, value:cuttingdiagram2dOptions.origin_corner },
                                ], 2 /* SETTINGS_RW_STRATEGY_MODEL */);

                                rubyCallCommand('cutlist_group_cuttingdiagram_2d', $.extend({ group_id: groupId, part_ids: that.selectionGroupId === groupId ? that.selectionPartIds : null }, cuttingdiagram2dOptions, that.generateOptions), function (response) {

                                    var $slide = that.pushNewSlide('ladb_cutlist_slide_cuttingdiagram_2d', 'tabs/cutlist/_slide-cuttingdiagram-2d.twig', $.extend({
                                        generateOptions: that.generateOptions,
                                        dimensionColumnOrderStrategy: that.generateOptions.dimension_column_order_strategy.split('>'),
                                        filename: that.filename,
                                        pageLabel: that.pageLabel,
                                        lengthUnit: that.lengthUnit,
                                        generatedAt: new Date().getTime() / 1000,
                                        group: group
                                    }, response), function () {
                                        that.dialog.setupTooltips();
                                    });

                                    // Fetch UI elements
                                    var $btnCuttingDiagram = $('#ladb_btn_cuttingdiagram', $slide);
                                    var $btnPrint = $('#ladb_btn_print', $slide);
                                    var $btnLabels = $('#ladb_btn_labels', $slide);
                                    var $btnClose = $('#ladb_btn_close', $slide);

                                    // Bind buttons
                                    $btnCuttingDiagram.on('click', function () {
                                        that.cuttingdiagram2dGroup(groupId);
                                    });
                                    $btnPrint.on('click', function () {
                                        window.print();
                                    });
                                    $btnLabels.on('click', function () {
                                        // Show Objective modal
                                        that.dialog.executeCommandOnTab('sponsor', 'show_objective_modal', { objectiveStrippedName: 'labels' }, null, true);
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

                            // Setup popovers
                            that.dialog.setupPopovers();

                        });

                    }

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
                that.dialog.notifyErrors(response['errors']);
            } else {
                that.generateCutlist(callback);
            }

        });

    };

    LadbTabCutlist.prototype.numbersReset = function (params, callback) {
        var that = this;

        rubyCallCommand('cutlist_numbers_reset', params ? params : {}, function (response) {

            if (response['errors']) {
                that.dialog.notifyErrors(response['errors']);
            } else {
                that.generateCutlist(callback);
            }

        });

    };

    // Options /////

    LadbTabCutlist.prototype.loadOptions = function (callback) {
        var that = this;

        this.dialog.pullSettings([

                SETTING_KEY_OPTION_AUTO_ORIENT,
                SETTING_KEY_OPTION_SMART_MATERIAL,
                SETTING_KEY_OPTION_DYNAMIC_ATTRIBUTES_NAME,
                SETTING_KEY_OPTION_PART_NUMBER_WITH_LETTERS,
                SETTING_KEY_OPTION_PART_NUMBER_SEQUENCE_BY_GROUP,
                SETTING_KEY_OPTION_PART_FOLDING,
                SETTING_KEY_OPTION_HIDE_ENTITY_NAMES,
                SETTING_KEY_OPTION_HIDE_TAGS,
                SETTING_KEY_OPTION_HIDE_CUTTING_DIMENSIONS,
                SETTING_KEY_OPTION_HIDE_BBOX_DIMENSIONS,
                SETTING_KEY_OPTION_HIDE_FINAL_AREAS,
                SETTING_KEY_OPTION_HIDE_EDGES,
                SETTING_KEY_OPTION_MINIMIZE_ON_HIGHLIGHT,
                SETTING_KEY_OPTION_PART_ORDER_STRATEGY,
                SETTING_KEY_OPTION_DIMENSION_COLUMN_ORDER_STRATEGY,
                SETTING_KEY_OPTION_HIDDEN_GROUP_IDS

            ],
            3 /* SETTINGS_RW_STRATEGY_MODEL_GLOBAL */,
            function () {

                rubyCallCommand('core_get_app_defaults', { dictionary: 'cutlist_options' }, function (response) {

                    if (response.errors && response.errors.length > 0) {
                        that.dialog.notifyErrors(response.errors);
                    } else {

                        var appDefaults = response.defaults;

                        that.generateOptions = {
                            auto_orient: that.dialog.getSetting(SETTING_KEY_OPTION_AUTO_ORIENT, appDefaults.auto_orient),
                            smart_material: that.dialog.getSetting(SETTING_KEY_OPTION_SMART_MATERIAL, appDefaults.smart_material),
                            dynamic_attributes_name: that.dialog.getSetting(SETTING_KEY_OPTION_DYNAMIC_ATTRIBUTES_NAME, appDefaults.dynamic_attributes_name),
                            part_number_with_letters: that.dialog.getSetting(SETTING_KEY_OPTION_PART_NUMBER_WITH_LETTERS, appDefaults.part_number_with_letters),
                            part_number_sequence_by_group: that.dialog.getSetting(SETTING_KEY_OPTION_PART_NUMBER_SEQUENCE_BY_GROUP, appDefaults.part_number_sequence_by_group),
                            part_folding: that.dialog.getSetting(SETTING_KEY_OPTION_PART_FOLDING, appDefaults.part_folding),
                            hide_entity_names: that.dialog.getSetting(SETTING_KEY_OPTION_HIDE_ENTITY_NAMES, appDefaults.hide_entity_names),
                            hide_tags: that.dialog.getSetting(SETTING_KEY_OPTION_HIDE_TAGS, appDefaults.hide_tags),
                            hide_cutting_dimensions: that.dialog.getSetting(SETTING_KEY_OPTION_HIDE_CUTTING_DIMENSIONS, appDefaults.hide_cutting_dimensions),
                            hide_bbox_dimensions: that.dialog.getSetting(SETTING_KEY_OPTION_HIDE_BBOX_DIMENSIONS, appDefaults.hide_bbox_dimensions),
                            hide_final_areas: that.dialog.getSetting(SETTING_KEY_OPTION_HIDE_FINAL_AREAS, appDefaults.hide_final_areas),
                            hide_edges: that.dialog.getSetting(SETTING_KEY_OPTION_HIDE_EDGES, appDefaults.hide_edges),
                            minimize_on_highlight: that.dialog.getSetting(SETTING_KEY_OPTION_MINIMIZE_ON_HIGHLIGHT, appDefaults.minimize_on_highlight),
                            part_order_strategy: that.dialog.getSetting(SETTING_KEY_OPTION_PART_ORDER_STRATEGY, appDefaults.part_order_strategy),
                            dimension_column_order_strategy: that.dialog.getSetting(SETTING_KEY_OPTION_DIMENSION_COLUMN_ORDER_STRATEGY, appDefaults.dimension_column_order_strategy),
                            hidden_group_ids: that.dialog.getSetting(SETTING_KEY_OPTION_HIDDEN_GROUP_IDS, [])
                        };

                        // Callback
                        if (callback && typeof(callback) === 'function') {
                            callback();
                        }

                    }

                });

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
        var $inputHideTags = $('#ladb_input_hide_tags', $modal);
        var $inputHideCuttingDimensions = $('#ladb_input_hide_cutting_dimensions', $modal);
        var $inputHideBBoxDimensions = $('#ladb_input_hide_bbox_dimensions', $modal);
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
            $inputHideTags.prop('checked', generateOptions.hide_tags);
            $inputHideCuttingDimensions.prop('checked', generateOptions.hide_cutting_dimensions);
            $inputHideBBoxDimensions.prop('checked', generateOptions.hide_bbox_dimensions);
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
            $sortablePartOrderStrategy.sortable(SORTABLE_OPTIONS);

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

        // Bind buttons
        $btnReset.on('click', function () {
            $(this).blur();

            rubyCallCommand('core_get_app_defaults', { dictionary: 'cutlist_options' }, function (response) {

                if (response.errors && response.errors.length > 0) {
                    that.dialog.notifyErrors(response.errors);
                } else {

                    var appDefaults = response.defaults;

                    var generateOptions = $.extend($.extend({}, that.generateOptions), {
                        auto_orient: appDefaults.auto_orient,
                        smart_material: appDefaults.smart_material,
                        dynamic_attributes_name: appDefaults.dynamic_attributes_name,
                        part_number_with_letters: appDefaults.part_number_with_letters,
                        part_number_sequence_by_group: appDefaults.part_number_sequence_by_group,
                        part_folding: appDefaults.part_folding,
                        hide_entity_names: appDefaults.hide_entity_names,
                        hide_tags: appDefaults.hide_tags,
                        hide_cutting_dimensions: appDefaults.hide_cutting_dimensions,
                        hide_bbox_dimensions: appDefaults.hide_bbox_dimensions,
                        hide_final_areas: appDefaults.hide_final_areas,
                        hide_edges: appDefaults.hide_edges,
                        minimize_on_highlight: appDefaults.minimize_on_highlight,
                        part_order_strategy: appDefaults.part_order_strategy,
                        dimension_column_order_strategy: appDefaults.dimension_column_order_strategy
                    });
                    populateOptionsInputs(generateOptions);

                }

            });

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
            that.generateOptions.hide_tags = $inputHideTags.is(':checked');
            that.generateOptions.hide_cutting_dimensions = $inputHideCuttingDimensions.is(':checked');
            that.generateOptions.hide_bbox_dimensions = $inputHideBBoxDimensions.is(':checked');
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
            that.dialog.setSettings([
                { key:SETTING_KEY_OPTION_AUTO_ORIENT, value:that.generateOptions.auto_orient },
                { key:SETTING_KEY_OPTION_SMART_MATERIAL, value:that.generateOptions.smart_material },
                { key:SETTING_KEY_OPTION_DYNAMIC_ATTRIBUTES_NAME, value:that.generateOptions.dynamic_attributes_name },
                { key:SETTING_KEY_OPTION_PART_NUMBER_WITH_LETTERS, value:that.generateOptions.part_number_with_letters },
                { key:SETTING_KEY_OPTION_PART_NUMBER_SEQUENCE_BY_GROUP, value:that.generateOptions.part_number_sequence_by_group },
                { key:SETTING_KEY_OPTION_PART_FOLDING, value:that.generateOptions.part_folding },
                { key:SETTING_KEY_OPTION_HIDE_ENTITY_NAMES, value:that.generateOptions.hide_entity_names },
                { key:SETTING_KEY_OPTION_HIDE_TAGS, value:that.generateOptions.hide_tags },
                { key:SETTING_KEY_OPTION_HIDE_CUTTING_DIMENSIONS, value:that.generateOptions.hide_cutting_dimensions },
                { key:SETTING_KEY_OPTION_HIDE_BBOX_DIMENSIONS, value:that.generateOptions.hide_bbox_dimensions },
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
        this.dialog.setupPopovers();

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

    // Init /////

    LadbTabCutlist.prototype.registerCommands = function () {
        LadbAbstractTab.prototype.registerCommands.call(this);

        var that = this;

        this.registerCommand('generate_cutlist', function (parameters) {
            var callback = parameters ? parameters.callback : null;
            setTimeout(function () {     // Use setTimeout to give time to UI to refresh
                that.generateCutlist(callback);
            }, 1);
        });
        this.registerCommand('edit_part', function (parameters) {
            var partId = parameters.part_id;
            var partSerializedPath = parameters.part_serialized_path;
            var tab = parameters.tab;
            var dontGenerate = parameters.dontGenerate;
            setTimeout(function () {     // Use setTimeout to give time to UI to refresh
                if (dontGenerate) {
                    that.editPart(partId, partSerializedPath, tab);
                } else {
                    that.generateCutlist(function () {
                        that.editPart(partId, partSerializedPath, tab);
                    });
                }
            }, 1);
        });

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
        this.$btnReport.on('click', function () {
            that.reportCutlist();
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

    LadbTabCutlist.prototype.processInitializedCallback = function (initializedCallback) {
        var that = this;

        // Load Options
        this.loadOptions(function () {
            LadbAbstractTab.prototype.processInitializedCallback.call(that, initializedCallback);
        });

    };


    // PLUGIN DEFINITION
    // =======================

    function Plugin(option, params) {
        return this.each(function () {
            var $this = $(this);
            var data = $this.data('ladb.tab.plugin');
            var options = $.extend({}, LadbTabCutlist.DEFAULTS, $this.data(), typeof option == 'object' && option);

            if (!data) {
                if (undefined === options.dialog) {
                    throw 'dialog option is mandatory.';
                }
                $this.data('ladb.tab.plugin', (data = new LadbTabCutlist(this, options, options.dialog)));
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

+function ($) {
    'use strict';

    // CONSTANTS
    // ======================

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
        this.lastReportOptionsTab = null;
        this.lastCuttingdiagram1dOptionsTab = null;
        this.lastCuttingdiagram2dOptionsTab = null;
        this.lastLabelsOptionsTab = null;

        this.$header = $('.ladb-header', this.$element);
        this.$headerExtra = $('.ladb-header-extra', this.$header);
        this.$btnGenerate = $('#ladb_btn_generate', this.$header);
        this.$btnPrint = $('#ladb_btn_print', this.$header);
        this.$btnExport = $('#ladb_btn_export', this.$header);
        this.$btnReport = $('#ladb_btn_report', this.$header);
        this.$btnOptions = $('#ladb_btn_options', this.$header);
        this.$itemHighlightAllParts = $('#ladb_item_highlight_all_parts', this.$header);
        this.$itemShowAllGroups = $('#ladb_item_show_all_groups', this.$header);
        this.$itemNumbersSave = $('#ladb_item_numbers_save', this.$header);
        this.$itemNumbersReset = $('#ladb_item_numbers_reset', this.$header);
        this.$itemExpendAll = $('#ladb_item_expand_all', this.$header);
        this.$itemCollapseAll = $('#ladb_item_collapse_all', this.$header);

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
        this.popToRootSlide();

        rubyCallCommand('cutlist_generate', $.extend(this.generateOptions, this.generateFilters), function (response) {

            that.generateAt = new Date().getTime() / 1000;
            that.setObsolete(false);

            var errors = response.errors;
            var warnings = response.warnings;
            var tips = response.tips;
            var selectionOnly = response.selection_only;
            var lengthUnit = response.length_unit;
            var massUnitStrippedname = response.mass_unit_strippedname;
            var currencySymbol = response.currency_symbol;
            var filename = response.filename;
            var modelName = response.model_name;
            var pageLabel = response.page_label;
            var instanceCount = response.instance_count;
            var ignoredInstanceCount = response.ignored_instance_count;
            var usedTags = response.used_tags;
            var materialUsages = response.material_usages;
            var groups = response.groups;
            var solidWoodMaterialCount = response.solid_wood_material_count;
            var sheetGoodMaterialCount = response.sheet_good_material_count;
            var dimensionalMaterialCount = response.dimensional_material_count;
            var edgeMaterialCount = response.edge_material_count;
            var hardwareMaterialCount = response.hardware_material_count;

            // Keep usefull data
            that.filename = filename;
            that.modelName = modelName;
            that.pageLabel = pageLabel;
            that.lengthUnit = lengthUnit;
            that.currencySymbol = currencySymbol;
            that.massUnitStrippedname = massUnitStrippedname;
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
            that.$headerExtra.empty();
            that.$headerExtra.append(Twig.twig({ ref: "tabs/cutlist/_header-extra.twig" }).render({
                selectionOnly: selectionOnly,
                filename: filename,
                modelName: modelName,
                pageLabel: pageLabel,
                generateAt: that.generateAt,
                lengthUnit: lengthUnit
            }));

            // Hide help panel
            that.$panelHelp.hide();

            // Update buttons and items state
            that.$btnPrint.prop('disabled', groups.length === 0);
            that.$btnExport.prop('disabled', groups.length === 0);
            that.$btnReport.prop('disabled', solidWoodMaterialCount + sheetGoodMaterialCount + dimensionalMaterialCount + edgeMaterialCount + hardwareMaterialCount === 0);
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
                if (that.generateOptions.hidden_group_ids[i] == null || that.generateOptions.hidden_group_ids[i].endsWith('summary')) {
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
                that.saveUIOptionsHiddenGroupIds();
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
                that.dialog.executeCommandOnTab('settings', 'highlight_panel', { panel:'model' });
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

                // Flag to ignore next material change event
                that.ignoreNextMaterialEvents = true;

                var materialId = $(this).data('material-id');
                that.dialog.executeCommandOnTab('materials', 'edit_material', {
                    materialId: materialId,
                    updatedCallback: function () {

                        // Flag to stop ignoring next material change event
                        that.ignoreNextMaterialEvents = false;

                        // Refresh the list
                        that.dialog.executeCommandOnTab('cutlist', 'generate_cutlist');

                    }
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

                // Flag to ignore next material change event
                that.ignoreNextMaterialEvents = true;

                var $group = $(this).parents('.ladb-cutlist-group');
                var groupId = $group.data('group-id');
                var group = that.findGroupById(groupId);
                if (group) {
                    that.dialog.executeCommandOnTab('materials', 'edit_material', {
                        materialId: group.material_id,
                        updatedCallback: function () {

                            // Flag to stop ignoring next material change event
                            that.ignoreNextMaterialEvents = false;

                            // Refresh the list
                            that.dialog.executeCommandOnTab('cutlist', 'generate_cutlist');

                        }
                    });
                }
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
            $('a.ladb-item-show-all-groups', that.$page).on('click', function () {
                $(this).blur();
                that.showAllGroups();
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
            $('button.ladb-btn-group-labels', that.$page).on('click', function () {
                $(this).blur();
                var $group = $(this).parents('.ladb-cutlist-group');
                var groupId = $group.data('group-id');
                that.labelsGroup(groupId);
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
            $('a.ladb-btn-folding-toggle-row', that.$page).on('click', function () {
                $(this).blur();
                var $part = $(this).parents('.ladb-cutlist-row-folder');
                that.toggleFoldingRow($part);
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
            if (typeof callback === 'function') {
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

        var visibleOnly = this.generateOptions.hidden_group_ids.length > 0 && this.generateOptions.hidden_group_ids.indexOf('summary') === -1
            || this.generateOptions.hidden_group_ids.length > 1 && this.generateOptions.hidden_group_ids.indexOf('summary') >= 0;

        // Retrieve export option options
        rubyCallCommand('core_get_model_preset', { dictionary: 'cutlist_export_options' }, function (response) {

            var exportOptions = response.preset;

            var $modal = that.appendModalInside('ladb_cutlist_modal_export', 'tabs/cutlist/_modal-export.twig', {
                visible_only: visibleOnly
            });

            // Fetch UI elements
            var $widgetPreset = $('.ladb-widget-preset', $modal);
            var $selectSource = $('#ladb_cutlist_export_select_source', $modal);
            var $selectColSep = $('#ladb_cutlist_export_select_col_sep', $modal);
            var $selectEncoding = $('#ladb_cutlist_export_select_encoding', $modal);
            var $sortableColumnOrderSummary = $('#ladb_sortable_column_order_summary', $modal);
            var $sortableColumnOrderCutlist = $('#ladb_sortable_column_order_cutlist', $modal);
            var $sortableColumnOrderInstancesList = $('#ladb_sortable_column_order_instances_list', $modal);
            var $btnSetupModelUnits = $('#ladb_btn_setup_model_units', $modal);
            var $btnExport = $('#ladb_cutlist_export_btn_export', $modal);

            // Define useful functions

            var fnFillAndBindSorter = function ($sorter, colDefs) {

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
                    $('li:last-child .ladb-editor-formula', $sorter)
                        .ladbEditorFormula({
                            wordDefs: wordDefs
                        })
                        .ladbEditorFormula('setFormula', [ colDefs[i].formula ])
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
            var fnFetchOptions = function (options) {
                options.source = parseInt($selectSource.val());
                options.col_sep = parseInt($selectColSep.val());
                options.encoding = parseInt($selectEncoding.val());

                var fnFetchColumnDefs = function ($sorter) {
                    var columnDefs = [];
                    $sorter.children('li').each(function () {
                        columnDefs.push({
                            name: $(this).data('name'),
                            hidden: $(this).data('hidden'),
                            formula: $('.ladb-editor-formula', $(this)).ladbEditorFormula('getFormula'),
                        });
                    });
                    return columnDefs;
                }
                if (options.coldefs == null) {
                    options.coldefs = [];
                }
                options.coldefs[0] = fnFetchColumnDefs($sortableColumnOrderSummary);
                options.coldefs[1] = fnFetchColumnDefs($sortableColumnOrderCutlist);
                options.coldefs[2] = fnFetchColumnDefs($sortableColumnOrderInstancesList);

            }
            var fnFillInputs = function (options) {
                $selectSource.selectpicker('val', options.source);
                $selectColSep.selectpicker('val', options.col_sep);
                $selectEncoding.selectpicker('val', options.encoding);
                fnFillAndBindSorter($sortableColumnOrderSummary, options.coldefs[0]);
                fnFillAndBindSorter($sortableColumnOrderCutlist, options.coldefs[1]);
                fnFillAndBindSorter($sortableColumnOrderInstancesList, options.coldefs[2]);
                fnComputeSorterVisibility(options.source);
            }

            $widgetPreset.ladbWidgetPreset({
                dialog: that.dialog,
                dictionary: 'cutlist_export_options',
                fnFetchOptions: fnFetchOptions,
                fnFillInputs: fnFillInputs
            });
            $selectSource.selectpicker(SELECT_PICKER_OPTIONS);
            $selectColSep.selectpicker(SELECT_PICKER_OPTIONS);
            $selectEncoding.selectpicker(SELECT_PICKER_OPTIONS);

            fnFillInputs(exportOptions);

            // Bind select
            $selectSource.on('change', function () {
                fnComputeSorterVisibility($(this).val());
            });

            // Bind buttons
            $btnSetupModelUnits.on('click', function () {
                $(this).blur();
                that.dialog.executeCommandOnTab('settings', 'highlight_panel', { panel:'model' });
            });
            $btnExport.on('click', function () {

                // Fetch options
                fnFetchOptions(exportOptions);

                // Store options
                rubyCallCommand('core_set_model_preset', { dictionary: 'cutlist_export_options', values: exportOptions });

                rubyCallCommand('cutlist_export', $.extend(exportOptions, { col_defs: exportOptions.coldefs[exportOptions.source] }, that.generateOptions), function (response) {

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

        });

    };

    LadbTabCutlist.prototype.reportCutlist = function (forceDefaultTab) {
        var that = this;

        var visibleOnly = this.generateOptions.hidden_group_ids.length > 0 && this.generateOptions.hidden_group_ids.indexOf('summary') === -1
            || this.generateOptions.hidden_group_ids.length > 1 && this.generateOptions.hidden_group_ids.indexOf('summary') >= 0;

        // Retrieve label options
        rubyCallCommand('core_get_model_preset', { dictionary: 'cutlist_report_options' }, function (response) {

            var reportOptions = response.preset;

            var $modal = that.appendModalInside('ladb_cutlist_modal_report', 'tabs/cutlist/_modal-report.twig', {
                visible_only: visibleOnly,
                tab: forceDefaultTab || that.lastReportOptionsTab == null ? 'general' : that.lastReportOptionsTab,
            }, true);

            // Fetch UI elements
            var $widgetPreset = $('.ladb-widget-preset', $modal);
            var $inputSolidWoodCoefficient = $('#ladb_input_solid_wood_coefficient', $modal);
            var $btnSetupModelUnits = $('#ladb_btn_setup_model_units', $modal);
            var $btnGenerate = $('#ladb_btn_generate', $modal);

            var fnFetchOptions = function (options) {
                options.solid_wood_coefficient = Math.max(1.0, $inputSolidWoodCoefficient.val() === '' ? 1.0 : parseFloat($inputSolidWoodCoefficient.val().replace(',', '.')));
            }
            var fnFillInputs = function (options) {
                $inputSolidWoodCoefficient.val(options.solid_wood_coefficient);
            }

            $widgetPreset.ladbWidgetPreset({
                dialog: that.dialog,
                dictionary: 'cutlist_report_options',
                fnFetchOptions: fnFetchOptions,
                fnFillInputs: fnFillInputs
            });
            $inputSolidWoodCoefficient.ladbTextinputNumberWithUnit({
                resetValue: '1'
            });

            fnFillInputs(reportOptions);

            // Bind buttons
            $btnSetupModelUnits.on('click', function () {
                $(this).blur();
                that.dialog.executeCommandOnTab('settings', 'highlight_panel', { panel:'model' });
            });
            $btnGenerate.on('click', function () {

                // Fetch options
                fnFetchOptions(reportOptions);

                // Store options
                rubyCallCommand('core_set_model_preset', {dictionary: 'cutlist_report_options', values: reportOptions });

                // Generate report
                that.generateReportCutlist(reportOptions);

                // Hide modal
                $modal.modal('hide');

            });

            // Show modal
            $modal.modal('show');

            // Setup popovers
            that.dialog.setupPopovers();

        });

    };

    LadbTabCutlist.prototype.generateReportCutlist = function (reportOptions, callback) {
        var that = this;

        var fnAdvance = function () {
            window.requestAnimationFrame(function () {
                rubyCallCommand('cutlist_report_advance', null, function (response) {

                    if (response.remaining_step === 0 || response.remaining_step === undefined) {

                        window.requestAnimationFrame(function () {

                            var $slide = that.pushNewSlide('ladb_cutlist_slide_report', 'tabs/cutlist/_slide-report.twig', $.extend({
                                errors: response.errors,
                                filename: that.filename,
                                modelName: that.modelName,
                                pageLabel: that.pageLabel,
                                lengthUnit: that.lengthUnit,
                                generatedAt: new Date().getTime() / 1000,
                                report: response
                            }, reportOptions), function () {

                                that.dialog.setupTooltips();

                                // Callback
                                if (typeof callback === 'function') {
                                    callback();
                                }

                            });

                            // Fetch UI elements
                            var $btnReport = $('#ladb_btn_report', $slide);
                            var $btnPrint = $('#ladb_btn_print', $slide);
                            var $btnClose = $('#ladb_btn_close', $slide);

                            // Bind buttons
                            $btnReport.on('click', function () {
                                that.reportCutlist();
                            });
                            $btnPrint.on('click', function () {
                                window.print();
                            });
                            $btnClose.on('click', function () {
                                that.popSlide();
                            });
                            $('.ladb-btn-setup-model-units', $slide).on('click', function() {
                                $(this).blur();
                                that.dialog.executeCommandOnTab('settings', 'highlight_panel', { panel:'model' });
                            });
                            $('.ladb-btn-toggle-no-print', $slide).on('click', function () {
                                var $group = $(this).parents('.ladb-cutlist-group');
                                if ($group.hasClass('no-print')) {
                                    that.showGroup($group, true);
                                } else {
                                    that.hideGroup($group, true);
                                }
                                $(this).blur();
                            });
                            $('a.ladb-btn-folding-toggle-row', $slide).on('click', function () {
                                $(this).blur();
                                var $row = $(this).parents('.ladb-cutlist-row-folder');
                                that.toggleFoldingRow($row, 'entry-id');
                                return false;
                            });
                            $('.ladb-cutlist-row', $slide).on('click', function () {
                                $(this).blur();
                                $('.ladb-click-tool', $(this)).first().click();
                                return false;
                            });
                            $('a.ladb-item-hide-all-other-groups', $slide).on('click', function () {
                                $(this).blur();
                                var $group = $(this).parents('.ladb-cutlist-group');
                                var groupId = $group.data('group-id');
                                that.hideAllGroups(groupId, $slide, true);
                                that.scrollSlideToTarget($slide, $group, true, false);
                            });
                            $('a.ladb-item-show-all-groups', $slide).on('click', function () {
                                $(this).blur();
                                that.showAllGroups($slide, true);
                            });
                            $('#ladb_item_expand_all', $slide).on('click', function () {
                                $(this).blur();
                                that.expandAllFoldingRows($slide, 'entry-id');
                            });
                            $('#ladb_item_collapse_all', $slide).on('click', function () {
                                $(this).blur();
                                that.collapseAllFoldingRows($slide, 'entry-id');
                            });
                            $('a.ladb-btn-edit-material', $slide).on('click', function () {
                                $(this).blur();

                                // Flag to ignore next material change event
                                that.ignoreNextMaterialEvents = true;

                                var materialId = $(this).data('material-id');
                                that.dialog.executeCommandOnTab('materials', 'edit_material', {
                                    materialId: materialId,
                                    propertiesTab: 'attributes',
                                    updatedCallback: function () {

                                        // Flag to stop ignoring next material change event
                                        that.ignoreNextMaterialEvents = false;

                                        // Refresh the list
                                        that.dialog.executeCommandOnTab('cutlist', 'generate_cutlist', {
                                            callback: function () {
                                                that.generateReportCutlist(reportOptions);
                                            }
                                        });

                                    }
                                });
                                return false;
                            });
                            $('a.ladb-btn-cuttingdiagram-1d', $slide).on('click', function () {
                                $(this).blur();
                                var groupId = $(this).data('group-id');
                                that.cuttingdiagram1dGroup(groupId, true, function () {
                                    that.generateReportCutlist(reportOptions);
                                });
                                return false;
                            });
                            $('a.ladb-btn-cuttingdiagram-2d', $slide).on('click', function () {
                                $(this).blur();
                                var groupId = $(this).data('group-id');
                                that.cuttingdiagram2dGroup(groupId, true, function () {
                                    that.generateReportCutlist(reportOptions);
                                });
                                return false;
                            });
                            $('a.ladb-btn-highlight-part', $slide).on('click', function () {
                                $(this).blur();
                                var partId = $(this).data('part-id');
                                that.highlightPart(partId);
                                return false;
                            });
                            $('a.ladb-btn-edit-part', $slide).on('click', function () {
                                $(this).blur();
                                var partId = $(this).data('part-id');
                                that.editPart(partId, undefined, undefined, function () {

                                    // Refresh the list
                                    that.dialog.executeCommandOnTab('cutlist', 'generate_cutlist', {
                                        callback: function () {
                                            that.generateReportCutlist(reportOptions);
                                        }
                                    });

                                });
                                return false;
                            });

                            that.dialog.finishProgress();

                        });

                    } else {

                        window.requestAnimationFrame(function () {
                            that.dialog.advanceProgress(1);
                        });

                        fnAdvance();
                    }

                });
            });
        }

        window.requestAnimationFrame(function () {
            rubyCallCommand('cutlist_report_start', $.extend(reportOptions, that.generateOptions), function (response) {
                window.requestAnimationFrame(function () {
                    that.dialog.startProgress(response.remaining_step);
                    fnAdvance();
                });
            });
        });

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
        var that = this;
        var $group = $('#ladb_group_' + id, this.$page);
        var defs = [ 'cuttingdiagram1d', 'cuttingdiagram2d', 'labels' ];
        $.each(defs, function () {
            var $btn = $('button.ladb-btn-group-' + this, $group);
            var $i = $('i', $btn);
            var clazz = 'ladb-opencutlist-icon-' + this + '-selection';
            var doEffet = false;
            if (that.selectionPartIds.length > 0) {
                doEffet = !$i.hasClass(clazz);
                $i.addClass(clazz);
            } else {
                doEffet = $i.hasClass(clazz);
                $i.removeClass(clazz);
            }
            if (doEffet) {
                $btn.effect('highlight', {}, 1500);
            }
        });
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
        if (this.selectionGroupId) {
            this.renderSelectionOnGroup(this.selectionGroupId);
        }
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

    LadbTabCutlist.prototype.editPart = function (id, serializedPath, tab, updatedCallback) {
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
                if (editedPart.instance_count_by_part !== editedParts[i].instance_count_by_part) {
                    editedPart.instance_count_by_part = MULTIPLE_VALUE;
                }
                if (editedPart.mass !== editedParts[i].mass) {
                    editedPart.mass = MULTIPLE_VALUE;
                }
                if (editedPart.price !== editedParts[i].price) {
                    editedPart.price = MULTIPLE_VALUE;
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
                var $inputInstanceCountByPart = $('#ladb_cutlist_part_input_instance_count_by_part', $modal);
                var $inputMass = $('#ladb_cutlist_part_input_mass', $modal);
                var $inputPrice = $('#ladb_cutlist_part_input_price', $modal);
                var $inputTags = $('#ladb_cutlist_part_input_tags', $modal);
                var $inputOrientationLockedOnAxis = $('#ladb_cutlist_part_input_orientation_locked_on_axis', $modal);
                var $inputSymmetrical = $('#ladb_cutlist_part_input_symmetrical', $modal);
                var $inputPartAxes = $('#ladb_cutlist_part_input_axes', $modal);
                var $sortableAxes = $('#ladb_sortable_axes', $modal);
                var $sortablePartAxes = $('#ladb_sortable_part_axes', $modal);
                var $sortablePartAxesExtra = $('#ladb_sortable_part_axes_extra', $modal);
                var $selectPartAxesOriginPosition = $('#ladb_cutlist_part_select_axes_origin_position', $modal);
                var $inputLengthIncrease = $('#ladb_cutlist_part_input_length_increase', $modal);
                var $inputWidthIncrease = $('#ladb_cutlist_part_input_width_increase', $modal);
                var $inputThicknessIncrease = $('#ladb_cutlist_part_input_thickness_increase', $modal);
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
                var $btnExportToSkp = $('#ladb_cutlist_part_export_to_skp', $modal);
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
                var fnOnAxiesOrderChanged = function () {
                    var axes = fnComputeAxesOrder();

                    var oriented = editedPart.normals_to_values[axes[0]] >= editedPart.normals_to_values[axes[1]]
                        &&  editedPart.normals_to_values[axes[1]] >= editedPart.normals_to_values[axes[2]];

                    // Check Orientation Locked On Axis option if needed
                    $inputOrientationLockedOnAxis.prop('checked', !oriented);
                    fnDisplayAxisDimensions();

                    // By default set origin position to 'min'
                    $selectPartAxesOriginPosition
                        .selectpicker('val', 'min')
                        .trigger('change')
                    ;

                }

                fnDisplayAxisDimensions();
                fnUpdateIncreasesPreview();

                // Bind tabs
                $tabs.on('shown.bs.tab', function (e) {
                    that.lastEditPartTab = $(e.target).attr('href').substring('#tab_edit_part_'.length);
                })

                // Bind input
                $inputInstanceCountByPart.ladbTextinputNumberWithUnit({
                    resetValue: '1',
                    defaultUnit: 'u_p',
                    units: [
                        { u_p: i18next.t('default.instance_plural') + ' / ' + i18next.t('default.part_single') },
                    ]
                });
                $inputMass.ladbTextinputNumberWithUnit({
                    defaultUnit: that.massUnitStrippedname + '_p',
                    units: [
                        { kg_p: 'kg / ' + i18next.t('default.part_single') },
                        { lb_p: 'lb / ' + i18next.t('default.part_single') }
                    ]
                });
                $inputPrice.ladbTextinputNumberWithUnit({
                    defaultUnit: '$_p',
                    units: [
                        { $_p: that.currencySymbol + ' / ' + i18next.t('default.part_single') }
                    ]
                });
                $inputLengthIncrease.on('change', function() {
                    fnUpdateIncreasesPreview();
                });
                $inputLengthIncrease.ladbTextinputDimension();
                $inputWidthIncrease.on('change', function() {
                    fnUpdateIncreasesPreview();
                });
                $inputWidthIncrease.ladbTextinputDimension();
                $inputThicknessIncrease.ladbTextinputDimension();

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
                $sortableAxes.on('dblclick', function () {
                   var sortedNormals = Object.keys(editedPart.normals_to_values).sort(function (a, b) {
                       return editedPart.normals_to_values[b] - editedPart.normals_to_values[a]
                   });
                   var $rowX = $('li[data-axis="' + sortedNormals[0] + '"]', $sortablePartAxes);
                   var $rowY = $('li[data-axis="' + sortedNormals[1] + '"]', $sortablePartAxes);
                   var $rowZ = $('li[data-axis="' + sortedNormals[2] + '"]', $sortablePartAxes);
                    $rowY.insertBefore($rowZ);
                    $rowX.insertBefore($rowY);
                    fnOnAxiesOrderChanged();
                });
                $sortablePartAxes.sortable({
                    cursor: 'ns-resize',
                    handle: '.ladb-handle',
                    stop: fnOnAxiesOrderChanged
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
                $btnExportToSkp.on('click', function () {
                    this.blur();
                    rubyCallCommand('cutlist_part_export_to_skp', {
                        definition_id: part.definition_id
                    }, function (response) {

                        if (response.errors) {
                            that.dialog.notifyErrors(response.errors);
                        }
                        if (response.export_path) {
                            that.dialog.notify(i18next.t('tab.cutlist.success.exported_to', { export_path: response.export_path }), 'success');
                        }

                    });
                    return false;
                });
                $btnUpdate.on('click', function () {

                    for (var i = 0; i < editedParts.length; i++) {

                        if (!multiple) {

                            editedParts[i].name = $inputName.val();

                            editedParts[i].orientation_locked_on_axis = $inputOrientationLockedOnAxis.is(':checked');
                            editedParts[i].symmetrical = $inputSymmetrical.is(':checked');
                            editedParts[i].axes_order = $inputPartAxes.val().length > 0 ? $inputPartAxes.val().split(',') : [];
                            editedParts[i].axes_origin_position = $selectPartAxesOriginPosition.val();

                        }

                        if ($selectMaterialName.val() !== MULTIPLE_VALUE) {
                            editedParts[i].material_name = $selectMaterialName.val();
                        }
                        if ($selectCumulable.val() !== MULTIPLE_VALUE) {
                            editedParts[i].cumulable = parseInt($selectCumulable.val());
                        }
                        if ($inputInstanceCountByPart.val() !== undefined && $inputInstanceCountByPart.val() !== '') {
                            editedParts[i].instance_count_by_part = Math.max(1, $inputInstanceCountByPart.val() === '' ? 1 : parseInt($inputInstanceCountByPart.val()));
                        }
                        if ($inputMass.val() !== undefined && $inputMass.val() !== '') {
                            editedParts[i].mass = $inputMass.ladbTextinputNumberWithUnit('val');
                        }
                        if ($inputPrice.val() !== undefined && $inputPrice.val() !== '') {
                            editedParts[i].price = $inputPrice.val();
                        }

                        var untouchTags = editedParts[i].tags.filter(function (tag) { return !editedPart.tags.includes(tag) });
                        editedParts[i].tags = untouchTags.concat($inputTags.tokenfield('getTokensList').split(';'));

                        if ($inputLengthIncrease.val() !== undefined && $inputLengthIncrease.val() !== '') {
                            editedParts[i].length_increase = $inputLengthIncrease.val();
                        }
                        if ($inputWidthIncrease.val() !== undefined && $inputWidthIncrease.val() !== '') {
                            editedParts[i].width_increase = $inputWidthIncrease.val();
                        }
                        if ($inputThicknessIncrease.val() !== undefined && $inputThicknessIncrease.val() !== '') {
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

                            if (typeof updatedCallback === 'function') {
                                updatedCallback()
                            } else {

                                var partId = editedPart.id;
                                var wTop = $('#ladb_part_' + partId).offset().top - $(window).scrollTop();

                                // Refresh the list
                                that.generateCutlist(function () {

                                    // Try to scroll to the edited part's row
                                    var $part = $('#ladb_part_' + partId, that.$page);
                                    if ($part.length > 0) {
                                        if ($part.hasClass('hide')) {
                                            that.expandFoldingRow($('#ladb_part_' + $part.data('folder-id')));
                                        }
                                        $part.effect('highlight', {}, 1500);
                                        that.$rootSlide.animate({ scrollTop: $part.offset().top - wTop }, 0);
                                    }

                                });

                            }

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
                            source: that.usedTags.concat(that.generateOptions.tags).unique(),
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

                // Change event
                $('input, select', $modal).on('change', function () {
                    $btnExportToSkp.prop('disabled', true);
                });

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

    LadbTabCutlist.prototype.toggleFoldingRow = function ($row, dataKey) {
        var $btn = $('.ladb-btn-folding-toggle-row', $row);
        var $i = $('i', $btn);

        if ($i.hasClass('ladb-opencutlist-icon-arrow-down')) {
            this.expandFoldingRow($row, dataKey);
        } else {
            this.collapseFoldingRow($row, dataKey);
        }
    };

    LadbTabCutlist.prototype.expandFoldingRow = function ($row, dataKey) {
        var rowId = $row.data(dataKey ? dataKey : 'part-id');
        var $btn = $('.ladb-btn-folding-toggle-row', $row);
        var $i = $('i', $btn);

        $i.addClass('ladb-opencutlist-icon-arrow-up');
        $i.removeClass('ladb-opencutlist-icon-arrow-down');

        // Show children
        $row.siblings('tr[data-folder-id=' + rowId + ']').removeClass('hide');

    };

    LadbTabCutlist.prototype.collapseFoldingRow = function ($row, dataKey) {
        var rowId = $row.data(dataKey ? dataKey : 'part-id');
        var $btn = $('.ladb-btn-folding-toggle-row', $row);
        var $i = $('i', $btn);

        $i.addClass('ladb-opencutlist-icon-arrow-down');
        $i.removeClass('ladb-opencutlist-icon-arrow-up');

        // Hide children
        $row.siblings('tr[data-folder-id=' + rowId + ']').addClass('hide');

    };

    LadbTabCutlist.prototype.expandAllFoldingRows = function ($slide, dataKey) {
        var that = this;
        $('.ladb-cutlist-row-folder', $slide === undefined ? this.$page : $slide).each(function () {
            that.expandFoldingRow($(this), dataKey);
        });
    };

    LadbTabCutlist.prototype.collapseAllFoldingRows = function ($slide, dataKey) {
        var that = this;
        $('.ladb-cutlist-row-folder', $slide === undefined ? this.$page : $slide).each(function () {
            that.collapseFoldingRow($(this), dataKey);
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
        // TODO find a best way to save hidden IDs without saving all options
        rubyCallCommand('core_set_model_preset', { dictionary: 'cutlist_options', values: this.generateOptions });
    };

    LadbTabCutlist.prototype.showGroup = function ($group, doNotSaveState, doNotFlushSettings) {
        var groupId = $group.data('group-id');
        var $btn = $('.ladb-btn-toggle-no-print', $group);
        var $i = $('i', $btn);
        var $summaryRow = $('#' + $group.attr('id') + '_summary');

        $group.removeClass('no-print');
        $i.addClass('ladb-opencutlist-icon-eye-close');
        $i.removeClass('ladb-opencutlist-icon-eye-open');
        $summaryRow.removeClass('ladb-mute');

        if (doNotSaveState === undefined || !doNotSaveState) {
            var idx = this.generateOptions.hidden_group_ids.indexOf(groupId);
            if (idx !== -1) {
                this.generateOptions.hidden_group_ids.splice(idx, 1);
                if (doNotFlushSettings === undefined || !doNotFlushSettings) {
                    this.saveUIOptionsHiddenGroupIds();
                }
            }
        }

    };

    LadbTabCutlist.prototype.hideGroup = function ($group, doNotSaveState, doNotFlushSettings) {
        var groupId = $group.data('group-id');
        var $btn = $('.ladb-btn-toggle-no-print', $group);
        var $i = $('i', $btn);
        var $summaryRow = $('#' + $group.attr('id') + '_summary');

        $group.addClass('no-print');
        $i.removeClass('ladb-opencutlist-icon-eye-close');
        $i.addClass('ladb-opencutlist-icon-eye-open');
        $summaryRow.addClass('ladb-mute');

        if (doNotSaveState === undefined || !doNotSaveState) {
            var idx = this.generateOptions.hidden_group_ids.indexOf(groupId);
            if (idx === -1) {
                this.generateOptions.hidden_group_ids.push(groupId);
                if (doNotFlushSettings === undefined || !doNotFlushSettings) {
                    this.saveUIOptionsHiddenGroupIds();
                }
            }
        }

    };

    LadbTabCutlist.prototype.showAllGroups = function ($slide, doNotSaveState) {
        console.log('showAllGroups', $slide, doNotSaveState);
        var that = this;
        $('.ladb-cutlist-group', $slide === undefined ? this.$page : $slide).each(function () {
            that.showGroup($(this), doNotSaveState === undefined  ? false : doNotSaveState,true);
        }).promise().done( function (){
            that.saveUIOptionsHiddenGroupIds();
        });
    };

    LadbTabCutlist.prototype.hideAllGroups = function (exceptedGroupId, $slide, doNotSaveState) {
        console.log('hideAllGroups', exceptedGroupId, $slide, doNotSaveState);
        var that = this;
        $('.ladb-cutlist-group', $slide === undefined ? this.$page : $slide).each(function () {
            var groupId = $(this).data('group-id');
            if (exceptedGroupId && groupId !== exceptedGroupId) {
                that.hideGroup($(this), doNotSaveState === undefined  ? false : doNotSaveState,true);
            }
        }).promise().done( function (){
            if (!doNotSaveState) {
                that.saveUIOptionsHiddenGroupIds();
            }
        });
    };

    LadbTabCutlist.prototype.cuttingdiagram1dGroup = function (groupId, forceDefaultTab, generateCallback) {
        var that = this;

        var group = this.findGroupById(groupId);
        var selectionOnly = this.selectionGroupId === groupId && this.selectionPartIds.length > 0;

        // Retrieve cutting diagram options
        rubyCallCommand('core_get_model_preset', { dictionary: 'cutlist_cuttingdiagram1d_options', section: groupId }, function (response) {

            var cuttingdiagram1dOptions = response.preset;

            rubyCallCommand('materials_get_attributes_command', { name: group.material_name }, function (response) {

                var $modal = that.appendModalInside('ladb_cutlist_modal_cuttingdiagram_1d', 'tabs/cutlist/_modal-cuttingdiagram-1d.twig', {
                    material_attributes: response,
                    group: group,
                    selection_only: selectionOnly,
                    tab: forceDefaultTab || that.lastCuttingdiagram1dOptionsTab == null ? 'material' : that.lastCuttingdiagram1dOptionsTab
                }, true);

                // Fetch UI elements
                var $tabs = $('a[data-toggle="tab"]', $modal);
                var $widgetPreset = $('.ladb-widget-preset', $modal);
                var $inputStdBar = $('#ladb_select_std_bar', $modal);
                var $inputScrapBarLengths = $('#ladb_input_scrap_bar_lengths', $modal);
                var $inputSawKerf = $('#ladb_input_saw_kerf', $modal);
                var $inputTrimming = $('#ladb_input_trimming', $modal);
                var $selectBarFolding = $('#ladb_select_bar_folding', $modal);
                var $selectHidePartList = $('#ladb_select_hide_part_list', $modal);
                var $selectFullWidthDiagram = $('#ladb_select_full_width_diagram', $modal);
                var $selectHideCross = $('#ladb_select_hide_cross', $modal);
                var $selectOriginCorner = $('#ladb_select_origin_corner', $modal);
                var $inputWrapLength = $('#ladb_input_wrap_length', $modal);
                var $btnEditMaterial = $('#ladb_btn_edit_material', $modal);
                var $btnGenerate = $('#ladb_btn_generate', $modal);

                var fnFetchOptions = function (options) {
                    options.std_bar = $inputStdBar.val();
                    options.scrap_bar_lengths = $inputScrapBarLengths.ladbTextinputTokenfield('getValidTokensList');
                    options.saw_kerf = $inputSawKerf.val();
                    options.trimming = $inputTrimming.val();
                    options.bar_folding = $selectBarFolding.val() === '1';
                    options.hide_part_list = $selectHidePartList.val() === '1';
                    options.full_width_diagram = $selectFullWidthDiagram.val() === '1';
                    options.hide_cross = $selectHideCross.val() === '1';
                    options.origin_corner = parseInt($selectOriginCorner.val());
                    options.wrap_length = $inputWrapLength.val();
                }
                var fnFillInputs = function (options) {
                    $inputSawKerf.val(options.saw_kerf);
                    $inputTrimming.val(options.trimming);
                    $selectBarFolding.selectpicker('val', options.bar_folding ? '1' : '0');
                    $selectHidePartList.selectpicker('val', options.hide_part_list ? '1' : '0');
                    $selectFullWidthDiagram.selectpicker('val', options.full_width_diagram ? '1' : '0');
                    $selectHideCross.selectpicker('val', options.hide_cross ? '1' : '0');
                    $selectOriginCorner.selectpicker('val', options.origin_corner);
                    $inputWrapLength.val(options.wrap_length);
                }
                var fnEditMaterial = function (callback) {

                    // Hide modal
                    $modal.modal('hide');

                    // Edit material and focus std_sizes input field
                    that.dialog.executeCommandOnTab('materials', 'edit_material', {
                        materialId: group.material_id,
                        propertiesTab: 'cut_options',
                        callback: callback
                    });

                };

                $widgetPreset.ladbWidgetPreset({
                    dialog: that.dialog,
                    dictionary: 'cutlist_cuttingdiagram1d_options',
                    fnFetchOptions: fnFetchOptions,
                    fnFillInputs: fnFillInputs
                });
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
                $inputStdBar.selectpicker(SELECT_PICKER_OPTIONS);
                $inputScrapBarLengths.ladbTextinputTokenfield({ format: 'dxq' });
                $inputScrapBarLengths.ladbTextinputTokenfield('setTokens', cuttingdiagram1dOptions.scrap_bar_lengths);
                $inputSawKerf.ladbTextinputDimension();
                $inputTrimming.ladbTextinputDimension();
                $selectBarFolding.selectpicker(SELECT_PICKER_OPTIONS);
                $selectHidePartList.selectpicker(SELECT_PICKER_OPTIONS);
                $selectFullWidthDiagram.selectpicker(SELECT_PICKER_OPTIONS);
                $selectHideCross.selectpicker(SELECT_PICKER_OPTIONS);
                $selectOriginCorner.selectpicker(SELECT_PICKER_OPTIONS);
                $inputWrapLength.ladbTextinputDimension();

                fnFillInputs(cuttingdiagram1dOptions);

                // Bind tabs
                $tabs.on('shown.bs.tab', function (e) {
                    that.lastCuttingdiagram1dOptionsTab = $(e.target).attr('href').substring('#tab_cuttingdiagram_options_'.length);
                })

                // Bind select
                $inputStdBar.on('changed.bs.select', function () {
                    var value = $inputStdBar.val();
                    if (value === 'add') {
                        fnEditMaterial(function ($editMaterialModal) {
                            $('#ladb_materials_input_std_lengths', $editMaterialModal).siblings('.token-input').focus();
                        });
                    }
                });

                // Bind buttons
                $btnEditMaterial.on('click', function () {
                    fnEditMaterial();
                });
                $btnGenerate.on('click', function () {

                    // Fetch options
                    fnFetchOptions(cuttingdiagram1dOptions);

                    // Store options
                    rubyCallCommand('core_set_model_preset', { dictionary: 'cutlist_cuttingdiagram1d_options', values: cuttingdiagram1dOptions, section: groupId });

                    if (typeof generateCallback === 'function') {
                        generateCallback();
                    } else {
                        rubyCallCommand('cutlist_group_cuttingdiagram_1d', $.extend({group_id: groupId, part_ids: selectionOnly ? that.selectionPartIds : null}, cuttingdiagram1dOptions, that.generateOptions), function (response) {

                            var $slide = that.pushNewSlide('ladb_cutlist_slide_cuttingdiagram_1d', 'tabs/cutlist/_slide-cuttingdiagram-1d.twig', $.extend({
                                generateOptions: that.generateOptions,
                                dimensionColumnOrderStrategy: that.generateOptions.dimension_column_order_strategy.split('>'),
                                filename: that.filename,
                                modelName: that.modelName,
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
                                that.cuttingdiagram1dGroup(groupId);
                            });
                            $btnPrint.on('click', function () {
                                window.print();
                            });
                            $btnLabels.on('click', function () {
                                that.labelsGroup(groupId);
                            });
                            $btnClose.on('click', function () {
                                that.popSlide();
                            });
                            $('.ladb-btn-setup-model-units', $slide).on('click', function () {
                                $(this).blur();
                                that.dialog.executeCommandOnTab('settings', 'highlight_panel', { panel:'model' });
                            });
                            $('.ladb-btn-toggle-no-print', $slide).on('click', function () {
                                var $group = $(this).parents('.ladb-cutlist-group');
                                if ($group.hasClass('no-print')) {
                                    that.showGroup($group, true);
                                } else {
                                    that.hideGroup($group, true);
                                }
                                $(this).blur();
                            });
                            $('.ladb-btn-scrollto-prev-group', $slide).on('click', function () {
                                var $group = $(this).parents('.ladb-cutlist-group');
                                var groupId = $group.data('bar-index');
                                var $target = $('.ladb-cuttingdiagram-group[data-bar-index=' + (parseInt(groupId) - 1) + ']');
                                $slide.animate({scrollTop: $slide.scrollTop() + $target.position().top - $('.ladb-header', $slide).outerHeight(true) - 20}, 200).promise().then(function () {
                                    $target.effect('highlight', {}, 1500);
                                });
                                $(this).blur();
                                return false;
                            });
                            $('.ladb-btn-scrollto-next-group', $slide).on('click', function () {
                                var $group = $(this).parents('.ladb-cutlist-group');
                                var groupId = $group.data('bar-index');
                                var $target = $('.ladb-cuttingdiagram-group[data-bar-index=' + (parseInt(groupId) + 1) + ']');
                                $slide.animate({scrollTop: $slide.scrollTop() + $target.position().top - $('.ladb-header', $slide).outerHeight(true) - 20}, 200).promise().then(function () {
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
                                    that.showGroup($target, false);
                                }
                                $slide.animate({scrollTop: $slide.scrollTop() + $target.position().top - $('.ladb-header', $slide).outerHeight(true) - 20}, 200).promise().then(function () {
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
                    }
                    
                    // Hide modal
                    $modal.modal('hide');

                });

                // Show modal
                $modal.modal('show');

                // Setup popovers
                that.dialog.setupPopovers();

            });


        });

    };

    LadbTabCutlist.prototype.cuttingdiagram2dGroup = function (groupId, forceDefaultTab, generateCallback) {
        var that = this;

        var group = this.findGroupById(groupId);
        var selectionOnly = this.selectionGroupId === groupId && this.selectionPartIds.length > 0;

        // Retrieve cutting diagram options
        rubyCallCommand('core_get_model_preset', { dictionary: 'cutlist_cuttingdiagram2d_options', section: groupId }, function (response) {

            var cuttingdiagram2dOptions = response.preset;

            rubyCallCommand('materials_get_attributes_command', { name: group.material_name }, function (response) {

                var $modal = that.appendModalInside('ladb_cutlist_modal_cuttingdiagram_2d', 'tabs/cutlist/_modal-cuttingdiagram-2d.twig', {
                    material_attributes: response,
                    group: group,
                    selection_only: selectionOnly,
                    tab: forceDefaultTab || that.lastCuttingdiagram2dOptionsTab == null ? 'material' : that.lastCuttingdiagram2dOptionsTab
                }, true);

                // Fetch UI elements
                var $tabs = $('a[data-toggle="tab"]', $modal);
                var $widgetPreset = $('.ladb-widget-preset', $modal);
                var $inputStdSheet = $('#ladb_select_std_sheet', $modal);
                var $inputScrapSheetSizes = $('#ladb_input_scrap_sheet_sizes', $modal);
                var $inputSawKerf = $('#ladb_input_saw_kerf', $modal);
                var $inputTrimming = $('#ladb_input_trimming', $modal);
                var $selectOptimization = $('#ladb_select_optimization', $modal);
                var $selectStacking = $('#ladb_select_stacking', $modal);
                var $selectSheetFolding = $('#ladb_select_sheet_folding', $modal);
                var $selectHidePartList = $('#ladb_select_hide_part_list', $modal);
                var $selectFullWidthDiagram = $('#ladb_select_full_width_diagram', $modal);
                var $selectHideCross = $('#ladb_select_hide_cross', $modal);
                var $selectOriginCorner = $('#ladb_select_origin_corner', $modal);
                var $selectHighlightPrimaryCuts = $('#ladb_select_highlight_primary_cuts', $modal);
                var $btnEditMaterial = $('#ladb_btn_edit_material', $modal);
                var $btnGenerate = $('#ladb_btn_generate', $modal);

                var fnFetchOptions = function (options) {
                    options.std_sheet = $inputStdSheet.val();
                    options.scrap_sheet_sizes = $inputScrapSheetSizes.ladbTextinputTokenfield('getValidTokensList');
                    options.saw_kerf = $inputSawKerf.val();
                    options.trimming = $inputTrimming.val();
                    options.optimization = parseInt($selectOptimization.val());
                    options.stacking = parseInt($selectStacking.val());
                    options.sheet_folding = $selectSheetFolding.val() === '1';
                    options.hide_part_list = $selectHidePartList.val() === '1';
                    options.full_width_diagram = $selectFullWidthDiagram.val() === '1';
                    options.hide_cross = $selectHideCross.val() === '1';
                    options.origin_corner = parseInt($selectOriginCorner.val());
                    options.highlight_primary_cuts = $selectHighlightPrimaryCuts.val() === '1';
                }
                var fnFillInputs = function (options) {
                    $inputSawKerf.val(options.saw_kerf);
                    $inputTrimming.val(options.trimming);
                    $selectOptimization.selectpicker('val', options.optimization);
                    $selectStacking.selectpicker('val', options.stacking);
                    $selectSheetFolding.selectpicker('val', options.sheet_folding ? '1' : '0');
                    $selectHidePartList.selectpicker('val', options.hide_part_list ? '1' : '0');
                    $selectFullWidthDiagram.selectpicker('val', options.full_width_diagram ? '1' : '0');
                    $selectHideCross.selectpicker('val', options.hide_cross ? '1' : '0');
                    $selectOriginCorner.selectpicker('val', options.origin_corner);
                    $selectHighlightPrimaryCuts.selectpicker('val', options.highlight_primary_cuts ? '1' : '0');
                }
                var fnEditMaterial = function (callback) {

                    // Hide modal
                    $modal.modal('hide');

                    // Edit material and focus std_sizes input field
                    that.dialog.executeCommandOnTab('materials', 'edit_material', {
                        materialId: group.material_id,
                        propertiesTab: 'cut_options',
                        callback: callback
                    });

                };

                $widgetPreset.ladbWidgetPreset({
                    dialog: that.dialog,
                    dictionary: 'cutlist_cuttingdiagram2d_options',
                    fnFetchOptions: fnFetchOptions,
                    fnFillInputs: fnFillInputs
                });
                if (cuttingdiagram2dOptions.std_sheet) {
                    var defaultValue = $inputStdSheet.val();
                    $inputStdSheet.val(cuttingdiagram2dOptions.std_sheet);
                    if ($inputStdSheet.val() == null) {
                        if (response.std_sizes.length === 0) {
                            $inputStdSheet.val('0x0');  // Special case if the std_sheet is not present anymore in the list and no std size defined. Select "none" by default.
                        } else {
                            $inputStdSheet.val(defaultValue);
                        }
                    }
                }
                $inputStdSheet.selectpicker(SELECT_PICKER_OPTIONS);
                $inputScrapSheetSizes.ladbTextinputTokenfield({ format: 'dxdxq' });
                $inputScrapSheetSizes.ladbTextinputTokenfield('setTokens', cuttingdiagram2dOptions.scrap_sheet_sizes);
                $inputSawKerf.ladbTextinputDimension();
                $inputTrimming.ladbTextinputDimension();
                $selectOptimization.selectpicker(SELECT_PICKER_OPTIONS);
                $selectStacking.selectpicker(SELECT_PICKER_OPTIONS);
                $selectSheetFolding.selectpicker(SELECT_PICKER_OPTIONS);
                $selectHidePartList.selectpicker(SELECT_PICKER_OPTIONS);
                $selectFullWidthDiagram.selectpicker(SELECT_PICKER_OPTIONS);
                $selectHideCross.selectpicker(SELECT_PICKER_OPTIONS);
                $selectOriginCorner.selectpicker(SELECT_PICKER_OPTIONS);
                $selectHighlightPrimaryCuts.selectpicker(SELECT_PICKER_OPTIONS);

                fnFillInputs(cuttingdiagram2dOptions);

                // Bind tabs
                $tabs.on('shown.bs.tab', function (e) {
                    that.lastCuttingdiagram2dOptionsTab = $(e.target).attr('href').substring('#tab_cuttingdiagram_options_'.length);
                })

                // Bind select
                $inputStdSheet.on('changed.bs.select', function () {
                    var value = $inputStdSheet.val();
                    if (value === 'add') {
                        fnEditMaterial(function ($editMaterialModal) {
                            $('#ladb_materials_input_std_sizes', $editMaterialModal).siblings('.token-input').focus();
                        });
                    }
                });

                // Bind buttons
                $btnEditMaterial.on('click', function () {
                    fnEditMaterial();
                });
                $btnGenerate.on('click', function () {

                    // Fetch options
                    fnFetchOptions(cuttingdiagram2dOptions);

                    // Store options
                    rubyCallCommand('core_set_model_preset', { dictionary: 'cutlist_cuttingdiagram2d_options', values: cuttingdiagram2dOptions, section: groupId });

                    if (typeof generateCallback === 'function') {
                        generateCallback();
                    } else {
                        rubyCallCommand('cutlist_group_cuttingdiagram_2d', $.extend({ group_id: groupId, part_ids: selectionOnly ? that.selectionPartIds : null }, cuttingdiagram2dOptions, that.generateOptions), function (response) {

                        var $slide = that.pushNewSlide('ladb_cutlist_slide_cuttingdiagram_2d', 'tabs/cutlist/_slide-cuttingdiagram-2d.twig', $.extend({
                            generateOptions: that.generateOptions,
                            dimensionColumnOrderStrategy: that.generateOptions.dimension_column_order_strategy.split('>'),
                            filename: that.filename,
                            modelName: that.modelName,
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
                            that.labelsGroup(groupId);
                        });
                        $btnClose.on('click', function () {
                            that.popSlide();
                        });
                        $('.ladb-btn-setup-model-units', $slide).on('click', function() {
                            $(this).blur();
                            that.dialog.executeCommandOnTab('settings', 'highlight_panel', { panel:'model' });
                        });
                        $('.ladb-btn-toggle-no-print', $slide).on('click', function () {
                            var $group = $(this).parents('.ladb-cutlist-group');
                            if ($group.hasClass('no-print')) {
                                that.showGroup($group, true);
                            } else {
                                that.hideGroup($group, true);
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
                                that.showGroup($target, false);
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
                    }

                    // Hide modal
                    $modal.modal('hide');

                });

                // Show modal
                $modal.modal('show');

                // Setup popovers
                that.dialog.setupPopovers();

            });

        });

    };

    LadbTabCutlist.prototype.labelsGroup = function (groupId, forceDefaultTab) {
        var that = this;

        var group = this.findGroupById(groupId);
        var selectionOnly = this.selectionGroupId === groupId && this.selectionPartIds.length > 0;

        // Retrieve parts to use
        var parts;
        if (selectionOnly) {
            parts = [];
            $.each(group.parts, function (index) {
                if (that.selectionPartIds.includes(this.id)) {
                    parts.push(this);
                }
            });
        } else {
            parts = group.parts;
        }

        // Retrieve label options
        rubyCallCommand('core_get_model_preset', { dictionary: 'cutlist_labels_options', section: groupId }, function (response) {

            var labelsOptions = response.preset;

            var $modal = that.appendModalInside('ladb_cutlist_modal_labels', 'tabs/cutlist/_modal-labels.twig', {
                group: group,
                selection_only: selectionOnly,
                tab: forceDefaultTab || that.lastLabelsOptionsTab == null ? 'layout' : that.lastLabelsOptionsTab
            }, true);

            // Fetch UI elements
            var $widgetPreset = $('.ladb-widget-preset', $modal);
            var $editorLabel = $('#ladb_editor_label', $modal);
            var $selectPageFormat = $('#ladb_select_page_format', $modal);
            var $inputPageWidth = $('#ladb_input_page_width', $modal);
            var $inputPageHeight = $('#ladb_input_page_height', $modal);
            var $inputMarginTop = $('#ladb_input_margin_top', $modal);
            var $inputMarginRight = $('#ladb_input_margin_right', $modal);
            var $inputMarginBottom = $('#ladb_input_margin_bottom', $modal);
            var $inputMarginLeft = $('#ladb_input_margin_left', $modal);
            var $inputSpacingH = $('#ladb_input_spacing_h', $modal);
            var $inputSpacingV = $('#ladb_input_spacing_v', $modal);
            var $inputColCount = $('#ladb_input_col_count', $modal);
            var $inputRowCount = $('#ladb_input_row_count', $modal);
            var $selectCuttingMarks = $('#ladb_select_cutting_marks', $modal);
            var $btnGenerate = $('#ladb_btn_generate', $modal);

            var fnPageSizeVisibility = function () {
                if ($selectPageFormat.selectpicker('val') == null) {
                    $selectPageFormat.selectpicker('val', '0');
                    $inputPageWidth.ladbTextinputDimension('enable');
                    $inputPageHeight.ladbTextinputDimension('enable');
                } else {
                    $inputPageWidth.ladbTextinputDimension('disable');
                    $inputPageHeight.ladbTextinputDimension('disable');
                }
            }
            var fnComputeLabelSize = function(pageWidth, pageHeight, marginTop, marginRight, marginBottom, marginLeft, spacingH, spacingV, colCount, rowCount, callback) {
                rubyCallCommand('core_length_to_float', {
                    page_width: pageWidth,
                    page_height: pageHeight,
                    margin_top: marginTop,
                    margin_right: marginRight,
                    margin_bottom: marginBottom,
                    margin_left: marginLeft,
                    spacing_h: spacingH,
                    spacing_v: spacingV
                }, function (response) {
                    colCount = parseInt(colCount);
                    rowCount = parseInt(rowCount);
                    var labelWidth = (response.page_width - response.margin_left - response.margin_right - response.spacing_v * (colCount - 1)) / colCount;
                    var labelHeight = (response.page_height - response.margin_top - response.margin_bottom - response.spacing_h * (rowCount - 1)) / rowCount;
                    callback(labelWidth, labelHeight, response);
                });
            }
            var fnFetchOptions = function (options) {
                options.page_width = $inputPageWidth.val();
                options.page_height = $inputPageHeight.val();
                options.margin_top = $inputMarginTop.val();
                options.margin_right = $inputMarginRight.val();
                options.margin_bottom = $inputMarginBottom.val();
                options.margin_left = $inputMarginLeft.val();
                options.spacing_h = $inputSpacingH.val();
                options.spacing_v = $inputSpacingV.val();
                options.col_count = Math.max(1, parseInt($inputColCount.val() === '' ? 1 : $inputColCount.val()));
                options.row_count = Math.max(1, parseInt($inputRowCount.val() === '' ? 1 : $inputRowCount.val()));
                options.cutting_marks = $selectCuttingMarks.val() === '1';
                options.layout = $editorLabel.ladbEditorLabel('getElementDefs');
            }
            var fnFillInputs = function (options) {
                $selectPageFormat.selectpicker('val', options.page_width.replace(',', '.') + 'x' + options.page_height.replace(',', '.'));
                $inputPageWidth.val(options.page_width);
                $inputPageHeight.val(options.page_height);
                $inputMarginTop.val(options.margin_top);
                $inputMarginRight.val(options.margin_right);
                $inputMarginBottom.val(options.margin_bottom);
                $inputMarginLeft.val(options.margin_left);
                $inputSpacingH.val(options.spacing_h);
                $inputSpacingV.val(options.spacing_v);
                $inputColCount.val(options.col_count);
                $inputRowCount.val(options.row_count);
                $selectCuttingMarks.selectpicker('val', options.cutting_marks ? '1' : '0');
                fnComputeLabelSize(options.page_width, options.page_height, options.margin_top, options.margin_right, options.margin_bottom, options.margin_left, options.spacing_h, options.spacing_v, options.col_count, options.row_count, function (labelWidth, labelHeight) {
                    $editorLabel.ladbEditorLabel('updateSizeAndElementDefs', [ labelWidth, labelHeight, options.layout ]);
                });
                fnPageSizeVisibility();
            }

            $widgetPreset.ladbWidgetPreset({
                dialog: that.dialog,
                dictionary: 'cutlist_labels_options',
                fnFetchOptions: fnFetchOptions,
                fnFillInputs: fnFillInputs
            });
            $editorLabel.ladbEditorLabel({
                filename: that.filename,
                modelName: that.modelName,
                pageLabel: that.pageLabel,
                lengthUnit: that.lengthUnit,
                generatedAt: new Date().getTime() / 1000,
                group: group,
                part: parts[0],
            });
            $selectPageFormat.selectpicker(SELECT_PICKER_OPTIONS);
            $inputPageWidth.ladbTextinputDimension();
            $inputPageHeight.ladbTextinputDimension();
            $inputMarginTop.ladbTextinputDimension();
            $inputMarginRight.ladbTextinputDimension();
            $inputMarginBottom.ladbTextinputDimension();
            $inputMarginLeft.ladbTextinputDimension();
            $inputSpacingH.ladbTextinputDimension();
            $inputSpacingV.ladbTextinputDimension();
            $inputColCount.ladbTextinputNumberWithUnit({
                resetValue: '1'
            });
            $inputRowCount.ladbTextinputNumberWithUnit({
                resetValue: '1'
            });
            $selectCuttingMarks.selectpicker(SELECT_PICKER_OPTIONS);

            fnFillInputs(labelsOptions);

            // Bind tabs
            $('a[data-toggle=tab]', $modal).on('shown.bs.tab', function (e) {
                var tabId = $(e.target).attr('href');
                that.lastLabelsOptionsTab = tabId.substring('#tab_labels_options_'.length);
                if (that.lastLabelsOptionsTab === 'layout') {

                    fnComputeLabelSize($inputPageWidth.val(), $inputPageHeight.val(), $inputMarginTop.val(), $inputMarginRight.val(), $inputMarginBottom.val(), $inputMarginLeft.val(), $inputSpacingH.val(), $inputSpacingV.val(), $inputColCount.val(), $inputRowCount.val(), function (labelWidth, labelHeight) {
                        $editorLabel.ladbEditorLabel('updateSize', [ labelWidth, labelHeight ]);
                    });

                }
            });

            // Bind select
            $selectPageFormat.on('change', function () {
                var format = $(this).val();
                if (format !== '0') {
                    $inputPageWidth.ladbTextinputDimension('disable');
                    $inputPageHeight.ladbTextinputDimension('disable');
                    var dimensions = format.split('x');
                    $inputPageWidth.val(dimensions[0]);
                    $inputPageHeight.val(dimensions[1]);
                } else {
                    $inputPageWidth.ladbTextinputDimension('enable');
                    $inputPageHeight.ladbTextinputDimension('enable');
                }
            });

            // Bind buttons
            $btnGenerate.on('click', function () {

                // Fetch options
                fnFetchOptions(labelsOptions);

                // Store options
                rubyCallCommand('core_set_model_preset', { dictionary: 'cutlist_labels_options', values: labelsOptions, section: groupId });

                fnComputeLabelSize(labelsOptions.page_width, labelsOptions.page_height, labelsOptions.margin_top, labelsOptions.margin_right, labelsOptions.margin_bottom, labelsOptions.margin_left, labelsOptions.spacing_h, labelsOptions.spacing_v, labelsOptions.col_count, labelsOptions.row_count, function (labelWidth, labelHeight, response) {

                    labelsOptions.page_width = response.page_width;
                    labelsOptions.page_height = response.page_height;
                    labelsOptions.margin_top = response.margin_top;
                    labelsOptions.margin_right = response.margin_right;
                    labelsOptions.margin_bottom = response.margin_bottom;
                    labelsOptions.margin_left = response.margin_left;
                    labelsOptions.spacing_h = response.spacing_h;
                    labelsOptions.spacing_v = response.spacing_v;

                    var errors = [];
                    var pages = [];

                    if (labelWidth <= 0 || isNaN(labelWidth) || labelHeight <= 0 || isNaN(labelHeight)) {

                        // Invalid size push an error
                        errors.push('tab.cutlist.labels.error.invalid_size');

                    } else {

                        // Split parts into pages
                        var page;
                        var gIndex = 0;
                        $.each(parts, function (index) {
                            var entityNames = [];
                            $.each(this.entity_names, function () {
                                var entityName = this[0];
                                var count = this[1];
                                for (var i = 0; i < count; i++) {
                                    entityNames.push(entityName)
                                }
                            });
                            for (var i = 1; i <= this.count; i++) {
                                if (gIndex % (labelsOptions.row_count * labelsOptions.col_count) === 0) {
                                    page = {
                                        part_infos: []
                                    }
                                    pages.push(page);
                                }
                                page.part_infos.push({
                                    position_in_batch: i,
                                    entity_name: entityNames[i - 1],
                                    part: this
                                });
                                gIndex++;
                            }
                        });

                    }

                    var $slide = that.pushNewSlide('ladb_cutlist_slide_labels', 'tabs/cutlist/_slide-labels.twig', $.extend({
                        errors: errors,
                        filename: that.filename,
                        modelName: that.modelName,
                        pageLabel: that.pageLabel,
                        lengthUnit: that.lengthUnit,
                        generatedAt: new Date().getTime() / 1000,
                        group: group,
                        pages: pages,
                    }, labelsOptions), function () {
                        that.dialog.setupTooltips();
                    });

                    // Fetch UI elements
                    var $btnLabels = $('#ladb_btn_labels', $slide);
                    var $btnPrint = $('#ladb_btn_print', $slide);
                    var $btnClose = $('#ladb_btn_close', $slide);

                    // Bind buttons
                    $btnLabels.on('click', function () {
                        that.labelsGroup(groupId);
                    });
                    $btnPrint.on('click', function () {

                        // Retrieve an modifiy Page rule to set margin to 0
                        var cssPageRuleStyle = document.styleSheets[0].cssRules[0].style;
                        var tmpMargin = cssPageRuleStyle.margin;
                        cssPageRuleStyle.margin = '0';

                        // Print
                        window.print();

                        // Retore margin
                        cssPageRuleStyle.margin = tmpMargin;

                    });
                    $btnClose.on('click', function () {
                        that.popSlide();
                    });
                    $('.ladb-btn-setup-model-units', $slide).on('click', function() {
                        $(this).blur();
                        that.dialog.executeCommandOnTab('settings', 'highlight_panel', { panel:'model' });
                    });
                    $('.ladb-btn-toggle-no-print', $slide).on('click', function () {
                        var $page = $(this).parents('.ladb-cutlist-group');
                        if ($page.hasClass('no-print')) {
                            that.showGroup($page, true);
                        } else {
                            that.hideGroup($page, true);
                        }
                        $(this).blur();
                    });

                    // Hide modal
                    $modal.modal('hide');

                });

            });

            // Show modal
            $modal.modal('show');

            // Setup popovers
            that.dialog.setupPopovers();

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

        rubyCallCommand('core_get_model_preset', { dictionary: 'cutlist_options' }, function (response) {

            that.generateOptions = response.preset;

            // Callback
            if (typeof callback == 'function') {
                callback();
            }

        });

    };

    LadbTabCutlist.prototype.editOptions = function () {
        var that = this;

        var $modal = that.appendModalInside('ladb_cutlist_modal_options', 'tabs/cutlist/_modal-options.twig');

        // Fetch UI elements
        var $widgetPreset = $('.ladb-widget-preset', $modal);
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
        var $inputTags = $('#ladb_input_tags', $modal);
        var $sortableDimensionColumnOrderStrategy = $('#ladb_sortable_dimension_column_order_strategy', $modal);
        var $btnSetupModelUnits = $('#ladb_cutlist_options_setup_model_units', $modal);
        var $btnUpdate = $('#ladb_cutlist_options_update', $modal);

        // Define useful functions
        var fnFetchOptions = function (options) {
            options.auto_orient = $inputAutoOrient.is(':checked');
            options.smart_material = $inputSmartMaterial.is(':checked');
            options.dynamic_attributes_name = $inputDynamicAttributesName.is(':checked');
            options.part_number_with_letters = $inputPartNumberWithLetters.is(':checked');
            options.part_number_sequence_by_group = $inputPartNumberSequenceByGroup.is(':checked');
            options.part_folding = $inputPartFolding.is(':checked');
            options.hide_entity_names = $inputHideInstanceNames.is(':checked');
            options.hide_tags = $inputHideTags.is(':checked');
            options.hide_cutting_dimensions = $inputHideCuttingDimensions.is(':checked');
            options.hide_bbox_dimensions = $inputHideBBoxDimensions.is(':checked');
            options.hide_final_areas = $inputHideFinalAreas.is(':checked');
            options.hide_edges = $inputHideEdges.is(':checked');
            options.minimize_on_highlight = $inputMinimizeOnHighlight.is(':checked');
            options.tags = $inputTags.tokenfield('getTokensList').split(';');

            var properties = [];
            $sortablePartOrderStrategy.children('li').each(function () {
                properties.push($(this).data('property'));
            });
            options.part_order_strategy = properties.join('>');

            properties = [];
            $sortableDimensionColumnOrderStrategy.children('li').each(function () {
                properties.push($(this).data('property'));
            });
            options.dimension_column_order_strategy = properties.join('>');

        };
        var fnFillInputs = function (options) {

            // Checkboxes

            $inputAutoOrient.prop('checked', options.auto_orient);
            $inputSmartMaterial.prop('checked', options.smart_material);
            $inputDynamicAttributesName.prop('checked', options.dynamic_attributes_name);
            $inputPartNumberWithLetters.prop('checked', options.part_number_with_letters);
            $inputPartNumberSequenceByGroup.prop('checked', options.part_number_sequence_by_group);
            $inputPartFolding.prop('checked', options.part_folding);
            $inputHideInstanceNames.prop('checked', options.hide_entity_names);
            $inputHideTags.prop('checked', options.hide_tags);
            $inputHideCuttingDimensions.prop('checked', options.hide_cutting_dimensions);
            $inputHideBBoxDimensions.prop('checked', options.hide_bbox_dimensions);
            $inputHideFinalAreas.prop('checked', options.hide_final_areas);
            $inputHideEdges.prop('checked', options.hide_edges);
            $inputMinimizeOnHighlight.prop('checked', options.minimize_on_highlight);
            $inputTags.tokenfield('setTokens', options.tags === '' ? ' ' : options.tags);

            // Sortables

            var properties, property, i;

            // Part order sortables

            properties = options.part_order_strategy.split('>');
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

            properties = options.dimension_column_order_strategy.split('>');
            $sortableDimensionColumnOrderStrategy.empty();
            for (i = 0; i < properties.length; i++) {
                property = properties[i];
                $sortableDimensionColumnOrderStrategy.append(Twig.twig({ref: "tabs/cutlist/_option-dimension-column-order-strategy-property.twig"}).render({
                    property: property
                }));
            }
            $sortableDimensionColumnOrderStrategy.sortable(SORTABLE_OPTIONS);

        };

        $widgetPreset.ladbWidgetPreset({
            dialog: that.dialog,
            dictionary: 'cutlist_options',
            fnFetchOptions: fnFetchOptions,
            fnFillInputs: fnFillInputs
        });

        // Bind buttons
        $btnSetupModelUnits.on('click', function () {
            $(this).blur();
            that.dialog.executeCommandOnTab('settings', 'highlight_panel', { panel:'model' });
        });
        $btnUpdate.on('click', function () {

            // Fetch options
            fnFetchOptions(that.generateOptions);

            // Store options
            rubyCallCommand('core_set_model_preset', { dictionary: 'cutlist_options', values: that.generateOptions });

            // Hide modal
            $modal.modal('hide');

            // Refresh the list if it has already been generated
            if (that.groups.length > 0) {
                that.generateCutlist();
            }

        });

        // Show modal
        $modal.modal('show');

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

        // Populate inputs
        fnFillInputs(that.generateOptions);

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
        this.$btnOptions.on('click', function () {
            that.editOptions();
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
            that.expandAllFoldingRows();
            $(this).blur();
        });
        this.$itemCollapseAll.on('click', function () {
            that.collapseAllFoldingRows();
            $(this).blur();
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
        addEventCallback('on_model_preset_changed', function (params) {
            if (that.generateAt && params.dictionary === 'settings_model') {
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
        addEventCallback([ 'on_selection_bulk_change', 'on_selection_cleared', 'on_pages_contents_modified' ], function () {
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
            var options = $.extend({}, LadbTabCutlist.DEFAULTS, $this.data(), typeof option === 'object' && option);

            if (!data) {
                if (undefined === options.dialog) {
                    throw 'dialog option is mandatory.';
                }
                $this.data('ladb.tab.plugin', (data = new LadbTabCutlist(this, options, options.dialog)));
            }
            if (typeof option === 'string') {
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

+function ($) {
    'use strict';

    // CONSTANTS
    // ======================

    // Various Consts

    var MULTIPLE_VALUE = '-1';

    // CLASS DEFINITION
    // ======================

    var LadbTabCutlist = function (element, options, dialog) {
        LadbAbstractTab.call(this, element, options, dialog);

        this.generateFilters = {
          tags_filter: [],
          edge_material_names_filter: [],
          veneer_material_names_filter: []
        };

        this.generateAt = null;
        this.filename = null;
        this.modelName = null;
        this.modelDescription = null;
        this.modelActivePath = null;
        this.pageName = null;
        this.pageDescription = null;
        this.isEntitySelection = null;
        this.lengthUnit = null;
        this.usedTags = [];
        this.usedEdgeMaterialDisplayNames = [];
        this.usedVeneerMaterialDisplayNames = [];
        this.materialUsages = [];
        this.groups = [];
        this.ignoreNextMaterialEvents = false;
        this.selectionGroupId = null;
        this.selectionPartIds = [];
        this.lastOptionsTab = null;
        this.lastEditPartTab = null;
        this.lastExportOptionsTab = null;
        this.lastExportOptionsEditingItem = null;
        this.lastReportOptionsTab = null;
        this.lastCuttingdiagram1dOptionsTab = null;
        this.lastCuttingdiagram2dOptionsTab = null;
        this.lastLabelsOptionsTab = null;
        this.lastLayoutOptionsTab = null;

        this.$header = $('.ladb-header', this.$element);
        this.$headerExtra = $('.ladb-header-extra', this.$header);
        this.$btnGenerate = $('#ladb_btn_generate', this.$header);
        this.$btnPrint = $('#ladb_btn_print', this.$header);
        this.$btnExport = $('#ladb_btn_export', this.$header);
        this.$btnLayout = $('#ladb_btn_layout', this.$header);
        this.$btnReport = $('#ladb_btn_report', this.$header);
        this.$btnOptions = $('#ladb_btn_options', this.$header);
        this.$itemHighlightAllParts = $('#ladb_item_highlight_all_parts', this.$header);
        this.$itemExport2dAllParts = $('#ladb_item_export_2d_all_parts', this.$header);
        this.$itemExport3dAllParts = $('#ladb_item_export_3d_all_parts', this.$header);
        this.$itemShowAllGroups = $('#ladb_item_show_all_groups', this.$header);
        this.$itemNumbersSave = $('#ladb_item_numbers_save', this.$header);
        this.$itemNumbersReset = $('#ladb_item_numbers_reset', this.$header);
        this.$itemExpendAll = $('#ladb_item_expand_all', this.$header);
        this.$itemCollapseAll = $('#ladb_item_collapse_all', this.$header);
        this.$itemResetPrices = $('#ladb_item_reset_prices', this.$header);

        this.$panelHelp = $('.ladb-panel-help', this.$element);
        this.$page = $('.ladb-page', this.$element);

    };
    LadbTabCutlist.prototype = Object.create(LadbAbstractTab.prototype);

    LadbTabCutlist.DEFAULTS = {};

    // Cutlist /////

    LadbTabCutlist.prototype.generateCutlist = function (callback) {
        var that = this;

        // Destroy previously created tokenfields
        $('#ladb_cutlist_tags_filter', that.$page).tokenfield('destroy');
        $('#ladb_cutlist_edge_material_names_filter', that.$page).tokenfield('destroy');
        $('#ladb_cutlist_veneer_material_names_filter', that.$page).tokenfield('destroy');

        this.groups = [];
        this.$page.empty();
        this.$btnGenerate.prop('disabled', true);
        this.popToRootSlide();
        this.hideModalInside();

        window.requestAnimationFrame(function () {

            // Start progress feedback
            that.dialog.startProgress(1);

            rubyCallCommand('cutlist_generate', $.extend(that.generateOptions, that.generateFilters), function (response) {

                that.generateAt = new Date().getTime() / 1000;
                that.setObsolete(false);

                var errors = response.errors;
                var warnings = response.warnings;
                var tips = response.tips;
                var filename = response.filename;
                var modelName = response.model_name;
                var modelDescription = response.model_description;
                var modelActivePath = response.model_active_path;
                var pageName = response.page_name;
                var pageDescription = response.page_description;
                var isEntitySelection = response.is_entity_selection;
                var lengthUnit = response.length_unit;
                var massUnitStrippedname = response.mass_unit_strippedname;
                var currencySymbol = response.currency_symbol;
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

                // Keep useful data
                that.filename = filename;
                that.modelName = modelName;
                that.modelDescription = modelDescription;
                that.modelActivePath = modelActivePath;
                that.pageName = pageName;
                that.pageDescription = pageDescription;
                that.cutlistTitle = (modelName ? modelName : filename.replace(/\.[^/.]+$/, '')) + (pageName ? ' - ' + pageName : '');
                that.isEntitySelection = isEntitySelection;
                that.lengthUnit = lengthUnit;
                that.currencySymbol = currencySymbol;
                that.massUnitStrippedname = massUnitStrippedname;
                that.usedTags = usedTags;
                that.usedEdgeMaterialDisplayNames = [];
                that.usedVeneerMaterialDisplayNames = [];
                that.materialUsages = materialUsages;
                that.groups = groups;

                // Compute usedEdgeMaterialDisplayNames
                for (var i = 0; i < materialUsages.length; i++) {
                    if (materialUsages[i].type === 4 && materialUsages[i].use_count > 0) {     // 4 = TYPE_EDGE
                        that.usedEdgeMaterialDisplayNames.push(materialUsages[i].display_name);
                    }
                }

                // Compute usedVeneerMaterialDisplayNames
                for (var i = 0; i < materialUsages.length; i++) {
                    if (materialUsages[i].type === 6 && materialUsages[i].use_count > 0) {     // 6 = TYPE_VENEER
                        that.usedVeneerMaterialDisplayNames.push(materialUsages[i].display_name);
                    }
                }

                // Update filename
                that.$headerExtra.empty();
                that.$headerExtra.append(Twig.twig({ ref: "tabs/cutlist/_header-extra.twig" }).render({
                    filename: filename,
                    modelName: modelName,
                    modelDescription: modelDescription,
                    modelActivePath: modelActivePath,
                    pageName: pageName,
                    pageDescription: pageDescription,
                    isEntitySelection: isEntitySelection,
                    lengthUnit: lengthUnit,
                    generateAt: that.generateAt
                }));

                // Hide help panel
                that.$panelHelp.hide();

                // Update buttons and items state
                that.$btnPrint.prop('disabled', groups.length === 0);
                that.$btnExport.prop('disabled', groups.length === 0);
                that.$btnLayout.prop('disabled', groups.length === 0);
                that.$btnReport.prop('disabled', solidWoodMaterialCount + sheetGoodMaterialCount + dimensionalMaterialCount + edgeMaterialCount + hardwareMaterialCount === 0);
                that.$itemHighlightAllParts.parents('li').toggleClass('disabled', groups.length === 0);
                that.$itemExport2dAllParts.parents('li').toggleClass('disabled', groups.length === 0);
                that.$itemExport3dAllParts.parents('li').toggleClass('disabled', groups.length === 0);
                that.$itemShowAllGroups.parents('li').toggleClass('disabled', groups.length === 0);
                that.$itemNumbersSave.parents('li').toggleClass('disabled', groups.length === 0);
                that.$itemNumbersReset.parents('li').toggleClass('disabled', groups.length === 0);
                that.$itemExpendAll.parents('li').toggleClass('disabled', groups.length === 0 || !that.generateOptions.part_folding);
                that.$itemCollapseAll.parents('li').toggleClass('disabled', groups.length === 0 || !that.generateOptions.part_folding);

                // Update page
                that.$page.empty();
                that.$page.append(Twig.twig({ ref: "tabs/cutlist/_list.twig" }).render({
                    capabilities: that.dialog.capabilities,
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
                    usedVeneerMaterialDisplayNames: that.usedVeneerMaterialDisplayNames,
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

                // Useful function
                var fnGenerateWithTagsFilter = function () {
                    var tokenList = $('#ladb_cutlist_tags_filter', that.$page).tokenfield('getTokensList');
                    that.generateFilters.tags_filter = tokenList.length === 0 ? [] : tokenList.split(';');
                    that.generateCutlist(function () {
                        $('#ladb_cutlist_tags_filter-tokenfield', that.$page).focus();
                    });
                }

                // Bind inputs
                $('#ladb_cutlist_tags_filter', that.$page)
                    .on('tokenfield:createtoken', function (e) {

                        var m = e.attrs.value.match(/([+-])(.*)/);
                        if (m) {
                            e.attrs.oko = m[1]
                            e.attrs.label = m[2];
                        } else {
                            e.attrs.oko = '+'
                            e.attrs.label = e.attrs.value;
                            e.attrs.value = '+' + e.attrs.value;
                        }

                        // Unique token
                        var tokens = $(this).tokenfield('getTokens');
                        if (Array.isArray(tokens)) {
                            $.each(tokens, function (index, token) {
                                if (token.label === e.attrs.label) {
                                    e.preventDefault();
                                    return false;
                                }
                            })
                        }

                        // Used token only
                        if (!that.usedTags.includes(e.attrs.label)) {
                            e.preventDefault();
                            return false;
                        }

                    })
                    .on('tokenfield:createdtoken', function (e) {
                        var $okoBtn = $('<a href="#" class="oko" data-toggle="tooltip" title="' + i18next.t('tab.cutlist.tooltip.oko_label_filter') + '"></a>')
                            .on('click', function () {
                                e.attrs.value = (e.attrs.oko === '+' ? '-' : '+') + e.attrs.label;
                                fnGenerateWithTagsFilter();
                            })
                            .insertBefore($('.close', e.relatedTarget))
                        ;
                        that.dialog.setupTooltips($(e.relatedTarget));
                        if (e.attrs.oko === '-') {
                            $okoBtn.append($('<i class="ladb-opencutlist-icon-eye-open"></i>'))
                            $(e.relatedTarget).addClass('ko');
                        } else {
                            $okoBtn.append($('<i class="ladb-opencutlist-icon-eye-close"></i>'))
                        }
                    })
                    .tokenfield($.extend(TOKENFIELD_OPTIONS, {
                        autocomplete: {
                            source: that.usedTags,
                            delay: 100
                        },
                        showAutocompleteOnFocus: false
                    }))
                    .on('tokenfield:createdtoken tokenfield:removedtoken', function (e) {
                        fnGenerateWithTagsFilter();
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
                        var tokens = $(this).tokenfield('getTokens');
                        if (Array.isArray(tokens)) {
                            $.each(tokens, function (index, token) {
                                if (token.label === e.attrs.label) {
                                    e.preventDefault();
                                    return false;
                                }
                            })
                        }

                        // Available token only
                        if (!that.usedEdgeMaterialDisplayNames.includes(e.attrs.label)) {
                            e.preventDefault();
                            return false;
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
                $('#ladb_cutlist_veneer_material_names_filter', that.$page)
                    .tokenfield($.extend(TOKENFIELD_OPTIONS, {
                        autocomplete: {
                            source: that.usedVeneerMaterialDisplayNames,
                            delay: 100
                        },
                        showAutocompleteOnFocus: false
                    }))
                    .on('tokenfield:createtoken', function (e) {

                        // Unique token
                        var tokens = $(this).tokenfield('getTokens');
                        if (Array.isArray(tokens)) {
                            $.each(tokens, function (index, token) {
                                if (token.label === e.attrs.label) {
                                    e.preventDefault();
                                    return false;
                                }
                            })
                        }

                        // Available token only
                        if (!that.usedVeneerMaterialDisplayNames.includes(e.attrs.label)) {
                            e.preventDefault();
                            return false;
                        }

                    })
                    .on('tokenfield:createdtoken tokenfield:removedtoken', function (e) {
                        var tokenList = $(this).tokenfield('getTokensList');
                        that.generateFilters.veneer_material_names_filter = tokenList.length === 0 ? [] : tokenList.split(';');
                        that.generateCutlist(function () {
                            $('#ladb_cutlist_veneer_material_names_filter-tokenfield', that.$page).focus();
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
                $('#ladb_cutlist_btn_veneer_material_names_filter_clear', that.$page).on('click', function () {
                    $(this).blur();
                    that.generateFilters.veneer_material_names_filter = [];
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
                $('a.ladb-btn-open-material-url', that.$page).on('click', function () {
                    $(this).blur();
                    rubyCallCommand('core_open_url', { url: $(this).attr('href') });
                    return false;
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
                $('a.ladb-btn-edge-material-filter', that.$page).on('click', function () {
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
                $('a.ladb-btn-veneer-material-filter', that.$page).on('click', function () {
                    $(this).blur();
                    var materialFilter = $(this).data('material-display-name');
                    var indexOf = that.generateFilters.veneer_material_names_filter.indexOf(materialFilter);
                    if (indexOf > -1) {
                        that.generateFilters.veneer_material_names_filter.splice(indexOf, 1);
                    } else {
                        that.generateFilters.veneer_material_names_filter.push(materialFilter);
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
                $('a.ladb-item-export-2d-group-parts', that.$page).on('click', function () {
                    var $group = $(this).parents('.ladb-cutlist-group');
                    var groupId = $group.data('group-id');
                    that.writeGroupParts(groupId, true);
                    $(this).blur();
                });
                $('a.ladb-item-export-3d-group-parts', that.$page).on('click', function () {
                    var $group = $(this).parents('.ladb-cutlist-group');
                    var groupId = $group.data('group-id');
                    that.writeGroupParts(groupId, false);
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
                $('a.ladb-item-dimensions-help', that.$page).on('click', function () {
                    $(this).blur();
                    var $group = $(this).parents('.ladb-cutlist-group');
                    var groupId = $group.data('group-id');
                    that.dimensionsHelpGroup(groupId);
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
                $('button.ladb-btn-group-packing', that.$page).on('click', function () {

                    // Show Objective modal
                    that.dialog.executeCommandOnTab('sponsor', 'show_objective_modal', {
                        objectiveStrippedName: 'packing',
                        objectiveIcon: 'packing-irregular',
                        objectiveImage: 'sponsor-objective-packing.png',
                    }, null, true);

                });
                $('button.ladb-btn-group-labels', that.$page).on('click', function () {
                    $(this).blur();
                    var $group = $(this).parents('.ladb-cutlist-group');
                    var groupId = $group.data('group-id');
                    that.labelsGroup(groupId);
                });
                $('button.ladb-btn-group-layout', that.$page).on('click', function () {
                    $(this).blur();
                    var $group = $(this).parents('.ladb-cutlist-group');
                    var groupId = $group.data('group-id');
                    that.layoutGroupParts(groupId);
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
                $('a.ladb-btn-open-part-url', that.$page).on('click', function () {
                    $(this).blur();
                    rubyCallCommand('core_open_url', { url: $(this).attr('href') });
                    return false;
                });
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
                    var labelFilter = '+' + $(this).html();
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

                // Finish progress feedback
                that.dialog.finishProgress();

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
        });

    };

    LadbTabCutlist.prototype.exportCutlist = function (forceDefaultTab) {
        var that = this;

        var isGroupSelection = this.generateOptions.hidden_group_ids.length > 0 && this.generateOptions.hidden_group_ids.indexOf('summary') === -1
            || this.generateOptions.hidden_group_ids.length > 1 && this.generateOptions.hidden_group_ids.indexOf('summary') >= 0;

        // Retrieve export option options
        rubyCallCommand('core_get_model_preset', { dictionary: 'cutlist_export_options' }, function (response) {

            var exportOptions = response.preset;

            var $modal = that.appendModalInside('ladb_cutlist_modal_export', 'tabs/cutlist/_modal-export.twig', {
                isGroupSelection: isGroupSelection,
                tab: forceDefaultTab || that.lastExportOptionsTab == null ? 'general' : that.lastExportOptionsTab
            });

            // Fetch UI elements
            var $tabs = $('a[data-toggle="tab"]', $modal);
            var $widgetPreset = $('.ladb-widget-preset', $modal);
            var $selectSource = $('#ladb_cutlist_export_select_source', $modal);
            var $selectColSep = $('#ladb_cutlist_export_select_col_sep', $modal);
            var $selectEncoding = $('#ladb_cutlist_export_select_encoding', $modal);
            var $editorSummary = $('#ladb_cutlist_export_editor_summary', $modal);
            var $editorCutlist = $('#ladb_cutlist_export_editor_cutlist', $modal);
            var $editorInstancesList = $('#ladb_cutlist_export_editor_instances_list', $modal);
            var $btnPreview = $('#ladb_cutlist_export_btn_preview', $modal);
            var $btnExport = $('#ladb_cutlist_export_btn_export', $modal);

            // Define useful functions

            var fnComputeSorterVisibility = function (source) {
                switch (parseInt(source)) {
                    case 0: // EXPORT_OPTION_SOURCE_SUMMARY
                        $editorSummary.show();
                        $editorCutlist.hide();
                        $editorInstancesList.hide();
                        break;
                    case 1: // EXPORT_OPTION_SOURCE_CUTLIST
                        $editorSummary.hide();
                        $editorCutlist.show();
                        $editorInstancesList.hide();
                        break;
                    case 2: // EXPORT_OPTION_SOURCE_INSTANCES_LIST
                        $editorSummary.hide();
                        $editorCutlist.hide();
                        $editorInstancesList.show();
                        break;
                }
            };
            var fnFetchLastExportOptionsEditingItem = function (source) {
                var index = null;
                switch (parseInt(source)) {
                    case 0: // EXPORT_OPTION_SOURCE_SUMMARY
                        index = $editorSummary.ladbEditorExport('getEditingItemIndex');
                        break;
                    case 1: // EXPORT_OPTION_SOURCE_CUTLIST
                        index = $editorCutlist.ladbEditorExport('getEditingItemIndex');
                        break;
                    case 2: // EXPORT_OPTION_SOURCE_INSTANCES_LIST
                        index = $editorInstancesList.ladbEditorExport('getEditingItemIndex');
                        break;
                }
                if (index != null) {
                    that.lastExportOptionsEditingItem = {
                        source : source,
                        index : index
                    }
                } else {
                    that.lastExportOptionsEditingItem = null;
                }
            };
            var fnFetchOptions = function (options) {
                options.source = parseInt($selectSource.val());
                options.col_sep = parseInt($selectColSep.val());
                options.encoding = parseInt($selectEncoding.val());

                if (options.source_col_defs == null) {
                    options.source_col_defs = [];
                }
                options.source_col_defs[0] = $editorSummary.ladbEditorExport('getColDefs');
                options.source_col_defs[1] = $editorCutlist.ladbEditorExport('getColDefs');
                options.source_col_defs[2] = $editorInstancesList.ladbEditorExport('getColDefs');

            }
            var fnFillInputs = function (options) {
                $selectSource.selectpicker('val', options.source);
                $selectColSep.selectpicker('val', options.col_sep);
                $selectEncoding.selectpicker('val', options.encoding);
                $editorSummary.ladbEditorExport('setColDefs', [ options.source_col_defs[0] ])
                $editorCutlist.ladbEditorExport('setColDefs', [ options.source_col_defs[1] ])
                $editorInstancesList.ladbEditorExport('setColDefs', [ options.source_col_defs[2] ])
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
            $editorSummary.ladbEditorExport({
                dialog: that.dialog,
                vars: [
                    { name: 'material_type', type: 'string' },
                    { name: 'material_name', type: 'string' },
                    { name: 'material_std_dimension', type: 'string' },
                    { name: 'material_description', type: 'string' },
                    { name: 'material_url', type: 'string' },
                    { name: 'part_count', type: 'integer' },
                    { name: 'total_cutting_length', type: 'length' },
                    { name: 'total_cutting_area', type: 'area' },
                    { name: 'total_cutting_volume', type: 'volume' },
                    { name: 'total_final_area', type: 'area' }
                ]
            });
            $editorCutlist.ladbEditorExport({
                dialog: that.dialog,
                vars: [
                    { name: 'number', type: 'string' },
                    { name: 'name', type: 'string' },
                    { name: 'count', type: 'integer' },
                    { name: 'cutting_length', type: 'length' },
                    { name: 'cutting_width', type: 'length' },
                    { name: 'cutting_thickness', type: 'length' },
                    { name: 'edge_cutting_length', type: 'length' },
                    { name: 'edge_cutting_width', type: 'length' },
                    { name: 'bbox_length', type: 'length' },
                    { name: 'bbox_width', type: 'length' },
                    { name: 'bbox_thickness', type: 'length' },
                    { name: 'final_area', type: 'area' },
                    { name: 'material_type', type: 'material-type' },
                    { name: 'material_name', type: 'string' },
                    { name: 'material_description', type: 'string' },
                    { name: 'material_url', type: 'string' },
                    { name: 'entity_names', type: 'array' },
                    { name: 'description', type: 'string' },
                    { name: 'url', type: 'string' },
                    { name: 'tags', type: 'array' },
                    { name: 'edge_ymin', type: 'edge' },
                    { name: 'edge_ymax', type: 'edge' },
                    { name: 'edge_xmin', type: 'edge' },
                    { name: 'edge_xmax', type: 'edge' },
                    { name: 'face_zmax', type: 'veneer' },
                    { name: 'face_zmin', type: 'veneer' },
                    { name: 'layers', type: 'array' }
                ],
                snippetDefs: [
                    { name: i18next.t('tab.cutlist.snippet.number_and_name'), value: '@number + " - " + @name' },
                    { name: '-' },
                    { name: i18next.t('tab.cutlist.snippet.size'), value: '@bbox_length + " x " + @bbox_width' },
                    { name: i18next.t('tab.cutlist.snippet.area'), value: '@bbox_length * @bbox_width' },
                    { name: i18next.t('tab.cutlist.snippet.volume'), value: '@bbox_length * @bbox_width * @bbox_thickness' },
                ]
            });
            $editorInstancesList.ladbEditorExport({
                dialog: that.dialog,
                vars: [
                    { name: 'number', type: 'string' },
                    { name: 'path', type: 'path' },
                    { name: 'instance_name', type: 'string' },
                    { name: 'name', type: 'string' },
                    { name: 'cutting_length', type: 'length' },
                    { name: 'cutting_width', type: 'length' },
                    { name: 'cutting_thickness', type: 'length' },
                    { name: 'edge_cutting_length', type: 'length' },
                    { name: 'edge_cutting_width', type: 'length' },
                    { name: 'bbox_length', type: 'length' },
                    { name: 'bbox_width', type: 'length' },
                    { name: 'bbox_thickness', type: 'length' },
                    { name: 'final_area', type: 'area' },
                    { name: 'material_type', type: 'material-type' },
                    { name: 'material_name', type: 'string' },
                    { name: 'material_description', type: 'string' },
                    { name: 'material_url', type: 'string' },
                    { name: 'description', type: 'string' },
                    { name: 'url', type: 'string' },
                    { name: 'tags', type: 'array' },
                    { name: 'edge_ymin', type: 'edge' },
                    { name: 'edge_ymax', type: 'edge' },
                    { name: 'edge_xmin', type: 'edge' },
                    { name: 'edge_xmax', type: 'edge' },
                    { name: 'face_zmax', type: 'veneer' },
                    { name: 'face_zmin', type: 'veneer' },
                    { name: 'layer', type: 'string' }
                ],
                snippetDefs: [
                    { name: i18next.t('tab.cutlist.snippet.number_and_name'), value: '@number + " - " + @name' },
                    { name: '-' },
                    { name: i18next.t('tab.cutlist.snippet.size'), value: '@bbox_length + " x " + @bbox_width' },
                    { name: i18next.t('tab.cutlist.snippet.area'), value: '@bbox_length * @bbox_width' },
                    { name: i18next.t('tab.cutlist.snippet.volume'), value: '@bbox_length * @bbox_width * @bbox_thickness' },
                ]
            });

            fnFillInputs(exportOptions);

            // Bind tabs
            $tabs.on('shown.bs.tab', function (e) {
                that.lastExportOptionsTab = $(e.target).attr('href').substring('#tab_export_options_'.length);
            });

            // Bind select
            $selectSource.on('change', function () {
                fnComputeSorterVisibility($(this).val());
            });

            // Bind buttons
            $btnPreview.on('click', function () {

                // Fetch options
                fnFetchOptions(exportOptions);

                // Fetch last editing item
                fnFetchLastExportOptionsEditingItem(exportOptions.source);

                // Store options
                rubyCallCommand('core_set_model_preset', { dictionary: 'cutlist_export_options', values: exportOptions });

                rubyCallCommand('cutlist_export', $.extend(exportOptions, { col_defs: exportOptions.source_col_defs[exportOptions.source], target: 'table' }, that.generateOptions), function (response) {

                    if (response.errors) {
                        that.dialog.notifyErrors(response.errors);
                    }
                    if (response.rows) {

                        var $slide = that.pushNewSlide('ladb_cutlist_slide_export', 'tabs/cutlist/_slide-export.twig', $.extend({
                            errors: response.errors,
                            filename: that.filename,
                            modelName: that.modelName,
                            modelDescription: that.modelDescription,
                            modelActivePath: that.modelActivePath,
                            pageName: that.pageName,
                            pageDescription: that.pageDescription,
                            isEntitySelection: that.isEntitySelection,
                            lengthUnit: that.lengthUnit,
                            generatedAt: new Date().getTime() / 1000,
                            rows: response.rows
                        }, exportOptions), function () {

                        });

                        var fnCopyToClipboard = function(noHeader) {
                            rubyCallCommand('cutlist_export', $.extend(exportOptions, { col_defs: exportOptions.source_col_defs[exportOptions.source], target: 'pasteable', no_header: noHeader }, that.generateOptions), function (response) {
                                if (response.errors) {
                                    that.dialog.notifyErrors(response.errors);
                                }
                                if (response.pasteable) {
                                    that.dialog.copyToClipboard(response.pasteable);
                                }
                            });
                        }

                        // Fetch UI elements
                        var $btnExport = $('#ladb_btn_export', $slide);
                        var $itemCopyAll = $('#ladb_item_copy_all', $slide);
                        var $itemCopyValues = $('#ladb_item_copy_values', $slide);
                        var $btnClose = $('#ladb_btn_close', $slide);

                        // Bind buttons
                        $btnExport.on('click', function () {
                            that.exportCutlist();
                        });
                        $itemCopyAll.on('click', function () {
                            fnCopyToClipboard(false);
                        });
                        $itemCopyValues.on('click', function () {
                            fnCopyToClipboard(true);
                        });
                        $btnClose.on('click', function () {
                            that.popSlide();
                        });
                        $('.ladb-btn-setup-model-units', $slide).on('click', function () {
                            $(this).blur();
                            that.dialog.executeCommandOnTab('settings', 'highlight_panel', { panel:'model' });
                        });

                    }

                });

                // Hide modal
                $modal.modal('hide');

            });
            $btnExport.on('click', function () {

                // Fetch options
                fnFetchOptions(exportOptions);

                // Fetch last editing item
                fnFetchLastExportOptionsEditingItem(exportOptions.source);

                // Store options
                rubyCallCommand('core_set_model_preset', { dictionary: 'cutlist_export_options', values: exportOptions });

                rubyCallCommand('cutlist_export', $.extend(exportOptions, { col_defs: exportOptions.source_col_defs[exportOptions.source], target: 'csv' }, that.generateOptions), function (response) {

                    if (response.errors) {
                        that.dialog.notifyErrors(response.errors);
                    }
                    if (response.export_path) {
                        that.dialog.notifySuccess(i18next.t('core.success.exported_to', { path: response.export_path }), [
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

            // Try to restore selection
            if (that.lastExportOptionsEditingItem != null) {
                switch (that.lastExportOptionsEditingItem.source) {
                    case 0: // EXPORT_OPTION_SOURCE_SUMMARY
                        $editorSummary.ladbEditorExport('setEditingItemIndex', that.lastExportOptionsEditingItem.index);
                        break;
                    case 1: // EXPORT_OPTION_SOURCE_CUTLIST
                        $editorCutlist.ladbEditorExport('setEditingItemIndex', that.lastExportOptionsEditingItem.index);
                        break;
                    case 2: // EXPORT_OPTION_SOURCE_INSTANCES_LIST
                        $editorInstancesList.ladbEditorExport('setEditingItemIndex', that.lastExportOptionsEditingItem.index);
                        break;
                }
            }

        });

    };

    LadbTabCutlist.prototype.reportCutlist = function (forceDefaultTab) {
        var that = this;

        var isGroupSelection = this.generateOptions.hidden_group_ids.length > 0 && this.generateOptions.hidden_group_ids.indexOf('summary') === -1
            || this.generateOptions.hidden_group_ids.length > 1 && this.generateOptions.hidden_group_ids.indexOf('summary') >= 0;

        // Retrieve label options
        rubyCallCommand('core_get_model_preset', { dictionary: 'cutlist_report_options' }, function (response) {

            var reportOptions = response.preset;

            var $modal = that.appendModalInside('ladb_cutlist_modal_report', 'tabs/cutlist/_modal-report.twig', {
                isGroupSelection: isGroupSelection,
                tab: forceDefaultTab || that.lastReportOptionsTab == null ? 'general' : that.lastReportOptionsTab,
            });

            // Fetch UI elements
            var $tabs = $('a[data-toggle="tab"]', $modal);
            var $widgetPreset = $('.ladb-widget-preset', $modal);
            var $inputSolidWoodCoefficient = $('#ladb_input_solid_wood_coefficient', $modal);
            var $btnGenerate = $('#ladb_cutlist_report_btn_generate', $modal);

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

            // Bind tabs
            $tabs.on('shown.bs.tab', function (e) {
                that.lastReportOptionsTab = $(e.target).attr('href').substring('#tab_report_options_'.length);
            });

            // Bind buttons
            $btnGenerate.on('click', function () {

                // Fetch options
                fnFetchOptions(reportOptions);

                // Store options
                rubyCallCommand('core_set_model_preset', { dictionary: 'cutlist_report_options', values: reportOptions });

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

                        var $slide = that.pushNewSlide('ladb_cutlist_slide_report', 'tabs/cutlist/_slide-report.twig', $.extend({
                            generateOptions: that.generateOptions,
                            errors: response.errors,
                            filename: that.filename,
                            modelName: that.modelName,
                            modelDescription: that.modelDescription,
                            modelActivePath: that.modelActivePath,
                            pageName: that.pageName,
                            pageDescription: that.pageDescription,
                            isEntitySelection: that.isEntitySelection,
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
                            this.blur();
                            that.print(that.cutlistTitle + ' - ' + i18next.t('tab.cutlist.report.title'));
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
                            var propertiesTab = $(this).data('properties-tab');
                            that.dialog.executeCommandOnTab('materials', 'edit_material', {
                                materialId: materialId,
                                propertiesTab: propertiesTab,
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
                        $('a.ladb-btn-open-part-url, a.ladb-btn-open-material-url', $slide).on('click', function () {
                            $(this).blur();
                            rubyCallCommand('core_open_url', { url: $(this).attr('href') });
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
        let partIdsWithContext = this.grabVisiblePartIdsWithContext(null, REAL_MATERIALS_FILTER);
        this.highlightParts(partIdsWithContext.partIds, partIdsWithContext.context);
    };

    LadbTabCutlist.prototype.highlightGroupParts = function (groupId) {
        let partIdsWithContext = this.grabVisiblePartIdsWithContext(groupId, REAL_MATERIALS_FILTER);
        this.highlightParts(partIdsWithContext.partIds, partIdsWithContext.context);
    };

    LadbTabCutlist.prototype.highlightPart = function (partId) {
        var groupAndPart = this.findGroupAndPartById(partId);
        if (groupAndPart) {

            var group = groupAndPart.group;
            var part = groupAndPart.part;

            var isFolder = part.children && part.children.length > 0;
            var isSelected = this.selectionGroupId === group.id && this.selectionPartIds.includes(partId) && this.selectionPartIds.length > 1;

            var partIds;
            if (isFolder) {
                partIds = [ partId ];
            } else if (isSelected) {
                partIds = this.selectionPartIds;
            } else {
                partIds = [ partId ];
            }

            this.highlightParts(partIds);

        }
    };

    LadbTabCutlist.prototype.highlightParts = function (partIds, context) { // partIds ignored if groupId is defined
        var that = this;

        var groupId = context && context.targetGroup ? context.targetGroup.id : null;

        rubyCallCommand('cutlist_highlight_parts', { minimize_on_highlight: this.generateOptions.minimize_on_highlight, group_id: groupId, part_ids: partIds }, function (response) {

            if (response['errors']) {
                that.dialog.notifyErrors(response['errors']);
            } else if (that.generateOptions.minimize_on_highlight) {
                that.dialog.minimize();
            }

        });

    }

    // Layout /////

    LadbTabCutlist.prototype.layoutAllParts = function () {
        let partIdsWithContext = this.grabVisiblePartIdsWithContext(null, REAL_MATERIALS_FILTER);
        this.layoutParts(partIdsWithContext.partIds, partIdsWithContext.context);
    };

    LadbTabCutlist.prototype.layoutGroupParts = function (groupId) {
        let partIdsWithContext = this.grabVisiblePartIdsWithContext(groupId, REAL_MATERIALS_FILTER);
        this.layoutParts(partIdsWithContext.partIds, partIdsWithContext.context);
    };

    LadbTabCutlist.prototype.layoutParts = function (partIds, context, forceDefaultTab) {
        var that = this;

        var section = context && context.targetGroup ? context.targetGroup.id : null;

        // Retrieve layout options
        rubyCallCommand('core_get_model_preset', { dictionary: 'cutlist_layout_options', section: section }, function (response) {

            var layoutOptions = response.preset;

            var $modal = that.appendModalInside('ladb_cutlist_modal_layout', 'tabs/cutlist/_modal-layout.twig', {
                group: context.targetGroup,
                isGroupSelection: context ? context.isGroupSelection : false,
                isPartSelection: context ? context.isPartSelection : false,
                tab: forceDefaultTab || that.lastLayoutOptionsTab == null ? 'layout' : that.lastLayoutOptionsTab,
                THREE_CAMERA_VIEWS: THREE_CAMERA_VIEWS
            });

            // Fetch UI elements
            var $tabs = $('a[data-toggle="tab"]', $modal);
            var $widgetPreset = $('.ladb-widget-preset', $modal);
            var $selectPageFormat = $('#ladb_select_page_format', $modal);
            var $inputPageWidth = $('#ladb_input_page_width', $modal);
            var $inputPageHeight = $('#ladb_input_page_height', $modal);
            var $selectPageHeader = $('#ladb_select_page_header', $modal);
            var $selectPartsColored = $('#ladb_select_parts_colored', $modal);
            var $selectPartsOpacity = $('#ladb_select_parts_opacity', $modal);
            var $selectPinsHidden = $('#ladb_select_pins_hidden', $modal);
            var $selectPinsColored = $('#ladb_select_pins_colored', $modal);
            var $textareaPinsFormula = $('#ladb_textarea_pins_formula', $modal);
            var $selectPinsLength = $('#ladb_select_pins_length', $modal);
            var $selectPinsDirection = $('#ladb_select_pins_direction', $modal);
            var $selectCameraView = $('#ladb_select_camera_view', $modal);
            var $selectCameraZoom = $('#ladb_select_camera_zoom', $modal);
            var $selectCameraTarget = $('#ladb_select_camera_target', $modal);
            var $inputCameraView = $('#ladb_input_camera_view', $modal);
            var $inputCameraZoom = $('#ladb_input_camera_zoom', $modal);
            var $inputCameraTarget = $('#ladb_input_camera_target', $modal);
            var $inputExplodeFactor = $('#ladb_input_explode_factor', $modal);
            var $formGroupPins = $('.ladb-cutlist-layout-form-group-pins', $modal);
            var $formGroupPinsDirection = $('.ladb-cutlist-layout-form-group-pins-direction', $modal);
            var $btnGenerate = $('#ladb_cutlist_layout_btn_generate', $modal);

            var fnUpdatePageSizeFieldsAvailability = function () {
                if ($selectPageFormat.selectpicker('val') == null) {
                    $selectPageFormat.selectpicker('val', '0');
                    $inputPageWidth.ladbTextinputDimension('enable');
                    $inputPageHeight.ladbTextinputDimension('enable');
                } else {
                    $inputPageWidth.ladbTextinputDimension('disable');
                    $inputPageHeight.ladbTextinputDimension('disable');
                }
            }
            var fnUpdateFieldsVisibility = function () {
                if ($selectPinsHidden.val() === '1') {
                    $formGroupPins.hide();
                } else {
                    $formGroupPins.show();
                    if ($selectPinsLength.val() === '0') {
                        $formGroupPinsDirection.hide();
                    } else {
                        $formGroupPinsDirection.show();
                    }
                }
            }
            var fnConvertPageSettings = function(pageWidth, pageHeight, callback) {
                rubyCallCommand('core_length_to_float', {
                    page_width: pageWidth,
                    page_height: pageHeight
                }, function (response) {
                    callback(response.page_width, response.page_height);
                });
            }
            var fnConvertToVariableDefs = function (vars) {

                // Generate variableDefs for formula editor
                var variableDefs = [];
                for (var i = 0; i < vars.length; i++) {
                    variableDefs.push({
                        text: vars[i].name,
                        displayText: i18next.t('tab.cutlist.export.' + vars[i].name),
                        type: vars[i].type
                    });
                }

                return variableDefs;
            }
            var fnFetchOptions = function (options) {
                options.page_width = $inputPageWidth.val();
                options.page_height = $inputPageHeight.val();
                options.page_header = $selectPageHeader.val() === '1';
                options.parts_colored = $selectPartsColored.val() === '1';
                options.parts_opacity = parseFloat($selectPartsOpacity.val());
                options.pins_hidden = $selectPinsHidden.val() === '1';
                options.pins_colored = $selectPinsColored.val() === '1';
                options.pins_formula = $textareaPinsFormula.val();
                options.pins_length = parseInt($selectPinsLength.val());
                options.pins_direction = parseInt($selectPinsDirection.val());
                options.camera_view = JSON.parse($inputCameraView.val());
                options.camera_zoom = JSON.parse($inputCameraZoom.val());
                options.camera_target = JSON.parse($inputCameraTarget.val());
                options.explode_factor = $inputExplodeFactor.slider('getValue');
            }
            var fnFillInputs = function (options) {
                $selectPageFormat.selectpicker('val', options.page_width.replace(',', '.') + 'x' + options.page_height.replace(',', '.'));
                $inputPageWidth.val(options.page_width);
                $inputPageHeight.val(options.page_height);
                $selectPageHeader.selectpicker('val', options.page_header ? '1' : '0');
                $selectPartsColored.selectpicker('val', options.parts_colored ? '1' : '0');
                $selectPartsOpacity.selectpicker('val', options.parts_opacity);
                $selectPinsHidden.selectpicker('val', options.pins_hidden ? '1' : '0');
                $selectPinsColored.selectpicker('val', options.pins_colored ? '1' : '0');
                $textareaPinsFormula.ladbTextinputCode('val', [ typeof options.pins_formula == 'string' ? options.pins_formula : '' ]);
                $selectPinsLength.selectpicker('val', options.pins_length);
                $selectPinsDirection.selectpicker('val', options.pins_direction);
                $selectCameraView.selectpicker('val', JSON.stringify(options.camera_view));
                $inputCameraView.val(JSON.stringify(options.camera_view));
                $selectCameraZoom.selectpicker('val', JSON.stringify(options.camera_zoom));
                $inputCameraZoom.val(JSON.stringify(options.camera_zoom));
                $selectCameraTarget.selectpicker('val', JSON.stringify(options.camera_target));
                $inputCameraTarget.val(JSON.stringify(options.camera_target));
                $inputExplodeFactor.slider('setValue', options.explode_factor);
                fnUpdatePageSizeFieldsAvailability();
                fnUpdateFieldsVisibility();
            }

            $widgetPreset.ladbWidgetPreset({
                dialog: that.dialog,
                dictionary: 'cutlist_layout_options',
                fnFetchOptions: fnFetchOptions,
                fnFillInputs: fnFillInputs
            });
            $selectPageFormat.selectpicker(SELECT_PICKER_OPTIONS);
            $inputPageWidth.ladbTextinputDimension({
                resetValue: '210mm'
            });
            $inputPageHeight.ladbTextinputDimension({
                resetValue: '297mm'
            });
            $selectPageHeader.selectpicker(SELECT_PICKER_OPTIONS);
            $selectPartsColored.selectpicker(SELECT_PICKER_OPTIONS);
            $selectPartsOpacity.selectpicker(SELECT_PICKER_OPTIONS);
            $selectPinsHidden.selectpicker(SELECT_PICKER_OPTIONS);
            $selectPinsColored.selectpicker(SELECT_PICKER_OPTIONS);
            $textareaPinsFormula.ladbTextinputCode({
                variableDefs: fnConvertToVariableDefs([
                    { name: 'number', type: 'string' },
                    { name: 'path', type: 'path' },
                    { name: 'instance_name', type: 'string' },
                    { name: 'name', type: 'string' },
                    { name: 'cutting_length', type: 'length' },
                    { name: 'cutting_width', type: 'length' },
                    { name: 'cutting_thickness', type: 'length' },
                    { name: 'edge_cutting_length', type: 'length' },
                    { name: 'edge_cutting_width', type: 'length' },
                    { name: 'bbox_length', type: 'length' },
                    { name: 'bbox_width', type: 'length' },
                    { name: 'bbox_thickness', type: 'length' },
                    { name: 'final_area', type: 'area' },
                    { name: 'material_type', type: 'material-type' },
                    { name: 'material_name', type: 'string' },
                    { name: 'material_description', type: 'string' },
                    { name: 'material_url', type: 'string' },
                    { name: 'description', type: 'string' },
                    { name: 'url', type: 'string' },
                    { name: 'tags', type: 'array' },
                    { name: 'edge_ymin', type: 'edge' },
                    { name: 'edge_ymax', type: 'edge' },
                    { name: 'edge_xmin', type: 'edge' },
                    { name: 'edge_xmax', type: 'edge' },
                    { name: 'face_zmax', type: 'veneer' },
                    { name: 'face_zmin', type: 'veneer' },
                    { name: 'layer', type: 'string' }
                ]),
                snippetDefs: [
                    { name: i18next.t('tab.cutlist.snippet.number'), value: '@number' },
                    { name: i18next.t('tab.cutlist.snippet.name'), value: '@name' },
                    { name: i18next.t('tab.cutlist.snippet.number_and_name'), value: '@number + " - " + @name' },
                    { name: '-' },
                    { name: i18next.t('tab.cutlist.snippet.size'), value: '@bbox_length + " x " + @bbox_width' },
                    { name: i18next.t('tab.cutlist.snippet.area'), value: '@bbox_length * @bbox_width' },
                    { name: i18next.t('tab.cutlist.snippet.volume'), value: '@bbox_length * @bbox_width * @bbox_thickness' },
                    { name: '-' },
                    { name: i18next.t('tab.cutlist.snippet.number_without_hardware'), value: "@number unless @material_type.is_hardware?" },
                ]
            });
            $selectPinsLength.selectpicker(SELECT_PICKER_OPTIONS);
            $selectPinsDirection.selectpicker(SELECT_PICKER_OPTIONS);
            $selectCameraView.selectpicker(SELECT_PICKER_OPTIONS);
            $selectCameraZoom.selectpicker(SELECT_PICKER_OPTIONS);
            $selectCameraTarget.selectpicker(SELECT_PICKER_OPTIONS);
            $inputExplodeFactor.slider(SLIDER_OPTIONS);

            fnFillInputs(layoutOptions);

            // Bind tabs
            $tabs.on('shown.bs.tab', function (e) {
                that.lastLayoutOptionsTab = $(e.target).attr('href').substring('#tab_layout_options_'.length);
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
            $selectPinsHidden.on('changed.bs.select', function (e, clickedIndex, isSelected, previousValue) {
                fnUpdateFieldsVisibility();
            });
            $selectPinsLength.on('changed.bs.select', function (e, clickedIndex, isSelected, previousValue) {
                fnUpdateFieldsVisibility();
            });
            $selectCameraTarget.on('changed.bs.select', function (e, clickedIndex, isSelected, previousValue) {
                $inputCameraTarget.val($(this).val());
            });
            $selectCameraView.on('changed.bs.select', function (e, clickedIndex, isSelected, previousValue) {
                $inputCameraView.val($(this).val());
            });
            $selectCameraZoom.on('changed.bs.select', function (e, clickedIndex, isSelected, previousValue) {
                $inputCameraZoom.val($(this).val());
            });

            // Bind buttons
            $btnGenerate.on('click', function () {

                // Fetch options
                fnFetchOptions(layoutOptions);

                // Store options
                rubyCallCommand('core_set_model_preset', { dictionary: 'cutlist_layout_options', values: layoutOptions, section: section });

                fnConvertPageSettings(layoutOptions.page_width, layoutOptions.page_height, function (pageWidth, pageHeight) {

                    window.requestAnimationFrame(function () {

                        // Start progress feedback
                        that.dialog.startProgress(1);

                        // Generate layout
                        rubyCallCommand('cutlist_layout_parts', {
                            part_ids: partIds,
                            parts_colored: layoutOptions.parts_colored,
                            pins_formula: layoutOptions.pins_formula
                        }, function (response) {

                            var controlsData = {
                                zoom: layoutOptions.camera_zoom,
                                target: layoutOptions.camera_target,
                                exploded_model_radius: 1
                            }

                            var $slide = that.pushNewSlide('ladb_cutlist_slide_layout', 'tabs/cutlist/_slide-layout.twig', {
                                capabilities: that.dialog.capabilities,
                                errors: response.errors,
                                filename: that.filename,
                                modelName: that.modelName,
                                modelDescription: that.modelDescription,
                                modelActivePath: that.modelActivePath,
                                pageName: that.pageName,
                                pageDescription: that.pageDescription,
                                isEntitySelection: that.isEntitySelection,
                                lengthUnit: that.lengthUnit,
                                generatedAt: new Date().getTime() / 1000,
                                group: context.targetGroup,
                                pageHeader: layoutOptions.page_header,
                                THREE_CAMERA_VIEWS: THREE_CAMERA_VIEWS
                            }, function () {

                                // Load frame when slide animation completed
                                $viewer.ladbThreeViewer('loadFrame');

                            });

                            // Fetch UI elements
                            var $btnLayout = $('#ladb_btn_layout', $slide);
                            var $btnPrint = $('#ladb_btn_print', $slide);
                            var $btnExport = $('#ladb_btn_export', $slide);
                            var $btnClose = $('#ladb_btn_close', $slide);
                            var $viewer = $('.ladb-three-viewer', $slide);
                            var $lblScale = $('.ladb-lbl-scale', $slide);

                            // Bind buttons
                            $btnLayout.on('click', function () {
                                that.layoutParts(partIds, context);
                            });
                            $btnPrint.on('click', function () {
                                $(this).blur();
                                that.print(that.cutlistTitle + ' - ' + i18next.t('tab.cutlist.layout.title'), '0', `${pageWidth}in ${pageHeight}in`);
                            });
                            $btnExport.on('click', function () {
                                $(this).blur();

                                window.requestAnimationFrame(function () {

                                    // Start progress feedback
                                    that.dialog.startProgress(1);

                                    $viewer.ladbThreeViewer('callCommand', ['get_exploded_parts_matrices', null, function (data) {

                                        rubyCallCommand('cutlist_layout_to_layout', $.extend({
                                            parts_infos: data.parts_infos,
                                            pins_infos: data.pins_infos,
                                            target_group_id: context && context.targetGroup ? context.targetGroup.id : null,
                                            generated_at: Twig.twig({ data: "{{ generatedAt|date(('default.date_format'|i18next)) }}" }).render({ generatedAt: new Date().getTime() / 1000 })
                                        }, layoutOptions, controlsData), function (response) {

                                            // Finish progress feedback
                                            that.dialog.finishProgress();

                                            if (response.errors) {
                                                that.dialog.notifyErrors(response.errors);
                                            }
                                            if (response.export_path) {
                                                that.dialog.notifySuccess(i18next.t('core.success.exported_to', { path: response.export_path }), [
                                                    Noty.button(i18next.t('default.open'), 'btn btn-default', function () {

                                                        rubyCallCommand('core_open_external_file', {
                                                            path: response.export_path
                                                        });

                                                    })
                                                ]);
                                            }

                                        });

                                    }]);

                                });

                            });
                            $btnClose.on('click', function () {
                                that.popSlide();
                            });
                            $('.ladb-btn-setup-model-units', $slide).on('click', function () {
                                $(this).blur();
                                that.dialog.executeCommandOnTab('settings', 'highlight_panel', { panel:'model' });
                            });

                            // Bind viewer
                            var storeOptionsTimeoutId = null;
                            $viewer.ladbThreeViewer({
                                autoload: false,
                                dialog: that.dialog,
                                modelDef: response.three_model_def,
                                partsColored: layoutOptions.parts_colored,
                                partsOpacity: layoutOptions.parts_opacity,
                                pinsHidden: layoutOptions.pins_hidden,
                                pinsColored: layoutOptions.pins_colored,
                                pinsRounded: typeof layoutOptions.pins_formula != 'string' || layoutOptions.pins_formula.length === 0,
                                pinsLength: layoutOptions.pins_length,
                                pinsDirection: layoutOptions.pins_direction,
                                cameraView: layoutOptions.camera_view,
                                cameraZoom: layoutOptions.camera_zoom,
                                cameraTarget: layoutOptions.camera_target,
                                explodeFactor: layoutOptions.explode_factor,
                            }).on('changed.controls', function (e, data) {

                                layoutOptions.camera_view = data.cameraView;
                                layoutOptions.camera_zoom = data.cameraZoomIsAuto ? null : data.cameraZoom;
                                layoutOptions.camera_target = data.cameraTargetIsAuto ? null : data.cameraTarget;
                                layoutOptions.explode_factor = data.explodeFactor;

                                controlsData.camera_zoom = data.cameraZoom;
                                controlsData.camera_target = data.cameraTarget;
                                controlsData.exploded_model_radius = data.explodedModelRadius;

                                if (data.trigger === 'user') {  // Avoid double storing on viewer init

                                    // Store options (only one time per 500ms)
                                    if (storeOptionsTimeoutId) {
                                        clearTimeout(storeOptionsTimeoutId);
                                    }
                                    storeOptionsTimeoutId = setTimeout(function () {
                                        rubyCallCommand('core_set_model_preset', {
                                            dictionary: 'cutlist_layout_options',
                                            values: layoutOptions,
                                            section: section
                                        });
                                        storeOptionsTimeoutId = null;
                                    }, 500);

                                }

                                var scale;
                                if (data.cameraZoom > 1) {
                                    scale = Number.parseFloat(data.cameraZoom.toFixed(3)) + ':1';
                                } else if (data.cameraZoom < 1) {
                                    scale = '1:' + Number.parseFloat((1 / data.cameraZoom).toFixed(3));
                                } else {
                                    scale = '1:1';
                                }
                                $lblScale.html(scale);

                            });

                            // Bind slide
                            $slide.on('remove', function () {
                                $viewer.ladbThreeViewer('destroy');
                            });

                            var $paperPage = $('.ladb-paper-page', $viewer)
                            if ($paperPage.length > 0 && pageWidth && pageHeight) {

                                $paperPage.outerWidth(pageWidth + 'in');
                                $paperPage.outerHeight(pageHeight + 'in');
                                $paperPage.css('padding', '0.25in');

                                // Scale frame to fit viewer on window resize
                                var fnScaleFrame = function (e) {

                                    // Auto remove listener
                                    if (e && !$paperPage.get(0).isConnected) {

                                        // Unbind window resize event
                                        $(window).off('resize', fnScaleFrame);

                                        // Unbind dialog maximized and minimized events
                                        that.dialog.$element.off('maximized.ladb.dialog', fnScaleFrame);

                                        // Unbind tab shown events
                                        that.$element.off('shown.ladb.tab', fnScaleFrame);

                                        return;
                                    }

                                    if (!$paperPage.is(':visible')) {
                                        return;
                                    }

                                    var spaceIW = $viewer.innerWidth();
                                    var spaceIH = $viewer.innerHeight();
                                    var frameOW = $paperPage.outerWidth();
                                    var frameOH = $paperPage.outerHeight();
                                    var scale = Math.min(
                                        spaceIW / frameOW,
                                        spaceIH / frameOH,
                                        1.0
                                    );

                                    $paperPage.css('transformOrigin', '0 0');
                                    $paperPage.css('transform', `translate(${(spaceIW - frameOW * scale) / 2}px, ${(spaceIH - frameOH * scale) / 2}px) scale(${scale})`);

                                };

                                // Bind window resize event
                                $(window).on('resize', fnScaleFrame);

                                // Bind dialog maximized and minimized events
                                that.dialog.$element.on('maximized.ladb.dialog', fnScaleFrame);

                                // Bind tab shown events
                                that.$element.on('shown.ladb.tab', fnScaleFrame);

                                fnScaleFrame();

                            }

                            // Finish progress feedback
                            that.dialog.finishProgress();

                        });

                    });

                    // Hide modal
                    $modal.modal('hide');

                });

            });

            // Bind modal
            $modal.on('hide.bs.modal', function () {
                $inputExplodeFactor.slider('destroy');
            });

            // Show modal
            $modal.modal('show');

            // Setup popovers
            that.dialog.setupPopovers();

        });

    }

    // Write /////

    LadbTabCutlist.prototype.writeAllParts = function (is2d) {
        let partIdsWithContext = this.grabVisiblePartIdsWithContext(null, REAL_MATERIALS_FILTER);
        this.writeParts(partIdsWithContext.partIds, partIdsWithContext.context, is2d);
    };

    LadbTabCutlist.prototype.writeGroupParts = function (groupId, is2d) {
        let partIdsWithContext = this.grabVisiblePartIdsWithContext(groupId, REAL_MATERIALS_FILTER);
        this.writeParts(partIdsWithContext.partIds, partIdsWithContext.context, is2d);
    };

    LadbTabCutlist.prototype.writePart = function (partId, is2d) {
        var groupAndPart = this.findGroupAndPartById(partId);
        if (groupAndPart) {

            var group = groupAndPart.group;
            var part = groupAndPart.part;

            var isFolder = part.children && part.children.length > 0;
            var isSelected = this.selectionGroupId === group.id && this.selectionPartIds.includes(partId) && this.selectionPartIds.length > 1;

            var partIds;
            if (isFolder) {
                partIds = [ partId ];
            } else if (isSelected) {
                partIds = this.selectionPartIds;
            } else {
                partIds = [ partId ];
            }

            this.writeParts(partIds, null, is2d);

        }
    };

    LadbTabCutlist.prototype.writeParts = function (partIds, context, is2d) {
        var that = this;

        var fileCount = 0;
        for (var i = 0 ; i < partIds.length; i++) {
            var groupAndPart = this.findGroupAndPartById(partIds[i]);
            if (groupAndPart) {
                if (groupAndPart.part.children) {
                    fileCount += groupAndPart.part.children.length;
                } else {
                    fileCount += 1;
                }
            }
        }

        if (fileCount === 0) {
            this.dialog.alert(i18next.t('tab.cutlist.write.title'), i18next.t('tab.cutlist.write.error.no_part'));
            return;
        }

        var section = context && context.targetGroup ? context.targetGroup.id : null;

        if (is2d) {

            // Retrieve write2d options
            rubyCallCommand('core_get_model_preset', { dictionary: 'cutlist_write2d_options', section: section }, function (response) {

                var write2dOptions = response.preset;

                var $modal = that.appendModalInside('ladb_cutlist_modal_write_2d', 'tabs/cutlist/_modal-write-2d.twig', {
                    group: context ? context.targetGroup : null,
                    isGroupSelection: context ? context.isGroupSelection : false,
                    isPartSelection: context ? context.isPartSelection : false,
                });

                // Fetch UI elements
                var $widgetPreset = $('.ladb-widget-preset', $modal);
                var $selectPartDrawingType = $('#ladb_select_part_drawing_type', $modal);
                var $selectFileFormat = $('#ladb_select_file_format', $modal);
                var $selectUnit = $('#ladb_select_unit', $modal);
                var $selectAnchor = $('#ladb_select_anchor', $modal);
                var $selectSmoothing = $('#ladb_select_smoothing', $modal);
                var $selectMergeHoles = $('#ladb_select_merge_holes', $modal);
                var $selectIncludePaths = $('#ladb_select_include_paths', $modal);
                var $inputPartsStrokeColor = $('#ladb_input_parts_stroke_color', $modal);
                var $inputPartsFillColor = $('#ladb_input_parts_fill_color', $modal);
                var $formGroupPartsHoles = $('#ladb_form_group_parts_holes', $modal);
                var $inputPartsHolesStrokeColor = $('#ladb_input_parts_holes_stroke_color', $modal);
                var $inputPartsHolesFillColor = $('#ladb_input_parts_holes_fill_color', $modal);
                var $formGroupPartsPaths = $('#ladb_form_group_parts_paths', that.$element);
                var $inputPartsPathsStrokeColor = $('#ladb_input_parts_paths_stroke_color', that.$element);
                var $btnExport = $('#ladb_btn_export', $modal);

                var fnFetchOptions = function (options) {
                    options.part_drawing_type = $selectPartDrawingType.val();
                    options.file_format = $selectFileFormat.val();
                    options.unit = parseInt($selectUnit.val());
                    options.anchor = $selectAnchor.val() === '1';
                    options.smoothing = $selectSmoothing.val() === '1';
                    options.merge_holes = $selectMergeHoles.val() === '1';
                    options.include_paths = $selectIncludePaths.val() === '1';
                    options.parts_stroke_color = $inputPartsStrokeColor.ladbTextinputColor('val');
                    options.parts_fill_color = $inputPartsFillColor.ladbTextinputColor('val');
                    options.parts_holes_stroke_color = $inputPartsHolesStrokeColor.ladbTextinputColor('val');
                    options.parts_holes_fill_color = $inputPartsHolesFillColor.ladbTextinputColor('val');
                    options.parts_paths_stroke_color = $inputPartsPathsStrokeColor.ladbTextinputColor('val');
                };
                var fnFillInputs = function (options) {
                    $selectPartDrawingType.selectpicker('val', options.part_drawing_type);
                    $selectFileFormat.selectpicker('val', options.file_format);
                    $selectUnit.selectpicker('val', options.unit);
                    $selectAnchor.selectpicker('val', options.anchor ? '1' : '0');
                    $selectSmoothing.selectpicker('val', options.smoothing ? '1' : '0');
                    $selectMergeHoles.selectpicker('val', options.merge_holes ? '1' : '0');
                    $selectIncludePaths.selectpicker('val', options.include_paths ? '1' : '0');
                    $inputPartsStrokeColor.ladbTextinputColor('val', options.parts_stroke_color);
                    $inputPartsFillColor.ladbTextinputColor('val', options.parts_fill_color);
                    $inputPartsHolesStrokeColor.ladbTextinputColor('val', options.parts_holes_stroke_color);
                    $inputPartsHolesFillColor.ladbTextinputColor('val', options.parts_holes_fill_color);
                    $inputPartsPathsStrokeColor.ladbTextinputColor('val', options.parts_paths_stroke_color);
                    fnUpdateFieldsVisibility();
                };
                var fnUpdateFieldsVisibility = function () {
                    var isDxf = $selectFileFormat.val() === 'dxf';
                    var isMergeHoles = $selectMergeHoles.val() === '1';
                    var isIncludePaths = $selectIncludePaths.val() === '1';
                    if (!isMergeHoles) $formGroupPartsHoles.hide(); else $formGroupPartsHoles.show();
                    $inputPartsHolesStrokeColor.ladbTextinputColor(!isMergeHoles ? 'disable' : 'enable');
                    $inputPartsHolesFillColor.ladbTextinputColor(!isMergeHoles ? 'disable' : 'enable');
                    if (!isIncludePaths) $formGroupPartsPaths.hide(); else $formGroupPartsPaths.show();
                    $inputPartsPathsStrokeColor.ladbTextinputColor(!isIncludePaths ? 'disable' : 'enable');
                    $('.ladb-form-fill-color').css('opacity', isDxf ? 0.3 : 1);
                };

                $widgetPreset.ladbWidgetPreset({
                    dialog: that.dialog,
                    dictionary: 'cutlist_write2d_options',
                    fnFetchOptions: fnFetchOptions,
                    fnFillInputs: fnFillInputs
                });
                $selectPartDrawingType.selectpicker(SELECT_PICKER_OPTIONS);
                $selectFileFormat
                    .selectpicker(SELECT_PICKER_OPTIONS)
                    .on('changed.bs.select', function () {
                        $('#ladb_btn_export_file_format', $btnExport).html($(this).val().toUpperCase() + ' <small>( ' + fileCount + ' ' + i18next.t('default.file', { count: fileCount }).toLowerCase() + ' )</small>');
                        fnUpdateFieldsVisibility();
                    })
                ;
                $selectUnit.selectpicker(SELECT_PICKER_OPTIONS);
                $selectAnchor.selectpicker(SELECT_PICKER_OPTIONS);
                $selectSmoothing.selectpicker(SELECT_PICKER_OPTIONS);
                $selectMergeHoles.selectpicker(SELECT_PICKER_OPTIONS).on('changed.bs.select', fnUpdateFieldsVisibility);
                $selectIncludePaths.selectpicker(SELECT_PICKER_OPTIONS).on('changed.bs.select', fnUpdateFieldsVisibility);
                $inputPartsStrokeColor.ladbTextinputColor(TEXTINPUT_COLOR_OPTIONS);
                $inputPartsFillColor.ladbTextinputColor(TEXTINPUT_COLOR_OPTIONS);
                $inputPartsHolesStrokeColor.ladbTextinputColor(TEXTINPUT_COLOR_OPTIONS);
                $inputPartsHolesFillColor.ladbTextinputColor(TEXTINPUT_COLOR_OPTIONS);
                $inputPartsPathsStrokeColor.ladbTextinputColor(TEXTINPUT_COLOR_OPTIONS);

                fnFillInputs(write2dOptions);

                // Bind buttons
                $btnExport.on('click', function () {

                    // Fetch options
                    fnFetchOptions(write2dOptions);

                    // Store options
                    rubyCallCommand('core_set_model_preset', { dictionary: 'cutlist_write2d_options', values: write2dOptions, section: section });

                    rubyCallCommand('cutlist_write_parts', $.extend(write2dOptions, {
                        part_ids: partIds,
                    }), function (response) {

                        if (response.errors) {
                            that.dialog.notifyErrors(response.errors);
                        }
                        if (response.export_path) {
                            that.dialog.notifySuccess(i18next.t('core.success.exported_to', {path: response.export_path}), [
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

                // Setup popovers
                that.dialog.setupPopovers();

            });

        } else {

            // Retrieve write3d options
            rubyCallCommand('core_get_model_preset', { dictionary: 'cutlist_write3d_options', section: section }, function (response) {

                var write3dOptions = response.preset;

                var $modal = that.appendModalInside('ladb_cutlist_modal_write_3d', 'tabs/cutlist/_modal-write-3d.twig', {
                    group: context ? context.targetGroup : null,
                    isGroupSelection: context ? context.isGroupSelection : false,
                    isPartSelection: context ? context.isPartSelection : false,
                });

                // Fetch UI elements
                var $widgetPreset = $('.ladb-widget-preset', $modal);
                var $selectFileFormat = $('#ladb_select_file_format', $modal);
                var $formGroupUnit = $('#ladb_form_group_unit', $modal);
                var $selectUnit = $('#ladb_select_unit', $modal);
                var $formGroupAnchor = $('#ladb_form_group_anchor', $modal);
                var $selectAnchor = $('#ladb_select_anchor', $modal);
                var $btnExport = $('#ladb_btn_export', $modal);

                var fnFetchOptions = function (options) {
                    options.file_format = $selectFileFormat.val();
                    options.unit = parseInt($selectUnit.val());
                    options.anchor = $selectAnchor.val() === '1';
                };
                var fnFillInputs = function (options) {
                    $selectFileFormat.selectpicker('val', options.file_format);
                    $selectUnit.selectpicker('val', options.unit);
                    $selectAnchor.selectpicker('val', options.anchor ? '1' : '0');
                    fnUpdateFieldsVisibility();
                };
                var fnUpdateFieldsVisibility = function () {
                    var isSkp = $selectFileFormat.val() === 'skp';
                    if (isSkp) $formGroupUnit.hide(); else $formGroupUnit.show();
                    if (isSkp) $formGroupAnchor.hide(); else $formGroupAnchor.show();
                };

                $widgetPreset.ladbWidgetPreset({
                    dialog: that.dialog,
                    dictionary: 'cutlist_write3d_options',
                    fnFetchOptions: fnFetchOptions,
                    fnFillInputs: fnFillInputs
                });
                $selectFileFormat
                    .selectpicker(SELECT_PICKER_OPTIONS)
                    .on('changed.bs.select', function () {
                        $('#ladb_btn_export_file_format', $btnExport).html($(this).val().toUpperCase() + ' <small>( ' + fileCount + ' ' + i18next.t('default.file', {count: fileCount}).toLowerCase() + ' )</small>');
                        fnUpdateFieldsVisibility();
                    })
                ;
                $selectUnit.selectpicker(SELECT_PICKER_OPTIONS);
                $selectAnchor.selectpicker(SELECT_PICKER_OPTIONS);

                fnFillInputs(write3dOptions);

                // Bind buttons
                $btnExport.on('click', function () {

                    // Fetch options
                    fnFetchOptions(write3dOptions);

                    // Store options
                    rubyCallCommand('core_set_model_preset', { dictionary: 'cutlist_write3d_options', values: write3dOptions, section: section });

                    rubyCallCommand('cutlist_write_parts', $.extend(write3dOptions, {
                        part_ids: partIds,
                        part_drawing_type: 3 // PART_DRAWING_TYPE_3D
                    }), function (response) {

                        if (response.errors) {
                            that.dialog.notifyErrors(response.errors);
                        }
                        if (response.export_path) {
                            that.dialog.notifySuccess(i18next.t('core.success.exported_to', {path: response.export_path}), [
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

                // Setup popovers
                that.dialog.setupPopovers();

            });

        }

    };

    // Parts /////

    LadbTabCutlist.prototype.grabVisiblePartIdsWithContext = function (groupId, materialFilter) {
        var that = this;

        let partIds = [];
        let targetGroup = null;
        let isGroupSelection = false;
        let isPartSelection = false;

        let fnIsGroupExcluded = function (group) {
            return materialFilter && !materialFilter.includes(group.material_type);
        };
        let fnGrabFromGroup = function (group) {

            if (fnIsGroupExcluded(group)) {
                return;
            }

            if (that.generateOptions.hidden_group_ids.indexOf(group.id) >= 0) {
                isGroupSelection = true;
                return;
            }

            for (let part of group.parts) {
                partIds.push(part.id);
            }

        };

        if (groupId) {

            targetGroup = this.findGroupById(groupId);
            if (targetGroup && !fnIsGroupExcluded(targetGroup)) {

                if (this.selectionGroupId === groupId && this.selectionPartIds.length > 0) {

                    isPartSelection = true;

                    // Take only selected parts
                    partIds = this.selectionPartIds;

                } else {

                    // Take all part from the group
                    fnGrabFromGroup(targetGroup);

                }

            }

        } else {

            // Grab from all visible groups
            for (let group of this.groups) {
                fnGrabFromGroup(group);
            }

        }

        return {
            partIds: partIds,
            context: {
                targetGroup: targetGroup,
                isGroupSelection: isGroupSelection,
                isPartSelection: isPartSelection,
            }
        }
    }

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
        var defs = [ 'cuttingdiagram1d', 'cuttingdiagram2d', 'labels', 'layout' ];
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
                .prop('title', i18next.t('tab.cutlist.tooltip.edit_parts_properties') + '...')
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
                    .prop('title', i18next.t('tab.cutlist.tooltip.edit_part_properties') + '...')
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
                var materialName = null;
                if (ownedMaterialCount === editedParts[i].material_origins.length) {
                    materialName = editedPart.material_name;
                } else if (ownedMaterialCount > 0) {
                    materialName = MULTIPLE_VALUE;
                }
                if (i === 0) {
                    editedPart.material_name = materialName;
                } else {
                    if (editedPart.material_name !== materialName) {
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
                if (editedPart.thickness_layer_count !== editedParts[i].thickness_layer_count) {
                    editedPart.thickness_layer_count = MULTIPLE_VALUE;
                }
                if (editedPart.description !== editedParts[i].description) {
                    editedPart.description = MULTIPLE_VALUE;
                }
                if (editedPart.url !== editedParts[i].url) {
                    editedPart.url = MULTIPLE_VALUE;
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
                if (editedPart.face_material_names.zmin !== editedParts[i].face_material_names.zmin) {
                    editedPart.face_material_names.zmin = MULTIPLE_VALUE;
                }
                if (editedPart.face_material_names.zmax !== editedParts[i].face_material_names.zmax) {
                    editedPart.face_material_names.zmax = MULTIPLE_VALUE;
                }
                if (editedPart.face_texture_angles.zmin !== editedParts[i].face_texture_angles.zmin) {
                    editedPart.face_texture_angles.zmin = MULTIPLE_VALUE;
                }
                if (editedPart.face_texture_angles.zmax !== editedParts[i].face_texture_angles.zmax) {
                    editedPart.face_texture_angles.zmax = MULTIPLE_VALUE;
                }
            }

            if (tab === undefined) {
                tab = this.lastEditPartTab;
            }
            if (tab === null || tab.length === 0
                || tab === 'extra' && group.material_type === 0 /* 0 = TYPE_UNKNOWN */ || part.virtual
                || tab === 'axes' && (multiple || part.virtual)
                || tab === 'edges' && group.material_type !== 2 /* 2 = TYPE_SHEET_GOOD */
                || tab === 'faces' && group.material_type !== 2 /* 2 = TYPE_SHEET_GOOD */
                || tab === 'infos_warnings' && (multiple || part.virtual)
            ) {
                tab = 'general';
            }
            this.lastEditPartTab = tab;

            var $modal = that.appendModalInside('ladb_cutlist_modal_part', 'tabs/cutlist/_modal-part.twig', {
                group: group,
                part: editedPart,
                partCount: editedParts.length,
                multiple: multiple,
                materialUsages: that.materialUsages,
                tab: tab
            });

            // Fetch UI elements
            var $tabs = $('a[data-toggle="tab"]', $modal);
            var $divPartThumbnail = $('#ladb_cutlist_part_thumbnail', $modal);
            var $inputName = $('#ladb_cutlist_part_input_name', $modal);
            var $selectMaterialName = $('#ladb_cutlist_part_select_material_name', $modal);
            var $selectCumulable = $('#ladb_cutlist_part_select_cumulable', $modal);
            var $inputInstanceCountByPart = $('#ladb_cutlist_part_input_instance_count_by_part', $modal);
            var $inputMass = $('#ladb_cutlist_part_input_mass', $modal);
            var $inputPrice = $('#ladb_cutlist_part_input_price', $modal);
            var $inputThicknessLayerCount = $('#ladb_cutlist_part_input_thickness_layer_count', $modal);
            var $inputDescription = $('#ladb_cutlist_part_input_description', $modal);
            var $inputUrl = $('#ladb_cutlist_part_input_url', $modal);
            var $inputTags = $('#ladb_cutlist_part_input_tags', $modal);
            var $inputOrientationLockedOnAxis = $('#ladb_cutlist_part_input_orientation_locked_on_axis', $modal);
            var $inputSymmetrical = $('#ladb_cutlist_part_input_symmetrical', $modal);
            var $inputIgnoreGrainDirection = $('#ladb_cutlist_part_input_ignore_grain_direction', $modal);
            var $inputPartAxes = $('#ladb_cutlist_part_input_axes', $modal);
            var $sortableAxes = $('#ladb_sortable_axes', $modal);
            var $sortablePartAxes = $('#ladb_sortable_part_axes', $modal);
            var $sortablePartAxesExtra = $('#ladb_sortable_part_axes_extra', $modal);
            var $selectPartAxesOriginPosition = $('#ladb_cutlist_part_select_axes_origin_position', $modal);
            var $inputLengthIncrease = $('#ladb_cutlist_part_input_length_increase', $modal);
            var $inputWidthIncrease = $('#ladb_cutlist_part_input_width_increase', $modal);
            var $inputThicknessIncrease = $('#ladb_cutlist_part_input_thickness_increase', $modal);
            var $selectEdgeYmax = $('#ladb_cutlist_part_select_edge_ymax', $modal);
            var $selectEdgeYmin = $('#ladb_cutlist_part_select_edge_ymin', $modal);
            var $selectEdgeXmin = $('#ladb_cutlist_part_select_edge_xmin', $modal);
            var $selectEdgeXmax = $('#ladb_cutlist_part_select_edge_xmax', $modal);
            var $selectFaceZmin = $('#ladb_cutlist_part_select_face_zmin', $modal);
            var $selectFaceZmax = $('#ladb_cutlist_part_select_face_zmax', $modal);
            var $formGroupFaceZminTextureAngle = $('#ladb_cutlist_part_form_group_face_zmin_texture_angle', $modal);
            var $formGroupFaceZmaxTextureAngle = $('#ladb_cutlist_part_form_group_face_zmax_texture_angle', $modal);
            var $inputFaceZminTextureAngle = $('#ladb_cutlist_part_input_face_zmin_texture_angle', $modal);
            var $inputFaceZmaxTextureAngle = $('#ladb_cutlist_part_input_face_zmax_texture_angle', $modal);
            var $rectIncreaseLength = $('svg .increase-length', $modal);
            var $rectIncreaseWidth = $('svg .increase-width', $modal);
            var $rectEdgeYmin = $('svg .edge-ymin', $modal);
            var $rectEdgeYmax = $('svg .edge-ymax', $modal);
            var $rectEdgeXmin = $('svg .edge-xmin', $modal);
            var $rectEdgeXmax = $('svg .edge-xmax', $modal);
            var $rectFaceZmin = $('svg .face-zmin', $modal);
            var $rectFaceZmax = $('svg .face-zmax', $modal);
            var $rectFaceZminGrain = $('svg .face-zmin .face-grain', $modal);
            var $rectFaceZmaxGrain = $('svg .face-zmax .face-grain', $modal);
            var $patternFaceZminGrain = $('#pattern_face_zmin_grain', $modal);
            var $patternFaceZmaxGrain = $('#pattern_face_zmax_grain', $modal);
            var $labelEdgeYmax = $('#ladb_cutlist_part_label_edge_ymax', $modal);
            var $labelEdgeYmin = $('#ladb_cutlist_part_label_edge_ymin', $modal);
            var $labelEdgeXmin = $('#ladb_cutlist_part_label_edge_xmin', $modal);
            var $labelEdgeXmax = $('#ladb_cutlist_part_label_edge_xmax', $modal);
            var $labelFaceZmin = $('#ladb_cutlist_part_label_face_zmin', $modal);
            var $labelFaceZmax = $('#ladb_cutlist_part_label_face_zmax', $modal);
            var $labelFaceZminTextureAngle = $('#ladb_cutlist_part_label_face_zmin_texture_angle', $modal);
            var $labelFaceZmaxTextureAngle = $('#ladb_cutlist_part_label_face_zmax_texture_angle', $modal);
            var $btnHighlight = $('#ladb_cutlist_part_highlight', $modal);
            var $btnExportToFile = $('a.ladb-cutlist-write-parts', $modal);
            var $btnUpdate = $('#ladb_cutlist_part_update', $modal);

            var thumbnailLoaded = false;

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
                if ($selectEdgeYmax.val() === '') {
                    $rectEdgeYmax.removeClass('ladb-active');
                } else {
                    $rectEdgeYmax.addClass('ladb-active');
                }
                if ($selectEdgeYmin.val() === '') {
                    $rectEdgeYmin.removeClass('ladb-active');
                } else {
                    $rectEdgeYmin.addClass('ladb-active');
                }
                if ($selectEdgeXmin.val() === '') {
                    $rectEdgeXmin.removeClass('ladb-active');
                } else {
                    $rectEdgeXmin.addClass('ladb-active');
                }
                if ($selectEdgeXmax.val() === '') {
                    $rectEdgeXmax.removeClass('ladb-active');
                } else {
                    $rectEdgeXmax.addClass('ladb-active');
                }
            };
            var fnIsMaterialTexturedAndGrained = function(name) {
                for (let materialUsage of that.materialUsages) {
                    if (materialUsage.name === name) {
                        return materialUsage.textured && materialUsage.grained;
                    }
                }
                return false;
            };
            var fnUpdateFacesPreview = function() {
                if ($selectFaceZmin.val() === '') {
                    $rectFaceZmin.removeClass('ladb-active');
                    $rectFaceZminGrain.hide();
                    $formGroupFaceZminTextureAngle.hide();
                } else {
                    $rectFaceZmin.addClass('ladb-active');
                    if (editedPart.face_texture_angles.zmin != null && fnIsMaterialTexturedAndGrained($selectFaceZmin.val())) {
                        $rectFaceZminGrain.show();
                        $patternFaceZminGrain.attr('patternTransform', 'rotate(' + $inputFaceZminTextureAngle.val() + ' 0 0)');
                        $formGroupFaceZminTextureAngle.show();
                    } else {
                        $rectFaceZminGrain.hide();
                        $formGroupFaceZminTextureAngle.hide();
                    }
                }
                if ($selectFaceZmax.val() === '') {
                    $rectFaceZmax.removeClass('ladb-active');
                    $rectFaceZmaxGrain.hide();
                    $formGroupFaceZmaxTextureAngle.hide();
                } else {
                    $rectFaceZmax.addClass('ladb-active');
                    if (editedPart.face_texture_angles.zmax != null && fnIsMaterialTexturedAndGrained($selectFaceZmax.val())) {
                        $rectFaceZmaxGrain.show();
                        $patternFaceZmaxGrain.attr('patternTransform', 'rotate(' + parseInt($inputFaceZmaxTextureAngle.val()) * -1 + ' 0 0)');
                        $formGroupFaceZmaxTextureAngle.show();
                    } else {
                        $rectFaceZmaxGrain.hide();
                        $formGroupFaceZmaxTextureAngle.hide();
                    }
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
                    if (!$selectEdgeYmax.prop('disabled')) {
                        $selectEdgeYmax.selectpicker('val', materialName);
                    }
                    if (!$selectEdgeYmin.prop('disabled')) {
                        $selectEdgeYmin.selectpicker('val', materialName);
                    }
                    if (!$selectEdgeXmin.prop('disabled')) {
                        $selectEdgeXmin.selectpicker('val', materialName);
                    }
                    if (!$selectEdgeXmax.prop('disabled')) {
                        $selectEdgeXmax.selectpicker('val', materialName);
                    }
                    fnUpdateEdgesPreview();
                }
            };
            var fnMaterialNameCopyToAllVeneers = function(materialName) {
                if (materialName !== MULTIPLE_VALUE) {
                    if (!$selectFaceZmax.prop('disabled')) {
                        $selectFaceZmax.selectpicker('val', materialName);
                    }
                    if (!$selectFaceZmin.prop('disabled')) {
                        $selectFaceZmin.selectpicker('val', materialName);
                    }
                    fnUpdateFacesPreview();
                }
            };
            var fnIncrementVeneerTextureAngleInputValue = function($input, inc) {
                let angle = parseInt($input.val());
                if (!isNaN(angle)) {
                    $input.val((angle + inc) % 360);
                    fnUpdateFacesPreview();
                }
            }
            var fnOnAxiesOrderChanged = function () {
                var axes = fnComputeAxesOrder();

                var oriented = editedPart.axes_to_values[axes[0]] >= editedPart.axes_to_values[axes[1]]
                    &&  editedPart.axes_to_values[axes[1]] >= editedPart.axes_to_values[axes[2]];

                // Check Orientation Locked On Axis option if needed
                $inputOrientationLockedOnAxis.prop('checked', !oriented);
                fnDisplayAxisDimensions();

                // By default set origin position to 'min'
                $selectPartAxesOriginPosition
                    .selectpicker('val', 'min')
                    .trigger('change')
                ;

            }
            var fnLoadThumbnail = function () {
                if (!thumbnailLoaded && !multiple && !part.virtual) {

                    // Generate and Retrieve part thumbnail file
                    rubyCallCommand('cutlist_part_get_thumbnail', part, function (response) {

                        var threeModelDef = response['three_model_def'];
                        var thumbnailFile = response['thumbnail_file'];

                        if (threeModelDef) {

                            var $viewer = $(Twig.twig({ref: 'tabs/cutlist/_three-viewer-modal-part.twig'}).render({
                                THREE_CAMERA_VIEWS: THREE_CAMERA_VIEWS,
                                group: group,
                                part: part
                            }));

                            $viewer.ladbThreeViewer({
                                dialog: that.dialog,
                                modelDef: threeModelDef,
                                partsColored: true,
                                partsOpacity: 0.8,
                                pinsHidden: true,
                                showBoxHelper: part.not_aligned_on_axes
                            });

                            $divPartThumbnail.html($viewer);

                        } else if (thumbnailFile) {

                                var $img = $('<img>')
                                    .attr('src', thumbnailFile)
                                ;
                                if (part.flipped) {
                                    $img
                                        .css('transform', 'scaleX(-1)')
                                    ;
                                }

                                $divPartThumbnail.html($img);

                        } else {
                            if (response['errors']) {
                                that.dialog.notifyErrors(response['errors']);
                            }
                            $divPartThumbnail.hide();
                        }

                        thumbnailLoaded = true;

                    });

                }
            }

            fnDisplayAxisDimensions();
            fnUpdateIncreasesPreview();

            if (tab === 'general') {
                fnLoadThumbnail();
            }

            // Bind tabs
            $tabs.on('shown.bs.tab', function (e) {
                that.lastEditPartTab = $(e.target).attr('href').substring('#tab_edit_part_'.length);
                if (that.lastEditPartTab === 'general') {
                    fnLoadThumbnail();
                }
            });

            // Bind input
            $inputName.ladbTextinputText();
            $inputInstanceCountByPart.ladbTextinputNumberWithUnit({
                resetValue: '1',
                defaultUnit: 'u_p',
                units: [
                    { u_p: i18next.t('default.instance_plural') + ' / ' + i18next.t('default.part_single') },
                ]
            });
            $inputMass.ladbTextinputNumberWithUnit({
                resetValue: ' ',
                defaultUnit: that.massUnitStrippedname + '_p',
                units: [
                    { kg_p: 'kg / ' + i18next.t('default.part_single') },
                    { lb_p: 'lb / ' + i18next.t('default.part_single') }
                ]
            });
            $inputPrice.ladbTextinputNumberWithUnit({
                resetValue: ' ',
                defaultUnit: '$_p',
                units: [
                    { $_p: that.currencySymbol + ' / ' + i18next.t('default.part_single') }
                ]
            });
            $inputThicknessLayerCount.ladbTextinputNumberWithUnit({
                resetValue: '1'
            });
            $inputDescription.ladbTextinputArea();
            $inputUrl.ladbTextinputUrl();
            $inputTags.ladbTextinputTokenfield({
                unique: true,
                autocomplete: {
                    source: that.usedTags.concat(that.generateOptions.tags).unique(),
                    delay: 100
                }
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
            $inputFaceZminTextureAngle
                .ladbTextinputNumberWithUnit({
                    resetValue: 0,
                    defaultUnit: 'deg',
                    units: [
                        { deg: i18next.t('default.unit_angle_0') }
                    ]
                })
                .on('change', function () {
                    fnUpdateFacesPreview();
                });
            $inputFaceZmaxTextureAngle
                .ladbTextinputNumberWithUnit({
                    resetValue: 0,
                    defaultUnit: 'deg',
                    units: [
                        { deg: i18next.t('default.unit_angle_0') }
                    ]
                })
                .on('change', function () {
                    fnUpdateFacesPreview();
                });

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
            $selectEdgeYmin.val(editedPart.edge_material_names.ymin);
            $selectEdgeYmin
                .selectpicker(SELECT_PICKER_OPTIONS)
                .on('changed.bs.select', function (e, clickedIndex, isSelected, previousValue) {
                    if (!fnNewCheck($(this), 4 /* TYPE_EDGE */)) {
                        fnUpdateEdgesPreview();
                    }
                });
            $selectEdgeYmax.val(editedPart.edge_material_names.ymax);
            $selectEdgeYmax
                .selectpicker(SELECT_PICKER_OPTIONS)
                .on('changed.bs.select', function (e, clickedIndex, isSelected, previousValue) {
                    if (!fnNewCheck($(this), 4 /* TYPE_EDGE */)) {
                        fnUpdateEdgesPreview();
                    }
                });
            $selectEdgeXmin.val(editedPart.edge_material_names.xmin);
            $selectEdgeXmin
                .selectpicker(SELECT_PICKER_OPTIONS)
                .on('changed.bs.select', function (e, clickedIndex, isSelected, previousValue) {
                    if (!fnNewCheck($(this), 4 /* TYPE_EDGE */)) {
                        fnUpdateEdgesPreview();
                    }
                });
            $selectEdgeXmax.val(editedPart.edge_material_names.xmax);
            $selectEdgeXmax
                .selectpicker(SELECT_PICKER_OPTIONS)
                .on('changed.bs.select', function (e, clickedIndex, isSelected, previousValue) {
                    if (!fnNewCheck($(this), 4 /* TYPE_EDGE */)) {
                        fnUpdateEdgesPreview();
                    }
                });
            $selectFaceZmin.val(editedPart.face_material_names.zmin);
            $selectFaceZmin
                .selectpicker(SELECT_PICKER_OPTIONS)
                .on('changed.bs.select', function (e, clickedIndex, isSelected, previousValue) {
                    if (!fnNewCheck($(this), 6 /* TYPE_VENEER */)) {
                        fnUpdateFacesPreview();
                    }
                });
            $selectFaceZmax.val(editedPart.face_material_names.zmax);
            $selectFaceZmax
                .selectpicker(SELECT_PICKER_OPTIONS)
                .on('changed.bs.select', function (e, clickedIndex, isSelected, previousValue) {
                    if (!fnNewCheck($(this), 6 /* TYPE_VENEER */)) {
                        fnUpdateFacesPreview();
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
                $selectEdgeYmin.selectpicker('toggle');
            });
            $rectEdgeYmax.on('click', function() {
                $selectEdgeYmax.selectpicker('toggle');
            });
            $rectEdgeXmin.on('click', function() {
                $selectEdgeXmin.selectpicker('toggle');
            });
            $rectEdgeXmax.on('click', function() {
                $selectEdgeXmax.selectpicker('toggle');
            });

            // Bind faces
            $rectFaceZmin.on('click', function() {
                $selectFaceZmin.selectpicker('toggle');
            });
            $rectFaceZmax.on('click', function() {
                $selectFaceZmax.selectpicker('toggle');
            });

            // Bind sorter
            $sortableAxes.on('dblclick', function () {
               var sortedNormals = Object.keys(editedPart.axes_to_values).sort(function (a, b) {
                   return editedPart.axes_to_values[b] - editedPart.axes_to_values[a]
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
                fnMaterialNameCopyToAllEdges($selectEdgeYmax.val());
            });
            $labelEdgeYmin.on('dblclick', function() {
                fnMaterialNameCopyToAllEdges($selectEdgeYmin.val());
            });
            $labelEdgeXmin.on('dblclick', function() {
                fnMaterialNameCopyToAllEdges($selectEdgeXmin.val());
            });
            $labelEdgeXmax.on('dblclick', function() {
                fnMaterialNameCopyToAllEdges($selectEdgeXmax.val());
            });
            $labelFaceZmin.on('dblclick', function() {
                fnMaterialNameCopyToAllVeneers($selectFaceZmin.val());
            });
            $labelFaceZmax.on('dblclick', function() {
                fnMaterialNameCopyToAllVeneers($selectFaceZmax.val());
            });
            $labelFaceZminTextureAngle.on('click', function() {
                fnIncrementVeneerTextureAngleInputValue($inputFaceZminTextureAngle, 90);
            });
            $labelFaceZmaxTextureAngle.on('click', function() {
                fnIncrementVeneerTextureAngleInputValue($inputFaceZmaxTextureAngle, 90);
            });

            // Bind buttons
            $btnHighlight.on('click', function () {
                this.blur();
                that.highlightPart(part.id);
                return false;
            });
            $btnExportToFile.on('click', function () {
                this.blur();
                that.writePart(part.id, $(this).data('is-2d'));
            });
            $btnUpdate.on('click', function () {

                for (var i = 0; i < editedParts.length; i++) {

                    if (!multiple && !part.virtual) {

                        editedParts[i].name = $inputName.val().trim();

                        editedParts[i].orientation_locked_on_axis = $inputOrientationLockedOnAxis.is(':checked');
                        editedParts[i].symmetrical = $inputSymmetrical.is(':checked');
                        editedParts[i].ignore_grain_direction = $inputIgnoreGrainDirection.is(":checked");
                        editedParts[i].axes_order = $inputPartAxes.val().length > 0 ? $inputPartAxes.val().split(',') : [];
                        editedParts[i].axes_origin_position = $selectPartAxesOriginPosition.val();

                    }

                    if ($selectMaterialName.val() !== MULTIPLE_VALUE) {
                        editedParts[i].material_name = $selectMaterialName.val();
                    }

                    if (!part.virtual) {

                        if ($selectCumulable.val() !== MULTIPLE_VALUE) {
                            editedParts[i].cumulable = parseInt($selectCumulable.val());
                        }
                        if (!$inputInstanceCountByPart.ladbTextinputNumberWithUnit('isMultiple')) {
                            editedParts[i].instance_count_by_part = Math.max(1, $inputInstanceCountByPart.val() === '' ? 1 : parseInt($inputInstanceCountByPart.val()));
                        }
                        if (!$inputMass.ladbTextinputNumberWithUnit('isMultiple')) {
                            editedParts[i].mass = $inputMass.ladbTextinputNumberWithUnit('val');
                        }
                        if (!$inputPrice.ladbTextinputNumberWithUnit('isMultiple')) {
                            editedParts[i].price = $inputPrice.val().trim();
                        }
                        if (!$inputThicknessLayerCount.ladbTextinputNumberWithUnit('isMultiple')) {
                            editedParts[i].thickness_layer_count = Math.max(1, $inputThicknessLayerCount.val() === '' ? 1 : parseInt($inputThicknessLayerCount.val()));
                        }
                        if (!$inputDescription.ladbTextinputArea('isMultiple')) {
                            editedParts[i].description = $inputDescription.val().trim();
                        }
                        if (!$inputUrl.ladbTextinputUrl('isMultiple')) {
                            editedParts[i].url = $inputUrl.val().trim();
                        }

                        var untouchTags = editedParts[i].tags.filter(function (tag) {
                            return !editedPart.tags.includes(tag)
                        });
                        editedParts[i].tags = untouchTags.concat($inputTags.tokenfield('getTokensList').split(';'));

                        if (!$inputLengthIncrease.ladbTextinputDimension('isMultiple')) {
                            editedParts[i].length_increase = $inputLengthIncrease.val();
                        }
                        if (!$inputWidthIncrease.ladbTextinputDimension('isMultiple')) {
                            editedParts[i].width_increase = $inputWidthIncrease.val();
                        }
                        if (!$inputThicknessIncrease.ladbTextinputDimension('isMultiple')) {
                            editedParts[i].thickness_increase = $inputThicknessIncrease.val();
                        }

                        if ($selectEdgeYmin.val() !== MULTIPLE_VALUE) {
                            editedParts[i].edge_material_names.ymin = $selectEdgeYmin.val();
                        }
                        if ($selectEdgeYmax.val() !== MULTIPLE_VALUE) {
                            editedParts[i].edge_material_names.ymax = $selectEdgeYmax.val();
                        }
                        if ($selectEdgeXmin.val() !== MULTIPLE_VALUE) {
                            editedParts[i].edge_material_names.xmin = $selectEdgeXmin.val();
                        }
                        if ($selectEdgeXmax.val() !== MULTIPLE_VALUE) {
                            editedParts[i].edge_material_names.xmax = $selectEdgeXmax.val();
                        }

                        if ($selectFaceZmin.val() !== MULTIPLE_VALUE) {
                            editedParts[i].face_material_names.zmin = $selectFaceZmin.val();
                        }
                        if ($selectFaceZmax.val() !== MULTIPLE_VALUE) {
                            editedParts[i].face_material_names.zmax = $selectFaceZmax.val();
                        }

                        if (!$inputFaceZminTextureAngle.ladbTextinputNumberWithUnit('isMultiple')) {
                            editedParts[i].face_texture_angles.zmin = $inputFaceZminTextureAngle.val() === '' ? null : parseInt($inputFaceZminTextureAngle.val());
                        }
                        if (!$inputFaceZmaxTextureAngle.ladbTextinputNumberWithUnit('isMultiple')) {
                            editedParts[i].face_texture_angles.zmax = $inputFaceZmaxTextureAngle.val() === '' ? null : parseInt($inputFaceZmaxTextureAngle.val());
                        }

                    }

                }

                rubyCallCommand('cutlist_part_update', { auto_orient: that.generateOptions.auto_orient, parts_data: editedParts }, function (response) {

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

            // Bind modal
            $modal.on('hide.bs.modal', function () {
                $inputTags.ladbTextinputTokenfield('destroy');
            });

            // Init edges preview
            fnUpdateEdgesPreview();

            // Init faces preview
            fnUpdateFacesPreview();

            // Show modal
            $modal.modal('show');

            // Setup popovers and tooltips
            that.dialog.setupPopovers();
            that.dialog.setupTooltips();

            // Change event
            $('input, select', $modal).on('change', function () {
                $btnExportToFile.prop('disabled', true);
            });

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
        var that = this;
        $('.ladb-cutlist-group', $slide === undefined ? this.$page : $slide).each(function () {
            that.showGroup($(this), doNotSaveState === undefined  ? false : doNotSaveState,true);
        }).promise().done( function (){
            that.saveUIOptionsHiddenGroupIds();
        });
    };

    LadbTabCutlist.prototype.hideAllGroups = function (exceptedGroupId, $slide, doNotSaveState) {
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
        var isPartSelection = this.selectionGroupId === groupId && this.selectionPartIds.length > 0;

        // Retrieve cutting diagram options
        rubyCallCommand('core_get_model_preset', { dictionary: 'cutlist_cuttingdiagram1d_options', section: groupId }, function (response) {

            var cuttingdiagram1dOptions = response.preset;

            rubyCallCommand('materials_get_attributes_command', { name: group.material_name }, function (response) {

                var $modal = that.appendModalInside('ladb_cutlist_modal_cuttingdiagram_1d', 'tabs/cutlist/_modal-cuttingdiagram-1d.twig', {
                    material_attributes: response,
                    group: group,
                    isPartSelection: isPartSelection,
                    tab: forceDefaultTab || that.lastCuttingdiagram1dOptionsTab == null ? 'material' : that.lastCuttingdiagram1dOptionsTab
                });

                // Fetch UI elements
                var $tabs = $('a[data-toggle="tab"]', $modal);
                var $widgetPreset = $('.ladb-widget-preset', $modal);
                var $inputStdBar = $('#ladb_select_std_bar', $modal);
                var $inputScrapBarLengths = $('#ladb_input_scrap_bar_lengths', $modal);
                var $inputSawKerf = $('#ladb_input_saw_kerf', $modal);
                var $inputTrimming = $('#ladb_input_trimming', $modal);
                var $selectBarFolding = $('#ladb_select_bar_folding', $modal);
                var $selectHidePartList = $('#ladb_select_hide_part_list', $modal);
                var $selectUseNames = $('#ladb_select_use_names', $modal);
                var $selectFullWidthDiagram = $('#ladb_select_full_width_diagram', $modal);
                var $selectHideCross = $('#ladb_select_hide_cross', $modal);
                var $selectOriginCorner = $('#ladb_select_origin_corner', $modal);
                var $inputWrapLength = $('#ladb_input_wrap_length', $modal);
                var $selectPartDrawingType = $('#ladb_select_part_drawing_type', $modal);
                var $btnEditMaterial = $('#ladb_btn_edit_material', $modal);
                var $btnGenerate = $('#ladb_btn_generate', $modal);

                var fnFetchOptions = function (options) {
                    options.std_bar = $inputStdBar.val();
                    options.scrap_bar_lengths = $inputScrapBarLengths.ladbTextinputTokenfield('getValidTokensList');
                    options.saw_kerf = $inputSawKerf.val();
                    options.trimming = $inputTrimming.val();
                    options.bar_folding = $selectBarFolding.val() === '1';
                    options.hide_part_list = $selectHidePartList.val() === '1';
                    options.use_names = $selectUseNames.val() === '1';
                    options.full_width_diagram = $selectFullWidthDiagram.val() === '1';
                    options.hide_cross = $selectHideCross.val() === '1';
                    options.origin_corner = parseInt($selectOriginCorner.val());
                    options.wrap_length = $inputWrapLength.val();
                    options.part_drawing_type = parseInt($selectPartDrawingType.val());
                }
                var fnFillInputs = function (options) {
                    $inputSawKerf.val(options.saw_kerf);
                    $inputTrimming.val(options.trimming);
                    $selectUseNames.selectpicker('val', options.use_names ? '1' : '0');
                    $selectBarFolding.selectpicker('val', options.bar_folding ? '1' : '0');
                    $selectHidePartList.selectpicker('val', options.hide_part_list ? '1' : '0');
                    $selectFullWidthDiagram.selectpicker('val', options.full_width_diagram ? '1' : '0');
                    $selectHideCross.selectpicker('val', options.hide_cross ? '1' : '0');
                    $selectOriginCorner.selectpicker('val', options.origin_corner);
                    $inputWrapLength.val(options.wrap_length);
                    $selectPartDrawingType.selectpicker('val', options.part_drawing_type);
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
                $selectUseNames.selectpicker(SELECT_PICKER_OPTIONS);
                $selectFullWidthDiagram.selectpicker(SELECT_PICKER_OPTIONS);
                $selectHideCross.selectpicker(SELECT_PICKER_OPTIONS);
                $selectOriginCorner.selectpicker(SELECT_PICKER_OPTIONS);
                $inputWrapLength.ladbTextinputDimension();
                $selectPartDrawingType.selectpicker(SELECT_PICKER_OPTIONS);

                fnFillInputs(cuttingdiagram1dOptions);

                // Bind tabs
                $tabs.on('shown.bs.tab', function (e) {
                    that.lastCuttingdiagram1dOptionsTab = $(e.target).attr('href').substring('#tab_cuttingdiagram_options_'.length);
                });

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

                        var fnAdvance = function () {
                            window.requestAnimationFrame(function () {
                                rubyCallCommand('cutlist_group_cuttingdiagram1d_advance', null, function (response) {

                                    var barCount = response.bars.length;

                                    if (response.errors && response.errors.length > 0 || response.bars && response.bars.length > 0) {

                                        var $slide = that.pushNewSlide('ladb_cutlist_slide_cuttingdiagram_1d', 'tabs/cutlist/_slide-cuttingdiagram-1d.twig', $.extend({
                                            capabilities: that.dialog.capabilities,
                                            generateOptions: that.generateOptions,
                                            dimensionColumnOrderStrategy: that.generateOptions.dimension_column_order_strategy.split('>'),
                                            filename: that.filename,
                                            modelName: that.modelName,
                                            modelDescription: that.modelDescription,
                                            modelActivePath: that.modelActivePath,
                                            pageName: that.pageName,
                                            pageDescription: that.pageDescription,
                                            isEntitySelection: that.isEntitySelection,
                                            lengthUnit: that.lengthUnit,
                                            generatedAt: new Date().getTime() / 1000,
                                            group: group
                                        }, response), function () {
                                            that.dialog.setupTooltips();
                                        });

                                        // Fetch UI elements
                                        var $btnCuttingDiagram = $('#ladb_btn_cuttingdiagram', $slide);
                                        var $btnPrint = $('#ladb_btn_print', $slide);
                                        var $btnExport = $('#ladb_btn_export', $slide);
                                        var $btnLabels = $('#ladb_btn_labels', $slide);
                                        var $btnClose = $('#ladb_btn_close', $slide);

                                        // Bind buttons
                                        $btnCuttingDiagram.on('click', function () {
                                            that.cuttingdiagram1dGroup(groupId);
                                        });
                                        $btnPrint.on('click', function () {
                                            $(this).blur();
                                            that.print(that.cutlistTitle + ' - ' + i18next.t('tab.cutlist.cuttingdiagram.title'));
                                        });
                                        $btnExport.on('click', function () {
                                            $(this).blur();

                                            // Count hidden groups
                                            var hiddenBarIndices = [];
                                            $('.ladb-cutlist-cuttingdiagram-group', $slide).each(function () {
                                                if ($(this).hasClass('no-print')) {
                                                    hiddenBarIndices.push($(this).data('bar-index'));
                                                }
                                            });
                                            var isBarSelection = hiddenBarIndices.length > 0

                                            // Retrieve cutting diagram options
                                            rubyCallCommand('core_get_model_preset', { dictionary: 'cutlist_cuttingdiagram1d_write_options', section: groupId }, function (response) {

                                                var exportOptions = response.preset;

                                                var $modal = that.appendModalInside('ladb_cutlist_modal_cuttingdiagram_1d_export', 'tabs/cutlist/_modal-cuttingdiagram-1d-write.twig', {
                                                    group: group,
                                                    isBarSelection: isBarSelection,
                                                });

                                                // Fetch UI elements
                                                var $widgetPreset = $('.ladb-widget-preset', $modal);
                                                var $selectFileFormat = $('#ladb_select_file_format', $modal);
                                                var $formGroupDxfStructure = $('#ladb_form_group_dxf_structure', $modal);
                                                var $selectDxfStructure = $('#ladb_select_dxf_structure', $modal);
                                                var $selectUnit = $('#ladb_select_unit', $modal);
                                                var $selectSmoothing = $('#ladb_select_smoothing', $modal);
                                                var $selectMergeHoles = $('#ladb_select_merge_holes', $modal);
                                                var $selectIncludePaths = $('#ladb_select_include_paths', $modal);
                                                var $inputBarHidden = $('#ladb_input_bar_hidden', $modal);
                                                var $inputBarStrokeColor = $('#ladb_input_bar_stroke_color', $modal);
                                                var $inputBarFillColor = $('#ladb_input_bar_fill_color', $modal);
                                                var $inputPartsHidden = $('#ladb_input_parts_hidden', $modal);
                                                var $inputPartsStrokeColor = $('#ladb_input_parts_stroke_color', $modal);
                                                var $inputPartsFillColor = $('#ladb_input_parts_fill_color', $modal);
                                                var $formGroupPartsHoles = $('#ladb_form_group_parts_holes', $modal);
                                                var $inputPartsHolesStrokeColor = $('#ladb_input_parts_holes_stroke_color', $modal);
                                                var $inputPartsHolesFillColor = $('#ladb_input_parts_holes_fill_color', $modal);
                                                var $formGroupPartsPaths = $('#ladb_form_group_parts_paths', $modal);
                                                var $inputPartsPathsStrokeColor = $('#ladb_input_parts_paths_stroke_color', $modal);
                                                var $formGroupTexts = $('#ladb_form_group_texts', $modal);
                                                var $inputTextsHidden = $('#ladb_input_texts_hidden', $modal);
                                                var $inputTextsColor = $('#ladb_input_texts_color', $modal);
                                                var $inputLeftoversHidden = $('#ladb_input_leftovers_hidden', $modal);
                                                var $inputLeftoversStrokeColor = $('#ladb_input_leftovers_stroke_color', $modal);
                                                var $inputLeftoversFillColor = $('#ladb_input_leftovers_fill_color', $modal);
                                                var $inputCutsHidden = $('#ladb_input_cuts_hidden', $modal);
                                                var $inputCutsColor = $('#ladb_input_cuts_color', $modal);
                                                var $btnExport = $('#ladb_btn_export', $modal);

                                                var fnFetchOptions = function (options) {
                                                    options.file_format = $selectFileFormat.val();
                                                    options.dxf_structure = parseInt($selectDxfStructure.val());
                                                    options.unit = parseInt($selectUnit.val());
                                                    options.smoothing = $selectSmoothing.val() === '1';
                                                    options.merge_holes = $selectMergeHoles.val() === '1';
                                                    options.include_paths = $selectIncludePaths.val() === '1';
                                                    options.bar_hidden = !$inputBarHidden.is(':checked');
                                                    options.bar_stroke_color = $inputBarStrokeColor.ladbTextinputColor('val');
                                                    options.bar_fill_color = $inputBarFillColor.ladbTextinputColor('val');
                                                    options.parts_hidden = !$inputPartsHidden.is(':checked');
                                                    options.parts_stroke_color = $inputPartsStrokeColor.ladbTextinputColor('val');
                                                    options.parts_fill_color = $inputPartsFillColor.ladbTextinputColor('val');
                                                    options.parts_holes_stroke_color = $inputPartsHolesStrokeColor.ladbTextinputColor('val');
                                                    options.parts_holes_fill_color = $inputPartsHolesFillColor.ladbTextinputColor('val');
                                                    options.parts_paths_stroke_color = $inputPartsPathsStrokeColor.ladbTextinputColor('val');
                                                    options.texts_hidden = !$inputTextsHidden.is(':checked');
                                                    options.texts_color = $inputTextsColor.ladbTextinputColor('val');
                                                    options.leftovers_hidden = !$inputLeftoversHidden.is(':checked');
                                                    options.leftovers_stroke_color = $inputLeftoversStrokeColor.ladbTextinputColor('val');
                                                    options.leftovers_fill_color = $inputLeftoversFillColor.ladbTextinputColor('val');
                                                    options.cuts_hidden = !$inputCutsHidden.is(':checked');
                                                    options.cuts_color = $inputCutsColor.ladbTextinputColor('val');
                                                };
                                                var fnFillInputs = function (options) {
                                                    $selectFileFormat.selectpicker('val', options.file_format);
                                                    $selectDxfStructure.selectpicker('val', options.dxf_structure);
                                                    $selectUnit.selectpicker('val', options.unit);
                                                    $selectSmoothing.selectpicker('val', options.smoothing ? '1' : '0');
                                                    $selectMergeHoles.selectpicker('val', options.merge_holes ? '1' : '0');
                                                    $selectIncludePaths.selectpicker('val', options.include_paths ? '1' : '0');
                                                    $inputBarHidden.prop('checked', !options.bar_hidden);
                                                    $inputBarStrokeColor.ladbTextinputColor('val', options.bar_stroke_color);
                                                    $inputBarFillColor.ladbTextinputColor('val', options.bar_fill_color);
                                                    $inputPartsHidden.prop('checked', !options.parts_hidden);
                                                    $inputPartsStrokeColor.ladbTextinputColor('val', options.parts_stroke_color);
                                                    $inputPartsFillColor.ladbTextinputColor('val', options.parts_fill_color);
                                                    $inputPartsHolesStrokeColor.ladbTextinputColor('val', options.parts_holes_stroke_color);
                                                    $inputPartsHolesFillColor.ladbTextinputColor('val', options.parts_holes_fill_color);
                                                    $inputPartsPathsStrokeColor.ladbTextinputColor('val', options.parts_paths_stroke_color);
                                                    $inputTextsHidden.prop('checked', !options.texts_hidden);
                                                    $inputTextsColor.ladbTextinputColor('val', options.texts_color);
                                                    $inputLeftoversHidden.prop('checked', !options.leftovers_hidden);
                                                    $inputLeftoversStrokeColor.ladbTextinputColor('val', options.leftovers_stroke_color);
                                                    $inputLeftoversFillColor.ladbTextinputColor('val', options.leftovers_fill_color);
                                                    $inputCutsHidden.prop('checked', !options.cuts_hidden);
                                                    $inputCutsColor.ladbTextinputColor('val', options.cuts_color);
                                                    fnUpdateFieldsVisibility();
                                                };
                                                var fnUpdateFieldsVisibility = function () {
                                                    var isDxf = $selectFileFormat.val() === 'dxf';
                                                    var isMergeHoles = $selectMergeHoles.val() === '1';
                                                    var isIncludePaths = $selectIncludePaths.val() === '1';
                                                    var isBarHidden = !$inputBarHidden.is(':checked');
                                                    var isPartsHidden = !$inputPartsHidden.is(':checked');
                                                    var isTextHidden = !$inputTextsHidden.is(':checked');
                                                    var isLeftoversHidden = !$inputLeftoversHidden.is(':checked');
                                                    var isCutsHidden = !$inputCutsHidden.is(':checked');
                                                    if (isDxf) $formGroupDxfStructure.show(); else $formGroupDxfStructure.hide();
                                                    $inputBarStrokeColor.ladbTextinputColor(isBarHidden ? 'disable' : 'enable');
                                                    $inputBarFillColor.ladbTextinputColor(isBarHidden || isDxf ? 'disable' : 'enable');
                                                    $inputPartsStrokeColor.ladbTextinputColor(isPartsHidden ? 'disable' : 'enable');
                                                    $inputPartsFillColor.ladbTextinputColor(isPartsHidden || isDxf ? 'disable' : 'enable');
                                                    if (isPartsHidden || !isMergeHoles) $formGroupPartsHoles.hide(); else $formGroupPartsHoles.show();
                                                    $inputPartsHolesStrokeColor.ladbTextinputColor(isPartsHidden || !isMergeHoles ? 'disable' : 'enable');
                                                    $inputPartsHolesFillColor.ladbTextinputColor(isPartsHidden || !isMergeHoles ? 'disable' : 'enable');
                                                    if (isPartsHidden || !isIncludePaths) $formGroupPartsPaths.hide(); else $formGroupPartsPaths.show();
                                                    $inputPartsPathsStrokeColor.ladbTextinputColor(!isIncludePaths ? 'disable' : 'enable');
                                                    if (isPartsHidden) $formGroupTexts.hide(); else $formGroupTexts.show();
                                                    $inputTextsColor.ladbTextinputColor(isTextHidden ? 'disable' : 'enable');
                                                    $inputLeftoversStrokeColor.ladbTextinputColor(isLeftoversHidden ? 'disable' : 'enable');
                                                    $inputLeftoversFillColor.ladbTextinputColor(isLeftoversHidden || isDxf ? 'disable' : 'enable');
                                                    $inputCutsColor.ladbTextinputColor(isCutsHidden ? 'disable' : 'enable');
                                                    $('.ladb-form-fill-color').css('opacity', isDxf ? 0.3 : 1);
                                                };

                                                $widgetPreset.ladbWidgetPreset({
                                                    dialog: that.dialog,
                                                    dictionary: 'cutlist_cuttingdiagram1d_write_options',
                                                    fnFetchOptions: fnFetchOptions,
                                                    fnFillInputs: fnFillInputs
                                                });
                                                $selectFileFormat
                                                    .selectpicker(SELECT_PICKER_OPTIONS)
                                                    .on('changed.bs.select', function () {
                                                        var fileCount = barCount - hiddenBarIndices.length;
                                                        $('#ladb_btn_export_file_format', $btnExport).html($(this).val().toUpperCase() + ' <small>( ' + fileCount + ' ' + i18next.t('default.file', { count: fileCount }).toLowerCase() + ' )</small>');
                                                        fnUpdateFieldsVisibility();
                                                    })
                                                ;
                                                $selectDxfStructure.selectpicker(SELECT_PICKER_OPTIONS);
                                                $selectUnit.selectpicker(SELECT_PICKER_OPTIONS);
                                                $selectSmoothing.selectpicker(SELECT_PICKER_OPTIONS);
                                                $selectMergeHoles.selectpicker(SELECT_PICKER_OPTIONS).on('change', fnUpdateFieldsVisibility);
                                                $selectIncludePaths.selectpicker(SELECT_PICKER_OPTIONS).on('change', fnUpdateFieldsVisibility);
                                                $inputBarStrokeColor.ladbTextinputColor(TEXTINPUT_COLOR_OPTIONS);
                                                $inputBarFillColor.ladbTextinputColor(TEXTINPUT_COLOR_OPTIONS);
                                                $inputPartsStrokeColor.ladbTextinputColor(TEXTINPUT_COLOR_OPTIONS);
                                                $inputPartsFillColor.ladbTextinputColor(TEXTINPUT_COLOR_OPTIONS);
                                                $inputPartsHolesStrokeColor.ladbTextinputColor(TEXTINPUT_COLOR_OPTIONS);
                                                $inputPartsHolesFillColor.ladbTextinputColor(TEXTINPUT_COLOR_OPTIONS);
                                                $inputPartsPathsStrokeColor.ladbTextinputColor(TEXTINPUT_COLOR_OPTIONS);
                                                $inputTextsColor.ladbTextinputColor(TEXTINPUT_COLOR_OPTIONS);
                                                $inputLeftoversStrokeColor.ladbTextinputColor(TEXTINPUT_COLOR_OPTIONS);
                                                $inputLeftoversFillColor.ladbTextinputColor(TEXTINPUT_COLOR_OPTIONS);
                                                $inputCutsColor.ladbTextinputColor(TEXTINPUT_COLOR_OPTIONS);

                                                fnFillInputs(exportOptions);

                                                // Bind inputs
                                                $inputBarHidden.on('change', fnUpdateFieldsVisibility);
                                                $inputPartsHidden.on('change', fnUpdateFieldsVisibility);
                                                $inputTextsHidden.on('change', fnUpdateFieldsVisibility);
                                                $inputLeftoversHidden.on('change', fnUpdateFieldsVisibility);
                                                $inputCutsHidden.on('change', fnUpdateFieldsVisibility);

                                                // Bind buttons
                                                $btnExport.on('click', function () {

                                                    // Fetch options
                                                    fnFetchOptions(exportOptions);

                                                    // Store options
                                                    rubyCallCommand('core_set_model_preset', { dictionary: 'cutlist_cuttingdiagram1d_write_options', values: exportOptions, section: groupId });

                                                    rubyCallCommand('cutlist_cuttingdiagram1d_write', $.extend(exportOptions, { hidden_bar_indices: hiddenBarIndices }, cuttingdiagram1dOptions), function (response) {

                                                        if (response.errors) {
                                                            that.dialog.notifyErrors(response.errors);
                                                        }
                                                        if (response.export_path) {
                                                            that.dialog.notifySuccess(i18next.t('core.success.exported_to', { path: response.export_path }), [
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

                                                // Setup popovers
                                                that.dialog.setupPopovers();

                                            });

                                        });
                                        $btnLabels.on('click', function () {

                                            // Compute label bins (a list of bar index attached to part id)
                                            let binDefs = {};
                                            let barIndex = 0;
                                            $.each(response.bars, function () {
                                                for (var i = 0 ; i < this.count; i++) {
                                                    barIndex++;
                                                    $.each(this.parts, function () {
                                                        if (!binDefs[this.id]) {
                                                            binDefs[this.id] = [];
                                                        }
                                                        binDefs[this.id].push(barIndex);
                                                    });
                                                }
                                            });

                                            that.labelsGroup(groupId, binDefs);
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
                                            var $target = $('.ladb-cutlist-cuttingdiagram-group[data-bar-index=' + (parseInt(groupId) - 1) + ']');
                                            $slide.animate({scrollTop: $slide.scrollTop() + $target.position().top - $('.ladb-header', $slide).outerHeight(true) - 20}, 200).promise().then(function () {
                                                $target.effect('highlight', {}, 1500);
                                            });
                                            $(this).blur();
                                            return false;
                                        });
                                        $('.ladb-btn-scrollto-next-group', $slide).on('click', function () {
                                            var $group = $(this).parents('.ladb-cutlist-group');
                                            var groupId = $group.data('bar-index');
                                            var $target = $('.ladb-cutlist-cuttingdiagram-group[data-bar-index=' + (parseInt(groupId) + 1) + ']');
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
                                        $('#ladb_btn_select_unplaced_parts', $slide).on('click', function () {
                                            that.cleanupSelection();
                                            $.each(response.unplaced_parts, function (index, part) {
                                                that.selectPart(part.id, true);
                                            });
                                            that.dialog.notifySuccess(i18next.t('tab.cutlist.success.part_selected', { count: response.unplaced_parts.length }), [
                                                Noty.button(i18next.t('default.see'), 'btn btn-default', function () {
                                                    $btnClose.click();
                                                })
                                            ]);
                                        });

                                        // SVG
                                        $('SVG .part', $slide).on('click', function () {
                                            var partId = $(this).data('part-id');
                                            that.highlightPart(partId);
                                            $(this).blur();
                                            return false;
                                        });

                                        that.dialog.finishProgress();

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
                            rubyCallCommand('cutlist_group_cuttingdiagram1d_start', $.extend({ group_id: groupId, part_ids: isPartSelection ? that.selectionPartIds : null }, cuttingdiagram1dOptions), function (response) {
                                window.requestAnimationFrame(function () {
                                    that.dialog.startProgress(response.estimated_steps);
                                    fnAdvance();
                                });
                            });
                        });

                    }

                    // Hide modal
                    $modal.modal('hide');

                });

                // Bind modal
                $modal.on('hide.bs.modal', function () {
                    $inputScrapBarLengths.ladbTextinputTokenfield('destroy');
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
        var isPartSelection = this.selectionGroupId === groupId && this.selectionPartIds.length > 0;

        // Retrieve cutting diagram options
        rubyCallCommand('core_get_model_preset', { dictionary: 'cutlist_cuttingdiagram2d_options', section: groupId }, function (response) {

            var cuttingdiagram2dOptions = response.preset;

            rubyCallCommand('materials_get_attributes_command', { name: group.material_name }, function (response) {

                var $modal = that.appendModalInside('ladb_cutlist_modal_cuttingdiagram_2d', 'tabs/cutlist/_modal-cuttingdiagram-2d.twig', {
                    material_attributes: response,
                    group: group,
                    isPartSelection: isPartSelection,
                    tab: forceDefaultTab || that.lastCuttingdiagram2dOptionsTab == null ? 'material' : that.lastCuttingdiagram2dOptionsTab
                });

                // Fetch UI elements
                var $tabs = $('a[data-toggle="tab"]', $modal);
                var $widgetPreset = $('.ladb-widget-preset', $modal);
                var $inputStdSheet = $('#ladb_select_std_sheet', $modal);
                var $inputScrapSheetSizes = $('#ladb_input_scrap_sheet_sizes', $modal);
                var $inputSawKerf = $('#ladb_input_saw_kerf', $modal);
                var $inputTrimming = $('#ladb_input_trimming', $modal);
                var $selectOptimization = $('#ladb_select_optimization', $modal);
                var $selectStacking = $('#ladb_select_stacking', $modal);
                var $inputKeepLength = $('#ladb_input_keep_length', $modal);
                var $inputKeepWidth = $('#ladb_input_keep_width', $modal);
                var $selectSheetFolding = $('#ladb_select_sheet_folding', $modal);
                var $selectHidePartList = $('#ladb_select_hide_part_list', $modal);
                var $selectUseNames = $('#ladb_select_use_names', $modal);
                var $selectFullWidthDiagram = $('#ladb_select_full_width_diagram', $modal);
                var $selectHideCross = $('#ladb_select_hide_cross', $modal);
                var $selectOriginCorner = $('#ladb_select_origin_corner', $modal);
                var $selectHighlightPrimaryCuts = $('#ladb_select_highlight_primary_cuts', $modal);
                var $selectHideEdgesPreview = $('#ladb_select_hide_edges_preview', $modal);
                var $selectPartDrawingType = $('#ladb_select_part_drawing_type', $modal);
                var $btnEditMaterial = $('#ladb_btn_edit_material', $modal);
                var $btnGenerate = $('#ladb_btn_generate', $modal);

                var fnFetchOptions = function (options) {
                    options.std_sheet = $inputStdSheet.val();
                    options.scrap_sheet_sizes = $inputScrapSheetSizes.ladbTextinputTokenfield('getValidTokensList');
                    options.saw_kerf = $inputSawKerf.val();
                    options.trimming = $inputTrimming.val();
                    options.optimization = parseInt($selectOptimization.val());
                    options.stacking = parseInt($selectStacking.val());
                    options.keep_length = $inputKeepLength.val();
                    options.keep_width = $inputKeepWidth.val();
                    options.sheet_folding = $selectSheetFolding.val() === '1';
                    options.hide_part_list = $selectHidePartList.val() === '1';
                    options.use_names = $selectUseNames.val() === '1';
                    options.full_width_diagram = $selectFullWidthDiagram.val() === '1';
                    options.hide_cross = $selectHideCross.val() === '1';
                    options.origin_corner = parseInt($selectOriginCorner.val());
                    options.highlight_primary_cuts = $selectHighlightPrimaryCuts.val() === '1';
                    options.hide_edges_preview = $selectHideEdgesPreview.val() === '1';
                    options.part_drawing_type = parseInt($selectPartDrawingType.val());
                }
                var fnFillInputs = function (options) {
                    $inputSawKerf.val(options.saw_kerf);
                    $inputTrimming.val(options.trimming);
                    $selectOptimization.selectpicker('val', options.optimization);
                    $selectStacking.selectpicker('val', options.stacking);
                    $inputKeepLength.val(options.keep_length);
                    $inputKeepWidth.val(options.keep_width);
                    $selectSheetFolding.selectpicker('val', options.sheet_folding ? '1' : '0');
                    $selectHidePartList.selectpicker('val', options.hide_part_list ? '1' : '0');
                    $selectUseNames.selectpicker('val', options.use_names ? '1' : '0');
                    $selectFullWidthDiagram.selectpicker('val', options.full_width_diagram ? '1' : '0');
                    $selectHideCross.selectpicker('val', options.hide_cross ? '1' : '0');
                    $selectOriginCorner.selectpicker('val', options.origin_corner);
                    $selectHighlightPrimaryCuts.selectpicker('val', options.highlight_primary_cuts ? '1' : '0');
                    $selectHideEdgesPreview.selectpicker('val', options.hide_edges_preview ? '1' : '0');
                    $selectPartDrawingType.selectpicker('val', options.part_drawing_type);
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
                $inputKeepLength.ladbTextinputDimension();
                $inputKeepWidth.ladbTextinputDimension();
                $selectSheetFolding.selectpicker(SELECT_PICKER_OPTIONS);
                $selectHidePartList.selectpicker(SELECT_PICKER_OPTIONS);
                $selectUseNames.selectpicker(SELECT_PICKER_OPTIONS);
                $selectFullWidthDiagram.selectpicker(SELECT_PICKER_OPTIONS);
                $selectHideCross.selectpicker(SELECT_PICKER_OPTIONS);
                $selectOriginCorner.selectpicker(SELECT_PICKER_OPTIONS);
                $selectHighlightPrimaryCuts.selectpicker(SELECT_PICKER_OPTIONS);
                $selectHideEdgesPreview.selectpicker(SELECT_PICKER_OPTIONS);
                $selectPartDrawingType.selectpicker(SELECT_PICKER_OPTIONS);

                fnFillInputs(cuttingdiagram2dOptions);

                // Bind tabs
                $tabs.on('shown.bs.tab', function (e) {
                    that.lastCuttingdiagram2dOptionsTab = $(e.target).attr('href').substring('#tab_cuttingdiagram_options_'.length);
                });

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

                        var fnAdvance = function () {
                            window.requestAnimationFrame(function () {
                                rubyCallCommand('cutlist_group_cuttingdiagram2d_advance', null, function (response) {

                                    if (response.errors && response.errors.length > 0 || response.sheets && response.sheets.length > 0) {

                                        var sheetCount = response.sheets.length;

                                        var $slide = that.pushNewSlide('ladb_cutlist_slide_cuttingdiagram_2d', 'tabs/cutlist/_slide-cuttingdiagram-2d.twig', $.extend({
                                            capabilities: that.dialog.capabilities,
                                            generateOptions: that.generateOptions,
                                            dimensionColumnOrderStrategy: that.generateOptions.dimension_column_order_strategy.split('>'),
                                            filename: that.filename,
                                            modelName: that.modelName,
                                            modelDescription: that.modelDescription,
                                            modelActivePath: that.modelActivePath,
                                            pageName: that.pageName,
                                            pageDescription: that.pageDescription,
                                            isEntitySelection: that.isEntitySelection,
                                            lengthUnit: that.lengthUnit,
                                            generatedAt: new Date().getTime() / 1000,
                                            group: group
                                        }, response), function () {
                                            that.dialog.setupTooltips();
                                        });

                                        // Fetch UI elements
                                        var $btnCuttingDiagram = $('#ladb_btn_cuttingdiagram', $slide);
                                        var $btnPrint = $('#ladb_btn_print', $slide);
                                        var $btnExport = $('#ladb_btn_export', $slide);
                                        var $btnLabels = $('#ladb_btn_labels', $slide);
                                        var $btnClose = $('#ladb_btn_close', $slide);

                                        // Bind buttons
                                        $btnCuttingDiagram.on('click', function () {
                                            that.cuttingdiagram2dGroup(groupId);
                                        });
                                        $btnPrint.on('click', function () {
                                            $(this).blur();
                                            that.print(that.cutlistTitle + ' - ' + i18next.t('tab.cutlist.cuttingdiagram.title'));
                                        });
                                        $btnExport.on('click', function () {
                                            $(this).blur();

                                            // Count hidden groups
                                            var hiddenSheetIndices = [];
                                            $('.ladb-cutlist-cuttingdiagram-group', $slide).each(function () {
                                                if ($(this).hasClass('no-print')) {
                                                    hiddenSheetIndices.push($(this).data('sheet-index'));
                                                }
                                            });
                                            var isSheetSelection = hiddenSheetIndices.length > 0

                                            // Retrieve cutting diagram options
                                            rubyCallCommand('core_get_model_preset', { dictionary: 'cutlist_cuttingdiagram2d_write_options', section: groupId }, function (response) {

                                                var exportOptions = response.preset;

                                                var $modal = that.appendModalInside('ladb_cutlist_modal_cuttingdiagram_2d_export', 'tabs/cutlist/_modal-cuttingdiagram-2d-write.twig', {
                                                    group: group,
                                                    isSheetSelection: isSheetSelection,
                                                });

                                                // Fetch UI elements
                                                var $widgetPreset = $('.ladb-widget-preset', $modal);
                                                var $selectFileFormat = $('#ladb_select_file_format', $modal);
                                                var $formGroupDxfStructure = $('#ladb_form_group_dxf_structure', $modal);
                                                var $selectDxfStructure = $('#ladb_select_dxf_structure', $modal);
                                                var $selectUnit = $('#ladb_select_unit', $modal);
                                                var $selectSmoothing = $('#ladb_select_smoothing', $modal);
                                                var $selectMergeHoles = $('#ladb_select_merge_holes', $modal);
                                                var $selectIncludePaths = $('#ladb_select_include_paths', $modal);
                                                var $inputSheetHidden = $('#ladb_input_sheet_hidden', $modal);
                                                var $inputSheetStrokeColor = $('#ladb_input_sheet_stroke_color', $modal);
                                                var $inputSheetFillColor = $('#ladb_input_sheet_fill_color', $modal);
                                                var $inputPartsHidden = $('#ladb_input_parts_hidden', $modal);
                                                var $inputPartsStrokeColor = $('#ladb_input_parts_stroke_color', $modal);
                                                var $inputPartsFillColor = $('#ladb_input_parts_fill_color', $modal);
                                                var $formGroupPartsHoles = $('#ladb_form_group_parts_holes', $modal);
                                                var $inputPartsHolesStrokeColor = $('#ladb_input_parts_holes_stroke_color', $modal);
                                                var $inputPartsHolesFillColor = $('#ladb_input_parts_holes_fill_color', $modal);
                                                var $formGroupPartsPaths = $('#ladb_form_group_parts_paths', $modal);
                                                var $inputPartsPathsStrokeColor = $('#ladb_input_parts_paths_stroke_color', $modal);
                                                var $formGroupTexts = $('#ladb_form_group_texts', $modal);
                                                var $inputTextsHidden = $('#ladb_input_texts_hidden', $modal);
                                                var $inputTextsColor = $('#ladb_input_texts_color', $modal);
                                                var $inputLeftoversHidden = $('#ladb_input_leftovers_hidden', $modal);
                                                var $inputLeftoversStrokeColor = $('#ladb_input_leftovers_stroke_color', $modal);
                                                var $inputLeftoversFillColor = $('#ladb_input_leftovers_fill_color', $modal);
                                                var $inputCutsHidden = $('#ladb_input_cuts_hidden', $modal);
                                                var $inputCutsColor = $('#ladb_input_cuts_color', $modal);
                                                var $btnExport = $('#ladb_btn_export', $modal);

                                                var fnFetchOptions = function (options) {
                                                    options.file_format = $selectFileFormat.val();
                                                    options.dxf_structure = parseInt($selectDxfStructure.val());
                                                    options.unit = parseInt($selectUnit.val());
                                                    options.smoothing = $selectSmoothing.val() === '1';
                                                    options.merge_holes = $selectMergeHoles.val() === '1';
                                                    options.include_paths = $selectIncludePaths.val() === '1';
                                                    options.sheet_hidden = !$inputSheetHidden.is(':checked');
                                                    options.sheet_stroke_color = $inputSheetStrokeColor.ladbTextinputColor('val');
                                                    options.sheet_fill_color = $inputSheetFillColor.ladbTextinputColor('val');
                                                    options.parts_hidden = !$inputPartsHidden.is(':checked');
                                                    options.parts_stroke_color = $inputPartsStrokeColor.ladbTextinputColor('val');
                                                    options.parts_fill_color = $inputPartsFillColor.ladbTextinputColor('val');
                                                    options.parts_holes_stroke_color = $inputPartsHolesStrokeColor.ladbTextinputColor('val');
                                                    options.parts_holes_fill_color = $inputPartsHolesFillColor.ladbTextinputColor('val');
                                                    options.parts_paths_stroke_color = $inputPartsPathsStrokeColor.ladbTextinputColor('val');
                                                    options.texts_hidden = !$inputTextsHidden.is(':checked');
                                                    options.texts_color = $inputTextsColor.ladbTextinputColor('val');
                                                    options.leftovers_hidden = !$inputLeftoversHidden.is(':checked');
                                                    options.leftovers_stroke_color = $inputLeftoversStrokeColor.ladbTextinputColor('val');
                                                    options.leftovers_fill_color = $inputLeftoversFillColor.ladbTextinputColor('val');
                                                    options.cuts_hidden = !$inputCutsHidden.is(':checked');
                                                    options.cuts_color = $inputCutsColor.ladbTextinputColor('val');
                                                };
                                                var fnFillInputs = function (options) {
                                                    $selectFileFormat.selectpicker('val', options.file_format);
                                                    $selectDxfStructure.selectpicker('val', options.dxf_structure);
                                                    $selectUnit.selectpicker('val', options.unit);
                                                    $selectSmoothing.selectpicker('val', options.smoothing ? '1' : '0');
                                                    $selectMergeHoles.selectpicker('val', options.merge_holes ? '1' : '0');
                                                    $selectIncludePaths.selectpicker('val', options.include_paths ? '1' : '0');
                                                    $inputSheetHidden.prop('checked', !options.sheet_hidden);
                                                    $inputSheetStrokeColor.ladbTextinputColor('val', options.sheet_stroke_color);
                                                    $inputSheetFillColor.ladbTextinputColor('val', options.sheet_fill_color);
                                                    $inputPartsHidden.prop('checked', !options.parts_hidden);
                                                    $inputPartsStrokeColor.ladbTextinputColor('val', options.parts_stroke_color);
                                                    $inputPartsFillColor.ladbTextinputColor('val', options.parts_fill_color);
                                                    $inputPartsHolesStrokeColor.ladbTextinputColor('val', options.parts_holes_stroke_color);
                                                    $inputPartsHolesFillColor.ladbTextinputColor('val', options.parts_holes_fill_color);
                                                    $inputPartsPathsStrokeColor.ladbTextinputColor('val', options.parts_paths_stroke_color);
                                                    $inputTextsHidden.prop('checked', !options.texts_hidden);
                                                    $inputTextsColor.ladbTextinputColor('val', options.texts_color);
                                                    $inputLeftoversHidden.prop('checked', !options.leftovers_hidden);
                                                    $inputLeftoversStrokeColor.ladbTextinputColor('val', options.leftovers_stroke_color);
                                                    $inputLeftoversFillColor.ladbTextinputColor('val', options.leftovers_fill_color);
                                                    $inputCutsHidden.prop('checked', !options.cuts_hidden);
                                                    $inputCutsColor.ladbTextinputColor('val', options.cuts_color);
                                                    fnUpdateFieldsVisibility();
                                                };
                                                var fnUpdateFieldsVisibility = function () {
                                                    var isDxf = $selectFileFormat.val() === 'dxf';
                                                    var isMergeHoles = $selectMergeHoles.val() === '1';
                                                    var isIncludePaths = $selectIncludePaths.val() === '1';
                                                    var isSheetHidden = !$inputSheetHidden.is(':checked');
                                                    var isPartsHidden = !$inputPartsHidden.is(':checked');
                                                    var isTextsHidden = !$inputTextsHidden.is(':checked');
                                                    var isLeftoversHidden = !$inputLeftoversHidden.is(':checked');
                                                    var isCutsHidden = !$inputCutsHidden.is(':checked');
                                                    if (isDxf) $formGroupDxfStructure.show(); else $formGroupDxfStructure.hide();
                                                    $inputSheetStrokeColor.ladbTextinputColor(isSheetHidden ? 'disable' : 'enable');
                                                    $inputSheetFillColor.ladbTextinputColor(isSheetHidden || isDxf ? 'disable' : 'enable');
                                                    $inputPartsStrokeColor.ladbTextinputColor(isPartsHidden ? 'disable' : 'enable');
                                                    $inputPartsFillColor.ladbTextinputColor(isPartsHidden || isDxf ? 'disable' : 'enable');
                                                    if (isPartsHidden || !isMergeHoles) $formGroupPartsHoles.hide(); else $formGroupPartsHoles.show();
                                                    $inputPartsHolesStrokeColor.ladbTextinputColor(isPartsHidden || !isMergeHoles ? 'disable' : 'enable');
                                                    $inputPartsHolesFillColor.ladbTextinputColor(isPartsHidden || !isMergeHoles ? 'disable' : 'enable');
                                                    if (isPartsHidden || !isIncludePaths) $formGroupPartsPaths.hide(); else $formGroupPartsPaths.show();
                                                    $inputPartsPathsStrokeColor.ladbTextinputColor(!isIncludePaths ? 'disable' : 'enable');
                                                    if (isPartsHidden) $formGroupTexts.hide(); else $formGroupTexts.show();
                                                    $inputTextsColor.ladbTextinputColor(isTextsHidden ? 'disable' : 'enable');
                                                    $inputLeftoversStrokeColor.ladbTextinputColor(isLeftoversHidden ? 'disable' : 'enable');
                                                    $inputLeftoversFillColor.ladbTextinputColor(isLeftoversHidden || isDxf ? 'disable' : 'enable');
                                                    $inputCutsColor.ladbTextinputColor(isCutsHidden ? 'disable' : 'enable');
                                                    $('.ladb-form-fill-color').css('opacity', isDxf ? 0.3 : 1);
                                                };

                                                $widgetPreset.ladbWidgetPreset({
                                                    dialog: that.dialog,
                                                    dictionary: 'cutlist_cuttingdiagram2d_write_options',
                                                    fnFetchOptions: fnFetchOptions,
                                                    fnFillInputs: fnFillInputs
                                                });
                                                $selectFileFormat
                                                    .selectpicker(SELECT_PICKER_OPTIONS)
                                                    .on('changed.bs.select', function () {
                                                        var fileCount = sheetCount - hiddenSheetIndices.length;
                                                        $('#ladb_btn_export_file_format', $btnExport).html($(this).val().toUpperCase() + ' <small>( ' + fileCount + ' ' + i18next.t('default.file', { count: fileCount }).toLowerCase() + ' )</small>');
                                                        fnUpdateFieldsVisibility();
                                                    })
                                                ;
                                                $selectDxfStructure.selectpicker(SELECT_PICKER_OPTIONS);
                                                $selectUnit.selectpicker(SELECT_PICKER_OPTIONS);
                                                $selectSmoothing.selectpicker(SELECT_PICKER_OPTIONS);
                                                $selectMergeHoles.selectpicker(SELECT_PICKER_OPTIONS).on('change', fnUpdateFieldsVisibility);
                                                $selectIncludePaths.selectpicker(SELECT_PICKER_OPTIONS).on('change', fnUpdateFieldsVisibility);
                                                $inputSheetStrokeColor.ladbTextinputColor(TEXTINPUT_COLOR_OPTIONS);
                                                $inputSheetFillColor.ladbTextinputColor(TEXTINPUT_COLOR_OPTIONS);
                                                $inputPartsStrokeColor.ladbTextinputColor(TEXTINPUT_COLOR_OPTIONS);
                                                $inputPartsFillColor.ladbTextinputColor(TEXTINPUT_COLOR_OPTIONS);
                                                $inputPartsHolesStrokeColor.ladbTextinputColor(TEXTINPUT_COLOR_OPTIONS);
                                                $inputPartsHolesFillColor.ladbTextinputColor(TEXTINPUT_COLOR_OPTIONS);
                                                $inputPartsPathsStrokeColor.ladbTextinputColor(TEXTINPUT_COLOR_OPTIONS);
                                                $inputTextsColor.ladbTextinputColor(TEXTINPUT_COLOR_OPTIONS);
                                                $inputLeftoversStrokeColor.ladbTextinputColor(TEXTINPUT_COLOR_OPTIONS);
                                                $inputLeftoversFillColor.ladbTextinputColor(TEXTINPUT_COLOR_OPTIONS);
                                                $inputCutsColor.ladbTextinputColor(TEXTINPUT_COLOR_OPTIONS);

                                                fnFillInputs(exportOptions);

                                                // Bind inputs
                                                $inputSheetHidden.on('change', fnUpdateFieldsVisibility);
                                                $inputPartsHidden.on('change', fnUpdateFieldsVisibility);
                                                $inputTextsHidden.on('change', fnUpdateFieldsVisibility);
                                                $inputLeftoversHidden.on('change', fnUpdateFieldsVisibility);
                                                $inputCutsHidden.on('change', fnUpdateFieldsVisibility);

                                                // Bind buttons
                                                $btnExport.on('click', function () {

                                                    // Fetch options
                                                    fnFetchOptions(exportOptions);

                                                    // Store options
                                                    rubyCallCommand('core_set_model_preset', { dictionary: 'cutlist_cuttingdiagram2d_write_options', values: exportOptions, section: groupId });

                                                    rubyCallCommand('cutlist_cuttingdiagram2d_write', $.extend(exportOptions, { hidden_sheet_indices: hiddenSheetIndices }, cuttingdiagram2dOptions), function (response) {

                                                        if (response.errors) {
                                                            that.dialog.notifyErrors(response.errors);
                                                        }
                                                        if (response.export_path) {
                                                            that.dialog.notifySuccess(i18next.t('core.success.exported_to', { path: response.export_path }), [
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

                                                // Setup popovers
                                                that.dialog.setupPopovers();

                                            });

                                        });
                                        $btnLabels.on('click', function () {

                                            // Compute label bins (a list of sheet index attached to part id)
                                            let binDefs = {};
                                            let sheetIndex = 0;
                                            $.each(response.sheets, function () {
                                                for (var i = 0 ; i < this.count; i++) {
                                                    sheetIndex++;
                                                    $.each(this.parts, function () {
                                                        if (!binDefs[this.id]) {
                                                            binDefs[this.id] = [];
                                                        }
                                                        binDefs[this.id].push(sheetIndex);
                                                    });
                                                }
                                            });

                                            that.labelsGroup(groupId, binDefs);
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
                                            var $target = $('.ladb-cutlist-cuttingdiagram-group[data-sheet-index=' + (parseInt(groupId) - 1) + ']');
                                            that.scrollSlideToTarget($slide, $target, true, true);
                                            $(this).blur();
                                            return false;
                                        });
                                        $('.ladb-btn-scrollto-next-group', $slide).on('click', function () {
                                            var $group = $(this).parents('.ladb-cutlist-group');
                                            var groupId = $group.data('sheet-index');
                                            var $target = $('.ladb-cutlist-cuttingdiagram-group[data-sheet-index=' + (parseInt(groupId) + 1) + ']');
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
                                        $('#ladb_btn_select_unplaced_parts', $slide).on('click', function () {
                                            that.cleanupSelection();
                                            $.each(response.unplaced_parts, function (index, part) {
                                                that.selectPart(part.id, true);
                                            });
                                            that.dialog.notifySuccess(i18next.t('tab.cutlist.success.part_selected', { count: response.unplaced_parts.length }), [
                                                Noty.button(i18next.t('default.see'), 'btn btn-default', function () {
                                                    $btnClose.click();
                                                })
                                            ]);
                                        });
                                        $('#ladb_btn_copy_leftovers_to_clipboard', $slide).on('click', function () {
                                            var items = [];
                                            $.each(response.to_keep_leftovers, function (index, leftover) {
                                                items.push(leftover.length + 'x' + leftover.width + 'x' + leftover.count);
                                            });
                                            that.dialog.copyToClipboard(items.join(';'));
                                        });

                                        // SVG
                                        $('SVG .part', $slide).on('click', function () {
                                            var partId = $(this).data('part-id');
                                            that.highlightPart(partId);
                                            $(this).blur();
                                            return false;
                                        });

                                        that.dialog.finishProgress();

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
                            rubyCallCommand('cutlist_group_cuttingdiagram2d_start', $.extend({ group_id: groupId, part_ids: isPartSelection ? that.selectionPartIds : null }, cuttingdiagram2dOptions), function (response) {
                                window.requestAnimationFrame(function () {
                                    that.dialog.startProgress(response.estimated_steps);
                                    fnAdvance();
                                });
                            });
                        });

                    }

                    // Hide modal
                    $modal.modal('hide');

                });

                // Bind modal
                $modal.on('hide.bs.modal', function () {
                    $inputScrapSheetSizes.ladbTextinputTokenfield('destroy');
                });

                // Show modal
                $modal.modal('show');

                // Setup popovers
                that.dialog.setupPopovers();

            });

        });

    };

    LadbTabCutlist.prototype.labelsGroup = function (groupId, binDefs, forceDefaultTab) {
        var that = this;

        var group = this.findGroupById(groupId);
        var isPartSelection = this.selectionGroupId === groupId && this.selectionPartIds.length > 0;
        var isBinSorterDisabled = !binDefs;

        // Retrieve parts
        var tmpBinDefs = binDefs ? JSON.parse(JSON.stringify(binDefs)) : null;
        var partInfos = [];
        var fnAppendPartInfo = function(part) { // Construct part info
            var flatPathsAndNames = [];
            var layered = part.thickness_layer_count > 1;
            for (var l = 1; l <= part.thickness_layer_count; l++) {
                $.each(part.entity_names, function () {
                    var count = this[1].length;
                    for (var i = 0; i < count; i++) {
                        flatPathsAndNames.push({
                            path: this[1][i],
                            name: this[0] + (layered ? ' // ' + l : ''),
                        });
                    }
                });
            }
            for (var i = 1; i <= part.count; i++) {
                var bin = null;
                if (tmpBinDefs && tmpBinDefs[part.id]) {
                    bin = tmpBinDefs[part.id].shift();
                }
                partInfos.push({
                    position_in_batch: i,
                    entity_named_path: flatPathsAndNames.length > 0 ? flatPathsAndNames[i - 1].path : '',
                    entity_name: flatPathsAndNames.length > 0 ? flatPathsAndNames[i - 1].name : '',
                    bin: bin,
                    part: part
                });
            }
        }
        var fnAppendPart = function(part) { // Check children
            if (part.children) {
                $.each(part.children, function (index) {
                    fnAppendPartInfo(this);
                });
            } else {
                fnAppendPartInfo(part);
            }
        };
        $.each(group.parts, function (index) {  // Iterate on selection
            if (isPartSelection) {
                if (that.selectionPartIds.includes(this.id)) {
                    fnAppendPart(this);
                }
            } else {
                fnAppendPart(this);
            }
        });

        // Retrieve label options
        rubyCallCommand('core_get_model_preset', { dictionary: 'cutlist_labels_options', section: groupId }, function (response) {

            var labelsOptions = response.preset;

            var $modal = that.appendModalInside('ladb_cutlist_modal_labels', 'tabs/cutlist/_modal-labels.twig', {
                group: group,
                isPartSelection: isPartSelection,
                isBinSorterDisabled: isBinSorterDisabled,
                tab: forceDefaultTab || that.lastLabelsOptionsTab == null ? 'layout' : that.lastLabelsOptionsTab
            });

            // Fetch UI elements
            var $widgetPreset = $('.ladb-widget-preset', $modal);
            var $editorLabelLayout = $('#ladb_editor_label_layout', $modal);
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
            var $sortablePartOrderStrategy = $('#ladb_sortable_part_order_strategy', $modal);
            var $editorLabelOffset = $('#ladb_editor_label_offset', $modal);
            var $btnGenerate = $('#ladb_cutlist_labels_btn_generate', $modal);

            var fnValidOffset = function (offset, colCount, rowCount) {
                if (offset >= colCount * rowCount) {
                    offset = 0;
                }
                return offset;
            }
            var fnUpdatePageSizeFieldsAvailability = function () {
                if ($selectPageFormat.selectpicker('val') == null) {
                    $selectPageFormat.selectpicker('val', '0');
                    $inputPageWidth.ladbTextinputDimension('enable');
                    $inputPageHeight.ladbTextinputDimension('enable');
                } else {
                    $inputPageWidth.ladbTextinputDimension('disable');
                    $inputPageHeight.ladbTextinputDimension('disable');
                }
            }
            var fnConvertPageSettings = function(pageWidth, pageHeight, marginTop, marginRight, marginBottom, marginLeft, spacingH, spacingV, colCount, rowCount, callback) {
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
                    callback(response, colCount, rowCount);
                });
            }
            var fnComputeLabelSize = function(pageWidth, pageHeight, marginTop, marginRight, marginBottom, marginLeft, spacingH, spacingV, colCount, rowCount, callback) {
                fnConvertPageSettings(pageWidth, pageHeight, marginTop, marginRight, marginBottom, marginLeft, spacingH, spacingV, colCount, rowCount, function (response, colCount, rowCount) {
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
                options.layout = $editorLabelLayout.ladbEditorLabelLayout('getElementDefs');
                options.offset = fnValidOffset($editorLabelOffset.ladbEditorLabelOffset('getOffset'), options.col_count, options.row_count);

                var properties = [];
                $sortablePartOrderStrategy.children('li').each(function () {
                    properties.push($(this).data('property'));
                });
                options.part_order_strategy = properties.join('>');

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
                    $editorLabelLayout.ladbEditorLabelLayout('updateSizeAndElementDefs', [ labelWidth, labelHeight, options.layout ]);
                });
                fnConvertPageSettings(options.page_width, options.page_height, options.margin_top, options.margin_right, options.margin_bottom, options.margin_left, options.spacing_h, options.spacing_v, options.col_count, options.row_count, function (response, colCount, rowCount) {
                    $editorLabelOffset.ladbEditorLabelOffset('updateSizeAndOffset', [ response.page_width, response.page_height, response.margin_top, response.margin_right, response.margin_bottom, response.margin_left, response.spacing_h, response.spacing_v, colCount, rowCount, fnValidOffset(options.offset, colCount, rowCount) ]);
                });
                fnUpdatePageSizeFieldsAvailability();

                // Part order sortables

                var properties = options.part_order_strategy.split('>');
                $sortablePartOrderStrategy.empty();
                for (var i = 0; i < properties.length; i++) {
                    var property = properties[i];
                    $sortablePartOrderStrategy.append(Twig.twig({ref: "tabs/cutlist/_labels-option-part-order-strategy-property.twig"}).render({
                        order: property.startsWith('-') ? '-' : '',
                        property: property.startsWith('-') ? property.substring(1) : property,
                        enabled: property !== 'bin' || !isBinSorterDisabled
                    }));
                }
                $sortablePartOrderStrategy.find('a').on('click', function () {
                    var $item = $(this).parent().parent();
                    var $icon = $('i', $(this));
                    var property = $item.data('property');
                    if (property.startsWith('-')) {
                        property = property.substring(1);
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

            }

            $widgetPreset.ladbWidgetPreset({
                dialog: that.dialog,
                dictionary: 'cutlist_labels_options',
                fnFetchOptions: fnFetchOptions,
                fnFillInputs: fnFillInputs
            });
            $editorLabelLayout.ladbEditorLabelLayout({
                dialog: that.dialog,
                group: group,
                partInfo: partInfos[0],
                hideMaterialColors: that.generateOptions.hide_material_colors
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
            $editorLabelOffset.ladbEditorLabelOffset();

            fnFillInputs(labelsOptions);

            // Bind tabs
            $('a[data-toggle=tab]', $modal).on('shown.bs.tab', function (e) {
                var tabId = $(e.target).attr('href');
                that.lastLabelsOptionsTab = tabId.substring('#tab_labels_options_'.length);
                if (that.lastLabelsOptionsTab === 'layout') {

                    fnComputeLabelSize($inputPageWidth.val(), $inputPageHeight.val(), $inputMarginTop.val(), $inputMarginRight.val(), $inputMarginBottom.val(), $inputMarginLeft.val(), $inputSpacingH.val(), $inputSpacingV.val(), $inputColCount.val(), $inputRowCount.val(), function (labelWidth, labelHeight) {
                        $editorLabelLayout.ladbEditorLabelLayout('updateSize', [ labelWidth, labelHeight ]);
                    });

                }
                if (that.lastLabelsOptionsTab === 'offset') {

                    fnConvertPageSettings($inputPageWidth.val(), $inputPageHeight.val(), $inputMarginTop.val(), $inputMarginRight.val(), $inputMarginBottom.val(), $inputMarginLeft.val(), $inputSpacingH.val(), $inputSpacingV.val(), $inputColCount.val(), $inputRowCount.val(), function (response, colCount, rowCount) {
                        $editorLabelOffset.ladbEditorLabelOffset('updateSizeAndOffset', [ response.page_width, response.page_height, response.margin_top, response.margin_right, response.margin_bottom, response.margin_left, response.spacing_h, response.spacing_v, colCount, rowCount, null ]);
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
                    var warnings = [];
                    var pages = [];

                    if (isPartSelection) {

                        // Warn for partiel result
                        warnings.push('tab.cutlist.labels.warning.is_part_selection')

                    }

                    var fnRenderSlide = function () {

                        var $slide = that.pushNewSlide('ladb_cutlist_slide_labels', 'tabs/cutlist/_slide-labels.twig', $.extend({
                            errors: errors,
                            warnings: warnings,
                            filename: that.filename,
                            modelName: that.modelName,
                            pageName: that.pageName,
                            isEntitySelection: that.isEntitySelection,
                            lengthUnit: that.lengthUnit,
                            generatedAt: new Date().getTime() / 1000,
                            group: group,
                            pages: pages,
                            hideMaterialColors: that.generateOptions.hide_material_colors
                        }, labelsOptions), function () {
                            that.dialog.setupTooltips();
                        });

                        // Fetch UI elements
                        var $btnLabels = $('#ladb_btn_labels', $slide);
                        var $btnPrint = $('#ladb_btn_print', $slide);
                        var $btnClose = $('#ladb_btn_close', $slide);

                        // Bind buttons
                        $btnLabels.on('click', function () {
                            that.labelsGroup(groupId, binDefs);
                        });
                        $btnPrint.on('click', function () {
                            $(this).blur();
                            that.print(that.cutlistTitle + ' - ' + i18next.t('tab.cutlist.labels.title'), '0', `${response.page_width}in ${response.page_height}in`);
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

                    };

                    if (labelWidth <= 0 || isNaN(labelWidth) || labelHeight <= 0 || isNaN(labelHeight)) {

                        // Invalid size push an error
                        errors.push('tab.cutlist.labels.error.invalid_size');

                        fnRenderSlide();

                    } else {

                        // Sort part infos
                        var fnFieldSorter = function (properties) {
                            return function (a, b) {
                                return properties
                                    .map(function (property) {
                                        var dir = 1;
                                        if (property[0] === '-') {
                                            dir = -1;
                                            property = property.substring(1);
                                        }
                                        var valA, valB;
                                        if (property === 'entity_named_path') {
                                            valA = a.entity_named_path;
                                            valB = b.entity_named_path;
                                        } else if (property === 'entity_name') {
                                            valA = a.entity_name;
                                            valB = b.entity_name;
                                        } else if (property === 'bin') {
                                            valA = a.bin;
                                            valB = b.bin;
                                        } else if (property === 'number') {
                                            valA = isNaN(a.part.number) ? a.part.number.padStart(3, ' ') : a.part.number;    // Pad part number with ' ' to be sure that 'AA' is greater than 'Z' -> " AA" > "  Z"
                                            valB = isNaN(a.part.number) ? b.part.number.padStart(3, ' ') : b.part.number;
                                        } else {
                                            valA = a.part[property];
                                            valB = b.part[property];
                                        }
                                        if (valA > valB) return dir;
                                        if (valA < valB) return -(dir);
                                        return 0;
                                    })
                                    .reduce(function firstNonZeroValue(p, n) {
                                        return p ? p : n;
                                    }, 0);
                            };
                        };
                        partInfos.sort(fnFieldSorter(labelsOptions.part_order_strategy.split('>')));

                        // Compute custom formulas
                        rubyCallCommand('cutlist_labels_compute_elements', { part_infos: partInfos, layout: labelsOptions.layout }, function (response) {

                            if (response.errors) {
                                errors.push(response.errors);
                            }
                            if (response.part_infos) {
                                partInfos = response.part_infos;
                            }

                            // Split part infos into pages
                            var page;
                            var gIndex = 0;
                            for (var i = 1; i <= labelsOptions.offset; i++) {
                                if (gIndex % (labelsOptions.row_count * labelsOptions.col_count) === 0) {
                                    page = {
                                        partInfos: []
                                    }
                                    pages.push(page);
                                }
                                page.partInfos.push({
                                    part: null
                                });
                                gIndex++;
                            }
                            $.each(partInfos, function (index) {
                                if (gIndex % (labelsOptions.row_count * labelsOptions.col_count) === 0) {
                                    page = {
                                        partInfos: []
                                    }
                                    pages.push(page);
                                }
                                page.partInfos.push(this);
                                gIndex++;
                            })

                            fnRenderSlide();

                        });

                    }

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

    LadbTabCutlist.prototype.editOptions = function (tab) {
        var that = this;

        if (tab === undefined) {
            tab = this.lastOptionsTab;
        }
        if (tab === null || tab.length === 0) {
            tab = 'general';
        }
        this.lastOptionsTab = tab;

        var $modal = that.appendModalInside('ladb_cutlist_modal_options', 'tabs/cutlist/_modal-options.twig', {
            tab: tab
        });

        // Fetch UI elements
        var $tabs = $('a[data-toggle="tab"]', $modal);
        var $widgetPreset = $('.ladb-widget-preset', $modal);
        var $inputAutoOrient = $('#ladb_input_auto_orient', $modal);
        var $inputFlippedDetection = $('#ladb_input_flipped_detection', $modal);
        var $inputSmartMaterial = $('#ladb_input_smart_material', $modal);
        var $inputDynamicAttributesName = $('#ladb_input_dynamic_attributes_name', $modal);
        var $inputPartNumberWithLetters = $('#ladb_input_part_number_with_letters', $modal);
        var $inputPartNumberSequenceByGroup = $('#ladb_input_part_number_sequence_by_group', $modal);
        var $inputPartFolding = $('#ladb_input_part_folding', $modal);
        var $inputHideInstanceNames = $('#ladb_input_hide_entity_names', $modal);
        var $inputHideDescriptions = $('#ladb_input_hide_descriptions', $modal);
        var $inputHideTags = $('#ladb_input_hide_tags', $modal);
        var $inputHideCuttingDimensions = $('#ladb_input_hide_cutting_dimensions', $modal);
        var $inputHideBBoxDimensions = $('#ladb_input_hide_bbox_dimensions', $modal);
        var $inputHideFinalAreas = $('#ladb_input_hide_final_areas', $modal);
        var $inputHideEdges = $('#ladb_input_hide_edges', $modal);
        var $inputHideFaces = $('#ladb_input_hide_faces', $modal);
        var $inputHideMaterialColors = $('#ladb_input_hide_material_colors', $modal);
        var $inputMinimizeOnHighlight = $('#ladb_input_minimize_on_highlight', $modal);
        var $sortablePartOrderStrategy = $('#ladb_sortable_part_order_strategy', $modal);
        var $inputTags = $('#ladb_input_tags', $modal);
        var $sortableDimensionColumnOrderStrategy = $('#ladb_sortable_dimension_column_order_strategy', $modal);
        var $btnSetupModelUnits = $('#ladb_cutlist_options_setup_model_units', $modal);
        var $btnUpdate = $('#ladb_cutlist_options_update', $modal);

        // Define useful functions
        var fnFetchOptions = function (options) {
            options.auto_orient = $inputAutoOrient.is(':checked');
            options.flipped_detection = $inputFlippedDetection.is(':checked');
            options.smart_material = $inputSmartMaterial.is(':checked');
            options.dynamic_attributes_name = $inputDynamicAttributesName.is(':checked');
            options.part_number_with_letters = $inputPartNumberWithLetters.is(':checked');
            options.part_number_sequence_by_group = $inputPartNumberSequenceByGroup.is(':checked');
            options.part_folding = $inputPartFolding.is(':checked');
            options.hide_entity_names = $inputHideInstanceNames.is(':checked');
            options.hide_descriptions = $inputHideDescriptions.is(':checked');
            options.hide_tags = $inputHideTags.is(':checked');
            options.hide_cutting_dimensions = $inputHideCuttingDimensions.is(':checked');
            options.hide_bbox_dimensions = $inputHideBBoxDimensions.is(':checked');
            options.hide_final_areas = $inputHideFinalAreas.is(':checked');
            options.hide_edges = $inputHideEdges.is(':checked');
            options.hide_faces = $inputHideFaces.is(':checked');
            options.hide_material_colors = $inputHideMaterialColors.is(':checked');
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
            $inputFlippedDetection.prop('checked', options.flipped_detection);
            $inputSmartMaterial.prop('checked', options.smart_material);
            $inputDynamicAttributesName.prop('checked', options.dynamic_attributes_name);
            $inputPartNumberWithLetters.prop('checked', options.part_number_with_letters);
            $inputPartNumberSequenceByGroup.prop('checked', options.part_number_sequence_by_group);
            $inputPartFolding.prop('checked', options.part_folding);
            $inputHideInstanceNames.prop('checked', options.hide_entity_names);
            $inputHideDescriptions.prop('checked', options.hide_descriptions);
            $inputHideTags.prop('checked', options.hide_tags);
            $inputHideCuttingDimensions.prop('checked', options.hide_cutting_dimensions);
            $inputHideBBoxDimensions.prop('checked', options.hide_bbox_dimensions);
            $inputHideFinalAreas.prop('checked', options.hide_final_areas);
            $inputHideEdges.prop('checked', options.hide_edges);
            $inputHideFaces.prop('checked', options.hide_faces);
            $inputHideMaterialColors.prop('checked', options.hide_material_colors);
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
                    property: property.startsWith('-') ? property.substring(1) : property
                }));
            }
            $sortablePartOrderStrategy.find('a').on('click', function () {
                var $item = $(this).parent().parent();
                var $icon = $('i', $(this));
                var property = $item.data('property');
                if (property.startsWith('-')) {
                    property = property.substring(1);
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

        // Bind tabs
        $tabs.on('shown.bs.tab', function (e) {
            that.lastOptionsTab = $(e.target).attr('href').substring('#tab_options_'.length);
        });

        // Bind input
        $inputTags.ladbTextinputTokenfield({
            unique: true,
            autocomplete: {
                source: that.usedTags,
                delay: 100
            }
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

        // Bind modal
        $modal.on('hide.bs.modal', function () {
            $inputTags.ladbTextinputTokenfield('destroy');
        });

        // Show modal
        $modal.modal('show');

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
            this.blur();
            that.print(that.cutlistTitle + ' - ' + i18next.t('tab.cutlist.title'));
        });
        this.$btnExport.on('click', function () {
            that.exportCutlist();
            this.blur();
        });
        this.$btnLayout.on('click', function () {
            that.layoutAllParts();
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
        this.$itemExport2dAllParts.on('click', function () {
            if (!$(this).parents('li').hasClass('disabled')) {
                that.writeAllParts(true);
            }
            this.blur();
        });
        this.$itemExport3dAllParts.on('click', function () {
            if (!$(this).parents('li').hasClass('disabled')) {
                that.writeAllParts(false);
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
        this.$itemResetPrices.on('click', function () {
            that.dialog.confirm(i18next.t('default.caution'), i18next.t('tab.cutlist.menu.reset_prices_confirm'), function () {
                rubyCallCommand('cutlist_reset_prices', null, function (response) {

                    if (response.errors) {
                        that.dialog.notifyErrors(response.errors);
                    } else {
                        that.dialog.alert(null, i18next.t('tab.cutlist.menu.reset_prices_success'), function () {
                            that.generateCutlist();
                        }, {
                            okBtnLabel: i18next.t('default.close')
                        });
                    }

                });
            }, {
                confirmBtnType: 'danger'
            });
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

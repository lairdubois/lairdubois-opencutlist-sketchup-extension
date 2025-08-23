+function ($) {
    'use strict';

    // CONSTANTS
    // ======================

    // Various Consts

    const MULTIPLE_VALUE = '-1';

    // CLASS DEFINITION
    // ======================

    const LadbTabCutlist = function (element, options, dialog) {
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
        this.lastEstimateOptionsTab = null;
        this.lastCuttingdiagram1dOptionsTab = null;
        this.lastCuttingdiagram2dOptionsTab = null;
        this.lastPackingOptionsTab = null;
        this.lastLabelsOptionsTab = null;
        this.lastLayoutOptionsTab = null;

        this.$header = $('.ladb-header', this.$element);
        this.$headerExtra = $('.ladb-header-extra', this.$header);
        this.$btnGenerate = $('#ladb_btn_generate', this.$header);
        this.$btnPrint = $('#ladb_btn_print', this.$header);
        this.$btnExport = $('#ladb_btn_export', this.$header);
        this.$btnLayout = $('#ladb_btn_layout', this.$header);
        this.$btnEstimate = $('#ladb_btn_estimate', this.$header);
        this.$btnOptions = $('#ladb_btn_options', this.$header);
        this.$itemHighlightAllParts = $('#ladb_item_highlight_all_parts', this.$header);
        this.$itemLabelsAllParts = $('#ladb_item_labels_all_parts', this.$header);
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
        const that = this;

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

            rubyCallCommand('cutlist_generate', $.extend({}, that.generateOptions, that.generateFilters), function (response) {

                that.generateAt = new Date().getTime() / 1000;
                that.setObsolete(false);

                const errors = response.errors;
                const warnings = response.warnings;
                const tips = response.tips;
                const filename = response.filename;
                const modelName = response.model_name;
                const modelDescription = response.model_description;
                const modelActivePath = response.model_active_path;
                const pageName = response.page_name;
                const pageDescription = response.page_description;
                const isEntitySelection = response.is_entity_selection;
                const lengthUnit = response.length_unit;
                const massUnitStrippedname = response.mass_unit_strippedname;
                const currencySymbol = response.currency_symbol;
                const instanceCount = response.instance_count;
                const ignoredInstanceCount = response.ignored_instance_count;
                const usedTags = response.used_tags;
                const materialUsages = response.material_usages;
                const groups = response.groups;
                const solidWoodMaterialCount = response.solid_wood_material_count;
                const sheetGoodMaterialCount = response.sheet_good_material_count;
                const dimensionalMaterialCount = response.dimensional_material_count;
                const edgeMaterialCount = response.edge_material_count;
                const hardwareMaterialCount = response.hardware_material_count;

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
                for (let i = 0; i < materialUsages.length; i++) {
                    if (materialUsages[i].type === 4 && materialUsages[i].use_count > 0) {     // 4 = TYPE_EDGE
                        that.usedEdgeMaterialDisplayNames.push(materialUsages[i].display_name);
                    }
                }

                // Compute usedVeneerMaterialDisplayNames
                for (let i = 0; i < materialUsages.length; i++) {
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
                that.$btnEstimate.prop('disabled', solidWoodMaterialCount + sheetGoodMaterialCount + dimensionalMaterialCount + edgeMaterialCount + hardwareMaterialCount === 0);
                that.$itemHighlightAllParts.parents('li').toggleClass('disabled', groups.length === 0);
                that.$itemLabelsAllParts.parents('li').toggleClass('disabled', groups.length === 0);
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
                const hiddenGroupIdsLength = that.generateOptions.hidden_group_ids.length;
                for (let i = hiddenGroupIdsLength - 1 ; i >= 0; i--) {
                    if (that.generateOptions.hidden_group_ids[i] == null || that.generateOptions.hidden_group_ids[i].endsWith('summary')) {
                        continue;
                    }
                    let exists = false;
                    for (let j = 0; j < groups.length; j++) {
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
                const fnGenerateWithTagsFilter = function () {
                    const tokenList = $('#ladb_cutlist_tags_filter', that.$page).tokenfield('getTokensList');
                    that.generateFilters.tags_filter = tokenList.length === 0 ? [] : tokenList.split(';');
                    that.generateCutlist(function () {
                        $('#ladb_cutlist_tags_filter-tokenfield', that.$page).focus();
                    });
                }
                const fnMouseEnter = function () {
                    const $row = $(this);
                    $row.addClass('ladb-hover');
                    if ($row.hasClass('ladb-selected')) {
                        $row.siblings('.ladb-selected').addClass('ladb-hover');
                    }
                };
                const fnMouseLeave = function () {
                    const $row = $(this);
                    $row.removeClass('ladb-hover');
                    if ($row.hasClass('ladb-selected')) {
                        $row.siblings('.ladb-selected').removeClass('ladb-hover');
                    }
                };

                // Bind inputs
                $('#ladb_cutlist_tags_filter', that.$page)
                    .on('tokenfield:createtoken', function (e) {

                        const m = e.attrs.value.match(/([+-])(.*)/);
                        if (m) {
                            e.attrs.oko = m[1]
                            e.attrs.label = m[2];
                        } else {
                            e.attrs.oko = '+'
                            e.attrs.label = e.attrs.value;
                            e.attrs.value = '+' + e.attrs.value;
                        }

                        // Unique token
                        const tokens = $(this).tokenfield('getTokens');
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
                        const $okoBtn = $('<a href="#" class="oko" data-toggle="tooltip" title="' + i18next.t('tab.cutlist.tooltip.oko_label_filter') + '"></a>')
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
                    .tokenfield($.extend({
                        autocomplete: {
                            source: that.usedTags,
                            delay: 100
                        },
                        showAutocompleteOnFocus: false
                    }, TOKENFIELD_OPTIONS))
                    .on('tokenfield:createdtoken tokenfield:removedtoken', function (e) {
                        fnGenerateWithTagsFilter();
                    })
                ;
                $('#ladb_cutlist_edge_material_names_filter', that.$page)
                    .tokenfield($.extend({
                        autocomplete: {
                            source: that.usedEdgeMaterialDisplayNames,
                            delay: 100
                        },
                        showAutocompleteOnFocus: false
                    }, TOKENFIELD_OPTIONS))
                    .on('tokenfield:createtoken', function (e) {

                        // Unique token
                        const tokens = $(this).tokenfield('getTokens');
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
                        const tokenList = $(this).tokenfield('getTokensList');
                        that.generateFilters.edge_material_names_filter = tokenList.length === 0 ? [] : tokenList.split(';');
                        that.generateCutlist(function () {
                            $('#ladb_cutlist_edge_material_names_filter-tokenfield', that.$page).focus();
                        });
                    })
                ;
                $('#ladb_cutlist_veneer_material_names_filter', that.$page)
                    .tokenfield($.extend({
                        autocomplete: {
                            source: that.usedVeneerMaterialDisplayNames,
                            delay: 100
                        },
                        showAutocompleteOnFocus: false
                    }, TOKENFIELD_OPTIONS))
                    .on('tokenfield:createtoken', function (e) {

                        // Unique token
                        const tokens = $(this).tokenfield('getTokens');
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
                        const tokenList = $(this).tokenfield('getTokensList');
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
                    const $group = $(this).parents('.ladb-cutlist-group');
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
                    const $target = $($(this).attr('href'));
                    if ($target.data('group-id')) {
                        that.showGroup($target);
                    }
                    that.scrollSlideToTarget(null, $target, true, true);
                    return false;
                });
                $('a.ladb-btn-edge-material-filter', that.$page).on('click', function () {
                    $(this).blur();
                    const materialFilter = $(this).data('material-display-name');
                    const indexOf = that.generateFilters.edge_material_names_filter.indexOf(materialFilter);
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
                    const materialFilter = $(this).data('material-display-name');
                    const indexOf = that.generateFilters.veneer_material_names_filter.indexOf(materialFilter);
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

                    const materialId = $(this).data('material-id');
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
                $('a.ladb-btn-toggle-visible', that.$page).on('click', function () {
                    $(this).blur();
                    const $target = $($(this).attr('href'));
                    if ($target.data('group-id')) {
                        that.toggleGroup($target);
                    }
                    return false;
                });
                $('a.ladb-btn-add-std-dimension-to-material', that.$page).on('click', function () {
                    $(this).blur();
                    const $group = $(this).parents('.ladb-cutlist-group');
                    const groupId = $group.data('group-id');
                    const group = that.findGroupById(groupId);
                    if (group) {

                        // Flag to ignore next material change event
                        that.ignoreNextMaterialEvents = true;

                        // Use real std dimension if dimension is rounded
                        const std_dimension = group.std_dimension_rounded ? group.std_dimension_real : group.std_dimension;

                        rubyCallCommand('materials_add_std_dimension_command', { material_name: group.material_name, std_dimension: std_dimension }, function (response) {

                            // Flag to stop ignoring next material change event
                            that.ignoreNextMaterialEvents = false;

                            if (response.errors) {
                                that.dialog.notifyErrors(response.errors);
                            } else {

                                const wTop = $group.offset().top - $(window).scrollTop();

                                // Refresh the list
                                that.generateCutlist(function () {

                                    // Try to scroll to the edited group's block
                                    const $group = $('#ladb_group_' + groupId, that.$page);
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

                    const $group = $(this).parents('.ladb-cutlist-group');
                    const groupId = $group.data('group-id');
                    const group = that.findGroupById(groupId);
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
                    const $group = $(this).parents('.ladb-cutlist-group');
                    const groupId = $group.data('group-id');
                    that.highlightGroupParts(groupId);
                    $(this).blur();
                });
                $('a.ladb-item-export-2d-group-parts', that.$page).on('click', function () {
                    const $group = $(this).parents('.ladb-cutlist-group');
                    const groupId = $group.data('group-id');
                    that.writeGroupParts(groupId, true);
                    $(this).blur();
                });
                $('a.ladb-item-export-3d-group-parts', that.$page).on('click', function () {
                    const $group = $(this).parents('.ladb-cutlist-group');
                    const groupId = $group.data('group-id');
                    that.writeGroupParts(groupId, false);
                    $(this).blur();
                });
                $('a.ladb-item-export-group-parts', that.$page).on('click', function () {
                    const $group = $(this).parents('.ladb-cutlist-group');
                    const groupId = $group.data('group-id');
                    that.exportGroupParts(groupId, false);
                    $(this).blur();
                });
                $('a.ladb-item-estimate-group-parts', that.$page).on('click', function () {
                    const $group = $(this).parents('.ladb-cutlist-group');
                    const groupId = $group.data('group-id');
                    that.estimateGroupParts(groupId, false);
                    $(this).blur();
                });
                $('a.ladb-item-hide-all-other-groups', that.$page).on('click', function () {
                    $(this).blur();
                    const $group = $(this).parents('.ladb-cutlist-group');
                    const groupId = $group.data('group-id');
                    that.hideAllGroups(groupId);
                    that.scrollSlideToTarget(null, $group, true, false);
                });
                $('a.ladb-item-show-all-groups', that.$page).on('click', function () {
                    $(this).blur();
                    that.showAllGroups();
                });
                $('a.ladb-item-dimensions-help', that.$page).on('click', function () {
                    $(this).blur();
                    const $group = $(this).parents('.ladb-cutlist-group');
                    const groupId = $group.data('group-id');
                    that.dimensionsHelpGroup(groupId);
                });
                $('a.ladb-item-numbers-save', that.$page).on('click', function () {
                    $(this).blur();
                    const $group = $(this).parents('.ladb-cutlist-group');
                    const groupId = $group.data('group-id');
                    const wTop = $group.offset().top - $(window).scrollTop();
                    that.numbersSave({ group_id: groupId }, function () {
                        that.$rootSlide.animate({ scrollTop: $('#ladb_group_' + groupId).offset().top - wTop }, 0);
                    });
                });
                $('a.ladb-item-numbers-reset', that.$page).on('click', function () {
                    $(this).blur();
                    const $group = $(this).parents('.ladb-cutlist-group');
                    const groupId = $group.data('group-id');
                    const wTop = $group.offset().top - $(window).scrollTop();
                    that.numbersReset({ group_id: groupId }, function () {
                        that.$rootSlide.animate({ scrollTop: $('#ladb_group_' + groupId).offset().top - wTop }, 0);
                    });
                });
                $('button.ladb-btn-group-cuttingdiagram1d', that.$page).on('click', function () {
                    $(this).blur();
                    const $group = $(this).parents('.ladb-cutlist-group');
                    const groupId = $group.data('group-id');
                    that.cuttingdiagram1dGroup(groupId, true);
                });
                $('button.ladb-btn-group-cuttingdiagram2d', that.$page).on('click', function () {
                    $(this).blur();
                    const $group = $(this).parents('.ladb-cutlist-group');
                    const groupId = $group.data('group-id');
                    that.cuttingdiagram2dGroup(groupId, true);
                });
                $('button.ladb-btn-group-packing', that.$page).on('click', function () {
                    $(this).blur();
                    const $group = $(this).parents('.ladb-cutlist-group');
                    const groupId = $group.data('group-id');
                    that.packingGroup(groupId);
                });
                $('button.ladb-btn-group-labels', that.$page).on('click', function () {
                    $(this).blur();
                    const $group = $(this).parents('.ladb-cutlist-group');
                    const groupId = $group.data('group-id');
                    that.labelsGroupParts(groupId);
                });
                $('button.ladb-btn-group-layout', that.$page).on('click', function () {
                    $(this).blur();
                    const $group = $(this).parents('.ladb-cutlist-group');
                    const groupId = $group.data('group-id');
                    that.layoutGroupParts(groupId);
                });
                $('.ladb-minitools a[data-tab]', that.$page).on('click', function () {
                    $(this).blur();
                    const $part = $(this).parents('.ladb-cutlist-row');
                    const partId = $part.data('part-id');
                    const tab = $(this).data('tab');
                    that.editPart(partId, undefined, tab);
                    return false;
                });
                $('a.ladb-btn-select-group-parts', that.$page).on('click', function () {
                    $(this).blur();
                    const $group = $(this).parents('.ladb-cutlist-group');
                    const groupId = $group.data('group-id');
                    that.selectGroupParts(groupId);
                    return false;
                });
                $('a.ladb-btn-select-part, td.ladb-btn-select-part', that.$page)
                    .on('click', function () {
                        $(this).blur();
                        const $part = $(this).parents('.ladb-cutlist-row');
                        const partId = $part.data('part-id');
                        that.selectPart(partId);
                        return false;
                    })
                    .on('dblclick', function() {
                        $(this).blur();
                        const $group = $(this).parents('.ladb-cutlist-group');
                        const groupId = $group.data('group-id');
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
                    const $part = $(this).parents('.ladb-cutlist-row');
                    const partId = $part.data('part-id');
                    that.highlightPart(partId);
                    return false;
                });
                $('a.ladb-btn-edit-part', that.$page).on('click', function () {
                    $(this).blur();
                    const $part = $(this).parents('.ladb-cutlist-row');
                    const partId = $part.data('part-id');
                    that.editPart(partId);
                    return false;
                });
                $('a.ladb-btn-folding-toggle-row', that.$page).on('click', function () {
                    $(this).blur();
                    const $part = $(this).parents('.ladb-cutlist-row-folder');
                    that.toggleFoldingRow($part);
                    return false;
                });
                $('a.ladb-btn-label-filter', that.$page).on('click', function () {
                    $(this).blur();
                    const labelFilter = '+' + $(this).html();
                    const indexOf = that.generateFilters.tags_filter.indexOf(labelFilter);
                    if (indexOf > -1) {
                        that.generateFilters.tags_filter.splice(indexOf, 1);
                    } else {
                        that.generateFilters.tags_filter.push(labelFilter);
                    }
                    that.generateCutlist();
                    return false;
                });
                $('.ladb-cutlist-row', that.$page)
                    .on('mouseenter', fnMouseEnter)
                    .on('mouseleave', fnMouseLeave)
                    .on('click', function () {
                        $(this).blur();
                        $('.ladb-click-tool', $(this)).first().click();
                        return false;
                    })
                    .on('contextmenu', function(e) {
                        const row = this;
                        const partId = $(row).data('part-id');
                        if (partId) {
                            fnMouseEnter.call(row)
                            const groupAndPart = that.findGroupAndPartById(partId);
                            const isMultiple = that.selectionGroupId === groupAndPart.group.id && that.selectionPartIds.includes(groupAndPart.part.id) && that.selectionPartIds.length > 1;
                            let items = [];
                            items.push({ text: isMultiple ? that.selectionPartIds.length + ' ' + i18next.t('default.part_plural') : groupAndPart.part.name});
                            items.push({ separator: true });
                            items.push({
                                text: i18next.t('tab.cutlist.highlight_part' + (isMultiple ? 's' : '')),
                                callback: function () {
                                    that.highlightPart(partId);
                                }
                            });
                            items.push({ separator: true });
                            items.push({
                                text: i18next.t('default.export') + ' / ' + i18next.t('tab.cutlist.menu.write_2d') + '...',
                                callback: function () {
                                    if (isMultiple) {
                                        that.writeGroupParts(groupAndPart.group.id, true);
                                    } else {
                                        that.writePart(partId, true);
                                    }
                                }
                            });
                            items.push({
                                text: i18next.t('default.export') + ' / ' + i18next.t('tab.cutlist.menu.write_3d') + '...',
                                callback: function () {
                                    if (isMultiple) {
                                        that.writeGroupParts(groupAndPart.group.id, false);
                                    } else {
                                        that.writePart(partId, false);
                                    }
                                }
                            });
                            that.dialog.showContextMenu(e.clientX, e.clientY, items, function () { fnMouseLeave.call(row) });
                            e.preventDefault();
                        }
                    })
                ;

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

    // Export /////

    LadbTabCutlist.prototype.exportAllParts = function () {
        let partIdsWithContext = this.grabVisiblePartIdsWithContext(null);
        this.exportParts(partIdsWithContext.partIds, partIdsWithContext.context);
    }

    LadbTabCutlist.prototype.exportGroupParts = function (groupId, forceDefaultTab) {
        let partIdsWithContext = this.grabVisiblePartIdsWithContext(groupId);
        this.exportParts(partIdsWithContext.partIds, partIdsWithContext.context, forceDefaultTab);
    }

    LadbTabCutlist.prototype.exportParts = function (partIds, context, forceDefaultTab) {
        const that = this;

        const section = context && context.targetGroup ? context.targetGroup.id : null;

        // Retrieve export option options
        rubyCallCommand('core_get_model_preset', { dictionary: 'cutlist_export_options', section: section }, function (response) {

            const exportOptions = response.preset;

            const $modal = that.appendModalInside('ladb_cutlist_modal_export', 'tabs/cutlist/_modal-export.twig', {
                group: context ? context.targetGroup : null,
                isGroupSelection: context ? context.isGroupSelection : false,
                isPartSelection: context ? context.isPartSelection : false,
                tab: forceDefaultTab || that.lastExportOptionsTab == null ? 'customize' : that.lastExportOptionsTab
            });

            // Fetch UI elements
            const $tabs = $('a[data-toggle="tab"]', $modal);
            const $widgetPreset = $('.ladb-widget-preset', $modal);
            const $radiosSource = $('input[name=ladb_radios_source]', $modal);
            const $selectFormat = $('#ladb_cutlist_export_select_format', $modal);
            const $selectCsvColSep = $('#ladb_cutlist_export_select_csv_col_sep', $modal);
            const $selectCsvEncoding = $('#ladb_cutlist_export_select_csv_encoding', $modal);
            const $editorSummary = $('#ladb_cutlist_export_editor_summary', $modal);
            const $editorCutlist = $('#ladb_cutlist_export_editor_cutlist', $modal);
            const $editorInstancesList = $('#ladb_cutlist_export_editor_instances_list', $modal);
            const $formGroupCsv = $('.form-group-csv', $modal);
            const $btnPreview = $('#ladb_cutlist_export_btn_preview', $modal);
            const $btnExport = $('#ladb_cutlist_export_btn_export', $modal);
            const $btnExportCsv = $('#ladb_cutlist_export_btn_export_csv', $modal);
            const $btnExportXlsx = $('#ladb_cutlist_export_btn_export_xlsx', $modal);
            const $btnExportCopyAll = $('#ladb_cutlist_export_btn_export_copy_all', $modal);
            const $btnExportCopyValues = $('#ladb_cutlist_export_btn_export_copy_values', $modal);

            // Define useful functions

            const fnComputeSorterVisibility = function (source) {
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
            const fnFetchLastExportOptionsEditingItem = function (source) {
                let index = null;
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
            const fnUpdateFieldsVisibility = function () {
                const format = $selectFormat.val();
                const isCsv = format === 'csv';
                if (isCsv) $formGroupCsv.show(); else $formGroupCsv.hide();
                $('#ladb_cutlist_export_btn_export_format', $btnExport).html(format.toUpperCase());
            };
            const fnCopyToClipboard = function(noHeader) {
                rubyCallCommand('cutlist_export', {
                    part_ids: partIds,
                    source: exportOptions.source,
                    col_defs: exportOptions.source_col_defs[exportOptions.source],
                    format: 'pasteable',
                    no_header: noHeader
                }, function (response) {
                    if (response.errors) {
                        that.dialog.notifyErrors(response.errors);
                    }
                    if (response.pasteable) {
                        that.dialog.copyToClipboard(response.pasteable);
                    }
                });
            }
            const fnFetchOptions = function (options) {
                options.source = that.toInt($radiosSource.filter(':checked').val());
                options.format = $selectFormat.val();
                options.csv_col_sep = that.toInt($selectCsvColSep.val());
                options.csv_encoding = that.toInt($selectCsvEncoding.val());

                if (options.source_col_defs == null) {
                    options.source_col_defs = [];
                }
                options.source_col_defs[0] = $editorSummary.ladbEditorExport('getColDefs');
                options.source_col_defs[1] = $editorCutlist.ladbEditorExport('getColDefs');
                options.source_col_defs[2] = $editorInstancesList.ladbEditorExport('getColDefs');

            }
            const fnFillInputs = function (options) {
                $radiosSource.filter('[value=' + options.source + ']').click();
                $selectFormat.selectpicker('val', options.format);
                $selectCsvColSep.selectpicker('val', options.csv_col_sep);
                $selectCsvEncoding.selectpicker('val', options.csv_encoding);
                $editorSummary.ladbEditorExport('setColDefs', [ options.source_col_defs[0] ])
                $editorCutlist.ladbEditorExport('setColDefs', [ options.source_col_defs[1] ])
                $editorInstancesList.ladbEditorExport('setColDefs', [ options.source_col_defs[2] ])
                fnComputeSorterVisibility(options.source);
                fnUpdateFieldsVisibility();
            }

            $widgetPreset.ladbWidgetPreset({
                dialog: that.dialog,
                dictionary: 'cutlist_export_options',
                fnFetchOptions: fnFetchOptions,
                fnFillInputs: fnFillInputs
            });
            $selectFormat
                .selectpicker(SELECT_PICKER_OPTIONS)
                .on('changed.bs.select', function () {
                    fnUpdateFieldsVisibility();
                })
            ;
            $selectCsvColSep.selectpicker(SELECT_PICKER_OPTIONS);
            $selectCsvEncoding.selectpicker(SELECT_PICKER_OPTIONS);
            $editorSummary.ladbEditorExport({
                dialog: that.dialog,
                vars: [
                    { name: 'material', type: 'material' },
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
                    { name: 'material', type: 'material' },
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
                    { name: 'layers', type: 'array' },
                    { name: 'component_definition', type: 'component_definition' },
                    { name: 'component_instances', type: 'array' }
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
                    { name: 'material', type: 'material' },
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
                    { name: 'layer', type: 'string' },
                    { name: 'component_definition', type: 'component_definition' },
                    { name: 'component_instance', type: 'component_instance' },
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

            // Bind radios
            $radiosSource.on('change', function () {
                fnComputeSorterVisibility($radiosSource.filter(':checked').val());
            });

            // Bind buttons
            $btnPreview.on('click', function () {

                // Fetch options
                fnFetchOptions(exportOptions);

                // Fetch last editing item
                fnFetchLastExportOptionsEditingItem(exportOptions.source);

                // Store options
                rubyCallCommand('core_set_model_preset', { dictionary: 'cutlist_export_options', section: section, values: exportOptions });

                rubyCallCommand('cutlist_export', {
                    part_ids: partIds,
                    source: exportOptions.source,
                    col_defs: exportOptions.source_col_defs[exportOptions.source],
                    format: 'table'
                }, function (response) {

                    if (response.errors) {
                        that.dialog.notifyErrors(response.errors);
                    }
                    if (response.rows) {

                        const $slide = that.pushNewSlide('ladb_cutlist_slide_export', 'tabs/cutlist/_slide-export.twig', $.extend({
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

                        // Fetch UI elements
                        const $btnExport = $('#ladb_btn_export', $slide);
                        const $itemCopyAll = $('#ladb_item_copy_all', $slide);
                        const $itemCopyValues = $('#ladb_item_copy_values', $slide);
                        const $btnClose = $('#ladb_btn_close', $slide);

                        // Bind buttons
                        $btnExport.on('click', function () {
                            that.exportParts(partIds, context, forceDefaultTab);
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
                rubyCallCommand('core_set_model_preset', { dictionary: 'cutlist_export_options', section: section, values: exportOptions });

                rubyCallCommand('cutlist_export', {
                    part_ids: partIds,
                    source: exportOptions.source,
                    format: exportOptions.format,
                    col_sep: exportOptions.col_sep,
                    encoding: exportOptions.encoding,
                    col_defs: exportOptions.source_col_defs[exportOptions.source]
                }, function (response) {

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
            $btnExportCsv.on('click', function () {
                $selectFormat.selectpicker('val', 'csv');
                $btnExport.click();
            });
            $btnExportXlsx.on('click', function () {
                $selectFormat.selectpicker('val', 'xlsx');
                $btnExport.click();
            });
            $btnExportCopyAll.on('click', function () {

                // Fetch options
                fnFetchOptions(exportOptions);

                // Fetch last editing item
                fnFetchLastExportOptionsEditingItem(exportOptions.source);

                // Store options
                rubyCallCommand('core_set_model_preset', { dictionary: 'cutlist_export_options', values: exportOptions });

                fnCopyToClipboard(false);
            });
            $btnExportCopyValues.on('click', function () {

                // Fetch options
                fnFetchOptions(exportOptions);

                // Fetch last editing item
                fnFetchLastExportOptionsEditingItem(exportOptions.source);

                // Store options
                rubyCallCommand('core_set_model_preset', { dictionary: 'cutlist_export_options', values: exportOptions });

                fnCopyToClipboard(true);
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

    }

    // Estimate /////

    LadbTabCutlist.prototype.estimateAllParts = function () {
        let partIdsWithContext = this.grabVisiblePartIdsWithContext(null);
        this.estimateParts(partIdsWithContext.partIds, partIdsWithContext.context);
    }

    LadbTabCutlist.prototype.estimateGroupParts = function (groupId, forceDefaultTab) {
        let partIdsWithContext = this.grabVisiblePartIdsWithContext(groupId);
        this.estimateParts(partIdsWithContext.partIds, partIdsWithContext.context, forceDefaultTab);
    }

    LadbTabCutlist.prototype.estimateParts = function (partIds, context, forceDefaultTab) {
        const that = this;

        const section = context && context.targetGroup ? context.targetGroup.id : null;

        // Retrieve estimate options
        rubyCallCommand('core_get_model_preset', { dictionary: 'cutlist_estimate_options', section: section }, function (response) {

            const estimateOptions = response.preset;

            const $modal = that.appendModalInside('ladb_cutlist_modal_estimate', 'tabs/cutlist/_modal-estimate.twig', {
                group: context ? context.targetGroup : null,
                isGroupSelection: context ? context.isGroupSelection : false,
                isPartSelection: context ? context.isPartSelection : false,
                tab: forceDefaultTab || that.lastEstimateOptionsTab == null ? 'general' : that.lastEstimateOptionsTab,
            });

            // Fetch UI elements
            const $tabs = $('a[data-toggle="tab"]', $modal);
            const $widgetPreset = $('.ladb-widget-preset', $modal);
            const $btnGenerate = $('#ladb_cutlist_estimate_btn_generate', $modal);

            const fnFetchOptions = function (options) {
            }
            const fnFillInputs = function (options) {
            }

            $widgetPreset.ladbWidgetPreset({
                dialog: that.dialog,
                dictionary: 'cutlist_estimate_options',
                fnFetchOptions: fnFetchOptions,
                fnFillInputs: fnFillInputs
            });

            fnFillInputs(estimateOptions);

            // Bind tabs
            $tabs.on('shown.bs.tab', function (e) {
                that.lastEstimateOptionsTab = $(e.target).attr('href').substring('#tab_estimate_options_'.length);
            });

            // Bind buttons
            $btnGenerate.on('click', function () {

                // Fetch options
                fnFetchOptions(estimateOptions);

                // Store options
                rubyCallCommand('core_set_model_preset', { dictionary: 'cutlist_estimate_options', section: section, values: estimateOptions });

                // Generate estimate
                that.generateEstimate(partIds, context, estimateOptions);

                // Hide modal
                $modal.modal('hide');

            });

            // Show modal
            $modal.modal('show');

            // Setup popovers
            that.dialog.setupPopovers();

        });

    };

    LadbTabCutlist.prototype.generateEstimate = function (partIds, context, estimateOptions, callback) {
        const that = this;

        window.requestAnimationFrame(function () {
            rubyCallCommand('cutlist_estimate_start', $.extend({
                part_ids: partIds
            }, estimateOptions), function (response) {

                const steps = response.steps

                that.dialog.startProgress(steps,
                    function () {
                        rubyCallCommand('cutlist_estimate_cancel');
                    },
                    function () {
                        rubyCallCommand('cutlist_estimate_next');
                    }
                );

                const fnCreateSlide = function (response) {

                    let $slide = that.pushNewSlide('ladb_cutlist_slide_estimate', 'tabs/cutlist/_slide-estimate.twig', {
                        capabilities: that.dialog.capabilities,
                        generateOptions: that.generateOptions,
                        estimateOptions: estimateOptions,
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
                        isGroupSelection: context ? context.isGroupSelection : false,
                        isPartSelection: context ? context.isPartSelection : false,
                        estimate: response
                    }, function () {
                        that.dialog.setupTooltips();
                    });

                    // Fetch UI elements
                    const $btnEstimate = $('#ladb_btn_estimate', $slide);
                    const $btnPrint = $('#ladb_btn_print', $slide);
                    const $btnClose = $('#ladb_btn_close', $slide);

                    // Bind buttons
                    $btnEstimate.on('click', function () {
                        that.estimateParts(partIds, context, false);
                    });
                    $btnPrint.on('click', function () {
                        this.blur();
                        that.print(that.cutlistTitle + ' - ' + i18next.t('tab.cutlist.estimate.title'));
                    });
                    $btnClose.on('click', function () {
                        that.popSlide();
                    });
                    $('.ladb-btn-setup-model-units', $slide).on('click', function() {
                        $(this).blur();
                        that.dialog.executeCommandOnTab('settings', 'highlight_panel', { panel:'model' });
                    });
                    $('.ladb-btn-toggle-no-print', $slide).on('click', function () {
                        const $group = $(this).parents('.ladb-cutlist-group');
                        if ($group.hasClass('no-print')) {
                            that.showGroup($group, false, false, estimateOptions, 'cutlist_estimate_options');
                        } else {
                            that.hideGroup($group, false, false, estimateOptions, 'cutlist_estimate_options');
                        }
                        $(this).blur();
                    });
                    $('a.ladb-btn-folding-toggle-row', $slide).on('click', function () {
                        $(this).blur();
                        const $row = $(this).parents('.ladb-cutlist-row-folder');
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
                        const $group = $(this).parents('.ladb-cutlist-group');
                        const groupId = $group.data('group-id');
                        that.hideAllGroups(groupId, $slide, false, estimateOptions, 'cutlist_estimate_options');
                        that.scrollSlideToTarget($slide, $group, true, false);
                    });
                    $('a.ladb-item-show-all-groups', $slide).on('click', function () {
                        $(this).blur();
                        that.showAllGroups($slide, false, estimateOptions, 'cutlist_estimate_options');
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

                        // Flag to ignore the next material change event
                        that.ignoreNextMaterialEvents = true;

                        const materialId = $(this).data('material-id');
                        const propertiesTab = $(this).data('properties-tab');
                        that.dialog.executeCommandOnTab('materials', 'edit_material', {
                            materialId: materialId,
                            propertiesTab: propertiesTab,
                            updatedCallback: function () {

                                // Flag to stop ignoring the next material change event
                                that.ignoreNextMaterialEvents = false;

                                // Refresh the list
                                that.dialog.executeCommandOnTab('cutlist', 'generate_cutlist', {
                                    callback: function () {
                                        that.generateEstimate(partIds, context, estimateOptions);
                                    }
                                });

                            }
                        });
                        return false;
                    });
                    $('a.ladb-btn-packing', $slide).on('click', function () {
                        $(this).blur();
                        const groupId = $(this).data('group-id');
                        that.packingGroup(groupId, true, function () {
                            that.generateEstimate(partIds, context, estimateOptions);
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
                        const partId = $(this).data('part-id');
                        that.highlightPart(partId);
                        return false;
                    });
                    $('a.ladb-btn-edit-part', $slide).on('click', function () {
                        $(this).blur();
                        const partId = $(this).data('part-id');
                        that.editPart(partId, undefined, 'extra', function () {

                            // Refresh the list
                            that.dialog.executeCommandOnTab('cutlist', 'generate_cutlist', {
                                callback: function () {
                                    that.generateEstimate(partIds, context, estimateOptions);
                                }
                            });

                        });
                        return false;
                    });
                    $('.progress-bar', $slide).on('click', function () {
                        $(this).blur();
                        const groupId = $(this).data('group-id');
                        const $group = $('.ladb-cutlist-group[data-group-id="' + groupId + '"]', $slide);
                        that.scrollSlideToTarget($slide, $group, true, true);
                    });

                    // Finish progress feedback
                    that.dialog.finishProgress();

                }

                if (response.running) {
                    let waitingForResponse = false;
                    const intervalId = setInterval(function () {

                        if (waitingForResponse) {
                            return;
                        }

                        rubyCallCommand('cutlist_estimate_advance', null, function (response) {

                            waitingForResponse = false;

                            if (response.running) {

                                // Set progress feedback
                                that.dialog.changeLabelProgress(response.run_name);
                                that.dialog.setProgress(response.run_index + response.run_progress);

                                if (response.solution) {
                                    if (response.solution === 'none') {
                                        that.dialog.previewProgress('');
                                    } else {
                                        that.dialog.previewProgress(Twig.twig({ref: "tabs/cutlist/_progress-preview-packing.twig"}).render({
                                            solution: response.solution
                                        }));
                                        if (response.run_index === steps - 1) {
                                            that.dialog.changeNextBtnLabelProgress(i18next.t('default.stop'), 'stop');
                                        }
                                    }
                                }

                            } else if (response.cancelled) {

                                clearInterval(intervalId);

                                // Finish progress feedback
                                that.dialog.finishProgress();

                            } else {

                                clearInterval(intervalId);

                                fnCreateSlide(response);

                            }

                        });
                        waitingForResponse = true;

                    }, 100);
                } else if (response.cancelled) {

                    // Finish progress feedback
                    that.dialog.finishProgress();

                } else {
                    fnCreateSlide(response);
                }

            });
        });

    }

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
        const groupAndPart = this.findGroupAndPartById(partId);
        if (groupAndPart) {

            const group = groupAndPart.group;
            const part = groupAndPart.part;

            const isFolder = part.children && part.children.length > 0;
            const isSelected = this.selectionGroupId === group.id && this.selectionPartIds.includes(partId) && this.selectionPartIds.length > 1;

            let partIds;
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
        const that = this;

        const groupId = context && context.targetGroup ? context.targetGroup.id : null;

        rubyCallCommand('cutlist_highlight_parts', { tab_name_to_show_on_quit: this.generateOptions.minimize_on_highlight ? 'cutlist' : null, part_ids: partIds }, function (response) {

            if (response.errors) {
                that.dialog.notifyErrors(response.errors);
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
        const that = this;

        const section = context && context.targetGroup ? context.targetGroup.id : null;

        // Retrieve layout options
        rubyCallCommand('core_get_model_preset', { dictionary: 'cutlist_layout_options', section: section }, function (response) {

            const layoutOptions = response.preset;

            const $modal = that.appendModalInside('ladb_cutlist_modal_layout', 'tabs/cutlist/_modal-layout.twig', {
                group: context.targetGroup,
                isGroupSelection: context ? context.isGroupSelection : false,
                isPartSelection: context ? context.isPartSelection : false,
                tab: forceDefaultTab || that.lastLayoutOptionsTab == null ? 'layout' : that.lastLayoutOptionsTab,
                THREE_CAMERA_VIEWS: THREE_CAMERA_VIEWS
            });

            // Fetch UI elements
            const $tabs = $('a[data-toggle="tab"]', $modal);
            const $widgetPreset = $('.ladb-widget-preset', $modal);
            const $selectPageFormat = $('#ladb_select_page_format', $modal);
            const $inputPageWidth = $('#ladb_input_page_width', $modal);
            const $inputPageHeight = $('#ladb_input_page_height', $modal);
            const $selectPageHeader = $('#ladb_select_page_header', $modal);
            const $selectPartsColored = $('#ladb_select_parts_colored', $modal);
            const $selectPartsOpacity = $('#ladb_select_parts_opacity', $modal);
            const $selectPinsHidden = $('#ladb_select_pins_hidden', $modal);
            const $selectPinsColored = $('#ladb_select_pins_colored', $modal);
            const $textareaPinsFormula = $('#ladb_textarea_pins_formula', $modal);
            const $selectPinsLength = $('#ladb_select_pins_length', $modal);
            const $selectPinsDirection = $('#ladb_select_pins_direction', $modal);
            const $selectCameraView = $('#ladb_select_camera_view', $modal);
            const $selectCameraZoom = $('#ladb_select_camera_zoom', $modal);
            const $selectCameraTarget = $('#ladb_select_camera_target', $modal);
            const $inputCameraView = $('#ladb_input_camera_view', $modal);
            const $inputCameraZoom = $('#ladb_input_camera_zoom', $modal);
            const $inputCameraTarget = $('#ladb_input_camera_target', $modal);
            const $inputExplodeFactor = $('#ladb_input_explode_factor', $modal);
            const $formGroupPins = $('.ladb-cutlist-layout-form-group-pins', $modal);
            const $formGroupPinsDirection = $('.ladb-cutlist-layout-form-group-pins-direction', $modal);
            const $btnGenerate = $('#ladb_cutlist_layout_btn_generate', $modal);

            const fnUpdatePageSizeFieldsAvailability = function () {
                if ($selectPageFormat.selectpicker('val') == null) {
                    $selectPageFormat.selectpicker('val', '0');
                    $inputPageWidth.ladbTextinputDimension('enable');
                    $inputPageHeight.ladbTextinputDimension('enable');
                } else {
                    $inputPageWidth.ladbTextinputDimension('disable');
                    $inputPageHeight.ladbTextinputDimension('disable');
                }
            }
            const fnUpdateFieldsVisibility = function () {
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
            const fnConvertPageSettings = function(pageWidth, pageHeight, callback) {
                rubyCallCommand('core_length_to_float', {
                    page_width: pageWidth,
                    page_height: pageHeight
                }, function (response) {
                    callback(response.page_width, response.page_height);
                });
            }
            const fnConvertToVariableDefs = function (vars) {

                // Generate variableDefs for formula editor
                const variableDefs = [];
                for (let i = 0; i < vars.length; i++) {
                    variableDefs.push({
                        text: vars[i].name,
                        displayText: i18next.t('tab.cutlist.export.' + vars[i].name),
                        type: vars[i].type
                    });
                }

                return variableDefs;
            }
            const fnFetchOptions = function (options) {
                options.page_width = $inputPageWidth.val();
                options.page_height = $inputPageHeight.val();
                options.page_header = $selectPageHeader.val() === '1';
                options.parts_colored = $selectPartsColored.val() === '1';
                options.parts_opacity = parseFloat($selectPartsOpacity.val());
                options.pins_hidden = $selectPinsHidden.val() === '1';
                options.pins_colored = $selectPinsColored.val() === '1';
                options.pins_formula = $textareaPinsFormula.val();
                options.pins_length = that.toInt($selectPinsLength.val());
                options.pins_direction = that.toInt($selectPinsDirection.val());
                options.camera_view = JSON.parse($inputCameraView.val());
                options.camera_zoom = JSON.parse($inputCameraZoom.val());
                options.camera_target = JSON.parse($inputCameraTarget.val());
                options.explode_factor = $inputExplodeFactor.slider('getValue');
            }
            const fnFillInputs = function (options) {
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
                    { name: 'material', type: 'material' },
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
                    { name: 'layer', type: 'string' },
                    { name: 'component_definition', type: 'component_definition' },
                    { name: 'component_instance', type: 'component_instance' }
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
                const format = $(this).val();
                if (format !== '0') {
                    $inputPageWidth.ladbTextinputDimension('disable');
                    $inputPageHeight.ladbTextinputDimension('disable');
                    const dimensions = format.split('x');
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

                            const controlsData = {
                                zoom: layoutOptions.camera_zoom,
                                target: layoutOptions.camera_target,
                                exploded_model_radius: 1
                            }

                            const $slide = that.pushNewSlide('ladb_cutlist_slide_layout', 'tabs/cutlist/_slide-layout.twig', {
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
                            const $btnLayout = $('#ladb_btn_layout', $slide);
                            const $btnPrint = $('#ladb_btn_print', $slide);
                            const $btnExport = $('#ladb_btn_export', $slide);
                            const $btnClose = $('#ladb_btn_close', $slide);
                            const $viewer = $('.ladb-three-viewer', $slide);
                            const $lblScale = $('.ladb-lbl-scale', $slide);

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

                                        rubyCallCommand('cutlist_layout_to_layout', {
                                            parts_infos: data.parts_infos,
                                            pins_infos: data.pins_infos,
                                            target_group_id: context && context.targetGroup ? context.targetGroup.id : null,
                                            generated_at: Twig.twig({ data: "{{ generatedAt|date(('default.date_format'|i18next)) }}" }).render({ generatedAt: new Date().getTime() / 1000 }),
                                            page_width: layoutOptions.page_width,
                                            page_height: layoutOptions.page_height,
                                            page_header: layoutOptions.page_header,
                                            parts_colored: layoutOptions.parts_colored,
                                            parts_opacity: layoutOptions.parts_opacity,
                                            pins_hidden: layoutOptions.pins_hidden,
                                            camera_view: layoutOptions.camera_view,
                                            camera_zoom: controlsData.camera_zoom,
                                            camera_target: controlsData.camera_target,
                                            exploded_model_radius: controlsData.exploded_model_radius
                                        }, function (response) {

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
                            let storeOptionsTimeoutId = null;
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

                                let scale;
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

                            const $paperPage = $('.ladb-paper-page', $viewer)
                            if ($paperPage.length > 0 && pageWidth && pageHeight) {

                                $paperPage.outerWidth(pageWidth + 'in');
                                $paperPage.outerHeight(pageHeight + 'in');
                                $paperPage.css('padding', '0.25in');

                                // Scale frame to fit viewer on window resize
                                const fnScaleFrame = function (e) {

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

                                    const spaceIW = $viewer.innerWidth();
                                    const spaceIH = $viewer.innerHeight();
                                    const frameOW = $paperPage.outerWidth();
                                    const frameOH = $paperPage.outerHeight();
                                    const scale = Math.min(
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
        const groupAndPart = this.findGroupAndPartById(partId);
        if (groupAndPart) {

            const group = groupAndPart.group;
            const part = groupAndPart.part;

            const isFolder = part.children && part.children.length > 0;
            const isSelected = this.selectionGroupId === group.id && this.selectionPartIds.includes(partId) && this.selectionPartIds.length > 1;

            let partIds;
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
        const that = this;

        let partCount = 0;
        let partInstanceCount = 0;
        for (let i = 0 ; i < partIds.length; i++) {
            const groupAndPart = this.findGroupAndPartById(partIds[i]);
            if (groupAndPart) {
                if (groupAndPart.part.children) {
                    partCount += groupAndPart.part.children.length;
                } else {
                    partCount += 1;
                }
                partInstanceCount += groupAndPart.part.count;
            }
        }

        if (partCount === 0) {
            this.dialog.alert(i18next.t('tab.cutlist.write.title'), i18next.t('tab.cutlist.write.error.no_part'));
            return;
        }

        const section = context && context.targetGroup ? context.targetGroup.id : null;

        if (is2d) {

            // Retrieve write2d options
            rubyCallCommand('core_get_model_preset', { dictionary: 'cutlist_write2d_options', section: section }, function (response) {

                const write2dOptions = response.preset;

                const $modal = that.appendModalInside('ladb_cutlist_modal_write_2d', 'tabs/cutlist/_modal-write-2d.twig', {
                    group: context ? context.targetGroup : null,
                    isGroupSelection: context ? context.isGroupSelection : false,
                    isPartSelection: context ? context.isPartSelection : false,
                });

                // Fetch UI elements
                const $widgetPreset = $('.ladb-widget-preset', $modal);
                const $selectPartDrawingType = $('#ladb_select_part_drawing_type', $modal);
                const $selectFileFormat = $('#ladb_select_file_format', $modal);
                const $selectUnit = $('#ladb_select_unit', $modal);
                const $selectUseCount = $('#ladb_select_use_count', $modal);
                const $selectAnchor = $('#ladb_select_anchor', $modal);
                const $selectSmoothing = $('#ladb_select_smoothing', $modal);
                const $selectMergeHoles = $('#ladb_select_merge_holes', $modal);
                const $formGroupMergeHolesOverflow = $('#ladb_form_group_merge_holes_overflow', $modal);
                const $inputMergeHolesOverflow = $('#ladb_input_merge_holes_overflow', $modal);
                const $selectIncludePaths = $('#ladb_select_include_paths', $modal);
                const $inputPartsStrokeColor = $('#ladb_input_parts_stroke_color', $modal);
                const $inputPartsFillColor = $('#ladb_input_parts_fill_color', $modal);
                const $formGroupPartsHoles = $('#ladb_form_group_parts_holes', $modal);
                const $inputPartsHolesStrokeColor = $('#ladb_input_parts_holes_stroke_color', $modal);
                const $inputPartsHolesFillColor = $('#ladb_input_parts_holes_fill_color', $modal);
                const $inputPartsDepthsStrokeColor = $('#ladb_input_parts_depths_stroke_color', $modal);
                const $inputPartsDepthsFillColor = $('#ladb_input_parts_depths_fill_color', $modal);
                const $formGroupPartsPaths = $('#ladb_form_group_parts_paths', that.$element);
                const $inputPartsPathsStrokeColor = $('#ladb_input_parts_paths_stroke_color', that.$element);
                const $inputPartsPathsFillColor = $('#ladb_input_parts_paths_fill_color', that.$element);
                const $btnExport = $('#ladb_btn_export', $modal);

                const fnFetchOptions = function (options) {
                    options.part_drawing_type = $selectPartDrawingType.val();
                    options.file_format = $selectFileFormat.val();
                    options.unit = that.toInt($selectUnit.val());
                    options.use_count = $selectUseCount.val() === '1';
                    options.anchor = $selectAnchor.val() === '1';
                    options.smoothing = $selectSmoothing.val() === '1';
                    options.merge_holes = $selectMergeHoles.val() === '1';
                    options.merge_holes_overflow = $inputMergeHolesOverflow.val();
                    options.include_paths = $selectIncludePaths.val() === '1';
                    options.parts_stroke_color = $inputPartsStrokeColor.ladbTextinputColor('val');
                    options.parts_fill_color = $inputPartsFillColor.ladbTextinputColor('val');
                    options.parts_holes_stroke_color = $inputPartsHolesStrokeColor.ladbTextinputColor('val');
                    options.parts_holes_fill_color = $inputPartsHolesFillColor.ladbTextinputColor('val');
                    options.parts_depths_stroke_color = $inputPartsDepthsStrokeColor.ladbTextinputColor('val');
                    options.parts_depths_fill_color = $inputPartsDepthsFillColor.ladbTextinputColor('val');
                    options.parts_paths_stroke_color = $inputPartsPathsStrokeColor.ladbTextinputColor('val');
                    options.parts_paths_fill_color = $inputPartsPathsFillColor.ladbTextinputColor('val');
                };
                const fnFillInputs = function (options) {
                    $selectPartDrawingType.selectpicker('val', options.part_drawing_type);
                    $selectFileFormat.selectpicker('val', options.file_format);
                    $selectUnit.selectpicker('val', options.unit);
                    $selectUseCount.selectpicker('val', options.use_count ? '1' : '0');
                    $selectAnchor.selectpicker('val', options.anchor ? '1' : '0');
                    $selectSmoothing.selectpicker('val', options.smoothing ? '1' : '0');
                    $selectMergeHoles.selectpicker('val', options.merge_holes ? '1' : '0');
                    $inputMergeHolesOverflow.val(options.merge_holes_overflow);
                    $selectIncludePaths.selectpicker('val', options.include_paths ? '1' : '0');
                    $inputPartsStrokeColor.ladbTextinputColor('val', options.parts_stroke_color);
                    $inputPartsFillColor.ladbTextinputColor('val', options.parts_fill_color);
                    $inputPartsDepthsStrokeColor.ladbTextinputColor('val', options.parts_depths_stroke_color);
                    $inputPartsDepthsFillColor.ladbTextinputColor('val', options.parts_depths_fill_color);
                    $inputPartsHolesStrokeColor.ladbTextinputColor('val', options.parts_holes_stroke_color);
                    $inputPartsHolesFillColor.ladbTextinputColor('val', options.parts_holes_fill_color);
                    $inputPartsPathsStrokeColor.ladbTextinputColor('val', options.parts_paths_stroke_color);
                    $inputPartsPathsFillColor.ladbTextinputColor('val', options.parts_paths_fill_color);
                    fnUpdateFieldsVisibility();
                };
                const fnUpdateFieldsVisibility = function () {
                    const isDxf = $selectFileFormat.val() === 'dxf';
                    const isMergeHoles = $selectMergeHoles.val() === '1';
                    const isIncludePaths = $selectIncludePaths.val() === '1';
                    if (isMergeHoles) $formGroupMergeHolesOverflow.show(); else $formGroupMergeHolesOverflow.hide();
                    $inputPartsFillColor.ladbTextinputColor(isDxf ? 'disable' : 'enable');
                    $inputPartsDepthsFillColor.ladbTextinputColor(isDxf ? 'disable' : 'enable');
                    if (!isMergeHoles) $formGroupPartsHoles.hide(); else $formGroupPartsHoles.show();
                    $inputPartsHolesStrokeColor.ladbTextinputColor(!isMergeHoles ? 'disable' : 'enable');
                    $inputPartsHolesFillColor.ladbTextinputColor(!isMergeHoles || isDxf ? 'disable' : 'enable');
                    if (!isIncludePaths) $formGroupPartsPaths.hide(); else $formGroupPartsPaths.show();
                    $inputPartsPathsStrokeColor.ladbTextinputColor(!isIncludePaths ? 'disable' : 'enable');
                    $inputPartsPathsFillColor.ladbTextinputColor(!isIncludePaths || isDxf ? 'disable' : 'enable');
                    $('.ladb-form-fill-color').css('opacity', isDxf ? 0.3 : 1);
                };
                const fnUpdateButtonLabel = function () {
                    let fileCount = $selectUseCount.val() === '1' ? partInstanceCount : partCount;
                    $('#ladb_btn_export_file_format', $btnExport).html($selectFileFormat.val().toUpperCase() + ' <small>( ' + fileCount + ' ' + i18next.t('default.file', { count: fileCount }).toLowerCase() + ' )</small>');
                }

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
                        fnUpdateButtonLabel();
                        fnUpdateFieldsVisibility();
                    })
                ;
                $selectUnit.selectpicker(SELECT_PICKER_OPTIONS);
                $selectUseCount
                    .selectpicker(SELECT_PICKER_OPTIONS)
                    .on('changed.bs.select', fnUpdateButtonLabel)
                ;
                $selectAnchor.selectpicker(SELECT_PICKER_OPTIONS);
                $selectSmoothing.selectpicker(SELECT_PICKER_OPTIONS);
                $selectMergeHoles.selectpicker(SELECT_PICKER_OPTIONS).on('changed.bs.select', fnUpdateFieldsVisibility);
                $inputMergeHolesOverflow.ladbTextinputDimension();
                $selectIncludePaths.selectpicker(SELECT_PICKER_OPTIONS).on('changed.bs.select', fnUpdateFieldsVisibility);
                $inputPartsStrokeColor.ladbTextinputColor(TEXTINPUT_COLOR_OPTIONS);
                $inputPartsFillColor.ladbTextinputColor(TEXTINPUT_COLOR_OPTIONS);
                $inputPartsHolesStrokeColor.ladbTextinputColor(TEXTINPUT_COLOR_OPTIONS);
                $inputPartsHolesFillColor.ladbTextinputColor(TEXTINPUT_COLOR_OPTIONS);
                $inputPartsDepthsStrokeColor.ladbTextinputColor(TEXTINPUT_COLOR_OPTIONS);
                $inputPartsDepthsFillColor.ladbTextinputColor(TEXTINPUT_COLOR_OPTIONS);
                $inputPartsPathsStrokeColor.ladbTextinputColor(TEXTINPUT_COLOR_OPTIONS);
                $inputPartsPathsFillColor.ladbTextinputColor(TEXTINPUT_COLOR_OPTIONS);

                fnFillInputs(write2dOptions);

                // Bind buttons
                $btnExport.on('click', function () {

                    // Fetch options
                    fnFetchOptions(write2dOptions);

                    // Store options
                    rubyCallCommand('core_set_model_preset', { dictionary: 'cutlist_write2d_options', values: write2dOptions, section: section });

                    rubyCallCommand('cutlist_write_parts', $.extend({
                        part_ids: partIds,
                    }, write2dOptions), function (response) {

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

                const write3dOptions = response.preset;

                const $modal = that.appendModalInside('ladb_cutlist_modal_write_3d', 'tabs/cutlist/_modal-write-3d.twig', {
                    group: context ? context.targetGroup : null,
                    isGroupSelection: context ? context.isGroupSelection : false,
                    isPartSelection: context ? context.isPartSelection : false,
                });

                // Fetch UI elements
                const $widgetPreset = $('.ladb-widget-preset', $modal);
                const $selectFileFormat = $('#ladb_select_file_format', $modal);
                const $formGroupUnit = $('#ladb_form_group_unit', $modal);
                const $selectUnit = $('#ladb_select_unit', $modal);
                const $selectUseCount = $('#ladb_select_use_count', $modal);
                const $formGroupAnchor = $('#ladb_form_group_anchor', $modal);
                const $selectAnchor = $('#ladb_select_anchor', $modal);
                const $formGroupSwitchYZ = $('#ladb_form_group_switch_yz', $modal);
                const $selectSwitchYZ = $('#ladb_select_switch_yz', $modal);
                const $btnExport = $('#ladb_btn_export', $modal);

                const fnFetchOptions = function (options) {
                    options.file_format = $selectFileFormat.val();
                    options.unit = that.toInt($selectUnit.val());
                    options.use_count = $selectUseCount.val() === '1';
                    options.anchor = $selectAnchor.val() === '1';
                    options.switch_yz = $selectSwitchYZ.val() === '1';
                };
                const fnFillInputs = function (options) {
                    $selectFileFormat.selectpicker('val', options.file_format);
                    $selectUnit.selectpicker('val', options.unit);
                    $selectUseCount.selectpicker('val', options.use_count ? '1' : '0');
                    $selectAnchor.selectpicker('val', options.anchor ? '1' : '0');
                    $selectSwitchYZ.selectpicker('val', options.switch_yz ? '1' : '0');
                    fnUpdateFieldsVisibility();
                };
                const fnUpdateFieldsVisibility = function () {
                    const isSkp = $selectFileFormat.val() === 'skp';
                    if (isSkp) $formGroupUnit.hide(); else $formGroupUnit.show();
                    if (isSkp) $formGroupAnchor.hide(); else $formGroupAnchor.show();
                    if (isSkp) $formGroupSwitchYZ.hide(); else $formGroupSwitchYZ.show();
                };
                const fnUpdateButtonLabel = function () {
                    let fileCount = $selectUseCount.val() === '1' ? partInstanceCount : partCount;
                    $('#ladb_btn_export_file_format', $btnExport).html($selectFileFormat.val().toUpperCase() + ' <small>( ' + fileCount + ' ' + i18next.t('default.file', { count: fileCount }).toLowerCase() + ' )</small>');
                }

                $widgetPreset.ladbWidgetPreset({
                    dialog: that.dialog,
                    dictionary: 'cutlist_write3d_options',
                    fnFetchOptions: fnFetchOptions,
                    fnFillInputs: fnFillInputs
                });
                $selectFileFormat
                    .selectpicker(SELECT_PICKER_OPTIONS)
                    .on('changed.bs.select', function () {
                        fnUpdateButtonLabel();
                        fnUpdateFieldsVisibility();
                    })
                ;
                $selectUnit.selectpicker(SELECT_PICKER_OPTIONS);
                $selectUseCount
                    .selectpicker(SELECT_PICKER_OPTIONS)
                    .on('changed.bs.select', fnUpdateButtonLabel)
                ;
                $selectAnchor.selectpicker(SELECT_PICKER_OPTIONS);
                $selectSwitchYZ.selectpicker(SELECT_PICKER_OPTIONS);

                fnFillInputs(write3dOptions);

                // Bind buttons
                $btnExport.on('click', function () {

                    // Fetch options
                    fnFetchOptions(write3dOptions);

                    // Store options
                    rubyCallCommand('core_set_model_preset', { dictionary: 'cutlist_write3d_options', values: write3dOptions, section: section });

                    rubyCallCommand('cutlist_write_parts', $.extend({
                        part_ids: partIds,
                        part_drawing_type: 7 // PART_DRAWING_TYPE_3D
                    }, write3dOptions), function (response) {

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

    // Packing /////

    LadbTabCutlist.prototype.packingGroup = function (groupId, forceDefaultTab, generateCallback) {
        const that = this;

        let partIdsWithContext = this.grabVisiblePartIdsWithContext(groupId);
        const partIds = partIdsWithContext.partIds;
        const context = partIdsWithContext.context;

        const group = context.targetGroup

        const section = groupId;

        // Retrieve packing options
        rubyCallCommand('core_get_model_preset', { dictionary: 'cutlist_packing_options', section: section }, function (response) {

            const packingOptions = response.preset;

            rubyCallCommand('materials_get_attributes_command', { name: group.material_name }, function (response) {

                const $modal = that.appendModalInside('ladb_cutlist_modal_packing', 'tabs/cutlist/_modal-packing.twig', {
                    material_attributes: response,
                    group: group,
                    isPartSelection: context ? context.isPartSelection : false,
                    tab: forceDefaultTab || that.lastPackingOptionsTab == null ? 'material' : that.lastPackingOptionsTab
                });

                // Fetch UI elements
                const $tabs = $('a[data-toggle="tab"]', $modal);
                const $widgetPreset = $('.ladb-widget-preset', $modal);
                const $editorStdBinSizes = $('#ladb_editor_std_bin_sizes', $modal);
                const $editorScrapBinSizes = $('#ladb_editor_scrap_bin_sizes', $modal);
                const $btnsProblemType = $('label.btn-radio', $modal);
                const $radiosProblemType = $('input[name=ladb_radios_problem_type]', $modal);
                const $formGroupRectangleguillotine = $('.ladb-cutlist-packing-form-group-rectangleguillotine', $modal)
                const $selectRectangleguillotineFirstStageOrientation = $('#ladb_select_rectangleguillotine_first_stage_orientation', $modal);
                const $selectRectangleguillotineCutType = $('#ladb_select_rectangleguillotine_cut_type', $modal);
                const $selectRectangleguillotineNumberOfStages = $('#ladb_select_rectangleguillotine_number_of_stages', $modal);
                const $inputRectangleguillotineKeepSize = $('#ladb_input_rectangleguillotine_keep_size', $modal);
                const $formGroupIrregular = $('.ladb-cutlist-packing-form-group-irregular', $modal)
                const $formGroupNotIrregular = $('.ladb-cutlist-packing-form-group-not-irregular', $modal)
                const $formGroupDebug = $('.ladb-cutlist-packing-form-group-debug', $modal)
                const $btnExpert = $('.ladb-cutlist-packing-btn-expert', $modal)
                const $selectIrregularAllowedRotations = $('#ladb_select_irregular_allowed_rotations', $modal);
                const $selectIrregularAllowMirroring = $('#ladb_select_irregular_allow_mirroring', $modal);
                const $inputSpacing = $('#ladb_input_spacing', $modal);
                const $inputTrimming = $('#ladb_input_trimming', $modal);
                const $textareaItemsFormula = $('#ladb_textarea_items_formula', $modal);
                const $selectOriginCorner = $('#ladb_select_origin_corner', $modal);
                const $selectBinFolding = $('#ladb_select_bin_folding', $modal);
                const $selectHidePartList = $('#ladb_select_hide_part_list', $modal);
                const $selectPartDrawingType = $('#ladb_select_part_drawing_type', $modal);
                const $selectColorization = $('#ladb_select_colorization', $modal);
                const $selectHighlightPrimaryCuts = $('#ladb_select_highlight_primary_cuts', $modal);
                const $selectHideEdgesPreview = $('#ladb_select_hide_edges_preview', $modal);
                const $selectObjective = $('#ladb_select_objective', $modal);
                const $selectOptimizationMode = $('#ladb_select_optimization_mode', $modal);
                const $inputTimeLimit = $('#ladb_input_time_limit', $modal);
                const $inputNotAnytimeTreeSearchQueueSize = $('#ladb_input_not_anytime_tree_search_queue_size', $modal);
                const $selectVerbosityLevel = $('#ladb_select_verbosity_level', $modal);
                const $selectInputToJsonBinDir = $('#ladb_select_input_to_json_bin_dir', $modal);
                const $btnEditMaterial = $('#ladb_btn_edit_material', $modal);
                const $btnUnloadLib = $('#ladb_btn_unload_lib', $modal);
                const $btnGenerate = $('#ladb_btn_generate', $modal);

                const fnFetchOptions = function (options) {
                    if (group.material_is_1d) {
                        options.std_bin_1d_sizes = $editorStdBinSizes.ladbEditorSizes('getSizes');
                        options.std_bin_2d_sizes = '';
                        options.scrap_bin_1d_sizes = $editorScrapBinSizes.ladbEditorSizes('getSizes');
                        options.scrap_bin_2d_sizes = '';
                    }
                    if (group.material_is_2d) {
                        options.std_bin_1d_sizes = ''
                        options.std_bin_2d_sizes = $editorStdBinSizes.ladbEditorSizes('getSizes');
                        options.scrap_bin_1d_sizes = '';
                        options.scrap_bin_2d_sizes = $editorScrapBinSizes.ladbEditorSizes('getSizes');
                    }

                    options.problem_type = $radiosProblemType.filter(':checked').val();
                    options.optimization_mode = $selectOptimizationMode.val();
                    options.objective = $selectObjective.val();
                    options.rectangleguillotine_first_stage_orientation = $selectRectangleguillotineFirstStageOrientation.val();
                    options.rectangleguillotine_cut_type = $selectRectangleguillotineCutType.val();
                    options.rectangleguillotine_number_of_stages = that.toInt($selectRectangleguillotineNumberOfStages.val());
                    options.rectangleguillotine_keep_size = $inputRectangleguillotineKeepSize.val();
                    options.irregular_allowed_rotations = $selectIrregularAllowedRotations.val();
                    options.irregular_allow_mirroring = $selectIrregularAllowMirroring.val() === '1';
                    options.spacing = $inputSpacing.val();
                    options.trimming = $inputTrimming.val();
                    options.items_formula = $textareaItemsFormula.val();
                    options.origin_corner = that.toInt($selectOriginCorner.val());
                    options.bin_folding = $selectBinFolding.val() === '1';
                    options.hide_part_list = $selectHidePartList.val() === '1';
                    options.part_drawing_type = that.toInt($selectPartDrawingType.val());
                    options.colorization = that.toInt($selectColorization.val());
                    options.highlight_primary_cuts = $selectHighlightPrimaryCuts.val() === '1';
                    options.hide_edges_preview = $selectHideEdgesPreview.val() === '1';
                    options.time_limit = that.toInt($inputTimeLimit.val());
                    options.not_anytime_tree_search_queue_size = that.toInt($inputNotAnytimeTreeSearchQueueSize.val());
                    options.verbosity_level = that.toInt($selectVerbosityLevel.val());
                    options.input_to_json_bin_dir = $selectInputToJsonBinDir.val();
                }
                const fnFillInputs = function (options) {
                    $radiosProblemType.filter('[value=' + fnValidProblemType(options.problem_type) + ']').click();
                    $selectOptimizationMode.selectpicker('val', options.optimization_mode);
                    $selectObjective.selectpicker('val', options.objective);
                    $selectRectangleguillotineFirstStageOrientation.selectpicker('val', options.rectangleguillotine_first_stage_orientation);
                    $selectRectangleguillotineCutType.selectpicker('val', options.rectangleguillotine_cut_type);
                    $selectRectangleguillotineNumberOfStages.selectpicker('val', options.rectangleguillotine_number_of_stages);
                    $inputRectangleguillotineKeepSize.ladbTextinputSize('val', options.rectangleguillotine_keep_size);
                    $selectIrregularAllowedRotations.selectpicker('val', fnValidIrregularAllowedRotations(options.irregular_allowed_rotations));
                    $selectIrregularAllowMirroring.selectpicker('val', options.irregular_allow_mirroring ? '1' : '0');
                    $inputSpacing.val(options.spacing);
                    $inputTrimming.val(options.trimming);
                    $textareaItemsFormula.ladbTextinputCode('val', [ typeof options.items_formula == 'string' ? options.items_formula : '' ]);
                    $selectOriginCorner.selectpicker('val', options.origin_corner);
                    $selectBinFolding.selectpicker('val', options.bin_folding ? '1' : '0');
                    $selectHidePartList.selectpicker('val', options.hide_part_list ? '1' : '0');
                    $selectPartDrawingType.selectpicker('val', options.part_drawing_type);
                    $selectColorization.selectpicker('val', options.colorization);
                    $selectHighlightPrimaryCuts.selectpicker('val', options.highlight_primary_cuts ? '1' : '0');
                    $selectHideEdgesPreview.selectpicker('val', options.hide_edges_preview ? '1' : '0');
                    $inputTimeLimit.val(options.time_limit);
                    $inputNotAnytimeTreeSearchQueueSize.val(options.not_anytime_tree_search_queue_size);
                    $selectVerbosityLevel.selectpicker('val', options.verbosity_level);
                    $selectInputToJsonBinDir.selectpicker('val', options.input_to_json_bin_dir);
                    fnUpdateFieldsVisibility();
                }
                const fnConvertToVariableDefs = function (vars) {

                    // Generate variableDefs for formula editor
                    const variableDefs = [];
                    for (let i = 0; i < vars.length; i++) {
                        variableDefs.push({
                            text: vars[i].name,
                            displayText: i18next.t('tab.cutlist.export.' + vars[i].name),
                            type: vars[i].type
                        });
                    }

                    return variableDefs;
                }
                const fnUpdateFieldsVisibility = function () {
                    const isRectangleguillotine = $radiosProblemType.filter(':checked').val() === 'rectangleguillotine';
                    const isIrregular = $radiosProblemType.filter(':checked').val() === 'irregular';
                    const isDebug = that.dialog.capabilities.is_dev && !that.dialog.capabilities.is_rbz;
                    if (isIrregular) $formGroupNotIrregular.hide(); else $formGroupNotIrregular.show();
                    if (isRectangleguillotine) $formGroupRectangleguillotine.show(); else $formGroupRectangleguillotine.hide();
                    if (isIrregular) $formGroupIrregular.show(); else $formGroupIrregular.hide();
                    if (isDebug) $formGroupDebug.show(); else $formGroupDebug.hide();
                    $('option[value=0]', $selectPartDrawingType).prop('disabled', isIrregular);
                    if ($selectPartDrawingType.val() === null) $selectPartDrawingType.selectpicker('val', 1);   // PART_DRAWING_TYPE_2D_TOP
                    $selectPartDrawingType.selectpicker('refresh');
                    $('.ladb-cutting-increase-help > small', $modal).css('text-decoration', isIrregular ? 'line-through' : 'none')
                    $('.ladb-cutting-increase-help > i', $modal).css('display', isIrregular ? 'inline' : 'none')
                    $('.nav li .ladb-cutting-increase-warning', $modal).css('display', isIrregular && (response.length_increase !== "0" || response.width_increase !== "0") ? 'inline' : 'none')
                };
                const fnValidProblemType = function (problemType) {
                    if (group.material_is_1d
                        && (problemType === 'rectangleguillotine' || problemType === 'rectangle')) {
                        return 'onedimensional';
                    }
                    return problemType;
                }
                const fnValidIrregularAllowedRotations = function (irregularAllowedRotations) {
                    if ((group.material_grained || group.material_is_1d)
                        && (irregularAllowedRotations === '90' || irregularAllowedRotations === '45')) {
                        return '180';
                    }
                    return irregularAllowedRotations;
                }
                const fnEditMaterial = function (options) {

                    // Hide modal
                    $modal.modal('hide');

                    // Edit material
                    that.dialog.executeCommandOnTab('materials', 'edit_material', $.extend({
                        materialId: group.material_id,
                        propertiesTab: 'formats'
                    }, options));

                };
                const fnGenerate = function (noCache = false) {

                    if (typeof generateCallback === 'function') {

                        // Hide modal
                        $modal.modal('hide');

                        generateCallback();

                    } else {

                        const fnCreateSlide = function (response) {

                            const solution = response.solution;

                            let dimensionColumnOrderStrategy = that.generateOptions.dimension_column_order_strategy.split('>').filter((p) => p !== 'thickness');
                            if (group.material_is_1d) dimensionColumnOrderStrategy = dimensionColumnOrderStrategy.filter((p) => p !== 'width');

                            let $slide = that.pushNewSlide('ladb_cutlist_slide_packing', 'tabs/cutlist/_slide-packing.twig', $.extend({
                                capabilities: that.dialog.capabilities,
                                generateOptions: that.generateOptions,
                                packingOptions: packingOptions,
                                dimensionColumnOrderStrategy: dimensionColumnOrderStrategy,
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
                            const $btnPacking = $('#ladb_btn_packing', $slide);
                            const $btnPrint = $('#ladb_btn_print', $slide);
                            const $btnExport = $('#ladb_btn_export', $slide);
                            const $btnLabels = $('#ladb_btn_labels', $slide);
                            const $btnClose = $('#ladb_btn_close', $slide);
                            const $btnGenerateNoCache = $('#ladb_btn_generate_no_cache', $slide);

                            // Bind buttons
                            $btnPacking.on('click', function () {
                                that.packingGroup(groupId);
                            });
                            $btnPrint.on('click', function () {
                                $(this).blur();
                                that.print(that.cutlistTitle + ' - ' + i18next.t('tab.cutlist.packing.title'));
                            });
                            $btnExport.on('click', function () {
                                $(this).blur();

                                // Count hidden groups
                                const hiddenBinIndices = [];
                                $('.ladb-cutlist-packing-group', $slide).each(function () {
                                    if ($(this).hasClass('no-print')) {
                                        hiddenBinIndices.push($(this).data('bin-index'));
                                    }
                                });
                                const isBinSelection = hiddenBinIndices.length > 0

                                // Retrieve packing options
                                rubyCallCommand('core_get_model_preset', {
                                    dictionary: 'cutlist_packing_write_options',
                                    section: groupId
                                }, function (response) {

                                    const writeOptions = response.preset;

                                    const $modal = that.appendModalInside('ladb_cutlist_modal_packing_export', 'tabs/cutlist/_modal-packing-write.twig', {
                                        group: group,
                                        isBinSelection: isBinSelection,
                                    });

                                    // Fetch UI elements
                                    const $widgetPreset = $('.ladb-widget-preset', $modal);
                                    const $selectFileFormat = $('#ladb_select_file_format', $modal);
                                    const $formGroupDxfStructure = $('#ladb_form_group_dxf_structure', $modal);
                                    const $selectDxfStructure = $('#ladb_select_dxf_structure', $modal);
                                    const $selectUnit = $('#ladb_select_unit', $modal);
                                    const $selectSmoothing = $('#ladb_select_smoothing', $modal);
                                    const $selectMergeHoles = $('#ladb_select_merge_holes', $modal);
                                    const $formGroupMergeHolesOverflow = $('#ladb_form_group_merge_holes_overflow', $modal);
                                    const $inputMergeHolesOverflow = $('#ladb_input_merge_holes_overflow', $modal);
                                    const $selectIncludePaths = $('#ladb_select_include_paths', $modal);
                                    const $inputBinHidden = $('#ladb_input_bin_hidden', $modal);
                                    const $inputBinStrokeColor = $('#ladb_input_bin_stroke_color', $modal);
                                    const $inputBinFillColor = $('#ladb_input_bin_fill_color', $modal);
                                    const $inputPartsHidden = $('#ladb_input_parts_hidden', $modal);
                                    const $inputPartsStrokeColor = $('#ladb_input_parts_stroke_color', $modal);
                                    const $inputPartsFillColor = $('#ladb_input_parts_fill_color', $modal);
                                    const $formGroupPartsDepths = $('#ladb_form_group_parts_depths', $modal);
                                    const $inputPartsDepthsStrokeColor = $('#ladb_input_parts_depths_stroke_color', $modal);
                                    const $inputPartsDepthsFillColor = $('#ladb_input_parts_depths_fill_color', $modal);
                                    const $formGroupPartsHoles = $('#ladb_form_group_parts_holes', $modal);
                                    const $inputPartsHolesStrokeColor = $('#ladb_input_parts_holes_stroke_color', $modal);
                                    const $inputPartsHolesFillColor = $('#ladb_input_parts_holes_fill_color', $modal);
                                    const $formGroupPartsPaths = $('#ladb_form_group_parts_paths', $modal);
                                    const $inputPartsPathsStrokeColor = $('#ladb_input_parts_paths_stroke_color', $modal);
                                    const $inputPartsPathsFillColor = $('#ladb_input_parts_paths_fill_color', $modal);
                                    const $formGroupTexts = $('#ladb_form_group_texts', $modal);
                                    const $inputTextsHidden = $('#ladb_input_texts_hidden', $modal);
                                    const $inputTextsColor = $('#ladb_input_texts_color', $modal);
                                    const $inputLeftoversHidden = $('#ladb_input_leftovers_hidden', $modal);
                                    const $inputLeftoversStrokeColor = $('#ladb_input_leftovers_stroke_color', $modal);
                                    const $inputLeftoversFillColor = $('#ladb_input_leftovers_fill_color', $modal);
                                    const $inputCutsHidden = $('#ladb_input_cuts_hidden', $modal);
                                    const $inputCutsColor = $('#ladb_input_cuts_color', $modal);
                                    const $btnExport = $('#ladb_btn_export', $modal);

                                    const fnFetchOptions = function (options) {
                                        options.file_format = $selectFileFormat.val();
                                        options.dxf_structure = that.toInt($selectDxfStructure.val());
                                        options.unit = that.toInt($selectUnit.val());
                                        options.smoothing = $selectSmoothing.val() === '1';
                                        options.merge_holes = $selectMergeHoles.val() === '1';
                                        options.merge_holes_overflow = $inputMergeHolesOverflow.val();
                                        options.include_paths = $selectIncludePaths.val() === '1';
                                        options.bin_hidden = !$inputBinHidden.is(':checked');
                                        options.bin_stroke_color = $inputBinStrokeColor.ladbTextinputColor('val');
                                        options.bin_fill_color = $inputBinFillColor.ladbTextinputColor('val');
                                        options.parts_hidden = !$inputPartsHidden.is(':checked');
                                        options.parts_stroke_color = $inputPartsStrokeColor.ladbTextinputColor('val');
                                        options.parts_fill_color = $inputPartsFillColor.ladbTextinputColor('val');
                                        options.parts_depths_stroke_color = $inputPartsDepthsStrokeColor.ladbTextinputColor('val');
                                        options.parts_depths_fill_color = $inputPartsDepthsFillColor.ladbTextinputColor('val');
                                        options.parts_holes_stroke_color = $inputPartsHolesStrokeColor.ladbTextinputColor('val');
                                        options.parts_holes_fill_color = $inputPartsHolesFillColor.ladbTextinputColor('val');
                                        options.parts_paths_stroke_color = $inputPartsPathsStrokeColor.ladbTextinputColor('val');
                                        options.parts_paths_fill_color = $inputPartsPathsFillColor.ladbTextinputColor('val');
                                        options.texts_hidden = !$inputTextsHidden.is(':checked');
                                        options.texts_color = $inputTextsColor.ladbTextinputColor('val');
                                        options.leftovers_hidden = !$inputLeftoversHidden.is(':checked');
                                        options.leftovers_stroke_color = $inputLeftoversStrokeColor.ladbTextinputColor('val');
                                        options.leftovers_fill_color = $inputLeftoversFillColor.ladbTextinputColor('val');
                                        options.cuts_hidden = !$inputCutsHidden.is(':checked');
                                        options.cuts_color = $inputCutsColor.ladbTextinputColor('val');
                                    };
                                    const fnFillInputs = function (options) {
                                        $selectFileFormat.selectpicker('val', options.file_format);
                                        $selectDxfStructure.selectpicker('val', options.dxf_structure);
                                        $selectUnit.selectpicker('val', options.unit);
                                        $selectSmoothing.selectpicker('val', options.smoothing ? '1' : '0');
                                        $selectMergeHoles.selectpicker('val', options.merge_holes ? '1' : '0');
                                        $inputMergeHolesOverflow.val(options.merge_holes_overflow);
                                        $selectIncludePaths.selectpicker('val', options.include_paths ? '1' : '0');
                                        $inputBinHidden.prop('checked', !options.bin_hidden);
                                        $inputBinStrokeColor.ladbTextinputColor('val', options.bin_stroke_color);
                                        $inputBinFillColor.ladbTextinputColor('val', options.bin_fill_color);
                                        $inputPartsHidden.prop('checked', !options.parts_hidden);
                                        $inputPartsStrokeColor.ladbTextinputColor('val', options.parts_stroke_color);
                                        $inputPartsFillColor.ladbTextinputColor('val', options.parts_fill_color);
                                        $inputPartsDepthsStrokeColor.ladbTextinputColor('val', options.parts_depths_stroke_color);
                                        $inputPartsDepthsFillColor.ladbTextinputColor('val', options.parts_depths_fill_color);
                                        $inputPartsHolesStrokeColor.ladbTextinputColor('val', options.parts_holes_stroke_color);
                                        $inputPartsHolesFillColor.ladbTextinputColor('val', options.parts_holes_fill_color);
                                        $inputPartsPathsStrokeColor.ladbTextinputColor('val', options.parts_paths_stroke_color);
                                        $inputPartsPathsFillColor.ladbTextinputColor('val', options.parts_paths_fill_color);
                                        $inputTextsHidden.prop('checked', !options.texts_hidden);
                                        $inputTextsColor.ladbTextinputColor('val', options.texts_color);
                                        $inputLeftoversHidden.prop('checked', !options.leftovers_hidden);
                                        $inputLeftoversStrokeColor.ladbTextinputColor('val', options.leftovers_stroke_color);
                                        $inputLeftoversFillColor.ladbTextinputColor('val', options.leftovers_fill_color);
                                        $inputCutsHidden.prop('checked', !options.cuts_hidden);
                                        $inputCutsColor.ladbTextinputColor('val', options.cuts_color);
                                        fnUpdateFieldsVisibility();
                                    };
                                    const fnUpdateFieldsVisibility = function () {
                                        const isDxf = $selectFileFormat.val() === 'dxf';
                                        const isMergeHoles = $selectMergeHoles.val() === '1';
                                        const isIncludePaths = $selectIncludePaths.val() === '1';
                                        const isSheetHidden = !$inputBinHidden.is(':checked');
                                        const isPartsHidden = !$inputPartsHidden.is(':checked');
                                        const isTextsHidden = !$inputTextsHidden.is(':checked');
                                        const isLeftoversHidden = !$inputLeftoversHidden.is(':checked');
                                        const isCutsHidden = !$inputCutsHidden.is(':checked');
                                        if (isDxf) $formGroupDxfStructure.show(); else $formGroupDxfStructure.hide();
                                        if (isMergeHoles) $formGroupMergeHolesOverflow.show(); else $formGroupMergeHolesOverflow.hide();
                                        $inputBinStrokeColor.ladbTextinputColor(isSheetHidden ? 'disable' : 'enable');
                                        $inputBinFillColor.ladbTextinputColor(isSheetHidden || isDxf ? 'disable' : 'enable');
                                        $inputPartsStrokeColor.ladbTextinputColor(isPartsHidden ? 'disable' : 'enable');
                                        $inputPartsFillColor.ladbTextinputColor(isPartsHidden || isDxf ? 'disable' : 'enable');
                                        if (isPartsHidden) $formGroupPartsDepths.hide(); else $formGroupPartsDepths.show();
                                        $inputPartsDepthsStrokeColor.ladbTextinputColor(isPartsHidden ? 'disable' : 'enable');
                                        $inputPartsDepthsFillColor.ladbTextinputColor(isPartsHidden || isDxf ? 'disable' : 'enable');
                                        if (isPartsHidden || !isMergeHoles) $formGroupPartsHoles.hide(); else $formGroupPartsHoles.show();
                                        $inputPartsHolesStrokeColor.ladbTextinputColor(isPartsHidden || !isMergeHoles ? 'disable' : 'enable');
                                        $inputPartsHolesFillColor.ladbTextinputColor(isPartsHidden || !isMergeHoles || isDxf ? 'disable' : 'enable');
                                        if (isPartsHidden || !isIncludePaths) $formGroupPartsPaths.hide(); else $formGroupPartsPaths.show();
                                        $inputPartsPathsStrokeColor.ladbTextinputColor(!isIncludePaths ? 'disable' : 'enable');
                                        $inputPartsPathsFillColor.ladbTextinputColor(!isIncludePaths || isDxf ? 'disable' : 'enable');
                                        if (isPartsHidden) $formGroupTexts.hide(); else $formGroupTexts.show();
                                        $inputTextsColor.ladbTextinputColor(isTextsHidden ? 'disable' : 'enable');
                                        $inputLeftoversStrokeColor.ladbTextinputColor(isLeftoversHidden ? 'disable' : 'enable');
                                        $inputLeftoversFillColor.ladbTextinputColor(isLeftoversHidden || isDxf ? 'disable' : 'enable');
                                        $inputCutsColor.ladbTextinputColor(isCutsHidden ? 'disable' : 'enable');
                                        $('.ladb-form-fill-color').css('opacity', isDxf ? 0.3 : 1);
                                    };

                                    $widgetPreset.ladbWidgetPreset({
                                        dialog: that.dialog,
                                        dictionary: 'cutlist_packing_write_options',
                                        fnFetchOptions: fnFetchOptions,
                                        fnFillInputs: fnFillInputs
                                    });
                                    $selectFileFormat
                                        .selectpicker(SELECT_PICKER_OPTIONS)
                                        .on('changed.bs.select', function () {
                                            const fileCount = solution.bins.length - hiddenBinIndices.length;
                                            $('#ladb_btn_export_file_format', $btnExport).html($(this).val().toUpperCase() + ' <small>( ' + fileCount + ' ' + i18next.t('default.file', {count: fileCount}).toLowerCase() + ' )</small>');
                                            fnUpdateFieldsVisibility();
                                        })
                                    ;
                                    $selectDxfStructure.selectpicker(SELECT_PICKER_OPTIONS);
                                    $selectUnit.selectpicker(SELECT_PICKER_OPTIONS);
                                    $selectSmoothing.selectpicker(SELECT_PICKER_OPTIONS);
                                    $selectMergeHoles.selectpicker(SELECT_PICKER_OPTIONS).on('change', fnUpdateFieldsVisibility);
                                    $inputMergeHolesOverflow.ladbTextinputDimension();
                                    $selectIncludePaths.selectpicker(SELECT_PICKER_OPTIONS).on('change', fnUpdateFieldsVisibility);
                                    $inputBinStrokeColor.ladbTextinputColor(TEXTINPUT_COLOR_OPTIONS);
                                    $inputBinFillColor.ladbTextinputColor(TEXTINPUT_COLOR_OPTIONS);
                                    $inputPartsStrokeColor.ladbTextinputColor(TEXTINPUT_COLOR_OPTIONS);
                                    $inputPartsFillColor.ladbTextinputColor(TEXTINPUT_COLOR_OPTIONS);
                                    $inputPartsDepthsStrokeColor.ladbTextinputColor(TEXTINPUT_COLOR_OPTIONS);
                                    $inputPartsDepthsFillColor.ladbTextinputColor(TEXTINPUT_COLOR_OPTIONS);
                                    $inputPartsHolesStrokeColor.ladbTextinputColor(TEXTINPUT_COLOR_OPTIONS);
                                    $inputPartsHolesFillColor.ladbTextinputColor(TEXTINPUT_COLOR_OPTIONS);
                                    $inputPartsPathsStrokeColor.ladbTextinputColor(TEXTINPUT_COLOR_OPTIONS);
                                    $inputPartsPathsFillColor.ladbTextinputColor(TEXTINPUT_COLOR_OPTIONS);
                                    $inputTextsColor.ladbTextinputColor(TEXTINPUT_COLOR_OPTIONS);
                                    $inputLeftoversStrokeColor.ladbTextinputColor(TEXTINPUT_COLOR_OPTIONS);
                                    $inputLeftoversFillColor.ladbTextinputColor(TEXTINPUT_COLOR_OPTIONS);
                                    $inputCutsColor.ladbTextinputColor(TEXTINPUT_COLOR_OPTIONS);

                                    fnFillInputs(writeOptions);

                                    // Bind inputs
                                    $inputBinHidden.on('change', fnUpdateFieldsVisibility);
                                    $inputPartsHidden.on('change', fnUpdateFieldsVisibility);
                                    $inputTextsHidden.on('change', fnUpdateFieldsVisibility);
                                    $inputLeftoversHidden.on('change', fnUpdateFieldsVisibility);
                                    $inputCutsHidden.on('change', fnUpdateFieldsVisibility);

                                    // Bind buttons
                                    $btnExport.on('click', function () {

                                        // Fetch options
                                        fnFetchOptions(writeOptions);

                                        // Store options
                                        rubyCallCommand('core_set_model_preset', {
                                            dictionary: 'cutlist_packing_write_options',
                                            values: writeOptions,
                                            section: groupId
                                        });

                                        rubyCallCommand('cutlist_packing_write', $.extend({
                                            hidden_bin_indices: hiddenBinIndices,
                                            part_drawing_type: packingOptions.part_drawing_type
                                        }, writeOptions), function (response) {

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

                            });
                            $btnLabels.on('click', function () {

                                // Compute label bins (a list of sheet or bar index attached to part id)
                                let binDefs = {};
                                let binIndex = 0;
                                $.each(response.solution.bins, function () {
                                    for (let i = 0; i < this.count; i++) {
                                        binIndex++;
                                        $.each(this.part_infos, function (v) {
                                            for (let j = 0; j < this.count; j++) {
                                                if (!binDefs[this.part.id]) {
                                                    binDefs[this.part.id] = [];
                                                }
                                                binDefs[this.part.id].push(binIndex);
                                            }
                                        });
                                    }
                                });

                                that.labelsGroupParts(groupId, binDefs);
                            });
                            $btnClose.on('click', function () {
                                that.popSlide();
                            });
                            $btnGenerateNoCache.on('click', function () {
                               fnGenerate(true);
                            });
                            $('.ladb-btn-setup-model-units', $slide).on('click', function () {
                                $(this).blur();
                                that.dialog.executeCommandOnTab('settings', 'highlight_panel', {panel: 'model'});
                            });
                            $('.ladb-btn-toggle-no-print', $slide).on('click', function () {
                                const $group = $(this).parents('.ladb-cutlist-group');
                                const groupId = $group.data('group-id');
                                if ($group.hasClass('no-print')) {
                                    that.showGroup($group, groupId !== 'packing_summary', false, packingOptions, 'cutlist_packing_options', section);
                                } else {
                                    that.hideGroup($group, groupId !== 'packing_summary', false, packingOptions, 'cutlist_packing_options', section);
                                }
                                $(this).blur();
                                return false;
                            });
                            $('.ladb-btn-scrollto-prev-group', $slide).on('click', function () {
                                const $group = $(this).parents('.ladb-cutlist-group');
                                const groupId = $group.data('bin-index');
                                const $target = $('.ladb-cutlist-packing-group[data-bin-index=' + (parseInt(groupId) - 1) + ']');
                                that.scrollSlideToTarget($slide, $target, true, true);
                                $(this).blur();
                                return false;
                            });
                            $('.ladb-btn-scrollto-next-group', $slide).on('click', function () {
                                const $group = $(this).parents('.ladb-cutlist-group');
                                const groupId = $group.data('bin-index');
                                const $target = $('.ladb-cutlist-packing-group[data-bin-index=' + (parseInt(groupId) + 1) + ']');
                                that.scrollSlideToTarget($slide, $target, true, true);
                                $(this).blur();
                                return false;
                            });
                            $('a.ladb-btn-highlight-part', $slide).on('click', function () {
                                const $part = $(this).parents('.ladb-cutlist-row');
                                const partId = $part.data('part-id');
                                that.highlightPart(partId);
                                $(this).blur();
                                return false;
                            });
                            $('a.ladb-btn-scrollto', $slide).on('click', function () {
                                const $target = $($(this).attr('href'));
                                if ($target.data('group-id')) {
                                    that.showGroup($target, false);
                                }
                                that.scrollSlideToTarget($slide, $target, true, true);
                                $(this).blur();
                                return false;
                            });
                            $('a.ladb-btn-edit-material', $slide).on('click', function () {
                                fnEditMaterial({
                                    propertiesTab: 'attributes',
                                });
                                $(this).blur();
                                return false;
                            });
                            $('.ladb-cutlist-row', $slide).on('click', function () {
                                $('.ladb-click-tool', $(this)).click();
                                $(this).blur();
                                return false;
                            });
                            $('#ladb_btn_select_unused_parts', $slide).on('click', function () {
                                that.cleanupSelection();
                                $.each(response.solution.unused_part_infos, function (index, part_info) {
                                    that.selectPart(part_info.part.id, true);
                                });
                                that.dialog.notifySuccess(i18next.t('tab.cutlist.success.part_selected', {count: response.solution.unused_part_infos.length}), [
                                    Noty.button(i18next.t('default.see'), 'btn btn-default', function () {
                                        $btnClose.click();
                                    })
                                ]);
                            });

                            // SVG
                            $('SVG .item', $slide).on('click', function () {
                                const partId = $(this).data('part-id');
                                that.highlightPart(partId);
                                $(this).blur();
                                return false;
                            });

                            // Finish progress feedback
                            that.dialog.finishProgress();

                        };

                        window.requestAnimationFrame(function () {
                            that.dialog.startProgress(parseInt(packingOptions.time_limit) * 4, function () {
                                rubyCallCommand('cutlist_group_packing_cancel');
                            });
                            rubyCallCommand('cutlist_group_packing_start', $.extend({
                                part_ids: partIds,
                                hide_material_colors: that.generateOptions.hide_material_colors,
                                no_cache: noCache
                            }, packingOptions), function (response) {

                                if (response.running) {
                                    let waitingForResponse = false;
                                    const intervalId = setInterval(function () {

                                        if (waitingForResponse) {
                                            return;
                                        }

                                        rubyCallCommand('cutlist_group_packing_advance', null, function (response) {

                                            waitingForResponse = false;

                                            if (response.running) {

                                                // Advance progress feedback
                                                that.dialog.incProgress(1);

                                                if (response.solution) {
                                                    that.dialog.changeCancelBtnLabelProgress(i18next.t('default.stop'))
                                                    that.dialog.previewProgress(Twig.twig({ref: "tabs/cutlist/_progress-preview-packing.twig"}).render({
                                                        solution: response.solution
                                                    }));
                                                }

                                            } else if (response.cancelled) {

                                                clearInterval(intervalId);

                                                // Finish progress feedback
                                                that.dialog.finishProgress();

                                            } else {

                                                clearInterval(intervalId);

                                                fnCreateSlide(response);

                                            }

                                        });
                                        waitingForResponse = true;

                                    }, 250);
                                } else if (response.cancelled) {

                                    // Finish progress feedback
                                    that.dialog.finishProgress();

                                } else {
                                    fnCreateSlide(response);
                                }

                            });
                        });

                        // Hide modal
                        $modal.modal('hide');

                    }

                };

                $widgetPreset.ladbWidgetPreset({
                    dialog: that.dialog,
                    dictionary: 'cutlist_packing_options',
                    fnFetchOptions: fnFetchOptions,
                    fnFillInputs: fnFillInputs
                });
                $editorStdBinSizes
                    .ladbEditorSizes({
                        format: group.material_is_1d ? FORMAT_D : FORMAT_D_D,
                        d1Placeholder: i18next.t('default.length'),
                        d2Placeholder: i18next.t('default.width'),
                        qPlaceholder: '∞',
                        qHidden: false,
                        emptyVal: '0',
                        dropdownActionLabel: '<i class="ladb-opencutlist-icon-plus"></i> ' + i18next.t('tab.cutlist.packing.option_std_bin_' + (group.material_is_1d ? '1' : '2') + 'd_add'),
                        dropdownActionCallback: function () {
                            fnEditMaterial({
                                callback: function ($editMaterialModal) {
                                    setTimeout(function () {
                                        $('#ladb_materials_editor_std_' + (group.material_is_1d ? 'lengths' : 'sizes'), $editMaterialModal).ladbEditorSizes('appendRow', [{}, {autoFocus: true}]);
                                    }, 200);
                                }
                            })
                        }
                    })
                    .ladbEditorSizes('setAvailableSizesAndSizes', [ group.material_is_1d ? response.std_lengths : response.std_sizes, group.material_is_1d ? packingOptions.std_bin_1d_sizes : packingOptions.std_bin_2d_sizes ])
                ;
                $editorScrapBinSizes
                    .ladbEditorSizes({
                        format: group.material_is_1d ? FORMAT_D_Q : FORMAT_D_D_Q,
                        d1Placeholder: i18next.t('default.length'),
                        d2Placeholder: i18next.t('default.width'),
                        emptyVal: '0'
                    })
                    .ladbEditorSizes('setSizes', group.material_is_1d ? packingOptions.scrap_bin_1d_sizes : packingOptions.scrap_bin_2d_sizes)
                ;
                $selectRectangleguillotineFirstStageOrientation.selectpicker(SELECT_PICKER_OPTIONS);
                $selectRectangleguillotineCutType.selectpicker(SELECT_PICKER_OPTIONS);
                $selectRectangleguillotineNumberOfStages.selectpicker(SELECT_PICKER_OPTIONS);
                $inputRectangleguillotineKeepSize.ladbTextinputSize({
                    resetValue: '',
                    d1Placeholder: i18next.t('default.length'),
                    d2Placeholder: i18next.t('default.width'),
                    qDisabled: true,
                    qHidden: true,
                    dSeparatorLabel: 'x'
                });
                $selectIrregularAllowedRotations.selectpicker(SELECT_PICKER_OPTIONS);
                $selectIrregularAllowMirroring.selectpicker(SELECT_PICKER_OPTIONS);
                $inputSpacing.ladbTextinputDimension();
                $inputTrimming.ladbTextinputDimension();
                $textareaItemsFormula.ladbTextinputCode({
                    variableDefs: fnConvertToVariableDefs([
                        { name: 'number', type: 'string' },
                        { name: 'path', type: 'array' },
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
                        { name: 'material', type: 'material' },
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
                        { name: 'layer', type: 'string' },
                        { name: 'component_definition', type: 'component_definition' },
                        { name: 'component_instance', type: 'component_instance' },
                    ]),
                    snippetDefs: [
                        { name: i18next.t('tab.cutlist.snippet.number'), value: '@number' },
                        { name: i18next.t('tab.cutlist.snippet.name'), value: '@name' },
                        { name: i18next.t('tab.cutlist.snippet.number_and_name'), value: '@number + " - " + @name' },
                        { name: '-' },
                        { name: i18next.t('tab.cutlist.snippet.size'), value: '@bbox_length + " x " + @bbox_width' },
                        { name: i18next.t('tab.cutlist.snippet.area'), value: '@bbox_length * @bbox_width' },
                        { name: i18next.t('tab.cutlist.snippet.volume'), value: '@bbox_length * @bbox_width * @bbox_thickness' },
                    ]
                });
                $selectOriginCorner.selectpicker(SELECT_PICKER_OPTIONS);
                $selectBinFolding.selectpicker(SELECT_PICKER_OPTIONS);
                $selectHidePartList.selectpicker(SELECT_PICKER_OPTIONS);
                $selectPartDrawingType.selectpicker(SELECT_PICKER_OPTIONS);
                $selectColorization.selectpicker(SELECT_PICKER_OPTIONS);
                $selectHighlightPrimaryCuts.selectpicker(SELECT_PICKER_OPTIONS);
                $selectHideEdgesPreview.selectpicker(SELECT_PICKER_OPTIONS);
                $selectObjective.selectpicker(SELECT_PICKER_OPTIONS);
                $selectOptimizationMode.selectpicker(SELECT_PICKER_OPTIONS)
                $inputTimeLimit.ladbTextinputText();
                $inputNotAnytimeTreeSearchQueueSize.ladbTextinputText();
                $selectVerbosityLevel.selectpicker(SELECT_PICKER_OPTIONS);
                $selectInputToJsonBinDir.selectpicker(SELECT_PICKER_OPTIONS);

                fnFillInputs(packingOptions);

                // Bind radios
                $btnsProblemType.on('click', function (e) {
                    if ($(this).hasClass('disabled')) {
                        e.preventDefault();
                        return false;
                    }
                });
                $radiosProblemType.on('change', fnUpdateFieldsVisibility);

                // Bind tabs
                $tabs.on('shown.bs.tab', function (e) {
                    that.lastPackingOptionsTab = $(e.target).attr('href').substring('#tab_packing_options_'.length);
                });

                // Bind collapses
                $('#ladb-cutlist-packing-collapse-expert')
                    .on('shown.bs.collapse', function () {
                        $('i', $btnExpert)
                            .removeClass('ladb-opencutlist-icon-plus')
                            .addClass('ladb-opencutlist-icon-minus')
                        ;
                    })
                    .on('hidden.bs.collapse', function () {
                        $('i', $btnExpert)
                            .addClass('ladb-opencutlist-icon-plus')
                            .removeClass('ladb-opencutlist-icon-minus')
                        ;
                    })
                ;

                // Bind clickable
                $('.ladb-clickable[data-material-properties-tab]').on('click', function (e) {
                    fnEditMaterial({
                        propertiesTab: $(this).data('material-properties-tab')
                    })
                })

                // Bind buttons
                $btnEditMaterial.on('click', function () {
                    fnEditMaterial();
                });
                $btnUnloadLib.on('click', function () {
                    rubyCallCommand('core_unload_c_lib', {lib: 'packy'}, function (response) {
                        if (response.errors) {
                            that.dialog.notifyErrors(response.errors);
                        }
                        if (response.success) {
                            that.dialog.notifySuccess('Packy unloaded');
                        }
                    });
                });
                $btnExpert.on('click', function () {
                    $('#ladb-cutlist-packing-collapse-expert').collapse('toggle');
                    $(this).blur();
                })
                $btnGenerate.on('click', function () {

                    // Fetch options
                    fnFetchOptions(packingOptions);

                    // Store options
                    rubyCallCommand('core_set_model_preset', { dictionary: 'cutlist_packing_options', values: packingOptions, section: section });

                    fnGenerate(false);

                });

                // Show modal
                $modal.modal('show');

                // Setup popovers
                that.dialog.setupPopovers();

            });

        });

    };

    // Labels /////

    LadbTabCutlist.prototype.labelsAllParts = function () {
        let partIdsWithContext = this.grabVisiblePartIdsWithContext(null);
        this.labelsParts(partIdsWithContext.partIds, partIdsWithContext.context);
    }

    LadbTabCutlist.prototype.labelsGroupParts = function (groupId, binDefs, forceDefaultTab) {
        let partIdsWithContext = this.grabVisiblePartIdsWithContext(groupId);
        this.labelsParts(partIdsWithContext.partIds, partIdsWithContext.context, binDefs, forceDefaultTab);
    }

    LadbTabCutlist.prototype.labelsParts = function (partIds, context, binDefs, forceDefaultTab) {
        const that = this;

        const isBinSorterDisabled = !binDefs;

        const section = context && context.targetGroup ? context.targetGroup.id : null;

        // Retrieve label options
        rubyCallCommand('core_get_model_preset', { dictionary: 'cutlist_labels_options', section: section }, function (response) {

            const labelsOptions = response.preset;

            const $modal = that.appendModalInside('ladb_cutlist_modal_labels', 'tabs/cutlist/_modal-labels.twig', {
                group: context.targetGroup,
                isGroupSelection: context ? context.isGroupSelection : false,
                isPartSelection: context ? context.isPartSelection : false,
                isBinSorterDisabled: isBinSorterDisabled,
                tab: forceDefaultTab || that.lastLabelsOptionsTab == null ? 'layout' : that.lastLabelsOptionsTab
            });

            // Fetch UI elements
            const $widgetPreset = $('.ladb-widget-preset', $modal);
            const $editorLabelLayout = $('#ladb_editor_label_layout', $modal);
            const $selectPageFormat = $('#ladb_select_page_format', $modal);
            const $inputPageWidth = $('#ladb_input_page_width', $modal);
            const $inputPageHeight = $('#ladb_input_page_height', $modal);
            const $inputMarginTop = $('#ladb_input_margin_top', $modal);
            const $inputMarginRight = $('#ladb_input_margin_right', $modal);
            const $inputMarginBottom = $('#ladb_input_margin_bottom', $modal);
            const $inputMarginLeft = $('#ladb_input_margin_left', $modal);
            const $inputSpacingH = $('#ladb_input_spacing_h', $modal);
            const $inputSpacingV = $('#ladb_input_spacing_v', $modal);
            const $inputColCount = $('#ladb_input_col_count', $modal);
            const $inputRowCount = $('#ladb_input_row_count', $modal);
            const $selectCuttingMarks = $('#ladb_select_cutting_marks', $modal);
            const $sortablePartOrderStrategy = $('#ladb_sortable_part_order_strategy', $modal);
            const $editorLabelOffset = $('#ladb_editor_label_offset', $modal);
            const $btnGenerate = $('#ladb_cutlist_labels_btn_generate', $modal);

            const fnValidOffset = function (offset, colCount, rowCount) {
                if (offset >= colCount * rowCount) {
                    offset = 0;
                }
                return offset;
            }
            const fnUpdatePageSizeFieldsAvailability = function () {
                if ($selectPageFormat.selectpicker('val') == null) {
                    $selectPageFormat.selectpicker('val', '0');
                    $inputPageWidth.ladbTextinputDimension('enable');
                    $inputPageHeight.ladbTextinputDimension('enable');
                } else {
                    $inputPageWidth.ladbTextinputDimension('disable');
                    $inputPageHeight.ladbTextinputDimension('disable');
                }
            }
            const fnConvertPageSettings = function(pageWidth, pageHeight, marginTop, marginRight, marginBottom, marginLeft, spacingH, spacingV, colCount, rowCount, callback) {
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
            const fnComputeLabelSize = function(pageWidth, pageHeight, marginTop, marginRight, marginBottom, marginLeft, spacingH, spacingV, colCount, rowCount, callback) {
                fnConvertPageSettings(pageWidth, pageHeight, marginTop, marginRight, marginBottom, marginLeft, spacingH, spacingV, colCount, rowCount, function (response, colCount, rowCount) {
                    const labelWidth = (response.page_width - response.margin_left - response.margin_right - response.spacing_v * (colCount - 1)) / colCount;
                    const labelHeight = (response.page_height - response.margin_top - response.margin_bottom - response.spacing_h * (rowCount - 1)) / rowCount;
                    callback(labelWidth, labelHeight, response);
                });
            }
            const fnFetchOptions = function (options) {
                options.page_width = $inputPageWidth.val();
                options.page_height = $inputPageHeight.val();
                options.margin_top = $inputMarginTop.val();
                options.margin_right = $inputMarginRight.val();
                options.margin_bottom = $inputMarginBottom.val();
                options.margin_left = $inputMarginLeft.val();
                options.spacing_h = $inputSpacingH.val();
                options.spacing_v = $inputSpacingV.val();
                options.col_count = Math.max(1, that.toInt($inputColCount.val() === '' ? 1 : $inputColCount.val()));
                options.row_count = Math.max(1, that.toInt($inputRowCount.val() === '' ? 1 : $inputRowCount.val()));
                options.cutting_marks = $selectCuttingMarks.val() === '1';
                options.layout = $editorLabelLayout.ladbEditorLabelLayout('getElementDefs');
                options.offset = fnValidOffset($editorLabelOffset.ladbEditorLabelOffset('getOffset'), options.col_count, options.row_count);

                let properties = [];
                $sortablePartOrderStrategy.children('li').each(function () {
                    properties.push($(this).data('property'));
                });
                options.part_order_strategy = properties.join('>');

            }
            const fnFillInputs = function (options) {
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

                let properties = options.part_order_strategy.split('>');
                $sortablePartOrderStrategy.empty();
                for (let i = 0; i < properties.length; i++) {
                    const property = properties[i];
                    $sortablePartOrderStrategy.append(Twig.twig({ref: "tabs/cutlist/_labels-option-part-order-strategy-property.twig"}).render({
                        order: property.startsWith('-') ? '-' : '',
                        property: property.startsWith('-') ? property.substring(1) : property,
                        enabled: property !== 'bin' || !isBinSorterDisabled
                    }));
                }
                $sortablePartOrderStrategy.find('a').on('click', function () {
                    const $item = $(this).parent().parent();
                    const $icon = $('i', $(this));
                    let property = $item.data('property');
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
                group: that.findGroupAndPartById(partIds[0]).group,
                partId: partIds[0],
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
                const tabId = $(e.target).attr('href');
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
                const format = $(this).val();
                if (format !== '0') {
                    $inputPageWidth.ladbTextinputDimension('disable');
                    $inputPageHeight.ladbTextinputDimension('disable');
                    const dimensions = format.split('x');
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
                rubyCallCommand('core_set_model_preset', { dictionary: 'cutlist_labels_options', values: labelsOptions, section: section });

                fnComputeLabelSize(labelsOptions.page_width, labelsOptions.page_height, labelsOptions.margin_top, labelsOptions.margin_right, labelsOptions.margin_bottom, labelsOptions.margin_left, labelsOptions.spacing_h, labelsOptions.spacing_v, labelsOptions.col_count, labelsOptions.row_count, function (labelWidth, labelHeight, response) {

                    labelsOptions.page_width = response.page_width;
                    labelsOptions.page_height = response.page_height;
                    labelsOptions.margin_top = response.margin_top;
                    labelsOptions.margin_right = response.margin_right;
                    labelsOptions.margin_bottom = response.margin_bottom;
                    labelsOptions.margin_left = response.margin_left;
                    labelsOptions.spacing_h = response.spacing_h;
                    labelsOptions.spacing_v = response.spacing_v;

                    const errors = [];
                    const warnings = [];
                    const pages = [];

                    if (context ? context.isGroupSelection : false) {

                        // Warn for partiel result
                        warnings.push('tab.cutlist.labels.warning.is_group_selection')

                    }
                    if (context ? context.isPartSelection : false) {

                        // Warn for partiel result
                        warnings.push('tab.cutlist.labels.warning.is_part_selection')

                    }

                    const fnRenderSlide = function () {

                        const $slide = that.pushNewSlide('ladb_cutlist_slide_labels', 'tabs/cutlist/_slide-labels.twig', $.extend({
                            errors: errors,
                            warnings: warnings,
                            filename: that.filename,
                            modelName: that.modelName,
                            pageName: that.pageName,
                            isEntitySelection: that.isEntitySelection,
                            lengthUnit: that.lengthUnit,
                            generatedAt: new Date().getTime() / 1000,
                            group: context.targetGroup,
                            pages: pages,
                            hideMaterialColors: that.generateOptions.hide_material_colors
                        }, labelsOptions), function () {
                            that.dialog.setupTooltips();
                        });

                        // Fetch UI elements
                        const $btnLabels = $('#ladb_btn_labels', $slide);
                        const $btnPrint = $('#ladb_btn_print', $slide);
                        const $btnClose = $('#ladb_btn_close', $slide);

                        // Bind buttons
                        $btnLabels.on('click', function () {
                            that.labelsParts(partIds, context, binDefs);
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
                            const $page = $(this).parents('.ladb-cutlist-group');
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

                        rubyCallCommand('cutlist_labels', { part_ids: partIds, layout: labelsOptions.layout, part_order_strategy: labelsOptions.part_order_strategy, bin_defs: binDefs }, function (response) {

                            let entries = [];

                            if (response.errors) {
                                errors.push(response.errors);
                            }
                            if (response.entries) {
                                entries = response.entries;
                            }

                            // Split part infos into pages
                            let page;
                            let gIndex = 0;
                            for (let i = 1; i <= labelsOptions.offset; i++) {
                                if (gIndex % (labelsOptions.row_count * labelsOptions.col_count) === 0) {
                                    page = {
                                        entries: []
                                    }
                                    pages.push(page);
                                }
                                page.entries.push({
                                    part: null
                                });
                                gIndex++;
                            }
                            for (const entry of entries) {
                                entry.group = that.findGroupById(entry.group_id, true);
                                if (gIndex % (labelsOptions.row_count * labelsOptions.col_count) === 0) {
                                    page = {
                                        entries: []
                                    }
                                    pages.push(page);
                                }
                                page.entries.push(entry);
                                gIndex++;
                            }

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
    }

    // Parts /////

    LadbTabCutlist.prototype.grabVisiblePartIdsWithContext = function (groupId, materialFilter) {
        const that = this;

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
        for (let i = 0; i < this.groups.length; i++) {
            const group = this.groups[i];
            for (let j = 0; j < group.parts.length; j++) {
                const part = group.parts[j];
                if (part.id === id) {
                    return { group: group, part: part };
                } else if (part.children !== undefined) {
                    for (let k = 0; k < part.children.length; k++) {
                        const childPart = part.children[k];
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
        for (let i = 0; i < this.groups.length; i++) {
            const group = this.groups[i];
            for (let j = 0; j < group.parts.length; j++) {
                const part = group.parts[j];
                if (part.children !== undefined) {
                    for (let k = 0; k < part.children.length; k++) {
                        const childPart = part.children[k];
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
        const that = this;
        const $group = $('#ladb_group_' + id, this.$page);
        const defs = [ 'packing', 'labels', 'layout' ];
        $.each(defs, function () {
            const $btn = $('button.ladb-btn-group-' + this, $group);
            const $i = $('i', $btn);
            const clazz = 'ladb-opencutlist-icon-' + this + '-selection';
            let doEffet = false;
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
        const $row = $('#ladb_part_' + id, this.$page);
        const $highlightPartBtn = $('a.ladb-btn-highlight-part', $row);
        const $editPartBtn = $('a.ladb-btn-edit-part', $row);
        const $selectPartBtn = $('a.ladb-btn-select-part', $row);

        if (selected) {
            $row.addClass('ladb-selected');
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
            $row.removeClass('ladb-selected');
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
        for (let i = 0; i < this.selectionPartIds.length; i++) {
            this.renderSelectionOnPart(this.selectionPartIds[i], true);
        }
    };

    LadbTabCutlist.prototype.cleanupSelection = function () {
        for (let i = this.selectionPartIds.length - 1; i >= 0 ; i--) {
            if (!this.findGroupAndPartById(this.selectionPartIds[i])) {
                this.selectionPartIds.splice(i, 1)
            }
        }
    };

    LadbTabCutlist.prototype.selectPart = function (partId, state /* undefined = TOGGLE, true = SELECT, false = UNSELECT */) {
        const groupAndPart = this.findGroupAndPartById(partId);
        if (groupAndPart) {

            // Unselect other group selection
            if (this.selectionGroupId !== null && this.selectionGroupId !== groupAndPart.group.id) {
                this.selectGroupParts(this.selectionGroupId, false);
            }

            // Manage selection
            let selected = this.selectionGroupId === groupAndPart.group.id && this.selectionPartIds.includes(partId);
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
        const group = this.findGroupById(groupId);
        if (group) {

            if (state === undefined) {
                state = !(this.selectionGroupId === group.id && this.selectionPartIds.length > 0);
            }
            for (let i = 0 ; i < group.parts.length; i++) {
                this.selectPart(group.parts[i].id, state);
            }

        }
    };

    LadbTabCutlist.prototype.editPart = function (id, serializedPath, tab, updatedCallback) {
        const that = this;

        const groupAndPart = id ? this.findGroupAndPartById(id) : (serializedPath ? this.findGroupAndPartBySerializedPath(serializedPath) : null);
        if (groupAndPart) {

            const group = groupAndPart.group;
            const part = groupAndPart.part;

            const isFolder = part.children && part.children.length > 0;
            const isSelected = this.selectionGroupId === group.id && this.selectionPartIds.includes(part.id) && this.selectionPartIds.length > 1;
            const multiple = isFolder || isSelected;

            const editedPart = JSON.parse(JSON.stringify(isFolder ? part.children[0] : part));  // Create a clone
            const editedParts = [];
            if (multiple) {
                if (isFolder && !isSelected) {
                    for (let i = 0; i < part.children.length; i++) {
                        editedParts.push(part.children[i]);
                    }
                } else if (isSelected) {
                    for (let i = 0; i < this.selectionPartIds.length; i++) {
                        const groupAndPart = that.findGroupAndPartById(this.selectionPartIds[i]);
                        if (groupAndPart) {
                            if (groupAndPart.part.children) {
                                for (let j = 0; j < groupAndPart.part.children.length; j++) {
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

            for (let i = 0; i < editedParts.length; i++) {
                let ownedMaterialCount = 0;
                for (let j = 0; j < editedParts[i].material_origins.length; j++) {
                    if (editedParts[i].material_origins[j] === 1) {    // 1 = MATERIAL_ORIGIN_OWNED
                        ownedMaterialCount++;
                    }
                }
                let materialName = null;
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

            const $modal = that.appendModalInside('ladb_cutlist_modal_part', 'tabs/cutlist/_modal-part.twig', {
                group: group,
                part: editedPart,
                partCount: editedParts.length,
                multiple: multiple,
                materialUsages: that.materialUsages,
                tab: tab
            });

            // Fetch UI elements
            const $tabs = $('a[data-toggle="tab"]', $modal);
            const $divPartThumbnail = $('#ladb_cutlist_part_thumbnail', $modal);
            const $inputName = $('#ladb_cutlist_part_input_name', $modal);
            const $selectMaterialName = $('#ladb_cutlist_part_select_material_name', $modal);
            const $selectCumulable = $('#ladb_cutlist_part_select_cumulable', $modal);
            const $inputInstanceCountByPart = $('#ladb_cutlist_part_input_instance_count_by_part', $modal);
            const $inputMass = $('#ladb_cutlist_part_input_mass', $modal);
            const $inputPrice = $('#ladb_cutlist_part_input_price', $modal);
            const $inputThicknessLayerCount = $('#ladb_cutlist_part_input_thickness_layer_count', $modal);
            const $inputDescription = $('#ladb_cutlist_part_input_description', $modal);
            const $inputUrl = $('#ladb_cutlist_part_input_url', $modal);
            const $inputTags = $('#ladb_cutlist_part_input_tags', $modal);
            const $inputOrientationLockedOnAxis = $('#ladb_cutlist_part_input_orientation_locked_on_axis', $modal);
            const $inputSymmetrical = $('#ladb_cutlist_part_input_symmetrical', $modal);
            const $inputIgnoreGrainDirection = $('#ladb_cutlist_part_input_ignore_grain_direction', $modal);
            const $inputPartAxes = $('#ladb_cutlist_part_input_axes', $modal);
            const $sortableAxes = $('#ladb_sortable_axes', $modal);
            const $sortablePartAxes = $('#ladb_sortable_part_axes', $modal);
            const $sortablePartAxesExtra = $('#ladb_sortable_part_axes_extra', $modal);
            const $selectPartAxesOriginPosition = $('#ladb_cutlist_part_select_axes_origin_position', $modal);
            const $inputLengthIncrease = $('#ladb_cutlist_part_input_length_increase', $modal);
            const $inputWidthIncrease = $('#ladb_cutlist_part_input_width_increase', $modal);
            const $inputThicknessIncrease = $('#ladb_cutlist_part_input_thickness_increase', $modal);
            const $selectEdgeYmax = $('#ladb_cutlist_part_select_edge_ymax', $modal);
            const $selectEdgeYmin = $('#ladb_cutlist_part_select_edge_ymin', $modal);
            const $selectEdgeXmin = $('#ladb_cutlist_part_select_edge_xmin', $modal);
            const $selectEdgeXmax = $('#ladb_cutlist_part_select_edge_xmax', $modal);
            const $selectFaceZmin = $('#ladb_cutlist_part_select_face_zmin', $modal);
            const $selectFaceZmax = $('#ladb_cutlist_part_select_face_zmax', $modal);
            const $formGroupFaceZminTextureAngle = $('#ladb_cutlist_part_form_group_face_zmin_texture_angle', $modal);
            const $formGroupFaceZmaxTextureAngle = $('#ladb_cutlist_part_form_group_face_zmax_texture_angle', $modal);
            const $inputFaceZminTextureAngle = $('#ladb_cutlist_part_input_face_zmin_texture_angle', $modal);
            const $inputFaceZmaxTextureAngle = $('#ladb_cutlist_part_input_face_zmax_texture_angle', $modal);
            const $rectIncreaseLength = $('svg .increase-length', $modal);
            const $rectIncreaseWidth = $('svg .increase-width', $modal);
            const $rectEdgeYmin = $('svg .edge-ymin', $modal);
            const $rectEdgeYmax = $('svg .edge-ymax', $modal);
            const $rectEdgeXmin = $('svg .edge-xmin', $modal);
            const $rectEdgeXmax = $('svg .edge-xmax', $modal);
            const $rectFaceZmin = $('svg .face-zmin', $modal);
            const $rectFaceZmax = $('svg .face-zmax', $modal);
            const $rectFaceZminGrain = $('svg .face-zmin .face-grain', $modal);
            const $rectFaceZmaxGrain = $('svg .face-zmax .face-grain', $modal);
            const $patternFaceZminGrain = $('#pattern_face_zmin_grain', $modal);
            const $patternFaceZmaxGrain = $('#pattern_face_zmax_grain', $modal);
            const $labelEdgeYmax = $('#ladb_cutlist_part_label_edge_ymax', $modal);
            const $labelEdgeYmin = $('#ladb_cutlist_part_label_edge_ymin', $modal);
            const $labelEdgeXmin = $('#ladb_cutlist_part_label_edge_xmin', $modal);
            const $labelEdgeXmax = $('#ladb_cutlist_part_label_edge_xmax', $modal);
            const $labelFaceZmin = $('#ladb_cutlist_part_label_face_zmin', $modal);
            const $labelFaceZmax = $('#ladb_cutlist_part_label_face_zmax', $modal);
            const $labelFaceZminTextureAngle = $('#ladb_cutlist_part_label_face_zmin_texture_angle', $modal);
            const $labelFaceZmaxTextureAngle = $('#ladb_cutlist_part_label_face_zmax_texture_angle', $modal);
            const $btnHighlight = $('#ladb_cutlist_part_highlight', $modal);
            const $btnExportToFile = $('a.ladb-cutlist-write-parts', $modal);
            const $btnUpdate = $('#ladb_cutlist_part_update', $modal);

            let thumbnailLoaded = false;

            // Utils function
            const fnComputeAxesOrder = function () {
                const axes = [];
                $sortablePartAxes.children('li').each(function () {
                    axes.push($(this).data('axis'));
                });
                $inputPartAxes.val(axes);
                return axes;
            };
            const fnDisplayAxisDimensions = function () {
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
            const fnUpdateEdgesPreview = function() {
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
            const fnIsMaterialTexturedAndGrained = function(name) {
                for (let materialUsage of that.materialUsages) {
                    if (materialUsage.name === name) {
                        return materialUsage.textured && materialUsage.grained;
                    }
                }
                return false;
            };
            const fnUpdateFacesPreview = function() {
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
                        $patternFaceZmaxGrain.attr('patternTransform', 'rotate(' + that.toInt($inputFaceZmaxTextureAngle.val()) * -1 + ' 0 0)');
                        $formGroupFaceZmaxTextureAngle.show();
                    } else {
                        $rectFaceZmaxGrain.hide();
                        $formGroupFaceZmaxTextureAngle.hide();
                    }
                }
            };
            const fnUpdateIncreasesPreview = function() {
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
            const fnNewCheck = function($select, type) {
                if ($select.val() === 'new') {
                    that.dialog.executeCommandOnTab('materials', 'new_material', { type: type });
                    $modal.modal('hide');
                    return true;
                }
                return false;
            };
            const fnMaterialNameCopyToAllEdges = function(materialName) {
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
            const fnMaterialNameCopyToAllVeneers = function(materialName) {
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
            const fnIncrementVeneerTextureAngleInputValue = function($input, inc) {
                let angle = parseInt($input.val());
                if (!isNaN(angle)) {
                    $input.val((angle + inc) % 360);
                    fnUpdateFacesPreview();
                }
            }
            const fnOnAxiesOrderChanged = function () {
                const axes = fnComputeAxesOrder();

                const oriented = editedPart.axes_to_values[axes[0]] >= editedPart.axes_to_values[axes[1]] && editedPart.axes_to_values[axes[1]] >= editedPart.axes_to_values[axes[2]];

                // Check Orientation Locked On Axis option if needed
                $inputOrientationLockedOnAxis.prop('checked', !oriented);
                fnDisplayAxisDimensions();

                // By default, set origin position to 'min'
                $selectPartAxesOriginPosition
                    .selectpicker('val', 'min')
                    .trigger('change')
                ;

            }
            const fnLoadThumbnail = function () {
                if (!thumbnailLoaded && !multiple && !part.virtual) {

                    // Generate and Retrieve part thumbnail file
                    rubyCallCommand('cutlist_part_get_thumbnail', {
                        definition_id: part.definition_id,
                        id: part.id
                    }, function (response) {

                        const threeModelDef = response['three_model_def'];
                        const thumbnailFile = response['thumbnail_file'];

                        if (threeModelDef) {

                            const $viewer = $(Twig.twig({ref: 'tabs/cutlist/_three-viewer-modal-part.twig'}).render({
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

                                const $img = $('<img>')
                                    .attr('src', thumbnailFile)
                                ;
                                if (part.flipped) {
                                    $img
                                        .css('transform', 'scaleX(-1)')
                                    ;
                                }

                                $divPartThumbnail.html($img);

                        } else {
                            if (response.errors) {
                                that.dialog.notifyErrors(response.errors);
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
               const sortedNormals = Object.keys(editedPart.axes_to_values).sort(function (a, b) {
                   return editedPart.axes_to_values[b] - editedPart.axes_to_values[a]
               });
               const $rowX = $('li[data-axis="' + sortedNormals[0] + '"]', $sortablePartAxes);
               const $rowY = $('li[data-axis="' + sortedNormals[1] + '"]', $sortablePartAxes);
               const $rowZ = $('li[data-axis="' + sortedNormals[2] + '"]', $sortablePartAxes);
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

                for (let i = 0; i < editedParts.length; i++) {

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
                            editedParts[i].cumulable = that.toInt($selectCumulable.val());
                        }
                        if (!$inputInstanceCountByPart.ladbTextinputNumberWithUnit('isMultiple')) {
                            editedParts[i].instance_count_by_part = Math.max(1, $inputInstanceCountByPart.val() === '' ? 1 : that.toInt($inputInstanceCountByPart.val()));
                        }
                        if (!$inputMass.ladbTextinputNumberWithUnit('isMultiple')) {
                            editedParts[i].mass = $inputMass.ladbTextinputNumberWithUnit('val');
                        }
                        if (!$inputPrice.ladbTextinputNumberWithUnit('isMultiple')) {
                            editedParts[i].price = $inputPrice.val().trim();
                        }
                        if (!$inputThicknessLayerCount.ladbTextinputNumberWithUnit('isMultiple')) {
                            editedParts[i].thickness_layer_count = Math.max(1, $inputThicknessLayerCount.val() === '' ? 1 : that.toInt($inputThicknessLayerCount.val()));
                        }
                        if (!$inputDescription.ladbTextinputArea('isMultiple')) {
                            editedParts[i].description = $inputDescription.val().trim();
                        }
                        if (!$inputUrl.ladbTextinputUrl('isMultiple')) {
                            editedParts[i].url = $inputUrl.val().trim();
                        }

                        const untouchTags = editedParts[i].tags.filter(function (tag) {
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
                            editedParts[i].face_texture_angles.zmin = $inputFaceZminTextureAngle.val() === '' ? null : that.toInt($inputFaceZminTextureAngle.val());
                        }
                        if (!$inputFaceZmaxTextureAngle.ladbTextinputNumberWithUnit('isMultiple')) {
                            editedParts[i].face_texture_angles.zmax = $inputFaceZmaxTextureAngle.val() === '' ? null : that.toInt($inputFaceZmaxTextureAngle.val());
                        }

                    }

                }

                rubyCallCommand('cutlist_part_update', { auto_orient: that.generateOptions.auto_orient, parts_data: editedParts }, function (response) {

                    if (response.errors) {

                        that.dialog.notifyErrors(response.errors);

                    } else {

                        if (typeof updatedCallback === 'function') {
                            updatedCallback()
                        } else {

                            const partId = editedPart.id;
                            const wTop = $('#ladb_part_' + partId).offset().top - $(window).scrollTop();

                            // Refresh the list
                            that.generateCutlist(function () {

                                // Try to scroll to the edited part's row
                                const $part = $('#ladb_part_' + partId, that.$page);
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

            const $modal = this.appendModalInside('ladb_cutlist_modal_unknow_part', 'tabs/cutlist/_modal-unknow-part.twig');

            // Show modal
            $modal.modal('show');

        }
    };

    LadbTabCutlist.prototype.toggleFoldingRow = function ($row, dataKey) {
        const $btn = $('.ladb-btn-folding-toggle-row', $row);
        const $i = $('i', $btn);

        if ($i.hasClass('ladb-opencutlist-icon-arrow-down')) {
            this.expandFoldingRow($row, dataKey);
        } else {
            this.collapseFoldingRow($row, dataKey);
        }
    };

    LadbTabCutlist.prototype.expandFoldingRow = function ($row, dataKey) {
        const rowId = $row.data(dataKey ? dataKey : 'part-id');
        const $btn = $('.ladb-btn-folding-toggle-row', $row);
        const $i = $('i', $btn);

        $i.addClass('ladb-opencutlist-icon-arrow-up');
        $i.removeClass('ladb-opencutlist-icon-arrow-down');

        // Show children
        $row.siblings('tr[data-folder-id=' + rowId + ']').removeClass('hide');

    };

    LadbTabCutlist.prototype.collapseFoldingRow = function ($row, dataKey) {
        const rowId = $row.data(dataKey ? dataKey : 'part-id');
        const $btn = $('.ladb-btn-folding-toggle-row', $row);
        const $i = $('i', $btn);

        $i.addClass('ladb-opencutlist-icon-arrow-down');
        $i.removeClass('ladb-opencutlist-icon-arrow-up');

        // Hide children
        $row.siblings('tr[data-folder-id=' + rowId + ']').addClass('hide');

    };

    LadbTabCutlist.prototype.expandAllFoldingRows = function ($slide, dataKey) {
        const that = this;
        $('.ladb-cutlist-row-folder', $slide === undefined ? this.$page : $slide).each(function () {
            that.expandFoldingRow($(this), dataKey);
        });
    };

    LadbTabCutlist.prototype.collapseAllFoldingRows = function ($slide, dataKey) {
        const that = this;
        $('.ladb-cutlist-row-folder', $slide === undefined ? this.$page : $slide).each(function () {
            that.collapseFoldingRow($(this), dataKey);
        });
    };

    // Groups /////

    LadbTabCutlist.prototype.findGroupById = function (id) {
        for (let i = 0 ; i < this.groups.length; i++) {
            const group = this.groups[i];
            if (group.id === id) {
                return group;
            }
        }
        return null;
    };

    LadbTabCutlist.prototype.saveUIOptionsHiddenGroupIds = function (presetValues, presetDictionary, presetSection) {
        // TODO find a best way to save hidden IDs without saving all options
        if (presetValues === undefined) presetValues = this.generateOptions
        if (presetDictionary === undefined) presetDictionary = 'cutlist_options'
        if (presetSection === undefined) presetSection = null
        rubyCallCommand('core_set_model_preset', { dictionary: presetDictionary, values: presetValues, section: presetSection });
    };

    LadbTabCutlist.prototype.toggleGroup = function ($group, doNotSaveState, doNotFlushSettings, presetValues, presetDictionary, presetSection) {
        if ($group.hasClass('no-print')) {
            this.showGroup($group, doNotSaveState, doNotFlushSettings, presetValues, presetDictionary, presetSection);
        } else {
            this.hideGroup($group, doNotSaveState, doNotFlushSettings, presetValues, presetDictionary, presetSection);
        }
    };

    LadbTabCutlist.prototype.showGroup = function ($group, doNotSaveState, doNotFlushSettings, presetValues, presetDictionary, presetSection) {
        const groupId = $group.data('group-id');
        const $btn = $('.ladb-btn-toggle-no-print', $group);
        const $i = $('i', $btn);
        const $summaryRow = $('#' + $group.attr('id') + '_summary');
        const $summaryToggleIconBtn = $('.ladb-btn-toggle-visible i', $summaryRow);

        $group.removeClass('no-print');
        $i.addClass('ladb-opencutlist-icon-eye-open');
        $i.removeClass('ladb-opencutlist-icon-eye-close');
        $summaryRow.removeClass('ladb-mute');
        $summaryToggleIconBtn.addClass('ladb-opencutlist-icon-eye-open');
        $summaryToggleIconBtn.removeClass('ladb-opencutlist-icon-eye-close');

        if (doNotSaveState === undefined || !doNotSaveState) {
            if (presetValues === undefined) presetValues = this.generateOptions;
            const idx = presetValues.hidden_group_ids.indexOf(groupId);
            if (idx !== -1) {
                presetValues.hidden_group_ids.splice(idx, 1);
                if (doNotFlushSettings === undefined || !doNotFlushSettings) {
                    this.saveUIOptionsHiddenGroupIds(presetValues, presetDictionary, presetSection);
                }
            }
        }

    };

    LadbTabCutlist.prototype.hideGroup = function ($group, doNotSaveState, doNotFlushSettings, presetValues, presetDictionary, presetSection) {
        const groupId = $group.data('group-id');
        const $btn = $('.ladb-btn-toggle-no-print', $group);
        const $i = $('i', $btn);
        const $summaryRow = $('#' + $group.attr('id') + '_summary');
        const $summaryToggleIconBtn = $('.ladb-btn-toggle-visible i', $summaryRow);

        $group.addClass('no-print');
        $i.removeClass('ladb-opencutlist-icon-eye-open');
        $i.addClass('ladb-opencutlist-icon-eye-close');
        $summaryRow.addClass('ladb-mute');
        $summaryToggleIconBtn.removeClass('ladb-opencutlist-icon-eye-open');
        $summaryToggleIconBtn.addClass('ladb-opencutlist-icon-eye-close');

        if (doNotSaveState === undefined || !doNotSaveState) {
            if (presetValues === undefined) presetValues = this.generateOptions;
            const idx = presetValues.hidden_group_ids.indexOf(groupId);
            if (idx === -1) {
                presetValues.hidden_group_ids.push(groupId);
                if (doNotFlushSettings === undefined || !doNotFlushSettings) {
                    this.saveUIOptionsHiddenGroupIds(presetValues, presetDictionary, presetSection);
                }
            }
        }

    };

    LadbTabCutlist.prototype.showAllGroups = function ($slide, doNotFlushSettings, presetValues, presetDictionary, presetSection) {
        const that = this;
        $('.ladb-cutlist-group', $slide === undefined ? this.$page : $slide).each(function () {
            that.showGroup($(this), false,true, presetValues, presetDictionary, presetSection);
        }).promise().done( function (){
            if (!doNotFlushSettings) {
                that.saveUIOptionsHiddenGroupIds(presetValues, presetDictionary, presetSection);
            }
        });
    };

    LadbTabCutlist.prototype.hideAllGroups = function (exceptedGroupId, $slide, doNotFlushSettings, presetValues, presetDictionary, presetSection) {
        const that = this;
        $('.ladb-cutlist-group', $slide === undefined ? this.$page : $slide).each(function () {
            const groupId = $(this).data('group-id');
            if (exceptedGroupId && groupId !== exceptedGroupId) {
                that.hideGroup($(this), false,true, presetValues, presetDictionary, presetSection);
            }
        }).promise().done( function (){
            if (!doNotFlushSettings) {
                that.saveUIOptionsHiddenGroupIds(presetValues, presetDictionary, presetSection);
            }
        });
    };

    LadbTabCutlist.prototype.cuttingdiagram1dGroup = function (groupId, forceDefaultTab, generateCallback) {
        const that = this;

        const group = this.findGroupById(groupId);
        const isPartSelection = this.selectionGroupId === groupId && this.selectionPartIds.length > 0;

        // Retrieve cutting diagram options
        rubyCallCommand('core_get_model_preset', { dictionary: 'cutlist_cuttingdiagram1d_options', section: groupId }, function (response) {

            const cuttingdiagram1dOptions = response.preset;

            rubyCallCommand('materials_get_attributes_command', { name: group.material_name }, function (response) {

                const $modal = that.appendModalInside('ladb_cutlist_modal_cuttingdiagram_1d', 'tabs/cutlist/_modal-cuttingdiagram-1d.twig', {
                    material_attributes: response,
                    group: group,
                    isPartSelection: isPartSelection,
                    tab: forceDefaultTab || that.lastCuttingdiagram1dOptionsTab == null ? 'material' : that.lastCuttingdiagram1dOptionsTab
                });

                // Fetch UI elements
                const $tabs = $('a[data-toggle="tab"]', $modal);
                const $widgetPreset = $('.ladb-widget-preset', $modal);
                const $inputStdBar = $('#ladb_select_std_bar', $modal);
                const $inputScrapBarLengths = $('#ladb_input_scrap_bar_lengths', $modal);
                const $inputSawKerf = $('#ladb_input_saw_kerf', $modal);
                const $inputTrimming = $('#ladb_input_trimming', $modal);
                const $selectBarFolding = $('#ladb_select_bar_folding', $modal);
                const $selectHidePartList = $('#ladb_select_hide_part_list', $modal);
                const $selectUseNames = $('#ladb_select_use_names', $modal);
                const $selectFullWidthDiagram = $('#ladb_select_full_width_diagram', $modal);
                const $selectHideCross = $('#ladb_select_hide_cross', $modal);
                const $selectOriginCorner = $('#ladb_select_origin_corner', $modal);
                const $inputWrapLength = $('#ladb_input_wrap_length', $modal);
                const $selectPartDrawingType = $('#ladb_select_part_drawing_type', $modal);
                const $btnEditMaterial = $('#ladb_btn_edit_material', $modal);
                const $btnGenerate = $('#ladb_btn_generate', $modal);

                const fnFetchOptions = function (options) {
                    options.std_bar = $inputStdBar.val();
                    options.scrap_bar_lengths = $inputScrapBarLengths.ladbTextinputTokenfield('getValidTokensList');
                    options.saw_kerf = $inputSawKerf.val();
                    options.trimming = $inputTrimming.val();
                    options.bar_folding = $selectBarFolding.val() === '1';
                    options.hide_part_list = $selectHidePartList.val() === '1';
                    options.use_names = $selectUseNames.val() === '1';
                    options.full_width_diagram = $selectFullWidthDiagram.val() === '1';
                    options.hide_cross = $selectHideCross.val() === '1';
                    options.origin_corner = that.toInt($selectOriginCorner.val());
                    options.wrap_length = $inputWrapLength.val();
                    options.part_drawing_type = that.toInt($selectPartDrawingType.val());
                }
                const fnFillInputs = function (options) {
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
                const fnEditMaterial = function (options) {

                    // Hide modal
                    $modal.modal('hide');

                    // Edit material and focus std_sizes input field
                    that.dialog.executeCommandOnTab('materials', 'edit_material', $.extend({
                        materialId: group.material_id,
                        propertiesTab: 'cut_options'
                    }, options));

                };

                $widgetPreset.ladbWidgetPreset({
                    dialog: that.dialog,
                    dictionary: 'cutlist_cuttingdiagram1d_options',
                    fnFetchOptions: fnFetchOptions,
                    fnFillInputs: fnFillInputs
                });
                if (cuttingdiagram1dOptions.std_bar) {
                    const defaultValue = $inputStdBar.val();
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
                    const value = $inputStdBar.val();
                    if (value === 'add') {
                        fnEditMaterial({
                            callback: function ($editMaterialModal) {
                                $('#ladb_materials_input_std_lengths', $editMaterialModal).siblings('.token-input').focus();
                            }
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

                        const fnAdvance = function () {
                            window.requestAnimationFrame(function () {
                                rubyCallCommand('cutlist_group_cuttingdiagram1d_advance', null, function (response) {

                                    const barCount = response.bars.length;

                                    if (response.errors && response.errors.length > 0 || response.bars && response.bars.length > 0) {

                                        const $slide = that.pushNewSlide('ladb_cutlist_slide_cuttingdiagram_1d', 'tabs/cutlist/_slide-cuttingdiagram-1d.twig', $.extend({
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
                                        const $btnCuttingDiagram = $('#ladb_btn_cuttingdiagram', $slide);
                                        const $btnPrint = $('#ladb_btn_print', $slide);
                                        const $btnExport = $('#ladb_btn_export', $slide);
                                        const $btnLabels = $('#ladb_btn_labels', $slide);
                                        const $btnClose = $('#ladb_btn_close', $slide);

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
                                            const hiddenBarIndices = [];
                                            $('.ladb-cutlist-cuttingdiagram-group', $slide).each(function () {
                                                if ($(this).hasClass('no-print')) {
                                                    hiddenBarIndices.push($(this).data('bar-index'));
                                                }
                                            });
                                            const isBarSelection = hiddenBarIndices.length > 0

                                            // Retrieve cutting diagram options
                                            rubyCallCommand('core_get_model_preset', { dictionary: 'cutlist_cuttingdiagram1d_write_options', section: groupId }, function (response) {

                                                const writeOptions = response.preset;

                                                const $modal = that.appendModalInside('ladb_cutlist_modal_cuttingdiagram_1d_export', 'tabs/cutlist/_modal-cuttingdiagram-1d-write.twig', {
                                                    group: group,
                                                    isBarSelection: isBarSelection,
                                                });

                                                // Fetch UI elements
                                                const $widgetPreset = $('.ladb-widget-preset', $modal);
                                                const $selectFileFormat = $('#ladb_select_file_format', $modal);
                                                const $formGroupDxfStructure = $('#ladb_form_group_dxf_structure', $modal);
                                                const $selectDxfStructure = $('#ladb_select_dxf_structure', $modal);
                                                const $selectUnit = $('#ladb_select_unit', $modal);
                                                const $selectSmoothing = $('#ladb_select_smoothing', $modal);
                                                const $selectMergeHoles = $('#ladb_select_merge_holes', $modal);
                                                const $selectIncludePaths = $('#ladb_select_include_paths', $modal);
                                                const $inputBarHidden = $('#ladb_input_bar_hidden', $modal);
                                                const $inputBarStrokeColor = $('#ladb_input_bar_stroke_color', $modal);
                                                const $inputBarFillColor = $('#ladb_input_bar_fill_color', $modal);
                                                const $inputPartsHidden = $('#ladb_input_parts_hidden', $modal);
                                                const $inputPartsStrokeColor = $('#ladb_input_parts_stroke_color', $modal);
                                                const $inputPartsFillColor = $('#ladb_input_parts_fill_color', $modal);
                                                const $formGroupPartsHoles = $('#ladb_form_group_parts_holes', $modal);
                                                const $inputPartsHolesStrokeColor = $('#ladb_input_parts_holes_stroke_color', $modal);
                                                const $inputPartsHolesFillColor = $('#ladb_input_parts_holes_fill_color', $modal);
                                                const $formGroupPartsPaths = $('#ladb_form_group_parts_paths', $modal);
                                                const $inputPartsPathsStrokeColor = $('#ladb_input_parts_paths_stroke_color', $modal);
                                                const $inputPartsPathsFillColor = $('#ladb_input_parts_paths_fill_color', $modal);
                                                const $formGroupTexts = $('#ladb_form_group_texts', $modal);
                                                const $inputTextsHidden = $('#ladb_input_texts_hidden', $modal);
                                                const $inputTextsColor = $('#ladb_input_texts_color', $modal);
                                                const $inputLeftoversHidden = $('#ladb_input_leftovers_hidden', $modal);
                                                const $inputLeftoversStrokeColor = $('#ladb_input_leftovers_stroke_color', $modal);
                                                const $inputLeftoversFillColor = $('#ladb_input_leftovers_fill_color', $modal);
                                                const $inputCutsHidden = $('#ladb_input_cuts_hidden', $modal);
                                                const $inputCutsColor = $('#ladb_input_cuts_color', $modal);
                                                const $btnExport = $('#ladb_btn_export', $modal);

                                                const fnFetchOptions = function (options) {
                                                    options.file_format = $selectFileFormat.val();
                                                    options.dxf_structure = that.toInt($selectDxfStructure.val());
                                                    options.unit = that.toInt($selectUnit.val());
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
                                                    options.parts_paths_fill_color = $inputPartsPathsFillColor.ladbTextinputColor('val');
                                                    options.texts_hidden = !$inputTextsHidden.is(':checked');
                                                    options.texts_color = $inputTextsColor.ladbTextinputColor('val');
                                                    options.leftovers_hidden = !$inputLeftoversHidden.is(':checked');
                                                    options.leftovers_stroke_color = $inputLeftoversStrokeColor.ladbTextinputColor('val');
                                                    options.leftovers_fill_color = $inputLeftoversFillColor.ladbTextinputColor('val');
                                                    options.cuts_hidden = !$inputCutsHidden.is(':checked');
                                                    options.cuts_color = $inputCutsColor.ladbTextinputColor('val');
                                                };
                                                const fnFillInputs = function (options) {
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
                                                    $inputPartsPathsFillColor.ladbTextinputColor('val', options.parts_paths_fill_color);
                                                    $inputTextsHidden.prop('checked', !options.texts_hidden);
                                                    $inputTextsColor.ladbTextinputColor('val', options.texts_color);
                                                    $inputLeftoversHidden.prop('checked', !options.leftovers_hidden);
                                                    $inputLeftoversStrokeColor.ladbTextinputColor('val', options.leftovers_stroke_color);
                                                    $inputLeftoversFillColor.ladbTextinputColor('val', options.leftovers_fill_color);
                                                    $inputCutsHidden.prop('checked', !options.cuts_hidden);
                                                    $inputCutsColor.ladbTextinputColor('val', options.cuts_color);
                                                    fnUpdateFieldsVisibility();
                                                };
                                                const fnUpdateFieldsVisibility = function () {
                                                    const isDxf = $selectFileFormat.val() === 'dxf';
                                                    const isMergeHoles = $selectMergeHoles.val() === '1';
                                                    const isIncludePaths = $selectIncludePaths.val() === '1';
                                                    const isBarHidden = !$inputBarHidden.is(':checked');
                                                    const isPartsHidden = !$inputPartsHidden.is(':checked');
                                                    const isTextHidden = !$inputTextsHidden.is(':checked');
                                                    const isLeftoversHidden = !$inputLeftoversHidden.is(':checked');
                                                    const isCutsHidden = !$inputCutsHidden.is(':checked');
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
                                                    $inputPartsPathsFillColor.ladbTextinputColor(!isIncludePaths ? 'disable' : 'enable');
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
                                                        const fileCount = barCount - hiddenBarIndices.length;
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
                                                $inputPartsPathsFillColor.ladbTextinputColor(TEXTINPUT_COLOR_OPTIONS);
                                                $inputTextsColor.ladbTextinputColor(TEXTINPUT_COLOR_OPTIONS);
                                                $inputLeftoversStrokeColor.ladbTextinputColor(TEXTINPUT_COLOR_OPTIONS);
                                                $inputLeftoversFillColor.ladbTextinputColor(TEXTINPUT_COLOR_OPTIONS);
                                                $inputCutsColor.ladbTextinputColor(TEXTINPUT_COLOR_OPTIONS);

                                                fnFillInputs(writeOptions);

                                                // Bind inputs
                                                $inputBarHidden.on('change', fnUpdateFieldsVisibility);
                                                $inputPartsHidden.on('change', fnUpdateFieldsVisibility);
                                                $inputTextsHidden.on('change', fnUpdateFieldsVisibility);
                                                $inputLeftoversHidden.on('change', fnUpdateFieldsVisibility);
                                                $inputCutsHidden.on('change', fnUpdateFieldsVisibility);

                                                // Bind buttons
                                                $btnExport.on('click', function () {

                                                    // Fetch options
                                                    fnFetchOptions(writeOptions);

                                                    // Store options
                                                    rubyCallCommand('core_set_model_preset', { dictionary: 'cutlist_cuttingdiagram1d_write_options', values: writeOptions, section: groupId });

                                                    rubyCallCommand('cutlist_cuttingdiagram1d_write', $.extend({
                                                        hidden_bar_indices: hiddenBarIndices,
                                                        part_drawing_type: cuttingdiagram1dOptions.part_drawing_type,
                                                        use_names: cuttingdiagram1dOptions.use_names,
                                                    }, writeOptions), function (response) {

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
                                                for (let i = 0 ; i < this.count; i++) {
                                                    barIndex++;
                                                    $.each(this.parts, function () {
                                                        if (!binDefs[this.id]) {
                                                            binDefs[this.id] = [];
                                                        }
                                                        binDefs[this.id].push(barIndex);
                                                    });
                                                }
                                            });

                                            that.labelsGroupParts(groupId, binDefs);
                                        });
                                        $btnClose.on('click', function () {
                                            that.popSlide();
                                        });
                                        $('.ladb-btn-setup-model-units', $slide).on('click', function () {
                                            $(this).blur();
                                            that.dialog.executeCommandOnTab('settings', 'highlight_panel', { panel:'model' });
                                        });
                                        $('.ladb-btn-toggle-no-print', $slide).on('click', function () {
                                            const $group = $(this).parents('.ladb-cutlist-group');
                                            if ($group.hasClass('no-print')) {
                                                that.showGroup($group, true);
                                            } else {
                                                that.hideGroup($group, true);
                                            }
                                            $(this).blur();
                                        });
                                        $('.ladb-btn-scrollto-prev-group', $slide).on('click', function () {
                                            const $group = $(this).parents('.ladb-cutlist-group');
                                            const groupId = $group.data('bar-index');
                                            const $target = $('.ladb-cutlist-cuttingdiagram-group[data-bar-index=' + (parseInt(groupId) - 1) + ']');
                                            $slide.animate({scrollTop: $slide.scrollTop() + $target.position().top - $('.ladb-header', $slide).outerHeight(true) - 20}, 200).promise().then(function () {
                                                $target.effect('highlight', {}, 1500);
                                            });
                                            $(this).blur();
                                            return false;
                                        });
                                        $('.ladb-btn-scrollto-next-group', $slide).on('click', function () {
                                            const $group = $(this).parents('.ladb-cutlist-group');
                                            const groupId = $group.data('bar-index');
                                            const $target = $('.ladb-cutlist-cuttingdiagram-group[data-bar-index=' + (parseInt(groupId) + 1) + ']');
                                            $slide.animate({scrollTop: $slide.scrollTop() + $target.position().top - $('.ladb-header', $slide).outerHeight(true) - 20}, 200).promise().then(function () {
                                                $target.effect('highlight', {}, 1500);
                                            });
                                            $(this).blur();
                                            return false;
                                        });
                                        $('a.ladb-btn-highlight-part', $slide).on('click', function () {
                                            $(this).blur();
                                            const $part = $(this).parents('.ladb-cutlist-row');
                                            const partId = $part.data('part-id');
                                            that.highlightPart(partId);
                                            return false;
                                        });
                                        $('a.ladb-btn-scrollto', $slide).on('click', function () {
                                            const $target = $($(this).attr('href'));
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
                                            const partId = $(this).data('part-id');
                                            that.highlightPart(partId);
                                            $(this).blur();
                                            return false;
                                        });

                                        that.dialog.finishProgress();

                                    } else {

                                        window.requestAnimationFrame(function () {
                                            that.dialog.incProgress(1);
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
        const that = this;

        const group = this.findGroupById(groupId);
        const isPartSelection = this.selectionGroupId === groupId && this.selectionPartIds.length > 0;

        // Retrieve cutting diagram options
        rubyCallCommand('core_get_model_preset', { dictionary: 'cutlist_cuttingdiagram2d_options', section: groupId }, function (response) {

            const cuttingdiagram2dOptions = response.preset;

            rubyCallCommand('materials_get_attributes_command', { name: group.material_name }, function (response) {

                const $modal = that.appendModalInside('ladb_cutlist_modal_cuttingdiagram_2d', 'tabs/cutlist/_modal-cuttingdiagram-2d.twig', {
                    material_attributes: response,
                    group: group,
                    isPartSelection: isPartSelection,
                    tab: forceDefaultTab || that.lastCuttingdiagram2dOptionsTab == null ? 'material' : that.lastCuttingdiagram2dOptionsTab
                });

                // Fetch UI elements
                const $tabs = $('a[data-toggle="tab"]', $modal);
                const $widgetPreset = $('.ladb-widget-preset', $modal);
                const $inputStdSheet = $('#ladb_select_std_sheet', $modal);
                const $inputScrapSheetSizes = $('#ladb_input_scrap_sheet_sizes', $modal);
                const $inputSawKerf = $('#ladb_input_saw_kerf', $modal);
                const $inputTrimming = $('#ladb_input_trimming', $modal);
                const $selectOptimization = $('#ladb_select_optimization', $modal);
                const $selectStacking = $('#ladb_select_stacking', $modal);
                const $inputKeepLength = $('#ladb_input_keep_length', $modal);
                const $inputKeepWidth = $('#ladb_input_keep_width', $modal);
                const $selectSheetFolding = $('#ladb_select_sheet_folding', $modal);
                const $selectHidePartList = $('#ladb_select_hide_part_list', $modal);
                const $selectUseNames = $('#ladb_select_use_names', $modal);
                const $selectFullWidthDiagram = $('#ladb_select_full_width_diagram', $modal);
                const $selectHideCross = $('#ladb_select_hide_cross', $modal);
                const $selectOriginCorner = $('#ladb_select_origin_corner', $modal);
                const $selectHighlightPrimaryCuts = $('#ladb_select_highlight_primary_cuts', $modal);
                const $selectHideEdgesPreview = $('#ladb_select_hide_edges_preview', $modal);
                const $selectPartDrawingType = $('#ladb_select_part_drawing_type', $modal);
                const $btnEditMaterial = $('#ladb_btn_edit_material', $modal);
                const $btnGenerate = $('#ladb_btn_generate', $modal);

                const fnFetchOptions = function (options) {
                    options.std_sheet = $inputStdSheet.val();
                    options.scrap_sheet_sizes = $inputScrapSheetSizes.ladbTextinputTokenfield('getValidTokensList');
                    options.saw_kerf = $inputSawKerf.val();
                    options.trimming = $inputTrimming.val();
                    options.optimization = that.toInt($selectOptimization.val());
                    options.stacking = that.toInt($selectStacking.val());
                    options.keep_length = $inputKeepLength.val();
                    options.keep_width = $inputKeepWidth.val();
                    options.sheet_folding = $selectSheetFolding.val() === '1';
                    options.hide_part_list = $selectHidePartList.val() === '1';
                    options.use_names = $selectUseNames.val() === '1';
                    options.full_width_diagram = $selectFullWidthDiagram.val() === '1';
                    options.hide_cross = $selectHideCross.val() === '1';
                    options.origin_corner = that.toInt($selectOriginCorner.val());
                    options.highlight_primary_cuts = $selectHighlightPrimaryCuts.val() === '1';
                    options.hide_edges_preview = $selectHideEdgesPreview.val() === '1';
                    options.part_drawing_type = that.toInt($selectPartDrawingType.val());
                }
                const fnFillInputs = function (options) {
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
                const fnEditMaterial = function (options) {

                    // Hide modal
                    $modal.modal('hide');

                    // Edit material and focus std_sizes input field
                    that.dialog.executeCommandOnTab('materials', 'edit_material', $.extend({
                        materialId: group.material_id,
                        propertiesTab: 'cut_options'
                    }, options));

                };

                $widgetPreset.ladbWidgetPreset({
                    dialog: that.dialog,
                    dictionary: 'cutlist_cuttingdiagram2d_options',
                    fnFetchOptions: fnFetchOptions,
                    fnFillInputs: fnFillInputs
                });
                if (cuttingdiagram2dOptions.std_sheet) {
                    const defaultValue = $inputStdSheet.val();
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
                    const value = $inputStdSheet.val();
                    if (value === 'add') {
                        fnEditMaterial({
                            callback: function ($editMaterialModal) {
                                $('#ladb_materials_input_std_sizes', $editMaterialModal).siblings('.token-input').focus();
                            }
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

                        const fnAdvance = function () {
                            window.requestAnimationFrame(function () {
                                rubyCallCommand('cutlist_group_cuttingdiagram2d_advance', null, function (response) {

                                    if (response.errors && response.errors.length > 0 || response.sheets && response.sheets.length > 0) {

                                        const sheetCount = response.sheets.length;

                                        const $slide = that.pushNewSlide('ladb_cutlist_slide_cuttingdiagram_2d', 'tabs/cutlist/_slide-cuttingdiagram-2d.twig', $.extend({
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
                                        const $btnCuttingDiagram = $('#ladb_btn_cuttingdiagram', $slide);
                                        const $btnPrint = $('#ladb_btn_print', $slide);
                                        const $btnExport = $('#ladb_btn_export', $slide);
                                        const $btnLabels = $('#ladb_btn_labels', $slide);
                                        const $btnClose = $('#ladb_btn_close', $slide);

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
                                            const hiddenSheetIndices = [];
                                            $('.ladb-cutlist-cuttingdiagram-group', $slide).each(function () {
                                                if ($(this).hasClass('no-print')) {
                                                    hiddenSheetIndices.push($(this).data('sheet-index'));
                                                }
                                            });
                                            const isSheetSelection = hiddenSheetIndices.length > 0

                                            // Retrieve cutting diagram options
                                            rubyCallCommand('core_get_model_preset', { dictionary: 'cutlist_cuttingdiagram2d_write_options', section: groupId }, function (response) {

                                                const writeOptions = response.preset;

                                                const $modal = that.appendModalInside('ladb_cutlist_modal_cuttingdiagram_2d_export', 'tabs/cutlist/_modal-cuttingdiagram-2d-write.twig', {
                                                    group: group,
                                                    isSheetSelection: isSheetSelection,
                                                });

                                                // Fetch UI elements
                                                const $widgetPreset = $('.ladb-widget-preset', $modal);
                                                const $selectFileFormat = $('#ladb_select_file_format', $modal);
                                                const $formGroupDxfStructure = $('#ladb_form_group_dxf_structure', $modal);
                                                const $selectDxfStructure = $('#ladb_select_dxf_structure', $modal);
                                                const $selectUnit = $('#ladb_select_unit', $modal);
                                                const $selectSmoothing = $('#ladb_select_smoothing', $modal);
                                                const $selectMergeHoles = $('#ladb_select_merge_holes', $modal);
                                                const $selectIncludePaths = $('#ladb_select_include_paths', $modal);
                                                const $inputSheetHidden = $('#ladb_input_sheet_hidden', $modal);
                                                const $inputSheetStrokeColor = $('#ladb_input_sheet_stroke_color', $modal);
                                                const $inputSheetFillColor = $('#ladb_input_sheet_fill_color', $modal);
                                                const $inputPartsHidden = $('#ladb_input_parts_hidden', $modal);
                                                const $inputPartsStrokeColor = $('#ladb_input_parts_stroke_color', $modal);
                                                const $inputPartsFillColor = $('#ladb_input_parts_fill_color', $modal);
                                                const $formGroupPartsHoles = $('#ladb_form_group_parts_holes', $modal);
                                                const $inputPartsHolesStrokeColor = $('#ladb_input_parts_holes_stroke_color', $modal);
                                                const $inputPartsHolesFillColor = $('#ladb_input_parts_holes_fill_color', $modal);
                                                const $formGroupPartsPaths = $('#ladb_form_group_parts_paths', $modal);
                                                const $inputPartsPathsStrokeColor = $('#ladb_input_parts_paths_stroke_color', $modal);
                                                const $inputPartsPathsFillColor = $('#ladb_input_parts_paths_fill_color', $modal);
                                                const $formGroupTexts = $('#ladb_form_group_texts', $modal);
                                                const $inputTextsHidden = $('#ladb_input_texts_hidden', $modal);
                                                const $inputTextsColor = $('#ladb_input_texts_color', $modal);
                                                const $inputLeftoversHidden = $('#ladb_input_leftovers_hidden', $modal);
                                                const $inputLeftoversStrokeColor = $('#ladb_input_leftovers_stroke_color', $modal);
                                                const $inputLeftoversFillColor = $('#ladb_input_leftovers_fill_color', $modal);
                                                const $inputCutsHidden = $('#ladb_input_cuts_hidden', $modal);
                                                const $inputCutsColor = $('#ladb_input_cuts_color', $modal);
                                                const $btnExport = $('#ladb_btn_export', $modal);

                                                const fnFetchOptions = function (options) {
                                                    options.file_format = $selectFileFormat.val();
                                                    options.dxf_structure = that.toInt($selectDxfStructure.val());
                                                    options.unit = that.toInt($selectUnit.val());
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
                                                    options.parts_paths_fill_color = $inputPartsPathsFillColor.ladbTextinputColor('val');
                                                    options.texts_hidden = !$inputTextsHidden.is(':checked');
                                                    options.texts_color = $inputTextsColor.ladbTextinputColor('val');
                                                    options.leftovers_hidden = !$inputLeftoversHidden.is(':checked');
                                                    options.leftovers_stroke_color = $inputLeftoversStrokeColor.ladbTextinputColor('val');
                                                    options.leftovers_fill_color = $inputLeftoversFillColor.ladbTextinputColor('val');
                                                    options.cuts_hidden = !$inputCutsHidden.is(':checked');
                                                    options.cuts_color = $inputCutsColor.ladbTextinputColor('val');
                                                };
                                                const fnFillInputs = function (options) {
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
                                                    $inputPartsPathsFillColor.ladbTextinputColor('val', options.parts_paths_fill_color);
                                                    $inputTextsHidden.prop('checked', !options.texts_hidden);
                                                    $inputTextsColor.ladbTextinputColor('val', options.texts_color);
                                                    $inputLeftoversHidden.prop('checked', !options.leftovers_hidden);
                                                    $inputLeftoversStrokeColor.ladbTextinputColor('val', options.leftovers_stroke_color);
                                                    $inputLeftoversFillColor.ladbTextinputColor('val', options.leftovers_fill_color);
                                                    $inputCutsHidden.prop('checked', !options.cuts_hidden);
                                                    $inputCutsColor.ladbTextinputColor('val', options.cuts_color);
                                                    fnUpdateFieldsVisibility();
                                                };
                                                const fnUpdateFieldsVisibility = function () {
                                                    const isDxf = $selectFileFormat.val() === 'dxf';
                                                    const isMergeHoles = $selectMergeHoles.val() === '1';
                                                    const isIncludePaths = $selectIncludePaths.val() === '1';
                                                    const isSheetHidden = !$inputSheetHidden.is(':checked');
                                                    const isPartsHidden = !$inputPartsHidden.is(':checked');
                                                    const isTextsHidden = !$inputTextsHidden.is(':checked');
                                                    const isLeftoversHidden = !$inputLeftoversHidden.is(':checked');
                                                    const isCutsHidden = !$inputCutsHidden.is(':checked');
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
                                                    $inputPartsPathsFillColor.ladbTextinputColor(!isIncludePaths ? 'disable' : 'enable');
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
                                                        const fileCount = sheetCount - hiddenSheetIndices.length;
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
                                                $inputPartsPathsFillColor.ladbTextinputColor(TEXTINPUT_COLOR_OPTIONS);
                                                $inputTextsColor.ladbTextinputColor(TEXTINPUT_COLOR_OPTIONS);
                                                $inputLeftoversStrokeColor.ladbTextinputColor(TEXTINPUT_COLOR_OPTIONS);
                                                $inputLeftoversFillColor.ladbTextinputColor(TEXTINPUT_COLOR_OPTIONS);
                                                $inputCutsColor.ladbTextinputColor(TEXTINPUT_COLOR_OPTIONS);

                                                fnFillInputs(writeOptions);

                                                // Bind inputs
                                                $inputSheetHidden.on('change', fnUpdateFieldsVisibility);
                                                $inputPartsHidden.on('change', fnUpdateFieldsVisibility);
                                                $inputTextsHidden.on('change', fnUpdateFieldsVisibility);
                                                $inputLeftoversHidden.on('change', fnUpdateFieldsVisibility);
                                                $inputCutsHidden.on('change', fnUpdateFieldsVisibility);

                                                // Bind buttons
                                                $btnExport.on('click', function () {

                                                    // Fetch options
                                                    fnFetchOptions(writeOptions);

                                                    // Store options
                                                    rubyCallCommand('core_set_model_preset', { dictionary: 'cutlist_cuttingdiagram2d_write_options', values: writeOptions, section: groupId });

                                                    rubyCallCommand('cutlist_cuttingdiagram2d_write', $.extend({
                                                        hidden_sheet_indices: hiddenSheetIndices,
                                                        part_drawing_type: cuttingdiagram2dOptions.part_drawing_type,
                                                        use_names: cuttingdiagram2dOptions.use_names,
                                                    }, writeOptions), function (response) {

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
                                            let binIndex = 0;
                                            $.each(response.sheets, function () {
                                                for (let i = 0 ; i < this.count; i++) {
                                                    binIndex++;
                                                    $.each(this.parts, function () {
                                                        if (!binDefs[this.id]) {
                                                            binDefs[this.id] = [];
                                                        }
                                                        binDefs[this.id].push(binIndex);
                                                    });
                                                }
                                            });

                                            that.labelsGroupParts(groupId, binDefs);
                                        });
                                        $btnClose.on('click', function () {
                                            that.popSlide();
                                        });
                                        $('.ladb-btn-setup-model-units', $slide).on('click', function() {
                                            $(this).blur();
                                            that.dialog.executeCommandOnTab('settings', 'highlight_panel', { panel:'model' });
                                        });
                                        $('.ladb-btn-toggle-no-print', $slide).on('click', function () {
                                            const $group = $(this).parents('.ladb-cutlist-group');
                                            if ($group.hasClass('no-print')) {
                                                that.showGroup($group, true);
                                            } else {
                                                that.hideGroup($group, true);
                                            }
                                            $(this).blur();
                                        });
                                        $('.ladb-btn-scrollto-prev-group', $slide).on('click', function () {
                                            const $group = $(this).parents('.ladb-cutlist-group');
                                            const groupId = $group.data('sheet-index');
                                            const $target = $('.ladb-cutlist-cuttingdiagram-group[data-sheet-index=' + (parseInt(groupId) - 1) + ']');
                                            that.scrollSlideToTarget($slide, $target, true, true);
                                            $(this).blur();
                                            return false;
                                        });
                                        $('.ladb-btn-scrollto-next-group', $slide).on('click', function () {
                                            const $group = $(this).parents('.ladb-cutlist-group');
                                            const groupId = $group.data('sheet-index');
                                            const $target = $('.ladb-cutlist-cuttingdiagram-group[data-sheet-index=' + (parseInt(groupId) + 1) + ']');
                                            that.scrollSlideToTarget($slide, $target, true, true);
                                            $(this).blur();
                                            return false;
                                        });
                                        $('a.ladb-btn-highlight-part', $slide).on('click', function () {
                                            $(this).blur();
                                            const $part = $(this).parents('.ladb-cutlist-row');
                                            const partId = $part.data('part-id');
                                            that.highlightPart(partId);
                                            return false;
                                        });
                                        $('a.ladb-btn-scrollto', $slide).on('click', function () {
                                            const $target = $($(this).attr('href'));
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
                                            const items = [];
                                            $.each(response.to_keep_leftovers, function (index, leftover) {
                                                items.push(leftover.length + 'x' + leftover.width + 'x' + leftover.count);
                                            });
                                            that.dialog.copyToClipboard(items.join(';'));
                                        });

                                        // SVG
                                        $('SVG .part', $slide).on('click', function () {
                                            const partId = $(this).data('part-id');
                                            that.highlightPart(partId);
                                            $(this).blur();
                                            return false;
                                        });

                                        that.dialog.finishProgress();

                                    } else {

                                        window.requestAnimationFrame(function () {
                                            that.dialog.incProgress(1);
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

    LadbTabCutlist.prototype.dimensionsHelpGroup = function (groupId) {
        const that = this;

        const group = this.findGroupById(groupId);

        rubyCallCommand('materials_get_attributes_command', { name: group.material_name }, function (response) {

            const $modal = that.appendModalInside('ladb_cutlist_modal_help', 'tabs/cutlist/_modal-dimensions-help.twig', { material_attributes: response, group: group, generateOptions: that.generateOptions });

            // Fetch UI elements
            const $btnCuttingToggle = $('#ladb_btn_cutting_toggle', $modal);
            const $btnBboxToggle = $('#ladb_btn_bbox_toggle', $modal);
            const $btnFinalToggle = $('#ladb_btn_final_toggle', $modal);

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
        const that = this;

        rubyCallCommand('cutlist_numbers_save', params ? params : {}, function (response) {

            if (response.errors) {
                that.dialog.notifyErrors(response.errors);
            } else {
                that.generateCutlist(callback);
            }

        });

    };

    LadbTabCutlist.prototype.numbersReset = function (params, callback) {
        const that = this;

        rubyCallCommand('cutlist_numbers_reset', params ? params : {}, function (response) {

            if (response.errors) {
                that.dialog.notifyErrors(response.errors);
            } else {
                that.generateCutlist(callback);
            }

        });

    };

    // Options /////

    LadbTabCutlist.prototype.loadOptions = function (callback) {
        const that = this;

        rubyCallCommand('core_get_model_preset', { dictionary: 'cutlist_options' }, function (response) {

            that.generateOptions = response.preset;

            // Callback
            if (typeof callback == 'function') {
                callback();
            }

        });

    };

    LadbTabCutlist.prototype.editOptions = function (tab) {
        const that = this;

        if (tab === undefined) {
            tab = this.lastOptionsTab;
        }
        if (tab === null || tab.length === 0) {
            tab = 'general';
        }
        this.lastOptionsTab = tab;

        const $modal = that.appendModalInside('ladb_cutlist_modal_options', 'tabs/cutlist/_modal-options.twig', {
            tab: tab
        });

        // Fetch UI elements
        const $tabs = $('a[data-toggle="tab"]', $modal);
        const $widgetPreset = $('.ladb-widget-preset', $modal);
        const $inputAutoOrient = $('#ladb_input_auto_orient', $modal);
        const $inputFlippedDetection = $('#ladb_input_flipped_detection', $modal);
        const $inputSmartMaterial = $('#ladb_input_smart_material', $modal);
        const $inputDynamicAttributesName = $('#ladb_input_dynamic_attributes_name', $modal);
        const $inputPartNumberWithLetters = $('#ladb_input_part_number_with_letters', $modal);
        const $inputPartNumberSequenceByGroup = $('#ladb_input_part_number_sequence_by_group', $modal);
        const $inputPartFolding = $('#ladb_input_part_folding', $modal);
        const $inputHideInstanceNames = $('#ladb_input_hide_entity_names', $modal);
        const $inputHideDescriptions = $('#ladb_input_hide_descriptions', $modal);
        const $inputHideTags = $('#ladb_input_hide_tags', $modal);
        const $inputHideCuttingDimensions = $('#ladb_input_hide_cutting_dimensions', $modal);
        const $inputHideBBoxDimensions = $('#ladb_input_hide_bbox_dimensions', $modal);
        const $inputHideFinalAreas = $('#ladb_input_hide_final_areas', $modal);
        const $inputHideEdges = $('#ladb_input_hide_edges', $modal);
        const $inputHideFaces = $('#ladb_input_hide_faces', $modal);
        const $inputHideMaterialColors = $('#ladb_input_hide_material_colors', $modal);
        const $inputMinimizeOnHighlight = $('#ladb_input_minimize_on_highlight', $modal);
        const $sortableGroupOrderStrategy = $('#ladb_sortable_group_order_strategy', $modal);
        const $sortablePartOrderStrategy = $('#ladb_sortable_part_order_strategy', $modal);
        const $inputTags = $('#ladb_input_tags', $modal);
        const $sortableDimensionColumnOrderStrategy = $('#ladb_sortable_dimension_column_order_strategy', $modal);
        const $btnSetupModelUnits = $('#ladb_cutlist_options_setup_model_units', $modal);
        const $btnUpdate = $('#ladb_cutlist_options_update', $modal);

        // Define useful functions
        const fnFetchOptions = function (options) {
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

            let properties = [];
            $sortableGroupOrderStrategy.children('li').each(function () {
                properties.push($(this).data('property'));
            });
            options.group_order_strategy = properties.join('>');

            properties = [];
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
        const fnFillInputs = function (options) {

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

            let properties, property, i;

            // Group order sortables

            properties = options.group_order_strategy.split('>');
            $sortableGroupOrderStrategy.empty();
            for (i = 0; i < properties.length; i++) {
                property = properties[i];
                $sortableGroupOrderStrategy.append(Twig.twig({ref: "tabs/cutlist/_option-part-order-strategy-property.twig"}).render({
                    order: property.startsWith('-') ? '-' : '',
                    property: property.startsWith('-') ? property.substring(1) : property
                }));
            }
            $sortableGroupOrderStrategy.find('a').on('click', function () {
                const $item = $(this).parent().parent();
                const $icon = $('i', $(this));
                let property = $item.data('property');
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
            $sortableGroupOrderStrategy.sortable(SORTABLE_OPTIONS);

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
                const $item = $(this).parent().parent();
                const $icon = $('i', $(this));
                let property = $item.data('property');
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

            const that = this;

            // Set tab as obsolete
            this.setObsolete(true);

            const $modal = this.appendModalInside('ladb_cutlist_modal_obsolete', 'tabs/cutlist/_modal-obsolete.twig', {
                messageI18nKey: messageI18nKey
            });

            // Fetch UI elements
            const $btnGenerate = $('#ladb_cutlist_obsolete_generate', $modal);

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

        const that = this;

        this.registerCommand('generate_cutlist', function (parameters) {
            const callback = parameters ? parameters.callback : null;
            setTimeout(function () {     // Use setTimeout to give time to UI to refresh
                that.generateCutlist(callback);
            }, 1);
        });
        this.registerCommand('edit_part', function (parameters) {
            const partId = parameters.part_id;
            const partSerializedPath = parameters.part_serialized_path;
            const tab = parameters.tab;
            const dontGenerate = parameters.dontGenerate;
            window.requestAnimationFrame(function () {
                if (dontGenerate) {
                    that.editPart(partId, partSerializedPath, tab);
                } else {
                    that.generateCutlist(function () {
                        that.editPart(partId, partSerializedPath, tab);
                    });
                }
            });
        });

    };

    LadbTabCutlist.prototype.bind = function () {
        LadbAbstractTab.prototype.bind.call(this);

        const that = this;

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
            that.exportAllParts();
            this.blur();
        });
        this.$btnLayout.on('click', function () {
            that.layoutAllParts();
            this.blur();
        });
        this.$btnEstimate.on('click', function () {
            that.estimateAllParts();
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
        this.$itemLabelsAllParts.on('click', function () {
            if (!$(this).parents('li').hasClass('disabled')) {
                that.labelsAllParts();
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
        addEventCallback([ 'on_drawing_change' ], function () {
            if (that.generateAt) {
                that.showObsolete('core.event.drawing_change');
            }
        });

    };

    LadbTabCutlist.prototype.processInitializedCallback = function (initializedCallback) {
        const that = this;

        // Load Options
        this.loadOptions(function () {
            LadbAbstractTab.prototype.processInitializedCallback.call(that, initializedCallback);
        });

    };


    // PLUGIN DEFINITION
    // =======================

    function Plugin(option, params) {
        return this.each(function () {
            const $this = $(this);
            let data = $this.data('ladb.tab.plugin');
            if (!data) {
                const options = $.extend({}, LadbTabCutlist.DEFAULTS, $this.data(), typeof option === 'object' && option);
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

    const old = $.fn.ladbTabCutlist;

    $.fn.ladbTabCutlist = Plugin;
    $.fn.ladbTabCutlist.Constructor = LadbTabCutlist;


    // NO CONFLICT
    // =================

    $.fn.ladbTabCutlist.noConflict = function () {
        $.fn.ladbTabCutlist = old;
        return this;
    }

}(jQuery);

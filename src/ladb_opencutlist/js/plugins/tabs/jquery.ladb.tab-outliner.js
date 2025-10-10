+function ($) {
    'use strict';

    // CONSTANTS
    // ======================

    // Various Consts

    const MULTIPLE_VALUE = '-1';

    // CLASS DEFINITION
    // ======================

    const LadbTabOutliner = function (element, options, dialog) {
        LadbAbstractTab.call(this, element, options, dialog);

        this.lastOptionsTab = null;
        this.lastEditNodeTab = null;

        this.$header = $('.ladb-header', this.$element);
        this.$fileTabs = $('.ladb-file-tabs', this.$header);
        this.$btnGenerate = $('#ladb_btn_generate', this.$header);
        this.$btnOptions = $('#ladb_btn_options', this.$header);
        this.$btnSideFold = $('#ladb_btn_side_fold', this.$header);

        this.$page = $('.ladb-page', this.$element);

    };
    LadbTabOutliner.prototype = Object.create(LadbAbstractTab.prototype);

    LadbTabOutliner.DEFAULTS = {};

    // List /////

    LadbTabOutliner.prototype.generateOutliner = function (expandedNodeIds, callback) {
        const that = this;

        if (!Array.isArray(expandedNodeIds)) {
            expandedNodeIds = [];
        }

        this.rootNode = null;
        this.$page.empty();
        this.$btnGenerate.prop('disabled', true);
        this.setObsolete(false);

        window.requestAnimationFrame(function () {

            // Start progress feedback
            that.dialog.startProgress(1);

            rubyCallCommand('outliner_generate', { expanded_node_ids: expandedNodeIds }, function (response) {

                const errors = response.errors;
                const warnings = response.warnings;
                const tips = response.tips;
                const filename = response.filename;
                const modelName = response.model_name;
                const root_node = response.root_node;
                const available_materials = response.available_materials;
                const available_layers = response.available_layers;

                // Keep useful data
                that.rootNode = root_node;
                that.availableMaterials = available_materials;
                that.availableLayers = available_layers;

                // Update filename
                that.$fileTabs.empty();
                that.$fileTabs.append(Twig.twig({ ref: "tabs/outliner/_file-tab.twig" }).render({
                    filename: filename,
                    modelName: modelName
                }));

                // Update page
                that.$page.empty();
                that.$page.append(Twig.twig({ ref: "tabs/outliner/_list.twig" }).render({
                    capabilities: that.dialog.capabilities,
                    errors: errors,
                    warnings: warnings,
                    tips: tips
                }));

                that.$tbody = $('#ladb_outliner_tbody', that.$page);

                that.renderNodes();

                const $toggleHiddenBtn = $('#ladb_btn_toggle_hidden');
                const $toggleSelectAllBtn = $('#ladb_btn_toggle_select_all');

                if (that.generateOptions.show_hidden_instances) {
                    $('i', $toggleHiddenBtn).addClass('ladb-opencutlist-icon-check-box-with-check-sign');
                }

                // Bind buttons
                $toggleHiddenBtn.on('click', function () {
                    $(this).blur();

                    // Toggle hidden instances
                    that.generateOptions.show_hidden_instances = !that.generateOptions.show_hidden_instances;

                    // Store options
                    rubyCallCommand('core_set_model_preset', { dictionary: 'outliner_options', values: that.generateOptions });

                    if (that.generateOptions.show_hidden_instances) {
                        $('i', $(this)).addClass('ladb-opencutlist-icon-check-box-with-check-sign');
                    } else {
                        $('i', $(this)).removeClass('ladb-opencutlist-icon-check-box-with-check-sign');
                    }
                    that.renderNodes();
                    return false;
                });
                $toggleSelectAllBtn.on('click', function (e) {
                    $(this).blur();

                    rubyCallCommand(e.shiftKey ? 'outliner_invert_select' : 'outliner_toggle_select_all', null, function (response) {
                        if (response.errors) {
                            that.dialog.notifyErrors(response.errors);
                        }
                    });

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
                }

            });

        });

    };

    LadbTabOutliner.prototype.refreshOutliner = function () {
        const that = this;

        rubyCallCommand('outliner_refresh', {}, function (response) {

            const root_node = response.root_node;
            const available_materials = response.available_materials;
            const available_layers = response.available_layers;

            // Keep useful data
            that.rootNode = root_node;
            that.availableMaterials = available_materials;
            that.availableLayers = available_layers;

            that.renderNodes();

        });

    };

    LadbTabOutliner.prototype.renderNodes = function () {
        const that = this;

        this.$tbody.empty();

        if (this.rootNode) {

            const fnRenderNode = function (node, activeOnly) {

                if (!node.computed_visible && !that.generateOptions.show_hidden_instances) {
                    return;
                }

                const $row = $(Twig.twig({ref: "tabs/outliner/_list-row-node.twig"}).render({
                    capabilities: that.dialog.capabilities,
                    generateOptions: that.generateOptions,
                    node: node
                }));
                that.$tbody.append($row);

                let $editedRow = null;

                const fnMouseEnter = function () {
                    $row.addClass('ladb-hover');
                    if (node.selected) {
                        $row.siblings('.ladb-selected').addClass('ladb-hover');
                    }
                    if (that.dialog.capabilities.sketchup_version_number >= 2300000000) {
                        if (!node.child_active && !node.active) {
                            rubyCallCommand('outliner_highlight', {
                                ids: node.selected ? that.getSelectedNodes().map(node => node.id) : [node.id],
                                highlighted: true
                            });
                        }
                    }
                };
                const fnMouseLeave = function () {
                    if ($editedRow !== $row) {
                        $row.removeClass('ladb-hover');
                        if (node.selected) {
                            $row.siblings('.ladb-selected').removeClass('ladb-hover');
                        }
                        if (that.dialog.capabilities.sketchup_version_number >= 2300000000) {
                            rubyCallCommand('outliner_highlight', { highlighted: false });
                        }
                    }
                };

                $row
                    .on('mouseenter', fnMouseEnter)
                    .on('mouseleave', fnMouseLeave)
                ;

                $row
                    .on('click', function (e) {
                        if (!node.computed_locked) {
                            $editedRow = $row;
                            fnMouseEnter();
                            that.editNode(node, null,
                                function ($modal) {
                                    const $target = $(e.target);
                                    if ($target.hasClass('ladb-outliner-node-name')) {
                                        $('#ladb_outliner_node_input_name', $modal)
                                            .focus()
                                            .select()
                                        ;
                                    } else if ($target.hasClass('ladb-outliner-node-definition-name')) {
                                        $('#ladb_outliner_node_input_definition_name', $modal)
                                            .focus()
                                            .select()
                                        ;
                                    } else if ($target.closest('.ladb-material-color-drop').length > 0) {
                                        $('#ladb_outliner_node_select_material_name', $modal).focus();
                                    } else if ($target.closest('.ladb-outliner-node-layers').length > 0) {
                                        $('#ladb_outliner_node_input_layer_name', $modal).focus();
                                    }
                                },
                                function ($modal) {
                                    $editedRow = null;
                                    fnMouseLeave();
                                }
                            );
                        }
                        return false;
                    })
                    .on('contextmenu', function (e) {
                        if (node.type > 0) {    // > TYPE_MODEL
                            $editedRow = $row;
                            fnMouseEnter();
                            let items = [];
                            if (node.selected) {
                                items.push({ text: that.getSelectedNodes().length + ' ' + i18next.t('tab.outliner.nodes') });
                            } else {
                                items.push({ text: that.computeNodeDisplayName(node) });
                            }
                            items.push({ separator: true });
                            items.push({
                                icon: 'input-field',
                                text: i18next.t('tab.outliner.deep_rename_parts.title') + '...',
                                callback: function () {

                                    // Retrieve cutting diagram options
                                    rubyCallCommand('core_get_model_preset', { dictionary: 'outliner_deep_rename_parts_options' }, function (response) {

                                        const deepRenamePartsOptions = response.preset;

                                        const $modal = that.appendModalInside('ladb_outliner_modal_deep_rename_parts', 'tabs/outliner/_modal-deep-rename-parts.twig', {});

                                        // Fetch UI elements
                                        const $widgetPreset = $('.ladb-widget-preset', $modal);
                                        const $textareaFormula = $('#ladb_textarea_formula', $modal);
                                        const $btnRename = $('#ladb_outliner_deep_rename_parts', $modal);

                                        // Define useful functions
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
                                        };
                                        const fnFetchOptions = function (options) {
                                            options.formula = $textareaFormula.val();
                                        };
                                        const fnFillInputs = function (options) {
                                            $textareaFormula.ladbTextinputCode('val', [ typeof options.formula == 'string' ? options.formula : '' ]);
                                        };

                                        $widgetPreset.ladbWidgetPreset({
                                            dialog: that.dialog,
                                            dictionary: 'outliner_deep_rename_parts_options',
                                            fnFetchOptions: fnFetchOptions,
                                            fnFillInputs: fnFillInputs

                                        });
                                        $textareaFormula.ladbTextinputCode({
                                            variableDefs: fnConvertToVariableDefs([
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
                                            ])
                                        });

                                        fnFillInputs(deepRenamePartsOptions);

                                        // Bind buttons
                                        $btnRename.on('click', function () {

                                            // Fetch options
                                            fnFetchOptions(deepRenamePartsOptions);

                                            // Store options
                                            rubyCallCommand('core_set_model_preset', { dictionary: 'outliner_deep_rename_parts_options', values: deepRenamePartsOptions });

                                            rubyCallCommand('outliner_deep_rename_parts', $.extend({
                                                id: node.id,
                                            }, deepRenamePartsOptions), function (response) {

                                                if (response.errors) {
                                                    that.dialog.notifyErrors(response.errors);
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

                                },
                                disabled: node.computed_locked
                            });
                            items.push({
                                icon: 'make-unique',
                                text: i18next.t('tab.outliner.deep_make_unique.title'),
                                callback: function () {
                                    rubyCallCommand('outliner_deep_make_unique', { id: node.id }, function (response) {

                                        if (response.errors) {
                                            that.dialog.notifyErrors(response.errors);
                                        }

                                    });
                                },
                                disabled: node.computed_locked
                            });
                            items.push({ separator: true });
                            if (node.selected) {
                                items.push({
                                    icon: 'group',
                                    text: i18next.t('tab.outliner.create_container.title_group') + '...',
                                    callback: function () {
                                        that.dialog.prompt(i18next.t('tab.outliner.create_container.title_group'), i18next.t('tab.outliner.edit_node.instance_name'), null, function (name) {
                                            rubyCallCommand('outliner_create_container', {
                                                id: node.id,
                                                name: name,
                                                component: false
                                            }, function (response) {

                                                if (response.errors) {
                                                    that.dialog.notifyErrors(response.errors);
                                                }

                                            });
                                        }, { emptyValueAllowed: true });
                                    },
                                    disabled: node.computed_locked
                                });
                                items.push({
                                    icon: 'component',
                                    text: i18next.t('tab.outliner.create_container.title_component') + '...',
                                    callback: function () {
                                        that.dialog.prompt(i18next.t('tab.outliner.create_container.title_component'), i18next.t('tab.outliner.edit_node.definition_name'), i18next.t('tab.outliner.type_2'), function (name) {
                                            rubyCallCommand('outliner_create_container', {
                                                id: node.id,
                                                name: name,
                                                component: true
                                            }, function (response) {

                                                if (response.errors) {
                                                    that.dialog.notifyErrors(response.errors);
                                                }

                                            });
                                        });
                                    },
                                    disabled: node.computed_locked
                                });
                            }
                            items.push({
                                icon: 'bomb',
                                text: i18next.t('tab.outliner.edit_node.explode') + '...',
                                callback: function () {
                                    that.explodeNode(node);
                                },
                                disabled: node.computed_locked
                            });
                            items.push({ separator: true });
                            items.push({
                                icon: 'trash',
                                text: i18next.t('tab.outliner.edit_node.erase') + '...',
                                class: 'dropdown-item-danger',
                                callback: function () {
                                    that.eraseNode(node);
                                },
                                disabled: node.computed_locked
                            });
                            that.dialog.showContextMenu(e.clientX, e.clientY, items, function () {
                                $editedRow = null;
                                fnMouseLeave();
                            });
                        }
                        e.preventDefault();
                    })
                ;

                $row
                    .on('dragstart', function (e) {
                        fnMouseLeave();
                        let dataTransfer = e.originalEvent.dataTransfer;
                        dataTransfer.effectAllowed = 'move';
                        dataTransfer.clearData();
                        dataTransfer.setData("text/plain", that.computeNodeDisplayName(node));
                        dataTransfer.setData("node_id", node.id);
                    })
                    .on('dragenter', function (e) {
                        $row.addClass('ladb-dragover-ok');
                    })
                    .on('dragleave', function (e) {
                        $row.removeClass('ladb-dragover-ok');
                    })
                    .on('dragover', function (e) {
                        e.preventDefault();
                    })
                    .on('drop', function (e) {
                        e.preventDefault();
                        $row.removeClass('ladb-dragover-ok');
                        const draggedNodeId = e.originalEvent.dataTransfer.getData("node_id");
                        if (draggedNodeId && draggedNodeId !== node.id) {
                            const draggedNode = that.findNodeById(draggedNodeId);
                            if (draggedNode) {
                                rubyCallCommand('outliner_move', { id: draggedNode.id, target_id: node.id }, function (response) {

                                    if (response.errors) {
                                        that.dialog.notifyErrors(response.errors);
                                    }

                                });
                            }
                        }
                    })
                ;
                $('a.ladb-btn-node-toggle-folding', $row).on('click', function () {
                    $(this).blur();

                    rubyCallCommand('outliner_toggle_expanded', { id: node.id }, function (response) {
                        if (response.errors) {
                            that.dialog.notifyErrors(response.errors);
                        }
                    });

                    return false;
                });
                $('a.ladb-btn-node-toggle-select', $row).on('click', function () {
                    $(this).blur();

                    rubyCallCommand('outliner_toggle_select', { id: node.id }, function (response) {
                        if (response.errors) {
                            that.dialog.notifyErrors(response.errors);
                        }
                    });

                    return false;
                });
                $('a.ladb-btn-node-toggle-visible', $row).on('click', function () {
                    $(this).blur();

                    rubyCallCommand('outliner_toggle_visible', { id: node.id }, function (response) {
                        if (response.errors) {
                            that.dialog.notifyErrors(response.errors);
                        }
                    });

                    return false;
                });
                $('a.ladb-btn-node-set-active', $row).on('click', function () {
                    $(this).blur();

                    rubyCallCommand('outliner_set_active', { id: node.id }, function (response) {
                        if (response.errors) {
                            that.dialog.notifyErrors(response.errors);
                        } else {
                            if (that.generateOptions.minimize_on_set_active) {
                                that.dialog.minimize();
                            }
                        }
                    });

                    return false;
                });
                $('a.ladb-btn-node-open-url', $row).on('click', function () {
                    $(this).blur();
                    rubyCallCommand('core_open_url', { url: $(this).attr('href') });
                    return false;
                });
                $('a.ladb-btn-node-edit', $row).on('click', function () {
                    $(this).blur();
                    that.editNode(node);
                    return false;
                });

                if (node.active) { activeOnly = false; }

                if (node.expanded || node.child_active || node.active) {
                    for (const child of node.children) {
                        if (activeOnly && !child.child_active && !child.active) {
                            continue;
                        }
                        fnRenderNode(child, activeOnly);
                    }
                }

            };
            fnRenderNode(this.rootNode, true);

            // Setup tooltips
            this.dialog.setupTooltips(this.$page);

        }

    }

    LadbTabOutliner.prototype.editNode = function (node, tab = null, shownCallback = undefined, hiddenCallback = undefined) {
        const that = this;

        const editedNode = JSON.parse(JSON.stringify(node));  // Create a clone
        let editedNodes = [];
        if (node.selected) {
            editedNodes = this.getSelectedNodes();
        } else {
            editedNodes.push(node);
        }

        let multiple = editedNodes.length > 1;
        if (multiple) {

            for (let i = 0; i < editedNodes.length; i++) {
                if (JSON.stringify(editedNode.layer) !== JSON.stringify(editedNodes[i].layer)) {
                    editedNode.layer = MULTIPLE_VALUE;
                }
                if (editedNode.name !== editedNodes[i].name) {
                    editedNode.name = MULTIPLE_VALUE;
                }
                if (JSON.stringify(editedNode.material) !== JSON.stringify(editedNodes[i].material)) {
                    editedNode.material = MULTIPLE_VALUE;
                }
                if (editedNode.type === 2 && editedNodes[i].type === 2 || editedNode.type === 3 && editedNodes[i].type === 3) {   // 2 = TYPE_COMPONENT, 3 = TYPE_PART
                    if (editedNode.definition_name !== editedNodes[i].definition_name) {
                        delete editedNode.definition_name;
                    }
                    if (editedNode.description !== editedNodes[i].description) {
                        editedNode.description = MULTIPLE_VALUE;
                    }
                    if (editedNode.url !== editedNodes[i].url) {
                        editedNode.url = MULTIPLE_VALUE;
                    }
                    editedNode.tags = editedNode.tags.filter(function (tag) {  // Extract only commun tags
                        return -1 !== editedNodes[i].tags.indexOf(tag);
                    });
                } else {
                    editedNode.type = -1;
                    delete editedNode.definition_name;
                    delete editedNode.description;
                    delete editedNode.url;
                    delete editedNode.tags;
                }
            }

        }

        if (tab === undefined) {
            tab = this.lastEditNodeTab;
        }
        if (tab === null || tab.length === 0) {
            tab = 'general';
        }
        this.lastEditNodeTab = tab;

        rubyCallCommand('outliner_edit', { ids: editedNodes.map(node => node.id) }, function (response) {

            if (response.errors) {
                that.dialog.notifyErrors(response.errors);
            } else {

                const $modal = that.appendModalInside('ladb_outliner_modal_edit', 'tabs/outliner/_modal-edit.twig', {
                    capabilities: that.dialog.capabilities,
                    mass_unit_strippedname: that.massUnitStrippedname,
                    length_unit_strippedname: that.lengthUnitStrippedname,
                    node: editedNode,
                    nodeCount: editedNodes.length,
                    multiple: multiple,
                    materialUsages: that.availableMaterials,
                    tab: tab
                });

                // Fetch UI elements
                const $tabs = $('.modal-header a[data-toggle="tab"]', $modal);
                const $inputName = $('#ladb_outliner_node_input_name', $modal);
                const $selectMaterialName = $('#ladb_outliner_node_select_material_name', $modal);
                const $inputDefinitionName = $('#ladb_outliner_node_input_definition_name', $modal);
                const $inputLayerName = $('#ladb_outliner_node_input_layer_name', $modal);
                const $inputDescription = $('#ladb_outliner_node_input_description', $modal);
                const $inputUrl = $('#ladb_outliner_node_input_url', $modal);
                const $inputTags = $('#ladb_outliner_node_input_tags', $modal);
                const $btnErase = $('#ladb_outliner_node_erase', $modal);
                const $btnExplode = $('#ladb_outliner_node_explode', $modal);
                const $btnUpdate = $('#ladb_outliner_node_update', $modal);

                // Utils function
                const fnNewCheck = function($select, type) {
                    if ($select.val() === 'new') {
                        that.dialog.executeCommandOnTab('materials', 'new_material', { type: type });
                        $modal.modal('hide');
                        return true;
                    }
                    return false;
                };

                // Bind tabs
                $tabs.on('shown.bs.tab', function (e) {
                    that.lastEditNodeTab = $(e.target).attr('href').substring('#tab_edit_node_'.length);
                });

                // Bind input
                $inputName.ladbTextinputText();
                $inputDefinitionName.ladbTextinputText();
                $inputLayerName.ladbTextinputText({
                    autocomplete: {
                        source: that.availableLayers.map(function (layer) { return {
                            value: layer.name,
                            category: layer.path.join(' / '),
                            icon: 'fill',
                            color: layer.color
                        } }),
                        delay: 0,
                        minLength: 0,
                        categoryIcon: 'folder'
                    }
                });
                $inputDescription.ladbTextinputArea();
                $inputUrl.ladbTextinputUrl();
                $inputTags.ladbTextinputTokenfield({
                    unique: true
                });

                // Bind select
                if (editedNode.material) {
                    $selectMaterialName.val(editedNode.material === MULTIPLE_VALUE ? MULTIPLE_VALUE : editedNode.material.name);
                }
                $selectMaterialName
                    .selectpicker(SELECT_PICKER_OPTIONS)
                    .on('changed.bs.select', function (e, clickedIndex, isSelected, previousValue) {
                        fnNewCheck($(this));
                    });

                // Bind buttons
                $btnErase.on('click', function () {
                    that.eraseNode(editedNode, function () {

                        // Hide modal
                        $modal.modal('hide');

                    });
                });
                $btnExplode.on('click', function () {
                    that.explodeNode(editedNode, function () {

                        // Hide modal
                        $modal.modal('hide');

                    });
                });
                $btnUpdate.on('click', function () {

                    let nodesData = [];
                    for (let i = 0; i < editedNodes.length; i++) {

                        let nodeData = {
                            id: editedNodes[i].id,
                            name: editedNodes[i].name,
                        };
                        nodesData.push(nodeData);

                        if (!$inputName.ladbTextinputText('isMultiple')) {
                            nodeData.name = $inputName.val();
                        }
                        if ($inputLayerName.length > 0) {
                            if (!$inputLayerName.ladbTextinputText('isMultiple')) {
                                nodeData.layer_name = $inputLayerName.val();
                            } else {
                                nodeData.layer_name = editedNodes[i].layer_name;
                            }
                        }
                        if ($selectMaterialName.length > 0) {
                            if ($selectMaterialName.val() !== MULTIPLE_VALUE) {
                                nodeData.material_name = $selectMaterialName.val();
                            } else {
                                nodeData.material_name = editedNodes[i].material_name;
                            }
                        }
                        if ($inputDefinitionName.length > 0) {
                            if(!$inputDefinitionName.ladbTextinputText('isMultiple')) {
                                nodeData.definition_name = $inputDefinitionName.val();
                            } else {
                                nodeData.definition_name = editedNodes[i].definition_name;
                            }
                        }
                        if ($inputDescription.length > 0) {
                            if (!$inputDescription.ladbTextinputArea('isMultiple')) {
                                nodeData.description = $inputDescription.val();
                            } else {
                                nodeData.description = editedNodes[i].description;
                            }
                        }
                        if ($inputUrl.length > 0) {
                            if (!$inputUrl.ladbTextinputUrl('isMultiple')) {
                                nodeData.url = $inputUrl.val();
                            } else {
                                nodeData.url = editedNodes[i].url;
                            }
                        }
                        if ($inputTags.length > 0) {
                            const untouchTags = editedNodes[i].tags.filter(function (tag) {
                                return !editedNode.tags.includes(tag)
                            });
                            nodeData.tags = untouchTags.concat($inputTags.tokenfield('getTokensList').split(';'));
                        }

                    }

                    rubyCallCommand('outliner_update', { nodes_data: nodesData }, function (response) {

                        if (response.errors) {
                            that.dialog.notifyErrors(response.errors);
                        } else {

                            // Hide modal
                            $modal.modal('hide');

                        }

                    });

                });

                // Bind model
                $modal
                    .on('shown.bs.modal', function () {

                        if (that.dialog.capabilities.sketchup_version_number >= 2300000000) {
                            rubyCallCommand('outliner_highlight', { ids: node.selected ? that.getSelectedNodes().map(node => node.id) : [ node.id ], highlighted: true });
                        }

                        // Focus
                        $inputName.focus();

                        // Setup tooltips & popovers
                        that.dialog.setupTooltips();
                        that.dialog.setupPopovers();

                        // Callback
                        if (typeof shownCallback === 'function') {
                            shownCallback($modal);
                        }

                    })
                    .on('hidden.bs.modal', function () {

                        if (that.dialog.capabilities.sketchup_version_number >= 2300000000) {
                            rubyCallCommand('outliner_highlight', { highlighted: false });
                        }

                        // Callback
                        if (typeof hiddenCallback === 'function') {
                            hiddenCallback($modal);
                        }

                    })
                ;

                // Show modal
                $modal.modal('show');

            }

        });

    };

    LadbTabOutliner.prototype.explodeNode = function (node, callback = undefined) {
        let that = this;

        that.dialog.confirm(i18next.t('default.caution'), i18next.t('tab.outliner.edit_node.explode_message', {
            name: node.selected ? that.getSelectedNodes().length + ' ' + i18next.t('tab.outliner.nodes') : this.computeNodeDisplayName(node)
        }), function () {

            rubyCallCommand('outliner_explode', { id: node.id }, function (response) {

                if (response.errors) {
                    that.dialog.notifyErrors(response.errors);
                } else {

                    // Callback
                    if (typeof callback === 'function') {
                        callback();
                    }

                }

            });

        }, {
            confirmBtnType: 'danger',
            confirmBtnLabel: i18next.t('tab.outliner.edit_node.explode')
        });

    };

    LadbTabOutliner.prototype.eraseNode = function (node, callback = undefined) {
        let that = this;

        that.dialog.confirm(i18next.t('default.caution'), i18next.t('tab.outliner.edit_node.erase_message', {
            name: node.selected ? that.getSelectedNodes().length + ' ' + i18next.t('tab.outliner.nodes') : this.computeNodeDisplayName(node)
        }), function () {

            rubyCallCommand('outliner_erase', { id: node.id }, function (response) {

                if (response.errors) {
                    that.dialog.notifyErrors(response.errors);
                } else {

                    // Callback
                    if (typeof callback === 'function') {
                        callback();
                    }

                }

            });

        }, {
            confirmBtnType: 'danger',
            confirmBtnLabel: i18next.t('tab.outliner.edit_node.erase')
        });

    };

    LadbTabOutliner.prototype.computeNodeDisplayName = function (node) {
        const names = [];
        if (node.name) {
            names.push(node.name);
        }
        if (node.definition_name) {
            let definitionName = node.definition_name
            if (node.type === 2 || node.type === 3) {   // 2 = TYPE_COMPONENT, 3 = TYPE_PART
                definitionName = '<' + definitionName + '>'
            }
            names.push(definitionName);
        }
        if (names.length === 0) {    // 1 = TYPE_GROUP
            names.push(i18next.t('tab.outliner.type_' + node.type));
        }
        return names.join(' ');
    };

    // Options /////

    LadbTabOutliner.prototype.loadOptions = function (callback) {
        const that = this;

        rubyCallCommand('core_get_model_preset', { dictionary: 'outliner_options' }, function (response) {

            that.generateOptions = response.preset;

            // Callback
            if (typeof callback == 'function') {
                callback();
            }

        });

    };

    LadbTabOutliner.prototype.editOptions = function (tab) {
        const that = this;

        if (tab === undefined) {
            tab = this.lastOptionsTab;
        }
        if (tab === null || tab.length === 0) {
            tab = 'general';
        }
        this.lastOptionsTab = tab;

        const $modal = that.appendModalInside('ladb_outliner_modal_options', 'tabs/outliner/_modal-options.twig', {
            tab: tab
        });

        // Fetch UI elements
        const $tabs = $('a[data-toggle="tab"]', $modal);
        const $widgetPreset = $('.ladb-widget-preset', $modal);
        const $inputShowIddenInstances = $('#ladb_input_show_hidden_instances', $modal);
        const $inputHideDescriptions = $('#ladb_input_hide_descriptions', $modal);
        const $inputHideTags = $('#ladb_input_hide_tags', $modal);
        const $inputMinimizeOnSetActive = $('#ladb_input_minimize_on_set_active', $modal);
        const $btnUpdate = $('#ladb_outliner_options_update', $modal);

        // Define useful functions
        const fnFetchOptions = function (options) {
            options.show_hidden_instances = $inputShowIddenInstances.is(':checked');
            options.hide_descriptions = $inputHideDescriptions.is(':checked');
            options.hide_tags = $inputHideTags.is(':checked');
            options.minimize_on_set_active = $inputMinimizeOnSetActive.is(':checked');
        };
        const fnFillInputs = function (options) {
            $inputShowIddenInstances.prop('checked', options.show_hidden_instances);
            $inputHideDescriptions.prop('checked', options.hide_descriptions);
            $inputHideTags.prop('checked', options.hide_tags);
            $inputMinimizeOnSetActive.prop('checked', options.minimize_on_set_active);
        };

        $widgetPreset.ladbWidgetPreset({
            dialog: that.dialog,
            dictionary: 'outliner_options',
            fnFetchOptions: fnFetchOptions,
            fnFillInputs: fnFillInputs

        });

        // Bind tabs
        $tabs.on('shown.bs.tab', function (e) {
            that.lastOptionsTab = $(e.target).attr('href').substring('#tab_options_'.length);
        });

        // Bind buttons
        $btnUpdate.on('click', function () {

            // Fetch options
            fnFetchOptions(that.generateOptions);

            // Store options
            rubyCallCommand('core_set_model_preset', { dictionary: 'outliner_options', values: that.generateOptions });

            // Hide modal
            $modal.modal('hide');

            // Regenerate the outliner
            that.generateOutliner();

        });

        // Populate inputs
        fnFillInputs(that.generateOptions);

        // Show modal
        $modal.modal('show');

        // Setup popovers
        this.dialog.setupPopovers();

    };

    // Internals /////

    LadbTabOutliner.prototype.findNodeById = function (id, parent) {
        if (parent === undefined) {
            parent = this.rootNode;
        }
        if (parent.id === id) {
            return parent;
        }
        for (const child of parent.children) {
            const node = this.findNodeById(id, child);
            if (node) {
                return node;
            }
        }
        return null;
    };

    LadbTabOutliner.prototype.getSelectedNodes = function (parent) {
        if (parent === undefined) {
            parent = this.rootNode;
        }
        var selectedNodes = [];
        if (parent.selected) {
            selectedNodes.push(parent);
        }
        for (const child of parent.children) {
            selectedNodes = selectedNodes.concat(this.getSelectedNodes(child));
        }
        return selectedNodes;
    }

    LadbTabOutliner.prototype.showObsolete = function (messageI18nKey, forced) {
        if (!this.isObsolete() || forced) {

            const that = this;

            // Set tab as obsolete
            this.setObsolete(true);

            const $modal = this.appendModalInside('ladb_outliner_modal_obsolete', 'tabs/outliner/_modal-obsolete.twig', {
                messageI18nKey: messageI18nKey
            });

            // Fetch UI elements
            const $btnGenerate = $('#ladb_outliner_obsolete_generate', $modal);

            // Bind buttons
            $btnGenerate.on('click', function () {
                $modal.modal('hide');
                that.generateOutliner();
            });

            // Show modal
            $modal.modal('show');

        }
    };

    // Init ///

    LadbTabOutliner.prototype.registerCommands = function () {
        LadbAbstractTab.prototype.registerCommands.call(this);

        const that = this;

        this.registerCommand('edit_node', function (parameters) {
            const nodeId = parameters.node_id;
            const tab = parameters.tab;
            window.requestAnimationFrame(function () {
                that.generateOutliner([ nodeId ], function () {
                    const node = that.findNodeById(nodeId);
                    if (node) {
                        that.editNode(node, tab);
                    }
                });
            });
        });

    };

    LadbTabOutliner.prototype.bind = function () {
        LadbAbstractTab.prototype.bind.call(this);

        const that = this;

        // Bind buttons
        this.$btnGenerate.on('click', function () {
            that.generateOutliner();
            this.blur();
        });
        this.$btnOptions.on('click', function () {
            that.editOptions();
            this.blur();
        });
        this.$btnSideFold.on('click', function () {
            that.$btnSideFold.toggleClass('active');
            that.dialog.maximize(that.$btnSideFold.hasClass('active'));
            this.blur();
            return false;
        });

        // Events

        this.$element
            .on('shown.ladb.tab', function () {
                rubyCallCommand('outliner_start_observing');
                if (this.rootNode != null) {
                    that.generateOutliner();
                }
            })
            .on('hidden.ladb.tab', function () {
                rubyCallCommand('outliner_stop_observing');
            });

        addEventCallback([ 'on_new_model', 'on_open_model', 'on_activate_model' ], function (params) {
            that.showObsolete('core.event.model_change', true);

            // Hide edit option model (if it exists)
            $('#ladb_outliner_modal_options').modal('hide');

            // Reload options (from new active model)
            that.loadOptions();

        });
        addEventCallback([ 'on_boo' ], function (params) {
            that.refreshOutliner();
        });

    };

    LadbTabOutliner.prototype.processInitializedCallback = function (initializedCallback) {
        const that = this;

        // Load Options
        that.loadOptions(function () {
            LadbAbstractTab.prototype.processInitializedCallback.call(that, initializedCallback);
        });

    };

    LadbTabOutliner.prototype.defaultInitializedCallback = function () {
        LadbAbstractTab.prototype.defaultInitializedCallback.call(this);

        this.generateOutliner();

    };

    // PLUGIN DEFINITION
    // =======================

    function Plugin(option, params) {
        return this.each(function () {
            const $this = $(this);
            let data = $this.data('ladb.tab.plugin');
            if (!data) {
                const options = $.extend({}, LadbTabOutliner.DEFAULTS, $this.data(), typeof option === 'object' && option);
                if (undefined === options.dialog) {
                    throw 'dialog option is mandatory.';
                }
                $this.data('ladb.tab.plugin', (data = new LadbTabOutliner(this, options, options.dialog)));
            }
            if (typeof option === 'string') {
                data[option].apply(data, Array.isArray(params) ? params : [ params ])
            } else {
                data.init(option.initializedCallback);
            }
        })
    }

    const old = $.fn.ladbTabOutliner;

    $.fn.ladbTabOutliner = Plugin;
    $.fn.ladbTabOutliner.Constructor = LadbTabOutliner;


    // NO CONFLICT
    // =================

    $.fn.ladbTabOutliner.noConflict = function () {
        $.fn.ladbTabOutliner = old;
        return this;
    }

}(jQuery);
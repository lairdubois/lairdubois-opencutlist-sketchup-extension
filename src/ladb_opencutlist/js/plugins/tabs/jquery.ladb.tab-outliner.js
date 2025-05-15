+function ($) {
    'use strict';

    // CLASS DEFINITION
    // ======================

    const LadbTabOutliner = function (element, options, dialog) {
        LadbAbstractTab.call(this, element, options, dialog);

        this.editedNode = null;
        this.lastEditNodeTab = null;

        this.$header = $('.ladb-header', this.$element);
        this.$fileTabs = $('.ladb-file-tabs', this.$header);
        this.$btnGenerate = $('#ladb_btn_generate', this.$header);

        this.$page = $('.ladb-page', this.$element);

        this.showHiddenInstances = true;

    };
    LadbTabOutliner.prototype = Object.create(LadbAbstractTab.prototype);

    LadbTabOutliner.DEFAULTS = {};

    // List /////

    LadbTabOutliner.prototype.generateOutliner = function (callback) {
        const that = this;

        this.rootNode = null;
        this.$page.empty();
        this.$btnGenerate.prop('disabled', true);
        this.setObsolete(false);

        window.requestAnimationFrame(function () {

            // Start progress feedback
            that.dialog.startProgress(1);

            rubyCallCommand('outliner_generate', {}, function (response) {

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

                if (false && root_node) {
                    const fn_set_parent = function (node, parent) {
                        node.parent = parent;
                        for (const child of node.children) {
                            fn_set_parent(child, node);
                        }
                    };
                    fn_set_parent(root_node, null);
                }

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

                const $toggleHiddenBtn = $('#ladb_btn_toggle_hidden')
                if (that.showHiddenInstances) {
                    $('i', $toggleHiddenBtn).addClass('ladb-opencutlist-icon-check-box-with-check-sign');
                }

                // Bind buttons
                $toggleHiddenBtn.on('click', function () {
                    $(this).blur();
                    that.showHiddenInstances = !that.showHiddenInstances;
                    if (that.showHiddenInstances) {
                        $('i', $(this)).addClass('ladb-opencutlist-icon-check-box-with-check-sign');
                    } else {
                        $('i', $(this)).removeClass('ladb-opencutlist-icon-check-box-with-check-sign');
                    }
                    that.renderNodes();
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

                if (!node.computed_visible && !that.showHiddenInstances) {
                    return;
                }

                const $row = $(Twig.twig({ref: "tabs/outliner/_list-row-node.twig"}).render({
                    capabilities: that.dialog.capabilities,
                    node: node
                }));
                that.$tbody.append($row);

                if (that.dialog.capabilities.sketchup_version_number >= 2300000000) {
                    $row
                        .on('mouseenter', function () {
                            if (!node.child_active && !node.active) {
                                rubyCallCommand('outliner_highlight', {id: node.id, highlighted: true});
                            }
                        })
                        .on('mouseleave', function () {
                            if (that.editedNode !== node) {
                                rubyCallCommand('outliner_highlight', {id: node.id, highlighted: false});
                            }
                        });
                }
                $row.on('click', function (e) {
                    $(this).blur();
                    $('.ladb-click-tool', $(this)).click();
                    return false;
                });
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
                        }
                    });

                    return false;
                });
                $('a.ladb-btn-node-open-url', $row).on('click', function () {
                    $(this).blur();
                    rubyCallCommand('core_open_url', {url: $(this).attr('href')});
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
            this.dialog.setupTooltips();

        }

    }

    LadbTabOutliner.prototype.editNode = function (node, tab) {
        const that = this;

        if (tab === undefined) {
            tab = this.lastEditNodeTab;
        }
        if (tab === null || tab.length === 0) {
            tab = 'general';
        }
        this.lastEditNodeTab = tab;

        // Keep the edited node
        this.editedNode = node;

        rubyCallCommand('outliner_edit', { id: that.editedNode.id }, function (response) {

            if (response.errors) {
                that.dialog.notifyErrors(response.errors);
            } else {

                // Update node ID in case of group made unique
                // that.editedNode.id = response.node_id;

                const $modal = that.appendModalInside('ladb_outliner_modal_edit', 'tabs/outliner/_modal-edit.twig', {
                    capabilities: that.dialog.capabilities,
                    mass_unit_strippedname: that.massUnitStrippedname,
                    length_unit_strippedname: that.lengthUnitStrippedname,
                    node: node,
                    tab: tab,
                    materialUsages: that.availableMaterials
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
                if (node.material) {
                    $selectMaterialName.val(node.material.name);
                }
                $selectMaterialName
                    .selectpicker(SELECT_PICKER_OPTIONS)
                    .on('changed.bs.select', function (e, clickedIndex, isSelected, previousValue) {
                        fnNewCheck($(this));
                    });

                // Bind buttons
                $btnExplode.on('click', function () {

                    const names = [];
                    if (that.editedNode.name) {
                        names.push(that.editedNode.name);
                    }
                    if (that.editedNode.definition_name) {
                        let definitionName = that.editedNode.definition_name
                        if (that.editedNode.type === 2 || that.editedNode.type === 3) {   // 2 = TYPE_COMPONENT, 3 = TYPE_PART
                            definitionName = '<' + definitionName + '>'
                        }
                        names.push(definitionName);
                    }

                    that.dialog.confirm(i18next.t('default.caution'), i18next.t('tab.outliner.edit_node.explode_message', { name: names.join(' ') }), function () {

                        rubyCallCommand('outliner_explode', { id: that.editedNode.id }, function (response) {

                            if (response.errors) {
                                that.dialog.notifyErrors(response.errors);
                            } else {

                                // Reload the list
                                that.generateOutliner();

                                // Reset edited material
                                that.editedNode = null;

                                // Hide modal
                                $modal.modal('hide');

                            }

                        });

                    }, {
                        confirmBtnType: 'danger',
                        confirmBtnLabel: i18next.t('tab.outliner.edit_node.explode')
                    });

                });
                $btnUpdate.on('click', function () {

                    const data = {
                        id: that.editedNode.id,
                        name: $inputName.val(),
                        material_name: $selectMaterialName.val()
                    }
                    if ($inputDefinitionName.length > 0) {
                        data.definition_name = $inputDefinitionName.val();
                    }
                    if ($inputLayerName.length > 0) {
                        data.layer_name = $inputLayerName.val();
                    }
                    if ($inputDescription.length > 0) {
                        data.description = $inputDescription.val();
                    }
                    if ($inputUrl.length > 0) {
                        data.url = $inputUrl.val();
                    }
                    if ($inputTags.length > 0) {
                        data.tags = $inputTags.tokenfield('getTokensList').split(';')
                    }

                    rubyCallCommand('outliner_update', data, function (response) {

                        if (response.errors) {
                            that.dialog.notifyErrors(response.errors);
                        } else {

                            // Reset edited material
                            that.editedNode = null;

                            // Hide modal
                            $modal.modal('hide');

                        }

                    });

                });

                // Bind model
                $modal
                    .on('shown.bs.modal', function () {
                        if (that.dialog.capabilities.sketchup_version_number >= 2300000000) {
                            rubyCallCommand('outliner_highlight', {id: node.id, highlighted: true});
                        }
                    })
                    .on('hidden.bs.modal', function () {
                        that.editedNode = null;
                        if (that.dialog.capabilities.sketchup_version_number >= 2300000000) {
                            rubyCallCommand('outliner_highlight', {id: node.id, highlighted: false});
                        }
                    })
                ;

                // Show modal
                $modal.modal('show');

                // Setup tooltips & popovers
                that.dialog.setupTooltips();
                that.dialog.setupPopovers();

            }

        });

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
                that.generateOutliner(function () {
                    const node = that.findNodeById(nodeId)
                    that.editNode(node, tab);
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

        // Events

        this.$element
            .on('shown.ladb.tab', function () {
                rubyCallCommand('outliner_start_observing');
                that.generateOutliner();
            })
            .on('hidden.ladb.tab', function () {
                rubyCallCommand('outliner_stop_observing');
            });

        addEventCallback([ 'on_new_model', 'on_open_model', 'on_activate_model' ], function (params) {
            that.showObsolete('core.event.model_change', true);
        });
        addEventCallback([ 'on_boo' ], function (params) {
            that.refreshOutliner();
        });

    };

    LadbTabOutliner.prototype.defaultInitializedCallback = function () {
        LadbAbstractTab.prototype.defaultInitializedCallback.call(this);

        // this.generateOutliner();

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
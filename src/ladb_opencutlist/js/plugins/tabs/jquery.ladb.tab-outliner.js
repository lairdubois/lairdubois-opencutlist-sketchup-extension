+function ($) {
    'use strict';

    // CLASS DEFINITION
    // ======================

    var LadbTabOutliner = function (element, options, dialog) {
        LadbAbstractTab.call(this, element, options, dialog);

        this.editedNode = null;
        this.ignoreNextSelectionEvents = false;
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
        var that = this;

        this.rootNode = null;
        this.$page.empty();
        this.$btnGenerate.prop('disabled', true);
        this.setObsolete(false);

        window.requestAnimationFrame(function () {

            // Start progress feedback
            that.dialog.startProgress(1);

            rubyCallCommand('outliner_generate', {}, function (response) {

                var errors = response.errors;
                var warnings = response.warnings;
                var tips = response.tips;
                var filename = response.filename;
                var modelName = response.model_name;
                var root_node = response.root_node;
                var available_layers = response.available_layers;

                // Keep useful data
                that.rootNode = root_node;
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
                    tips: tips,
                    root_node: root_node
                }));

                that.updateHidden();

                // Setup tooltips
                that.dialog.setupTooltips();

                // Bind rows
                that.bindNodeRows(that.$page);

                // Bind buttons
                $('#ladb_btn_toggle_hidden').on('click', function () {
                    $(this).blur();
                    that.toggleHidden();
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

    LadbTabOutliner.prototype.editNode = function (id, tab) {
        var that = this;

        var node = this.findNodeById(id);
        if (node) {

            if (tab === undefined) {
                tab = this.lastEditNodeTab;
            }
            if (tab === null || tab.length === 0) {
                tab = 'general';
            }
            this.lastEditNodeTab = tab;

            // Keep the edited node
            this.editedNode = node;

            var $modal = this.appendModalInside('ladb_outliner_modal_edit', 'tabs/outliner/_modal-edit.twig', {
                capabilities: that.dialog.capabilities,
                mass_unit_strippedname: that.massUnitStrippedname,
                length_unit_strippedname: that.lengthUnitStrippedname,
                node: node,
                tab: tab,
            });

            // Fetch UI elements
            var $tabs = $('.modal-header a[data-toggle="tab"]', $modal);
            var $inputName = $('#ladb_outliner_node_input_name', $modal);
            var $inputDefinitionName = $('#ladb_outliner_node_input_definition_name', $modal);
            var $inputLayerName = $('#ladb_outliner_node_input_layer_name', $modal);
            var $inputDescription = $('#ladb_outliner_node_input_description', $modal);
            var $inputUrl = $('#ladb_outliner_node_input_url', $modal);
            var $inputTags = $('#ladb_outliner_node_input_tags', $modal);
            var $btnExplode = $('#ladb_outliner_node_explode', $modal);
            var $btnUpdate = $('#ladb_outliner_node_update', $modal);

            // Bind tabs
            $tabs.on('shown.bs.tab', function (e) {
                that.lastEditNodeTab = $(e.target).attr('href').substring('#tab_edit_node_'.length);
            });

            // Bind input
            $inputName.ladbTextinputText();
            $inputDefinitionName.ladbTextinputText();
            $inputLayerName.ladbTextinputTokenfield({
                limit: 1,
                autocomplete: {
                    source: that.availableLayers.map(function (layer) { return {
                        value: layer.name,
                        category: layer.path.join(' / '),
                        icon: 'fill',
                        color: layer.color
                    } }),
                    delay: 100,
                    categoryIcon: 'folder'
                },
                showAutocompleteOnFocus: true
            });
            $inputDescription.ladbTextinputArea();
            $inputUrl.ladbTextinputUrl();
            $inputTags.ladbTextinputTokenfield({
                unique: true
            });

            // Bind buttons
            $btnExplode.on('click', function () {

                var names = [];
                if (that.editedNode.name) {
                    names.push(that.editedNode.name);
                }
                if (that.editedNode.definition_name) {
                    var definitionName = that.editedNode.definition_name
                    if (that.editedNode.type === 2 || that.editedNode.type === 3) {   // 2 = TYPE_COMPONENT, 3 = TYPE_PART
                        definitionName = '<' + definitionName + '>'
                    }
                    names.push(definitionName);
                }

                that.dialog.confirm(i18next.t('default.caution'), i18next.t('tab.outliner.edit_node.explode_message', { name: names.join(' ') }), function () {

                    rubyCallCommand('outliner_explode', { id: that.editedNode.id }, function (response) {

                        if (response['errors']) {
                            that.dialog.notifyErrors(response['errors']);
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

                var data = {
                    id: that.editedNode.id,
                    name: $inputName.val()
                }
                if ($inputDefinitionName.length > 0) {
                    data['definition_name'] = $inputDefinitionName.val();
                }
                if ($inputLayerName.length > 0) {
                    data['layer_name'] = $inputLayerName.tokenfield('getTokensList')
                }
                if ($inputDescription.length > 0) {
                    data['description'] = $inputDescription.val();
                }
                if ($inputUrl.length > 0) {
                    data['url'] = $inputUrl.val();
                }
                if ($inputTags.length > 0) {
                    data['tags'] = $inputTags.tokenfield('getTokensList').split(';')
                }

                rubyCallCommand('outliner_update', data, function (response) {

                    if (response['errors']) {
                        that.dialog.notifyErrors(response['errors']);
                    } else {

                        // Reload the list
                        var nodeId = that.editedNode.id;
                        that.generateOutliner(function() {
                            that.scrollSlideToTarget(null, $('[data-node-id=' + nodeId + ']', that.$page), false, true);
                        });

                        // Reset edited material
                        that.editedNode = null;

                        // Hide modal
                        $modal.modal('hide');

                    }

                });

            });

            // Show modal
            $modal.modal('show');

            // Setup tooltips & popovers
            this.dialog.setupTooltips();
            this.dialog.setupPopovers();

        } else {
            alert('Node not found (id=' + id + ')');
        }

    };

    LadbTabOutliner.prototype.toggleFoldingNode = function (id, $row) {
        var node = this.findNodeById(id);
        if (node) {
            node.expanded = !node.expanded;
            if ($row === undefined) {
                $row = $('#ladb_outliner_row_' + node.id, this.$page);
            }
            this.replaceNodeRow(node, $row);
            rubyCallCommand('outliner_set_expanded', {
                id: node.id,
                expanded: node.expanded
            });
        }
    };

    LadbTabOutliner.prototype.toggleVisibleNode = function (id, $row) {
        var node = this.findNodeById(id);
        if (node) {
            node.visible = !node.visible;
            if ($row === undefined) {
                $row = $('#ladb_outliner_row_' + node.id, this.$page);
            }
            this.replaceNodeRow(node, $row);
            rubyCallCommand('outliner_set_visible', {
                id: node.id,
                visible: node.visible
            });
        }
    };

    LadbTabOutliner.prototype.toggleHidden = function () {
        this.showHiddenInstances = !this.showHiddenInstances;
        this.updateHidden();
    };

    LadbTabOutliner.prototype.updateHidden = function () {
        var that = this;

        var $btn = $('#ladb_btn_toggle_hidden');
        var $i = $('i', $btn);

        if (this.showHiddenInstances) {
            $i.addClass('ladb-opencutlist-icon-check-box-with-check-sign');
        } else {
            $i.removeClass('ladb-opencutlist-icon-check-box-with-check-sign');
        }

        $('.ladb-outliner-row', this.$page).each(function () {
            var $row = $(this);
            if (!that.showHiddenInstances && $row.hasClass('ladb-mute')) {
                $row.hide();
            } else {
                $row.show();
            }
        });

    };

    // Internals /////

    LadbTabOutliner.prototype.bindNodeRows = function ($rowsContext) {
        var that = this;

        $('.ladb-outliner-row', $rowsContext).each(function () {
            var $row = $(this);
            $row.on('click', function (e) {
                $(this).blur();
                $('.ladb-click-tool', $(this)).click();
                return false;
            });
        });
        $('a.ladb-btn-node-toggle-folding', $rowsContext).on('click', function () {
            $(this).blur();
            var $row = $(this).parents('.ladb-outliner-row');
            var nodeId = $row.data('node-id');
            that.toggleFoldingNode(nodeId, $row);
            return false;
        });
        $('a.ladb-btn-node-open-url', $rowsContext).on('click', function () {
            $(this).blur();
            rubyCallCommand('core_open_url', { url: $(this).attr('href') });
            return false;
        });
        $('a.ladb-btn-node-set-active', $rowsContext).on('click', function () {
            $(this).blur();
            var $row = $(this).parents('.ladb-outliner-row');
            var nodeId = $row.data('node-id');

            // Flag to ignore next selection change event
            that.ignoreNextSelectionEvents = true;

            rubyCallCommand('outliner_set_active', { id: nodeId }, function (response) {

                // Flag to stop ignoring next selection change event
                that.ignoreNextSelectionEvents = false;

                if (response['errors']) {
                    that.dialog.notifyErrors(response['errors']);
                } else {

                }

            });

            return false;
        });
        $('a.ladb-btn-node-toggle-visible', $rowsContext).on('click', function () {
            $(this).blur();
            var $row = $(this).parents('.ladb-outliner-row');
            var nodeId = $row.data('node-id');
            that.toggleVisibleNode(nodeId, $row);
            return false;
        });
        $('a.ladb-btn-node-edit', $rowsContext).on('click', function () {
            $(this).blur();
            var $row = $(this).parents('.ladb-outliner-row');
            var nodeId = $row.data('node-id');
            that.editNode(nodeId);
            return false;
        });

    };

    LadbTabOutliner.prototype.replaceNodeRow = function (node, $row) {

        // Remove sub tree
        $('.f-' + node.id, this.$page).remove();

        var parentClasses = $row.attr('class').split(' ').filter(function (c) { return c.startsWith('f-'); }).join(' ');
        var parentEntityLocked = $row.data('parent-entity-locked');
        var parentEntityVisible = $row.data('parent-entity-visible');
        var parentLayerVisible = $row.data('parent-layer-visible');

        // Build new rows
        var $rows = $(Twig.twig({ ref: "tabs/outliner/_list-row-node.twig" }).render({
            node: node,
            parentClasses: parentClasses,
            parentEntityLocked: parentEntityLocked,
            parentEntityVisible: parentEntityVisible,
            parentLayerVisible: parentLayerVisible,
            capabilities: this.dialog.capabilities,
        }));

        // Bind rows
        this.bindNodeRows($('<div>').append($rows));

        // Replace row
        $row.replaceWith($rows);

        this.updateHidden();

    };

    LadbTabOutliner.prototype.findNodeById = function (id, parent) {
        if (parent === undefined) {
            parent = this.rootNode;
        }
        if (parent.id === id) {
            return parent;
        }
        for (var i = 0; i < parent.children.length; i++) {
            var node = this.findNodeById(id, parent.children[i]);
            if (node) {
                return node;
            }
        }
        return null;
    };

    LadbTabOutliner.prototype.showObsolete = function (messageI18nKey, forced) {
        if (!this.isObsolete() || forced) {

            var that = this;

            // Set tab as obsolete
            this.setObsolete(true);

            var $modal = this.appendModalInside('ladb_outliner_modal_obsolete', 'tabs/outliner/_modal-obsolete.twig', {
                messageI18nKey: messageI18nKey
            });

            // Fetch UI elements
            var $btnGenerate = $('#ladb_outliner_obsolete_generate', $modal);

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

    LadbTabOutliner.prototype.bind = function () {
        LadbAbstractTab.prototype.bind.call(this);

        var that = this;

        // Bind buttons
        this.$btnGenerate.on('click', function () {
            that.generateOutliner();
            this.blur();
        });

        // Events

        addEventCallback([ 'on_new_model', 'on_open_model', 'on_activate_model' ], function (params) {
            that.showObsolete('core.event.model_change', true);
        });
        addEventCallback([ 'on_layer_changed', 'on_layer_removed', 'on_layers_folder_changed', 'on_layers_folder_removed', 'on_remove_all_layers' ], function (params) {
            that.showObsolete('core.event.layers_change', true);
        });
        addEventCallback([ 'on_selection_bulk_change' ], function (params) {
            if (!that.ignoreNextSelectionEvents) {
                that.showObsolete('core.event.selection_change', true);
            }
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
            var $this = $(this);
            var data = $this.data('ladb.tab.plugin');
            var options = $.extend({}, LadbTabOutliner.DEFAULTS, $this.data(), typeof option === 'object' && option);

            if (!data) {
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

    var old = $.fn.ladbTabOutliner;

    $.fn.ladbTabOutliner = Plugin;
    $.fn.ladbTabOutliner.Constructor = LadbTabOutliner;


    // NO CONFLICT
    // =================

    $.fn.ladbTabOutliner.noConflict = function () {
        $.fn.ladbTabOutliner = old;
        return this;
    }

}(jQuery);
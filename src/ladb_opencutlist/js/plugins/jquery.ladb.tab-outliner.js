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

    };
    LadbTabOutliner.prototype = Object.create(LadbAbstractTab.prototype);

    LadbTabOutliner.DEFAULTS = {};

    // List /////

    LadbTabOutliner.prototype.generateOutliner = function (callback) {
        var that = this;

        this.materials = [];
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

                // Keep useful data
                that.rootNode = root_node;

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

                // Setup tooltips
                that.dialog.setupTooltips();

                // Bind rows
                $('.ladb-outliner-row', that.$page).each(function (index) {
                    var $row = $(this);
                    $row.on('click', function (e) {
                        $(this).blur();
                        $('.ladb-click-tool', $(this)).click();
                        return false;
                    });
                });
                $('a.ladb-btn-folding-toggle-row', that.$page).on('click', function () {
                    $(this).blur();
                    var $row = $(this).parents('.ladb-outliner-row');
                    var nodeId = $row.data('node-id');
                    that.toggleFoldingNode(nodeId, $row);
                    return false;
                });
                $('a.ladb-btn-open-node-url', that.$page).on('click', function () {
                    $(this).blur();
                    rubyCallCommand('core_open_url', { url: $(this).attr('href') });
                    return false;
                });
                $('a.ladb-btn-node-set-active', that.$page).on('click', function () {
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
                $('a.ladb-btn-node-toggle-visible', that.$page).on('click', function () {
                    $(this).blur();
                    var $i = $('i', $(this));
                    var $row = $(this).parents('.ladb-outliner-row');
                    var nodeId = $row.data('node-id');

                    rubyCallCommand('outliner_toggle_visible', { id: nodeId }, function (response) {

                        if (response['errors']) {
                            that.dialog.notifyErrors(response['errors']);
                        } else {

                            if (response.visible) {
                                $row.removeClass('ladb-mute');
                                $i.addClass('ladb-opencutlist-icon-eye-open');
                                $i.removeClass('ladb-opencutlist-icon-eye-close');
                            } else {
                                $row.addClass('ladb-mute');
                                $i.removeClass('ladb-opencutlist-icon-eye-open');
                                $i.addClass('ladb-opencutlist-icon-eye-close');
                            }

                        }

                    });

                    return false;
                });
                $('a.ladb-btn-node-edit', that.$page).on('click', function () {
                    $(this).blur();
                    var $row = $(this).parents('.ladb-outliner-row');
                    var nodeId = $row.data('node-id');
                    that.editNode(nodeId);
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
            var $btnExplode = $('#ladb_outliner_node_explode', $modal);
            var $btnUpdate = $('#ladb_outliner_node_update', $modal);

            // Bind tabs
            $tabs.on('shown.bs.tab', function (e) {
                that.lastEditNodeTab = $(e.target).attr('href').substring('#tab_edit_node_'.length);
            });

            // Bind input
            $inputName.ladbTextinputText();
            $inputDefinitionName.ladbTextinputText();
            $inputLayerName.ladbTextinputText();
            $inputDescription.ladbTextinputArea();
            $inputUrl.ladbTextinputUrl();

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

                    rubyCallCommand('outliner_explode', that.editedNode, function (response) {

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
                    data['layer_name'] = $inputLayerName.val();
                }
                if ($inputDescription.length > 0) {
                    data['description'] = $inputDescription.val();
                }
                if ($inputUrl.length > 0) {
                    data['url'] = $inputUrl.val();
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
            if (node.expanded) {
                this.expendNodeRow(node, $row);
            } else {
                this.collapseNodeRow(node, $row);
            }
            rubyCallCommand('outliner_set_expanded', node, function (response) {

            });
        }
    };

    LadbTabOutliner.prototype.expendNodeRow = function (node, $row) {
        if (node.expanded) {

            var $btn = $('.ladb-btn-folding-toggle-row', $row);
            var $i = $('i', $btn);

            $i.addClass('ladb-opencutlist-icon-arrow-down');
            $i.removeClass('ladb-opencutlist-icon-arrow-right');

            for (var i = 0; i < node.children.length; i++) {
                $row = $('#ladb_outliner_row_' + node.children[i].id, this.$page);
                $row.removeClass('hide');
                this.expendNodeRow(node.children[i], $row);
            }

        }
    };

    LadbTabOutliner.prototype.collapseNodeRow = function (node, $row) {
        if (!node.expanded) {

            var $btn = $('.ladb-btn-folding-toggle-row', $row);
            var $i = $('i', $btn);

            $i.addClass('ladb-opencutlist-icon-arrow-right');
            $i.removeClass('ladb-opencutlist-icon-arrow-down');

        }
        for (var i = 0; i < node.children.length; i++) {
            $row = $('#ladb_outliner_row_' + node.children[i].id, this.$page);
            $row.addClass('hide');
            this.collapseNodeRow(node.children[i], $row);
        }
    };

    // Internals /////

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
+function ($) {
    'use strict';

    // CLASS DEFINITION
    // ======================

    var LadbTabMaterials = function (element, options, opencutlist) {
        LadbAbstractTab.call(this, element, options, opencutlist);

        this.currency_symbol = '';
        this.massUnitStrippedname = '';
        this.lengthUnitStrippedname = '';
        this.currentMaterial = null;
        this.editedMaterial = null;
        this.ignoreNextMaterialEvents = false;
        this.lastMaterialPropertiesTab = null;

        this.$header = $('.ladb-header', this.$element);
        this.$fileTabs = $('.ladb-file-tabs', this.$header);
        this.$btnList = $('#ladb_btn_list', this.$header);
        this.$btnNew = $('#ladb_btn_new', this.$header);
        this.$btnOptions = $('#ladb_btn_options', this.$header);
        this.$itemImportFromSkm = $('#ladb_item_import_from_skm', this.$header);
        this.$itemPurgeUnused = $('#ladb_item_purge_unused', this.$header);

        this.$page = $('.ladb-page', this.$element);

    };
    LadbTabMaterials.prototype = new LadbAbstractTab;

    LadbTabMaterials.DEFAULTS = {};

    // List /////

    LadbTabMaterials.prototype.loadList = function (callback) {
        var that = this;

        this.materials = [];
        this.$page.empty();
        this.$btnList.prop('disabled', true);
        this.setObsolete(false);

        rubyCallCommand('materials_list', this.generateOptions, function (response) {

            var errors = response.errors;
            var warnings = response.warnings;
            var filename = response.filename;
            var modelName = response.model_name;
            var materials = response.materials;
            var currentMaterialName = response.current_material_name;

            // Keep useful data
            that.lengthUnitStrippedname = response.length_unit_strippedname;
            that.massUnitStrippedname = response.mass_unit_strippedname;
            that.currencySymbol = response.currency_symbol;
            that.materials = materials;

            // Update filename
            that.$fileTabs.empty();
            that.$fileTabs.append(Twig.twig({ ref: "tabs/materials/_file-tab.twig" }).render({
                filename: filename,
                modelName: modelName
            }));

            // Update items state
            that.$itemPurgeUnused.closest('li').toggleClass('disabled', materials == null || materials.length === 0);

            // Update page
            that.$page.empty();
            that.$page.append(Twig.twig({ ref: "tabs/materials/_list.twig" }).render({
                errors: errors,
                warnings: warnings,
                materials: materials,
                currentMaterialName: currentMaterialName
            }));

            // Setup tooltips
            that.dialog.setupTooltips();

            // Bind rows
            $('.ladb-material-box', that.$page).each(function (index) {
                var $box = $(this);
                $box.on('click', function (e) {
                    $(this).blur();
                    $('.ladb-click-tool', $(this)).click();
                    return false;
                });
            });
            $('.ladb-btn-edit-material', that.$page).on('click', function() {
                $(this).blur();
                var materialId = $(this).closest('.ladb-material-box').data('material-id');
                that.editMaterial(materialId);
                return false;
            });
            $('.ladb-btn-set-current', that.$page)
                .on('click', function () {
                    $(this).blur();
                    var materialId = $(this).closest('.ladb-material-box').data('material-id');
                    that.setCurrentMaterial(materialId);
                    return false;
                })
                .on('dblclick', function () {
                    $(this).blur();
                    that.dialog.minimize();
                    return false;
                });

            // Restore button state
            that.$btnList.prop('disabled', false);

            // Stick header
            that.stickSlideHeader(that.$rootSlide);

            // Callback
            if (typeof callback === 'function') {
                callback();
            }

        });

    };

    // Material /////

    LadbTabMaterials.prototype.newMaterial = function (name, color, type) {
        var that = this;

        var material = {
            name: name ? name : '',
            color: color ? color : color,
            attributes: {
                type: type ? type : 0
            }
        };

        var $modal = this.appendModalInside('ladb_materials_modal_new', 'tabs/materials/_modal-new.twig', {
            mass_unit_strippedname: that.massUnitStrippedname,
            length_unit_strippedname: that.lengthUnitStrippedname,
            material: material
        }, true);

        // Fetch UI elements
        var $btnCreate = $('#ladb_materials_create', $modal);

        // Define usefull functions
        var fnUpdateBtnCreateStatus = function() {
            $btnCreate.prop('disabled', $inputs.inputName.data('ladb-invalid') || $inputs.inputColor.data('ladb-invalid'))
        };

        // Bind form
        var $inputs = this.bindMaterialPropertiesForm($modal, material, true);

        // Bind inputs
        $inputs.inputName.on('keyup change', fnUpdateBtnCreateStatus);
        $inputs.inputColor.on('keyup change', fnUpdateBtnCreateStatus);

        // Bind buttons
        $btnCreate.on('click', function () {

            // Flag to ignore next material change event
            that.ignoreNextMaterialEvents = true;

            rubyCallCommand('materials_create', {
                name: $inputs.inputName.val().trim(),
                color: $inputs.inputColor.val(),
                attributes: {
                    type: parseInt($inputs.selectType.val()),
                    thickness: $inputs.inputThickness.val(),
                    length_increase: $inputs.inputLengthIncrease.val(),
                    width_increase: $inputs.inputWidthIncrease.val(),
                    thickness_increase: $inputs.inputThicknessIncrease.val(),
                    std_lengths: $inputs.inputStdLengths.ladbTextinputTokenfield('getValidTokensList'),
                    std_widths: $inputs.inputStdWidths.ladbTextinputTokenfield('getValidTokensList'),
                    std_thicknesses: $inputs.inputStdThicknesses.ladbTextinputTokenfield('getValidTokensList'),
                    std_sections: $inputs.inputStdSections.ladbTextinputTokenfield('getValidTokensList'),
                    std_sizes: $inputs.inputStdSizes.ladbTextinputTokenfield('getValidTokensList'),
                    grained: $inputs.selectGrained.val() === '1',
                    edge_decremented: $inputs.selectEdgeDecremented.val() === '1',
                    volumic_mass: $inputs.inputVolumicMass.ladbTextinputNumberWithUnit('val'),
                    std_prices: $inputs.editorStdPrices.ladbEditorStdPrices('getStdPrices')
                }
            }, function (response) {

                // Flag to stop ignoring next material change event
                that.ignoreNextMaterialEvents = false;

                if (response.errors && response.errors.length > 0) {
                    that.dialog.notifyErrors(response.errors);
                } else {
                    that.loadList();
                }

            });

            // Hide modal
            $modal.modal('hide');

        });

        // Show modal
        $modal.modal('show');

        // Setup tooltips & popovers
        this.dialog.setupTooltips();
        this.dialog.setupPopovers();

        // Focus
        $inputs.inputName.focus();

    };

    LadbTabMaterials.prototype.editMaterial = function (id, propertiesTab, callback, updatedCallback) {
        var that = this;

        var material = this.findMaterialById(id);
        if (material) {

            if (propertiesTab === undefined) {
                propertiesTab = this.lastMaterialPropertiesTab;
            }
            if (propertiesTab === null || propertiesTab.length === 0) {
                propertiesTab = 'cut_options';
            }
            this.lastMaterialPropertiesTab = propertiesTab;

            // Keep the edited material
            this.editedMaterial = material;

            var $modal = this.appendModalInside('ladb_materials_modal_edit', 'tabs/materials/_modal-edit.twig', {
                capabilities: that.dialog.capabilities,
                mass_unit_strippedname: that.massUnitStrippedname,
                length_unit_strippedname: that.lengthUnitStrippedname,
                material: material,
                properties_tab: propertiesTab
            }, true);

            // Fetch UI elements
            var $btnTabTexture = $('#ladb_materials_btn_tab_texture', $modal);
            var $inputTextureRotation = $('#ladb_materials_input_texture_rotation', $modal);
            var $imgTexture = $('#ladb_materials_img_texture', $modal);
            var $btnTextureRotateLeft = $('#ladb_materials_btn_texture_rotate_left', $modal);
            var $btnTextureRotateRight = $('#ladb_materials_btn_texture_rotate_right', $modal);
            var $btnTextureColorized = $('#ladb_materials_btn_texture_colorized', $modal);
            var $inputTextureWidth = $('#ladb_materials_input_texture_width', $modal);
            var $inputTextureHeight = $('#ladb_materials_input_texture_height', $modal);
            var $btnTextureSizeLock = $('#ladb_material_btn_texture_size_lock', $modal);
            var $btnRemove = $('#ladb_materials_remove', $modal);
            var $btnExportToSkm = $('#ladb_materials_export_to_skm', $modal);
            var $btnUpdate = $('#ladb_materials_update', $modal);

            // Bind form
            var $inputs = this.bindMaterialPropertiesForm($modal, material, false, function () {
                $btnExportToSkm.prop('disabled', true);
            });

            // Define usefull functions
            var fnFetchAttributes = function (attributes) {
                attributes.type = parseInt($inputs.selectType.val());
                attributes.thickness = $inputs.inputThickness.val();
                attributes.length_increase = $inputs.inputLengthIncrease.val();
                attributes.width_increase = $inputs.inputWidthIncrease.val();
                attributes.thickness_increase = $inputs.inputThicknessIncrease.val();
                attributes.std_lengths = $inputs.inputStdLengths.ladbTextinputTokenfield('getValidTokensList');
                attributes.std_widths = $inputs.inputStdWidths.ladbTextinputTokenfield('getValidTokensList');
                attributes.std_thicknesses = $inputs.inputStdThicknesses.ladbTextinputTokenfield('getValidTokensList');
                attributes.std_sections = $inputs.inputStdSections.ladbTextinputTokenfield('getValidTokensList');
                attributes.std_sizes = $inputs.inputStdSizes.ladbTextinputTokenfield('getValidTokensList');
                attributes.grained = $inputs.selectGrained.val() === '1';
                attributes.edge_decremented = $inputs.selectEdgeDecremented.val() === '1';
                attributes.volumic_mass = $inputs.inputVolumicMass.ladbTextinputNumberWithUnit('val');
                attributes.std_prices = $inputs.editorStdPrices.ladbEditorStdPrices('getStdPrices');
            };
            var fnRotateTexture = function (angle) {
                var rotation = parseInt($inputTextureRotation.val());
                $imgTexture.parent().removeClass("ladb-rotate" + rotation);
                if (angle < 0 && rotation === 0) {
                    rotation = 360;
                }
                rotation = (rotation + angle) % 360;
                $imgTexture.parent().addClass("ladb-rotate" + rotation);
                $inputTextureRotation.val(rotation);
                if (Math.abs(angle) === 90) {
                    var tw = $inputTextureWidth.val();
                    var th = $inputTextureHeight.val();
                    $inputTextureWidth.val(th);
                    $inputTextureHeight.val(tw);
                    material.texture_ratio = 1 / material.texture_ratio;
                }
                if (!material.texture_colorizable) {
                    $btnTextureColorized.removeClass('hide');
                }
            };
            var fnGetMaterialTexture = function (colorized) {
                rubyCallCommand('materials_get_texture_command', { name: material.name, colorized: colorized }, function (response) {

                    // Add texture file to material
                    material.texture_file = response.texture_file;

                    if (response.texture_colorized) {
                        $btnTextureColorized.addClass('active')
                    }

                    // Update img src with generated texture file
                    $imgTexture.attr('src', material.texture_file);

                });
            };
            var fnComputeSizeAspectRatio = function (isWidthMaster) {
                if ($btnTextureSizeLock.data('locked')) {
                    rubyCallCommand('core_compute_size_aspect_ratio', {
                        width: $inputTextureWidth.val(),
                        height: $inputTextureHeight.val(),
                        ratio: material.texture_ratio,
                        is_width_master: isWidthMaster
                    }, function (response) {
                        $inputTextureWidth.val(response.width);
                        $inputTextureHeight.val(response.height);
                    });
                }
            };
            var fnUpdateBtnUpdateStatus = function() {
                $btnUpdate.prop('disabled', $inputs.inputName.data('ladb-invalid') || $inputs.inputColor.data('ladb-invalid'))
            };

            // Bind inputs
            $inputs.inputName.on('keyup change', fnUpdateBtnUpdateStatus);
            $inputs.inputColor.on('keyup change', fnUpdateBtnUpdateStatus);

            // Bind tabs
            $btnTabTexture.on('shown.bs.tab', function (e) {

                fnGetMaterialTexture(false);

                // Unbind event
                $btnTabTexture.off('shown.bs.tab');
            });

            // Bind buttons
            $btnTextureRotateLeft.on('click', function () {
                fnRotateTexture(-90);
                this.blur();
            });
            $btnTextureRotateRight.on('click', function () {
                fnRotateTexture(90);
                this.blur();
            });
            $btnTextureColorized.on('click', function () {
                $btnTextureColorized.toggleClass('active');
                fnGetMaterialTexture($btnTextureColorized.hasClass('active'));
                this.blur();
            });
            $btnTextureSizeLock.on('click', function () {
                var $i = $('i', $btnTextureSizeLock);
                if ($btnTextureSizeLock.data('locked')) {
                    $i.addClass('ladb-opencutlist-icon-unlock');
                    $i.removeClass('ladb-opencutlist-icon-lock');
                    $btnTextureSizeLock
                        .data('locked', false)
                        .removeClass('active');
                } else {
                    $i.removeClass('ladb-opencutlist-icon-unlock');
                    $i.addClass('ladb-opencutlist-icon-lock');
                    $btnTextureSizeLock
                        .data('locked', true)
                        .addClass('active');
                }
                this.blur();
            });
            $btnRemove.on('click', function () {
                $modal.modal('hide');   // Hide modal
                that.removeMaterial(that.editedMaterial);
                this.blur();
            });
            $btnExportToSkm.on('click', function () {
                that.exportToSkm(that.editedMaterial, true);
                this.blur();
            });
            $btnUpdate.on('click', function () {

                that.editedMaterial.display_name = $inputs.inputName.val().trim();
                that.editedMaterial.color = $inputs.inputColor.val();
                that.editedMaterial.texture_rotation = parseInt($inputTextureRotation.val());
                that.editedMaterial.texture_width = $inputTextureWidth.val();
                that.editedMaterial.texture_height = $inputTextureHeight.val();
                that.editedMaterial.texture_colorized = $btnTextureColorized.hasClass('active');
                fnFetchAttributes(that.editedMaterial.attributes);

                // Flag to ignore next material change event
                that.ignoreNextMaterialEvents = true;

                rubyCallCommand('materials_update', that.editedMaterial, function (response) {

                    // Flag to stop ignoring next material change event
                    that.ignoreNextMaterialEvents = false;

                    if (response['errors']) {
                        that.dialog.notifyErrors(response['errors']);
                    } else {

                        if (typeof updatedCallback === 'function') {
                            updatedCallback();
                        } else {

                            // Reload the list
                            var material_id = that.editedMaterial.id;
                            that.loadList(function() {
                                that.scrollSlideToTarget(null, $('#ladb_material_' + material_id, that.$page), false, true);
                            });

                        }

                        // Reset edited material
                        that.editedMaterial = null;

                        // Hide modal
                        $modal.modal('hide');

                    }

                });

            });

            // Bind inputs
            $inputTextureWidth.on('blur', function () {
                fnComputeSizeAspectRatio(true);
            });
            $inputTextureHeight.on('blur', function () {
                fnComputeSizeAspectRatio(false);
            });

            // Show modal
            $modal.modal('show');

            // Focus
            $inputs.inputName.focus();

            // Setup tooltips & popovers
            this.dialog.setupTooltips();
            this.dialog.setupPopovers();

            // Callback
            if (typeof callback === 'function') {
                callback($modal);
            }

        } else {
            alert('Material not found (id=' + id + ')');
        }
    };

    LadbTabMaterials.prototype.removeMaterial = function (material) {
        var that = this;

        this.dialog.confirm(i18next.t('default.caution'), i18next.t('tab.materials.remove.message', { material_name: material.display_name }), function () {

            // Flag to ignore next material change event
            that.ignoreNextMaterialEvents = true;

            rubyCallCommand('materials_remove', {
                name: material.name,
                display_name: material.display_name
            }, function (response) {

                // Flag to stop ignoring next material change event
                that.ignoreNextMaterialEvents = false;

                if (response.errors && response.errors.length > 0) {
                    that.dialog.notifyErrors(response.errors);
                } else {

                    // Reload the list
                    that.loadList();

                }

            });

        }, {
            confirmBtnType: 'danger',
            confirmBtnLabel: i18next.t('default.remove')
        });

    };

    LadbTabMaterials.prototype.importFromSkm = function () {
        var that = this;

        // Flag to ignore next material change event
        that.ignoreNextMaterialEvents = true;

        rubyCallCommand('materials_import_from_skm', null, function (response) {

            // Flag to stop ignoring next material change event
            that.ignoreNextMaterialEvents = false;

            if (response.errors && response.errors.length > 0) {
                that.dialog.notifyErrors(response.errors);
            } else {
                that.loadList(function() {
                    var $material = $('#ladb_material_' + response.material_id, that.$page);
                    that.scrollSlideToTarget(null, $material, true, true);
                });
            }

        });
    };

    LadbTabMaterials.prototype.exportToSkm = function (material) {
        var that = this;

        rubyCallCommand('materials_export_to_skm', {
            name: material.name,
            display_name: material.display_name
        }, function (response) {

            if (response.errors) {
                that.dialog.notifyErrors(response.errors);
            }
            if (response.export_path) {
                that.dialog.notify(i18next.t('tab.materials.success.exported_to', { export_path: response.export_path }), 'success');
            }

        });
    };

    LadbTabMaterials.prototype.setCurrentMaterial = function (materialId) {
        var material = this.findMaterialById(materialId);
        if (material) {
            rubyCallCommand('materials_set_current_command', {
                name: material.name
            });
        }
    };

    LadbTabMaterials.prototype.purgeUnused = function () {
        var that = this;

        // Flag to ignore next material change event
        that.ignoreNextMaterialEvents = true;

        rubyCallCommand('materials_purge_unused', null, function (response) {

            // Flag to stop ignoring next material change event
            that.ignoreNextMaterialEvents = false;

            if (response.errors && response.errors.length > 0) {
                that.dialog.notifyErrors(response.errors);
            } else {
                that.loadList();
            }

        });
    };

    // Options /////

    LadbTabMaterials.prototype.loadOptions = function (callback) {
        var that = this;

        rubyCallCommand('core_get_model_preset', { dictionary: 'materials_options' }, function (response) {

            that.generateOptions = response.preset;

            // Callback
            if (typeof callback === 'function') {
                callback();
            }

        });

    };

    LadbTabMaterials.prototype.editOptions = function () {
        var that = this;

        var $modal = that.appendModalInside('ladb_materials_modal_options', 'tabs/materials/_modal-options.twig');

        // Fetch UI elements
        var $widgetPreset = $('.ladb-widget-preset', $modal);
        var $sortableMaterialOrderStrategy = $('#ladb_sortable_material_order_strategy', $modal);
        var $btnUpdate = $('#ladb_materials_options_update', $modal);

        // Define useful functions
        var fnFetchOptions = function (options) {

            var properties = [];
            $sortableMaterialOrderStrategy.children('li').each(function () {
                properties.push($(this).data('property'));
            });
            options.material_order_strategy = properties.join('>');

        };
        var fnFillInputs = function (options) {

            // Sortables

            var properties, property, i;

            // Material order sortables

            properties = options.material_order_strategy.split('>');
            $sortableMaterialOrderStrategy.empty();
            for (i = 0; i < properties.length; i++) {
                property = properties[i];
                $sortableMaterialOrderStrategy.append(Twig.twig({ref: "tabs/materials/_option-material-order-strategy-property.twig"}).render({
                    order: property.startsWith('-') ? '-' : '',
                    property: property.startsWith('-') ? property.substr(1) : property
                }));
            }
            $sortableMaterialOrderStrategy.find('a').on('click', function () {
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
            $sortableMaterialOrderStrategy.sortable({
                cursor: 'ns-resize',
                handle: '.ladb-handle'
            });

        };

        $widgetPreset.ladbWidgetPreset({
            dialog: that.dialog,
            dictionary: 'materials_options',
            fnFetchOptions: fnFetchOptions,
            fnFillInputs: fnFillInputs

        });

        // Bind buttons
        $btnUpdate.on('click', function () {

            // Fetch options
            fnFetchOptions(that.generateOptions);

            // Store options
            rubyCallCommand('core_set_model_preset', { dictionary: 'materials_options', values: that.generateOptions });

            // Hide modal
            $modal.modal('hide');

            // Reload the list
            that.loadList();

        });

        // Populate inputs
        fnFillInputs(that.generateOptions);

        // Show modal
        $modal.modal('show');

        // Setup popovers
        this.dialog.setupPopovers();

    };

    // Internals /////

    LadbTabMaterials.prototype.findMaterialById = function (id) {
        var material;
        for (var i = 0; i < this.materials.length; i++) {
            material = this.materials[i];
            if (material.id === id) {
                return material;
            }
        }
        return null;
    };

    LadbTabMaterials.prototype.showObsolete = function (messageI18nKey, forced) {
        if (!this.isObsolete() || forced) {

            var that = this;

            // Set tab as obsolete
            this.setObsolete(true);

            var $modal = this.appendModalInside('ladb_materials_modal_obsolete', 'tabs/materials/_modal-obsolete.twig', {
                messageI18nKey: messageI18nKey
            });

            // Fetch UI elements
            var $btnRefresh = $('#ladb_materials_obsolete_refresh', $modal);

            // Bind buttons
            $btnRefresh.on('click', function () {
                $modal.modal('hide');
                that.loadList();
            });

            // Show modal
            $modal.modal('show');

        }
    };

    LadbTabMaterials.prototype.bindMaterialPropertiesForm = function ($modal, material, setAttributeToDefaults, inputChangeCallback) {
        var that = this;

        // Fetch UI elements
        var $tabs = $('a[data-toggle="tab"]', $modal);
        var $widgetPreset = $('.ladb-widget-preset', $modal);
        var $btnTabAttributes = $('#ladb_materials_btn_tab_general_attributes', $modal);
        var $inputName = $('#ladb_materials_input_name', $modal);
        var $inputNameWarning = $('#ladb_materials_input_name_warning', $modal);
        var $inputColor = $('#ladb_materials_input_color', $modal);
        var $inputColorWarning = $('#ladb_materials_input_color_warning', $modal);
        var $selectType = $('#ladb_materials_input_type', $modal);
        var $inputThickness = $('#ladb_materials_input_thickness', $modal);
        var $inputLengthIncrease = $('#ladb_materials_input_length_increase', $modal);
        var $inputWidthIncrease = $('#ladb_materials_input_width_increase', $modal);
        var $inputThicknessIncrease = $('#ladb_materials_input_thickness_increase', $modal);
        var $inputStdLengths = $('#ladb_materials_input_std_lengths', $modal);
        var $inputStdWidths = $('#ladb_materials_input_std_widths', $modal);
        var $inputStdThicknesses = $('#ladb_materials_input_std_thicknesses', $modal);
        var $inputStdSections = $('#ladb_materials_input_std_sections', $modal);
        var $inputStdSizes = $('#ladb_materials_input_std_sizes', $modal);
        var $selectGrained = $('#ladb_materials_select_grained', $modal);
        var $selectEdgeDecremented = $('#ladb_materials_select_edge_decremented', $modal);
        var $inputVolumicMass = $('#ladb_materials_input_volumic_mass', $modal);
        var $editorStdPrices = $('#ladb_materials_editor_std_prices', $modal);

        // Define usefull functions
        var fnFetchType = function (options) {
            options.type = parseInt($selectType.val());
        };
        var fnFetchStds = function (options) {
            options.std_lengths = $inputStdLengths.ladbTextinputTokenfield('getValidTokensList');
            options.std_widths = $inputStdWidths.ladbTextinputTokenfield('getValidTokensList');
            options.std_thicknesses = $inputStdThicknesses.ladbTextinputTokenfield('getValidTokensList');
            options.std_sections = $inputStdSections.ladbTextinputTokenfield('getValidTokensList');
            options.std_sizes = $inputStdSizes.ladbTextinputTokenfield('getValidTokensList');
        };
        var fnFetchOptions = function (options) {
            fnFetchType(options);
            options.thickness = $inputThickness.val();
            options.length_increase = $inputLengthIncrease.val();
            options.width_increase = $inputWidthIncrease.val();
            options.thickness_increase = $inputThicknessIncrease.val();
            fnFetchStds(options);
            options.grained = $selectGrained.val() === '1';
            options.edge_decremented = $selectEdgeDecremented.val() === '1';
            options.volumic_mass = $inputVolumicMass.ladbTextinputNumberWithUnit('val');
            options.std_prices = $editorStdPrices.ladbEditorStdPrices('getStdPrices');
        };
        var fnFillInputs = function (options) {
            var fnSetTokens = function ($input, tokens) {
                // Workaround for empty string tokens
                $input.tokenfield('setTokens', tokens === '' ? ' ' : tokens);
            };
            $inputThickness.val(options.thickness);
            $inputLengthIncrease.val(options.length_increase);
            $inputWidthIncrease.val(options.width_increase);
            $inputThicknessIncrease.val(options.thickness_increase);
            fnSetTokens($inputStdLengths, options.std_lengths);
            fnSetTokens($inputStdWidths, options.std_widths);
            fnSetTokens($inputStdThicknesses, options.std_thicknesses);
            fnSetTokens($inputStdSections, options.std_sections);
            fnSetTokens($inputStdSizes, options.std_sizes);
            $selectGrained.selectpicker('val', options.grained ? '1' : '0');
            $selectEdgeDecremented.selectpicker('val', options.edge_decremented ? '1' : '0');
            $inputVolumicMass.ladbTextinputNumberWithUnit('val', options.volumic_mass);
            fnSetStdPricesTypeAndStds();
            $editorStdPrices.ladbEditorStdPrices('setStdPrices', [ options.std_prices ]);
        };
        var fnSetStdPricesTypeAndStds = function () {
            var options = {};
            fnFetchType(options);
            fnFetchStds(options);
            $editorStdPrices.ladbEditorStdPrices('setTypeAndStds', [
                options.type,
                {
                    stdLengths: options.std_lengths ? options.std_lengths.split(';') : [],
                    stdWidths: options.std_widths ? options.std_widths.split(';') : [],
                    stdThicknesses: options.std_thicknesses ? options.std_thicknesses.split(';') : [],
                    stdSections: options.std_sections ? options.std_sections.split(';') : [],
                    stdSizes: options.std_sizes ? options.std_sizes.split(';') : [],
                }
            ]);
        };
        var fnComputeFieldsVisibility = function (type) {
            switch (type) {
                case 0:   // TYPE_UNKNOWN
                    $inputThickness.closest('section').hide();
                    break;
                case 1:   // TYPE_SOLID_WOOD
                    $inputThickness.closest('section').show();
                    $inputThickness.closest('.form-group').hide();
                    $inputLengthIncrease.closest('.form-group').show();
                    $inputWidthIncrease.closest('.form-group').show();
                    $inputThicknessIncrease.closest('.form-group').show();
                    $inputStdLengths.closest('.form-group').hide();
                    $inputStdWidths.closest('.form-group').hide();
                    $inputStdThicknesses.closest('.form-group').show();
                    $inputStdSections.closest('.form-group').hide();
                    $inputStdSizes.closest('.form-group').hide();
                    $selectGrained.closest('.form-group').hide();
                    $selectEdgeDecremented.closest('.form-group').hide();
                    $inputVolumicMass.closest('.form-group').show();
                    $editorStdPrices.closest('.form-group').show();
                    break;
                case 2:   // TYPE_SHEET_GOOD
                    $inputThickness.closest('section').show();
                    $inputThickness.closest('.form-group').hide();
                    $inputLengthIncrease.closest('.form-group').show();
                    $inputWidthIncrease.closest('.form-group').show();
                    $inputThicknessIncrease.closest('.form-group').hide();
                    $inputStdLengths.closest('.form-group').hide();
                    $inputStdWidths.closest('.form-group').hide();
                    $inputStdThicknesses.closest('.form-group').show();
                    $inputStdSections.closest('.form-group').hide();
                    $inputStdSizes.closest('.form-group').show();
                    $selectGrained.closest('.form-group').show();
                    $selectEdgeDecremented.closest('.form-group').hide();
                    $inputVolumicMass.closest('.form-group').show();
                    $editorStdPrices.closest('.form-group').show();
                    break;
                case 3:   // TYPE_DIMENSIONAL
                    $inputThickness.closest('section').show();
                    $inputThickness.closest('.form-group').hide();
                    $inputLengthIncrease.closest('.form-group').show();
                    $inputWidthIncrease.closest('.form-group').hide();
                    $inputThicknessIncrease.closest('.form-group').hide();
                    $inputStdLengths.closest('.form-group').show();
                    $inputStdWidths.closest('.form-group').hide();
                    $inputStdThicknesses.closest('.form-group').hide();
                    $inputStdSections.closest('.form-group').show();
                    $inputStdSizes.closest('.form-group').hide();
                    $selectGrained.closest('.form-group').hide();
                    $selectEdgeDecremented.closest('.form-group').hide();
                    $inputVolumicMass.closest('.form-group').show();
                    $editorStdPrices.closest('.form-group').show();
                    break;
                case 4:   // TYPE_EDGE
                    $inputThickness.closest('section').show();
                    $inputThickness.closest('.form-group').show();
                    $inputLengthIncrease.closest('.form-group').show();
                    $inputWidthIncrease.closest('.form-group').hide();
                    $inputThicknessIncrease.closest('.form-group').hide();
                    $inputStdLengths.closest('.form-group').hide();
                    $inputStdWidths.closest('.form-group').show();
                    $inputStdThicknesses.closest('.form-group').hide();
                    $inputStdSections.closest('.form-group').hide();
                    $inputStdSizes.closest('.form-group').hide();
                    $selectGrained.closest('.form-group').hide();
                    $selectEdgeDecremented.closest('.form-group').show();
                    $inputVolumicMass.closest('.form-group').show();
                    $editorStdPrices.closest('.form-group').show();
                    break;
                case 5:   // TYPE_HARDWARE
                    $inputThickness.closest('section').hide();
                    break;
                default:
                    $inputThickness.closest('section').hide();
            }
        };
        var fnCheckInputNameValue = function(verbose) {
            if ($inputName.val().length > 0) {
                $inputName.data('ladb-invalid', false);
                if (verbose) {
                    $inputNameWarning.hide();
                }
            } else {
                $inputName.data('ladb-invalid', true);
                if (verbose) {
                    $inputNameWarning.show();
                }
            }
        };
        var fnCheckInputColorValue = function(verbose) {
            if ($inputColor.val().match(/^#[0-9a-f]{6}$/i)) {
                $inputColor.data('ladb-invalid', false);
                if (verbose) {
                    $inputColorWarning.hide();
                }
            } else {
                $inputColor.data('ladb-invalid', true);
                if (verbose) {
                    $inputColorWarning.show();
                }
            }
        };

        $widgetPreset.ladbWidgetPreset({
            dialog: that.dialog,
            dictionary: 'materials_material_attributes',
            section: material.attributes.type,
            fnFetchOptions: fnFetchOptions,
            fnFillInputs: fnFillInputs
        });
        $inputVolumicMass.ladbTextinputNumberWithUnit({
            defaultUnit: that.massUnitStrippedname + '_' + that.lengthUnitStrippedname + '3',
            units: [
                {
                    kg_m3: 'kg / m³',
                    kg_ft3: 'kg / ft³'
                },
                {
                    lb_ft3: 'lb / ft³',
                    lb_m3: 'lb / m³'
                },
            ]
        });
        $editorStdPrices.ladbEditorStdPrices({
            currencySymbol: that.currencySymbol,
            lengthUnitStrippedname: that.lengthUnitStrippedname,
            inputChangeCallback: inputChangeCallback
        });

        // Bind tab
        $tabs.on('shown.bs.tab', function (e) {
            that.lastMaterialPropertiesTab = $(e.target).attr('href').substring('#tab_edit_material_general_'.length);
        })

        $btnTabAttributes.on('shown.bs.tab', function () {
            fnSetStdPricesTypeAndStds();
        });

        // Bind select
        $selectType.on('change', function () {
            var options = {};
            fnFetchType(options);

            fnComputeFieldsVisibility(options.type);

            // Update section on preset widget
            $widgetPreset.ladbWidgetPreset('setSection', options.type);

            // Reset fields to defaults
            $widgetPreset.ladbWidgetPreset('restoreFromPreset', [ null, true ]);

        });
        $selectType.selectpicker(SELECT_PICKER_OPTIONS);
        $selectGrained.selectpicker(SELECT_PICKER_OPTIONS);
        $selectEdgeDecremented.selectpicker(SELECT_PICKER_OPTIONS);

        // Bind inputs
        $inputName.on('keyup change', function() { fnCheckInputNameValue(true); });
        $inputColor.on('keyup change', function() { fnCheckInputColorValue(true); });
        $inputColor.ladbTextinputColor();

        // Bind modal event
        $modal.on('shown.bs.modal', function() {

            // Init textinputs
            $inputThickness.ladbTextinputDimension();
            $inputLengthIncrease.ladbTextinputDimension();
            $inputWidthIncrease.ladbTextinputDimension();
            $inputThicknessIncrease.ladbTextinputDimension();

            // Init tokenfields (this must done after modal shown for correct token label max width measurement)
            $inputStdLengths.ladbTextinputTokenfield({ format: 'd' });
            $inputStdWidths.ladbTextinputTokenfield({ format: 'd' });
            $inputStdThicknesses.ladbTextinputTokenfield({ format: 'd' });
            $inputStdSections.ladbTextinputTokenfield({ format: 'dxd' });
            $inputStdSizes.ladbTextinputTokenfield({ format: 'dxd' });

            if (setAttributeToDefaults) {
                $widgetPreset.ladbWidgetPreset('restoreFromPreset', [ null, true ]);
            } else {
                fnFillInputs(material.attributes);
            }

            if (inputChangeCallback) {
                // Bind change
                $('input', $modal).on('change', function () {
                    inputChangeCallback();
                });
            }

        });

        // Initials
        fnComputeFieldsVisibility(material.attributes.type);
        fnCheckInputNameValue(false);
        fnCheckInputColorValue(false);

        return {
            inputName: $inputName,
            inputColor: $inputColor,
            selectType: $selectType,
            inputThickness: $inputThickness,
            inputLengthIncrease: $inputLengthIncrease,
            inputWidthIncrease: $inputWidthIncrease,
            inputThicknessIncrease: $inputThicknessIncrease,
            inputStdLengths: $inputStdLengths,
            inputStdWidths: $inputStdWidths,
            inputStdThicknesses: $inputStdThicknesses,
            inputStdSections: $inputStdSections,
            inputStdSizes: $inputStdSizes,
            selectGrained: $selectGrained,
            selectEdgeDecremented: $selectEdgeDecremented,
            inputVolumicMass: $inputVolumicMass,
            editorStdPrices: $editorStdPrices,
        }
    };

    // Init ///

    LadbTabMaterials.prototype.registerCommands = function () {
        LadbAbstractTab.prototype.registerCommands.call(this);

        var that = this;

        this.registerCommand('new_material', function (parameters) {
            setTimeout(function () {     // Use setTimeout to give time to UI to refresh
                var name = parameters.name;
                var color = parameters.color;
                var type = parameters.type;
                that.newMaterial(name, color, type);
            }, 1);
        });
        this.registerCommand('edit_material', function (parameters) {
            var materialId = parameters.materialId;
            var propertiesTab = parameters.propertiesTab;
            var callback = parameters.callback;
            var updatedCallback = parameters.updatedCallback;
            setTimeout(function () {     // Use setTimeout to give time to UI to refresh
                that.loadList(function () {
                    that.editMaterial(materialId, propertiesTab, callback, updatedCallback);
                });
            }, 1);
        });
    };

    LadbTabMaterials.prototype.bind = function () {
        LadbAbstractTab.prototype.bind.call(this);

        var that = this;

        // Bind buttons
        this.$btnList.on('click', function () {
            that.loadList();
            this.blur();
        });
        this.$btnNew.on('click', function () {
            that.newMaterial();
            this.blur();
        });
        this.$btnOptions.on('click', function () {
            that.editOptions();
            this.blur();
        });
        this.$itemImportFromSkm.on('click', function () {
            that.importFromSkm();
            this.blur();
        });
        this.$itemPurgeUnused.on('click', function () {
            that.purgeUnused();
            this.blur();
        });

        // Events

        addEventCallback([ 'on_new_model', 'on_open_model', 'on_activate_model' ], function (params) {
            that.showObsolete('core.event.model_change', true);
        });
        addEventCallback('on_options_provider_changed', function () {
            that.showObsolete('core.event.options_change', true);
        });
        addEventCallback('on_model_preset_changed', function (params) {
            if (params.dictionary === 'settings_model') {
                that.showObsolete('core.event.options_change', true);
            }
        });
        addEventCallback([ 'on_material_add', 'on_material_remove', 'on_material_change' ], function () {
            if (!that.ignoreNextMaterialEvents) {
                that.showObsolete('core.event.material_change', true);
            }
        });
        addEventCallback([ 'on_material_set_current' ], function (params) {
            for (var i = 0; i < that.materials.length; i++) {
                if (that.materials[i].name === params.material_name) {
                    if (that.currentMaterial !== that.materials[i]) {
                        that.currentMaterial = that.materials[i];
                        $('.ladb-material-box').removeClass('ladb-active');
                        $('.ladb-material-box[data-material-id="' + that.currentMaterial.id + '"]').addClass('ladb-active');
                    }
                    break;
                }
            }
        });

    };

    LadbTabMaterials.prototype.processInitializedCallback = function (initializedCallback) {
        var that = this;

        // Load Options
        that.loadOptions(function () {
            LadbAbstractTab.prototype.processInitializedCallback.call(that, initializedCallback);
        });

    };

    LadbTabMaterials.prototype.defaultInitializedCallback = function () {
        LadbAbstractTab.prototype.defaultInitializedCallback.call(this);

        this.loadList();

    };


    // PLUGIN DEFINITION
    // =======================

    function Plugin(option, params) {
        return this.each(function () {
            var $this = $(this);
            var data = $this.data('ladb.tab.plugin');
            var options = $.extend({}, LadbTabMaterials.DEFAULTS, $this.data(), typeof option === 'object' && option);

            if (!data) {
                if (undefined === options.dialog) {
                    throw 'dialog option is mandatory.';
                }
                $this.data('ladb.tab.plugin', (data = new LadbTabMaterials(this, options, options.dialog)));
            }
            if (typeof option === 'string') {
                data[option].apply(data, Array.isArray(params) ? params : [ params ])
            } else {
                data.init(option.initializedCallback);
            }
        })
    }

    var old = $.fn.ladbTabMaterials;

    $.fn.ladbTabMaterials = Plugin;
    $.fn.ladbTabMaterials.Constructor = LadbTabMaterials;


    // NO CONFLICT
    // =================

    $.fn.ladbTabMaterials.noConflict = function () {
        $.fn.ladbTabMaterials = old;
        return this;
    }

}(jQuery);

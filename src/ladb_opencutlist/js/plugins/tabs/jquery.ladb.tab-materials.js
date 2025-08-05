+function ($) {
    'use strict';

    // CLASS DEFINITION
    // ======================

    const LadbTabMaterials = function (element, options, dialog) {
        LadbAbstractTab.call(this, element, options, dialog);

        this.currencySymbol = '';
        this.massUnitStrippedname = '';
        this.lengthUnitStrippedname = '';
        this.currentMaterial = null;
        this.editedMaterial = null;
        this.ignoreNextMaterialEvents = false;
        this.lastOptionsTab = null;
        this.lastEditMaterialTab = null;
        this.lastMaterialPropertiesTab = null;

        this.$header = $('.ladb-header', this.$element);
        this.$fileTabs = $('.ladb-file-tabs', this.$header);
        this.$btnList = $('#ladb_btn_list', this.$header);
        this.$btnNew = $('#ladb_btn_new', this.$header);
        this.$btnImport = $('#ladb_btn_import', this.$header);
        this.$btnOptions = $('#ladb_btn_options', this.$header);
        this.$itemPurgeUnused = $('#ladb_item_purge_unused', this.$header);
        this.$itemResetPrices = $('#ladb_item_reset_prices', this.$header);

        this.$page = $('.ladb-page', this.$element);

    };
    LadbTabMaterials.prototype = Object.create(LadbAbstractTab.prototype);

    LadbTabMaterials.DEFAULTS = {};

    // List /////

    LadbTabMaterials.prototype.loadList = function (callback) {
        const that = this;

        this.materials = [];
        this.$page.empty();
        this.$btnList.prop('disabled', true);
        this.setObsolete(false);

        window.requestAnimationFrame(function () {

            // Start progress feedback
            that.dialog.startProgress(1);

            rubyCallCommand('materials_list', that.generateOptions, function (response) {

                const errors = response.errors;
                const warnings = response.warnings;
                const filename = response.filename;
                const modelName = response.model_name;
                const materials = response.materials;

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
                    showTypeSeparators: response.show_type_separators && (that.generateOptions.material_order_strategy.startsWith('type') || that.generateOptions.material_order_strategy.startsWith('-type')),
                    materials: materials
                }));

                // Setup tooltips
                that.dialog.setupTooltips();

                // Bind rows
                $('.ladb-material-box', that.$page).each(function (index) {
                    const $box = $(this);
                    $box.on('click', function (e) {
                        $(this).blur();
                        $('.ladb-click-tool', $(this)).click();
                        return false;
                    });
                });
                $('.ladb-btn-edit-material', that.$page).on('click', function() {
                    $(this).blur();
                    const materialId = $(this).closest('.ladb-material-box').data('material-id');
                    that.editMaterial(materialId);
                    return false;
                });
                $('.ladb-btn-set-current', that.$page)
                    .on('click', function () {
                        $(this).blur();
                        const materialId = $(this).closest('.ladb-material-box').data('material-id');
                        that.setCurrentMaterial(materialId);
                        if (that.generateOptions.minimize_on_smart_paint) {
                            that.dialog.minimize();
                        }
                        return false;
                    });
                $('.ladb-btn-open-material-url', that.$page)
                    .on('click', function () {
                        $(this).blur();
                        rubyCallCommand('core_open_url', { url: $(this).attr('href') });
                        return false;
                    })

                // Restore button state
                that.$btnList.prop('disabled', false);

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

    // Material /////

    LadbTabMaterials.prototype.newMaterial = function (name, color, type) {
        const that = this;

        const material = {
            name: name ? name : '',
            color: color ? color : '',
            attributes: {
                type: type ? type : 0,
                description: '',
                url: ''
            }
        };

        const $modal = this.appendModalInside('ladb_materials_modal_new', 'tabs/materials/_modal-new.twig', {
            capabilities: that.dialog.capabilities,
            mass_unit_strippedname: that.massUnitStrippedname,
            length_unit_strippedname: that.lengthUnitStrippedname,
            material: material
        });

        // Fetch UI elements
        const $btnCreate = $('#ladb_materials_create', $modal);

        // Define useful functions
        const fnUpdateBtnCreateStatus = function() {
            $btnCreate.prop('disabled', $inputs.inputName.data('ladb-invalid') || $inputs.inputColor.data('ladb-invalid'))
        };

        // Bind form
        const $inputs = this.bindMaterialPropertiesForm($modal, material, true);

        // Bind inputs
        $inputs.inputName.on('keyup change', fnUpdateBtnCreateStatus);
        $inputs.inputColor.on('keyup change', fnUpdateBtnCreateStatus);

        // Bind buttons
        $btnCreate.on('click', function () {

            // Flag to ignore the next material change event
            that.ignoreNextMaterialEvents = true;

            rubyCallCommand('materials_create', {
                name: $inputs.inputName.val().trim(),
                color: $inputs.inputColor.val(),
                attributes: {
                    type: parseInt($inputs.selectType.val()),
                    description: $inputs.inputDescription.val(),
                    url: $inputs.inputUrl.val(),
                    thickness: $inputs.inputThickness.val(),
                    length_increase: $inputs.inputLengthIncrease.val(),
                    width_increase: $inputs.inputWidthIncrease.val(),
                    thickness_increase: $inputs.inputThicknessIncrease.val(),
                    std_sections: $inputs.editorStdSections.ladbEditorSizes('getSizes'),
                    std_lengths: $inputs.editorStdLengths.ladbEditorSizes('getSizes'),
                    std_widths: $inputs.editorStdWidths.ladbEditorSizes('getSizes'),
                    std_thicknesses: $inputs.editorStdThicknesses.ladbEditorSizes('getSizes'),
                    std_sizes: $inputs.editorStdSizes.ladbEditorSizes('getSizes'),
                    grained: $inputs.selectGrained.val() === '1',
                    edge_decremented: $inputs.selectEdgeDecremented.val() === '1',
                    raw_estimated: $inputs.selectRawEstimated.val() === '1',
                    multiplier_coefficient: Math.max(1.0, $inputs.inputMultiplierCoefficient.val() === '' ? 1.0 : parseFloat($inputs.inputMultiplierCoefficient.val().replace(',', '.'))),
                    std_volumic_masses: $inputs.editorStdVolumicMasses.ladbEditorStdAttributes('getStdAttributes'),
                    std_prices: $inputs.editorStdPrices.ladbEditorStdAttributes('getStdAttributes'),
                    std_cut_prices: $inputs.editorStdCutPrices.ladbEditorStdAttributes('getStdAttributes')
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

    };

    LadbTabMaterials.prototype.editMaterial = function (id, tab, propertiesTab, callback, updatedCallback) {
        const that = this;

        const material = this.findMaterialById(id);
        if (material) {

            if (tab === undefined) {
                tab = this.lastEditMaterialTab;
            }
            if (tab === null || tab.length === 0) {
                tab = 'general';
            }
            this.lastEditMaterialTab = tab;

            if (propertiesTab === undefined) {
                propertiesTab = this.lastMaterialPropertiesTab;
            }
            if (propertiesTab === null || propertiesTab.length === 0) {
                propertiesTab = 'formats';
            }
            this.lastMaterialPropertiesTab = propertiesTab;

            // Keep the edited material
            this.editedMaterial = material;

            const $modal = this.appendModalInside('ladb_materials_modal_edit', 'tabs/materials/_modal-edit.twig', {
                capabilities: that.dialog.capabilities,
                mass_unit_strippedname: that.massUnitStrippedname,
                length_unit_strippedname: that.lengthUnitStrippedname,
                material: material,
                tab: tab,
                properties_tab: propertiesTab
            });

            // Fetch UI elements
            const $tabs = $('.modal-header a[data-toggle="tab"]', $modal);
            const $btnTabTexture = $('#ladb_materials_btn_tab_texture', $modal);
            const $inputTextureChanged = $('#ladb_materials_input_texture_changed', $modal);
            const $inputTextureRatio = $('#ladb_materials_input_texture_ratio', $modal);
            const $inputTextureRotation = $('#ladb_materials_input_texture_rotation', $modal);
            const $divTextureThumbnail = $('#ladb_materials_div_texture_thumbnail', $modal);
            const $imgTexture = $('#ladb_materials_img_texture', $modal);
            const $spanTextureWidth = $('#ladb_materials_span_texture_width', $modal);
            const $spanTextureHeight = $('#ladb_materials_span_texture_height', $modal);
            const $btnTextureLoad = $('#ladb_materials_btn_texture_load', $modal);
            const $btnTextureExport = $('#ladb_materials_btn_texture_export', $modal);
            const $btnTextureClear = $('#ladb_materials_btn_texture_clear', $modal);
            const $btnTextureRotateLeft = $('#ladb_materials_btn_texture_rotate_left', $modal);
            const $btnTextureRotateRight = $('#ladb_materials_btn_texture_rotate_right', $modal);
            const $inputTextureWidth = $('#ladb_materials_input_texture_width', $modal);
            const $inputTextureHeight = $('#ladb_materials_input_texture_height', $modal);
            const $btnTextureSizeLock = $('#ladb_material_btn_texture_size_lock', $modal);
            const $btnDelete = $('#ladb_materials_delete', $modal);
            const $btnDuplicate = $('#ladb_materials_duplicate', $modal);
            const $btnExportToSkm = $('#ladb_materials_export_to_skm', $modal);
            const $btnUpdate = $('#ladb_materials_update', $modal);

            // Bind form
            const $inputs = this.bindMaterialPropertiesForm($modal, material, false, function () {
                $btnExportToSkm.prop('disabled', true);
            });

            // Define useful functions
            const fnFetchAttributes = function (attributes) {
                attributes.type = parseInt($inputs.selectType.val());
                attributes.description = $inputs.inputDescription.val();
                attributes.url = $inputs.inputUrl.val();
                attributes.thickness = $inputs.inputThickness.val();
                attributes.length_increase = $inputs.inputLengthIncrease.val();
                attributes.width_increase = $inputs.inputWidthIncrease.val();
                attributes.thickness_increase = $inputs.inputThicknessIncrease.val();
                attributes.std_sections = $inputs.editorStdSections.ladbEditorSizes('getSizes');
                attributes.std_lengths = $inputs.editorStdLengths.ladbEditorSizes('getSizes');
                attributes.std_widths = $inputs.editorStdWidths.ladbEditorSizes('getSizes');
                attributes.std_thicknesses = $inputs.editorStdThicknesses.ladbEditorSizes('getSizes');
                attributes.std_sizes = $inputs.editorStdSizes.ladbEditorSizes('getSizes');
                attributes.grained = $inputs.selectGrained.val() === '1';
                attributes.edge_decremented = $inputs.selectEdgeDecremented.val() === '1';
                attributes.raw_estimated = $inputs.selectRawEstimated.val() === '1';
                attributes.multiplier_coefficient = Math.max(1.0, $inputs.inputMultiplierCoefficient.val() === '' ? 1.0 : parseFloat($inputs.inputMultiplierCoefficient.val().replace(',', '.')));
                attributes.std_volumic_masses = $inputs.editorStdVolumicMasses.ladbEditorStdAttributes('getStdAttributes');
                attributes.std_prices = $inputs.editorStdPrices.ladbEditorStdAttributes('getStdAttributes');
                attributes.std_cut_prices = $inputs.editorStdCutPrices.ladbEditorStdAttributes('getStdAttributes');
            };
            const fnResetTextureRotation = function () {
                const rotation = parseInt($inputTextureRotation.val());
                $imgTexture.parent().removeClass("ladb-rotate" + rotation);
                $inputTextureRotation.val(0);
            }
            const fnRotateTexture = function (angle) {
                let rotation = parseInt($inputTextureRotation.val());
                $imgTexture.parent().removeClass("ladb-rotate" + rotation);
                if (angle < 0 && rotation === 0) {
                    rotation = 360;
                }
                rotation = (rotation + angle) % 360;
                $imgTexture.parent().addClass("ladb-rotate" + rotation);
                $inputTextureRotation.val(rotation);
                if (Math.abs(angle) === 90) {
                    const tw = $inputTextureWidth.val();
                    const th = $inputTextureHeight.val();
                    $inputTextureWidth.val(th);
                    $inputTextureHeight.val(tw);
                    material.texture_ratio = 1 / material.texture_ratio;
                }
            };
            const fnGetMaterialTexture = function () {
                if (material.textured) {
                    rubyCallCommand('materials_get_texture_command', {
                        name: material.name
                    }, function (response) {

                        if (response.errors) {
                            that.dialog.notifyErrors(response.errors);
                        } else if (response.texture_file) {

                            // Update img src with generated texture file
                            $imgTexture.attr('src', response.texture_file);

                            // Refresh UI
                            fnUpdateTextureTab();

                        }

                    });
                } else {
                    // Refresh UI
                    fnUpdateTextureTab();
                }
            };
            const fnComputeSizeAspectRatio = function (isWidthMaster) {
                if ($btnTextureSizeLock.data('locked')) {
                    rubyCallCommand('core_compute_size_aspect_ratio', {
                        width: $inputTextureWidth.val() ? $inputTextureWidth.val() : '1m',
                        height: $inputTextureHeight.val() ? $inputTextureHeight.val() : '1m',
                        ratio: $inputTextureRatio.val() ? parseFloat($inputTextureRatio.val()) : 1.0,
                        is_width_master: isWidthMaster
                    }, function (response) {
                        $inputTextureWidth.val(response.width);
                        $inputTextureHeight.val(response.height);
                    });
                }
            };
            const fnUpdateBtnUpdateStatus = function() {
                $btnUpdate.prop('disabled', $inputs.inputName.data('ladb-invalid') || $inputs.inputColor.data('ladb-invalid'))
            };
            const fnUpdateTextureTab = function () {
                if ($imgTexture.attr('src') !== '') {
                    $('.ladb-hidden-no-texture', $modal).show();
                    $('.ladb-hidden-textured', $modal).hide();
                } else {
                    $('.ladb-hidden-no-texture', $modal).hide();
                    $('.ladb-hidden-textured', $modal).show();
                }
            }

            if (tab === 'texture') {
                fnGetMaterialTexture(false);
            }

            // Bind img
            $imgTexture.on('load', function() {
                $divTextureThumbnail.show();
                $spanTextureWidth.html(this.naturalWidth);
                $spanTextureHeight.html(this.naturalHeight);
            });

            // Bind inputs
            $inputs.inputName.on('keyup change', fnUpdateBtnUpdateStatus);
            $inputs.inputColor.on('keyup change', fnUpdateBtnUpdateStatus);
            $inputTextureWidth
                .ladbTextinputDimension({
                    resetValue: '1m'
                })
                .on('blur', function () {
                    fnComputeSizeAspectRatio(true);
                });
            $inputTextureHeight
                .ladbTextinputDimension({
                    resetValue: '1m'
                })
                .on('blur', function () {
                    fnComputeSizeAspectRatio(false);
                });

            // Bind tabs
            $tabs.on('shown.bs.tab', function (e) {
                that.lastEditMaterialTab = $(e.target).attr('href').substring('#tab_edit_material_'.length);
            });
            $btnTabTexture.on('shown.bs.tab', function (e) {
                if ($imgTexture.attr('src') === '') {
                    fnGetMaterialTexture(false);
                }
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
            $btnTextureLoad.on('click', function () {
                rubyCallCommand('materials_load_texture_command', null, function (response) {

                    if (response.errors) {
                        that.dialog.notifyErrors(response.errors);
                    } else if (response.texture_file) {

                        // Reset previous rotation
                        fnResetTextureRotation();

                        // Add texture infos
                        $inputTextureRatio.val(response.texture_ratio);
                        $inputTextureChanged.val(true);

                        // Update img src with generated texture file
                        $imgTexture.attr('src', response.texture_file);

                        // Re-compute size
                        fnComputeSizeAspectRatio(true);

                        // Refresh UI
                        fnUpdateTextureTab();

                    }

                });
                this.blur();
            });
            $btnTextureExport.on('click', function () {
                rubyCallCommand('materials_export_texture_command', { name: material.name }, function (response) {

                    if (response.errors) {
                        that.dialog.notifyErrors(response.errors);
                    }
                    if (response.export_path) {
                        that.dialog.notifySuccess(i18next.t('core.success.exported_to', { path: response.export_path }));
                    }

                });
                this.blur();
            });
            $btnTextureClear.on('click', function () {

                // Reset img src
                $imgTexture.attr('src', '');

                // Add texture infos
                $inputTextureChanged.val(true);

                // Refresh UI
                fnUpdateTextureTab();

            });
            $btnTextureSizeLock.on('click', function () {
                const $i = $('i', $btnTextureSizeLock);
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
            $btnDelete.on('click', function () {
                const editedMaterial = that.editedMaterial;
                $modal.modal('hide');   // Hide modal
                that.deleteMaterial(editedMaterial);
                this.blur();
            });
            $btnDuplicate.on('click', function () {
                const editedMaterial = that.editedMaterial;
                $modal.modal('hide');   // Hide modal
                that.duplicateMaterial(editedMaterial);
                this.blur();
            });
            $btnExportToSkm.on('click', function () {
                that.exportToSkm(that.editedMaterial, true);
                this.blur();
            });
            $btnUpdate.on('click', function () {

                const material = {
                    name: that.editedMaterial.name,
                    display_name: $inputs.inputName.val().trim(),
                    color: $inputs.inputColor.val(),
                    texture_file: $imgTexture.attr('src') === '' ? null : $imgTexture.attr('src'),
                    texture_changed: $inputTextureChanged.val() === 'true',
                    texture_rotation: parseInt($inputTextureRotation.val()),
                    texture_width: $inputTextureWidth.val(),
                    texture_height: $inputTextureHeight.val(),
                    attributes: {}
                }
                fnFetchAttributes(material.attributes);

                // Flag to ignore next material change event
                that.ignoreNextMaterialEvents = true;

                rubyCallCommand('materials_update', material, function (response) {

                    // Flag to stop ignoring next material change event
                    that.ignoreNextMaterialEvents = false;

                    if (response.errors) {
                        that.dialog.notifyErrors(response.errors);
                    } else {

                        if (typeof updatedCallback === 'function') {
                            updatedCallback();
                        } else {

                            // Reload the list
                            const materialId = that.editedMaterial.id;
                            that.loadList(function() {
                                that.scrollSlideToTarget(null, $('#ladb_material_' + materialId, that.$page), false, true);
                            });

                        }

                        // Hide modal
                        $modal.modal('hide');

                    }

                });

            });

            // Bind model
            $modal
                .on('hidden.bs.modal', function () {

                    // Reset edited material
                    that.editedMaterial = null;

                })
            ;

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

    LadbTabMaterials.prototype.duplicateMaterial = function (material) {
        const that = this;

        this.dialog.prompt(i18next.t('default.duplicate'), i18next.t('tab.materials.duplicate.message', { material_name: material.display_name }), material.display_name, function (value) {

            // Flag to ignore the next material change event
            that.ignoreNextMaterialEvents = true;

            rubyCallCommand('materials_duplicate', {
                name: material.name,
                new_name: value
            }, function (response) {

                // Flag to stop ignoring the next material change event
                that.ignoreNextMaterialEvents = false;

                if (response.errors && response.errors.length > 0) {
                    that.dialog.notifyErrors(response.errors);
                } else {

                    // Reload the list + edit the new material
                    const materialId = response.id;
                    that.loadList(function() {
                        that.editMaterial(materialId);
                    });

                }

            });

        }, {
            validateBtnLabel: i18next.t('default.duplicate')
        });

    };

    LadbTabMaterials.prototype.deleteMaterial = function (material) {
        const that = this;

        this.dialog.confirm(i18next.t('default.caution'), i18next.t('tab.materials.delete.message', { material_name: material.display_name }), function () {

            // Flag to ignore the next material change event
            that.ignoreNextMaterialEvents = true;

            rubyCallCommand('materials_delete', {
                name: material.name,
            }, function (response) {

                // Flag to stop ignoring the next material change event
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
            confirmBtnLabel: i18next.t('default.delete')
        });

    };

    LadbTabMaterials.prototype.importFromSkm = function () {
        const that = this;

        // Flag to ignore the next material change event
        that.ignoreNextMaterialEvents = true;

        rubyCallCommand('materials_import_from_skm', null, function (response) {

            // Flag to stop ignoring the next material change event
            that.ignoreNextMaterialEvents = false;

            if (response.errors && response.errors.length > 0) {
                that.dialog.notifyErrors(response.errors);
            } else if (!response.cancelled) {
                that.loadList(function() {
                    const $material = $('#ladb_material_' + response.material_id, that.$page);
                    that.scrollSlideToTarget(null, $material, true, true);
                });
            }

        });
    };

    LadbTabMaterials.prototype.exportToSkm = function (material) {
        const that = this;

        rubyCallCommand('materials_export_to_skm', {
            name: material.name,
            display_name: material.display_name
        }, function (response) {

            if (response.errors) {
                that.dialog.notifyErrors(response.errors);
            }
            if (response.export_path) {
                that.dialog.notifySuccess(i18next.t('core.success.exported_to', { path: response.export_path }));
            }

        });
    };

    LadbTabMaterials.prototype.setCurrentMaterial = function (materialId) {
        const material = this.findMaterialById(materialId);
        if (material) {
            rubyCallCommand('materials_smart_paint_command', {
                tab_name_to_show_on_quit: this.generateOptions.minimize_on_smart_paint ? 'materials' : null,
                name: material.name
            });
        }
    };

    LadbTabMaterials.prototype.purgeUnused = function () {
        const that = this;

        // Flag to ignore the next material change event
        that.ignoreNextMaterialEvents = true;

        rubyCallCommand('materials_purge_unused', null, function (response) {

            // Flag to stop ignoring the next material change event
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
        const that = this;

        rubyCallCommand('core_get_model_preset', { dictionary: 'materials_options' }, function (response) {

            that.generateOptions = response.preset;

            // Callback
            if (typeof callback === 'function') {
                callback();
            }

        });

    };

    LadbTabMaterials.prototype.editOptions = function (tab) {
        const that = this;

        if (tab === undefined) {
            tab = this.lastOptionsTab;
        }
        if (tab === null || tab.length === 0) {
            tab = 'general';
        }
        this.lastOptionsTab = tab;

        const $modal = that.appendModalInside('ladb_materials_modal_options', 'tabs/materials/_modal-options.twig', {
            tab: tab
        });

        // Fetch UI elements
        const $tabs = $('a[data-toggle="tab"]', $modal);
        const $widgetPreset = $('.ladb-widget-preset', $modal);
        const $inputMinimizeOnSmartPaint = $('#ladb_input_minimize_on_smart_paint', $modal);
        const $sortableMaterialOrderStrategy = $('#ladb_sortable_material_order_strategy', $modal);
        const $btnUpdate = $('#ladb_materials_options_update', $modal);

        // Define useful functions
        const fnFetchOptions = function (options) {

            options.minimize_on_smart_paint = $inputMinimizeOnSmartPaint.is(':checked');

            const properties = [];
            $sortableMaterialOrderStrategy.children('li').each(function () {
                properties.push($(this).data('property'));
            });
            options.material_order_strategy = properties.join('>');

        };
        const fnFillInputs = function (options) {

            // Checkboxes

            $inputMinimizeOnSmartPaint.prop('checked', options.minimize_on_smart_paint);

            // Sortables

            let properties, property, i;

            // Material order sortables

            properties = options.material_order_strategy.split('>');
            $sortableMaterialOrderStrategy.empty();
            for (i = 0; i < properties.length; i++) {
                property = properties[i];
                $sortableMaterialOrderStrategy.append(Twig.twig({ref: "tabs/materials/_option-material-order-strategy-property.twig"}).render({
                    order: property.startsWith('-') ? '-' : '',
                    property: property.startsWith('-') ? property.substring(1) : property
                }));
            }
            $sortableMaterialOrderStrategy.find('a').on('click', function () {
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

        // Bind tabs
        $tabs.on('shown.bs.tab', function (e) {
            that.lastOptionsTab = $(e.target).attr('href').substring('#tab_options_'.length);
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
        let material;
        for (let i = 0; i < this.materials.length; i++) {
            material = this.materials[i];
            if (material.id === id) {
                return material;
            }
        }
        return null;
    };

    LadbTabMaterials.prototype.showObsolete = function (messageI18nKey, forced) {
        if (!this.isObsolete() || forced) {

            const that = this;

            // Set tab as obsolete
            this.setObsolete(true);

            const $modal = this.appendModalInside('ladb_materials_modal_obsolete', 'tabs/materials/_modal-obsolete.twig', {
                messageI18nKey: messageI18nKey
            });

            // Fetch UI elements
            const $btnRefresh = $('#ladb_materials_obsolete_refresh', $modal);

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
        const that = this;

        // Fetch UI elements
        const $tabs = $('section a[data-toggle="tab"]', $modal);
        const $widgetPreset = $('.ladb-widget-preset', $modal);
        const $btnTabAttributes = $('#ladb_materials_btn_tab_general_attributes', $modal);
        const $inputName = $('#ladb_materials_input_name', $modal);
        const $inputNameWarning = $('#ladb_materials_input_name_warning', $modal);
        const $inputColor = $('#ladb_materials_input_color', $modal);
        const $inputColorWarning = $('#ladb_materials_input_color_warning', $modal);
        const $selectType = $('#ladb_materials_input_type', $modal);
        const $inputDescription = $('#ladb_materials_input_description', $modal);
        const $inputUrl = $('#ladb_materials_input_url', $modal);
        const $inputThickness = $('#ladb_materials_input_thickness', $modal);
        const $inputLengthIncrease = $('#ladb_materials_input_length_increase', $modal);
        const $inputWidthIncrease = $('#ladb_materials_input_width_increase', $modal);
        const $inputThicknessIncrease = $('#ladb_materials_input_thickness_increase', $modal);
        const $editorStdSections = $('#ladb_materials_editor_std_sections', $modal);
        const $editorStdLengths = $('#ladb_materials_editor_std_lengths', $modal);
        const $editorStdWidths = $('#ladb_materials_editor_std_widths', $modal);
        const $editorStdThicknesses = $('#ladb_materials_editor_std_thicknesses', $modal);
        const $editorStdSizes = $('#ladb_materials_editor_std_sizes', $modal);
        const $selectGrained = $('#ladb_materials_select_grained', $modal);
        const $selectEdgeDecremented = $('#ladb_materials_select_edge_decremented', $modal);
        const $selectRawEstimated = $('#ladb_materials_select_raw_estimated', $modal);
        const $inputMultiplierCoefficient = $('#ladb_materials_input_multiplier_coefficient', $modal);
        const $editorStdVolumicMasses = $('#ladb_materials_editor_std_volumic_masses', $modal);
        const $editorStdPrices = $('#ladb_materials_editor_std_prices', $modal);
        const $editorStdCutPrices = $('#ladb_materials_editor_std_cut_prices', $modal);

        // Define useful functions
        const fnFetchType = function (options) {
            options.type = parseInt($selectType.val());
        };
        const fnFetchStds = function (options) {
            options.std_sections = $editorStdSections.ladbEditorSizes('getSizes');
            options.std_lengths = $editorStdLengths.ladbEditorSizes('getSizes');
            options.std_widths = $editorStdWidths.ladbEditorSizes('getSizes');
            options.std_thicknesses = $editorStdThicknesses.ladbEditorSizes('getSizes');
            options.std_sizes = $editorStdSizes.ladbEditorSizes('getSizes');
        };
        const fnFetchOptions = function (options) {
            fnFetchType(options);
            options.thickness = $inputThickness.val();
            options.length_increase = $inputLengthIncrease.val();
            options.width_increase = $inputWidthIncrease.val();
            options.thickness_increase = $inputThicknessIncrease.val();
            fnFetchStds(options);
            options.grained = $selectGrained.val() === '1';
            options.edge_decremented = $selectEdgeDecremented.val() === '1';
            options.raw_estimated = $selectRawEstimated.val() === '1';
            options.multiplier_coefficient = Math.max(1.0, $inputMultiplierCoefficient.val() === '' ? 1.0 : parseFloat($inputMultiplierCoefficient.val().replace(',', '.')));
            options.std_volumic_masses = $editorStdVolumicMasses.ladbEditorStdAttributes('getStdAttributes');
            options.std_prices = $editorStdPrices.ladbEditorStdAttributes('getStdAttributes');
            options.std_cut_prices = $editorStdCutPrices.ladbEditorStdAttributes('getStdAttributes');
        };
        const fnFillInputs = function (options) {
            $inputThickness.val(options.thickness);
            $inputLengthIncrease.val(options.length_increase);
            $inputWidthIncrease.val(options.width_increase);
            $inputThicknessIncrease.val(options.thickness_increase);
            $editorStdSections.ladbEditorSizes('setSizes', options.std_sections);
            $editorStdLengths.ladbEditorSizes('setSizes', options.std_lengths);
            $editorStdWidths.ladbEditorSizes('setSizes', options.std_widths);
            $editorStdThicknesses.ladbEditorSizes('setSizes', options.std_thicknesses);
            $editorStdSizes.ladbEditorSizes('setSizes', options.std_sizes);
            $selectGrained.selectpicker('val', options.grained ? '1' : '0');
            $selectEdgeDecremented.selectpicker('val', options.edge_decremented ? '1' : '0');
            $selectRawEstimated.selectpicker('val', options.raw_estimated ? '1' : '0');
            $inputMultiplierCoefficient.val(options.multiplier_coefficient);
            fnSetStdAttributesTypeAndStds();
            $editorStdVolumicMasses.ladbEditorStdAttributes('setStdAttributes', [ options.std_volumic_masses ]);
            $editorStdPrices.ladbEditorStdAttributes('setStdAttributes', [ options.std_prices ]);
            $editorStdCutPrices.ladbEditorStdAttributes('setStdAttributes', [ options.std_cut_prices ]);
        };
        const fnSetStdAttributesTypeAndStds = function () {
            const options = {};
            fnFetchType(options);
            fnFetchStds(options);
            const stds = {
                stdSections: options.std_sections ? options.std_sections.split(';') : [],
                stdLengths: options.std_lengths ? options.std_lengths.split(';') : [],
                stdWidths: options.std_widths ? options.std_widths.split(';') : [],
                stdThicknesses: options.std_thicknesses ? options.std_thicknesses.split(';') : [],
                stdSizes: options.std_sizes ? options.std_sizes.split(';') : [],
            };
            $editorStdVolumicMasses.ladbEditorStdAttributes('setTypeAndStds', [ options.type, stds ]);
            $editorStdPrices.ladbEditorStdAttributes('setTypeAndStds', [ options.type, stds ]);
            $editorStdCutPrices.ladbEditorStdAttributes('setTypeAndStds', [ options.type, stds ]);
        };
        const fnComputeFieldsVisibility = function (type) {
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
                    $editorStdSections.closest('.form-group').hide();
                    $editorStdLengths.closest('.form-group').hide();
                    $editorStdWidths.closest('.form-group').hide();
                    $editorStdThicknesses.closest('.form-group').show();
                    $editorStdSizes.closest('.form-group').hide();
                    $selectGrained.closest('.form-group').hide();
                    $selectEdgeDecremented.closest('.form-group').hide();
                    $selectRawEstimated.closest('.form-group').hide();
                    $inputMultiplierCoefficient.closest('.form-group').show();
                    $editorStdVolumicMasses.closest('.form-group').show();
                    $editorStdPrices.closest('.form-group').show();
                    $editorStdCutPrices.closest('.form-group').hide();
                    break;
                case 2:   // TYPE_SHEET_GOOD
                    $inputThickness.closest('section').show();
                    $inputThickness.closest('.form-group').hide();
                    $inputLengthIncrease.closest('.form-group').show();
                    $inputWidthIncrease.closest('.form-group').show();
                    $inputThicknessIncrease.closest('.form-group').hide();
                    $editorStdSections.closest('.form-group').hide();
                    $editorStdLengths.closest('.form-group').hide();
                    $editorStdWidths.closest('.form-group').hide();
                    $editorStdThicknesses.closest('.form-group').show();
                    $editorStdSizes.closest('.form-group').show();
                    $selectGrained.closest('.form-group').show();
                    $selectEdgeDecremented.closest('.form-group').hide();
                    $selectRawEstimated.closest('.form-group').show();
                    $inputMultiplierCoefficient.closest('.form-group').hide();
                    $editorStdVolumicMasses.closest('.form-group').show();
                    $editorStdPrices.closest('.form-group').show();
                    $editorStdCutPrices.closest('.form-group').show();
                    break;
                case 3:   // TYPE_DIMENSIONAL
                    $inputThickness.closest('section').show();
                    $inputThickness.closest('.form-group').hide();
                    $inputLengthIncrease.closest('.form-group').show();
                    $inputWidthIncrease.closest('.form-group').hide();
                    $inputThicknessIncrease.closest('.form-group').hide();
                    $editorStdSections.closest('.form-group').show();
                    $editorStdLengths.closest('.form-group').show();
                    $editorStdWidths.closest('.form-group').hide();
                    $editorStdThicknesses.closest('.form-group').hide();
                    $editorStdSizes.closest('.form-group').hide();
                    $selectGrained.closest('.form-group').hide();
                    $selectEdgeDecremented.closest('.form-group').hide();
                    $selectRawEstimated.closest('.form-group').show();
                    $inputMultiplierCoefficient.closest('.form-group').hide();
                    $editorStdVolumicMasses.closest('.form-group').show();
                    $editorStdPrices.closest('.form-group').show();
                    $editorStdCutPrices.closest('.form-group').show();
                    break;
                case 4:   // TYPE_EDGE
                    $inputThickness.closest('section').show();
                    $inputThickness.closest('.form-group').show();
                    $inputLengthIncrease.closest('.form-group').show();
                    $inputWidthIncrease.closest('.form-group').hide();
                    $inputThicknessIncrease.closest('.form-group').hide();
                    $editorStdSections.closest('.form-group').hide();
                    $editorStdLengths.closest('.form-group').show();
                    $editorStdWidths.closest('.form-group').show();
                    $editorStdThicknesses.closest('.form-group').hide();
                    $editorStdSizes.closest('.form-group').hide();
                    $selectGrained.closest('.form-group').hide();
                    $selectEdgeDecremented.closest('.form-group').show();
                    $selectRawEstimated.closest('.form-group').show();
                    $inputMultiplierCoefficient.closest('.form-group').hide();
                    $editorStdVolumicMasses.closest('.form-group').show();
                    $editorStdPrices.closest('.form-group').show();
                    $editorStdCutPrices.closest('.form-group').show();
                    break;
                case 5:   // TYPE_HARDWARE
                    $inputThickness.closest('section').hide();
                    break;
                case 6:   // TYPE_VENEER
                    $inputThickness.closest('section').show();
                    $inputThickness.closest('.form-group').show();
                    $inputLengthIncrease.closest('.form-group').show();
                    $inputWidthIncrease.closest('.form-group').show();
                    $inputThicknessIncrease.closest('.form-group').hide();
                    $editorStdSections.closest('.form-group').hide();
                    $editorStdLengths.closest('.form-group').hide();
                    $editorStdWidths.closest('.form-group').hide();
                    $editorStdThicknesses.closest('.form-group').hide();
                    $editorStdSizes.closest('.form-group').show();
                    $selectGrained.closest('.form-group').show();
                    $selectEdgeDecremented.closest('.form-group').hide();
                    $selectRawEstimated.closest('.form-group').show();
                    $inputMultiplierCoefficient.closest('.form-group').hide();
                    $editorStdVolumicMasses.closest('.form-group').show();
                    $editorStdPrices.closest('.form-group').show();
                    $editorStdCutPrices.closest('.form-group').show();
                    break;
                default:
                    $inputThickness.closest('section').hide();
            }
        };
        const fnCheckInputNameValue = function(verbose) {
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
        const fnCheckInputColorValue = function(verbose) {
            if ($inputColor.val().match(/^(#[0-9a-f]{6}|)$/i)) {
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

        // Init textinputs
        $inputThickness.ladbTextinputDimension();
        $inputLengthIncrease.ladbTextinputDimension();
        $inputWidthIncrease.ladbTextinputDimension();
        $inputThicknessIncrease.ladbTextinputDimension();

        // Init editors
        $editorStdSections.ladbEditorSizes({
            format: FORMAT_D_D,
            d1Placeholder: i18next.t('default.width'),
            d2Placeholder: i18next.t('default.height'),
            qHidden: true,
            emptyDisplayed: false
        });
        $editorStdLengths.ladbEditorSizes({
            format: FORMAT_D,
            d1Placeholder: i18next.t('default.length'),
            qHidden: true,
            emptyDisplayed: false
        });
        $editorStdWidths.ladbEditorSizes({
            format: FORMAT_D,
            d1Placeholder: i18next.t('default.width'),
            qHidden: true,
            emptyDisplayed: false
        });
        $editorStdThicknesses.ladbEditorSizes({
            format: FORMAT_D,
            d1Placeholder: i18next.t('default.thickness'),
            qHidden: true,
            emptyDisplayed: false
        });
        $editorStdSizes.ladbEditorSizes({
            format: FORMAT_D_D,
            d1Placeholder: i18next.t('default.length'),
            d2Placeholder: i18next.t('default.width'),
            qHidden: true,
            emptyDisplayed: false
        });
        $inputMultiplierCoefficient.ladbTextinputNumberWithUnit({
            resetValue: '1'
        });
        $editorStdVolumicMasses.ladbEditorStdAttributes({
            strippedName: 'volumic_masses',
            units: [
                {
                    kg_m3: 'kg / m³',
                    kg_ft3: 'kg / ft³',
                    kg_fbm: 'kg / fbm',
                    kg_i: 'kg / ' + i18next.t('default.instance_single'),
                },
                {
                    lb_ft3: 'lb / ft³',
                    lb_fbm: 'lb / fbm',
                    lb_m3: 'lb / m³',
                    lb_i: 'lb / ' + i18next.t('default.instance_single'),
                }
            ],
            lengthUnitStrippedname: that.lengthUnitStrippedname,
            defaultUnitByTypeCallback: function (type) {
                switch (type) {
                    case 1: /* TYPE_SOLID_WOOD */
                        return that.massUnitStrippedname + '_' + (that.lengthUnitStrippedname === 'ft' ? 'fbm' : that.lengthUnitStrippedname + '3');
                    case 2: /* TYPE_SHEET_GOOD */
                    case 3: /* TYPE_DIMENSIONAL */
                    case 4: /* TYPE_EDGE */
                    case 6: /* TYPE_VENEER */
                        return that.massUnitStrippedname + '_' + that.lengthUnitStrippedname + '3';
                }
            },
            enabledUnitsByTypeCallback: function (type, rowPos) {
                switch (type) {
                    case 1: /* TYPE_SOLID_WOOD */
                        return [ 'kg_m3', 'kg_ft3', 'kg_fbm', 'lb_ft3', 'lb_m3', 'lb_fbm' ];
                    case 2: /* TYPE_SHEET_GOOD */
                    case 3: /* TYPE_DIMENSIONAL */
                    case 4: /* TYPE_EDGE */
                    case 6: /* TYPE_VENEER */
                        const unitKeys = [ 'kg_m3', 'kg_ft3', 'lb_ft3', 'lb_m3' ];
                        if (rowPos === 'N') {
                            unitKeys.push('kg_i');
                            unitKeys.push('lb_i');
                        }
                        return unitKeys;
                }
            },
            inputChangeCallback: inputChangeCallback
        });
        $editorStdPrices.ladbEditorStdAttributes({
            strippedName: 'prices',
            units: [
                {
                    $_m: that.currencySymbol + ' / m',
                    $_m2: that.currencySymbol + ' / m²',
                    $_m3: that.currencySymbol + ' / m³',
                },
                {
                    $_ft: that.currencySymbol + ' / ft',
                    $_ft2: that.currencySymbol + ' / ft²',
                    $_ft3: that.currencySymbol + ' / ft³',
                    $_fbm: that.currencySymbol + ' / fbm',
                },
                {
                    $_i: that.currencySymbol + ' / ' + i18next.t('default.instance_single')
                }
            ],
            lengthUnitStrippedname: that.lengthUnitStrippedname,
            defaultUnitByTypeCallback: function (type) {
                switch (type) {
                    case 1: /* TYPE_SOLID_WOOD */
                        return '$_' + (that.lengthUnitStrippedname === 'ft' ? 'fbm' : that.lengthUnitStrippedname + '3');
                    case 2: /* TYPE_SHEET_GOOD */
                    case 6: /* TYPE_VENEER */
                        return '$_' + that.lengthUnitStrippedname + '2';
                    case 3: /* TYPE_DIMENSIONAL */
                    case 4: /* TYPE_EDGE */
                        return '$_' + that.lengthUnitStrippedname;
                }
            },
            enabledUnitsByTypeCallback: function (type, rowPos) {
                switch (type) {
                    case 1: /* TYPE_SOLID_WOOD */
                        return [ '$_m3', '$_ft3', '$_fbm' ];
                    case 2: /* TYPE_SHEET_GOOD */
                    case 3: /* TYPE_DIMENSIONAL */
                    case 4: /* TYPE_EDGE */
                    case 6: /* TYPE_VENEER */
                        const unitKeys = [ '$_m', '$_m2', '$_m3', '$_ft', '$_ft2', '$_ft3' ];
                        if (rowPos === 'N') {
                            unitKeys.push('$_i');
                        }
                        return unitKeys;
                }
            },
            inputChangeCallback: inputChangeCallback
        });
        $editorStdCutPrices.ladbEditorStdAttributes({
            strippedName: 'cut_prices',
            units: [
                {
                    $_m: that.currencySymbol + ' / m',
                },
                {
                    $_ft: that.currencySymbol + ' / ft',
                },
                {
                    $_c: that.currencySymbol + ' / ' + i18next.t('default.cut_single'),
                }
            ],
            lengthUnitStrippedname: that.lengthUnitStrippedname,
            defaultUnitByTypeCallback: function (type) {
                switch (type) {
                    case 2: /* TYPE_SHEET_GOOD */
                    case 6: /* TYPE_VENEER */
                    case 3: /* TYPE_DIMENSIONAL */
                    case 4: /* TYPE_EDGE */
                        return '$_' + that.lengthUnitStrippedname;
                }
            },
            enabledUnitsByTypeCallback: function (type, rowPos) {
                switch (type) {
                    case 2: /* TYPE_SHEET_GOOD */
                    case 3: /* TYPE_DIMENSIONAL */
                    case 4: /* TYPE_EDGE */
                    case 6: /* TYPE_VENEER */
                        return [ '$_m', '$_ft', '$_c' ];
                }
            },
            inputChangeCallback: inputChangeCallback
        });

        // Bind tabs
        $tabs.on('shown.bs.tab', function (e) {
            that.lastMaterialPropertiesTab = $(e.target).attr('href').substring('#tab_edit_material_general_'.length);
        })

        $btnTabAttributes.on('shown.bs.tab', function () {
            fnSetStdAttributesTypeAndStds();
        });

        // Bind select
        $selectType.on('change', function () {
            const options = {};
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
        $selectRawEstimated.selectpicker(SELECT_PICKER_OPTIONS);

        // Bind inputs
        $inputName.on('keyup change', function () { fnCheckInputNameValue(true); });
        $inputName.ladbTextinputText();
        $inputColor.on('keyup change', function () { fnCheckInputColorValue(true); });
        $inputColor.ladbTextinputColor({
            resetValue: ''
        });
        $inputDescription.ladbTextinputArea();
        $inputUrl.ladbTextinputUrl();

        // Bind modal event
        $modal
            .on('shown.bs.modal', function () {

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

            })
        ;

        // Initials
        fnComputeFieldsVisibility(material.attributes.type);
        fnCheckInputNameValue(false);
        fnCheckInputColorValue(false);

        return {
            inputName: $inputName,
            inputColor: $inputColor,
            selectType: $selectType,
            inputDescription: $inputDescription,
            inputUrl: $inputUrl,
            inputThickness: $inputThickness,
            inputLengthIncrease: $inputLengthIncrease,
            inputWidthIncrease: $inputWidthIncrease,
            inputThicknessIncrease: $inputThicknessIncrease,
            editorStdSections: $editorStdSections,
            editorStdLengths: $editorStdLengths,
            editorStdWidths: $editorStdWidths,
            editorStdThicknesses: $editorStdThicknesses,
            editorStdSizes: $editorStdSizes,
            selectGrained: $selectGrained,
            selectEdgeDecremented: $selectEdgeDecremented,
            selectRawEstimated: $selectRawEstimated,
            inputMultiplierCoefficient: $inputMultiplierCoefficient,
            editorStdVolumicMasses: $editorStdVolumicMasses,
            editorStdPrices: $editorStdPrices,
            editorStdCutPrices: $editorStdCutPrices,
        }
    };

    // Init ///

    LadbTabMaterials.prototype.registerCommands = function () {
        LadbAbstractTab.prototype.registerCommands.call(this);

        const that = this;

        this.registerCommand('new_material', function (parameters) {
            setTimeout(function () {     // Use setTimeout to give time to UI to refresh
                const name = parameters ? parameters.name : null;
                const color = parameters ? parameters.color : null;
                const type = parameters ? parameters.type : null;
                that.newMaterial(name, color, type);
            }, 1);
        });
        this.registerCommand('edit_material', function (parameters) {
            const materialId = parameters.materialId;
            const tab = parameters.tab;
            const propertiesTab = parameters.propertiesTab;
            const callback = parameters.callback;
            const updatedCallback = parameters.updatedCallback;
            window.requestAnimationFrame(function () {
                that.loadList(function () {
                    that.editMaterial(materialId, tab, propertiesTab, callback, updatedCallback);
                });
            });
        });
    };

    LadbTabMaterials.prototype.bind = function () {
        LadbAbstractTab.prototype.bind.call(this);

        const that = this;

        // Bind buttons
        this.$btnList.on('click', function () {
            that.loadList();
            this.blur();
        });
        this.$btnNew.on('click', function () {
            that.newMaterial();
            this.blur();
        });
        this.$btnImport.on('click', function () {
            that.importFromSkm();
            this.blur();
        });
        this.$btnOptions.on('click', function () {
            that.editOptions();
            this.blur();
        });
        this.$itemPurgeUnused.on('click', function () {
            that.purgeUnused();
            this.blur();
        });
        this.$itemResetPrices.on('click', function () {
            that.dialog.confirm(i18next.t('default.caution'), i18next.t('tab.materials.menu.reset_prices_confirm'), function () {
                rubyCallCommand('materials_reset_prices', null, function (response) {

                    if (response.errors) {
                        that.dialog.notifyErrors(response.errors);
                    } else {
                        that.dialog.alert(null, i18next.t('tab.cutlist.menu.reset_prices_success'), function () {
                            that.loadList();
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
            that.showObsolete('core.event.model_change', true);

            // Hide edit option model (if it exists)
            $('#ladb_materials_modal_options').modal('hide');

            // Reload options (from new active model)
            that.loadOptions();

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
            if (that.materials) {
                for (let i = 0; i < that.materials.length; i++) {
                    if (that.materials[i].name === params.material_name) {
                        if (that.currentMaterial !== that.materials[i]) {
                            that.currentMaterial = that.materials[i];
                            $('.ladb-material-box').removeClass('ladb-active');
                            $('.ladb-material-box[data-material-id="' + that.currentMaterial.id + '"]').addClass('ladb-active');
                        }
                        break;
                    }
                }
            }
        });

    };

    LadbTabMaterials.prototype.processInitializedCallback = function (initializedCallback) {
        const that = this;

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
            const $this = $(this);
            let data = $this.data('ladb.tab.plugin');
            if (!data) {
                const options = $.extend({}, LadbTabMaterials.DEFAULTS, $this.data(), typeof option === 'object' && option);
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

    const old = $.fn.ladbTabMaterials;

    $.fn.ladbTabMaterials = Plugin;
    $.fn.ladbTabMaterials.Constructor = LadbTabMaterials;


    // NO CONFLICT
    // =================

    $.fn.ladbTabMaterials.noConflict = function () {
        $.fn.ladbTabMaterials = old;
        return this;
    }

}(jQuery);

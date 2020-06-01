+function ($) {
    'use strict';

    // CONSTANTS
    // ======================

    // Options keys

    var SETTING_KEY_OPTION_PREFIX = 'materials.option.';
    var SETTING_KEY_OPTION_PREFIX_TYPE = SETTING_KEY_OPTION_PREFIX + 'type_';

    var SETTING_KEY_OPTION_MATERIAL_ORDER_STRATEGY = SETTING_KEY_OPTION_PREFIX + 'material_order_strategy';

    var SETTING_KEY_OPTION_SUFFIX_THICKNESS = '_thickness';
    var SETTING_KEY_OPTION_SUFFIX_LENGTH_INCREASE = '_length_increase';
    var SETTING_KEY_OPTION_SUFFIX_WIDTH_INCREASE = '_width_increase';
    var SETTING_KEY_OPTION_SUFFIX_THICKNESS_INCREASE = '_thickness_increase';
    var SETTING_KEY_OPTION_SUFFIX_STD_LENGTHS = '_std_lengths';
    var SETTING_KEY_OPTION_SUFFIX_STD_WIDTHS = '_std_widths';
    var SETTING_KEY_OPTION_SUFFIX_STD_THICKNESSES = '_std_thicknesses';
    var SETTING_KEY_OPTION_SUFFIX_STD_SECTIONS = '_std_sections';
    var SETTING_KEY_OPTION_SUFFIX_STD_SIZES = '_std_sizes';
    var SETTING_KEY_OPTION_SUFFIX_GRAINED = '_grained';
    var SETTING_KEY_OPTION_SUFFIX_EDGE_DECREMENTED = '_edge_decremented';

    // Options defaults

    var OPTION_DEFAULT_MATERIAL_ORDER_STRATEGY = 'name>type';

    // Select picker options

    var SELECT_PICKER_OPTIONS = {
        size: 10,
        iconBase: 'ladb-opencutlist-icon',
        tickIcon: 'ladb-opencutlist-icon-tick',
        showTick: true
    };

    // Tokenfield options

    var TOKENFIELD_OPTIONS = {
        delimiter: ';',
        createTokensOnBlur: true
    };

    // CLASS DEFINITION
    // ======================

    var LadbTabMaterials = function (element, options, opencutlist) {
        LadbAbstractTab.call(this, element, options, opencutlist);

        this.materials = [];
        this.currentMaterial = null;
        this.editedMaterial = null;
        this.ignoreNextMaterialEvents = false;

        this.$header = $('.ladb-header', this.$element);
        this.$fileTabs = $('.ladb-file-tabs', this.$header);
        this.$btnList = $('#ladb_btn_list', this.$header);
        this.$btnNew = $('#ladb_btn_new', this.$header);
        this.$itemImportFromSkm = $('#ladb_item_import_from_skm', this.$header);
        this.$itemPurgeUnused = $('#ladb_item_purge_unused', this.$header);
        this.$itemOptions = $('#ladb_item_options', this.$header);

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
            var materials = response.materials;
            var currentMaterialName = response.current_material_name;

            // Keep useful data
            that.materials = materials;

            // Update filename
            that.$fileTabs.empty();
            that.$fileTabs.append(Twig.twig({ ref: "tabs/materials/_file-tab.twig" }).render({
                filename: filename
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
            that.opencutlist.setupTooltips();

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
                    that.opencutlist.minimize();
                    return false;
                });

            // Restore button state
            that.$btnList.prop('disabled', false);

            // Stick header
            that.stickSlideHeader(that.$rootSlide);

            // Callback
            if (callback && typeof callback == 'function') {
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

        // Create color picker
        $inputs.hueb.on('change', function() {
            fnUpdateBtnCreateStatus();
        });

        // Bind buttons
        $btnCreate.on('click', function () {

            // Flag to ignore next material change event
            that.ignoreNextMaterialEvents = true;

            rubyCallCommand('materials_create', {
                name: $inputs.inputName.val().trim(),
                color: $inputs.inputColor.val(),
                attributes: {
                    type: $inputs.selectType.val(),
                    thickness: $inputs.inputThickness.val(),
                    length_increase: $inputs.inputLengthIncrease.val(),
                    width_increase: $inputs.inputWidthIncrease.val(),
                    thickness_increase: $inputs.inputThicknessIncrease.val(),
                    std_lengths: $inputs.inputStdLengths.val(),
                    std_widths: $inputs.inputStdWidths.val(),
                    std_thicknesses: $inputs.inputStdThicknesses.val(),
                    std_sections: $inputs.inputStdSections.val(),
                    std_sizes: $inputs.inputStdSizes.val(),
                    grained: $inputs.selectGrained.val() === '1',
                    edge_decremented: $inputs.selectEdgeDecremented.val() === '1'
                }
            }, function (response) {

                var materialId = response.id;

                // Flag to stop ignoring next material change event
                that.ignoreNextMaterialEvents = false;

                if (response.errors && response.errors.length > 0) {
                    that.opencutlist.notifyErrors(response.errors);
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
        this.opencutlist.setupTooltips();
        this.opencutlist.setupPopovers();

        // Focus
        $inputs.inputName.focus();

    };

    LadbTabMaterials.prototype.editMaterial = function (id, callback) {
        var that = this;

        var material = this.findMaterialById(id);
        if (material) {

            // Keep the edited material
            this.editedMaterial = material;

            var $modal = this.appendModalInside('ladb_materials_modal_edit', 'tabs/materials/_modal-edit.twig', {
                capabilities: that.opencutlist.capabilities,
                material: material
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

            // Define usefull functions
            var fnDisableBtnExport = function () {
                $btnExportToSkm.prop('disabled', true);
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
                    rubyCallCommand('core_compute_size_aspect_ratio_command', {
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

            // Bind form
            var $inputs = this.bindMaterialPropertiesForm($modal, material);

            // Bind inputs
            $inputs.inputName.on('keyup change', fnUpdateBtnUpdateStatus);
            $inputs.inputColor.on('keyup change', fnUpdateBtnUpdateStatus);

            // Bind tabs
            $btnTabTexture.on('shown.bs.tab', function (e) {

                fnGetMaterialTexture(false);

                // Unbind event
                $btnTabTexture.off('shown.bs.tab');
            });

            // Bind change
            $('input', $modal).on('change', function () {
                fnDisableBtnExport();
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
                that.editedMaterial.attributes.type = $inputs.selectType.val();
                that.editedMaterial.attributes.thickness = $inputs.inputThickness.val();
                that.editedMaterial.attributes.length_increase = $inputs.inputLengthIncrease.val();
                that.editedMaterial.attributes.width_increase = $inputs.inputWidthIncrease.val();
                that.editedMaterial.attributes.thickness_increase = $inputs.inputThicknessIncrease.val();
                that.editedMaterial.attributes.std_lengths = $inputs.inputStdLengths.val();
                that.editedMaterial.attributes.std_widths = $inputs.inputStdWidths.val();
                that.editedMaterial.attributes.std_thicknesses = $inputs.inputStdThicknesses.val();
                that.editedMaterial.attributes.std_sections = $inputs.inputStdSections.val();
                that.editedMaterial.attributes.std_sizes = $inputs.inputStdSizes.val();
                that.editedMaterial.attributes.grained = $inputs.selectGrained.val() === '1';
                that.editedMaterial.attributes.edge_decremented = $inputs.selectEdgeDecremented.val() === '1';

                // Flag to ignore next material change event
                that.ignoreNextMaterialEvents = true;

                rubyCallCommand('materials_update', that.editedMaterial, function (response) {

                    // Flag to stop ignoring next material change event
                    that.ignoreNextMaterialEvents = false;

                    if (response['errors']) {
                        that.opencutlist.notifyErrors(response['errors']);
                    } else {

                        // Reload the list
                        var material_id = that.editedMaterial.id;
                        that.loadList(function() {
                            that.scrollSlideToTarget(null, $('#ladb_material_' + material_id, that.$page), false, true);
                        });

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
            this.opencutlist.setupTooltips();
            this.opencutlist.setupPopovers();

            // Callback
            if (typeof(callback) === 'function') {
                callback($modal);
            }

        } else {
            alert('Material not found (id=' + id + ')');
        }
    };

    LadbTabMaterials.prototype.removeMaterial = function (material) {
        var that = this;

        var $modal = this.appendModalInside('ladb_materials_modal_remove', 'tabs/materials/_modal-remove.twig', {
            material: material
        });

        // Fetch UI elements
        var $btnRemove = $('#ladb_materials_remove', $modal);

        // Bind buttons
        $btnRemove.on('click', function () {

            // Flag to ignore next material change event
            that.ignoreNextMaterialEvents = true;

            rubyCallCommand('materials_remove', {
                name: material.name,
                display_name: material.display_name
            }, function (response) {

                // Flag to stop ignoring next material change event
                that.ignoreNextMaterialEvents = false;

                if (response.errors && response.errors.length > 0) {
                    that.opencutlist.notifyErrors(response.errors);
                } else {

                    // Reload the list
                    that.loadList();

                    // Hide modal
                    $modal.modal('hide');

                }

            });

        });

        // Show modal
        $modal.modal('show');

    };

    LadbTabMaterials.prototype.importFromSkm = function () {
        var that = this;

        // Flag to ignore next material change event
        that.ignoreNextMaterialEvents = true;

        rubyCallCommand('materials_import_from_skm', null, function (response) {

            // Flag to stop ignoring next material change event
            that.ignoreNextMaterialEvents = false;

            if (response.errors && response.errors.length > 0) {
                that.opencutlist.notifyErrors(response.errors);
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

            var i;

            if (response.errors) {
                that.opencutlist.notifyErrors(response.errors);
            }
            if (response.export_path) {
                that.opencutlist.notify(i18next.t('tab.materials.success.exported_to', { export_path: response.export_path }), 'success');
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
                that.opencutlist.notifyErrors(response.errors);
            } else {
                that.loadList();
            }

        });
    };

    // Options /////

    LadbTabMaterials.prototype.loadOptions = function (callback) {
        var that = this;

        this.opencutlist.pullSettings([

                SETTING_KEY_OPTION_MATERIAL_ORDER_STRATEGY

            ],
            3 /* SETTINGS_RW_STRATEGY_MODEL_GLOBAL */,
            function () {

                that.generateOptions = {
                    material_order_strategy: that.opencutlist.getSetting(SETTING_KEY_OPTION_MATERIAL_ORDER_STRATEGY, OPTION_DEFAULT_MATERIAL_ORDER_STRATEGY)
                };

                // Callback
                if (callback && typeof(callback) === 'function') {
                    callback();
                }

            });

    };

    LadbTabMaterials.prototype.editOptions = function () {
        var that = this;

        var $modal = that.appendModalInside('ladb_materials_modal_options', 'tabs/materials/_modal-options.twig');

        // Fetch UI elements
        var $sortableMaterialOrderStrategy = $('#ladb_sortable_material_order_strategy', $modal);
        var $btnReset = $('#ladb_materials_options_reset', $modal);
        var $btnUpdate = $('#ladb_materials_options_update', $modal);

        // Define useful functions
        var populateOptionsInputs = function (options) {

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

        // Bind buttons
        $btnReset.on('click', function () {
            $(this).blur();

            var options = $.extend($.extend({}, that.generateOptions), {
                material_order_strategy: OPTION_DEFAULT_MATERIAL_ORDER_STRATEGY,
            });
            populateOptionsInputs(options);
        });
        $btnUpdate.on('click', function () {

            // Fetch options

            var properties = [];
            $sortableMaterialOrderStrategy.children('li').each(function () {
                properties.push($(this).data('property'));
            });
            that.generateOptions.material_order_strategy = properties.join('>');

            // Store options
            that.opencutlist.setSettings([
                { key:SETTING_KEY_OPTION_MATERIAL_ORDER_STRATEGY, value:that.generateOptions.material_order_strategy },
            ], 3 /* SETTINGS_RW_STRATEGY_MODEL_GLOBAL */);

            // Hide modal
            $modal.modal('hide');

            // Reload the list
            that.loadList();

        });

        // Populate inputs
        populateOptionsInputs(that.generateOptions);

        // Show modal
        $modal.modal('show');

        // Setup popovers
        this.opencutlist.setupPopovers();

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

    LadbTabMaterials.prototype.bindMaterialPropertiesForm = function ($modal, material, setAttributeToDefaults) {
        var that = this;

        // Fetch UI elements
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
        var $spanCutOptionsDefaultsType1 = $('#ladb_materials_span_cut_options_defaults_type_1', $modal);
        var $spanCutOptionsDefaultsType2 = $('#ladb_materials_span_cut_options_defaults_type_2', $modal);
        var $spanCutOptionsDefaultsType3 = $('#ladb_materials_span_cut_options_defaults_type_3', $modal);
        var $spanCutOptionsDefaultsType4 = $('#ladb_materials_span_cut_options_defaults_type_4', $modal);
        var $btnCutOptionsDefaultsSave = $('#ladb_materials_btn_cut_options_defaults_save', $modal);
        var $btnCutOptionsDefaultsReset = $('#ladb_materials_btn_cut_options_defaults_reset', $modal);

        // Define usefull functions
        var fnComputeFieldsVisibility = function (type) {
            switch (type) {
                case 0:   // TYPE_UNKNOW
                    $inputLengthIncrease.closest('section').hide();
                    break;
                case 1:   // TYPE_SOLID_WOOD
                    $inputThickness.closest('.form-group').hide();
                    $inputLengthIncrease.closest('section').show();
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
                    $spanCutOptionsDefaultsType1.show();
                    $spanCutOptionsDefaultsType2.hide();
                    $spanCutOptionsDefaultsType3.hide();
                    $spanCutOptionsDefaultsType4.hide();
                    break;
                case 2:   // TYPE_SHEET_GOOD
                    $inputThickness.closest('.form-group').hide();
                    $inputLengthIncrease.closest('section').show();
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
                    $spanCutOptionsDefaultsType1.hide();
                    $spanCutOptionsDefaultsType2.show();
                    $spanCutOptionsDefaultsType3.hide();
                    $spanCutOptionsDefaultsType4.hide();
                    break;
                case 3:   // TYPE_DIMENSIONAL
                    $inputThickness.closest('.form-group').hide();
                    $inputLengthIncrease.closest('section').show();
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
                    $spanCutOptionsDefaultsType1.hide();
                    $spanCutOptionsDefaultsType2.hide();
                    $spanCutOptionsDefaultsType3.show();
                    $spanCutOptionsDefaultsType4.hide();
                    break;
                case 4:   // TYPE_EDGE
                    $inputThickness.closest('.form-group').show();
                    $inputLengthIncrease.closest('section').show();
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
                    $spanCutOptionsDefaultsType1.hide();
                    $spanCutOptionsDefaultsType2.hide();
                    $spanCutOptionsDefaultsType3.hide();
                    $spanCutOptionsDefaultsType4.show();
                    break;
            }
        };
        fnComputeFieldsVisibility(material.attributes.type);

        var fnSetFieldValuesToDefaults = function (type) {
            var defaultThickness,
                defaultLengthIncrease,
                defaultWidthIncrease,
                defaultThicknessIncrease,
                defaultStdLengths,
                defaultStdWidths,
                defaultStdThicknesses,
                defaultStdSections,
                defaultStdSizes,
                defaultGrained,
                defaultEdgeDecremented;
            switch (type) {
                case 0:   // TYPE_UNKNOW
                    defaultThickness = '0';
                    defaultLengthIncrease = '0';
                    defaultWidthIncrease = '0';
                    defaultThicknessIncrease = '0';
                    defaultStdLengths = '';
                    defaultStdWidths = '';
                    defaultStdThicknesses = '';
                    defaultStdSections = '';
                    defaultStdSizes = '';
                    defaultGrained = false;
                    defaultEdgeDecremented = false;
                    break;
                case 1:   // TYPE_SOLID_WOOD
                    defaultThickness = '0';
                    defaultLengthIncrease = '50mm';
                    defaultWidthIncrease = '5mm';
                    defaultThicknessIncrease = '5mm';
                    defaultStdLengths = '';
                    defaultStdWidths = '';
                    defaultStdThicknesses = '18mm;27mm;35mm;45mm;54mm;65mm;80mm;100mm';
                    defaultStdSections = '';
                    defaultStdSizes = '';
                    defaultGrained = true;
                    defaultEdgeDecremented = true;
                    break;
                case 2:   // TYPE_SHEET_GOOD
                    defaultThickness = '0';
                    defaultLengthIncrease = '0';
                    defaultWidthIncrease = '0';
                    defaultThicknessIncrease = '0';
                    defaultStdLengths = '';
                    defaultStdWidths = '';
                    defaultStdThicknesses = '5mm;8mm;10mm;15mm;18mm;22mm';
                    defaultStdSections = '';
                    defaultStdSizes = '';
                    defaultGrained = false;
                    defaultEdgeDecremented = false;
                    break;
                case 3:   // TYPE_DIMENSIONAL
                    defaultThickness = '0';
                    defaultLengthIncrease = '0';
                    defaultWidthIncrease = '0';
                    defaultThicknessIncrease = '0';
                    defaultStdLengths = '3000mm';
                    defaultStdWidths = '';
                    defaultStdThicknesses = '';
                    defaultStdSections = '40mm x 30mm;50mm x 40mm';
                    defaultStdSizes = '';
                    defaultGrained = false;
                    defaultEdgeDecremented = false;
                    break;
                case 4:   // TYPE_EDGE
                    defaultThickness = '2mm';
                    defaultLengthIncrease = '50mm';
                    defaultWidthIncrease = '0';
                    defaultThicknessIncrease = '0';
                    defaultStdLengths = '';
                    defaultStdWidths = '23mm;33mm;43mm';
                    defaultStdThicknesses = '';
                    defaultStdSections = '';
                    defaultStdSizes = '';
                    defaultGrained = false;
                    defaultEdgeDecremented = true;
                    break;
            }
            var setTokens = function ($input, tokens) {
                // Workaround for empty string tokens
                $input.tokenfield('setTokens', tokens === ''  ? ' ' : tokens);
            };
            $inputThickness.val(that.opencutlist.getSetting(SETTING_KEY_OPTION_PREFIX_TYPE + type + SETTING_KEY_OPTION_SUFFIX_THICKNESS, defaultThickness));
            $inputLengthIncrease.val(that.opencutlist.getSetting(SETTING_KEY_OPTION_PREFIX_TYPE + type + SETTING_KEY_OPTION_SUFFIX_LENGTH_INCREASE, defaultLengthIncrease));
            $inputWidthIncrease.val(that.opencutlist.getSetting(SETTING_KEY_OPTION_PREFIX_TYPE + type + SETTING_KEY_OPTION_SUFFIX_WIDTH_INCREASE, defaultWidthIncrease));
            $inputThicknessIncrease.val(that.opencutlist.getSetting(SETTING_KEY_OPTION_PREFIX_TYPE + type + SETTING_KEY_OPTION_SUFFIX_THICKNESS_INCREASE, defaultThicknessIncrease));
            setTokens($inputStdLengths, that.opencutlist.getSetting(SETTING_KEY_OPTION_PREFIX_TYPE + type + SETTING_KEY_OPTION_SUFFIX_STD_LENGTHS, defaultStdLengths));
            setTokens($inputStdWidths, that.opencutlist.getSetting(SETTING_KEY_OPTION_PREFIX_TYPE + type + SETTING_KEY_OPTION_SUFFIX_STD_WIDTHS, defaultStdWidths));
            setTokens($inputStdThicknesses, that.opencutlist.getSetting(SETTING_KEY_OPTION_PREFIX_TYPE + type + SETTING_KEY_OPTION_SUFFIX_STD_THICKNESSES, defaultStdThicknesses));
            setTokens($inputStdSections, that.opencutlist.getSetting(SETTING_KEY_OPTION_PREFIX_TYPE + type + SETTING_KEY_OPTION_SUFFIX_STD_SECTIONS, defaultStdSections));
            setTokens($inputStdSizes, that.opencutlist.getSetting(SETTING_KEY_OPTION_PREFIX_TYPE + type + SETTING_KEY_OPTION_SUFFIX_STD_SIZES, defaultStdSizes));
            $selectGrained.selectpicker('val', that.opencutlist.getSetting(SETTING_KEY_OPTION_PREFIX_TYPE + type + SETTING_KEY_OPTION_SUFFIX_GRAINED, defaultGrained) ? '1' : '0');
            $selectEdgeDecremented.selectpicker('val', that.opencutlist.getSetting(SETTING_KEY_OPTION_PREFIX_TYPE + type + SETTING_KEY_OPTION_SUFFIX_EDGE_DECREMENTED, defaultEdgeDecremented) ? '1' : '0');
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

        // Bind select
        $selectType.on('change', function () {
            var type = parseInt($(this).val());

            // fnDisableBtnExport();
            fnComputeFieldsVisibility(type);
            fnSetFieldValuesToDefaults(type);

        });
        $selectType.selectpicker(SELECT_PICKER_OPTIONS);
        $selectGrained.selectpicker(SELECT_PICKER_OPTIONS);
        $selectEdgeDecremented.selectpicker(SELECT_PICKER_OPTIONS);

        // Create color picker
        var hueb = new Huebee($inputColor.get(0) , {
            notation: 'hex',
            saturations: 2,
            shades: 7,
            customColors: [ '#4F78A7', '#EF8E2C', '#DE545A', '#79B8B2', '#5CA34D', '#ECCA48', '#AE78A2', '#FC9CA8', '#9B755F', '#BAB0AC' ]
        });
        hueb.on('change', function() {
            hueb.close();
            $inputColor.trigger('change');
        });

        // Bind inputs
        $inputName.on('keyup change', function() { fnCheckInputNameValue(true); });
        $inputColor.on('keyup change', function() { fnCheckInputColorValue(true); });

        // Initial input checks
        fnCheckInputNameValue(false);
        fnCheckInputColorValue(false);

        // Bind buttons
        $btnCutOptionsDefaultsSave.on('click', function () {

            var type = parseInt($selectType.val());
            var thickness = $inputThickness.val();
            var length_increase = $inputLengthIncrease.val();
            var width_increase = $inputWidthIncrease.val();
            var thickness_increase = $inputThicknessIncrease.val();
            var std_lengths = $inputStdLengths.val();
            var std_widths = $inputStdWidths.val();
            var std_thicknesses = $inputStdThicknesses.val();
            var std_sections = $inputStdSections.val();
            var std_sizes = $inputStdSizes.val();
            var grained = $selectGrained.val() === '1';
            var edgeDecrement = $selectEdgeDecremented.val() === '1';

            // Update default cut options for specific type to last used
            that.opencutlist.setSettings([
                { key:SETTING_KEY_OPTION_PREFIX_TYPE + type + SETTING_KEY_OPTION_SUFFIX_THICKNESS, value:thickness, preprocessor:1 /* SETTINGS_PREPROCESSOR_D */ },
                { key:SETTING_KEY_OPTION_PREFIX_TYPE + type + SETTING_KEY_OPTION_SUFFIX_LENGTH_INCREASE, value:length_increase, preprocessor:1 /* SETTINGS_PREPROCESSOR_D */ },
                { key:SETTING_KEY_OPTION_PREFIX_TYPE + type + SETTING_KEY_OPTION_SUFFIX_WIDTH_INCREASE, value:width_increase, preprocessor:1 /* SETTINGS_PREPROCESSOR_D */ },
                { key:SETTING_KEY_OPTION_PREFIX_TYPE + type + SETTING_KEY_OPTION_SUFFIX_THICKNESS_INCREASE, value:thickness_increase, preprocessor:1 /* SETTINGS_PREPROCESSOR_D */ },
                { key:SETTING_KEY_OPTION_PREFIX_TYPE + type + SETTING_KEY_OPTION_SUFFIX_STD_LENGTHS, value:std_lengths, preprocessor:1 /* SETTINGS_PREPROCESSOR_D */ },
                { key:SETTING_KEY_OPTION_PREFIX_TYPE + type + SETTING_KEY_OPTION_SUFFIX_STD_WIDTHS, value:std_widths, preprocessor:1 /* SETTINGS_PREPROCESSOR_D */ },
                { key:SETTING_KEY_OPTION_PREFIX_TYPE + type + SETTING_KEY_OPTION_SUFFIX_STD_THICKNESSES, value:std_thicknesses, preprocessor:1 /* SETTINGS_PREPROCESSOR_D */ },
                { key:SETTING_KEY_OPTION_PREFIX_TYPE + type + SETTING_KEY_OPTION_SUFFIX_STD_SECTIONS, value:std_sections, preprocessor:2 /* SETTINGS_PREPROCESSOR_DXD */ },
                { key:SETTING_KEY_OPTION_PREFIX_TYPE + type + SETTING_KEY_OPTION_SUFFIX_STD_SIZES, value:std_sizes, preprocessor:2 /* SETTINGS_PREPROCESSOR_DXD */ },
                { key:SETTING_KEY_OPTION_PREFIX_TYPE + type + SETTING_KEY_OPTION_SUFFIX_GRAINED, value:grained },
                { key:SETTING_KEY_OPTION_PREFIX_TYPE + type + SETTING_KEY_OPTION_SUFFIX_EDGE_DECREMENTED, value:edgeDecrement }
            ], 0 /* SETTINGS_RW_STRATEGY_GLOBAL */);

            that.opencutlist.notify(i18next.t('tab.materials.edit_material.cut_options_defaults.save_success', { type_name: i18next.t('tab.materials.type_' + type) }), 'success');

            this.blur();
        });
        $btnCutOptionsDefaultsReset.on('click', function () {
            var type = parseInt($selectType.val());
            fnSetFieldValuesToDefaults(type);
            this.blur();
        });

        // Bind modal event
        $modal.on('shown.bs.modal', function() {

            // Init tokenfields (this must done after modal shown for correct token label max width measurement)
            $inputStdLengths.tokenfield(TOKENFIELD_OPTIONS).on('tokenfield:createdtoken', that.tokenfieldValidatorFn_d);
            $inputStdWidths.tokenfield(TOKENFIELD_OPTIONS).on('tokenfield:createdtoken', that.tokenfieldValidatorFn_d);
            $inputStdThicknesses.tokenfield(TOKENFIELD_OPTIONS).on('tokenfield:createdtoken', that.tokenfieldValidatorFn_d);
            $inputStdSections.tokenfield(TOKENFIELD_OPTIONS).on('tokenfield:createdtoken', that.tokenfieldValidatorFn_dxd);
            $inputStdSizes.tokenfield(TOKENFIELD_OPTIONS).on('tokenfield:createdtoken', that.tokenfieldValidatorFn_dxd);

            if (setAttributeToDefaults) {
                fnSetFieldValuesToDefaults(material.attributes.type);
            }

        });

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
            hueb: hueb
        }
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
        this.$itemImportFromSkm.on('click', function () {
            that.importFromSkm();
            this.blur();
        });
        this.$itemPurgeUnused.on('click', function () {
            that.purgeUnused();
            this.blur();
        });
        this.$itemOptions.on('click', function () {
            that.editOptions();
            this.blur();
        });

        // Events

        addEventCallback([ 'on_new_model', 'on_open_model', 'on_activate_model' ], function (params) {
            that.showObsolete('core.event.model_change', true);
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

    LadbTabMaterials.prototype.init = function (initializedCallback) {
        var that = this;

        // Register commands
        this.registerCommand('new_material', function (parameters) {
            setTimeout(function () {     // Use setTimer to give time tu UI to refresh
                var name = parameters.name;
                var color = parameters.color;
                var type = parameters.type;
                that.newMaterial(name, color, type);
            }, 1);
        });
        this.registerCommand('edit_material', function (parameters) {
            var materialId = parameters.material_id;
            var callback = parameters.callback;
            setTimeout(function () {     // Use setTimer to give time tu UI to refresh
                that.loadList(function () {
                    that.editMaterial(materialId, callback);
                });
            }, 1);
        });

        // Load settings
        var settingsKeys = [];
        for (var type = 0; type <= 4; type++) {     // 4 = TYPE_EDGE_BAND
            settingsKeys.push(SETTING_KEY_OPTION_PREFIX_TYPE + type + SETTING_KEY_OPTION_SUFFIX_THICKNESS);
            settingsKeys.push(SETTING_KEY_OPTION_PREFIX_TYPE + type + SETTING_KEY_OPTION_SUFFIX_LENGTH_INCREASE);
            settingsKeys.push(SETTING_KEY_OPTION_PREFIX_TYPE + type + SETTING_KEY_OPTION_SUFFIX_WIDTH_INCREASE);
            settingsKeys.push(SETTING_KEY_OPTION_PREFIX_TYPE + type + SETTING_KEY_OPTION_SUFFIX_THICKNESS_INCREASE);
            settingsKeys.push(SETTING_KEY_OPTION_PREFIX_TYPE + type + SETTING_KEY_OPTION_SUFFIX_STD_LENGTHS);
            settingsKeys.push(SETTING_KEY_OPTION_PREFIX_TYPE + type + SETTING_KEY_OPTION_SUFFIX_STD_WIDTHS);
            settingsKeys.push(SETTING_KEY_OPTION_PREFIX_TYPE + type + SETTING_KEY_OPTION_SUFFIX_STD_THICKNESSES);
            settingsKeys.push(SETTING_KEY_OPTION_PREFIX_TYPE + type + SETTING_KEY_OPTION_SUFFIX_STD_SECTIONS);
            settingsKeys.push(SETTING_KEY_OPTION_PREFIX_TYPE + type + SETTING_KEY_OPTION_SUFFIX_STD_SIZES);
            settingsKeys.push(SETTING_KEY_OPTION_PREFIX_TYPE + type + SETTING_KEY_OPTION_SUFFIX_GRAINED);
            settingsKeys.push(SETTING_KEY_OPTION_PREFIX_TYPE + type + SETTING_KEY_OPTION_SUFFIX_EDGE_DECREMENTED);
        }

        this.opencutlist.pullSettings(settingsKeys, 0 /* SETTINGS_RW_STRATEGY_GLOBAL */, function () {

            // Load Options
            that.loadOptions(function () {

                that.bind();

                if (initializedCallback && typeof(initializedCallback) == 'function') {
                    initializedCallback(that.$element);
                } else {
                    setTimeout(function () {     // Use setTimer to give time tu UI to refresh
                        that.loadList();
                    }, 1);
                }

            });

        });

    };


    // PLUGIN DEFINITION
    // =======================

    function Plugin(option, params) {
        return this.each(function () {
            var $this = $(this);
            var data = $this.data('ladb.tabMaterials');
            var options = $.extend({}, LadbTabMaterials.DEFAULTS, $this.data(), typeof option == 'object' && option);

            if (!data) {
                if (undefined === options.opencutlist) {
                    throw 'opencutlist option is mandatory.';
                }
                $this.data('ladb.tabMaterials', (data = new LadbTabMaterials(this, options, options.opencutlist)));
            }
            if (typeof option == 'string') {
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
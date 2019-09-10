+function ($) {
    'use strict';

    // CONSTANTS
    // ======================

    // Options keys

    var SETTING_KEY_OPTION_PREFIX = 'materials.option.';
    var SETTING_KEY_OPTION_PREFIX_TYPE = SETTING_KEY_OPTION_PREFIX + 'type_';

    var SETTING_KEY_OPTION_SUFFIX_THICKNESS = '_thickness';
    var SETTING_KEY_OPTION_SUFFIX_LENGTH_INCREASE = '_length_increase';
    var SETTING_KEY_OPTION_SUFFIX_WIDTH_INCREASE = '_width_increase';
    var SETTING_KEY_OPTION_SUFFIX_THICKNESS_INCREASE = '_thickness_increase';
    var SETTING_KEY_OPTION_SUFFIX_STD_WIDTHS = '_std_widths';
    var SETTING_KEY_OPTION_SUFFIX_STD_THICKNESSES = '_std_thicknesses';
    var SETTING_KEY_OPTION_SUFFIX_STD_SECTIONS = '_std_sections';
    var SETTING_KEY_OPTION_SUFFIX_STD_SIZES = '_std_sizes';
    var SETTING_KEY_OPTION_SUFFIX_GRAINED = '_grained';
    var SETTING_KEY_OPTION_SUFFIX_EDGE_DECREMENTED = '_edge_decremented';

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
        this.editedMaterial = null;
        this.ignoreNextMaterialEvents = false;

        this.$header = $('.ladb-header', this.$element);
        this.$fileTabs = $('.ladb-file-tabs', this.$header);
        this.$btnList = $('#ladb_btn_list', this.$header);
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

        rubyCallCommand('materials_list', null, function (response) {

            var errors = response.errors;
            var warnings = response.warnings;
            var filename = response.filename;
            var materials = response.materials;

            // Keep useful data
            that.materials = materials;

            // Update filename
            that.$fileTabs.empty();
            that.$fileTabs.append(Twig.twig({ ref: "tabs/materials/_file-tab.twig" }).render({
                filename: filename
            }));

            // Update items state
            that.$itemPurgeUnused.closest('li').toggleClass('disabled', materials == null || materials.length == 0);

            // Update page
            that.$page.empty();
            that.$page.append(Twig.twig({ ref: "tabs/materials/_list.twig" }).render({
                errors: errors,
                warnings: warnings,
                materials: materials
            }));

            // Setup tooltips
            that.opencutlist.setupTooltips();

            // Bind rows
            $('.ladb-material-box', that.$page).each(function (index) {
                var $box = $(this);
                var materialId = $box.data('material-id');
                $box.on('click', function () {
                    that.editMaterial(materialId);
                });
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

    LadbTabMaterials.prototype.remove = function (material) {
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
                    that.loadList();
                }

            });

            // Hide modal
            $modal.modal('hide');

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
                that.loadList();
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

    // Material /////

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

    LadbTabMaterials.prototype.editMaterial = function (id, callback) {
        var that = this;

        var material = this.findMaterialById(id);
        if (material) {

            // Keep the edited material
            this.editedMaterial = material;

            var $modal = this.appendModalInside('ladb_materials_modal_material', 'tabs/materials/_modal-material.twig', {
                material: material
            });

            // Fetch UI elements
            var $btnTabTexture = $('#ladb_materials_btn_tab_texture', $modal);
            var $inputName = $('#ladb_materials_input_name', $modal);
            var $selectType = $('#ladb_materials_input_type', $modal);
            var $inputThickness = $('#ladb_materials_input_thickness', $modal);
            var $inputLengthIncrease = $('#ladb_materials_input_length_increase', $modal);
            var $inputWidthIncrease = $('#ladb_materials_input_width_increase', $modal);
            var $inputThicknessIncrease = $('#ladb_materials_input_thickness_increase', $modal);
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
            var disableBtnExport = function () {
                $btnExportToSkm.prop('disabled', true);
            };
            var computeFieldsVisibility = function (type) {
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
                    case 3:   // TYPE_BAR
                        $inputThickness.closest('.form-group').hide();
                        $inputLengthIncrease.closest('section').show();
                        $inputLengthIncrease.closest('.form-group').show();
                        $inputWidthIncrease.closest('.form-group').hide();
                        $inputThicknessIncrease.closest('.form-group').hide();
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
            computeFieldsVisibility(material.attributes.type);

            var setFiledValuesToDefaults = function (type) {
                var defaultThickness,
                    defaultLengthIncrease,
                    defaultWidthIncrease,
                    defaultThicknessIncrease,
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
                        defaultStdWidths = '';
                        defaultStdThicknesses = '5mm;8mm;10mm;15mm;18mm;22mm';
                        defaultStdSections = '';
                        defaultStdSizes = '';
                        defaultGrained = false;
                        defaultEdgeDecremented = false;
                        break;
                    case 3:   // TYPE_BAR
                        defaultThickness = '0';
                        defaultLengthIncrease = '50mm';
                        defaultWidthIncrease = '0';
                        defaultThicknessIncrease = '0';
                        defaultStdWidths = '';
                        defaultStdThicknesses = '';
                        defaultStdSections = '30mm x 40mm;40mm x 50mm';
                        defaultStdSizes = '';
                        defaultGrained = false;
                        defaultEdgeDecremented = false;
                        break;
                    case 4:   // TYPE_EDGE
                        defaultThickness = '2mm';
                        defaultLengthIncrease = '50mm';
                        defaultWidthIncrease = '0';
                        defaultThicknessIncrease = '0';
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
                setTokens($inputStdWidths, that.opencutlist.getSetting(SETTING_KEY_OPTION_PREFIX_TYPE + type + SETTING_KEY_OPTION_SUFFIX_STD_WIDTHS, defaultStdWidths));
                setTokens($inputStdThicknesses, that.opencutlist.getSetting(SETTING_KEY_OPTION_PREFIX_TYPE + type + SETTING_KEY_OPTION_SUFFIX_STD_THICKNESSES, defaultStdThicknesses));
                setTokens($inputStdSections, that.opencutlist.getSetting(SETTING_KEY_OPTION_PREFIX_TYPE + type + SETTING_KEY_OPTION_SUFFIX_STD_SECTIONS, defaultStdSections));
                setTokens($inputStdSizes, that.opencutlist.getSetting(SETTING_KEY_OPTION_PREFIX_TYPE + type + SETTING_KEY_OPTION_SUFFIX_STD_SIZES, defaultStdSizes));
                $selectGrained.selectpicker('val', that.opencutlist.getSetting(SETTING_KEY_OPTION_PREFIX_TYPE + type + SETTING_KEY_OPTION_SUFFIX_GRAINED, defaultGrained) ? '1' : '0');
                $selectEdgeDecremented.selectpicker('val', that.opencutlist.getSetting(SETTING_KEY_OPTION_PREFIX_TYPE + type + SETTING_KEY_OPTION_SUFFIX_EDGE_DECREMENTED, defaultEdgeDecremented) ? '1' : '0');
            };

            var rotateTexture = function (angle) {
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

            var getMaterialTexture = function (colorized) {
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

            var computeSizeAspectRatio = function (isWidthMaster) {
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

            // Bin tabs
            $btnTabTexture.on('shown.bs.tab', function (e) {

                getMaterialTexture(false);

                // Unbind event
                $btnTabTexture.off('shown.bs.tab');
            });

            // Bind change
            $('input', $modal).on('change', function () {
                disableBtnExport();
            });

            // Bind select
            $selectType.on('change', function () {
                var type = parseInt($(this).val());

                disableBtnExport();
                computeFieldsVisibility(type);
                setFiledValuesToDefaults(type);

            });
            $selectType.selectpicker(SELECT_PICKER_OPTIONS);
            $selectGrained.selectpicker(SELECT_PICKER_OPTIONS);
            $selectEdgeDecremented.selectpicker(SELECT_PICKER_OPTIONS);

            // Bind buttons
            $btnCutOptionsDefaultsSave.on('click', function () {

                var type = parseInt($selectType.val());
                var thickness = $inputThickness.val();
                var length_increase = $inputLengthIncrease.val();
                var width_increase = $inputWidthIncrease.val();
                var thickness_increase = $inputThicknessIncrease.val();
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
                setFiledValuesToDefaults(type);
                this.blur();
            });
            $btnTextureRotateLeft.on('click', function () {
                rotateTexture(-90);
                this.blur();
            });
            $btnTextureRotateRight.on('click', function () {
                rotateTexture(90);
                this.blur();
            });
            $btnTextureColorized.on('click', function () {
                $btnTextureColorized.toggleClass('active');
                getMaterialTexture($btnTextureColorized.hasClass('active'));
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
                that.remove(that.editedMaterial);
                this.blur();
            });
            $btnExportToSkm.on('click', function () {
                that.exportToSkm(that.editedMaterial, true);
                this.blur();
            });
            $btnUpdate.on('click', function () {

                that.editedMaterial.display_name = $inputName.val();
                that.editedMaterial.texture_rotation = parseInt($inputTextureRotation.val());
                that.editedMaterial.texture_width = $inputTextureWidth.val();
                that.editedMaterial.texture_height = $inputTextureHeight.val();
                that.editedMaterial.texture_colorized = $btnTextureColorized.hasClass('active');
                that.editedMaterial.attributes.type = $selectType.val();
                that.editedMaterial.attributes.thickness = $inputThickness.val();
                that.editedMaterial.attributes.length_increase = $inputLengthIncrease.val();
                that.editedMaterial.attributes.width_increase = $inputWidthIncrease.val();
                that.editedMaterial.attributes.thickness_increase = $inputThicknessIncrease.val();
                that.editedMaterial.attributes.std_widths = $inputStdWidths.val();
                that.editedMaterial.attributes.std_thicknesses = $inputStdThicknesses.val();
                that.editedMaterial.attributes.std_sections = $inputStdSections.val();
                that.editedMaterial.attributes.std_sizes = $inputStdSizes.val();
                that.editedMaterial.attributes.grained = $selectGrained.val() === '1';
                that.editedMaterial.attributes.edge_decremented = $selectEdgeDecremented.val() === '1';

                // Flag to ignore next material change event
                that.ignoreNextMaterialEvents = true;

                rubyCallCommand('materials_update', that.editedMaterial, function (response) {

                    // Flag to stop ignoring next material change event
                    that.ignoreNextMaterialEvents = false;

                    if (response['errors']) {
                        that.opencutlist.notifyErrors(response['errors']);
                    } else {
                        that.loadList();
                    }

                    // Reset edited material
                    that.editedMaterial = null;

                    // Hide modal
                    $modal.modal('hide');

                });

            });

            // Bind inputs
            $inputTextureWidth.on('blur', function () {
                computeSizeAspectRatio(true);
            });
            $inputTextureHeight.on('blur', function () {
                computeSizeAspectRatio(false);
            });

            // Show modal
            $modal.modal('show');

            // Init tokenfields (this must done after modal shown for correct token label max width measurement)
            $inputStdWidths.tokenfield(TOKENFIELD_OPTIONS).on('tokenfield:createdtoken', that.tokenfieldValidatorFn_d);
            $inputStdThicknesses.tokenfield(TOKENFIELD_OPTIONS).on('tokenfield:createdtoken', that.tokenfieldValidatorFn_d);
            $inputStdSections.tokenfield(TOKENFIELD_OPTIONS).on('tokenfield:createdtoken', that.tokenfieldValidatorFn_dxd);
            $inputStdSizes.tokenfield(TOKENFIELD_OPTIONS).on('tokenfield:createdtoken', that.tokenfieldValidatorFn_dxd);

            // Setup tooltips & popovers
            this.opencutlist.setupTooltips();
            this.opencutlist.setupPopovers();

            /// Callback
            if (typeof(callback) === 'function') {
                callback($modal);
            }

        } else {
            alert('Material not found (id=' + id + ')');
        }
    };

    // Internals /////

    LadbTabMaterials.prototype.showOutdated = function (messageI18nKey) {
        var that = this;

        var $modal = this.appendModalInside('ladb_materials_modal_outdated', 'tabs/materials/_modal-outdated.twig', {
            messageI18nKey: messageI18nKey
        });

        // Fetch UI elements
        var $btnRefresh = $('#ladb_materials_outdated_refresh', $modal);

        // Bind buttons
        $btnRefresh.on('click', function () {
            $modal.modal('hide');
            that.loadList();
        });

        // Show modal
        $modal.modal('show');

    };

    LadbTabMaterials.prototype.bind = function () {
        LadbAbstractTab.prototype.bind.call(this);

        var that = this;

        // Bind buttons
        this.$btnList.on('click', function () {
            that.loadList();
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
            that.showOutdated('core.event.model_change');
        });
        addEventCallback([ 'on_material_add', 'on_material_remove', 'on_material_change' ], function () {
            if (!that.ignoreNextMaterialEvents) {
                that.showOutdated('core.event.material_change');
            }
        });

    };

    LadbTabMaterials.prototype.init = function (initializedCallback) {
        var that = this;

        // Register commands
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
        for (var type = 0; type <= 3; type++) {     // 3 = TYPE_BAR
            settingsKeys.push(SETTING_KEY_OPTION_PREFIX_TYPE + type + SETTING_KEY_OPTION_SUFFIX_THICKNESS);
            settingsKeys.push(SETTING_KEY_OPTION_PREFIX_TYPE + type + SETTING_KEY_OPTION_SUFFIX_LENGTH_INCREASE);
            settingsKeys.push(SETTING_KEY_OPTION_PREFIX_TYPE + type + SETTING_KEY_OPTION_SUFFIX_WIDTH_INCREASE);
            settingsKeys.push(SETTING_KEY_OPTION_PREFIX_TYPE + type + SETTING_KEY_OPTION_SUFFIX_THICKNESS_INCREASE);
            settingsKeys.push(SETTING_KEY_OPTION_PREFIX_TYPE + type + SETTING_KEY_OPTION_SUFFIX_STD_WIDTHS);
            settingsKeys.push(SETTING_KEY_OPTION_PREFIX_TYPE + type + SETTING_KEY_OPTION_SUFFIX_STD_THICKNESSES);
            settingsKeys.push(SETTING_KEY_OPTION_PREFIX_TYPE + type + SETTING_KEY_OPTION_SUFFIX_STD_SECTIONS);
            settingsKeys.push(SETTING_KEY_OPTION_PREFIX_TYPE + type + SETTING_KEY_OPTION_SUFFIX_STD_SIZES);
            settingsKeys.push(SETTING_KEY_OPTION_PREFIX_TYPE + type + SETTING_KEY_OPTION_SUFFIX_GRAINED);
            settingsKeys.push(SETTING_KEY_OPTION_PREFIX_TYPE + type + SETTING_KEY_OPTION_SUFFIX_EDGE_DECREMENTED);
        }

        this.opencutlist.pullSettings(settingsKeys, 0 /* SETTINGS_RW_STRATEGY_GLOBAL */, function () {

            that.bind();

            if (initializedCallback && typeof(initializedCallback) == 'function') {
                initializedCallback(that.$element);
            } else {
                setTimeout(function () {     // Use setTimer to give time tu UI to refresh
                    that.loadList();
                }, 1);
            }

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
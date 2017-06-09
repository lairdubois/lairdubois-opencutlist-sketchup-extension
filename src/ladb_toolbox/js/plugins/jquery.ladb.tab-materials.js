+function ($) {
    'use strict';

    // CONSTANTS
    // ======================

    // Options keys

    var SETTING_KEY_OPTION_PREFIX = 'materials_option_';
    var SETTING_KEY_OPTION_PREFIX_TYPE = SETTING_KEY_OPTION_PREFIX + 'type_';

    var SETTING_KEY_OPTION_SUFFIX_LENGTH_INCREASE = '_length_increase';
    var SETTING_KEY_OPTION_SUFFIX_WIDTH_INCREASE = '_width_increase';
    var SETTING_KEY_OPTION_SUFFIX_THICKNESS_INCREASE = '_thickness_increase';
    var SETTING_KEY_OPTION_SUFFIX_STD_THICKNESSES = '_std_thicknesses';

    // Select picker options

    var SELECT_PICKER_OPTIONS = {
        size: 10,
        iconBase: 'ladb-toolbox-icon',
        tickIcon: 'ladb-toolbox-icon-tick',
        showTick: true
    };

    // CLASS DEFINITION
    // ======================

    var LadbTabMaterials = function (element, options, toolbox) {
        LadbAbstractTab.call(this, element, options, toolbox);

        this.materials = [];
        this.editedMaterial = null;
        this.ignoreNextMaterialChangeEvent = false;

        this.$header = $('.ladb-header', this.$element);
        this.$fileTabs = $('.ladb-file-tabs', this.$header);
        this.$btnList = $('#ladb_btn_list', this.$header);
        this.$itemPurgeUnused = $('#ladb_item_purge_unused', this.$header);

        this.$page = $('.ladb-page', this.$element);

    };
    LadbTabMaterials.prototype = new LadbAbstractTab;

    LadbTabMaterials.DEFAULTS = {};

    // List /////

    LadbTabMaterials.prototype.loadList = function () {
        var that = this;

        this.materials = [];
        this.$page.empty();
        this.$btnList.prop('disabled', true);

        rubyCallCommand('materials_list', null, function(response) {

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
            that.$itemPurgeUnused.closest('li').toggleClass('disabled', materials.length == 0);

            // Update page
            that.$page.empty();
            that.$page.append(Twig.twig({ ref: "tabs/materials/_list.twig" }).render({
                errors: errors,
                warnings: warnings,
                materials: materials
            }));

            // Setup tooltips
            that.toolbox.setupTooltips();

            // Bind rows
            $('.ladb-material-box', that.$page).each(function(index) {
                var $box = $(this);
                var materialId = $box.data('material-id');
                $box.on('click', function() {
                    that.editMaterial(materialId);
                });
            });

            // Restore button state
            that.$btnList.prop('disabled', false);

            // Stick header
            that.$header.stick_in_parent();

        });

    };

    LadbTabMaterials.prototype.purgeUnused = function () {
        rubyCallCommand('materials_purge_unused');
    };

    // Material /////

    LadbTabMaterials.prototype.findMaterialById = function (id) {
        var material;
        for (var i = 0; i < this.materials.length; i++) {
            material = this.materials[i];
            if (material.id == id) {
                return material;
            }
        }
        return null;
    };

    LadbTabMaterials.prototype.editMaterial = function (id) {
        var that = this;

        var material = this.findMaterialById(id);
        if (material) {

            // Keep the edited material
            this.editedMaterial = material;

            var $modal = this.showModalInside('ladb_materials_modal_material', 'tabs/materials/_modal-material.twig', {
                material: material
            });

            // Fetch UI elements
            var $inputName = $('#ladb_materials_input_name', $modal);
            var $selectType = $('#ladb_materials_input_type', $modal);
            var $inputLengthIncrease = $('#ladb_materials_input_length_increase', $modal);
            var $inputWidthIncrease = $('#ladb_materials_input_width_increase', $modal);
            var $inputThicknessIncrease = $('#ladb_materials_input_thickness_increase', $modal);
            var $inputStdThicknesses = $('#ladb_materials_input_std_thicknesses', $modal);
            var $spanCutOptionsDefaultsType1 = $('#ladb_materials_span_cut_options_defaults_type_1', $modal);
            var $spanCutOptionsDefaultsType2 = $('#ladb_materials_span_cut_options_defaults_type_2', $modal);
            var $btnCutOptionsDefaultsSave = $('#ladb_materials_btn_cut_options_defaults_save', $modal);
            var $btnCutOptionsDefaultsReset = $('#ladb_materials_btn_cut_options_defaults_reset', $modal);
            var $btnUpdate = $('#ladb_materials_update', $modal);

            // Define usefull functions
            var computeFieldsVisibility = function(type) {
                switch (type) {
                    case 0:   // TYPE_UNKNOW
                        $inputLengthIncrease.closest('section').hide();
                        break;
                    case 1:   // TYPE_SOLID_WOOD
                        $inputLengthIncrease.closest('section').show();
                        $inputLengthIncrease.closest('.form-group').show();
                        $inputWidthIncrease.closest('.form-group').show();
                        $inputThicknessIncrease.closest('.form-group').show();
                        $inputStdThicknesses.closest('.form-group').show();
                        $spanCutOptionsDefaultsType1.show();
                        $spanCutOptionsDefaultsType2.hide();
                        break;
                    case 2:   // TYPE_SHEET_GOOD
                        $inputLengthIncrease.closest('section').show();
                        $inputLengthIncrease.closest('.form-group').show();
                        $inputWidthIncrease.closest('.form-group').show();
                        $inputThicknessIncrease.closest('.form-group').hide();
                        $inputStdThicknesses.closest('.form-group').show();
                        $spanCutOptionsDefaultsType1.hide();
                        $spanCutOptionsDefaultsType2.show();
                        break;
                }
            };
            computeFieldsVisibility(material.attributes.type);

            var setFiledValuesToDefaults = function(type) {
                var defaultLengthIncrease,
                    defaultWidthIncrease,
                    defaultThicknessIncrease,
                    defaultStdThicknesses;
                switch (type) {
                    case 0:   // TYPE_UNKNOW
                        defaultLengthIncrease = '0';
                        defaultWidthIncrease = '0';
                        defaultThicknessIncrease = '0';
                        defaultStdThicknesses = '';
                        break;
                    case 1:   // TYPE_SOLID_WOOD
                        defaultLengthIncrease = '50mm';
                        defaultWidthIncrease = '5mm';
                        defaultThicknessIncrease = '5mm';
                        defaultStdThicknesses = '18mm;27mm;35mm;45mm;54mm;65mm;80mm;100mm';
                        break;
                    case 2:   // TYPE_SHEET_GOOD
                        defaultLengthIncrease = '10mm';
                        defaultWidthIncrease = '10mm';
                        defaultThicknessIncrease = '0';
                        defaultStdThicknesses = '4mm;8mm;10mm;15mm;18mm;22mm';
                        break;
                }
                $inputLengthIncrease.val(that.toolbox.getSetting(SETTING_KEY_OPTION_PREFIX_TYPE + type + SETTING_KEY_OPTION_SUFFIX_LENGTH_INCREASE, defaultLengthIncrease));
                $inputWidthIncrease.val(that.toolbox.getSetting(SETTING_KEY_OPTION_PREFIX_TYPE + type + SETTING_KEY_OPTION_SUFFIX_WIDTH_INCREASE, defaultWidthIncrease));
                $inputThicknessIncrease.val(that.toolbox.getSetting(SETTING_KEY_OPTION_PREFIX_TYPE + type + SETTING_KEY_OPTION_SUFFIX_THICKNESS_INCREASE, defaultThicknessIncrease));
                $inputStdThicknesses.tokenfield('setTokens', that.toolbox.getSetting(SETTING_KEY_OPTION_PREFIX_TYPE + type + SETTING_KEY_OPTION_SUFFIX_STD_THICKNESSES, defaultStdThicknesses));
            };

            // Bind select
            $selectType.on('change', function () {
                var type = parseInt($(this).val());

                computeFieldsVisibility(type);
                setFiledValuesToDefaults(type);

            });
            $selectType.selectpicker(SELECT_PICKER_OPTIONS);

            // Init tokenfield
            $inputStdThicknesses.tokenfield({
                delimiter: ';'
            });

            // Bind buttons
            $btnCutOptionsDefaultsSave.on('click', function() {

                var type = $selectType.val();
                var length_increase = $inputLengthIncrease.val();
                var width_increase = $inputWidthIncrease.val();
                var thickness_increase = $inputThicknessIncrease.val();
                var std_thicknesses = $inputStdThicknesses.val();

                // Update default cut options for specific type to last used
                that.toolbox.setSettings([
                    { key:SETTING_KEY_OPTION_PREFIX_TYPE + type + SETTING_KEY_OPTION_SUFFIX_LENGTH_INCREASE, value:length_increase },
                    { key:SETTING_KEY_OPTION_PREFIX_TYPE + type + SETTING_KEY_OPTION_SUFFIX_WIDTH_INCREASE, value:width_increase },
                    { key:SETTING_KEY_OPTION_PREFIX_TYPE + type + SETTING_KEY_OPTION_SUFFIX_THICKNESS_INCREASE, value:thickness_increase },
                    { key:SETTING_KEY_OPTION_PREFIX_TYPE + type + SETTING_KEY_OPTION_SUFFIX_STD_THICKNESSES, value:std_thicknesses }
                ]);

                that.toolbox.notify(i18next.t('tab.materials.edit_material.cut_options_defaults.save_success', { type_name: i18next.t('tab.materials.type_' + type) }), 'success');

            });
            $btnCutOptionsDefaultsReset.on('click', function() {

                var type = $selectType.val();

                setFiledValuesToDefaults(type);

            });
            $btnUpdate.on('click', function () {

                that.editedMaterial.display_name = $inputName.val();
                that.editedMaterial.attributes.type = $selectType.val();
                that.editedMaterial.attributes.length_increase = $inputLengthIncrease.val();
                that.editedMaterial.attributes.width_increase = $inputWidthIncrease.val();
                that.editedMaterial.attributes.thickness_increase = $inputThicknessIncrease.val();
                that.editedMaterial.attributes.std_thicknesses = $inputStdThicknesses.val();

                // Flag to ignore next material change event
                that.ignoreNextMaterialChangeEvent = true;

                rubyCallCommand('materials_update', that.editedMaterial, function() {

                    // Reset edited material
                    that.editedMaterial = null;

                    // Hide modal
                    $modal.modal('hide');

                    // Refresh the list
                    that.loadList();

                });

            });

        }
    };

    // Internals /////

    LadbTabMaterials.prototype.showOutdated = function (messageI18nKey) {
        var that = this;

        var $modal = this.showModalInside('ladb_materials_modal_outdated', 'tabs/materials/_modal-outdated.twig', {
            messageI18nKey: messageI18nKey
        });

        // Fetch UI elements
        var $btnRefresh = $('#ladb_materials_outdated_refresh', $modal);

        // Bind buttons
        $btnRefresh.on('click', function () {
            $modal.modal('hide');
            that.loadList();
        });

    };

    LadbTabMaterials.prototype.bind = function () {
        var that = this;

        // Bind buttons
        this.$btnList.on('click', function () {
            that.loadList();
            this.blur();
        });
        this.$itemPurgeUnused.on('click', function () {
            that.purgeUnused();
            this.blur();
        });

        // Events

        addEventCallback([ 'on_new_model', 'on_activate_model' ], function(params) {
            that.showOutdated('core.event.model_change');
        });
        addEventCallback([ 'on_material_add', 'on_material_remove', 'on_material_change' ], function() {
            if (!that.ignoreNextMaterialChangeEvent) {
                that.showOutdated('core.event.material_change');
                that.ignoreNextMaterialChangeEvent = false;
            }
        });

    };

    LadbTabMaterials.prototype.init = function () {
        var that = this;

        var settingsKeys = [];
        for (var type = 0; type <= 2; type++) {
            settingsKeys.push(SETTING_KEY_OPTION_PREFIX_TYPE + type + SETTING_KEY_OPTION_SUFFIX_LENGTH_INCREASE);
            settingsKeys.push(SETTING_KEY_OPTION_PREFIX_TYPE + type + SETTING_KEY_OPTION_SUFFIX_WIDTH_INCREASE);
            settingsKeys.push(SETTING_KEY_OPTION_PREFIX_TYPE + type + SETTING_KEY_OPTION_SUFFIX_THICKNESS_INCREASE);
            settingsKeys.push(SETTING_KEY_OPTION_PREFIX_TYPE + type + SETTING_KEY_OPTION_SUFFIX_STD_THICKNESSES);
        }

        this.toolbox.pullSettings(settingsKeys, function() {

            that.bind();

            setTimeout(function() {
                that.loadList();
            }, 500);

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
                if (undefined === options.toolbox) {
                    throw 'toolbox option is mandatory.';
                }
                $this.data('ladb.tabMaterials', (data = new LadbTabMaterials(this, options, options.toolbox)));
            }
            if (typeof option == 'string') {
                data[option](params);
            } else {
                data.init();
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
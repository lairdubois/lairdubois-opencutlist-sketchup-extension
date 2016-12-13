+function ($) {
    'use strict';

    // CLASS DEFINITION
    // ======================

    var LadbTabMaterials = function (element, options, toolbox) {
        this.options = options;
        this.$element = $(element);
        this.toolbox = toolbox;

        this.materials = [];
        this.currentMaterial = null;

        this.$btnList = $('#ladb_btn_list', this.$element);
        this.$alertErrors = $('.ladb-alert-errors', this.$element);
        this.$alertWarnings = $('.ladb-alert-warnings', this.$element);
        this.$list = $('#materials_list', this.$element);
        this.$modal = $('#materials_modal', this.$element);
        this.$inputName = $('#ladb_materials_input_name', this.$modal);
        this.$inputType = $('#ladb_materials_input_type', this.$modal);
        this.$inputLengthIncrease = $('#ladb_materials_input_length_increase', this.$modal);
        this.$inputWidthIncrease = $('#ladb_materials_input_width_increase', this.$modal);
        this.$inputThicknessIncrease = $('#ladb_materials_input_thickness_increase', this.$modal);
        this.$inputStdThicknesses = $('#ladb_materials_input_std_thicknesses', this.$modal);
        this.$btnUpdate = $('#ladb_materials_update', this.$modal);
    };

    LadbTabMaterials.DEFAULTS = {};

    LadbTabMaterials.prototype.loadList = function () {
        rubyCall('ladb_materials_list', null);
    };

    LadbTabMaterials.prototype.onList = function (data) {
        var that = this;

        var errors = data.errors;
        this.materials = data.materials;

        // Errors
        this.$alertErrors.empty();
        if (errors && errors.length > 0) {
            that.$alertErrors.show();
            errors.forEach(function (error) {
                that.$alertErrors.append(error);
            });
        } else {
            that.$alertErrors.hide();
        }

        // Update list
        this.$list.empty();
        this.$list.append(Twig.twig({ ref: "tabs/materials/_list.twig" }).render({
            materials: this.materials
        }));

        // Bind rows
        $('.ladb-material-box', this.$list).each(function(index) {
            var $box = $(this);
            var materialId = $box.data('material-id');
            $box.on('click', function() {
                that.editMaterial(materialId);
            });
        });

    };

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
        var material = this.findMaterialById(id);
        if (material) {

            this.currentMaterial = material;

            // Title
            var $modalTitle = $('.modal-title', this.$modal);
            $modalTitle.html(material.display_name);

            // Form fields
            this.$inputName.val(material.display_name);
            this.$inputType.val(material.attributes.type);
            this.$inputLengthIncrease.val(material.attributes.length_increase);
            this.$inputWidthIncrease.val(material.attributes.width_increase);
            this.$inputThicknessIncrease.val(material.attributes.thickness_increase);
            this.$inputStdThicknesses.val(material.attributes.std_thicknesses);

            // Arrange cut options form section
            this.arrangeCutOptionsFormSectionByType(material.attributes.type);

            this.$modal.modal('show');
        }
    };

    LadbTabMaterials.prototype.arrangeCutOptionsFormSectionByType = function (type) {
        switch (type) {
            case 0:   // TYPE_UNKNOW
                this.$inputLengthIncrease.closest('section').hide();
                break;
            case 1:   // TYPE_HARDWOOD
                this.$inputLengthIncrease.closest('section').show();
                this.$inputLengthIncrease.closest('.form-group').show();
                this.$inputWidthIncrease.closest('.form-group').show();
                this.$inputThicknessIncrease.closest('.form-group').show();
                this.$inputStdThicknesses.closest('.form-group').show();
                break;
            case 2:   // TYPE_PLYWOOD
                this.$inputLengthIncrease.closest('section').show();
                this.$inputLengthIncrease.closest('.form-group').show();
                this.$inputWidthIncrease.closest('.form-group').show();
                this.$inputThicknessIncrease.closest('.form-group').hide();
                this.$inputStdThicknesses.closest('.form-group').show();
                break;
        }
    };

    LadbTabMaterials.prototype.populateDefaultCutOptionsFormSectionByType = function (type) {
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
            case 1:   // TYPE_HARDWOOD
                defaultLengthIncrease = '50mm';
                defaultWidthIncrease = '5mm';
                defaultThicknessIncrease = '5mm';
                defaultStdThicknesses = '18mm;27mm;35mm;45mm;80mm;100mm';
                break;
            case 2:   // TYPE_PLYWOOD
                defaultLengthIncrease = '10mm';
                defaultWidthIncrease = '10mm';
                defaultThicknessIncrease = '0';
                defaultStdThicknesses = '4mm;8mm;10mm;15mm;18mm;22mm';
                break;
        }
        this.$inputLengthIncrease.val(this.toolbox.getSettingsValue('materials_type_' + type + '_length_increase', defaultLengthIncrease));
        this.$inputWidthIncrease.val(this.toolbox.getSettingsValue('materials_type_' + type + '_width_increase', defaultWidthIncrease));
        this.$inputThicknessIncrease.val(this.toolbox.getSettingsValue('materials_type_' + type + '_thickness_increase', defaultThicknessIncrease));
        this.$inputStdThicknesses.val(this.toolbox.getSettingsValue('materials_type_' + type + '_std_thicknesses', defaultStdThicknesses));
    };

    LadbTabMaterials.prototype.storeDefaultCutOptionsFormSectionByType = function (type) {
        this.toolbox.setSettingsValue('materials_type_' + type + '_length_increase', this.$inputLengthIncrease.val());
        this.toolbox.setSettingsValue('materials_type_' + type + '_width_increase', this.$inputWidthIncrease.val());
        this.toolbox.setSettingsValue('materials_type_' + type + '_thickness_increase', this.$inputThicknessIncrease.val());
        this.toolbox.setSettingsValue('materials_type_' + type + '_std_thicknesses', this.$inputStdThicknesses.val());
    };

    LadbTabMaterials.prototype.bind = function () {
        var that = this;

        // Bind buttons
        this.$btnList.on('click', function () {
            that.loadList();
        });
        this.$btnUpdate.on('click', function () {

            that.currentMaterial.display_name = that.$inputName.val();
            that.currentMaterial.attributes.type = that.$inputType.val();
            that.currentMaterial.attributes.length_increase = that.$inputLengthIncrease.val();
            that.currentMaterial.attributes.width_increase = that.$inputWidthIncrease.val();
            that.currentMaterial.attributes.thickness_increase = that.$inputThicknessIncrease.val();
            that.currentMaterial.attributes.std_thicknesses = that.$inputStdThicknesses.val();

            rubyCall('ladb_materials_update', that.currentMaterial);

            that.storeDefaultCutOptionsFormSectionByType(that.$inputType.val());

            that.$modal.modal('hide');
        });

        // Bind inputs
        this.$inputType.on('change', function () {
            var type = parseInt(that.$inputType.val());
            that.arrangeCutOptionsFormSectionByType(type);
            that.populateDefaultCutOptionsFormSectionByType(type);
        });

    };

    LadbTabMaterials.prototype.init = function () {
        this.bind();
        setTimeout(this.loadList, 500);
    };


    // PLUGIN DEFINITION
    // =======================

    function Plugin(option, params) {
        return this.each(function () {
            var $this = $(this);
            var data = $this.data('ladb.tabMaterials');
            var options = $.extend({}, LadbTabMaterials.DEFAULTS, $this.data(), typeof option == 'object' && option);

            if (!data) {
                if (options.toolbox == undefined) {
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
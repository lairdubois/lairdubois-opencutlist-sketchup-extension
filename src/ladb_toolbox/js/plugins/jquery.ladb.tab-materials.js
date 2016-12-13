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

    LadbTabMaterials.prototype.onList = function (data) {
        var that = this;

        this.materials = data;

        // Update list
        this.$list.empty();
        this.$list.append(Twig.twig({ ref: "tabs/materials/_list.twig" }).render({
            materials: this.materials
        }));

        // Bind rows
        $('.ladb-material-box', this.$list).each(function(index) {
            var $row = $(this);
            var materialId = $row.data('material-id');
            $('.ladb-btn-material-edit', $row).on('click', function() {
                that.editMaterial(materialId);
                $(this).blur();
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

            this.$modal.modal('show');
        }
    };

    LadbTabMaterials.prototype.bind = function () {
        var that = this;

        // Bind buttons
        this.$btnList.on('click', function () {
            rubyCall('ladb_materials_list', null);
        });
        this.$btnUpdate.on('click', function () {

            that.currentMaterial.display_name = that.$inputName.val();
            that.currentMaterial.attributes.type = that.$inputType.val();
            that.currentMaterial.attributes.length_increase = that.$inputLengthIncrease.val();
            that.currentMaterial.attributes.width_increase = that.$inputWidthIncrease.val();
            that.currentMaterial.attributes.thickness_increase = that.$inputThicknessIncrease.val();
            that.currentMaterial.attributes.std_thicknesses = that.$inputStdThicknesses.val();

            rubyCall('ladb_materials_update', {
                material: that.currentMaterial
            });

            that.$modal.modal('hide');
        });

    };

    LadbTabMaterials.prototype.init = function () {
        this.bind();
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
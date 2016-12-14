+function ($) {
    'use strict';

    var LADB_LENGTH_UNIT_INFOS = {
        0: {name: 'pouce', unit: 'in'},
        1: {name: 'pied', unit: 'ft'},
        2: {name: 'millimètre', unit: 'mm'},
        3: {name: 'centimètre', unit: 'cm'},
        4: {name: 'mètre', unit: 'm'}
    };

    // CLASS DEFINITION
    // ======================

    var LadbTabCutlist = function (element, options, toolbox) {
        this.options = options;
        this.$element = $(element);
        this.toolbox = toolbox;

        this.lengthUnitInfos = LADB_LENGTH_UNIT_INFOS[2];

        this.groups = [];
        this.materialUsages = [];
        this.editedPart = null;

        this.partNumberLetter = this.toolbox.getSettingsValue('cutlist_part_number_letter', true);
        this.partNumberSequenceByGroup = this.toolbox.getSettingsValue('cutlist_part_number_sequence_by_group', false);

        this.$filename = $('#ladb_filename', this.$element);
        this.$unit = $('#ladb_unit', this.$element);
        this.$btnGenerate = $('#ladb_btn_generate', this.$element);
        this.$btnPrint = $('#ladb_btn_print', this.$element);
        this.$panelHelp = $('.ladb-panel-help', this.$element);
        this.$inputPartNumberSequenceByGroup = $('#ladb_input_part_number_sequence_by_group', this.$element);
        this.$inputPartNumberLetter = $('#ladb_input_part_number_letter', this.$element);
        this.$list = $('#list', this.$element);
        this.$modalEdit = $('#cutlist_part_modal', this.$element);
        this.$btnPartUpdate = $('#ladb_cutlist_part_update', this.$modalEdit);
        this.$selectMaterialName = $('#ladb_cutlist_part_select_material_name', this.$modalEdit);
        this.$inputPartName = $('#ladb_cutlist_part_input_name', this.$modalEdit);
    };

    LadbTabCutlist.DEFAULTS = {};

    LadbTabCutlist.prototype.getLengthUnitInfos = function (lengthUnitIndex) {
        if (lengthUnitIndex < 0 || lengthUnitIndex >= LADB_LENGTH_UNIT_INFOS.length) {
            return null;
        }
        return LADB_LENGTH_UNIT_INFOS[lengthUnitIndex];
    };

    LadbTabCutlist.prototype.generateCutlist = function () {
        this.groups = [];
        this.$list.empty();
        this.$btnGenerate.prop('disabled', true);
        rubyCall('ladb_cutlist_generate', {
            part_number_letter: this.partNumberLetter,
            part_number_sequence_by_group: this.partNumberSequenceByGroup
        });
    };

    LadbTabCutlist.prototype.onCutlistGenerated = function (data) {
        var that = this;

        var status = data.status;
        var errors = data.errors;
        var warnings = data.warnings;
        var filepath = data.filepath;
        var lengthUnit = data.length_unit;
        var materialUsages = data.material_usages;
        var groups = data.groups;

        // Keep usefull data
        this.groups = groups;
        this.materialUsages = materialUsages;

        // Update filename
        this.$filename.empty();
        this.$filename.append(filepath.split('\\').pop().split('/').pop());

        // Update unit and length options
        this.lengthUnitInfos = this.getLengthUnitInfos(lengthUnit);
        this.$unit.empty();
        this.$unit.append(' en ' + this.lengthUnitInfos.name);

        // Hide help panel
        if (groups.length > 0) {
            this.$panelHelp.hide();
        }

        // Update print button state
        this.$btnPrint.prop('disabled', groups.length == 0);

        // Update list
        this.$list.empty();
        this.$list.append(Twig.twig({ ref: "tabs/cutlist/_list.twig" }).render({
            errors: errors,
            warnings: warnings,
            groups: groups
        }));

        // Bind buttons
        $('.ladb-btn-toggle-no-print', this.$list).on('click', function() {
            var $i = $('i', $(this));
            var groupId = $(this).data('group-id');
            var $group = $('#' + groupId);
            $group.toggleClass('no-print');
            if ($group.hasClass('no-print')) {
                $i.removeClass('ladb-toolbox-icon-eye-close');
                $i.addClass('ladb-toolbox-icon-eye-open');
            } else {
                $i.addClass('ladb-toolbox-icon-eye-close');
                $i.removeClass('ladb-toolbox-icon-eye-open');
            }
            $(this).blur();
        });
        $('a.ladb-scrollto', this.$list).on('click', function() {
            var target = $(this).attr('href');
            $('html, body').animate({ scrollTop: $(target).offset().top - 20 }, 500).promise().then(function() {
                $(target).effect("highlight", {}, 1500);
            });
            $(this).blur();
            return false;
        });
        $('a.ladb-btn-edit', this.$list).on('click', function() {
            var partGuid = $(this).data('part-id');
            that.editPart(partGuid);
            $(this).blur();
            return false;
        });

        // Restore button state
        this.$btnGenerate.prop('disabled', false);

    };

    LadbTabCutlist.prototype.findPartById = function (id) {
        for (var i = 0 ; i < this.groups.length; i++) {
            var group = this.groups[i];
            for (var j = 0; j < group.parts.length; j++) {
                var part = group.parts[j];
                if (part.id == id) {
                    return part;
                }
            }
        }
        return null;
    };

    LadbTabCutlist.prototype.editPart = function (id) {
        var part = this.findPartById(id);
        if (part) {

            // Keep the edited part
            this.editedPart = part;

            // Populate material select
            this.$selectMaterialName.empty();
            this.$selectMaterialName.append(Twig.twig({ ref: "tabs/cutlist/_material_usages.twig" }).render({
                materialUsages: this.materialUsages
            }));

            // Form fields
            this.$inputPartName.val(part.name);
            this.$selectMaterialName.val(part.material_name);

            this.$modalEdit.modal('show');
        }
    };

    LadbTabCutlist.prototype.bind = function () {
        var that = this;

        // Bind buttons
        this.$btnGenerate.on('click', function () {
            that.generateCutlist();
            this.blur();
        });
        this.$btnPrint.on('click', function () {
            window.print();
            this.blur();
        });
        this.$btnPartUpdate.on('click', function () {

            that.editedPart.name = that.$inputPartName.val();
            that.editedPart.material_name = that.$selectMaterialName.val();

            rubyCall('ladb_cutlist_part_update', that.editedPart);

            // Reset edited material
            that.editedPart = null;

            // Hide modal
            that.$modalEdit.modal('hide');

        });

        // Bind inputs
        this.$inputPartNumberLetter.on('change', function () {
            that.partNumberLetter = that.$inputPartNumberLetter.is(':checked');
            that.toolbox.setSettingsValue('cutlist_part_number_letter', that.partNumberLetter);
        });
        this.$inputPartNumberSequenceByGroup.on('change', function () {
            that.partNumberSequenceByGroup = that.$inputPartNumberSequenceByGroup.is(':checked');
            that.toolbox.setSettingsValue('cutlist_part_number_sequence_by_group', that.partNumberSequenceByGroup);
        });

    };

    LadbTabCutlist.prototype.init = function () {
        this.bind();

        // Init inputs values
        this.$inputPartNumberLetter.prop('checked', this.partNumberLetter);
        this.$inputPartNumberSequenceByGroup.prop('checked', this.partNumberSequenceByGroup);
    };


    // PLUGIN DEFINITION
    // =======================

    function Plugin(option, params) {
        return this.each(function () {
            var $this = $(this);
            var data = $this.data('ladb.tabCutlist');
            var options = $.extend({}, LadbTabCutlist.DEFAULTS, $this.data(), typeof option == 'object' && option);

            if (!data) {
                if (options.toolbox == undefined) {
                    throw 'toolbox option is mandatory.';
                }
                $this.data('ladb.tabCutlist', (data = new LadbTabCutlist(this, options, options.toolbox)));
            }
            if (typeof option == 'string') {
                data[option](params);
            } else {
                data.init();
            }
        })
    }

    var old = $.fn.ladbTabCutlist;

    $.fn.ladbTabCutlist = Plugin;
    $.fn.ladbTabCutlist.Constructor = LadbTabCutlist;


    // NO CONFLICT
    // =================

    $.fn.ladbTabCutlist.noConflict = function () {
        $.fn.ladbTabCutlist = old;
        return this;
    }

}(jQuery);
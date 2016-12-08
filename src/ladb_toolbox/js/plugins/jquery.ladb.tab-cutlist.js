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

        this.lengthIncrease = this.toolbox.getSettingsValue('lengthIncrease', 50);
        this.widthIncrease = this.toolbox.getSettingsValue('widthIncrease', 5);
        this.thicknessIncrease = this.toolbox.getSettingsValue('thicknessIncrease', 5);
        this.stdThicknesses = this.toolbox.getSettingsValue('stdThicknesses', '18;27;35;45;64;80;100');
        this.pieceNumberLetter = this.toolbox.getSettingsValue('pieceNumberLetter', true);
        this.pieceNumberSequenceByGroup = this.toolbox.getSettingsValue('pieceNumberSequenceByGroup', false);

        this.$filename = $('#ladb_filename', this.$element);
        this.$unit = $('#ladb_unit', this.$element);
        this.$btnRefresh = $('#ladb_btn_refresh', this.$element);
        this.$btnPrint = $('#ladb_btn_print', this.$element);
        this.$panelHelp = $('.ladb-panel-help', this.$element);
        this.$alertErrors = $('.ladb-alert-errors', this.$element);
        this.$alertWarnings = $('.ladb-alert-warnings', this.$element);
        this.$inputLengthIncrease = $('#ladb_input_length_increase', this.$element);
        this.$inputWidthIncrease = $('#ladb_input_width_increase', this.$element);
        this.$inputThicknessIncrease = $('#ladb_input_thickness_increase', this.$element);
        this.$inputStdThicknesses = $('#ladb_input_std_thicknesses', this.$element);
        this.$inputPieceNumberSequenceByGroup = $('#ladb_input_piece_number_sequence_by_group', this.$element);
        this.$inputPieceNumberLetter = $('#ladb_input_piece_number_letter', this.$element);
        this.$list = $('#list', this.$element);
    };

    LadbTabCutlist.DEFAULTS = {};

    LadbTabCutlist.prototype.getLengthUnitInfos = function (lengthUnitIndex) {
        if (lengthUnitIndex < 0 || lengthUnitIndex >= LADB_LENGTH_UNIT_INFOS.length) {
            return null;
        }
        return LADB_LENGTH_UNIT_INFOS[lengthUnitIndex];
    };

    LadbTabCutlist.prototype.onCutlistGenerated = function (jsonData) {
        var that = this;

        var data = JSON.parse(jsonData);

        var status = data.status;
        var errors = data.errors;
        var warnings = data.warnings;
        var filepath = data.filepath;
        var lengthUnit = data.length_unit;
        var groups = data.groups;

        // Update filename
        this.$filename.empty();
        this.$filename.append(filepath.split('\\').pop().split('/').pop());

        // Update unit and length options
        this.lengthUnitInfos = this.getLengthUnitInfos(lengthUnit);
        this.$unit.empty();
        this.$unit.append(' en ' + this.lengthUnitInfos.name);

        // Errors
        this.$alertErrors.empty();
        if (errors.length > 0) {
            that.$alertErrors.show();
            errors.forEach(function (error) {
                that.$alertErrors.append(error);
            });
        } else {
            that.$alertErrors.hide();
        }

        // Warnings
        this.$alertWarnings.empty();
        if (warnings.length > 0) {
            that.$alertWarnings.show();
            warnings.forEach(function (warning) {
                that.$alertWarnings.append(warning);
            });
        } else {
            that.$alertWarnings.hide();
        }

        // Hide help panel
        if (groups.length > 0) {
            this.$panelHelp.hide();
        }

        // Update print button state
        this.$btnPrint.prop('disabled', groups.length == 0);

        // Update list
        this.$list.empty();
        this.$list.append(Twig.twig({ ref: "tabs/cutlist/_list.twig" }).render({
            groups: groups
        }));

        // Bind buttons
        $('.ladb-btn-toggle-no-print', this.$list).on('click', function() {
            var $i = $('i', $(this));
            var groupId = $(this).data('group-id');
            var $group = $('#' + groupId);
            $group.toggleClass('no-print');
            if ($group.hasClass('no-print')) {
                $('tbody', $group).hide();
                $i.removeClass('glyphicon-eye-close');
                $i.addClass('glyphicon-eye-open');
            } else {
                $('tbody', $group).show();
                $i.addClass('glyphicon-eye-close');
                $i.removeClass('glyphicon-eye-open');
            }
            $(this).blur();
        });

    };

    LadbTabCutlist.prototype.bind = function () {
        var that = this;

        // Bind buttons
        this.$btnRefresh.on('click', function () {
            that.toolbox.rubyCall('ladb_cutlist_generate', {
                length_increase: that.lengthIncrease + 'mm',
                width_increase: that.widthIncrease + 'mm',
                thickness_increase: that.thicknessIncrease + 'mm',
                std_thicknesses: that.stdThicknesses,
                piece_number_letter: that.pieceNumberLetter,
                piece_number_sequence_by_group: that.pieceNumberSequenceByGroup
            });
            this.blur();
        });
        this.$btnPrint.on('click', function () {
            window.print();
            this.blur();
        });

        // Bind inputs
        this.$inputLengthIncrease.on('change', function () {
            var lengthIncrease = parseFloat(that.$inputLengthIncrease.val());
            if (!isNaN(lengthIncrease)) {
                that.lengthIncrease = lengthIncrease;
                that.toolbox.setSettingsValue("lengthIncrease", that.lengthIncrease);
            }
        });
        this.$inputWidthIncrease.on('change', function () {
            var widthIncrease = parseFloat(that.$inputWidthIncrease.val());
            if (!isNaN(widthIncrease)) {
                that.widthIncrease = widthIncrease;
                that.toolbox.setSettingsValue('widthIncrease', that.widthIncrease);
            }
        });
        this.$inputThicknessIncrease.on('change', function () {
            var thicknessIncrease = parseFloat(that.$inputThicknessIncrease.val());
            if (!isNaN(thicknessIncrease)) {
                that.thicknessIncrease = thicknessIncrease;
                that.toolbox.setSettingsValue('thicknessIncrease', that.thicknessIncrease);
            }
        });
        this.$inputStdThicknesses.on('change', function () {
            var stdThicknesses = that.$inputStdThicknesses.val();
            if (true) {
                that.stdThicknesses = stdThicknesses;
                that.toolbox.setSettingsValue('stdThicknesses', that.stdThicknesses);
            }
        });
        this.$inputPieceNumberLetter.on('change', function () {
            that.pieceNumberLetter = that.$inputPieceNumberLetter.is(':checked');
            that.toolbox.setSettingsValue('pieceNumberLetter', that.pieceNumberLetter);
        });
        this.$inputPieceNumberSequenceByGroup.on('change', function () {
            that.pieceNumberSequenceByGroup = that.$inputPieceNumberSequenceByGroup.is(':checked');
            that.toolbox.setSettingsValue('pieceNumberSequenceByGroup', that.pieceNumberSequenceByGroup);
        });

    };

    LadbTabCutlist.prototype.init = function () {
        this.bind();

        // Init inputs values
        this.$inputLengthIncrease.val(this.lengthIncrease);
        this.$inputWidthIncrease.val(this.widthIncrease);
        this.$inputThicknessIncrease.val(this.thicknessIncrease);
        this.$inputStdThicknesses.val(this.stdThicknesses);
        this.$inputPieceNumberLetter.prop('checked', this.pieceNumberLetter);
        this.$inputPieceNumberSequenceByGroup.prop('checked', this.pieceNumberSequenceByGroup);
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
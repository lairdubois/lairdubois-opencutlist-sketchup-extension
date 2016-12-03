+function ($) {
    'use strict';

    var LADB_LENGTH_UNIT_INFOS = {
        0: {name: 'pouce', unit: 'in'},
        1: {name: 'pied', unit: 'ft'},
        2: {name: 'millimètre', unit: 'mm'},
        3: {name: 'centimètre', unit: 'cm'},
        4: {name: 'mètre', unit: 'm'}
    };

    var configurableRoundingFormatter = function (maxDecimals) {
        return function (scalar, units) {
            return scalar.toFixed(maxDecimals) + ' ' + units;
        };
    };

    // CLASS DEFINITION
    // ======================

    var LadbTabCutlist = function (element, options) {
        this.options = options;
        this.$element = $(element);

        this.lengthUnitInfos = LADB_LENGTH_UNIT_INFOS[2];

        this.lengthIncrease = 50;
        this.widthIncrease = 5;
        this.thicknessIncrease = 5;

        this.$filename = $('#ladb_filename', this.$element);
        this.$unit = $('#ladb_unit', this.$element);
        this.$btnRefresh = $('#ladb_btn_refresh', this.$element);
        this.$btnPrint = $('#ladb_btn_print', this.$element);
        this.$inputLengthIncrease = $('#ladb_input_length_increase', this.$element);
        this.$inputWidthIncrease = $('#ladb_input_width_increase', this.$element);
        this.$inputThicknessIncrease = $('#ladb_input_thickness_increase', this.$element);
        this.$list = $('#list', this.$element);
    };

    LadbTabCutlist.DEFAULTS = {};

    LadbTabCutlist.prototype.rubyCall = function (fn, callback, param) {
        window.location.href = "skp:" + fn + "@" + JSON.stringify({callback: callback, param: param});
    };

    LadbTabCutlist.prototype.getCodeFromIndex = function (index) {
        return String.fromCharCode(65 + (index % 26));
    };

    LadbTabCutlist.prototype.getLengthUnitInfos = function (lengthUnitIndex) {
        if (lengthUnitIndex < 0 || lengthUnitIndex >= LADB_LENGTH_UNIT_INFOS.length) {
            return null;
        }
        return LADB_LENGTH_UNIT_INFOS[lengthUnitIndex];
    };

    LadbTabCutlist.prototype.onCutlistGenerated = function (jsonData) {

        var data = JSON.parse(jsonData);

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

        // Update list
        this.$list.empty();

        var that = this;
        Twig.twig({
            href: "../twig/tabs/cutlist/_group-list.twig",
            load: function (template) {
                that.$list.append(template.render({
                    groups: groups
                }));
            }
        });

        // for (var i = 0; i < groups.length; i++) {
        //
        //     var group = groups[i];
        //     var pieces = group.pieces;
        //
        //     var $table = $('<table>', {
        //         class: 'table table-bordered ladb-cutlist'
        //     });
        //     var $tbody = $('<tbody>');
        //
        //     var lastThickness = 0;
        //     for (var j = 0; j < pieces.length; j++) {
        //
        //         var piece = pieces[j];
        //
        //         if (piece.thickness != lastThickness) {
        //             $tbody.append(
        //                 '<tr style="background-color: #fcfcfc;">' +
        //                     '<td colspan="8" style="padding: 5px 10px 5px 10px; font-size: 80%;">Epaisseur ' + piece.thickness + 'mm</strong></td>' +
        //                 '</tr>'
        //             );
        //         }
        //
        //         $tbody.append(
        //             '<tr style="font-size: 120%;">' +
        //                 '<td>' + piece.name + '</td>' +
        //                 '<td class="text-right">' + piece.length + '</td>' +
        //                 '<td class="text-right">' + piece.width + '</td>' +
        //                 '<td class="text-right">' + piece.thickness + '</td>' +
        //                 '<td class="text-center">x ' + piece.count + '</td>' +
        //                 '<td class="text-right" style="color: red;">' + piece.raw_length + '</td>' +
        //                 '<td class="text-right" style="color: red;">' + piece.raw_width + '</td>' +
        //                 '<td class="text-center" style="color: red;">' + this.getCodeFromIndex(j) + '</td>' +
        //             '</tr>'
        //         );
        //
        //         lastThickness = piece.thickness;
        //     }
        //
        //     $table.append(
        //         '<tbody style="background-color: #f9f9f9;">' +
        //             '<tr style="background-color: #eee;">' +
        //                 '<td colspan="8"><span style="font-size: 18px;">' + group.name + ' / <strong>' + group.raw_thickness + 'mm</strong></span><span class="pull-right" style="white-space: nowrap;">Surface brute : <strong>' + Qty(group.raw_area, 'in^2').format('m^2', configurableRoundingFormatter(3)) + '</strong>, Volume brut : <strong>' + Qty(group.raw_volume, 'in^3').format('m^3', configurableRoundingFormatter(3)) + '</strong></span></td>' +
        //             '</tr>' +
        //             '<tr>' +
        //                 '<td class="text-center" rowspan="2" style="vertical-align: middle !important;">Nom</td>' +
        //                 '<td class="text-center" colspan="3">Finie</td>' +
        //                 '<td class="text-center" rowspan="2" style="vertical-align: middle !important;">Nbr.</td>' +
        //                 '<td class="text-center" colspan="2">Brute</td>' +
        //                 '<td class="text-center" rowspan="2" style="vertical-align: middle !important;">Id</td>' +
        //             '</tr>' +
        //             '<tr>' +
        //                 '<td class="text-center" width="10%">Long.</td>' +
        //                 '<td class="text-center" width="10%">Larg.</td>' +
        //                 '<td class="text-center" width="10%">Ep.</td>' +
        //                 '<td class="text-center" width="10%">Long.</td>' +
        //                 '<td class="text-center" width="10%">Larg.</td>' +
        //             '</tr>' +
        //         '</tbody>'
        //     );
        //     $table.append($tbody);
        //     this.$list.append($table);
        // }

    };

    LadbTabCutlist.prototype.bind = function () {
        var that = this;

        // Bind buttons
        this.$btnRefresh.on('click', function () {
            that.rubyCall('ladb_generate_cutlist', '$(\'#' + that.$element.attr('id') + '\').ladbTabCutlist(\'onCutlistGenerated\', \'%PARAM%\')', {
                length_increase: that.lengthIncrease + 'mm',
                width_increase: that.widthIncrease + 'mm',
                thickness_increase: that.thicknessIncrease + 'mm'
            });
        });
        this.$btnPrint.on('click', function () {
            window.print();
        });

        // Bind inputs
        this.$inputLengthIncrease.on('change', function () {
            that.lengthIncrease = parseFloat(that.$inputLengthIncrease.val());
        });
        this.$inputWidthIncrease.on('change', function () {
            that.widthIncrease = parseFloat(that.$inputWidthIncrease.val());
        });
        this.$inputThicknessIncrease.on('change', function () {
            that.thicknessIncrease = parseFloat(that.$inputThicknessIncrease.val());
        });

    };

    LadbTabCutlist.prototype.init = function () {
        this.bind();

        // Init inputs values
        this.$inputLengthIncrease.val(this.lengthIncrease);
        this.$inputWidthIncrease.val(this.widthIncrease);
        this.$inputThicknessIncrease.val(this.thicknessIncrease);
    };


    // PLUGIN DEFINITION
    // =======================

    function Plugin(option, params) {
        return this.each(function () {
            var $this = $(this);
            var data = $this.data('ladb.tabCutlist');
            var options = $.extend({}, LadbTabCutlist.DEFAULTS, $this.data(), typeof option == 'object' && option);

            if (!data) {
                $this.data('ladb.tabCutlist', (data = new LadbTabCutlist(this, options)));
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
+function ($) {
    'use strict';

    var LADB_LENGTH_UNIT_INFOS = {
        0: {name: 'pouce', unit: 'in'},
        1: {name: 'pied', unit: 'ft'},
        2: {name: 'millimètre', unit: 'mm'},
        3: {name: 'centimètre', unit: 'cm'},
        4: {name: 'mètre', unit: 'm'}
    };

    function setSettingsValue(key, value) {
        if (typeof(Storage) !== "undefined") {
            localStorage.setItem(key, value);
        }
    }

    function getSettingsValue(key, defaultValue) {
        if (typeof(Storage) !== "undefined") {
            var value = localStorage.getItem(key);
            if (value) {
                return value;
            }
        }
        return defaultValue;
    }

    // CLASS DEFINITION
    // ======================

    var LadbTabCutlist = function (element, options) {
        this.options = options;
        this.$element = $(element);

        this.lengthUnitInfos = LADB_LENGTH_UNIT_INFOS[2];

        this.lengthIncrease = getSettingsValue('lengthIncrease', 50);
        this.widthIncrease = getSettingsValue('widthIncrease', 5);
        this.thicknessIncrease = getSettingsValue('thicknessIncrease', 5);

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

    LadbTabCutlist.prototype.rubyCall = function (fn, params) {
        window.location.href = "skp:" + fn + "@" + JSON.stringify(params);
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
            that.rubyCall('ladb_generate_cutlist', {
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
            setSettingsValue("lengthIncrease", that.lengthIncrease);
        });
        this.$inputWidthIncrease.on('change', function () {
            that.widthIncrease = parseFloat(that.$inputWidthIncrease.val());
            setSettingsValue("widthIncrease", that.widthIncrease);
        });
        this.$inputThicknessIncrease.on('change', function () {
            that.thicknessIncrease = parseFloat(that.$inputThicknessIncrease.val());
            setSettingsValue("thicknessIncrease", that.thicknessIncrease);
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
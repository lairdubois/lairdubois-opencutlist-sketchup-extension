+function ($) {
    'use strict';

    // CLASS DEFINITION
    // ======================

    var LadbPresetWidget = function (element, options) {
        this.options = options;
        this.$element = $(element);

        this.$groupSave = $('.ladb-widget-preset-group-save', this.$element);
        this.$ulSave = $('ul', this.$groupSave);
        this.$btnUserDefaultSave = $('.ladb-widget-preset-btn-user-default', this.$ulSave);
        this.$btnAdd = $('.ladb-widget-preset-btn-add', this.$ulSave);

        this.$groupRestore = $('.ladb-widget-preset-group-restore', this.$element);
        this.$ulRestore = $('ul', this.$groupRestore);
        this.$btnUserDefaultRestore = $('.ladb-widget-preset-btn-user-default', this.$ulRestore);
        this.$btnAppDefaultRestore = $('.ladb-widget-preset-btn-app-default', this.$ulRestore);

    };

    LadbPresetWidget.DEFAULTS = {
        dictionary: null,
        section: null,
        fnPopulateValues: null,
        fnPopulateInputs: null,
        fnOnSaved: null
    };

    LadbPresetWidget.prototype.saveTo = function (name, isNew) {
        var that = this;
        if (isNew || confirm('Confirm ?')) {
            rubyCallCommand('core_set_global_preset', {
                dictionary: that.options.dictionary,
                values: that.options.fnPopulateValues(),
                name: name
            }, function () {
                that.options.fnOnSaved(name);
                if (isNew) {
                    that.refresh();
                }
            });
        }
    };

    LadbPresetWidget.prototype.restoreFrom = function (name) {
        var that = this;
        rubyCallCommand('core_get_global_preset', {
            dictionary: that.options.dictionary,
            name: name
        }, function (response) {
            that.options.fnPopulateInputs(response.preset);
        });
    };

    LadbPresetWidget.prototype.refresh = function () {
        var that = this;

        rubyCallCommand('core_list_global_preset_names', { dictionary: this.options.dictionary }, function (response) {

            $('.removable', that.$ulSave).remove();
            $('.removable', that.$ulRestore).remove();

            $.each(response.names, function (index) {

                var name = this;

                var $itemSave = $('<li class="removable" />');
                var $btnSave = $('<a href="#">' + name + '</a>');
                $btnSave.on('click', function () {
                    that.saveTo(name, false);
                });
                $itemSave.append($btnSave);
                that.$ulSave.append($itemSave);

                var $itemRestore = $('<li class="removable" />');
                var $btnRestore = $('<a href="#">' + name + '</a>');
                $btnRestore.on('click', function () {
                    that.restoreFrom(name);
                });
                $itemRestore.append($btnRestore);
                that.$ulRestore.append($itemRestore);

            });

        });

    };

    LadbPresetWidget.prototype.bind = function () {
        var that = this;

        this.$btnUserDefaultSave.on('click', function () {
            that.saveTo(null);
        });
        this.$btnAdd.on('click', function () {
            var name = prompt('Nom de la configuration', '');
            if (name) {
                that.saveTo(name, true);
            }
        });
        this.$btnUserDefaultRestore.on('click', function () {
            that.restoreFrom(null);
        });
        this.$btnAppDefaultRestore.on('click', function () {
            rubyCallCommand('core_get_app_defaults', {
                dictionary: that.options.dictionary,
            }, function (response) {
                that.options.fnPopulateInputs(response.defaults);
            });
        });

    };

    LadbPresetWidget.prototype.init = function () {
        this.refresh();
        this.bind();
    };

    // PLUGIN DEFINITION
    // =======================

    function Plugin(option, params) {
        var value;
        var elements = this.each(function () {
            var $this = $(this);
            var data = $this.data('ladb.presetWidget');
            var options = $.extend({}, LadbPresetWidget.DEFAULTS, $this.data(), typeof option == 'object' && option);

            if (!data) {
                $this.data('ladb.presetWidget', (data = new LadbPresetWidget(this, options)));
            }
            if (typeof option == 'string') {
                value = data[option].apply(data, Array.isArray(params) ? params : [ params ])
            } else {
                data.init();
            }
        });
        return typeof value !== 'undefined' ? value : elements;
    }

    var old = $.fn.ladbPresetWidget;

    $.fn.ladbPresetWidget = Plugin;
    $.fn.ladbPresetWidget.Constructor = LadbPresetWidget;


    // NO CONFLICT
    // =================

    $.fn.ladbPresetWidget.noConflict = function () {
        $.fn.ladbPresetWidget = old;
        return this;
    }

}(jQuery);
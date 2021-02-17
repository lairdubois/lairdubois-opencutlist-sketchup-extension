+function ($) {
    'use strict';

    // CLASS DEFINITION
    // ======================

    var LadbWidgetPreset = function (element, options, dialog) {
        this.options = options;
        this.$element = $(element);
        this.dialog = dialog;

        this.$groupSave = $('.ladb-widget-preset-group-save', this.$element);
        this.$ulSave = $('ul', this.$groupSave);
        this.$btnUserDefaultSave = $('.ladb-widget-preset-btn-user-default', this.$ulSave);
        this.$btnAdd = $('.ladb-widget-preset-btn-add', this.$ulSave);

        this.$groupRestore = $('.ladb-widget-preset-group-restore', this.$element);
        this.$ulRestore = $('ul', this.$groupRestore);
        this.$btnUserDefaultRestore = $('.ladb-widget-preset-btn-user-default', this.$ulRestore);
        this.$btnAppDefaultRestore = $('.ladb-widget-preset-btn-app-default', this.$ulRestore);

    };

    LadbWidgetPreset.DEFAULTS = {
        dictionary: null,
        section: null,
        fnFetchOptions: null,
        fnFillInputs: null
    };

    LadbWidgetPreset.prototype.deletePreset = function (name) {
        var that = this;
        if (confirm(i18next.t('core.preset.delete_confirm', { name: name }))) {
            rubyCallCommand('core_set_global_preset', {
                dictionary: that.options.dictionary,
                section: that.options.section,
                values: null,
                name: name
            }, function () {
                that.dialog.notify(i18next.t('core.preset.delete_success', { name: name }), 'success');
                that.refresh();
            });
        }
    };

    LadbWidgetPreset.prototype.saveToPreset = function (name, isNew) {
        var that = this;
        if (isNew || confirm(i18next.t('core.preset.override_confirm', { name: name ? name : i18next.t('core.preset.user_default') }))) {
            var values = {};
            that.options.fnFetchOptions(values);
            rubyCallCommand('core_set_global_preset', {
                dictionary: that.options.dictionary,
                section: that.options.section,
                values: values,
                name: name
            }, function () {
                that.dialog.notify(i18next.t('core.preset.save_success', { name: name ? name : i18next.t('core.preset.user_default') }), 'success');
                if (isNew) {
                    that.refresh();
                }
            });
        }
    };

    LadbWidgetPreset.prototype.restoreFromPreset = function (name) {
        var that = this;
        rubyCallCommand('core_get_global_preset', {
            dictionary: that.options.dictionary,
            section: that.options.section,
            name: name
        }, function (response) {
            that.options.fnFillInputs(response.preset);
        });
    };

    LadbWidgetPreset.prototype.refresh = function () {
        var that = this;

        rubyCallCommand('core_list_global_preset_names', { dictionary: this.options.dictionary }, function (response) {

            $('.removable', that.$ulSave).remove();
            $('.removable', that.$ulRestore).remove();

            var fnCreateMinitools = function (name) {
                return $('<div class="ladb-minitools" />')
                    .append(
                        $('<a href="#" class="ladb-tool-dark" data-toggle="tooltip" title="DELETE"><i class="ladb-opencutlist-icon-trash"></a>')
                            .on('click', function () {
                                that.deletePreset(name);
                            })
                    );
            }

            $.each(response.names, function (index) {

                var name = this;

                that.$ulSave.append(
                    $('<li class="removable with-minitools" />')
                        .append(
                            $('<a href="#">' + name + '</a>')
                                .on('click', function () {
                                    that.saveToPreset(name, false);
                                })
                        )
                        .append(fnCreateMinitools(name))
                );

                that.$ulRestore.append(
                    $('<li class="removable with-minitools" />')
                        .append(
                            $('<a href="#">' + name + '</a>')
                                .on('click', function () {
                                    that.restoreFromPreset(name);
                                })
                        )
                        .append(fnCreateMinitools(name))
                );

            });

        });

    };

    LadbWidgetPreset.prototype.bind = function () {
        var that = this;

        // Bind buttons
        this.$btnUserDefaultSave.on('click', function () {
            that.saveToPreset(null);
        });
        this.$btnAdd.on('click', function () {
            var name = prompt(i18next.t('core.preset.add_prompt'), '');
            if (name) {
                that.saveToPreset(name, true);
            }
        });
        this.$btnUserDefaultRestore.on('click', function () {
            that.restoreFromPreset(null);
        });
        this.$btnAppDefaultRestore.on('click', function () {
            rubyCallCommand('core_get_app_defaults', {
                dictionary: that.options.dictionary,
            }, function (response) {
                that.options.fnFillInputs(response.defaults);
            });
        });

    };

    LadbWidgetPreset.prototype.init = function () {
        this.refresh();
        this.bind();
    };

    // PLUGIN DEFINITION
    // =======================

    function Plugin(option, params) {
        var value;
        var elements = this.each(function () {
            var $this = $(this);
            var data = $this.data('ladb.widgetPreset');
            var options = $.extend({}, LadbWidgetPreset.DEFAULTS, $this.data(), typeof option == 'object' && option);

            if (!data) {
                if (undefined === options.dialog) {
                    throw 'dialog option is mandatory.';
                }
                $this.data('ladb.widgetPreset', (data = new LadbWidgetPreset(this, options, options.dialog)));
            }
            if (typeof option == 'string') {
                value = data[option].apply(data, Array.isArray(params) ? params : [ params ])
            } else {
                data.init();
            }
        });
        return typeof value !== 'undefined' ? value : elements;
    }

    var old = $.fn.ladbWidgetPreset;

    $.fn.ladbWidgetPreset = Plugin;
    $.fn.ladbWidgetPreset.Constructor = LadbWidgetPreset;


    // NO CONFLICT
    // =================

    $.fn.ladbWidgetPreset.noConflict = function () {
        $.fn.ladbWidgetPreset = old;
        return this;
    }

}(jQuery);
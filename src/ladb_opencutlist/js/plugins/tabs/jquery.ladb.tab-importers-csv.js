+function ($) {
    'use strict';

    // CLASS DEFINITION
    // ======================

    const LadbTabImportersCsv = function (element, options, dialog) {
        LadbAbstractTab.call(this, element, options, dialog);

        this.loadOptions = null;
        this.importablePartCount = 0;
        this.model_is_empty = false;

        this.$header = $('.ladb-header', this.$element);
        this.$btnOpen = $('#ladb_btn_open', this.$header);

    };
    LadbTabImportersCsv.prototype = Object.create(LadbAbstractTab.prototype);

    LadbTabImportersCsv.DEFAULTS = {};

    LadbTabImportersCsv.prototype.openCsv = function (path = null) {
        const that = this;

        rubyCallCommand('importers_csv_open', { path: path }, function (response) {

            if (response.path) {

                const path = response.path;
                const filename = response.filename;
                const lengthUnit = response.length_unit;

                // Retrieve load options
                rubyCallCommand('core_get_model_preset', { dictionary: 'importers_csv_load_options' }, function (response) {

                    const loadOptions = response.preset;
                    loadOptions.path = path;
                    loadOptions.filename = filename;

                    const $modal = that.appendModalInside('ladb_importer_modal_load', 'tabs/importers/csv/_modal-load.twig', $.extend({ lengthUnit: lengthUnit }, loadOptions));

                    // Fetch UI elements
                    const $widgetPreset = $('.ladb-widget-preset', $modal);
                    const $selectColSep = $('#ladb_importer_load_select_col_sep', $modal);
                    const $selectFirstLineHeaders = $('#ladb_importer_load_select_first_line_headers', $modal);
                    const $btnLoad = $('#ladb_importer_load', $modal);

                    // Define useful functions
                    const fnFetchOptions = function (options) {
                        options.col_sep = $selectColSep.val();
                        options.first_line_headers = $selectFirstLineHeaders.val() === '1';
                    };
                    const fnFillInputs = function (options) {
                        $selectColSep.selectpicker('val', options.col_sep);
                        $selectFirstLineHeaders.selectpicker('val', options.first_line_headers ? '1' : '0');
                        loadOptions.column_mapping = options.column_mapping;
                    };

                    $widgetPreset.ladbWidgetPreset({
                        dialog: that.dialog,
                        dictionary: 'importers_csv_load_options',
                        fnFetchOptions: fnFetchOptions,
                        fnFillInputs: fnFillInputs
                    });

                    // Bind select
                    $selectColSep.selectpicker(SELECT_PICKER_OPTIONS);
                    $selectFirstLineHeaders.selectpicker(SELECT_PICKER_OPTIONS);

                    fnFillInputs(loadOptions);

                    // Bind buttons
                    $btnLoad.on('click', function () {

                        // Fetch options
                        fnFetchOptions(loadOptions);

                        that.loadCsv(loadOptions);

                        // Hide modal
                        $modal.modal('hide');

                    });

                    // Show modal
                    $modal.modal('show');

                });

            } else if (response.errors.length > 0) {
                that.dialog.notifyErrors(response.errors);
            }

        });
    };

    LadbTabImportersCsv.prototype.loadCsv = function (loadOptions, out = true) {
        const that = this;

        // Store options
        rubyCallCommand('core_set_model_preset', { dictionary: 'importers_csv_load_options', values: loadOptions });

        rubyCallCommand('importers_csv_load', loadOptions, function (response) {

            that.setObsolete(false);

            let i;

            if (response.path) {

                const errors = response.errors;
                const warnings = response.warnings;
                const filename = response.filename;
                const columns = response.columns;
                const parts = response.parts;
                const importablePartCount = response.importable_part_count;
                const modelIsEmpty = response.model_is_empty;
                const lengthUnit = response.length_unit;

                // Keep useful data
                that.loadOptions = loadOptions;
                that.importablePartCount = importablePartCount;
                that.model_is_empty = modelIsEmpty;

                const $slide = that.pushNewSlide('ladb_importers_csv_slide_load', 'tabs/importers/csv/_slide-load.twig', $.extend({
                    out: out,
                    filename: filename,
                    lengthUnit: lengthUnit,
                    errors: errors,
                    warnings: warnings,
                    columns: columns,
                    parts: parts,
                    importablePartCount: importablePartCount
                }));

                // Fetch UI elements
                const $btnImport = $('#ladb_btn_import', $slide);
                const $btnClose = $('#ladb_btn_close', $slide);
                const $header = $('.ladb-header', $slide);
                const $page = $('.ladb-page', $slide);

                // Setup tooltips
                that.dialog.setupTooltips($slide);

                // Apply column mapping
                for (i = 0; i < columns.length; i++) {
                    const $select = $('#ladb_select_column_' + i, $page);
                    $select
                        .val(columns[i].mapping)
                        .on('changed.bs.select', function(e, clickedIndex, isSelected, previousValue) {
                            const column = $(e.currentTarget).data('column');
                            const mapping = $(e.currentTarget).selectpicker('val');
                            for (const k in loadOptions.column_mapping) {
                                if (loadOptions.column_mapping[k] === column) {
                                    delete loadOptions.column_mapping[k];
                                }
                            }
                            if (mapping) {
                                loadOptions.column_mapping[mapping] = column;
                            }
                            that.loadCsv(loadOptions, false)
                        })
                        .selectpicker($.extend(SELECT_PICKER_OPTIONS, {
                            noneSelectedText: i18next.t('tab.import.column.unused')
                        }));
                }

                // Bind buttons
                $btnImport.on('click', function () {
                    that.importParts();
                    this.blur();
                });
                $btnClose.on('click', function () {
                    that.close();
                });
                $('.ladb-btn-setup-model-units', $header).on('click', function() {
                    $(this).blur();
                    that.dialog.executeCommandOnTab('settings', 'highlight_panel', { panel:'model' });
                });

                // Manage buttons
                $btnImport.prop( "disabled", importablePartCount === 0);

            } else if (response.errors && response.errors.length > 0) {
                that.dialog.notifyErrors(response.errors);
            }

        });

    };

    LadbTabImportersCsv.prototype.importParts = function () {
        const that = this;

        // Retrieve load option options
        rubyCallCommand('core_get_model_preset', { dictionary: 'importers_csv_import_options' }, function (response) {

            const importOptions = response.preset;

            importOptions.remove_all = false;      // This option is not stored to force user to know the option status

            const $modal = that.appendModalInside('ladb_importer_modal_import', 'tabs/importers/csv/_modal-import.twig', $.extend({
                importablePartCount: that.importablePartCount,
                model_is_empty: that.model_is_empty
            }, importOptions));

            // Fetch UI elements
            const $widgetPreset = $('.ladb-widget-preset', $modal);
            const $selectRemoveAll = $('#ladb_importer_import_select_remove_all', $modal);
            const $inputKeepDefinitionsSettings = $('#ladb_importer_import_input_keep_definitions_settings', $modal);
            const $inputKeepMaterialsSettings = $('#ladb_importer_import_input_keep_materials_settings', $modal);
            const $btnImport = $('#ladb_importer_import', $modal);

            // Define useful functions
            const fnFetchOptions = function (options) {
                options.remove_all = $selectRemoveAll.selectpicker('val') === '1';
                options.keep_definitions_settings = $inputKeepDefinitionsSettings.prop('checked');
                options.keep_materials_settings = $inputKeepMaterialsSettings.prop('checked');
            };
            const fnFillInputs = function (options) {
                $selectRemoveAll.prop('val', options.remove_all ? '1' : '0');
                $inputKeepDefinitionsSettings.prop('checked', options.keep_definitions_settings);
                $inputKeepMaterialsSettings.prop('checked', options.keep_materials_settings);
            };

            $widgetPreset.ladbWidgetPreset({
                dialog: that.dialog,
                dictionary: 'importers_csv_import_options',
                fnFetchOptions: fnFetchOptions,
                fnFillInputs: fnFillInputs
            });

            // Bind select
            $selectRemoveAll
                .on('changed.bs.select', function (e, clickedIndex, isSelected, previousValue) {
                    const removeAll = $(e.currentTarget).selectpicker('val');
                    if (removeAll === '1') {
                        $inputKeepDefinitionsSettings.closest('.form-group').show();
                    } else {
                        $inputKeepDefinitionsSettings.closest('.form-group').hide();
                    }
                })
                .selectpicker(SELECT_PICKER_OPTIONS);

            fnFillInputs(importOptions);

            // Bind buttons
            $btnImport.on('click', function () {

                // Fetch options
                fnFetchOptions(importOptions);

                // Store options
                rubyCallCommand('core_set_model_preset', { dictionary: 'importers_csv_import_options', values: importOptions });

                rubyCallCommand('importers_csv_import', importOptions, function (response) {

                    if (response.errors.length > 0) {
                        that.dialog.notifyErrors(response.errors);
                    }
                    if (response.imported_part_count) {

                        that.dialog.notifySuccess(i18next.t('tab.importers.default.success.imported_title'), [
                            Noty.button(i18next.t('default.see'), 'btn btn-default', function () {
                                that.dialog.minimize();
                                rubyCallCommand('core_zoom_extents')
                            }),
                            Noty.button(i18next.t('tab.cutlist.title'), 'btn btn-default', function () {
                                that.dialog.executeCommandOnTab('cutlist', 'generate_cutlist');
                            }),
                        ]);

                        // Close
                        that.close();
                    }

                });

                // Hide modal
                $modal.modal('hide');

            });

            // Show modal
            $modal.modal('show');

        });

    };

    LadbTabImportersCsv.prototype.close = function () {
        if (this.loadOptions) {

            // Close slide
            this.popSlide();

            // Cleanup keeped data
            this.loadOptions = null;
            this.importablePartCount = 0;
            this.model_is_empty = false;

        }
    }

    // Internals /////

    LadbTabImportersCsv.prototype.showObsolete = function (messageI18nKey, forced) {
        if (!this.isObsolete() || forced) {

            const that = this;

            // Set tab as obsolete
            this.setObsolete(true);

            const $modal = this.appendModalInside('ladb_importer_modal_obsolete', 'tabs/importers/csv/_modal-obsolete.twig', {
                messageI18nKey: messageI18nKey
            });

            // Fetch UI elements
            const $btnLoad = $('#ladb_importer_obsolete_load', $modal);

            // Bind buttons
            $btnLoad.on('click', function () {
                $modal.modal('hide');
                that.loadCsv(that.loadOptions);
            });

            // Show modal
            $modal.modal('show');

        }
    };

    // Init /////

    LadbTabImportersCsv.prototype.registerCommands = function () {
        LadbAbstractTab.prototype.registerCommands.call(this);

        const that = this;

        this.registerCommand('load', function (parameters) {
            that.openCsv(parameters.path);
        });

    };

    LadbTabImportersCsv.prototype.bind = function () {
        LadbAbstractTab.prototype.bind.call(this);

        const that = this;

        // Bind buttons
        this.$btnOpen.on('click', function () {
            that.openCsv();
            this.blur();
        });

        // Events

        addEventCallback('on_options_provider_changed', function () {
            if (that.loadOptions) {
                that.showObsolete('core.event.options_change', true);
            }
        });

    };


    // PLUGIN DEFINITION
    // =======================

    function Plugin(option, params) {
        return this.each(function () {
            const $this = $(this);
            let data = $this.data('ladb.tab.plugin');
            if (!data) {
                const options = $.extend({}, LadbTabImportersCsv.DEFAULTS, $this.data(), typeof option === 'object' && option);
                if (undefined === options.dialog) {
                    throw 'dialog option is mandatory.';
                }
                $this.data('ladb.tab.plugin', (data = new LadbTabImportersCsv(this, options, options.dialog)));
            }
            if (typeof option === 'string') {
                data[option].apply(data, Array.isArray(params) ? params : [ params ])
            } else {
                data.init(option.initializedCallback);
            }
        })
    }

    const old = $.fn.ladbTabImportersCsv;

    $.fn.ladbTabImportersCsv = Plugin;
    $.fn.ladbTabImportersCsv.Constructor = LadbTabImportersCsv;


    // NO CONFLICT
    // =================

    $.fn.ladbTabImportersCsv.noConflict = function () {
        $.fn.ladbTabImportersCsv = old;
        return this;
    }

}(jQuery);

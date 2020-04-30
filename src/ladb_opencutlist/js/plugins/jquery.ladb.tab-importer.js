+function ($) {
    'use strict';

    var SETTING_KEY_LOAD_OPTION_COL_SEP = 'importer.load.option.col_sep';
    var SETTING_KEY_LOAD_OPTION_FIRST_LINE_HEADERS = 'importer.load.option.first_line_headers';
    var SETTING_KEY_LOAD_OPTION_COLUMN_MAPPGING = 'importer.load.option.column_mapping';

    var SETTING_KEY_IMPORT_OPTION_KEEP_DEFINITIONS_SETTINGS = 'importer.import.option.keep_definitions_settings';
    var SETTING_KEY_IMPORT_OPTION_KEEP_METARIALS_SETTINGS = 'importer.import.option.keep_materials_settings';

    // Options defaults

    var OPTION_DEFAULT_COL_SEP = 1;     // ,
    var OPTION_DEFAULT_FIRST_LINE_HEADERS = 1;  // headers
    var OPTION_DEFAULT_COLUMN_MAPPGING = {};

    var OPTION_DEFAULT_KEEP_DEFINITIONS_SETTINGS = true;
    var OPTION_DEFAULT_KEEP_MATERIALS_SETTINGS = true;

    // Select picker options

    var SELECT_PICKER_OPTIONS = {
        size: 10,
        iconBase: 'ladb-opencutlist-icon',
        tickIcon: 'ladb-opencutlist-icon-tick',
        showTick: true,
        noneSelectedText: 'Non utilisé'
    };

    // CLASS DEFINITION
    // ======================

    var LadbTabImporter = function (element, options, opencutlist) {
        LadbAbstractTab.call(this, element, options, opencutlist);

        this.loadOptions = null;
        this.importablePartCount = 0;
        this.model_is_empty = false;

        this.$header = $('.ladb-header', this.$element);
        this.$fileTabs = $('.ladb-file-tabs', this.$header);
        this.$btnOpen = $('#ladb_btn_open', this.$header);
        this.$btnImport = $('#ladb_btn_import', this.$header);

        this.$panelHelp = $('.ladb-panel-help', this.$element);
        this.$page = $('.ladb-page', this.$element);

    };
    LadbTabImporter.prototype = new LadbAbstractTab;

    LadbTabImporter.DEFAULTS = {};

    LadbTabImporter.prototype.openCSV = function () {
        var that = this;

        rubyCallCommand('importer_open', null, function (response) {

            var i;

            if (response.errors.length > 0) {

                // Update filename
                that.$fileTabs.empty();

                // Hide help panel
                that.$panelHelp.hide();

                // Update page
                that.$page.empty();
                that.$page.append(Twig.twig({ ref: "tabs/importer/_list.twig" }).render({
                    errors: response.errors
                }));

                // Manage buttons
                that.$btnOpen.removeClass('btn-default');
                that.$btnOpen.addClass('btn-primary');
                that.$btnImport.hide();

                // Stick header
                that.stickSlideHeader(that.$rootSlide);

            }
            if (response.path) {

                var lengthUnit = response.length_unit;

                // Retrieve load options
                that.opencutlist.pullSettings([

                        SETTING_KEY_LOAD_OPTION_COL_SEP,
                        SETTING_KEY_LOAD_OPTION_FIRST_LINE_HEADERS,
                        SETTING_KEY_LOAD_OPTION_COLUMN_MAPPGING

                    ],
                    0 /* SETTINGS_RW_STRATEGY_GLOBAL */,
                    function () {

                        var loadOptions = {
                            path: response.path,
                            filename: response.filename,
                            col_sep: that.opencutlist.getSetting(SETTING_KEY_LOAD_OPTION_COL_SEP, OPTION_DEFAULT_COL_SEP),
                            first_line_headers: that.opencutlist.getSetting(SETTING_KEY_LOAD_OPTION_FIRST_LINE_HEADERS, OPTION_DEFAULT_FIRST_LINE_HEADERS),
                            column_mapping: that.opencutlist.getSetting(SETTING_KEY_LOAD_OPTION_COLUMN_MAPPGING, OPTION_DEFAULT_COLUMN_MAPPGING)
                        };

                        var $modal = that.appendModalInside('ladb_importer_modal_load', 'tabs/importer/_modal-load.twig', $.extend(loadOptions, {
                            lengthUnit: lengthUnit
                        }));

                        // Fetch UI elements
                        var $selectColSep = $('#ladb_importer_load_select_col_sep', $modal);
                        var $selectFirstLineHeaders = $('#ladb_importer_load_select_first_line_headers', $modal);
                        var $btnSetupModelUnits = $('#ladb_setup_model_units', $modal);
                        var $btnLoad = $('#ladb_importer_load', $modal);

                        // Bind select
                        $selectColSep.val(loadOptions.col_sep);
                        $selectColSep.selectpicker(SELECT_PICKER_OPTIONS);
                        $selectFirstLineHeaders.val(loadOptions.first_line_headers ? '1' : '0');
                        $selectFirstLineHeaders.selectpicker(SELECT_PICKER_OPTIONS);

                        // Bind buttons
                        $btnLoad.on('click', function () {

                            // Fetch options

                            loadOptions.col_sep = $selectColSep.val();
                            loadOptions.first_line_headers = $selectFirstLineHeaders.val() === '1';

                            // Store options
                            that.opencutlist.setSettings([
                                { key:SETTING_KEY_LOAD_OPTION_COL_SEP, value:loadOptions.col_sep },
                                { key:SETTING_KEY_LOAD_OPTION_FIRST_LINE_HEADERS, value:loadOptions.first_line_headers }
                            ], 0 /* SETTINGS_RW_STRATEGY_GLOBAL */);

                            that.loadCSV(loadOptions);

                            // Hide modal
                            $modal.modal('hide');

                        });
                        $btnSetupModelUnits.on('click', function () {
                            $(this).blur();
                            rubyCallCommand('core_open_model_info_page', {
                                page: i18next.t('core.model_info_page.units')
                            });
                        });

                        // Show modal
                        $modal.modal('show');

                    });

            }

        });
    };

    LadbTabImporter.prototype.loadCSV = function (loadOptions) {
        var that = this;

        // Store options
        that.opencutlist.setSettings([
            { key:SETTING_KEY_LOAD_OPTION_COLUMN_MAPPGING, value:loadOptions.column_mapping }
        ], 0 /* SETTINGS_RW_STRATEGY_GLOBAL */);

        rubyCallCommand('importer_load', loadOptions, function (response) {

            that.setObsolete(false);

            var i;

            if (response.path) {

                var errors = response.errors;
                var warnings = response.warnings;
                var filename = response.filename;
                var columns = response.columns;
                var parts = response.parts;
                var importablePartCount = response.importable_part_count;
                var model_is_empty = response.model_is_empty;
                var lengthUnit = response.length_unit;

                // Keep usefull data
                that.loadOptions = loadOptions;
                that.importablePartCount = importablePartCount;
                that.model_is_empty = model_is_empty;

                // Update filename
                that.$fileTabs.empty();
                that.$fileTabs.append(Twig.twig({ ref: "tabs/importer/_file-tab.twig" }).render({
                    filename: filename,
                    importablePartCount: importablePartCount,
                    lengthUnit: lengthUnit
                }));

                // Hide help panel
                that.$panelHelp.hide();

                // Update page
                that.$page.empty();
                that.$page.append(Twig.twig({ ref: "tabs/importer/_list.twig" }).render({
                    errors: errors,
                    warnings: warnings,
                    columns: columns,
                    parts: parts,
                    importablePartCount: importablePartCount
                }));

                // Setup tooltips
                that.opencutlist.setupTooltips();

                // Apply column mapping
                for (i = 0; i < columns.length; i++) {
                    var $select = $('#ladb_select_column_' + i, that.$page);
                    $select
                        .val(columns[i].mapping)
                        .on('changed.bs.select', function(e, clickedIndex, isSelected, previousValue) {
                            var column = $(e.currentTarget).data('column');
                            var mapping = $(e.currentTarget).selectpicker('val');
                            for (var k in loadOptions.column_mapping) {
                                if (loadOptions.column_mapping[k] === column) {
                                    delete loadOptions.column_mapping[k];
                                }
                            }
                            if (mapping) {
                                loadOptions.column_mapping[mapping] = column;
                            }
                            that.loadCSV(loadOptions)
                        })
                        .selectpicker(SELECT_PICKER_OPTIONS);
                }

                // Bind buttons
                $('.ladb-btn-setup-model-units', that.$header).on('click', function() {
                    $(this).blur();
                    rubyCallCommand('core_open_model_info_page', {
                        page: i18next.t('core.model_info_page.units')
                    });
                });

                // Manage buttons
                that.$btnOpen.removeClass('btn-primary');
                that.$btnOpen.addClass('btn-default');
                that.$btnImport.show();
                that.$btnImport.prop( "disabled", importablePartCount === 0);

                // Stick header
                that.stickSlideHeader(that.$rootSlide);

            }

        });

    };

    LadbTabImporter.prototype.importParts = function () {
        var that = this;

        // Retrieve load option options
        that.opencutlist.pullSettings([

                SETTING_KEY_IMPORT_OPTION_KEEP_DEFINITIONS_SETTINGS,
                SETTING_KEY_IMPORT_OPTION_KEEP_METARIALS_SETTINGS

            ],
            3 /* SETTINGS_RW_STRATEGY_MODEL_GLOBAL */,
            function () {

                var importOptions = {
                    remove_all: false,      // This option is not stored to force user to know the option status
                    keep_definitions_settings: that.opencutlist.getSetting(SETTING_KEY_IMPORT_OPTION_KEEP_DEFINITIONS_SETTINGS, OPTION_DEFAULT_KEEP_DEFINITIONS_SETTINGS),
                    keep_materials_settings: that.opencutlist.getSetting(SETTING_KEY_IMPORT_OPTION_KEEP_METARIALS_SETTINGS, OPTION_DEFAULT_KEEP_MATERIALS_SETTINGS)
                };

                var $modal = that.appendModalInside('ladb_importer_modal_import', 'tabs/importer/_modal-import.twig', $.extend(importOptions, {
                    importablePartCount: that.importablePartCount,
                    model_is_empty: that.model_is_empty
                }));

                // Fetch UI elements
                var $SelectRemoveAll = $('#ladb_importer_import_select_remove_all', $modal);
                var $inputKeepDefinitionsSettings = $('#ladb_importer_import_input_keep_definitions_settings', $modal);
                var $inputKeepMaterialsSettings = $('#ladb_importer_import_input_keep_materials_settings', $modal);
                var $btnImport = $('#ladb_importer_import', $modal);

                $inputKeepDefinitionsSettings.prop('checked', importOptions.keep_definitions_settings);
                $inputKeepMaterialsSettings.prop('checked', importOptions.keep_materials_settings);

                // Bind select
                $SelectRemoveAll
                    .on('changed.bs.select', function (e, clickedIndex, isSelected, previousValue) {
                        var removeAll = $(e.currentTarget).selectpicker('val');
                        if (removeAll === '1') {
                            $inputKeepDefinitionsSettings.closest('.form-group').show();
                        } else {
                            $inputKeepDefinitionsSettings.closest('.form-group').hide();
                        }
                    })
                    .selectpicker(SELECT_PICKER_OPTIONS);

                // Bind buttons
                $btnImport.on('click', function () {

                    // Fetch options

                    importOptions.remove_all = $SelectRemoveAll.selectpicker('val') === '1';
                    importOptions.keep_definitions_settings = $inputKeepDefinitionsSettings.prop('checked');
                    importOptions.keep_materials_settings = $inputKeepMaterialsSettings.prop('checked');

                    // Store options
                    that.opencutlist.setSettings([
                        { key:SETTING_KEY_IMPORT_OPTION_KEEP_DEFINITIONS_SETTINGS, value:importOptions.keep_definitions_settings },
                        { key:SETTING_KEY_IMPORT_OPTION_KEEP_METARIALS_SETTINGS, value:importOptions.keep_materials_settings }
                    ], 3 /* SETTINGS_RW_STRATEGY_MODEL_GLOBAL */);

                    rubyCallCommand('importer_import', importOptions, function (response) {

                        var i;

                        if (response.errors.length > 0) {
                            that.opencutlist.notifyErrors(response.errors);
                        }
                        if (response.imported_part_count) {

                            // Update filename
                            that.$fileTabs.empty();

                            // Unstick header
                            that.unstickSlideHeader(that.$rootSlide);

                            // Update page
                            that.$page.empty();
                            that.$page.append(Twig.twig({ ref: "tabs/importer/_alert-success.twig" }).render({
                                importedPartCount: response.imported_part_count
                            }));

                            // Bind buttons
                            $('#ladb_importer_success_btn_see', that.$page).on('click', function() {
                                this.blur();
                                that.opencutlist.minimize();
                                rubyCallCommand('core_zoom_extents')
                            });
                            $('#ladb_importer_success_btn_cutlist', that.$page).on('click', function() {
                                this.blur();
                                that.opencutlist.executeCommandOnTab('cutlist', 'generate_cutlist');
                            });

                            // Manage buttons
                            that.$btnOpen.removeClass('btn-default');
                            that.$btnOpen.addClass('btn-primary');
                            that.$btnImport.hide();

                            // Cleanup keeped data
                            that.loadOptions = null;
                            that.importablePartCount = 0;
                            that.model_is_empty = false;

                        }

                    });

                    // Hide modal
                    $modal.modal('hide');

                });

                // Show modal
                $modal.modal('show');

            }

        );

    };

    // Internals /////

    LadbTabImporter.prototype.showObsolete = function (messageI18nKey, forced) {
        if (!this.isObsolete() || forced) {

            var that = this;

            // Set tab as obsolete
            this.setObsolete(true);

            var $modal = this.appendModalInside('ladb_importer_modal_obsolete', 'tabs/importer/_modal-obsolete.twig', {
                messageI18nKey: messageI18nKey
            });

            // Fetch UI elements
            var $btnLoad = $('#ladb_importer_obsolete_load', $modal);

            // Bind buttons
            $btnLoad.on('click', function () {
                $modal.modal('hide');
                that.loadCSV(that.loadOptions);
            });

            // Show modal
            $modal.modal('show');

        }
    };

    LadbTabImporter.prototype.bind = function () {
        LadbAbstractTab.prototype.bind.call(this);

        var that = this;

        // Bind buttons
        this.$btnOpen.on('click', function () {
            that.openCSV();
            this.blur();
        });
        this.$btnImport.on('click', function () {
            that.importParts();
            this.blur();
        });

        // Events

        addEventCallback('on_options_provider_changed', function () {
            if (that.loadOptions) {
                that.showObsolete('core.event.options_change', true);
            }
        });

    };

    LadbTabImporter.prototype.init = function (initializedCallback) {
        var that = this;

        this.bind();

        // Callback
        if (initializedCallback && typeof(initializedCallback) == 'function') {
            initializedCallback(that.$element);
        }

    };


    // PLUGIN DEFINITION
    // =======================

    function Plugin(option, params) {
        return this.each(function () {
            var $this = $(this);
            var data = $this.data('ladb.tabImporter');
            var options = $.extend({}, LadbTabImporter.DEFAULTS, $this.data(), typeof option == 'object' && option);

            if (!data) {
                if (undefined === options.opencutlist) {
                    throw 'opencutlist option is mandatory.';
                }
                $this.data('ladb.tabImporter', (data = new LadbTabImporter(this, options, options.opencutlist)));
            }
            if (typeof option == 'string') {
                data[option].apply(data, Array.isArray(params) ? params : [ params ])
            } else {
                data.init(option.initializedCallback);
            }
        })
    }

    var old = $.fn.ladbTabImporter;

    $.fn.ladbTabImporter = Plugin;
    $.fn.ladbTabImporter.Constructor = LadbTabImporter;


    // NO CONFLICT
    // =================

    $.fn.ladbTabImporter.noConflict = function () {
        $.fn.ladbTabImporter = old;
        return this;
    }

}(jQuery);
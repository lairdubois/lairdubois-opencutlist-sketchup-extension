+function ($) {
    'use strict';

    var SETTING_KEY_LOAD_OPTION_COL_SEP = 'importer.load.option.col_sep';
    var SETTING_KEY_LOAD_OPTION_ENCODING = 'importer.load.option.encoding';
    var SETTING_KEY_LOAD_OPTION_WITH_HEADERS = 'importer.load.option.with_headers';
    var SETTING_KEY_LOAD_OPTION_COLUMN_MAPPGING = 'importer.load.option.column_mapping';

    // Options defaults

    var OPTION_DEFAULT_COL_SEP = 0;     // \t
    var OPTION_DEFAULT_ENCODING = 0;    // UTF-8
    var OPTION_DEFAULT_WITH_HEADERS = true;
    var OPTION_DEFAULT_COLUMN_MAPPGING = {};

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

        this.$header = $('.ladb-header', this.$element);
        this.$fileTabs = $('.ladb-file-tabs', this.$header);
        this.$btnOpen = $('#ladb_btn_open', this.$header);
        this.$btnImport = $('#ladb_btn_import', this.$header);

        this.$page = $('.ladb-page', this.$element);

    };
    LadbTabImporter.prototype = new LadbAbstractTab;

    LadbTabImporter.DEFAULTS = {};

    LadbTabImporter.prototype.openCSV = function () {
        var that = this;

        rubyCallCommand('importer_open', null, function (response) {

            var i;

            if (response.errors) {
                for (i = 0; i < response.errors.length; i++) {
                    that.opencutlist.notify('<i class="ladb-opencutlist-icon-warning"></i> ' + i18next.t(response.errors[i]), 'error');
                }
            }
            if (response.csv_path) {

                // Retrieve load option options
                that.opencutlist.pullSettings([

                        SETTING_KEY_LOAD_OPTION_COL_SEP,
                        SETTING_KEY_LOAD_OPTION_ENCODING,
                        SETTING_KEY_LOAD_OPTION_WITH_HEADERS,
                        SETTING_KEY_LOAD_OPTION_COLUMN_MAPPGING

                    ],
                    3 /* SETTINGS_RW_STRATEGY_MODEL_GLOBAL */,
                    function () {

                        var loadOptions = {
                            csv_path: response.csv_path,
                            col_sep: that.opencutlist.getSetting(SETTING_KEY_LOAD_OPTION_COL_SEP, OPTION_DEFAULT_COL_SEP),
                            encoding: that.opencutlist.getSetting(SETTING_KEY_LOAD_OPTION_ENCODING, OPTION_DEFAULT_ENCODING),
                            with_headers: that.opencutlist.getSetting(SETTING_KEY_LOAD_OPTION_WITH_HEADERS, OPTION_DEFAULT_WITH_HEADERS),
                            column_mapping: that.opencutlist.getSetting(SETTING_KEY_LOAD_OPTION_COLUMN_MAPPGING, OPTION_DEFAULT_COLUMN_MAPPGING)
                        };

                        var $modal = that.appendModalInside('ladb_importer_modal_load', 'tabs/importer/_modal-load.twig', loadOptions);

                        // Fetch UI elements
                        var $selectColSep = $('#ladb_importer_load_select_col_sep', $modal);
                        var $selectEncoding = $('#ladb_importer_load_select_encoding', $modal);
                        var $inputWithHeader = $('#ladb_importer_load_input_with_headers', $modal);
                        var $btnLoad = $('#ladb_importer_load', $modal);

                        // Bind select
                        $selectColSep.val(loadOptions.col_sep);
                        $selectColSep.selectpicker(SELECT_PICKER_OPTIONS);
                        $selectEncoding.val(loadOptions.encoding);
                        $selectEncoding.selectpicker(SELECT_PICKER_OPTIONS);
                        $inputWithHeader.prop('checked', loadOptions.with_headers);

                        // Bind buttons
                        $btnLoad.on('click', function () {

                            that.loadCSV(loadOptions);

                            // Hide modal
                            $modal.modal('hide');

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
            { key:SETTING_KEY_LOAD_OPTION_COL_SEP, value:loadOptions.col_sep },
            { key:SETTING_KEY_LOAD_OPTION_ENCODING, value:loadOptions.encoding },
            { key:SETTING_KEY_LOAD_OPTION_WITH_HEADERS, value:loadOptions.with_headers },
            { key:SETTING_KEY_LOAD_OPTION_COLUMN_MAPPGING, value:loadOptions.column_mapping }
        ], 0 /* SETTINGS_RW_STRATEGY_GLOBAL */);

        rubyCallCommand('importer_load', loadOptions, function (response) {

            var i;

            if (response.errors) {
                for (i = 0; i < response.errors.length; i++) {
                    that.opencutlist.notify('<i class="ladb-opencutlist-icon-warning"></i> ' + i18next.t(response.errors[i]), 'error');
                }
            }
            if (response.warnings) {
                for (i = 0; i < response.warnings.length; i++) {
                    that.opencutlist.notify('<i class="ladb-opencutlist-icon-warning"></i> ' + i18next.t(response.warnings[i]), 'warning');
                }
            }
            if (response.csv_path) {

                var errors = response.errors;
                var warnings = response.warnings;
                var csv_path = response.csv_path;
                var columns = response.columns;
                var parts = response.parts;

                // Update filename
                that.$fileTabs.empty();
                that.$fileTabs.append(Twig.twig({ ref: "tabs/importer/_file-tab.twig" }).render({
                    filename: csv_path
                }));

                // Update page
                that.$page.empty();
                that.$page.append(Twig.twig({ ref: "tabs/importer/_list.twig" }).render({
                    errors: errors,
                    warnings: warnings,
                    csv_path: csv_path,
                    columns: columns,
                    parts: parts
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
                        });
                }

                // Display import button
                that.$btnImport.show();

                // Bind selects
                $('select', that.$page).selectpicker(SELECT_PICKER_OPTIONS);

                // Stick header
                that.stickSlideHeader(that.$rootSlide);

            }

        });

    };


    LadbTabImporter.prototype.bind = function () {
        var that = this;

        this.$btnOpen.on('click', function () {
            that.openCSV();
            this.blur();
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
            var data = $this.data('ladb.tabSettings');
            var options = $.extend({}, LadbTabImporter.DEFAULTS, $this.data(), typeof option == 'object' && option);

            if (!data) {
                if (undefined === options.opencutlist) {
                    throw 'opencutlist option is mandatory.';
                }
                $this.data('ladb.tabSettings', (data = new LadbTabImporter(this, options, options.opencutlist)));
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
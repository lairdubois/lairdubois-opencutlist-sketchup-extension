+function ($) {
    'use strict';

    // CLASS DEFINITION
    // ======================

    const LadbTabImportersBxf2 = function (element, options, dialog) {
        LadbAbstractTab.call(this, element, options, dialog);

        this.loadOptions = null;

        this.$header = $('.ladb-header', this.$element);
        this.$fileTabs = $('.ladb-file-tabs', this.$header);
        this.$btnOpen = $('#ladb_btn_open', this.$header);
        this.$btnImport = $('#ladb_btn_import', this.$header);

        this.$panelHelp = $('.ladb-panel-help', this.$element);
        this.$page = $('.ladb-page', this.$element);

        this.model = null;

    };
    LadbTabImportersBxf2.prototype = Object.create(LadbAbstractTab.prototype);

    LadbTabImportersBxf2.DEFAULTS = {};

    LadbTabImportersBxf2.prototype.openBxf2 = function (path = null) {
        const that = this;

        rubyCallCommand('importers_bxf2_open', { path: path }, function (response) {

            if (response.errors.length > 0) {

                // Update filename
                that.$fileTabs.empty();

                // Hide help panel
                that.$panelHelp.hide();

                // Update page
                that.$page.empty();
                that.$page.append(Twig.twig({ ref: "tabs/importers/bxf2/_list.twig" }).render({
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

                // Update page
                that.$page.empty();

                that.loadBxf2({ path: response.path, filename: response.filename });

            }

        });
    };

    LadbTabImportersBxf2.prototype.loadBxf2 = function (loadOptions) {
        const that = this;

        rubyCallCommand('importers_bxf2_load', loadOptions, function (response) {

            if (response.errors.length > 0) {

                // Update filename
                that.$fileTabs.empty();

                // Hide help panel
                that.$panelHelp.hide();

                // Update page
                that.$page.empty();
                that.$page.append(Twig.twig({ ref: "tabs/importers/bxf2/_list.twig" }).render({
                    errors: response.errors
                }));

                // Manage buttons
                that.$btnOpen.removeClass('btn-default');
                that.$btnOpen.addClass('btn-primary');
                that.$btnImport.hide();

                // Stick header
                that.stickSlideHeader(that.$rootSlide);

            } else {

                const errors = response.errors;
                const warnings = response.warnings;
                const filename = response.filename;

                that.model = response.model;

                // Update filename
                that.$fileTabs.empty();
                that.$fileTabs.append(Twig.twig({ ref: "tabs/importers/bxf2/_file-tab.twig" }).render({
                    filename: filename,
                }));

                // Hide help panel
                that.$panelHelp.hide();

                // Update page
                that.$page.empty();
                that.$page.append(Twig.twig({ ref: "tabs/importers/bxf2/_list.twig" }).render({
                    errors: errors,
                    warnings: warnings,
                    model: response.model,
                }));

                // Manage buttons
                that.$btnOpen.removeClass('btn-primary');
                that.$btnOpen.addClass('btn-default');
                that.$btnImport.show();

            }

        });
    };

    LadbTabImportersBxf2.prototype.importBxf2 = function () {
        const that = this;

        // Retrieve load option options
        rubyCallCommand('core_get_model_preset', { dictionary: 'importers_bxf2_import_options' }, function (response) {

            const importOptions = response.preset;

            const $modal = that.appendModalInside('ladb_importer_modal_import', 'tabs/importers/bxf2/_modal-import.twig', $.extend({
                cabinetCount: that.model.cabinets.length,
            }, importOptions));

            // Fetch UI elements
            const $widgetPreset = $('.ladb-widget-preset', $modal);
            const $inputPartMaterialName = $('#ladb_importer_import_input_part_material_name', $modal);
            const $inputMachiningMaterialName = $('#ladb_importer_import_input_machining_material_name', $modal);
            const $inputMachiningLayerName = $('#ladb_importer_import_input_machining_layer_name', $modal);
            const $inputHardwareMaterialName = $('#ladb_importer_import_input_hardware_material_name', $modal);
            const $inputHardwareLayerName = $('#ladb_importer_import_input_hardware_layer_name', $modal);
            const $btnImport = $('#ladb_importer_import', $modal);

            // Define useful functions
            const fnFetchOptions = function (options) {
                options.part_material_name = $inputPartMaterialName.val();
                options.machining_material_name = $inputMachiningMaterialName.val();
                options.machining_layer_name = $inputMachiningLayerName.val();
                options.hardware_material_name = $inputHardwareMaterialName.val();
                options.hardware_layer_name = $inputHardwareLayerName.val();
            };
            const fnFillInputs = function (options) {
                $inputPartMaterialName.val(options.part_material_name);
                $inputMachiningMaterialName.val(options.machining_material_name);
                $inputMachiningLayerName.val(options.machining_layer_name);
                $inputHardwareMaterialName.val(options.hardware_material_name);
                $inputHardwareLayerName.val(options.hardware_layer_name);
            };

            $widgetPreset.ladbWidgetPreset({
                dialog: that.dialog,
                dictionary: 'importers_bxf2_import_options',
                fnFetchOptions: fnFetchOptions,
                fnFillInputs: fnFillInputs
            });

            // Bind inputs
            $inputPartMaterialName.ladbTextinputText();
            $inputMachiningMaterialName.ladbTextinputText();
            $inputMachiningLayerName.ladbTextinputText();
            $inputHardwareMaterialName.ladbTextinputText();
            $inputHardwareLayerName.ladbTextinputText();

            // Bind buttons
            $btnImport.on('click', function () {

                // Fetch options
                fnFetchOptions(importOptions);

                // Store options
                rubyCallCommand('core_set_model_preset', { dictionary: 'importers_bxf2_import_options', values: importOptions });

                rubyCallCommand('importers_bxf2_import', importOptions, function (response) {

                    if (response.errors.length > 0) {
                        that.dialog.notifyErrors(response.errors);
                    } else {

                        // Update filename
                        that.$fileTabs.empty();

                        // Unstick header
                        that.unstickSlideHeader(that.$rootSlide);

                        // Update page
                        that.$page.empty();
                        that.$page.append(Twig.twig({ ref: "tabs/importers/bxf2/_alert-success.twig" }).render({
                        }));

                        // Bind buttons
                        $('#ladb_importer_success_btn_see', that.$page).on('click', function() {
                            this.blur();
                            that.dialog.minimize();
                            rubyCallCommand('core_zoom_extents')
                        });
                        $('#ladb_importer_success_btn_cutlist', that.$page).on('click', function() {
                            this.blur();
                            that.dialog.executeCommandOnTab('cutlist', 'generate_cutlist');
                        });

                        // Manage buttons
                        that.$btnOpen.removeClass('btn-default');
                        that.$btnOpen.addClass('btn-primary');
                        that.$btnImport.hide();

                    }

                });

                // Hide modal
                $modal.modal('hide');

            });

            // Show modal
            $modal.modal('show');

        });

    };

    // Internals /////

    LadbTabImportersBxf2.prototype.showObsolete = function (messageI18nKey, forced) {
        if (!this.isObsolete() || forced) {

            const that = this;

            // Set tab as obsolete
            this.setObsolete(true);

            const $modal = this.appendModalInside('ladb_importer_modal_obsolete', 'tabs/importer-bxf2/_modal-obsolete.twig', {
                messageI18nKey: messageI18nKey
            });

            // Fetch UI elements
            const $btnLoad = $('#ladb_importer_obsolete_load', $modal);

            // Bind buttons
            $btnLoad.on('click', function () {
                $modal.modal('hide');
                that.loadBxf2(that.loadOptions);
            });

            // Show modal
            $modal.modal('show');

        }
    };

    // Init /////

    LadbTabImportersBxf2.prototype.registerCommands = function () {
        LadbAbstractTab.prototype.registerCommands.call(this);

        const that = this;

        this.registerCommand('load', function (parameters) {
            that.openBxf2(parameters.path);
        });

    };

    LadbTabImportersBxf2.prototype.bind = function () {
        LadbAbstractTab.prototype.bind.call(this);

        const that = this;

        // Bind buttons
        this.$btnOpen.on('click', function () {
            that.openBxf2();
            this.blur();
        });
        this.$btnImport.on('click', function () {
            that.importBxf2();
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
                const options = $.extend({}, LadbTabImportersBxf2.DEFAULTS, $this.data(), typeof option === 'object' && option);
                if (undefined === options.dialog) {
                    throw 'dialog option is mandatory.';
                }
                $this.data('ladb.tab.plugin', (data = new LadbTabImportersBxf2(this, options, options.dialog)));
            }
            if (typeof option === 'string') {
                data[option].apply(data, Array.isArray(params) ? params : [ params ])
            } else {
                data.init(option.initializedCallback);
            }
        })
    }

    const old = $.fn.ladbTabImportersBxf2;

    $.fn.ladbTabImportersBxf2 = Plugin;
    $.fn.ladbTabImportersBxf2.Constructor = LadbTabImportersBxf2;


    // NO CONFLICT
    // =================

    $.fn.ladbTabImportersBxf2.noConflict = function () {
        $.fn.ladbTabImportersBxf2 = old;
        return this;
    }

}(jQuery);

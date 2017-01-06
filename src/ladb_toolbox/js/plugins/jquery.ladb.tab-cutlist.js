+function ($) {
    'use strict';

    var OPTION_KEY_AUTO_ORIENT = 'cutlist_option_auto_orient';
    var OPTION_KEY_SMART_MATERIAL = 'cutlist_option_smart_material';
    var OPTION_KEY_PART_NUMBER_WITH_LETTERS = 'cutlist_option_part_number_with_letters';
    var OPTION_KEY_PART_NUMBER_SEQUENCE_BY_GROUP = 'cutlist_option_part_number_sequence_by_group';
    var OPTION_KEY_PART_ORDER_STRATEGY = 'cutlist_option_part_order_strategy';

    var SETTING_KEY_SUMMARY_NO_PRINT = 'cutlist_setting_summary_hidden';

    // CLASS DEFINITION
    // ======================

    var LadbTabCutlist = function (element, options, toolbox) {
        this.options = options;
        this.$element = $(element);
        this.toolbox = toolbox;

        this.groups = [];
        this.materialUsages = [];
        this.editedPart = null;

        this.$fileTabs = $('.ladb-file-tabs', this.$element);
        this.$btnGenerate = $('#ladb_btn_generate', this.$element);
        this.$btnPrint = $('#ladb_btn_print', this.$element);
        this.$panelHelp = $('.ladb-panel-help', this.$element);

        this.$page = $('.ladb-page', this.$element);

        this.$modalOptions = $('#ladb_cutlist_modal_options', this.$element);
        this.$inputAutoOrient = $('#ladb_input_auto_orient', this.$modalOptions);
        this.$inputSmartMaterial = $('#ladb_input_smart_material', this.$modalOptions);
        this.$inputPartNumberWithLetters = $('#ladb_input_part_number_with_letters', this.$modalOptions);
        this.$inputPartNumberSequenceByGroup = $('#ladb_input_part_number_sequence_by_group', this.$modalOptions);
        this.$sortablePartNumberSequenceByGroup = $('#ladb_sortable_part_order_strategy', this.$modalOptions);

        this.$modalEditPart = $('#ladb_cutlist_modal_part', this.$element);
        this.$btnPartUpdate = $('#ladb_cutlist_part_update', this.$modalEditPart);
        this.$selectMaterialName = $('#ladb_cutlist_part_select_material_name', this.$modalEditPart);
        this.$inputPartName = $('#ladb_cutlist_part_input_name', this.$modalEditPart);
        this.$divMaterialOrigins = $('.ladb-material-origins', this.$modalEditPart);
    };

    LadbTabCutlist.DEFAULTS = {};

    LadbTabCutlist.prototype.generateCutlist = function () {
        var that = this;

        this.groups = [];
        this.$page.empty();
        this.$btnGenerate.prop('disabled', true);

        rubyCallCommand('cutlist_generate', this.userOptions, function(data) {

            var errors = data.errors;
            var warnings = data.warnings;
            var tips = data.tips;
            var filename = data.filename;
            var pageLabel = data.page_label;
            var materialUsages = data.material_usages;
            var groups = data.groups;

            // Keep usefull data
            that.groups = groups;
            that.materialUsages = materialUsages;

            // Update filename
            that.$fileTabs.empty();
            that.$fileTabs.append(Twig.twig({ ref: "tabs/cutlist/_file-tab.twig" }).render({
                filename: filename,
                pageLabel: pageLabel
            }));

            // Hide help panel
            if (groups.length > 0) {
                that.$panelHelp.hide();
            }

            // Update print button state
            that.$btnPrint.prop('disabled', groups.length == 0);

            // Update page
            that.$page.empty();
            that.$page.append(Twig.twig({ ref: "tabs/cutlist/_list.twig" }).render({
                showThicknessSeparators: that.userOptions.part_order_strategy.startsWith('thickness') || that.userOptions.part_order_strategy.startsWith('-thickness'),
                userSettings: that.userSettings,
                errors: errors,
                warnings: warnings,
                tips: tips,
                groups: groups
            }));

            // Init tooltips
            $('[data-toggle="tooltip"]').tooltip();

            // Bind buttons
            $('.ladb-btn-toggle-no-print', that.$page).on('click', function() {
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
                if (groupId == 'ladb_summary') {
                    that.userSettings.summary_no_print = $group.hasClass('no-print');
                    that.toolbox.setUserSetting(SETTING_KEY_SUMMARY_NO_PRINT, that.userSettings.summary_no_print);
                }
            });
            $('a.ladb-btn-scrollto', that.$page).on('click', function() {
                var target = $(this).attr('href');
                $('html, body').animate({ scrollTop: $(target).offset().top - 20 }, 500).promise().then(function() {
                    $(target).effect("highlight", {}, 1500);
                });
                $(this).blur();
                return false;
            });
            $('a.ladb-btn-edit', that.$page).on('click', function() {
                var partGuid = $(this).data('part-id');
                that.editPart(partGuid);
                $(this).blur();
                return false;
            });

            // Restore button state
            that.$btnGenerate.prop('disabled', false);

        });

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
        var that = this;

        var part = this.findPartById(id);
        if (part) {

            rubyCallCommand('cutlist_part_get_thumbnail', part, function(data) {

                var thumbnailFile = data['thumbnail_file'];

                var $imgThumbnail = $('.ladb-part-thumbnail', that.$modalEditPart);
                $imgThumbnail.attr('src', thumbnailFile);

                // Keep the edited part
                that.editedPart = part;

                // Populate material select
                that.$selectMaterialName.empty();
                that.$selectMaterialName.append(Twig.twig({ref: "tabs/cutlist/_material-usages.twig"}).render({
                    materialUsages: that.materialUsages
                }));

                // Form fields
                that.$inputPartName.val(part.name);
                that.$selectMaterialName.val(part.material_name);

                // Refresh select
                that.$selectMaterialName.selectpicker('refresh');

                // Material origins
                that.$divMaterialOrigins.empty();
                if (part.material_name) {
                    that.$divMaterialOrigins.append(Twig.twig({ref: "tabs/cutlist/_material-origins.twig"}).render({
                        materialOrigins: part.material_origins,
                        displayOwned: true,
                        flat: true
                    }));
                }

                that.$modalEditPart.modal('show');

            });

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

            rubyCallCommand('cutlist_part_update', that.editedPart, function() {

                // Reset edited part
                that.editedPart = null;

                // Hide modal
                that.$modalEditPart.modal('hide');

                // Refresh the list
                that.generateCutlist();

            });

        });

        // Bind inputs
        this.$inputAutoOrient.on('change', function () {
            that.userOptions.auto_orient = that.$inputAutoOrient.is(':checked');
            that.toolbox.setUserSetting(OPTION_KEY_AUTO_ORIENT, that.userOptions.auto_orient);
        });
        this.$inputSmartMaterial.on('change', function () {
            that.userOptions.smart_material = that.$inputSmartMaterial.is(':checked');
            that.toolbox.setUserSetting(OPTION_KEY_SMART_MATERIAL, that.userOptions.smart_material);
        });
        this.$inputPartNumberWithLetters.on('change', function () {
            that.userOptions.part_number_with_letters = that.$inputPartNumberWithLetters.is(':checked');
            that.toolbox.setUserSetting(OPTION_KEY_PART_NUMBER_WITH_LETTERS, that.userOptions.part_number_with_letters);
        });
        this.$inputPartNumberSequenceByGroup.on('change', function () {
            that.userOptions.part_number_sequence_by_group = that.$inputPartNumberSequenceByGroup.is(':checked');
            that.toolbox.setUserSetting(OPTION_KEY_PART_NUMBER_SEQUENCE_BY_GROUP, that.userOptions.part_number_sequence_by_group);
        });

    };

    LadbTabCutlist.prototype.init = function () {
        var that = this;

        this.toolbox.pullUserSettings([
            OPTION_KEY_AUTO_ORIENT,
            OPTION_KEY_SMART_MATERIAL,
            OPTION_KEY_PART_NUMBER_WITH_LETTERS,
            OPTION_KEY_PART_NUMBER_SEQUENCE_BY_GROUP,
            OPTION_KEY_PART_ORDER_STRATEGY,
            SETTING_KEY_SUMMARY_NO_PRINT
        ], function() {

            that.userOptions = {
                auto_orient: that.toolbox.getUserSetting(OPTION_KEY_AUTO_ORIENT, true),
                smart_material: that.toolbox.getUserSetting(OPTION_KEY_SMART_MATERIAL, true),
                part_number_with_letters: that.toolbox.getUserSetting(OPTION_KEY_PART_NUMBER_WITH_LETTERS, true),
                part_number_sequence_by_group: that.toolbox.getUserSetting(OPTION_KEY_PART_NUMBER_SEQUENCE_BY_GROUP, false),
                part_order_strategy: that.toolbox.getUserSetting(OPTION_KEY_PART_ORDER_STRATEGY, '-thickness>-length>-width>-count>name')
            };

            that.userSettings = {
                summary_no_print: that.toolbox.getUserSetting(SETTING_KEY_SUMMARY_NO_PRINT, false)
            };

            // Init inputs values
            that.$inputAutoOrient.prop('checked', that.userOptions.auto_orient);
            that.$inputSmartMaterial.prop('checked', that.userOptions.smart_material);
            that.$inputPartNumberWithLetters.prop('checked', that.userOptions.part_number_with_letters);
            that.$inputPartNumberSequenceByGroup.prop('checked', that.userOptions.part_number_sequence_by_group);

            // Init selects
            that.$selectMaterialName.selectpicker({
                size: 10,
                iconBase: 'ladb-toolbox-icon',
                tickIcon: 'ladb-toolbox-icon-tick',
                showTick: true
            });

            // Init sortable
            var onSortableChange = function() {
                var properties = [];
                that.$sortablePartNumberSequenceByGroup.children('li').each(function () {
                    properties.push($(this).data('property'));
                });
                that.userOptions.part_order_strategy = properties.join('>');
                that.toolbox.setUserSetting(OPTION_KEY_PART_ORDER_STRATEGY, that.userOptions.part_order_strategy);
                console.log(that.userOptions.part_order_strategy);
            };
            var properties = that.userOptions.part_order_strategy.split('>');
            for (var i = 0; i < properties.length; i++) {
                var property = properties[i];
                that.$sortablePartNumberSequenceByGroup.append(Twig.twig({ref: "tabs/cutlist/_option-part-order-strategy-property.twig"}).render({
                    order: property.startsWith('-') ? '-' : '',
                    property: property.startsWith('-') ? property.substr(1) : property
                }));
            }
            that.$sortablePartNumberSequenceByGroup.find('a').on('click', function() {
                var $item = $(this).parent().parent();
                var $icon = $('i', $(this));
                var property = $item.data('property');
                if (property.startsWith('-')) {
                    property = property.substr(1);
                    $icon.addClass('ladb-toolbox-icon-sort-asc');
                    $icon.removeClass('ladb-toolbox-icon-sort-desc');
                } else {
                    property = '-' + property;
                    $icon.removeClass('ladb-toolbox-icon-sort-asc');
                    $icon.addClass('ladb-toolbox-icon-sort-desc');
                }
                $item.data('property', property);
                onSortableChange()
            });
            that.$sortablePartNumberSequenceByGroup.sortable({
                cursor: 'move',
                handle: '.ladb-handle',
                update: function (event, ui) {
                    onSortableChange();
                }
            });

            that.bind();

            // Init tooltips & popover
            $('[data-toggle="tooltip"]').tooltip();
            $('[data-toggle="popover"]').popover({
                html: true
            });

        });

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
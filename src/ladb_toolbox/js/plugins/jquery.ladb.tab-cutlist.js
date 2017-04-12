+function ($) {
    'use strict';

    // CONSTANTS
    // ======================

    // Options keys

    var SETTING_KEY_OPTION_AUTO_ORIENT = 'cutlist_option_auto_orient';
    var SETTING_KEY_OPTION_SMART_MATERIAL = 'cutlist_option_smart_material';
    var SETTING_KEY_OPTION_PART_NUMBER_WITH_LETTERS = 'cutlist_option_part_number_with_letters';
    var SETTING_KEY_OPTION_PART_NUMBER_SEQUENCE_BY_GROUP = 'cutlist_option_part_number_sequence_by_group';
    var SETTING_KEY_OPTION_PART_ORDER_STRATEGY = 'cutlist_option_part_order_strategy';

    var SETTING_KEY_OPTION_HIDE_RAW_DIMENSIONS = 'cutlist_option_hide_raw_dimensions';
    var SETTING_KEY_OPTION_HIDE_FINAL_DIMENSIONS = 'cutlist_option_hide_final_dimensions';
    var SETTING_KEY_OPTION_HIDE_UNTYPED_MATERIAL_DIMENSIONS = 'cutlist_option_hide_untyped_material_dimensions';
    var SETTING_KEY_OPTION_HIDDEN_GROUP_IDS = 'cutlist_option_hidden_group_ids';

    // Options defaults

    var OPTION_DEFAULT_AUTO_ORIENT = true;
    var OPTION_DEFAULT_SMART_MATERIAL = true;
    var OPTION_DEFAULT_PART_NUMBER_WITH_LETTERS = true;
    var OPTION_DEFAULT_PART_NUMBER_SEQUENCE_BY_GROUP = true;
    var OPTION_DEFAULT_PART_ORDER_STRATEGY = '-thickness>-length>-width>-count>name';

    var OPTION_DEFAULT_HIDE_RAW_DIMENSIONS = false;
    var OPTION_DEFAULT_HIDE_FINAL_DIMENSIONS = false;
    var OPTION_DEFAULT_HIDE_UNTYPED_MATERIAL_DIMENSIONS = false;
    var OPTION_DEFAULT_HIDDEN_GROUP_IDS = [];

    // Select picker options

    var SELECT_PICKER_OPTIONS = {
        size: 10,
        iconBase: 'ladb-toolbox-icon',
        tickIcon: 'ladb-toolbox-icon-tick',
        showTick: true
    };

    // CLASS DEFINITION
    // ======================

    var LadbTabCutlist = function (element, options, toolbox) {
        this.options = options;
        this.$element = $(element);
        this.toolbox = toolbox;

        this.groups = [];
        this.materialUsages = [];
        this.editedPart = null;
        this.editedGroup = null;

        this.$header = $('.ladb-header', this.$element);
        this.$fileTabs = $('.ladb-file-tabs', this.$header);
        this.$btnGenerate = $('#ladb_btn_generate', this.$header);
        this.$btnPrint = $('#ladb_btn_print', this.$header);
        this.$btnExport = $('#ladb_btn_export', this.$header);
        this.$itemShowAllGroups = $('#ladb_item_show_all_groups', this.$header);
        this.$itemOptions = $('#ladb_item_options', this.$header);

        this.$panelHelp = $('.ladb-panel-help', this.$element);
        this.$page = $('.ladb-page', this.$element);

    };

    LadbTabCutlist.DEFAULTS = {};

    // Cutlist /////

    LadbTabCutlist.prototype.generateCutlist = function (callback) {
        var that = this;

        this.groups = [];
        this.$page.empty();
        this.$btnGenerate.prop('disabled', true);

        rubyCallCommand('cutlist_generate', this.generateOptions, function(data) {

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
            that.$panelHelp.hide();

            // Update buttons and items state
            that.$btnPrint.prop('disabled', groups.length == 0);
            that.$btnExport.prop('disabled', groups.length == 0);
            that.$itemShowAllGroups.closest('li').toggleClass('disabled', groups.length == 0);

            // Update page
            that.$page.empty();
            that.$page.append(Twig.twig({ ref: "tabs/cutlist/_list.twig" }).render({
                showThicknessSeparators: that.generateOptions.part_order_strategy.startsWith('thickness') || that.generateOptions.part_order_strategy.startsWith('-thickness'),
                uiOptions: that.uiOptions,
                errors: errors,
                warnings: warnings,
                tips: tips,
                groups: groups
            }));

            // Setup tooltips
            that.toolbox.setupTooltips();

            // Cleanup nonexistent hidden group ids
            var hiddenGroupIdsLength = that.uiOptions.hidden_group_ids.length;
            for (var i = hiddenGroupIdsLength - 1 ; i >= 0; i--) {
                if (that.uiOptions.hidden_group_ids[i] == 'summary') {
                    continue;
                }
                var exists = false;
                for (var j = 0; j < groups.length; j++) {
                    if (that.uiOptions.hidden_group_ids[i] == groups[j].id) {
                        exists = true;
                        break;
                    }
                }
                if (!exists) {
                    that.uiOptions.hidden_group_ids.splice(i, 1);
                }
            }
            if (hiddenGroupIdsLength > that.uiOptions.hidden_group_ids.length) {
                that.toolbox.setSetting(SETTING_KEY_OPTION_HIDDEN_GROUP_IDS, that.uiOptions.hidden_group_ids);
            }

            // Bind buttons
            $('.ladb-btn-toggle-no-print', that.$page).on('click', function() {
                var $group = $(this).closest('.ladb-cutlist-group');
                if ($group.hasClass('no-print')) {
                    that.showGroup($group);
                } else {
                    that.hideGroup($group);
                }
                $(this).blur();
            });
            $('a.ladb-btn-scrollto', that.$page).on('click', function() {
                var target = $(this).attr('href');
                $('html, body').animate({ scrollTop: $(target).offset().top - that.$header.outerHeight(true) - 20 }, 200).promise().then(function() {
                    $(target).effect("highlight", {}, 1500);
                });
                $(this).blur();
            });
            $('a.ladb-item-edit-material', that.$page).on('click', function() {
                $(this).blur();
            });
            $('a.ladb-item-edit-group', that.$page).on('click', function() {
                var $group = $(this).closest('.ladb-cutlist-group');
                var groupId = $group.data('group-id');
                that.editGroup(groupId);
                $(this).blur();
            });
            $('a.ladb-item-hide-all-other-groups', that.$page).on('click', function() {
                var $group = $(this).closest('.ladb-cutlist-group');
                var groupId = $group.data('group-id');
                that.hideAllGroups(groupId);
                $('html, body').animate({ scrollTop: $group.offset().top - that.$header.outerHeight(true) - 20 }, 200).promise();
                $(this).blur();
            });
            $('a.ladb-btn-edit-part', that.$page).on('click', function() {
                var partId = $(this).data('part-id');
                that.editPart(partId);
                $(this).blur();
                return false;
            });

            // Restore button state
            that.$btnGenerate.prop('disabled', false);

            // Stick header
            that.$header.stick_in_parent();

            // Callback
            if (callback && typeof callback == 'function') {
                callback();
            }

        });

    };

    LadbTabCutlist.prototype.exportCutlist = function () {
        var that = this;

        rubyCallCommand('cutlist_export', {
            hidden_group_ids: this.uiOptions.hidden_group_ids
        }, function(data) {

            var i;

            if (data.errors) {
                for (i = 0; i < data.errors.length; i++) {
                    that.toolbox.notify(i18next.t(data.errors[i]), 'error');
                }
            }
            if (data.warnings) {
                for (i = 0; i < data.warnings.length; i++) {
                    that.toolbox.notify(i18next.t(data.warnings[i]), 'warning');
                }
            }
            if (data.export_path) {
                var n = that.toolbox.notify(i18next.t('tab.cutlist.success.exported_to', { export_path: data.export_path }), 'success', [
                    Noty.button('Ouvrir', 'btn btn-default', function () {
                        window.open('file://' + data.export_path, '_blank');
                        n.close();
                    })
                ]);
            }

        });

    };

    // Parts /////

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

                // Keep the edited part
                that.editedPart = part;

                // Render modal
                that.$element.append(Twig.twig({ref: "tabs/cutlist/_modal-part.twig"}).render({
                    part: part,
                    thumbnailFile: thumbnailFile,
                    materialUsages: that.materialUsages
                }));

                // Fetch UI elements
                var $modal = $('#ladb_cutlist_modal_part', that.$element);
                var $inputName = $('#ladb_cutlist_part_input_name', $modal);
                var $selectMaterialName = $('#ladb_cutlist_part_select_material_name', $modal);
                var $btnUpdate = $('#ladb_cutlist_part_update', $modal);

                // Bind modal
                $modal.on('hidden.bs.modal', function () {
                    $(this)
                        .data('bs.modal', null)
                        .remove();
                });

                // Bind select
                $selectMaterialName.val(part.material_name);
                $selectMaterialName.selectpicker(SELECT_PICKER_OPTIONS);

                // Bind buttons
                $btnUpdate.on('click', function () {

                    that.editedPart.name = $inputName.val();
                    that.editedPart.material_name = $selectMaterialName.val();

                    rubyCallCommand('cutlist_part_update', that.editedPart, function() {

                        var partId = that.editedPart.id;
                        var wTop = $('#ladb_part_' + partId).offset().top - $(window).scrollTop();

                        // Reset edited part
                        that.editedPart = null;

                        // Hide modal
                        $modal.modal('hide');

                        // Refresh the list
                        that.generateCutlist(function() {

                            // Try to scroll to the edited part's row
                            var $part = $('#ladb_part_' + partId);
                            if ($part.length > 0) {
                                $part.effect("highlight", {}, 1500);
                                $('html, body').animate({ scrollTop: $part.offset().top - wTop }, 0);
                            }

                        });

                    });

                });

                // Show modal
                $modal.modal('show');

            });

        }
    };

    // Groups /////

    LadbTabCutlist.prototype.findGroupById = function (id) {
        for (var i = 0 ; i < this.groups.length; i++) {
            var group = this.groups[i];
            if (group.id == id) {
                return group;
            }
        }
        return null;
    };

    LadbTabCutlist.prototype.editGroup = function (id) {
        var that = this;

        var group = this.findGroupById(id);
        if (group) {

            // Keep the edited group
            that.editedGroup = group;

            // Render modal
            that.$element.append(Twig.twig({ref: "tabs/cutlist/_modal-group.twig"}).render({
                group: group,
                materialUsages: that.materialUsages
            }));

            // Fetch UI elements
            var $modal = $('#ladb_cutlist_modal_group', that.$element);
            var $selectMaterialName = $('#ladb_cutlist_group_select_material_name', $modal);
            var $btnUpdate = $('#ladb_cutlist_group_update', $modal);

            // Bind modal
            $modal.on('hidden.bs.modal', function () {
                $(this)
                    .data('bs.modal', null)
                    .remove();
            });

            // Bind select
            $selectMaterialName.val(group.material_name);
            $selectMaterialName.selectpicker(SELECT_PICKER_OPTIONS);

            // Bind buttons
            $btnUpdate.on('click', function () {

                // Fetch form values
                that.editedGroup.material_name = $selectMaterialName.val();

                rubyCallCommand('cutlist_group_update', that.editedGroup, function() {

                    // Reset edited group
                    that.editedGroup = null;

                    // Hide modal
                    $modal.modal('hide');

                    // Refresh the list
                    that.generateCutlist();

                });

            });

            // Show modal
            $modal.modal('show');

        }
    };

    LadbTabCutlist.prototype.showGroup = function ($group) {
        var groupId = $group.data('group-id');
        var $btn = $('.ladb-btn-toggle-no-print', $group);
        var $i = $('i', $btn);

        $group.removeClass('no-print');
        $i.addClass('ladb-toolbox-icon-eye-close');
        $i.removeClass('ladb-toolbox-icon-eye-open');

        var idx = this.uiOptions.hidden_group_ids.indexOf(groupId);
        if (idx != -1) {
            this.uiOptions.hidden_group_ids.splice(idx, 1);
            this.toolbox.setSetting(SETTING_KEY_OPTION_HIDDEN_GROUP_IDS, this.uiOptions.hidden_group_ids);
        }

    };

    LadbTabCutlist.prototype.hideGroup = function ($group) {
        var groupId = $group.data('group-id');
        var $btn = $('.ladb-btn-toggle-no-print', $group);
        var $i = $('i', $btn);

        $group.addClass('no-print');
        $i.removeClass('ladb-toolbox-icon-eye-close');
        $i.addClass('ladb-toolbox-icon-eye-open');

        var idx = this.uiOptions.hidden_group_ids.indexOf(groupId);
        if (idx == -1) {
            this.uiOptions.hidden_group_ids.push(groupId);
            this.toolbox.setSetting(SETTING_KEY_OPTION_HIDDEN_GROUP_IDS, this.uiOptions.hidden_group_ids);
        }

    };

    LadbTabCutlist.prototype.showAllGroups = function () {
        var that = this;
        $('.ladb-cutlist-group', this.$page).each(function() {
            that.showGroup($(this));
        });
    };

    LadbTabCutlist.prototype.hideAllGroups = function (exceptedGroupId) {
        var that = this;
        $('.ladb-cutlist-group', this.$page).each(function() {
            var groupId = $(this).data('group-id');
            if (exceptedGroupId && groupId != exceptedGroupId) {
                that.hideGroup($(this));
            }
        });
    };

    // Options /////

    LadbTabCutlist.prototype.editOptions = function () {
        var that = this;

        // Render modal
        this.$element.append(Twig.twig({ref: "tabs/cutlist/_modal-options.twig"}).render({
        }));

        // Fetch UI elements
        var $modal = $('#ladb_cutlist_modal_options', that.$element);
        var $inputAutoOrient = $('#ladb_input_auto_orient', $modal);
        var $inputSmartMaterial = $('#ladb_input_smart_material', $modal);
        var $inputPartNumberWithLetters = $('#ladb_input_part_number_with_letters', $modal);
        var $inputPartNumberSequenceByGroup = $('#ladb_input_part_number_sequence_by_group', $modal);
        var $inputHideRawDimensions = $('#ladb_input_hide_raw_dimensions', $modal);
        var $inputHideFinalDimensions = $('#ladb_input_hide_final_dimensions', $modal);
        var $inputHideUntypedMaterialDimensions = $('#ladb_input_hide_untyped_material_dimensions', $modal);
        var $sortablePartOrderStrategy = $('#ladb_sortable_part_order_strategy', $modal);
        var $btnReset = $('#ladb_cutlist_options_reset', $modal);
        var $btnUpdate = $('#ladb_cutlist_options_update', $modal);

        // Bind modal
        $modal.on('hidden.bs.modal', function () {
            $(this)
                .data('bs.modal', null)
                .remove();
        });

        var populateOptionsInputs = function (generateOptions, uiOptions) {

            // Checkboxes

            $inputAutoOrient.prop('checked', generateOptions.auto_orient);
            $inputSmartMaterial.prop('checked', generateOptions.smart_material);
            $inputPartNumberWithLetters.prop('checked', generateOptions.part_number_with_letters);
            $inputPartNumberSequenceByGroup.prop('checked', generateOptions.part_number_sequence_by_group);
            $inputHideRawDimensions.prop('checked', uiOptions.hide_raw_dimensions);
            $inputHideFinalDimensions.prop('checked', uiOptions.hide_final_dimensions);
            $inputHideUntypedMaterialDimensions
                .prop('checked', uiOptions.hide_untyped_material_dimensions)
                .prop('disabled', uiOptions.hide_final_dimensions);

            // Part order sortables

            var properties = generateOptions.part_order_strategy.split('>');
            $sortablePartOrderStrategy.empty();
            for (var i = 0; i < properties.length; i++) {
                var property = properties[i];
                $sortablePartOrderStrategy.append(Twig.twig({ref: "tabs/cutlist/_option-part-order-strategy-property.twig"}).render({
                    order: property.startsWith('-') ? '-' : '',
                    property: property.startsWith('-') ? property.substr(1) : property
                }));
            }
            $sortablePartOrderStrategy.find('a').on('click', function() {
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
            });
            $sortablePartOrderStrategy.sortable({
                cursor: 'ns-resize',
                handle: '.ladb-handle'
            });

        };

        // Bind inputs
        $inputHideFinalDimensions.on('change', function () {
            $inputHideUntypedMaterialDimensions.prop('disabled', $(this).is(':checked'));
        });

        // Bind buttons
        $btnReset.on('click', function() {
            var generateOptions = $.extend($.extend({}, that.generateOptions), {
                auto_orient: OPTION_DEFAULT_AUTO_ORIENT,
                smart_material: OPTION_DEFAULT_SMART_MATERIAL,
                part_number_with_letters: OPTION_DEFAULT_PART_NUMBER_WITH_LETTERS,
                part_number_sequence_by_group: OPTION_DEFAULT_PART_NUMBER_SEQUENCE_BY_GROUP,
                part_order_strategy: OPTION_DEFAULT_PART_ORDER_STRATEGY
            });
            var uiOptions = $.extend($.extend({}, that.uiOptions), {
                hide_raw_dimensions: OPTION_DEFAULT_HIDE_RAW_DIMENSIONS,
                hide_final_dimensions: OPTION_DEFAULT_HIDE_FINAL_DIMENSIONS,
                hide_untyped_material_dimensions: OPTION_DEFAULT_HIDE_UNTYPED_MATERIAL_DIMENSIONS
            });
            populateOptionsInputs(generateOptions, uiOptions);
        });
        $btnUpdate.on('click', function() {

            // Fetch options

            that.generateOptions.auto_orient = $inputAutoOrient.is(':checked');
            that.generateOptions.smart_material = $inputSmartMaterial.is(':checked');
            that.generateOptions.part_number_with_letters = $inputPartNumberWithLetters.is(':checked');
            that.generateOptions.part_number_sequence_by_group = $inputPartNumberSequenceByGroup.is(':checked');
            that.uiOptions.hide_raw_dimensions = $inputHideRawDimensions.is(':checked');
            that.uiOptions.hide_final_dimensions = $inputHideFinalDimensions.is(':checked');
            that.uiOptions.hide_untyped_material_dimensions = $inputHideUntypedMaterialDimensions.is(':checked');

            var properties = [];
            $sortablePartOrderStrategy.children('li').each(function () {
                properties.push($(this).data('property'));
            });
            that.generateOptions.part_order_strategy = properties.join('>');

            // Store options
            that.toolbox.setSettings([
                { key:SETTING_KEY_OPTION_AUTO_ORIENT, value:that.generateOptions.auto_orient },
                { key:SETTING_KEY_OPTION_SMART_MATERIAL, value:that.generateOptions.smart_material },
                { key:SETTING_KEY_OPTION_PART_NUMBER_WITH_LETTERS, value:that.generateOptions.part_number_with_letters },
                { key:SETTING_KEY_OPTION_PART_NUMBER_SEQUENCE_BY_GROUP, value:that.generateOptions.part_number_sequence_by_group },
                { key:SETTING_KEY_OPTION_PART_ORDER_STRATEGY, value:that.generateOptions.part_order_strategy },
                { key:SETTING_KEY_OPTION_HIDE_RAW_DIMENSIONS, value:that.uiOptions.hide_raw_dimensions },
                { key:SETTING_KEY_OPTION_HIDE_FINAL_DIMENSIONS, value:that.uiOptions.hide_final_dimensions },
                { key:SETTING_KEY_OPTION_HIDE_UNTYPED_MATERIAL_DIMENSIONS, value:that.uiOptions.hide_untyped_material_dimensions }
            ]);

            // Hide modal
            $modal.modal('hide');

            // Refresh the list if it has already been generated
            if (that.groups.length > 0) {
                that.generateCutlist();
            }

        });

        // Populate inputs
        populateOptionsInputs(that.generateOptions, that.uiOptions);

        // Setup popovers
        this.toolbox.setupPopovers();

        // Show modal
        $modal.modal('show');

    };

    // Internals /////

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
        this.$btnExport.on('click', function () {

            // Render modal
            that.$element.append(Twig.twig({ref: "tabs/cutlist/_modal-export.twig"}).render({
            }));

            // Fetch UI elements
            var $modal = $('#ladb_cutlist_modal_export', that.$element);
            var $btnExport = $('#ladb_cutlist_export', $modal);

            // Bind modal
            $modal.on('hidden.bs.modal', function () {
                $(this)
                    .data('bs.modal', null)
                    .remove();
            });

            // Bind buttons
            $btnExport.on('click', function() {
                that.exportCutlist();

                // Hide modal
                $modal.modal('hide');

            });

            // Show modal
            $modal.modal('show');

            this.blur();
        });
        this.$itemShowAllGroups.on('click', function () {
            that.showAllGroups();
            this.blur();
        });
        this.$itemOptions.on('click', function () {
            that.editOptions();
            this.blur();
        });

    };

    LadbTabCutlist.prototype.init = function () {
        var that = this;

        this.toolbox.pullSettings([

            SETTING_KEY_OPTION_AUTO_ORIENT,
            SETTING_KEY_OPTION_SMART_MATERIAL,
            SETTING_KEY_OPTION_PART_NUMBER_WITH_LETTERS,
            SETTING_KEY_OPTION_PART_NUMBER_SEQUENCE_BY_GROUP,
            SETTING_KEY_OPTION_PART_ORDER_STRATEGY,

            SETTING_KEY_OPTION_HIDE_UNTYPED_MATERIAL_DIMENSIONS,
            SETTING_KEY_OPTION_HIDE_RAW_DIMENSIONS,
            SETTING_KEY_OPTION_HIDE_FINAL_DIMENSIONS,
            SETTING_KEY_OPTION_HIDDEN_GROUP_IDS

        ], function() {

            that.generateOptions = {
                auto_orient: that.toolbox.getSetting(SETTING_KEY_OPTION_AUTO_ORIENT, OPTION_DEFAULT_AUTO_ORIENT),
                smart_material: that.toolbox.getSetting(SETTING_KEY_OPTION_SMART_MATERIAL, OPTION_DEFAULT_SMART_MATERIAL),
                part_number_with_letters: that.toolbox.getSetting(SETTING_KEY_OPTION_PART_NUMBER_WITH_LETTERS, OPTION_DEFAULT_PART_NUMBER_WITH_LETTERS),
                part_number_sequence_by_group: that.toolbox.getSetting(SETTING_KEY_OPTION_PART_NUMBER_SEQUENCE_BY_GROUP, OPTION_DEFAULT_PART_NUMBER_SEQUENCE_BY_GROUP),
                part_order_strategy: that.toolbox.getSetting(SETTING_KEY_OPTION_PART_ORDER_STRATEGY, OPTION_DEFAULT_PART_ORDER_STRATEGY)
            };

            that.uiOptions = {
                hide_raw_dimensions: that.toolbox.getSetting(SETTING_KEY_OPTION_HIDE_RAW_DIMENSIONS, OPTION_DEFAULT_HIDE_RAW_DIMENSIONS),
                hide_final_dimensions: that.toolbox.getSetting(SETTING_KEY_OPTION_HIDE_FINAL_DIMENSIONS, OPTION_DEFAULT_HIDE_FINAL_DIMENSIONS),
                hide_untyped_material_dimensions: that.toolbox.getSetting(SETTING_KEY_OPTION_HIDE_UNTYPED_MATERIAL_DIMENSIONS, OPTION_DEFAULT_HIDE_UNTYPED_MATERIAL_DIMENSIONS),
                hidden_group_ids: that.toolbox.getSetting(SETTING_KEY_OPTION_HIDDEN_GROUP_IDS, OPTION_DEFAULT_HIDDEN_GROUP_IDS)
            };

            that.bind();
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
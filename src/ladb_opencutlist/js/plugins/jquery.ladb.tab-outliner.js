+function ($) {
    'use strict';

    // CLASS DEFINITION
    // ======================

    var LadbTabOutliner = function (element, options, opencutlist) {
        LadbAbstractTab.call(this, element, options, opencutlist);

        this.$header = $('.ladb-header', this.$element);
        this.$fileTabs = $('.ladb-file-tabs', this.$header);
        this.$btnList = $('#ladb_btn_list', this.$header);

        this.$page = $('.ladb-page', this.$element);

    };
    LadbTabOutliner.prototype = new LadbAbstractTab;

    LadbTabOutliner.DEFAULTS = {};

    // List /////

    LadbTabOutliner.prototype.loadList = function (callback) {
        var that = this;

        this.materials = [];
        this.$page.empty();
        this.$btnList.prop('disabled', true);
        this.setObsolete(false);

        window.requestAnimationFrame(function () {

            // Start progress feedback
            that.dialog.startProgress(1);

            rubyCallCommand('outliner_list', {}, function (response) {

                var errors = response.errors;
                var warnings = response.warnings;
                var filename = response.filename;
                var modelName = response.model_name;
                var root_node = response.root_node;

                // Keep useful data
                that.lengthUnitStrippedname = response.length_unit_strippedname;
                that.massUnitStrippedname = response.mass_unit_strippedname;
                that.currencySymbol = response.currency_symbol;
                that.rootNode = root_node;

                // Update filename
                that.$fileTabs.empty();
                that.$fileTabs.append(Twig.twig({ ref: "tabs/outliner/_file-tab.twig" }).render({
                    filename: filename,
                    modelName: modelName
                }));

                // Update page
                that.$page.empty();
                that.$page.append(Twig.twig({ ref: "tabs/outliner/_list.twig" }).render({
                    errors: errors,
                    warnings: warnings,
                    root_node: root_node
                }));

                // Setup tooltips
                that.dialog.setupTooltips();

                // Bind rows
                $('a.ladb-btn-folding-toggle-row', that.$page).on('click', function () {
                    $(this).blur();
                    var $row = $(this).parents('.ladb-outliner-row');
                    that.toggleFoldingRow($row);
                    return false;
                });

                // Restore button state
                that.$btnList.prop('disabled', false);

                // Stick header
                that.stickSlideHeader(that.$rootSlide);

                // Finish progress feedback
                that.dialog.finishProgress();

                // Callback
                if (typeof callback === 'function') {
                    callback();
                }

            });

        });

    };

    LadbTabOutliner.prototype.toggleFoldingRow = function ($row, dataKey) {
        var $btn = $('.ladb-btn-folding-toggle-row', $row);
        var $i = $('i', $btn);

        if ($i.hasClass('ladb-opencutlist-icon-arrow-down')) {
            this.expandFoldingRow($row, dataKey);
        } else {
            this.collapseFoldingRow($row, dataKey);
        }
    };

    LadbTabOutliner.prototype.expandFoldingRow = function ($row, dataKey) {
        var rowId = $row.data(dataKey ? dataKey : 'folder-id');
        var $btn = $('.ladb-btn-folding-toggle-row', $row);
        var $i = $('i', $btn);

        $i.addClass('ladb-opencutlist-icon-arrow-up');
        $i.removeClass('ladb-opencutlist-icon-arrow-down');

        // Show children
        $row.siblings('tr.folder-' + rowId).removeClass('hide');

    };

    LadbTabOutliner.prototype.collapseFoldingRow = function ($row, dataKey) {
        var rowId = $row.data(dataKey ? dataKey : 'folder-id');
        var $btn = $('.ladb-btn-folding-toggle-row', $row);
        var $i = $('i', $btn);

        $i.addClass('ladb-opencutlist-icon-arrow-down');
        $i.removeClass('ladb-opencutlist-icon-arrow-up');

        // Hide children
        $row.siblings('tr.folder-' + rowId).addClass('hide');

    };

    LadbTabOutliner.prototype.expandAllFoldingRows = function ($slide, dataKey) {
        var that = this;
        $('.ladb-cutlist-row-folder', $slide === undefined ? this.$page : $slide).each(function () {
            that.expandFoldingRow($(this), dataKey);
        });
    };

    LadbTabOutliner.prototype.collapseAllFoldingRows = function ($slide, dataKey) {
        var that = this;
        $('.ladb-cutlist-row-folder', $slide === undefined ? this.$page : $slide).each(function () {
            that.collapseFoldingRow($(this), dataKey);
        });
    };

    // Init ///

    LadbTabOutliner.prototype.bind = function () {
        LadbAbstractTab.prototype.bind.call(this);

        var that = this;

        // Bind buttons
        this.$btnList.on('click', function () {
            that.loadList();
            this.blur();
        });

    };

    LadbTabOutliner.prototype.defaultInitializedCallback = function () {
        LadbAbstractTab.prototype.defaultInitializedCallback.call(this);

        this.loadList();

    };

    // PLUGIN DEFINITION
    // =======================

    function Plugin(option, params) {
        return this.each(function () {
            var $this = $(this);
            var data = $this.data('ladb.tab.plugin');
            var options = $.extend({}, LadbTabOutliner.DEFAULTS, $this.data(), typeof option === 'object' && option);

            if (!data) {
                if (undefined === options.dialog) {
                    throw 'dialog option is mandatory.';
                }
                $this.data('ladb.tab.plugin', (data = new LadbTabOutliner(this, options, options.dialog)));
            }
            if (typeof option === 'string') {
                data[option].apply(data, Array.isArray(params) ? params : [ params ])
            } else {
                data.init(option.initializedCallback);
            }
        })
    }

    var old = $.fn.ladbTabOutliner;

    $.fn.ladbTabOutliner = Plugin;
    $.fn.ladbTabOutliner.Constructor = LadbTabOutliner;


    // NO CONFLICT
    // =================

    $.fn.ladbTabOutliner.noConflict = function () {
        $.fn.ladbTabOutliner = old;
        return this;
    }

}(jQuery);
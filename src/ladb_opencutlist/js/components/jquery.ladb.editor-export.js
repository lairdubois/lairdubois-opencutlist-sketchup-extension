+function ($) {
    'use strict';

    // CLASS DEFINITION
    // ======================

    var LadbEditorExport = function (element, options, dialog) {
        this.options = options;
        this.$element = $(element);
        this.dialog = dialog;

        this.variableDefs = [];

        this.$editingItem = null;
        this.$editingForm = null;
    };

    LadbEditorExport.DEFAULTS = {
        variables: []
    };

    LadbEditorExport.prototype.setColdefs = function (colDefs) {
        var that = this;

        // Cancel editing
        this.editColumn(null);

        // Populate rows
        this.$sortable.empty();
        $.each(colDefs, function (index, colDef) {

            // Append column
            that.appendColumnItem(colDef.name, colDef.header, colDef.formula, colDef.hidden);

        });

        // Bind sorter
        this.$sortable.sortable(SORTABLE_OPTIONS);

    };

    LadbEditorExport.prototype.getColdefs = function () {
        var colDefs = [];
        this.$sortable.children('li').each(function () {
            colDefs.push({
                name: $(this).data('name'),
                header: $(this).data('header'),
                formula: $(this).data('formula'),
                hidden: typeof $(this).data('hidden') == 'boolean' ? $(this).data('hidden') : false
            });
        });
        return colDefs;
    };

    LadbEditorExport.prototype.appendColumnItem = function (name, header, formula, hidden) {
        var that = this;

        // Create and append row
        var $item = $(Twig.twig({ref: "tabs/cutlist/_export-column-item.twig"}).render({
            name: name,
            header: header,
            formula: formula,
            hidden: hidden
        }));
        this.$sortable.append($item);

        // Bind row
        $item.on('click', function () {
            that.editColumn($item);
            return false;
        })

        // Bind buttons
        $('a.ladb-cutlist-export-column-item-formula-btn', $item).on('click', function () {
            that.editColumn($item, 'formula');
            return false;
        });
        $('a.ladb-cutlist-export-column-item-visibility-btn', $item).on('click', function () {
            var $icon = $('i', $(this));
            var hidden = $item.data('hidden');
            if (hidden === true) {
                hidden = false;
                $item.removeClass('ladb-inactive');
                $icon.removeClass('ladb-opencutlist-icon-eye-close');
                $icon.addClass('ladb-opencutlist-icon-eye-open');
            } else {
                hidden = true;
                $item.addClass('ladb-inactive');
                $icon.addClass('ladb-opencutlist-icon-eye-close');
                $icon.removeClass('ladb-opencutlist-icon-eye-open');
            }
            $item.data('hidden', hidden);
            return false;
        });

        return $item;
    };

    LadbEditorExport.prototype.editColumn = function ($item, focus) {
        var that = this;

        // Cleanup
        if (this.$editingForm) {
            this.$editingForm.remove();
        }
        if (this.$btnContainer) {
            this.$btnContainer.empty();
        }
        if (this.$editingItem) {
            this.$editingItem.removeClass('ladb-selected');
        }

        this.$editingItem = $item;
        if ($item) {

            // Mark item as selected
            this.$editingItem.addClass('ladb-selected');

            // Buttons
            var $btnRemove = $('<button class="btn btn-danger"><i class="ladb-opencutlist-icon-clear"></i> ' + i18next.t('tab.cutlist.export.remove_column') + '</button>');
            $btnRemove
                .on('click', function () {
                    that.removeColumn($item);
                })
            ;
            this.$btnContainer.append($btnRemove);

            // Create the form
            this.$editingForm = $(Twig.twig({ref: "tabs/cutlist/_export-column-form.twig"}).render({
                name: $item.data('name'),
                header: $item.data('header'),
                formula: $item.data('formula')
            }));

            var $inputHeader = $('#ladb_input_header', this.$editingForm);
            var $inputFormula = $('#ladb_div_formula', this.$editingForm);

            // Bind inputs
            $inputHeader
                .ladbTextinputText()
                .on('keyup', function () {
                    $item.data('header', $(this).val());

                    // Update item header
                    $('.ladb-cutlist-export-column-item-header', $item).replaceWith(Twig.twig({ref: "tabs/cutlist/_export-column-item-header.twig"}).render({
                        name: $item.data('name'),
                        header: $item.data('header')
                    }))

                })
            ;
            $inputFormula
                .ladbTextinputCode({
                    variableDefs: this.variableDefs
                })
                .on('change', function () {
                    $item.data('formula', $(this).val());
                })
            ;

            this.$element.append(this.$editingForm);

            // Focus
            if (focus === 'formula') {
                $inputFormula.focus();
            } else {
                $inputHeader.focus();
            }

        }

    };

    LadbEditorExport.prototype.removeColumn = function ($item) {

        // Retrieve sibling item if possible
        var $siblingItem = $item.prev();
        if ($siblingItem.length === 0) {
            $siblingItem = $item.next();
            if ($siblingItem.length === 0) {
                $siblingItem = null;
            }
        }

        // Remove column item
        $item.remove();

        // Move editing to sibling item
        this.editColumn($siblingItem);

    };

    LadbEditorExport.prototype.addColumn = function (name) {

        // Create and append item
        var $item = this.appendColumnItem(name);

        // Edit column
        this.editColumn($item);

        // Scroll sortable to bottom
        this.$sortable.animate({ scrollTop: this.$sortable.get(0).scrollHeight }, 200);

    };

    LadbEditorExport.prototype.init = function () {
        var that = this;

        // Generate variableDefs for formula editor
        this.variableDefs = [];
        for (var i = 0; i < this.options.vars.length; i++) {
            this.variableDefs.push({
                text: this.options.vars[i],
                displayText: i18next.t('tab.cutlist.export.' + this.options.vars[i])
            });
        }

        // Build UI

        var $header = $('<div class="ladb-editor-export-header">').append(i18next.t('tab.cutlist.export.columns'))
        this.$sortable = $('<ul class="ladb-editor-export-sortable ladb-sortable-list" />')

        this.$element.append(
            $('<div class="ladb-editor-export-container">')
                .append($header)
                .append(this.$sortable)
        )

        // Buttons

        var $btnAdd = $('<button class="btn btn-default"><i class="ladb-opencutlist-icon-plus"></i> ' + i18next.t('tab.cutlist.export.add_column') + '</button>')
            .on('click', function () {
                that.addColumn('');
            });

        var $dropDown = $('<ul class="dropdown-menu dropdown-menu-right">');
        $dropDown.append(
            $('<li class="dropdown-header">' + i18next.t('tab.cutlist.export.add_native_columns') + '</li>')
        )
        $.each(this.options.vars, function (index, v) {
            $dropDown.append(
                $('<li>')
                    .append(
                        $('<a href="#">' + i18next.t('tab.cutlist.export.' + v) + '</a>')
                            .on('click', function () {
                                that.addColumn(v);
                            })
                    )
            )
        });

        var $btnGroup = $('<div class="btn-group">')
            .append($btnAdd)
            .append($('<button type="button" class="btn btn-default dropdown-toggle" data-toggle="dropdown"><span class="caret"></span></button>'))
            .append($dropDown)

        var $btnContainer = $('<div style="display: inline-block" />');

        this.$element.append(
            $('<div class="ladb-editor-export-buttons" style="margin: 10px;"></div>')
                .append($btnGroup)
                .append('&nbsp;')
                .append($btnContainer)
        );

        this.$btnContainer = $btnContainer;

    };

    // PLUGIN DEFINITION
    // =======================

    function Plugin(option, params) {
        var value;
        var elements = this.each(function () {
            var $this = $(this);
            var data = $this.data('ladb.editorExport');
            var options = $.extend({}, LadbEditorExport.DEFAULTS, $this.data(), typeof option === 'object' && option);

            if (!data) {
                $this.data('ladb.editorExport', (data = new LadbEditorExport(this, options, options.dialog)));
            }
            if (typeof option === 'string') {
                value = data[option].apply(data, Array.isArray(params) ? params : [ params ])
            } else {
                data.init(params);
            }
        });
        return typeof value !== 'undefined' ? value : elements;
    }

    var old = $.fn.ladbEditorExport;

    $.fn.ladbEditorExport = Plugin;
    $.fn.ladbEditorExport.Constructor = LadbEditorExport;


    // NO CONFLICT
    // =================

    $.fn.ladbEditorExport.noConflict = function () {
        $.fn.ladbEditorExport = old;
        return this;
    }

}(jQuery);
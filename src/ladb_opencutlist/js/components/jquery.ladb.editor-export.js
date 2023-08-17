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
        vars: [],
        snippetDefs: []
    };

    LadbEditorExport.prototype.setColDefs = function (colDefs) {
        var that = this;

        // Cancel editing
        this.editColumn(null);

        // Populate rows
        this.$sortable.empty();
        $.each(colDefs, function (index, colDef) {

            // Append column
            that.appendColumnItem(false, colDef.name, colDef.title, colDef.formula, colDef.align, colDef.hidden);

        });

    };

    LadbEditorExport.prototype.getColDefs = function () {
        var colDefs = [];
        this.$sortable.children('li').each(function () {
            colDefs.push({
                name: $(this).data('name'),
                title: $(this).data('title'),
                formula: $(this).data('formula'),
                align: $(this).data('align'),
                hidden: $(this).data('hidden')
            });
        });
        return colDefs;
    };

    LadbEditorExport.prototype.setEditingItemIndex = function (index) {
        var $item = $(this.$sortable.children().get(index));
        if ($item.length) {
            this.editColumn($item);
        }
    }

    LadbEditorExport.prototype.getEditingItemIndex = function () {
        return this.$editingItem ? this.$editingItem.index() : null;
    }

    LadbEditorExport.prototype.appendColumnItem = function (appendAfterEditingItem, name, title, formula, align, hidden) {
        var that = this;

        // Create and append row
        var $item = $(Twig.twig({ref: "components/_editor-export-column-item.twig"}).render({
            name: name || '',
            title: title || '',
            formula: formula || '',
            align: align || 'left',
            hidden: hidden || false
        }));
        if (appendAfterEditingItem && this.$editingItem) {
            this.$editingItem.after($item);
        } else {
            this.$sortable.append($item);
        }

        // Bind row
        $item.on('click', function () {
            that.editColumn($item);
            return false;
        })

        // Bind buttons
        $('a.ladb-editor-export-column-item-formula-btn', $item).on('click', function () {
            that.editColumn($item, 'formula');
            return false;
        });
        $('a.ladb-editor-export-column-item-align-btn', $item).on('click', function () {
            var $icon = $('i', $(this));
            var align = $item.data('align');
            $icon.removeClass('ladb-opencutlist-icon-align-' + align);
            switch (align) {
                case 'left':
                    align = 'center';
                    break;
                case 'center':
                    align = 'right';
                    break;
                case 'right':
                    align = 'left';
                    break;
            }
            $item.data('align', align);
            $icon.addClass('ladb-opencutlist-icon-align-' + align);
            return false;
        });
        $('a.ladb-editor-export-column-item-visibility-btn', $item).on('click', function () {
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

    LadbEditorExport.prototype.editColumn = function ($item, focusTo) {
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

            if (this.$btnRemoveAll) {
                this.$btnRemoveAll.hide();
            }

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
            this.$editingForm = $(Twig.twig({ref: "components/_editor-export-column-form.twig"}).render({
                name: $item.data('name'),
                title: $item.data('title'),
                formula: $item.data('formula')
            }));
            this.$element.append(this.$editingForm);

            var $inputHeader = $('#ladb_input_title', this.$editingForm);
            var $inputFormula = $('#ladb_textarea_formula', this.$editingForm);

            // Bind inputs
            $inputHeader
                .ladbTextinputText()
                .on('keyup', function () {
                    $item.data('title', $(this).val());

                    // Update item title
                    $('.ladb-editor-export-column-item-title', $item).replaceWith(Twig.twig({ref: "components/_editor-export-column-item-title.twig"}).render({
                        name: $item.data('name'),
                        title: $item.data('title')
                    }));

                })
            ;
            $inputFormula
                .ladbTextinputCode({
                    variableDefs: this.variableDefs,
                    snippetDefs: this.options.snippetDefs
                })
                .on('change', function () {
                    $item.data('formula', $(this).val());

                    // Update item formula button
                    if ($(this).val() === '') {
                        $('.ladb-editor-export-column-item-formula-btn', $item).removeClass('ladb-active');
                    } else {
                        $('.ladb-editor-export-column-item-formula-btn', $item).addClass('ladb-active');
                    }

                })
            ;

            // Focus
            if (focusTo === 'formula') {
                $inputFormula.ladbTextinputCode('focus');
            } else {
                $inputHeader.ladbTextinputText('focus');
            }

            // Scroll to item
            if ($item.position().top < 0) {
                this.$sortable.animate({ scrollTop: this.$sortable.scrollTop() + $item.position().top }, 200);
            } else if ($item.position().top + $item.outerHeight() > this.$sortable.outerHeight(true)) {
                this.$sortable.animate({ scrollTop: this.$sortable.scrollTop() + $item.position().top + $item.outerHeight(true) - this.$sortable.outerHeight() }, 200);
            }

            if (this.$helpBlock) {
                this.$helpBlock.hide();
            }

            this.dialog.setupTooltips(this.$editingForm);
            this.dialog.setupPopovers(this.$editingForm);

        } else {

            if (this.$helpBlock) {
                this.$helpBlock.show();
            }

            if (this.$btnRemoveAll) {
                this.$btnRemoveAll.show();
            }

        }

    };

    LadbEditorExport.prototype.removeColumn = function ($item) {

        // Retrieve sibling item if possible
        var $siblingItem = $item.next();
        if ($siblingItem.length === 0) {
            $siblingItem = $item.prev();
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
        var $item = this.appendColumnItem(true, name);

        // Edit column
        this.editColumn($item);

    };

    LadbEditorExport.prototype.init = function () {
        var that = this;

        // Generate variableDefs for formula editor
        this.variableDefs = [];
        for (var i = 0; i < this.options.vars.length; i++) {
            this.variableDefs.push({
                text: this.options.vars[i].name,
                displayText: i18next.t('tab.cutlist.export.' + this.options.vars[i].name),
                type: this.options.vars[i].type
            });
        }

        // Build UI

        this.$element.addClass('row');

        var $header = $('<div class="ladb-editor-export-columns-header">' + i18next.t('tab.cutlist.export.columns') + '</div>')
            .on('click', function (e) {
                that.editColumn(null);
            });
        this.$sortable = $('<ul class="ladb-editor-export-columns-sortable ladb-sortable-list" />')
            .sortable(SORTABLE_OPTIONS)
        ;

        this.$element.append(
            $('<div class="col-xs-10 col-xs-push-1">').append(
                $('<div class="ladb-editor-export-columns">')
                    .append($header)
                    .append(this.$sortable)
            )
        );

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
                        $('<a href="#">' + i18next.t('tab.cutlist.export.' + v.name) + '</a>')
                            .on('click', function () {
                                that.addColumn(v.name);
                            })
                    )
            )
        });

        var $btnGroup = $('<div class="btn-group">')
            .append($btnAdd)
            .append($('<button type="button" class="btn btn-default dropdown-toggle" data-toggle="dropdown"><span class="caret"></span></button>'))
            .append($dropDown)

        var $btnRemoveAll = $('<button class="btn btn-danger"><i class="ladb-opencutlist-icon-clear"></i> ' + i18next.t('tab.cutlist.export.remove_all_columns') + '</button>')
            .on('click', function () {
                $(this).blur();
                that.$sortable.empty();
                that.editColumn(null);
                return false;
            });

        var $btnContainer = $('<div style="display: inline-block" />');

        this.$element.append(
            $('<div class="col-xs-10 col-xs-push-1">').append(
                $('<div class="ladb-editor-export-buttons" style="margin: 10px;"></div>')
                    .append($btnGroup)
                    .append('&nbsp;')
                    .append($btnRemoveAll)
                    .append($btnContainer)
            )
        );

        this.$btnContainer = $btnContainer;
        this.$btnRemoveAll = $btnRemoveAll;

        // Help

        this.$helpBlock = $('<div class="col-xs-10 col-xs-push-1"><p class="help-block text-center"><small>' + i18next.t('tab.cutlist.export.customize_help') + '</small></p></div>');
        this.$element.append(this.$helpBlock);

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
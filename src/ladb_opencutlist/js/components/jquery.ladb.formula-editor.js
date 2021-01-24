+function ($) {
    'use strict';

    // CLASS DEFINITION
    // ======================

    var LadbFormulaEditor = function (element, options) {
        this.options = options;
        this.$element = $(element);

    };

    LadbFormulaEditor.DEFAULTS = {
        wordDefs: []
    };

    LadbFormulaEditor.prototype.tagFromWordDef = function (wordDef) {
        return "<div class='" + wordDef.class + "' contenteditable='false' data-value='" + wordDef.value + "'><span>" + wordDef.label + "</span></div>";
    }

    LadbFormulaEditor.prototype.setFormula = function (formula) {
        if (formula.length > 0) {
            for (var i = 0; i < this.options.wordDefs.length; i++) {
                var wordDef = this.options.wordDefs[i];
                var re = new RegExp('(?:\\b)(' + wordDef.value + ')(?:\\b)', 'g');
                formula = formula.replace(re, this.tagFromWordDef(wordDef));
            }
            formula = '<span></span>' + formula + '<span></span>';
        }
        this.$element
            .empty()
            .html(formula)
        ;
    };

    LadbFormulaEditor.prototype.getFormula = function () {

        var fnExplore = function(element, words) {
            if (element.nodeType === 1 /* ELEMENT_NODE */) {
                var $element = $(element);
                if ($element.data('value')) {
                    words.push($element.data('value'));
                } else {
                    $element.contents().each(function () {
                        fnExplore(this, words);
                    });
                }
            } else if (element.nodeType === 3 /* TEXT_NODE */) {
                words.push(element.data.trim());
            }
            return words;
        };

        var words = fnExplore(this.$element.get(0), []);
        return words.join(' ').trim();
    };

    LadbFormulaEditor.prototype.bind = function () {
        var that = this;

        var tribute = new Tribute({
            autocompleteMode: true,
            noMatchTemplate: "",
            values: that.options.wordDefs,
            allowSpaces: false,
            replaceTextSuffix: '<span></span>',
            lookup: 'label',
            selectTemplate: function(item) {
                if (typeof item === "undefined") return null;
                if (this.range.isContentEditable(this.current.element)) {
                    return that.tagFromWordDef(item.original);
                }
                return item.original.value;
            },
            menuItemTemplate: function(item) {
                return item.string;
            }
        });
        tribute.attach(this.$element.get( 0 ));

    };

    LadbFormulaEditor.prototype.init = function () {
        this.bind();
    };

    // PLUGIN DEFINITION
    // =======================

    function Plugin(option, params) {
        var value;
        var elements = this.each(function () {
            var $this = $(this);
            var data = $this.data('ladb.formulaeditor');
            var options = $.extend({}, LadbFormulaEditor.DEFAULTS, $this.data(), typeof option == 'object' && option);

            if (!data) {
                $this.data('ladb.formulaeditor', (data = new LadbFormulaEditor(this, options, options.dialog)));
            }
            if (typeof option == 'string') {
                value = data[option].apply(data, Array.isArray(params) ? params : [ params ])
            } else {
                data.init();
            }
        });
        return typeof value !== 'undefined' ? value : elements;
    }

    var old = $.fn.ladbFormulaEditor;

    $.fn.ladbFormulaEditor = Plugin;
    $.fn.ladbFormulaEditor.Constructor = LadbFormulaEditor;


    // NO CONFLICT
    // =================

    $.fn.ladbFormulaEditor.noConflict = function () {
        $.fn.ladbFormulaEditor = old;
        return this;
    }

}(jQuery);
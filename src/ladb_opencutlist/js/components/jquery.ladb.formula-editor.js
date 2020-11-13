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
        return "<span class='" + wordDef.class + "' contenteditable='false' data-value='" + wordDef.value + "'>" + wordDef.label + "</span>";
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

        this.$element.textcomplete([
            {
                match: /(^|\b)(\w{1,}|&])$/,
                search: function (term, callback) {
                    callback($.map(that.options.wordDefs, function (wordDef) {
                        return wordDef.label.toLowerCase().indexOf(term.toLowerCase()) === 0 ? wordDef : null;
                    }));
                },
                template: function (wordDef) {
                    return wordDef.label;
                },
                replace: function (wordDef) {
                    return that.tagFromWordDef(wordDef);
                },
            }
        ], {
            adapter: $.fn.textcomplete.HTMLContentEditable
        });
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
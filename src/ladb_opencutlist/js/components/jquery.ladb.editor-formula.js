+function ($) {
    'use strict';

    // CLASS DEFINITION
    // ======================

    var LadbEditorFormula = function (element, options) {
        this.options = options;
        this.$element = $(element);

    };

    LadbEditorFormula.DEFAULTS = {
        wordDefs: []
    };

    LadbEditorFormula.prototype.tagFromWordDef = function (wordDef) {
        return "<div class='" + wordDef.class + "' contenteditable='false' data-value='" + wordDef.value + "'><span>" + wordDef.label + "</span></div>";
    }

    LadbEditorFormula.prototype.setFormula = function (formula) {
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

    LadbEditorFormula.prototype.getFormula = function () {

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

    LadbEditorFormula.prototype.bind = function () {
        var that = this;

        var tribute = new Tribute({
            autocompleteMode: true,
            noMatchTemplate: "",
            values: that.options.wordDefs,
            allowSpaces: false,
            replaceTextSuffix: '<span></span>',
            lookup: 'label',
            selectTemplate: function(item) {
                if (typeof item === 'undefined') return null;
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

    LadbEditorFormula.prototype.init = function () {
        this.bind();
    };

    // PLUGIN DEFINITION
    // =======================

    function Plugin(option, params) {
        var value;
        var elements = this.each(function () {
            var $this = $(this);
            var data = $this.data('ladb.formulaeditor');
            var options = $.extend({}, LadbEditorFormula.DEFAULTS, $this.data(), typeof option === 'object' && option);

            if (!data) {
                $this.data('ladb.formulaeditor', (data = new LadbEditorFormula(this, options, options.dialog)));
            }
            if (typeof option === 'string') {
                value = data[option].apply(data, Array.isArray(params) ? params : [ params ])
            } else {
                data.init();
            }
        });
        return typeof value !== 'undefined' ? value : elements;
    }

    var old = $.fn.ladbEditorFormula;

    $.fn.ladbEditorFormula = Plugin;
    $.fn.ladbEditorFormula.Constructor = LadbEditorFormula;


    // NO CONFLICT
    // =================

    $.fn.ladbEditorFormula.noConflict = function () {
        $.fn.ladbEditorFormula = old;
        return this;
    }

}(jQuery);
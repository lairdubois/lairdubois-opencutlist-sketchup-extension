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


    LadbFormulaEditor.prototype.getFormula = function () {
        var formula = '';
        this.$element.children().each(function () {
            var value = $(this).data('value');
            if (value) {
                formula += value;
            } else {
                formula += $(this).html().replace(/&nbsp;/, ' ').trim();
            }
        });
        return formula;
    };

    LadbFormulaEditor.prototype.bind = function () {
        var that = this;

        this.$element.textcomplete([
            {
                match: /(^|\b)(\w{1,}|[+\-*/%^|&])$/,
                search: function (term, callback) {
                    callback($.map(that.options.wordDefs, function (wordDef) {
                        return wordDef.label.toLowerCase().indexOf(term.toLowerCase()) === 0 ? wordDef : null;
                    }));
                },
                template: function (wordDef) {
                    return wordDef.label;
                },
                replace: function (wordDef) {
                    return "<span class='" + wordDef.class + "' contenteditable='false' data-value='" + wordDef.value + "'>" + wordDef.label + "</span>";
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
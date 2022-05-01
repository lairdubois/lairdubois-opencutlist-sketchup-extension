+function ($) {
    'use strict';

    var HINT_TYPE_KEYWORD = 1;
    var HINT_TYPE_VARIABLE = 2;

    // CLASS DEFINITION
    // ======================

    var LadbTextinputFormula = function(element, options) {
        LadbTextinputAbstract.call(this, element, options);
    };
    LadbTextinputFormula.prototype = new LadbTextinputAbstract;

    LadbTextinputFormula.DEFAULTS = {
        resetValue: '',
        keywordDefs: [],
        variableDefs: []
    };

    LadbTextinputFormula.prototype.reset = function () {
        LadbTextinputAbstract.prototype.reset.call(this);
        this.cm.setValue(this.$element.val());
        this.cm.refresh();
    };

    LadbTextinputFormula.prototype.init = function() {
        LadbTextinputAbstract.prototype.init.call(this);

        var that = this;

        /////

        var hints = [];

        var variables = [];
        for (let variableDef of this.options.variableDefs) {
            variables.push(variableDef.text);
            hints.push({
                type: HINT_TYPE_VARIABLE,
                text: variableDef.text,
                displayText: variableDef.displayText,
                className: 'CodeMirror-hint-variable'
            });
        }

        var keywords = [];
        for (let keywordDef of this.options.keywordDefs) {
            keywords.push(keywordDef.text);
            hints.push({
                type: HINT_TYPE_KEYWORD,
                text: keywordDef.text,
                displayText: keywordDef.displayText,
                className: 'CodeMirror-hint-keyword'
            });
        }

        /////

        var fnRefreshVariableMarks = function (cm, from, to) {
            if (from === undefined) {
                from = { line: 0, ch: 0 }
            }
            if (to === undefined) {
                to = { line: cm.lineCount() + 1, ch: 0 }
            }
            for (let lineNumber = from.line; lineNumber <= to.line; lineNumber++) {

                // Clear variable marks
                let marks = cm.findMarks(
                    { line: lineNumber, ch: 0},
                    { line: lineNumber + 1, ch: 0}
                );
                for (let mark of marks) {
                    if (mark.attributes === 'variable') {
                        mark.clear();
                    }
                }

                // Regenerate line marks
                let tokens = cm.getLineTokens(lineNumber);
                for (let token of tokens) {
                    if (token.type === 'variable-2') {
                        let displayText = null;
                        for (let variableDef of that.options.variableDefs) {
                            if (token.string === ('@' + variableDef.text)) {
                                displayText = variableDef.displayText;
                                break;
                            }
                        }
                        if (displayText) {
                            cm.markText(
                                { line: lineNumber, ch: token.start },
                                { line: lineNumber, ch: token.end },
                                {
                                    atomic: true,
                                    replacedWith: $('<span class="cm-variable">' + displayText + '</span>').get(0),
                                    handleMouseEvents: true,
                                    attributes: 'variable'
                                }
                            )
                        }

                    }
                }

            }        }

        /////

        CodeMirror.registerHelper('hint', 'opencutlist', function(cm) {
            var cur = cm.getCursor();
            var curLine = cm.getLine(cur.line);
            var start = cur.ch;
            var end = start;
            while (end < curLine.length && /[\w$]/.test(curLine.charAt(end))) ++end;
            while (start && /[\w$]/.test(curLine.charAt(start - 1))) --start;
            var curWord = start !== end && curLine.slice(start, end);
            var regExp = new RegExp(curWord, 'i');
            return {
                list: (!curWord ? hints : hints.filter(function(hint) {
                    return hint.displayText.match(regExp);
                })).sort(),
                from: CodeMirror.Pos(cur.line, start),
                to: CodeMirror.Pos(cur.line, end)
            }
        });

        CodeMirror.commands.autocomplete = function (cm) {
            CodeMirror.showHint(cm, CodeMirror.hint.opencutlist);
        };

        // CodeMirror.defineSimpleMode("dentaku", {
        //     // The start state contains the rules that are initially used
        //     start: [
        //         // The regex matches the token, the token property contains the type
        //         { regex: /"(?:[^\\]|\\.)*?(?:"|$)/, token: "string" },
        //         // Rules are matched in the order in which they appear, so there is
        //         // no ambiguity between this one and the one above
        //         { regex: new RegExp('(?:' + keywords.join('|') + ')\\b', 'i'), token: "keyword" },
        //         { regex: /true|false/, token: "atom" },
        //         { regex: /0x[a-f\d]+|[-+]?(?:\.\d+|\d+\.?\d*)(?:e[-+]?\d+)?/i,  token: "number" },
        //         // A next property will cause the mode to move to a different state
        //         { regex: /\/\*/, token: "comment", next: "comment"},
        //         { regex: /[-+\/*=<>!]+/, token: "operator" },
        //         { regex: new RegExp('(?:' + variables.join('|') + ')\\b', 'i'), token: "variable" },
        //     ],
        //     // The multi-line comment state.
        //     comment: [
        //         { regex: /.*?\*\//, token: "comment", next: "start" },
        //         { regex: /.*/, token: "comment"}
        //     ],
        //     // The meta property contains global information about the mode. It
        //     // can contain properties like lineComment, which are supported by
        //     // all modes, and also directives like dontIndentStates, which are
        //     // specific to simple modes.
        //     meta: {
        //         dontIndentStates: ["comment"]
        //     }
        // });

        this.cm = CodeMirror.fromTextArea(this.$element.get(0), {
            mode: 'ruby',
            indentUnit: 2,
            tabSize: 2,
            lineWrapping: true,
            lineNumbers: false,
            autoRefresh: true,
            autoCloseBrackets: true,
            matchBrackets: true,
            extraKeys: {
                "Ctrl-Space": "autocomplete"
            },
        });
        this.cm.on('change', function (cm, change) {

            // Try to autocomplete if inserted char is @
            if (change.text[0] === '@') {
                CodeMirror.showHint(cm, CodeMirror.hint.opencutlist);
            }

            fnRefreshVariableMarks(cm, change.from, change.to);

            // Keep textarea up to date
            that.$element
                .val(cm.getValue())
                .trigger('change')
            ;
        });

        fnRefreshVariableMarks(this.cm);

    };


    // PLUGIN DEFINITION
    // =======================

    function Plugin(option, params) {
        var value;
        var elements = this.each(function () {
            var $this = $(this);
            var data = $this.data('ladb.textinputFormula');
            var options = $.extend({}, LadbTextinputFormula.DEFAULTS, $this.data(), typeof option === 'object' && option);

            if (!data) {
                $this.data('ladb.textinputFormula', (data = new LadbTextinputFormula(this, options)));
            }
            if (typeof option === 'string') {
                value = data[option].apply(data, Array.isArray(params) ? params : [ params ])
            } else {
                data.init();
            }
        });
        return typeof value !== 'undefined' ? value : elements;
    }

    var old = $.fn.ladbTextinputFormula;

    $.fn.ladbTextinputFormula             = Plugin;
    $.fn.ladbTextinputFormula.Constructor = LadbTextinputFormula;


    // NO CONFLICT
    // =================

    $.fn.ladbTextinputFormula.noConflict = function () {
        $.fn.ladbTextinputFormula = old;
        return this;
    }

}(jQuery);
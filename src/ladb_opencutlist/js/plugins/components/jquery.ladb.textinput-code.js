+function ($) {
    'use strict';

    // CLASS DEFINITION
    // ======================

    const LadbTextinputCode = function(element, options) {
        LadbTextinputAbstract.call(this, element, options);
    };
    LadbTextinputCode.prototype = new LadbTextinputAbstract;

    LadbTextinputCode.DEFAULTS = $.extend({
        variableDefs: [],
        snippetDefs: []
    }, LadbTextinputAbstract.DEFAULTS);

    LadbTextinputCode.prototype.focus = function () {
        this.cm.focus();
    };

    LadbTextinputCode.prototype.reset = function () {
        LadbTextinputAbstract.prototype.reset.call(this);
        this.cm.setValue(this.$element.val());
        this.cm.refresh();
    };

    LadbTextinputCode.prototype.val = function (value) {
        if (this.cm) {
            this.cm.setValue(value);
            this.cm.refresh();
        }
        return LadbTextinputAbstract.prototype.val.call(this, value);
    };

    LadbTextinputCode.prototype.createLeftToolsContainer = function ($toolContainer) {
        // Do not create the left tools container
    };

    LadbTextinputCode.prototype.appendRightTools = function ($toolsContainer) {
        const that = this;

        if (this.options.snippetDefs && this.options.snippetDefs.length > 0) {

            const $snippetDropdownBtn = $('<div data-toggle="dropdown">')
                .append('<i class="ladb-opencutlist-icon-snippets">')
            ;
            const $snippetDropdown = $('<ul class="dropdown-menu dropdown-menu-right">');

            for (let i = 0; i < this.options.snippetDefs.length; i++) {
                let snippetDef = that.options.snippetDefs[i];
                if (snippetDef.name === '-') {
                    $snippetDropdown
                        .append($('<li role="separator" class="divider">'))
                    ;
                } else {
                    $snippetDropdown
                        .append($('<li>')
                            .append($('<a href="#">')
                                .on('click', function () {
                                    that.val(snippetDef.value);
                                    $(this).blur();
                                    that.focus();
                                })
                                .append(snippetDef.name)
                            )
                        )
                    ;
                }
            }

            const $snippetBtn = $('<div class="ladb-textinput-tool ladb-textinput-tool-btn dropdown" tabindex="-1" data-toggle="tooltip" title="' + i18next.t('core.component.textinput_code.snippets') + '">')
                .append($snippetDropdownBtn)
                .append($snippetDropdown)
            ;
            $toolsContainer.append($snippetBtn);

        }

        LadbTextinputAbstract.prototype.appendRightTools.call(this, $toolsContainer);
    };

    LadbTextinputCode.prototype.init = function() {
        LadbTextinputAbstract.prototype.init.call(this);

        const that = this;

        /////

        const fnRefreshVariableMarks = function (cm, from, to) {
            if (from === undefined) {
                from = { line: 0, ch: 0 }
            }
            if (to === undefined) {
                to = { line: cm.lineCount() + 1, ch: 0 }
            }
            for (let lineNumber = from.line; lineNumber <= to.line; lineNumber++) {

                // Clear variable marks
                let marks = cm.findMarks(
                    CodeMirror.Pos(lineNumber, 0),
                    CodeMirror.Pos(lineNumber + 1, 0)
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
                                CodeMirror.Pos(lineNumber, token.start),
                                CodeMirror.Pos(lineNumber, token.end),
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

            }
        }

        /////

        const hints = [];
        for (let variableDef of this.options.variableDefs) {
            hints.push({
                text: variableDef.text,
                displayText: variableDef.displayText,
                normalizedText: variableDef.displayText.normalize('NFD').replace(/[\u0300-\u036f]/g, ''),
                className: 'CodeMirror-hint-' + variableDef.type
            });
        }

        CodeMirror.registerHelper('hint', 'opencutlist', function(cm) {
            const cur = cm.getCursor();
            const curLine = cm.getLine(cur.line);
            let start = cur.ch;
            let end = start;
            while (end < curLine.length && /[A-Za-zÀ-ÖØ-öø-ÿ]/.test(curLine.charAt(end))) ++end;
            while (start && /[A-Za-zÀ-ÖØ-öø-ÿ]/.test(curLine.charAt(start - 1))) --start;
            const curWord = start !== end && curLine.slice(start, end).normalize('NFD').replace(/[\u0300-\u036f]/g, '');
            const regExp = new RegExp(curWord, 'i');
            return {
                list: (!curWord ? hints : hints.filter(function(hint) {
                    return hint.normalizedText.match(regExp);
                })).sort(),
                from: CodeMirror.Pos(cur.line, start),
                to: CodeMirror.Pos(cur.line, end)
            }
        });

        CodeMirror.commands.autocomplete = function (cm) {
            CodeMirror.showHint(cm, CodeMirror.hint.ruby);
        };

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

            // Refresh marks
            fnRefreshVariableMarks(cm, change.from, change.to);

            // Keep the textarea up to date
            that.$element
                .val(cm.getValue())
                .trigger('change')
            ;

        });
        this.cm.on('focus', function () {
           that.$helpBlock.show();
        });
        this.cm.on('blur', function () {
            that.$helpBlock.hide();
        });

        fnRefreshVariableMarks(this.cm);

        // Append help block
        this.$helpBlock = $('<div class="ladb-textinput-code-help">' + i18next.t('core.component.textinput_code.help') + '</div>');
        this.$helpBlock.hide();
        this.$wrapper.append(this.$helpBlock);

    };


    // PLUGIN DEFINITION
    // =======================

    function Plugin(option, params) {
        let value;
        const elements = this.each(function () {
            const $this = $(this);
            let data = $this.data('ladb.textinputCode');
            if (!data) {
                const options = $.extend({}, LadbTextinputCode.DEFAULTS, $this.data(), typeof option === 'object' && option);
                $this.data('ladb.textinputCode', (data = new LadbTextinputCode(this, options)));
            }
            if (typeof option === 'string') {
                value = data[option].apply(data, Array.isArray(params) ? params : [ params ])
            } else {
                data.init();
            }
        });
        return typeof value !== 'undefined' ? value : elements;
    }

    const old = $.fn.ladbTextinputCode;

    $.fn.ladbTextinputCode             = Plugin;
    $.fn.ladbTextinputCode.Constructor = LadbTextinputCode;


    // NO CONFLICT
    // =================

    $.fn.ladbTextinputCode.noConflict = function () {
        $.fn.ladbTextinputCode = old;
        return this;
    }

}(jQuery);
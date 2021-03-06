'use strict';

// CLASS DEFINITION
// ======================

var LadbTextinputAbstract = function (element, options, resetValue, inputRegex) {
    this.options = options;
    this.$element = $(element);

    this.resetValue = resetValue;
    this.inputRegex = inputRegex;

    this.$resetBtn = null;
};

LadbTextinputAbstract.DEFAULTS = {};

LadbTextinputAbstract.prototype.disable = function () {
    this.$element.prop('disabled', true);
    this.$resetBtn.hide();
};

LadbTextinputAbstract.prototype.enable = function () {
    this.$element.prop('disabled', false);
    this.$resetBtn.show();
};

LadbTextinputAbstract.prototype.reset = function () {
    this.$element
        .val(this.resetValue)
        .trigger('change')
    ;
};

LadbTextinputAbstract.prototype.val = function (value) {
    return this.$element.val(value);
};

/////

LadbTextinputAbstract.prototype.createLeftToolsContainer = function () {
    var $toolsContainer = $('<div class="ladb-textinput-tools ladb-textinput-tools-left" />');
    this.appendLeftTools($toolsContainer);
    this.$inputWrapper
        .before($toolsContainer)
    ;
};

LadbTextinputAbstract.prototype.appendLeftTools = function ($toolsContainer) {
};

LadbTextinputAbstract.prototype.createRightToolsContainer = function () {
    var $toolsContainer = $('<div class="ladb-textinput-tools ladb-textinput-tools-right" />');
    this.appendRightTools($toolsContainer);
    this.$inputWrapper
        .after($toolsContainer)
    ;
};

LadbTextinputAbstract.prototype.appendRightTools = function ($toolsContainer) {
    var that = this;

    var $resetBtn =
        $('<div class="ladb-textinput-tool ladb-btn-reset" tabindex="-1"><i class="ladb-opencutlist-icon-clear"></i></div>')
            .on('click', function() {
                that.reset();
                $(this).blur();
            })
    ;
    $toolsContainer.append($resetBtn);

    this.$resetBtn = $resetBtn;
};

LadbTextinputAbstract.prototype.init = function () {
    var that = this;

    this.$element
        .wrap('<div class="ladb-textinput-input" />')
    ;
    this.$inputWrapper = this.$element.parent();

    this.$inputWrapper
        .wrap('<div class="ladb-textinput" />')
    ;
    this.$wrapper = this.$inputWrapper.parent();

    this.createLeftToolsContainer();
    this.createRightToolsContainer();

    var value = this.$element.val();
    if (value) {
        this.val(value);
    }

    if (this.inputRegex) {

        // Apply regex on input values
        ['input', 'keydown', 'keyup', 'mousedown', 'mouseup', 'select', 'contextmenu', 'drop'].forEach(function (event) {
            that.$element[0].addEventListener(event, function () {
                if (that.inputRegex.test(this.value)) {
                    this.oldValue = this.value;
                    this.oldSelectionStart = this.selectionStart;
                    this.oldSelectionEnd = this.selectionEnd;
                } else if (this.hasOwnProperty('oldValue')) {
                    this.value = this.oldValue;
                    this.setSelectionRange(this.oldSelectionStart, this.oldSelectionEnd);
                } else {
                    this.value = '';
                }
            });
        });

    }

};

'use strict';

// CLASS DEFINITION
// ======================

var LadbTextinputAbstract = function (element, options, resetValue) {
    this.options = options;
    this.$element = $(element);

    this.resetValue = resetValue;

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
    this.$element.val(this.resetValue);
};

LadbTextinputAbstract.prototype.init = function () {
    var that = this;

    var $resetBtn = $('<div class="ladb-btn-reset"><i class="ladb-opencutlist-icon-clear"></i></div>');
    $resetBtn.on('click', function() {
        that.reset();
        that.$element.trigger('change');
    });
    this.$element
        .wrap('<div class="input-group ladb-textinput" />')
        .after($resetBtn)
    ;
    this.$resetBtn = $resetBtn;

};

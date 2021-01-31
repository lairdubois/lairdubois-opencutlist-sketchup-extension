'use strict';

// CLASS DEFINITION
// ======================

var LadbAbstractSimpleTextinput = function (element, options, resetValue) {
    this.options = options;
    this.$element = $(element);

    this.resetValue = resetValue;

    this.$resetBtn = null;
};

LadbAbstractSimpleTextinput.DEFAULTS = {};

LadbAbstractSimpleTextinput.prototype.disable = function () {
    this.$element.prop('disabled', true);
    this.$resetBtn.hide();
};

LadbAbstractSimpleTextinput.prototype.enable = function () {
    this.$element.prop('disabled', false);
    this.$resetBtn.show();
};

LadbAbstractSimpleTextinput.prototype.reset = function () {
    this.$element.val(this.resetValue);
};

LadbAbstractSimpleTextinput.prototype.init = function () {
    var that = this;

    var $resetBtn = $('<div class="ladb-btn-reset"><i class="ladb-opencutlist-icon-clear"></i></div>');
    $resetBtn.on('click', function() {
        that.reset();
        that.$element.trigger('change');
    });
    this.$element
        .wrap('<div class="input-group ladb-simple-textinput" />')
        .after($resetBtn)
    ;
    this.$resetBtn = $resetBtn;

};

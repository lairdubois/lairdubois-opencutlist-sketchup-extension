'use strict';

// CLASS DEFINITION
// ======================

var LadbAbstractSimpleTextinput = function (element, options, resetValue) {
    this.options = options;
    this.$element = $(element);

    this.resetValue = resetValue;
};

LadbAbstractSimpleTextinput.DEFAULTS = {};

LadbAbstractSimpleTextinput.prototype.reset = function () {
    this.$element.val(this.resetValue);
};

LadbAbstractSimpleTextinput.prototype.init = function () {
    var that = this;

    var $resetButton = $('<div class="ladb-btn-reset"><i class="ladb-opencutlist-icon-clear"></i></div>');
    $resetButton.on('click', function() {
        that.reset();
        that.$element.trigger('change');
    });
    this.$element
        .wrap('<div class="input-group ladb-simple-textinput" />')
        .after($resetButton)
    ;

};

'use strict';

function LadbAbstractModal(element, options, dialog) {
    this.options = options;
    this.$element = $(element);
    this.dialog = dialog;

    this._$modal = null;

}

// Init /////

LadbAbstractModal.prototype.bind = function () {
    const that = this;

    // Bind buttons
    $('[data-dismiss="modal"]', this.$element).on('click', function () {
        that.dialog.hide();
    });

};

LadbAbstractModal.prototype.init = function () {

    // Bind element
    this.bind();

    // Setup tooltips and popovers
    this.dialog.setupTooltips(this.$element);
    this.dialog.setupPopovers(this.$element);

};

// Modal /////

LadbAbstractModal.prototype.appendModalInside = function (id, twigFile, renderParams) {
    const that = this;

    // Hide previously opened modal
    if (this._$modal) {
        this._$modal.modal('hide');
    }

    // Create modal element
    this._$modal = $(Twig.twig({ref: twigFile}).render(renderParams));

    // Add modal extra classes
    this._$modal.addClass('modal-inside');

    // Bind modal
    this._$modal.on('shown.bs.modal', function () {
        $('body > .modal-backdrop').first().appendTo(that.$element);
        $('body')
            .removeClass('modal-open')
            .css('padding-right', 0);
        that.$element.addClass('modal-open');
        $('input[autofocus]', that._$modal).first().focus();
    });
    this._$modal.on('hidden.bs.modal', function () {
        $(this)
            .data('bs.modal', null)
            .remove();
        that.$element.removeClass('modal-open');
        that._$modal = null;
    });

    // Append modal
    this.$element.append(this._$modal);

    // Bind help buttons (if exist)
    this.dialog.bindHelpButtonsInParent(this._$modal);

    return this._$modal;
};

LadbAbstractModal.prototype.hideModalInside = function () {
    if (this._$modal) {
        this._$modal.modal('hide');
    }
}

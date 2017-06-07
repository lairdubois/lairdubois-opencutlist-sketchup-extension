'use strict';

function LadbAbstractTab(element, options, toolbox) {
    this.options = options;
    this.$element = $(element);
    this.toolbox = toolbox;

    this._$modal = null;
}

// Modal /////

LadbAbstractTab.prototype.showModalInside = function(id, twigFile, renderParams) {

    // Hide previously opened modal
    if (this._$modal) {
        this._$modal.modal('hide');
    }

    // Render modal
    this.$element.append(Twig.twig({ref: twigFile}).render(renderParams));

    // Fetch UI elements
    this._$modal = $('#' + id, this.$element);

    // Add modal extra classes
    this._$modal.addClass('modal-inside');

    // Bind modal
    this._$modal.on('hidden.bs.modal', function () {
        $(this)
            .data('bs.modal', null)
            .remove();
    });

    // Show modal
    this._$modal.modal('show');
    $('body > .modal-backdrop').first().appendTo(this.$element);
    $('body')
        .removeClass('modal-open')
        .css('padding-right', 0);

    return this._$modal;
};

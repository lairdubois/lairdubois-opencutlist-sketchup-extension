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

    // Mark the fields the toolbar does not edit
    this.markModalOnlyFields();

    // Setup tooltips and popovers
    this.dialog.setupTooltips(this.$element);
    this.dialog.setupPopovers(this.$element);

};

// Fields /////

// Badges the fields of a tool action modal that are not in the tool's
// toolbar - only when the modal was opened with the toolbar's keys
// (toolbar_option_keys). A field's key is read off its id
// (ladb_input_<key>, ladb_select_<key>, ladb_textarea_<key>).
LadbAbstractModal.prototype.markModalOnlyFields = function () {
    const toolbarOptionKeys = this.options.toolbar_option_keys;
    if (!Array.isArray(toolbarOptionKeys)) {
        return;
    }
    $('.form-group', this.$element).each(function () {
        const $formGroup = $(this);
        const $field = $('[id^="ladb_input_"], [id^="ladb_select_"], [id^="ladb_textarea_"]', $formGroup).first();
        if ($field.length === 0) {
            return;
        }
        const key = $field.attr('id').replace(/^ladb_(input|select|textarea)_/, '');
        if (toolbarOptionKeys.indexOf(key) >= 0) {
            return;
        }
        $('.control-label', $formGroup).first().append(
            $('<i class="ladb-opencutlist-icon-asterisk ladb-modal-only-badge" data-toggle="tooltip"></i>')
                .attr('title', i18next.t('tool.default.modal_only_help'))
        );
    });
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

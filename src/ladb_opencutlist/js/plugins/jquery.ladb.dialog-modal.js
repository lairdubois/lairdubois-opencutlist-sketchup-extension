+function ($) {
    'use strict';

    // CLASS DEFINITION
    // ======================

    const LadbDialogModal = function (element, options) {
        LadbAbstractDialog.call(this, element, $.extend({
            noty_layout: 'dialogModal'
        }, options));

        this.$modal = null;

        this.$wrapper = null;

    };
    LadbDialogModal.prototype = Object.create(LadbAbstractDialog.prototype);

    LadbDialogModal.DEFAULTS = {};

    // force : closes even with unsaved changes (see setGuarded)
    LadbDialogModal.prototype.hide = function (force) {
        rubyCallCommand('core_modal_dialog_hide', { force: force === true });
    };

    // Unsaved changes : closing the window - its close button or from Ruby -
    // goes through confirmClose instead.
    LadbDialogModal.prototype.setGuarded = function (guarded) {
        guarded = guarded === true;
        if (guarded !== this._guarded) {
            this._guarded = guarded;
            rubyCallCommand('core_modal_dialog_set_guarded', { guarded: guarded });
        }
    };

    // Asks the modal - if it knows how to - before closing.
    LadbDialogModal.prototype.confirmClose = function () {
        const jQueryPlugin = this.$modal ? this.$modal.data('ladb.modal.plugin') : null;
        if (jQueryPlugin && typeof jQueryPlugin.confirmClose === 'function') {
            jQueryPlugin.confirmClose();
        } else {
            this.hide(true);
        }
    };

    LadbDialogModal.prototype.loadModal = function (modalName, params) {

        // Render and append tab
        this.$wrapper.append(Twig.twig({ref: "modals/modal-" + modalName.replace(/[_]/g, '-') + ".twig"}).render($.extend({
            modalName: modalName,
            capabilities: this.capabilities,
            classes: 'modal-full'
        }, typeof params === 'object' && params)));

        // Fetch tab
        const $modal = $('#ladb_modal_' + modalName, this.$wrapper);

        // Initialize modal (with its jQuery plugin)
        const jQueryPluginFn = 'ladbModal' + modalName.toLowerCase().split(/[^a-z0-9]+/g).map(function (word) {
            return word.charAt(0).toUpperCase() + word.slice(1);
        }).join('');   // ex: 'hardware_editor' -> 'ladbModalHardwareEditor'
        $modal[jQueryPluginFn]($.extend({ dialog: this }, typeof params === 'object' && params));

        // Bind help buttons (if exist)
        this.bindHelpButtonsInParent($modal);

        // Store modal
        this.$modal = $modal;

        return $modal;
    };

    // Internals /////

    LadbDialogModal.prototype.bind = function () {
        const that = this;

        // Bind validate with enter on modals
        $('body').on('keydown', function (e) {
            if (e.keyCode === 27) {   // "escape" key

                // Progress cancel detection
                if (that.cancelProgress()) {
                    return;
                }

                // Dropdown detection
                if ($(e.target).hasClass('dropdown')) {
                    return;
                }

                // CodeMirror dropdown detection
                if ($(e.target).attr('aria-autocomplete') === 'list') {
                    return;
                }

                // Bootstrap select detection
                if ($(e.target).attr('role') === 'listbox' || $(e.target).attr('role') === 'combobox') {
                    return;
                }

                if (that._$modal) {
                    // A dialog modal (confirm, prompt...) is shown over, dismiss it only
                    $('[data-dismiss="modal"]', that._$modal).first().click();
                    return;
                }

                if (that.$modal) {
                    // A modal is shown, try to click on first "dismiss" button
                    $('[data-dismiss="modal"]', that.$modal).first().click();
                } else {
                    // No modal, hide the dialog
                    that.hide();
                }

            } else if (e.keyCode === 13) {   // Only intercept "enter" key

                const $target = $(e.target);
                if (!$target.is('input[type=text]')) {  // Only intercept if focus is on input[type=text] field
                    return;
                }
                $target.blur(); // Blur target to be sure "change" event occur before

                // Prevent default behavior
                e.preventDefault();

                // Try to retrieve the current top modal (1. from global dialog modal, 2. from inner modal, 3. form dialog itself)
                let $modal = null;
                if (that._$modal) {
                    $modal = that._$modal;
                } else {
                    const jQueryPlugin = that.$modal.data('ladb.modal.plugin');
                    if (jQueryPlugin && jQueryPlugin._$modal) {
                        $modal = jQueryPlugin._$modal;
                    } else {
                        $modal = that.$modal;
                    }
                }

                if ($modal) {
                    const $btnValidate = $('.btn-validate-modal', $modal).first();
                    if ($btnValidate && $btnValidate.is(':enabled')) {
                        $btnValidate.click();
                    }
                }

            }
        });

    };

    LadbDialogModal.prototype.init = function () {
        LadbAbstractDialog.prototype.init.call(this);

        const that = this;

        // Render and append layout template
        this.$element.append(Twig.twig({ref: 'core/layout-modal.twig'}).render({
            capabilities: that.capabilities
        }));

        // Fetch useful elements
        this.$wrapper = $('#ladb_wrapper', this.$element);

        this.bind();

        that.setFontSize(that.options.tabs_dialog_font_size);

        // Load startup modal
        if (this.options.dialog_params && this.options.dialog_params.startup_modal_name) {
            this.loadModal(this.options.dialog_params.startup_modal_name, this.options.dialog_params.params);
        }

    };


    // PLUGIN DEFINITION
    // =======================

    function Plugin(option, params) {
        return this.each(function () {
            const $this = $(this);
            let data = $this.data('ladb.dialog');
            if (!data) {
                const options = $.extend({}, LadbDialogModal.DEFAULTS, $this.data(), typeof option === 'object' && option);
                $this.data('ladb.dialog', (data = new LadbDialogModal(this, options)));
            }
            if (typeof option === 'string') {
                data[option].apply(data, Array.isArray(params) ? params : [ params ])
            } else {
                data.init();
            }
        })
    }

    const old = $.fn.ladbDialogModal;

    $.fn.ladbDialogModal = Plugin;
    $.fn.ladbDialogModal.Constructor = LadbDialogModal;


    // NO CONFLICT
    // =================

    $.fn.ladbDialogModal.noConflict = function () {
        $.fn.ladbDialogModal = old;
        return this;
    }

}(jQuery);
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

    LadbDialogModal.prototype.hide = function () {
        rubyCallCommand('core_modal_dialog_hide');
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
        const jQueryPluginFn = 'ladbModal' + modalName.camelize().capitalize();
        $modal[jQueryPluginFn]($.extend({ dialog: this }, typeof params === 'object' && params));

        // Setup tooltips & popovers
        this.setupTooltips($modal);
        this.setupPopovers($modal);

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

                if (that.$modal) {
                    const $btnValidate = $('.btn-validate-modal', that.$modal).first();
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
            let data = $this.data('ladb.dialog-modal');
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
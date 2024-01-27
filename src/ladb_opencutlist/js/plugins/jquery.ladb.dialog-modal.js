+function ($) {
    'use strict';

    // CLASS DEFINITION
    // ======================

    var LadbDialogModal = function (element, options) {
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
        var $modal = $('#ladb_modal_' + modalName, this.$wrapper);

        // Initialize modal (with its jQuery plugin)
        var jQueryPluginFn = 'ladbModal' + modalName.camelize().capitalize();
        $modal[jQueryPluginFn]($.extend({ dialog: this }, typeof params === 'object' && params));

        // Setup tooltips & popovers
        this.setupTooltips();
        this.setupPopovers();

        // Bind help buttons (if exist)
        this.bindHelpButtonsInParent($modal);

        // Store modal
        this.$modal = $modal;

        return $modal;
    };

    // Internals /////

    LadbDialogModal.prototype.bind = function () {
        var that = this;

        // Bind validate with enter on modals
        $('body').on('keydown', function (e) {
            if (e.keyCode === 27) {   // "escape" key

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

                // Try to retrieve the current top modal (1. from global dialog modal, 2. from active tab inner modal)
                var $modal = null;
                if (that._$modal) {
                    $modal = that._$modal;
                } else {
                    if (that.$modal) {
                        $modal = that.$modal._$modal;
                    }
                }

                if ($modal) {
                    // A modal is shown, try to click on first "dismiss" button
                    $('[data-dismiss="modal"]', $modal).first().click();
                } else {
                    // No modal, hide the dialog
                    that.hide();
                }

            } else if (e.keyCode === 13) {   // Only intercept "enter" key

                var $target = $(e.target);
                if (!$target.is('input[type=text]')) {  // Only intercept if focus is on input[type=text] field
                    return;
                }
                $target.blur(); // Blur target to be sure "change" event occur before

                // Prevent default behavior
                e.preventDefault();

                // Try to retrieve the current top modal (1. from global dialog modal, 2. from active tab inner modal)
                var $modal = null;
                if (that._$modal) {
                    $modal = that._$modal;
                } else {
                    if (that.$modal) {
                        $modal = that.$modal._$modal;
                    }
                }

                if ($modal) {
                    var $btnValidate = $('.btn-validate-modal', $modal).first();
                    if ($btnValidate && $btnValidate.is(':enabled')) {
                        $btnValidate.click();
                    }
                }

            }
        });

    };

    LadbDialogModal.prototype.init = function () {
        LadbAbstractDialog.prototype.init.call(this);

        var that = this;

        // Render and append layout template
        this.$element.append(Twig.twig({ref: 'core/layout-modal.twig'}).render({
            capabilities: that.capabilities
        }));

        // Fetch useful elements
        this.$wrapper = $('#ladb_wrapper', this.$element);

        this.bind();

        // Load startup modal
        if (this.options.dialog_params && this.options.dialog_params.startup_modal_name) {
            this.loadModal(this.options.dialog_params.startup_modal_name, this.options.dialog_params.params);
        }

    };


    // PLUGIN DEFINITION
    // =======================

    function Plugin(option, params) {
        return this.each(function () {
            var $this = $(this);
            var data = $this.data('ladb.dialog-modal');
            var options = $.extend({}, LadbDialogModal.DEFAULTS, $this.data(), typeof option === 'object' && option);

            if (!data) {
                $this.data('ladb.dialog', (data = new LadbDialogModal(this, options)));
            }
            if (typeof option === 'string') {
                data[option].apply(data, Array.isArray(params) ? params : [ params ])
            } else {
                data.init();
            }
        })
    }

    var old = $.fn.ladbDialogModal;

    $.fn.ladbDialogModal = Plugin;
    $.fn.ladbDialogModal.Constructor = LadbDialogModal;


    // NO CONFLICT
    // =================

    $.fn.ladbDialogModal.noConflict = function () {
        $.fn.ladbDialogModal = old;
        return this;
    }

}(jQuery);
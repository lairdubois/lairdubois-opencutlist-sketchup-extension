+function ($) {
    'use strict';

    // CLASS DEFINITION
    // ======================

    const LadbModalSmartJoinToolAction0 = function (element, options, dialog) {
        LadbAbstractModalSmartJoinToolAction.call(this, element, options, dialog, 'action_0');
    };
    LadbModalSmartJoinToolAction0.prototype = Object.create(LadbAbstractModalSmartJoinToolAction.prototype);

    LadbModalSmartJoinToolAction0.DEFAULTS = {};

    // PLUGIN DEFINITION
    // =======================

    function Plugin(option, params) {
        return this.each(function () {
            const $this = $(this);
            let data = $this.data('ladb.modal.plugin');
            const options = $.extend({}, LadbModalSmartJoinToolAction0.DEFAULTS, $this.data(), typeof option === 'object' && option);

            if (!data) {
                if (undefined === options.dialog) {
                    throw 'dialog option is mandatory.';
                }
                $this.data('ladb.modal.plugin', (data = new LadbModalSmartJoinToolAction0(this, options, options.dialog)));
            }
            if (typeof option === 'string') {
                data[option].apply(data, Array.isArray(params) ? params : [ params ])
            } else {
                data.init();
            }
        })
    }

    const old = $.fn.ladbModalSmartJoinToolAction0;

    $.fn.ladbModalSmartJoinToolAction0 = Plugin;
    $.fn.ladbModalSmartJoinToolAction0.Constructor = LadbModalSmartJoinToolAction0;


    // NO CONFLICT
    // =================

    $.fn.ladbModalSmartJoinToolAction0.noConflict = function () {
        $.fn.ladbModalSmartJoinToolAction0 = old;
        return this;
    }

}(jQuery);

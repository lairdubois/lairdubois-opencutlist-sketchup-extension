+function ($) {
    'use strict';

    // CLASS DEFINITION
    // ======================

    const LadbModalSmartJoinToolAction2 = function (element, options, dialog) {
        LadbAbstractModalSmartJoinToolAction.call(this, element, options, dialog, 'action_2');
    };
    LadbModalSmartJoinToolAction2.prototype = Object.create(LadbAbstractModalSmartJoinToolAction.prototype);

    LadbModalSmartJoinToolAction2.DEFAULTS = {};

    // PLUGIN DEFINITION
    // =======================

    function Plugin(option, params) {
        return this.each(function () {
            const $this = $(this);
            let data = $this.data('ladb.modal.plugin');
            const options = $.extend({}, LadbModalSmartJoinToolAction2.DEFAULTS, $this.data(), typeof option === 'object' && option);

            if (!data) {
                if (undefined === options.dialog) {
                    throw 'dialog option is mandatory.';
                }
                $this.data('ladb.modal.plugin', (data = new LadbModalSmartJoinToolAction2(this, options, options.dialog)));
            }
            if (typeof option === 'string') {
                data[option].apply(data, Array.isArray(params) ? params : [ params ])
            } else {
                data.init();
            }
        })
    }

    const old = $.fn.ladbModalSmartJoinToolAction2;

    $.fn.ladbModalSmartJoinToolAction2 = Plugin;
    $.fn.ladbModalSmartJoinToolAction2.Constructor = LadbModalSmartJoinToolAction2;


    // NO CONFLICT
    // =================

    $.fn.ladbModalSmartJoinToolAction2.noConflict = function () {
        $.fn.ladbModalSmartJoinToolAction2 = old;
        return this;
    }

}(jQuery);

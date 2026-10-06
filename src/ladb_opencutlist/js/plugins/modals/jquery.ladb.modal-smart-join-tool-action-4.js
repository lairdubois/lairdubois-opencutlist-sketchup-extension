+function ($) {
    'use strict';

    // CLASS DEFINITION
    // ======================

    const LadbModalSmartJoinToolAction4 = function (element, options, dialog) {
        LadbAbstractModalSmartJoinToolAction.call(this, element, options, dialog, 'action_4');
    };
    LadbModalSmartJoinToolAction4.prototype = Object.create(LadbAbstractModalSmartJoinToolAction.prototype);

    LadbModalSmartJoinToolAction4.DEFAULTS = {};

    // PLUGIN DEFINITION
    // =======================

    function Plugin(option, params) {
        return this.each(function () {
            const $this = $(this);
            let data = $this.data('ladb.modal.plugin');
            const options = $.extend({}, LadbModalSmartJoinToolAction4.DEFAULTS, $this.data(), typeof option === 'object' && option);

            if (!data) {
                if (undefined === options.dialog) {
                    throw 'dialog option is mandatory.';
                }
                $this.data('ladb.modal.plugin', (data = new LadbModalSmartJoinToolAction4(this, options, options.dialog)));
            }
            if (typeof option === 'string') {
                data[option].apply(data, Array.isArray(params) ? params : [ params ])
            } else {
                data.init();
            }
        })
    }

    const old = $.fn.ladbModalSmartJoinToolAction4;

    $.fn.ladbModalSmartJoinToolAction4 = Plugin;
    $.fn.ladbModalSmartJoinToolAction4.Constructor = LadbModalSmartJoinToolAction4;


    // NO CONFLICT
    // =================

    $.fn.ladbModalSmartJoinToolAction4.noConflict = function () {
        $.fn.ladbModalSmartJoinToolAction4 = old;
        return this;
    }

}(jQuery);

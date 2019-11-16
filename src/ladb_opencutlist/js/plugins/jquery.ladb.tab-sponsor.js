+function ($) {
    'use strict';

    var MESSAGE_PREFIX = 'ladb-opencutlist-';

    // CLASS DEFINITION
    // ======================

    var LadbTabSponsor = function (element, options, opencutlist) {
        LadbAbstractTab.call(this, element, options, opencutlist);

        this.$containerFluid = $('.ladb-container .container-fluid', this.$element);
        this.$iframe = $('#ladb_sponsor_iframe', this.$element);

        this.$membersDiv = $('#ladb_sponsor_members', this.$element);
    };
    LadbTabSponsor.prototype = new LadbAbstractTab;

    LadbTabSponsor.DEFAULTS = {};

    LadbTabSponsor.prototype.bind = function () {
        var that = this;

        // Bind window message event
        window.addEventListener('message', function (e) {
            if (typeof e.data !== 'string' || e.data.substr(0, MESSAGE_PREFIX.length) !== MESSAGE_PREFIX) return;
            var jsonData = JSON.parse(e.data.substr(MESSAGE_PREFIX.length));

            // Hide default container
            that.$containerFluid.hide();

            // Update iframe height
            that.$iframe.height(jsonData.height);

        });

    };

    LadbTabSponsor.prototype.init = function (initializedCallback) {
        var that = this;

        this.bind();

        $.getJSON( "https://opencollective.com/lairdubois-opencutlist-sketchup-extension/members/users.json", function( data ) {

            $.each(data, function (index, member) {
                console.log(member);
                that.$membersDiv.append(Twig.twig({ ref: "tabs/sponsor/_member.twig" }).render({
                    member: member
                }));
            });


        });


        // Callback
        if (initializedCallback && typeof(initializedCallback) == 'function') {
            initializedCallback(that.$element);
        }

    };


    // PLUGIN DEFINITION
    // =======================

    function Plugin(option, params) {
        return this.each(function () {
            var $this = $(this);
            var data = $this.data('ladb.tabSponsor');
            var options = $.extend({}, LadbTabSponsor.DEFAULTS, $this.data(), typeof option == 'object' && option);

            if (!data) {
                if (undefined === options.opencutlist) {
                    throw 'opencutlist option is mandatory.';
                }
                $this.data('ladb.tabSponsor', (data = new LadbTabSponsor(this, options, options.opencutlist)));
            }
            if (typeof option == 'string') {
                data[option].apply(data, Array.isArray(params) ? params : [ params ])
            } else {
                data.init(option.initializedCallback);
            }
        })
    }

    var old = $.fn.ladbTabSponsor;

    $.fn.ladbTabSponsor = Plugin;
    $.fn.ladbTabSponsor.Constructor = LadbTabSponsor;


    // NO CONFLICT
    // =================

    $.fn.ladbTabSponsor.noConflict = function () {
        $.fn.ladbTabSponsor = old;
        return this;
    }

}(jQuery);
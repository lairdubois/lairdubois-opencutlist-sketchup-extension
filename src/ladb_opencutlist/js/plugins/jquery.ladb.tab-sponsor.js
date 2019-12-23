+function ($) {
    'use strict';

    var MESSAGE_PREFIX = 'ladb-opencutlist-';

    var GRAPHQL_SLUG = 'lairdubois-opencutlist-sketchup-extension';
    var GRAPHQL_ENDPOINT = 'https://api.opencollective.com/graphql/v2/';
    var GRAPHQL_PAGE_SIZE = 16;

    // CLASS DEFINITION
    // ======================

    var LadbTabSponsor = function (element, options, opencutlist) {
        LadbAbstractTab.call(this, element, options, opencutlist);

        this.$loading = $('.ladb-loading', this.$element);

    };
    LadbTabSponsor.prototype = new LadbAbstractTab;

    LadbTabSponsor.DEFAULTS = {};

    LadbTabSponsor.prototype.bind = function () {
        var that = this;

    };

    LadbTabSponsor.prototype.loadBackers = function (page) {
        var that = this;

        // Show loading
        this.$loading.show();

        // Init page
        page = page ? page : 0;

        $.ajax({
            url: GRAPHQL_ENDPOINT,
            contentType: 'application/json',
            type: 'POST',
            dataType: 'json',
            data: JSON.stringify({
                query: "query members($slug: String) { collective(slug: $slug) { name slug members(offset: " + page * GRAPHQL_PAGE_SIZE + ", limit: " + GRAPHQL_PAGE_SIZE + ", role: BACKER) { totalCount nodes { account { slug name description imageUrl website } totalDonations { value currency } } } }}",
                variables: {
                    slug: GRAPHQL_SLUG
                }
            }),
            success: function (response) {
                if (response.data) {

                    var nextPage = ((page + 1) * GRAPHQL_PAGE_SIZE < response.data.collective.members.totalCount) ? page + 1 : null;

                    // Render members list
                    var $list = $(Twig.twig({ref: 'tabs/sponsor/_members-' + (page === 0 ? '0' : 'n') + '.twig'}).render({
                        members: response.data.collective.members,
                        nextPage: nextPage,
                    }));
                    if (page === 0) {
                        $list.insertBefore(that.$loading);
                    } else {
                        $('#ladb_sponsor_members').append($list);
                    }

                    // Bind button
                    $('.ladb-sponsor-next-page-btn', $list).on('click', function () {
                        that.loadBackers(nextPage);
                        $(this).remove();
                    });

                    // Bind
                    $('.ladb-sponsor-member-box', $list).on('click', function(e) {
                        var $closestAnchor = $(e.target.closest('a'));
                        if ($closestAnchor.length > 0) {
                            rubyCallCommand('core_open_url', { url: $closestAnchor.attr('href') });
                            return false;
                        }
                        var slug = $(this).data('member-slug');
                        rubyCallCommand('core_open_url', { url: 'https://opencollective.com/' + slug });
                    });

                }

                // Hide loading
                that.$loading.hide();

            },
            error: function(jqXHR, textStatus, errorThrown) {

                // Hide loading
                that.$loading.hide();

            }
        });

    };

    LadbTabSponsor.prototype.init = function (initializedCallback) {
        var that = this;

        this.bind();
        this.loadBackers();

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
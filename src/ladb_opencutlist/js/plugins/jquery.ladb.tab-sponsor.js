+function ($) {
    'use strict';

    var MESSAGE_PREFIX = 'ladb-opencutlist-';

    var GRAPHQL_SLUG = 'babel'; //'lairdubois-opencutlist-sketchup-extension';
    var GRAPHQL_ENDPOINT = 'https://api.opencollective.com/graphql/v2/';
    var GRAPHQL_PAGE_SIZE = 20;

    // CLASS DEFINITION
    // ======================

    var LadbTabSponsor = function (element, options, opencutlist) {
        LadbAbstractTab.call(this, element, options, opencutlist);

        this.$loading = $('.ladb-loading', this.$element);

        this.$page = $('.ladb-page', this.$element);

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

        // Construct GraphQL querry
        var graph = graphql(GRAPHQL_ENDPOINT);
        const membersQuery = graph(`
            query members($slug: String) {
              collective(slug: $slug) {
                name
                slug
                members(offset: ` + page * GRAPHQL_PAGE_SIZE + `, limit: ` + GRAPHQL_PAGE_SIZE + `, role: BACKER) {
                  totalCount
                  nodes {
                    id
                    account {
                      id
                      slug
                      name
                      description
                      imageUrl
                      website
                    }
                    since
                    totalDonations {
                      value
                      currency
                    }
                  }
                }
              }
            }
        `);

        membersQuery({ slug: GRAPHQL_SLUG})
            .then(function (response) {

                var nextPage = ((page + 1) * GRAPHQL_PAGE_SIZE < response.collective.members.totalCount) ? page + 1 : null;

                // Render members list
                var $list = $(Twig.twig({ref: 'tabs/sponsor/_members-' + (page == 0 ? '0' : 'n') + '.twig'}).render({
                    members: response.collective.members,
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

                // Hide loading
                that.$loading.hide();

            }).catch(function (error) {
                // response is originally response.errors of query result
                console.log(error)
            })

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
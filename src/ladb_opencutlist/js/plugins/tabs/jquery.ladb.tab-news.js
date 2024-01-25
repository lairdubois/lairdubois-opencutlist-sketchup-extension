+function ($) {
    'use strict';

    // CONSTANTS
    // ======================

    var UPDATES_PAGE_SIZE = 5;

    // CLASS DEFINITION
    // ======================

    var LadbTabNews = function (element, options, dialog) {
        LadbAbstractTab.call(this, element, options, dialog);

        this.$page = $('.ladb-page', this.$element);

    };
    LadbTabNews.prototype = Object.create(LadbAbstractTab.prototype);

    LadbTabNews.DEFAULTS = {};

    LadbTabNews.prototype.loadUpdates = function (page) {
        var that = this;

        // Fetch UI elements
        var $loading = $('.ladb-loading', this.$page);

        // Show loading
        $loading.show();

        // Init page
        page = page ? page : 0;

        $.ajax({
            url: GRAPHQL_ENDPOINT,
            contentType: 'application/json',
            type: 'POST',
            dataType: 'json',
            data: JSON.stringify({
                query: "query updates($slug: String) { " +
                        "collective(slug: $slug) { " +
                            "updates(offset: " + page * UPDATES_PAGE_SIZE + ", limit: " + UPDATES_PAGE_SIZE + ", onlyPublishedUpdates: true) { " +
                                "totalCount " +
                                "nodes { " +
                                    "slug " +
                                    "title " +
                                    "publishedAt " +
                                    "isPrivate " +
                                    "html " +
                                    "reactions " +
                                    "fromAccount { " +
                                        "slug " +
                                        "name " +
                                        "imageUrl " +
                                    "}" +
                                    "comments { " +
                                        "nodes { " +
                                            "createdAt " +
                                            "fromAccount { " +
                                                "slug " +
                                                "name " +
                                                "imageUrl " +
                                            "}" +
                                            "html " +
                                            "reactions " +
                                        "}" +
                                    "}" +
                                "}" +
                            "}" +
                        "}" +
                    "}",
                variables: {
                    slug: GRAPHQL_SLUG
                }
            }),
            success: function (response) {
                if (response.data) {

                    // First page, keep last listed news timestamp
                    if (page === 0) {
                        var lastNewsTimestamp = Date.parse(response.data.collective.updates.nodes[0].publishedAt);
                        that.dialog.setLastListedNewsTimestamp(lastNewsTimestamp);
                    }

                    var nextPage = ((page + 1) * UPDATES_PAGE_SIZE < response.data.collective.updates.totalCount) ? page + 1 : null;

                    // Render updates list
                    var $list = $(Twig.twig({ref: 'tabs/news/_updates-' + (page === 0 ? '0' : 'n') + '.twig'}).render({
                        updates: response.data.collective.updates,
                        nextPage: nextPage,
                    }));
                    if (page === 0) {
                        $list.insertBefore($loading);
                    } else {
                        $('#ladb_news_updates').append($list);
                    }

                    // Bind button
                    $('.ladb-news-next-page-btn', $list).on('click', function () {
                        that.loadUpdates(nextPage);
                        $(this).parent().remove();
                    });
                    $('.ladb-news-comment-btn', $list).on('click', function () {
                        var slug = $(this).closest('.ladb-news-update-box').data('update-slug');
                        rubyCallCommand('core_open_url', { url: 'https://opencollective.com/' + GRAPHQL_SLUG + '/updates/' + slug });
                        return false;
                    });

                    // Bind box
                    $('.ladb-news-update-box', $list).on('click', function(e) {
                        var $closestAnchor = $(e.target.closest('a'));
                        if ($closestAnchor.length > 0) {
                            rubyCallCommand('core_open_url', { url: $closestAnchor.attr('href') });
                            return false;
                        }
                        var slug = $(this).data('update-slug');
                        rubyCallCommand('core_open_url', { url: 'https://opencollective.com/' + GRAPHQL_SLUG + '/updates/' + slug });
                    });

                }

                // Hide loading
                $loading.hide();

            },
            error: function(jqXHR, textStatus, errorThrown) {

                that.$page.empty();
                that.$page.append(Twig.twig({ ref: "core/_alert-errors.twig" }).render({
                    errors: [ 'tab.news.error.fail_to_load_list' ]
                }));

            }
        });

    }

    LadbTabNews.prototype.defaultInitializedCallback = function () {
        LadbAbstractTab.prototype.defaultInitializedCallback.call(this);

        this.loadUpdates();

    };

    // PLUGIN DEFINITION
    // =======================

    function Plugin(option, params) {
        return this.each(function () {
            var $this = $(this);
            var data = $this.data('ladb.tab.plugin');
            var options = $.extend({}, LadbTabNews.DEFAULTS, $this.data(), typeof option === 'object' && option);

            if (!data) {
                if (undefined === options.dialog) {
                    throw 'dialog option is mandatory.';
                }
                $this.data('ladb.tab.plugin', (data = new LadbTabNews(this, options, options.dialog)));
            }
            if (typeof option === 'string') {
                data[option].apply(data, Array.isArray(params) ? params : [ params ])
            } else {
                data.init(option.initializedCallback);
            }
        })
    }

    var old = $.fn.ladbTabNews;

    $.fn.ladbTabNews = Plugin;
    $.fn.ladbTabNews.Constructor = LadbTabNews;


    // NO CONFLICT
    // =================

    $.fn.ladbTabNews.noConflict = function () {
        $.fn.ladbTabNews = old;
        return this;
    }

}(jQuery);
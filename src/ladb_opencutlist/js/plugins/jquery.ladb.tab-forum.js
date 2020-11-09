+function ($) {
    'use strict';

    // CONSTANTS
    // ======================

    var UPDATES_PAGE_SIZE = 5;

    // CLASS DEFINITION
    // ======================

    var LadbTabForum = function (element, options, opencutlist) {
        LadbAbstractTab.call(this, element, options, opencutlist);

        this.$btnCreateConversation = $('#ladb_btn_create_conversation', this.$element);

        this.$page = $('.ladb-page', this.$element);

        this.conversations = {};

    };
    LadbTabForum.prototype = new LadbAbstractTab;

    LadbTabForum.DEFAULTS = {};

    LadbTabForum.prototype.loadConversations = function (page) {
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
                query: "query conversations($slug: String) { " +
                        "collective(slug: $slug) { " +
                            "conversations(offset: " + page * UPDATES_PAGE_SIZE + ", limit: " + UPDATES_PAGE_SIZE + ") { " +
                                "totalCount " +
                                "nodes { " +
                                    "id " +
                                    "slug " +
                                    "title " +
                                    "createdAt " +
                                    "fromCollective { " +
                                        "slug " +
                                        "name " +
                                        "imageUrl " +
                                    "}" +
                                    "summary " +
                                    "body { " +
                                        "html " +
                                    "} " +
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
                                    "stats {" +
                                        "commentsCount " +
                                    "} " +
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

                    // Store conversations
                    var conversation = null;
                    for (var i = 0; i < response.data.collective.conversations.nodes.length; i++) {

                        conversation = response.data.collective.conversations.nodes[i];
                        that.conversations[conversation.id] = conversation;

                    }

                    var nextPage = ((page + 1) * UPDATES_PAGE_SIZE < response.data.collective.conversations.totalCount) ? page + 1 : null;

                    // Render conversations list
                    var $list = $(Twig.twig({ref: 'tabs/forum/_conversations-' + (page === 0 ? '0' : 'n') + '.twig'}).render({
                        conversations: response.data.collective.conversations,
                        nextPage: nextPage,
                    }));
                    if (page === 0) {
                        $list.insertBefore($loading);
                    } else {
                        $('#ladb_forum_conversations').append($list);
                    }

                    // Bind button
                    $('.ladb-forum-next-page-btn', $list).on('click', function () {
                        that.loadConversations(nextPage);
                        $(this).remove();
                    });

                    // Bind
                    $('.ladb-forum-conversation-box', $list).on('click', function(e) {
                        var $closestAnchor = $(e.target.closest('a'));
                        if ($closestAnchor.length > 0) {
                            rubyCallCommand('core_open_url', { url: $closestAnchor.attr('href') });
                            return false;
                        }
                        var id = $(this).data('conversation-id');
                        that.showConversationModal(id)
                    });

                }

                // Hide loading
                $loading.hide();

            },
            error: function(jqXHR, textStatus, errorThrown) {

                that.$page.empty();
                that.$page.append(Twig.twig({ ref: "core/_alert-errors.twig" }).render({
                    errors: [ 'tab.forum.error.fail_to_load_list' ]
                }));

            }
        });

    }

    LadbTabForum.prototype.showConversationModal = function (id) {
        var conversation = this.conversations[id];

        var $modal = this.appendModalInside('ladb_forum_conversation', 'tabs/forum/_modal-conversation.twig', {
            conversation: conversation
        });

        // Bind buttons
        $('#ladb_forum_conversation_reply', $modal).on('click', function () {
            var slug = $(this).data('conversation-slug');
            var id = $(this).data('conversation-id');
            rubyCallCommand('core_open_url', { url: 'https://opencollective.com/' + GRAPHQL_SLUG + '/conversations/' + slug + '-' + id });
            return false;
        });

        // Show modal
        $modal.modal('show');

    };

    LadbTabForum.prototype.bind = function () {
        LadbAbstractTab.prototype.bind.call(this);

        // Bind buttons
        this.$btnCreateConversation.on('click', function () {
            rubyCallCommand('core_open_url', { url: 'https://opencollective.com/' + GRAPHQL_SLUG + '/conversations/new' });
            return false;
        });

    };

    LadbTabForum.prototype.defaultInitializedCallback = function () {
        LadbAbstractTab.prototype.defaultInitializedCallback.call(this);

        this.loadConversations();

    };

    // PLUGIN DEFINITION
    // =======================

    function Plugin(option, params) {
        return this.each(function () {
            var $this = $(this);
            var data = $this.data('ladb.tab.plugin');
            var options = $.extend({}, LadbTabForum.DEFAULTS, $this.data(), typeof option == 'object' && option);

            if (!data) {
                if (undefined === options.dialog) {
                    throw 'dialog option is mandatory.';
                }
                $this.data('ladb.tab.plugin', (data = new LadbTabForum(this, options, options.dialog)));
            }
            if (typeof option == 'string') {
                data[option].apply(data, Array.isArray(params) ? params : [ params ])
            } else {
                data.init(option.initializedCallback);
            }
        })
    }

    var old = $.fn.ladbTabForum;

    $.fn.ladbTabForum = Plugin;
    $.fn.ladbTabForum.Constructor = LadbTabForum;


    // NO CONFLICT
    // =================

    $.fn.ladbTabForum.noConflict = function () {
        $.fn.ladbTabForum = old;
        return this;
    }

}(jQuery);
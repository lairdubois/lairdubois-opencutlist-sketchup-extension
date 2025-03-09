+function ($) {
    'use strict';

    // CONSTANTS
    // ======================

    const UPDATES_PAGE_SIZE = 5;

    // CLASS DEFINITION
    // ======================

    const LadbTabForum = function (element, options, dialog) {
        LadbAbstractTab.call(this, element, options, dialog);

        this.$btnCreateConversation = $('#ladb_btn_create_conversation', this.$element);

        this.$page = $('.ladb-page', this.$element);

        this.conversations = {};

    };
    LadbTabForum.prototype = Object.create(LadbAbstractTab.prototype);

    LadbTabForum.DEFAULTS = {};

    LadbTabForum.prototype.loadConversations = function (tagFilter, page) {
        const that = this;

        // Fetch UI elements
        const $loading = $('.ladb-loading', this.$page);

        // Show loading
        $loading.show();

        // Init page
        page = page ? page : 0;

        // Reset if first page
        if (page === 0) {

            // Clear cache
            this.conversations = {};

            // Empty conversations
            $('#ladb_forum_page_content', this.$page).remove();

        }

        $.ajax({
            url: GRAPHQL_ENDPOINT,
            contentType: 'application/json',
            type: 'POST',
            dataType: 'json',
            data: JSON.stringify({
                query: "query conversations($slug: String" + (tagFilter ? ", $tag: String" : "") + ") { " +
                        "collective(slug: $slug) { " +
                            (page === 0 ? "conversationsTags { tag count } " : "") +
                            "conversations(offset: " + page * UPDATES_PAGE_SIZE + ", limit: " + UPDATES_PAGE_SIZE + (tagFilter ? ", tag: $tag" : "") + ") { " +
                                "totalCount " +
                                "nodes { " +
                                    "id " +
                                    "slug " +
                                    "title " +
                                    "createdAt " +
                                    "fromAccount { " +
                                        "slug " +
                                        "name " +
                                        "imageUrl " +
                                    "}" +
                                    "summary " +
                                    "tags " +
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
                    slug: GRAPHQL_SLUG,
                    tag: tagFilter
                }
            }),
            success: function (response) {
                if (response.data) {

                    // Cache conversations
                    let conversation = null;
                    for (let i = 0; i < response.data.collective.conversations.nodes.length; i++) {

                        conversation = response.data.collective.conversations.nodes[i];
                        that.conversations[conversation.id] = conversation;

                    }

                    const nextPage = ((page + 1) * UPDATES_PAGE_SIZE < response.data.collective.conversations.totalCount) ? page + 1 : null;

                    // Render conversations list
                    const $list = $(Twig.twig({ref: 'tabs/forum/_conversations-' + (page === 0 ? '0' : 'n') + '.twig'}).render({
                        conversationsTags: response.data.collective.conversationsTags,
                        conversations: response.data.collective.conversations,
                        tagFilter: tagFilter,
                        nextPage: nextPage,
                    }));
                    if (page === 0) {
                        $list.insertBefore($loading);
                    } else {
                        $('#ladb_forum_conversations').append($list);
                    }

                    // Bind button
                    $('.ladb-forum-next-page-btn', $list).on('click', function () {
                        that.loadConversations(tagFilter, nextPage);
                        $(this).parent().remove();
                    });
                    $('.ladb-forum-tag', $list).on('click', function () {
                        that.loadConversations($(this).hasClass('ladb-active') ? null : $(this).data('tag'));
                        return false;
                    });

                    // Bind box
                    $('.ladb-forum-conversation-box', $list).on('click', function(e) {
                        const $closestAnchor = $(e.target.closest('a'));
                        if ($closestAnchor.length > 0) {
                            rubyCallCommand('core_open_url', { url: $closestAnchor.attr('href') });
                            return false;
                        }
                        const id = $(this).data('conversation-id');
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
        const that = this;
        const conversation = this.conversations[id];

        const $modal = this.appendModalInside('ladb_forum_conversation', 'tabs/forum/_modal-conversation.twig', {
            conversation: conversation
        });

        // Bind buttons
        $('#ladb_forum_conversation_reply', $modal).on('click', function () {
            const slug = $(this).data('conversation-slug');
            const id = $(this).data('conversation-id');

            that.showRedirectionModal(function() {
                rubyCallCommand('core_open_url', { url: 'https://opencollective.com/' + GRAPHQL_SLUG + '/conversations/' + slug + '-' + id });
            });

            return false;
        });

        // Show modal
        $modal.modal('show');

    };

    LadbTabForum.prototype.showRedirectionModal = function (callback) {

        const $modal = this.appendModalInside('ladb_forum_redirection', 'tabs/forum/_modal-redirection.twig', {
        });

        // Bind buttons
        $('#ladb_forum_redirection_continue', $modal).on('click', function () {
            callback();

            // hide modal
            $modal.modal('hide');

            return false;
        });

        // Show modal
        $modal.modal('show');

    };

    // Init ///

    LadbTabForum.prototype.registerCommands = function () {
        LadbAbstractTab.prototype.registerCommands.call(this);

        const that = this;

        this.registerCommand('load_conversations', function (parameters) {
            setTimeout(function () {     // Use setTimeout to give time to UI to refresh
                const tagFilter = parameters ? parameters.tagFilter : null;
                that.loadConversations(tagFilter);
            }, 1);
        });
    };

    LadbTabForum.prototype.bind = function () {
        LadbAbstractTab.prototype.bind.call(this);

        const that = this;

        // Bind buttons
        this.$btnCreateConversation.on('click', function () {
            that.showRedirectionModal(function() {
                rubyCallCommand('core_open_url', { url: 'https://opencollective.com/' + GRAPHQL_SLUG + '/conversations/new' });
            });
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
            const $this = $(this);
            let data = $this.data('ladb.tab.plugin');
            if (!data) {
                const options = $.extend({}, LadbTabForum.DEFAULTS, $this.data(), typeof option === 'object' && option);
                if (undefined === options.dialog) {
                    throw 'dialog option is mandatory.';
                }
                $this.data('ladb.tab.plugin', (data = new LadbTabForum(this, options, options.dialog)));
            }
            if (typeof option === 'string') {
                data[option].apply(data, Array.isArray(params) ? params : [ params ])
            } else {
                data.init(option.initializedCallback);
            }
        })
    }

    const old = $.fn.ladbTabForum;

    $.fn.ladbTabForum = Plugin;
    $.fn.ladbTabForum.Constructor = LadbTabForum;


    // NO CONFLICT
    // =================

    $.fn.ladbTabForum.noConflict = function () {
        $.fn.ladbTabForum = old;
        return this;
    }

}(jQuery);
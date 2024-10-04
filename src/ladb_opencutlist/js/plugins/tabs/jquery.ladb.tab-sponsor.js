+function ($) {
    'use strict';

    // CONSTANTS
    // ======================

    var BACKERS_PAGE_SIZE = 16;

    // CLASS DEFINITION
    // ======================

    var LadbTabSponsor = function (element, options, dialog) {
        LadbAbstractTab.call(this, element, options, dialog);

        this.$widgetObjective = $('.ladb-sponsor-objective-widget', this.$element);
        this.$widgetBackers = $('#ladb_sponsor_backers_widget', this.$element);

    };
    LadbTabSponsor.prototype = Object.create(LadbAbstractTab.prototype);

    LadbTabSponsor.DEFAULTS = {};

    LadbTabSponsor.prototype.bindObjectiveWidget = function ($widget) {
        var that = this;

        var objectiveName = this.dialog.capabilities.manifest.sponsor && this.dialog.capabilities.manifest.sponsor.objectiveName ? this.dialog.capabilities.manifest.sponsor.objectiveName : '';
        var objectiveGoal = this.dialog.capabilities.manifest.sponsor && this.dialog.capabilities.manifest.sponsor.objectiveGoal ? this.dialog.capabilities.manifest.sponsor.objectiveGoal : 10000;
        var objectiveCurrency = this.dialog.capabilities.manifest.sponsor && this.dialog.capabilities.manifest.sponsor.objectiveCurrency ? this.dialog.capabilities.manifest.sponsor.objectiveCurrency : 'USD';

        // Fetch UI elements
        var $loading = $('.ladb-loading', $widget);
        var $btnInfo = $('.ladb-sponsor-objective-info-btn', $widget);
        var $labelObjective = $('.ladb-sponsor-objective-label', $widget);
        var $labelObjectiveGoal = $('.ladb-sponsor-objective-goal-label', $widget);
        var $labelObjectiveProgress = $('.ladb-sponsor-objective-progress-label', $widget);
        var $progressObjective = $('.progress', $widget);
        var $progressBarObjective = $('.progress-bar', $widget);

        // Append objective name
        $labelObjective.append(' ' + objectiveName);

        // Append currency formatted objective goal
        $labelObjectiveGoal.append(that.dialog.amountToLocaleString(objectiveGoal, objectiveCurrency));

        // Bind button
        $btnInfo.on('click', function() {
            that.showObjectiveModal();
        });

        // Load current balance
        $.ajax({
            url: GRAPHQL_ENDPOINT,
            contentType: 'application/json',
            type: 'POST',
            dataType: 'json',
            data: JSON.stringify({
                query: "query collective($slug: String) { " +
                        "collective(slug: $slug) { " +
                            "stats { " +
                                "balance { value }" +
                            "}" +
                        "}" +
                    "}",
                variables: {
                    slug: GRAPHQL_SLUG
                }
            }),
            success: function (response) {
                if (response.data) {

                    var balance = response.data.collective.stats.balance.value;
                    var objectiveProgress100 = Math.round(balance / objectiveGoal * 100);
                    var objectiveReached = objectiveProgress100 >= 100;

                    $progressObjective.show();
                    $progressBarObjective
                        .append(that.dialog.amountToLocaleString(balance, objectiveCurrency))
                        .animate({ width: Math.min(100, objectiveProgress100) + '%' }, 300, 'linear')
                    ;
                    $labelObjectiveProgress
                        .addClass('ladb-color-' + (objectiveReached ? 'success' : 'null'))
                        .append((objectiveReached ? '<i class="ladb-opencutlist-icon-tick"></i> ' : '') + i18next.t('tab.sponsor.objective_funded_progress', { progress: objectiveProgress100 }))
                        .show()
                    ;

                    // Hide loading
                    $loading.hide();

                }
            },
            error: function(jqXHR, textStatus, errorThrown) {

                // Hide loading
                $loading.hide();

            }
        });

    };

    LadbTabSponsor.prototype.loadBackers = function (page) {
        var that = this;

        // Fetch UI elements
        var $loading = $('.ladb-loading', this.$widgetBackers);

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
                query: "query members($slug: String) { " +
                        "collective(slug: $slug) { " +
                            "name " +
                            "slug " +
                            "members(offset: " + page * BACKERS_PAGE_SIZE + ", limit: " + BACKERS_PAGE_SIZE + ", role: BACKER, orderBy: { field: CREATED_AT, direction:DESC }) { " +
                                "totalCount " +
                                "nodes { " +
                                    "account { " +
                                        "slug " +
                                        "name " +
                                        "description " +
                                        "imageUrl " +
                                        "website " +
                                    "} " +
                                    "totalDonations { " +
                                        "value " +
                                        "currency " +
                                    "} " +
                                    "publicMessage" +
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

                    var nextPage = ((page + 1) * BACKERS_PAGE_SIZE < response.data.collective.members.totalCount) ? page + 1 : null;

                    // Render members list
                    var $list = $(Twig.twig({ref: 'tabs/sponsor/_members-' + (page === 0 ? '0' : 'n') + '.twig'}).render({
                        members: response.data.collective.members,
                        nextPage: nextPage,
                    }));
                    if (page === 0) {
                        $list.insertBefore($loading);
                    } else {
                        $('#ladb_sponsor_members').append($list);
                    }

                    // Bind button
                    $('.ladb-sponsor-next-page-btn', $list).on('click', function () {
                        that.loadBackers(nextPage);
                        $(this).parent().remove();
                    });

                    // Bind box
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
                $loading.hide();

            },
            error: function(jqXHR, textStatus, errorThrown) {

                // Hide loading
                $loading.hide();

            }
        });

    };

    LadbTabSponsor.prototype.showObjectiveModal = function (objectiveStrippedName, objectiveIcon, objectiveImage, objectiveVideoId) {

        var $modal = this.dialog.appendModal('ladb_sponsor_modal_objective', 'tabs/sponsor/_modal-objective.twig', {
            objectiveStrippedName: objectiveStrippedName ? objectiveStrippedName : 'default',
            objectiveIcon: objectiveIcon ? objectiveIcon : 'default',
            objectiveImage: objectiveImage,
            objectiveVideoId: objectiveVideoId
        });

        // Fetch UI elements
        var $widgetObjective = $('.ladb-sponsor-objective-widget', $modal);
        var $btnSponsor = $('#ladb_sponsor_btn', $modal);

        // Bind objective widget
        this.bindObjectiveWidget($widgetObjective);

        // Bind buttons
        $btnSponsor.on('click', function () {

            // Hide modal
            $modal.modal('hide');

        });

        // Show modal
        $modal.modal('show');

    };

    // Init ///

    LadbTabSponsor.prototype.registerCommands = function () {
        LadbAbstractTab.prototype.registerCommands.call(this);

        var that = this;

        this.registerCommand('show_objective_modal', function (parameters) {
            that.showObjectiveModal(parameters.objectiveStrippedName, parameters.objectiveIcon, parameters.objectiveImage, parameters.objectiveVideoId);
        });

    };

    LadbTabSponsor.prototype.defaultInitializedCallback = function () {
        LadbAbstractTab.prototype.defaultInitializedCallback.call(this);

        this.bindObjectiveWidget(this.$widgetObjective);
        this.loadBackers();

    };


    // PLUGIN DEFINITION
    // =======================

    function Plugin(option, params) {
        return this.each(function () {
            var $this = $(this);
            var data = $this.data('ladb.tab.plugin');
            var options = $.extend({}, LadbTabSponsor.DEFAULTS, $this.data(), typeof option === 'object' && option);

            if (!data) {
                if (undefined === options.dialog) {
                    throw 'dialog option is mandatory.';
                }
                $this.data('ladb.tab.plugin', (data = new LadbTabSponsor(this, options, options.dialog)));
            }
            if (typeof option === 'string') {
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
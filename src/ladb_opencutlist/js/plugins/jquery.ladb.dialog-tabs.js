+function ($) {
    'use strict';

    // CONSTANTS
    // ======================

    var EW_URL = 'https://www.lairdubois.fr/opencutlist';

    var MANIFEST_URL = 'https://www.lairdubois.fr/opencutlist/manifest'
    var MANIFEST_DEV_URL = 'https://www.lairdubois.fr/opencutlist/manifest-dev'

    var SETTING_KEY_MUTED_UPDATE_BUILD = 'core.muted_update_build';
    var SETTING_KEY_LAST_LISTED_NEWS_TIMESTAMP = 'core.last_listed_news_timestamp';

    // CLASS DEFINITION
    // ======================

    var LadbDialogTabs = function (element, options) {
        LadbAbstractDialog.call(this, element, $.extend({
            noty_layout: 'dialogTabs'
        }, options));

        this.zzz = false;

        this.minimizing = false;
        this.maximizing = false;
        this.maximized = false;

        this.activeTabName = null;
        this.$tabs = {};
        this.$tabBtns = {};

        this.$wrapper = null;
        this.$wrapperSlides = null;
        this.$leftbar = null;

    };
    LadbDialogTabs.prototype = Object.create(LadbAbstractDialog.prototype);

    LadbDialogTabs.DEFAULTS = {
        defaultTabName: 'cutlist',
        tabDefs: [
            {
                name: 'materials',
                bar: 'leftbar',
                icon: 'ladb-opencutlist-icon-materials',
                sponsorAd: false
            },
            {
                name: 'cutlist',
                bar: 'leftbar',
                icon: 'ladb-opencutlist-icon-cutlist',
                sponsorAd: true
            },
            {
                name: 'importer',
                bar: 'leftbar',
                icon: 'ladb-opencutlist-icon-import',
                sponsorAd: true
            },
            {
                name: 'tutorials',
                bar: 'leftbar-bottom',
                icon: 'ladb-opencutlist-icon-tutorials',
                sponsorAd: false
            },
            {
                name: 'news',
                bar: null,
                icon: 'ladb-opencutlist-icon-news',
                sponsorAd: false
            },
            {
                name: 'forum',
                bar: null,
                icon: 'ladb-opencutlist-icon-forum',
                sponsorAd: false
            },
            {
                name: 'settings',
                bar: 'bottombar',
                icon: 'ladb-opencutlist-icon-settings',
                sponsorAd: true
            },
            {
                name: 'sponsor',
                bar: 'bottombar',
                icon: 'ladb-opencutlist-icon-sponsor',
                classes: 'ladb-highlighted-sponsor',
                sponsorAd: false
            },
            {
                name: 'about',
                bar: 'bottombar',
                icon: null,
                sponsorAd: false
            }
        ]
    };

    // Manifest /////

    LadbDialogTabs.prototype.loadManifest = function () {
        var that = this;

        if (this.capabilities.manifest == null && this.capabilities.update_available == null) {
            $.getJSON(this.appendOclMetasToUrlQueryParams(this.capabilities.is_dev ? MANIFEST_DEV_URL : MANIFEST_URL), function (data) {

                // Keep manifest data
                that.capabilities.manifest = data;

                // Compare versions
                if (data.build && data.build > that.capabilities.build) {

                    // Flag as update_available
                    that.capabilities.update_available = true;

                    // Check ignored build
                    that.capabilities.update_muted = that.mutedUpdateBuild ? that.mutedUpdateBuild === data.build : false;

                    // Trigger updatable event
                    setTimeout(function () {

                        // Fresh update, notify it
                        if (!that.capabilities.update_muted) {
                            that.$leftbar.ladbLeftbar('pushNotification', [ '#ladb_leftbar_btn_upgrade' ]);
                        } else {
                            that.$leftbar.ladbLeftbar('pushNotification', [ '#ladb_leftbar_btn_upgrade', { muted: true } ]);
                        }

                    }, 1000);

                } else {

                    // Flag as not update_available
                    that.capabilities.update_available = false;
                    that.capabilities.update_muted = false;

                }

                // Send update status to ruby
                rubyCallCommand('core_set_update_status', {
                    manifest: that.capabilities.manifest,
                    update_available: that.capabilities.update_available,
                    update_muted: that.capabilities.update_muted
                });

            }).fail(function(e) {
                that.capabilities.manifest = {}
                that.capabilities.update_available = false;
                that.capabilities.update_muted = false;
            });
        }

    };

    // News /////

    LadbDialogTabs.prototype.checkNews = function () {
        var that = this;

        if (this.capabilities.last_news_timestamp == null) {
            $.ajax({
                url: GRAPHQL_ENDPOINT,
                contentType: 'application/json',
                type: 'POST',
                dataType: 'json',
                data: JSON.stringify({
                    query: "query lastUpdateId($slug: String) { " +
                            "collective(slug: $slug) { " +
                                "updates(limit: 1, onlyPublishedUpdates: true) { " +
                                    "nodes { " +
                                        "publishedAt " +
                                    "}" +
                                "}" +
                            "}" +
                        "}",
                    variables: {
                        slug: GRAPHQL_SLUG
                    }
                }),
                success: function (response) {
                    if (response.data && response.data.collective.updates.nodes.length > 0) {

                        var lastNewsTimestamp = Date.parse(response.data.collective.updates.nodes[0].publishedAt);

                        if (that.lastListedNewsTimestamp == null) {

                            // First run lastListedNewsTimestamp is set to lastNewsTimestamp. In this case current last news do not generate notification.
                            that.setLastListedNewsTimestamp(lastNewsTimestamp);

                        } else if (lastNewsTimestamp > that.lastListedNewsTimestamp) {

                            // Fresh news are available, notify it :)
                            that.$leftbar.ladbLeftbar('pushNotification', ['#ladb_leftbar_btn_news'])

                        }

                        // Save timestamp
                        that.capabilities.last_news_timestamp = lastNewsTimestamp;

                        // Send news status to ruby
                        rubyCallCommand('core_set_news_status', {
                            last_news_timestamp: that.capabilities.last_news_timestamp
                        });

                    }
                },
                error: function (jqXHR, textStatus, errorThrown) {
                    that.capabilities.last_news_timestamp = null;
                }
            });
        }

    };

    LadbDialogTabs.prototype.setLastListedNewsTimestamp = function (lastListedNewsTimestamp) {
        this.lastListedNewsTimestamp = lastListedNewsTimestamp;
        this.setSetting(SETTING_KEY_LAST_LISTED_NEWS_TIMESTAMP, this.lastListedNewsTimestamp);
    }

    // UI /////

    LadbDialogTabs.prototype.setCompact = function (compact) {
        if (compact) {
            $('body').addClass('ladb-table-compact');
        } else {
            $('body').removeClass('ladb-table-compact');
        }
    };

    // Actions /////

    LadbDialogTabs.prototype.minimize = function () {
        var that = this;
        if (that.maximized && !that.minimizing) {
            that.minimizing = true;
            that.$element.trigger(jQuery.Event('minimizing.ladb.dialog'));
            rubyCallCommand('core_tabs_dialog_minimize', null, function () {
                that.minimizing = false;
                Noty.closeAll();
                that.$wrapper.hide();
                that.maximized = false;
                that.$element.trigger(jQuery.Event('minimized.ladb.dialog'));
            });
        }
    };

    LadbDialogTabs.prototype.maximize = function () {
        var that = this;
        if (!that.maximized && !that.maximizing) {
            that.maximizing = true;
            that.$element.trigger(jQuery.Event('maximizing.ladb.dialog'));
            rubyCallCommand('core_tabs_dialog_maximize', null, function () {
                that.maximizing = false;
                that.$wrapper.show();
                that.maximized = true;
                that.$element.trigger(jQuery.Event('maximized.ladb.dialog'));
            });
        }
    };

    LadbDialogTabs.prototype.getTabDef = function (tabName) {
        for (var i = 0; i < this.options.tabDefs.length; i++) {
            var tabDef = this.options.tabDefs[i];
            if (tabDef.name === tabName) {
                return tabDef;
            }
        }
        return null;
    };

    LadbDialogTabs.prototype.getActiveTab = function () {
        return this.$tabs[this.activeTabName];
    };

    LadbDialogTabs.prototype.getActiveTabBtn = function () {
        return this.$tabBtns[this.activeTabName];
    };

    LadbDialogTabs.prototype.getTabPlugin = function ($tab) {
        if ($tab) {
            return $tab.data('ladb.tab.plugin');
        }
    };

    LadbDialogTabs.prototype.unselectActiveTab = function () {
        if (this.activeTabName) {

            // Flag as inactive
            this.getActiveTabBtn().removeClass('ladb-active');
            $('[data-ladb-tab-name="' + this.activeTabName + '"]').removeClass('ladb-active');

            // Hide active tab
            this.getActiveTab().hide();

        }
    };

    LadbDialogTabs.prototype.loadTab = function (tabName, callback) {

        if (this.zzz) {
            return;
        }

        var $tab = this.$tabs[tabName];
        if (!$tab) {

            // Render and append tab
            this.$wrapperSlides.append(Twig.twig({ref: "tabs/" + tabName + "/tab.twig"}).render({
                tabName: tabName,
                capabilities: this.capabilities
            }));

            // Fetch tab
            $tab = $('#ladb_tab_' + tabName, this.$wrapperSlides);

            // Initialize tab (with its jQuery plugin)
            var jQueryPluginFn = 'ladbTab' + tabName.charAt(0).toUpperCase() + tabName.slice(1);
            $tab[jQueryPluginFn]({
                dialog: this,
                initializedCallback: callback
            });

            // Setup tooltips & popovers
            this.setupTooltips();
            this.setupPopovers();

            // Bind help buttons (if exist)
            this.bindHelpButtonsInParent($tab);

            // Cache tab
            this.$tabs[tabName] = $tab;

            // Hide tab
            $tab.hide();

        } else {

            // Callback
            if (typeof callback === 'function') {
                callback($tab);
            }

        }

        return $tab;
    };

    LadbDialogTabs.prototype.selectTab = function (tabName, callback) {

        if (this.zzz) {
            return;
        }

        var $tab = this.$tabs[tabName];
        var $freshTab = false;
        if (tabName !== this.activeTabName) {
            if (this.activeTabName) {
                this.unselectActiveTab();
            }
            if ($tab) {

                $freshTab = false;

            } else {

                $freshTab = true;

                // Load tab
                $tab = this.loadTab(tabName, callback);

            }

            // Display tab
            $tab.show();

            // Flag tab as active
            this.$tabBtns[tabName].addClass('ladb-active');
            $('[data-ladb-tab-name="' + tabName + '"]').addClass('ladb-active');
            this.activeTabName = tabName;

        }

        // By default maximize the dialog
        this.maximize();

        // If fresh tab, callback is invoke through 'initializedCallback'
        if (!$freshTab) {

            // Callback
            if (typeof callback === 'function') {
                callback($tab);
            } else {

                var jQueryPlugin = this.getTabPlugin($tab);
                if (jQueryPlugin && !jQueryPlugin.defaultInitializedCallbackCalled) {
                    jQueryPlugin.defaultInitializedCallback();
                }

            }

        } else {

            // Try to show sponsor ad
            var tabDef = this.getTabDef(tabName);
            if (tabDef && tabDef.sponsorAd && callback === undefined) {
                this.showSponsorAd();
            }

        }

        // Close all Noty
        Noty.closeAll();

        // Trigger event
        if ($tab) {
            $tab.trigger(jQuery.Event('shown.ladb.tab'));
        }

        return $tab;
    };

    LadbDialogTabs.prototype.executeCommandOnTab = function (tabName, command, parameters, callback, keepTabInBackground) {
        var that = this;

        var fnExecute = function ($tab) {
            var jQueryPlugin = that.getTabPlugin($tab);
            if (jQueryPlugin) {
                jQueryPlugin.executeCommand(command, parameters, callback);
            }
        }

        if (keepTabInBackground) {
            this.loadTab(tabName, fnExecute);
        } else {
            this.selectTab(tabName, fnExecute);
        }

    };

    LadbDialogTabs.prototype.showSponsorAd = function () {

        // Render ad in bottombar
        $('#ladb_bottombar').append(Twig.twig({ ref: "tabs/sponsor/_ad.twig" }).render());

        // Auto hide on next mouse down
        $(window).on('mousedown', this.hideSponsorAd);

    };

    LadbDialogTabs.prototype.hideSponsorAd = function () {

        // Remove ad
        $('#ladb_sponsor_ad').remove();

        // Unbind auto hide
        $(window).off('mousedown', this.hideSponsorAd);

    };

    // Modal /////

    LadbDialogTabs.prototype.showUpgradeModal = function () {
        var that = this;

        // Append modal
        var $modal = this.appendModal('ladb_core_modal_upgrade', 'core/_modal-upgrade.twig', {
            capabilities: this.capabilities,
        });

        // Fetch UI elements
        var $panelInfos = $('#ladb_panel_infos', $modal);
        var $panelProgress = $('#ladb_panel_progress', $modal);
        var $footer = $('.modal-footer', $modal);
        var $btnIgnoreUpdate = $('#ladb_btn_ignore_update', $modal);
        var $btnUpgrade = $('#ladb_btn_upgrade', $modal);
        var $btnDownload = $('.ladb-btn-download', $modal);
        var $btnSponsor = $('#ladb_btn_sponsor', $modal);
        var $linkChangelog = $('#ladb_link_changelog', $modal);
        var $progressBar = $('div[role=progressbar]', $modal);

        // Bind buttons
        $btnIgnoreUpdate.on('click', function () {

            that.mutedUpdateBuild = that.capabilities.manifest.build;
            that.setSetting(SETTING_KEY_MUTED_UPDATE_BUILD, that.mutedUpdateBuild);

            that.capabilities.update_muted = true;

            // Send update status to ruby
            rubyCallCommand('core_set_update_status', {
                manifest: that.capabilities.manifest,
                update_available: that.capabilities.update_available,
                update_muted: that.capabilities.update_muted
            });

            // Hide notification badge
            that.$leftbar.ladbLeftbar('muteNotification', [ '#ladb_leftbar_btn_upgrade' ]);

            // Close and remove modal
            $modal.modal('hide');
            $modal.remove();

        });
        $btnUpgrade.on('click', function () {

            $panelInfos.hide();
            $panelProgress.show();
            $footer.hide();

            rubyCallCommand('core_upgrade', { url: that.capabilities.manifest && that.capabilities.manifest.url ? that.appendOclMetasToUrlQueryParams(that.capabilities.manifest.url) : EW_URL }, function (response) {
                if (response.cancelled) {

                    // Close and remove modal
                    $modal.modal('hide');
                    $modal.remove();

                } else {

                    var fnProgress = function (params) {
                        $progressBar.css('width', (params.current / params.total * 100) + '%');
                    };
                    var fnCancelled = function (params) {

                        // Close and remove modal
                        $modal.modal('hide');
                        $modal.remove();

                        // Remove event callbacks
                        removeEventCallback('on_upgrade_progress', fnProgress);
                        removeEventCallback('on_upgrade_cancelled', fnCancelled);

                    }

                    addEventCallback('on_upgrade_progress', fnProgress);
                    addEventCallback('on_upgrade_cancelled', fnCancelled);

                }
            });

            return false;
        });
        $btnDownload.on('click', function () {

            // Open url
            rubyCallCommand('core_open_url', { url: that.capabilities.manifest && that.capabilities.manifest.url ? that.appendOclMetasToUrlQueryParams(that.capabilities.manifest.url) : EW_URL });

            // Close and remove modal
            $modal.modal('hide');
            $modal.remove();

            return false;
        });
        $btnSponsor.on('click', function () {

            // Open sponsor tab
            that.selectTab('sponsor');

            // Close and remove modal
            $modal.modal('hide');
            $modal.remove();

            return false;
        });
        $linkChangelog.on('click', function () {
            rubyCallCommand('core_open_url', { url: that.getChangelogUrl() });
        })

        // Show modal
        $modal.modal('show');

    };

    // Internals /////

    LadbDialogTabs.prototype.bind = function () {
        var that = this;

        // Bind buttons
        $.each(this.$tabBtns, function (tabName, $tabBtn) {
            $tabBtn.on('click', function () {
                that.maximize();
                that.selectTab(tabName);
            });
        });

        // Bind "docs" button
        this.bindHelpButtonsInParent(this.$leftbar);

        // Bind fake tabs
        $('a[data-ladb-tab-name]', this.$element).on('click', function() {
            var tabName = $(this).data('ladb-tab-name');
            that.selectTab(tabName);
        });
        $('#ladb_tab_btn_outliner', this.$element).on('click', function() {

            // Show Objective modal
            that.executeCommandOnTab('sponsor', 'show_objective_modal', {
                objectiveStrippedName: 'outliner',
                objectiveIcon: 'outliner',
                objectiveVideoId: '7iXH7ZBH27k',
            }, null, true);

        });

        // Bind dialog maximized events
        this.$element.on('maximized.ladb.dialog', function() {
            that.loadManifest();
            that.checkNews();
        });

        // Bind validate with enter on modals
        $('body').on('keydown', function (e) {
            if (e.keyCode === 27) {   // "escape" key

                // Dropdown detection
                if ($(e.target).hasClass('dropdown')) {
                    return;
                }

                // CodeMirror dropdown detection
                if ($(e.target).attr('aria-autocomplete') === 'list') {
                    return;
                }

                // Bootstrap select detection
                if ($(e.target).attr('role') === 'listbox' || $(e.target).attr('role') === 'combobox') {
                    return;
                }

                // Try to retrieve the current top modal (1. from global dialog modal, 2. from active tab inner modal)
                var $modal = null;
                if (that._$modal) {
                    $modal = that._$modal;
                } else {
                    var jQueryPlugin = that.getTabPlugin(that.getActiveTab());
                    if (jQueryPlugin) {
                        $modal = jQueryPlugin._$modal;
                    }
                }

                if ($modal) {
                    // A modal is shown, try to click on first "dismiss" button
                    $('[data-dismiss="modal"]', $modal).first().click();
                } else {
                    // No modal, minimize the dialog
                    that.minimize();
                }

            } else if (e.keyCode === 13) {   // Only intercept "enter" key

                var $target = $(e.target);
                if (!$target.is('input[type=text]')) {  // Only intercept if focus is on input[type=text] field
                    return;
                }
                $target.blur(); // Blur target to be sure "change" event occur before

                // Prevent default behavior
                e.preventDefault();

                // Try to retrieve the current top modal (1. from global dialog modal, 2. from active tab inner modal)
                var $modal = null;
                if (that._$modal) {
                    $modal = that._$modal;
                } else {
                    var jQueryPlugin = that.getTabPlugin(that.getActiveTab());
                    if (jQueryPlugin) {
                        $modal = jQueryPlugin._$modal;
                    }
                }

                if ($modal) {
                    var $btnValidate = $('.btn-validate-modal', $modal).first();
                    if ($btnValidate && $btnValidate.is(':enabled')) {
                        $btnValidate.click();
                    }
                }

            }
        });

    };

    LadbDialogTabs.prototype.init = function () {
        LadbAbstractDialog.prototype.init.call(this);

        var that = this;

        this.pullSettings([
                SETTING_KEY_MUTED_UPDATE_BUILD,
                SETTING_KEY_LAST_LISTED_NEWS_TIMESTAMP
            ],
            function () {

                that.mutedUpdateBuild = that.getSetting(SETTING_KEY_MUTED_UPDATE_BUILD, null);
                that.lastListedNewsTimestamp = that.getSetting(SETTING_KEY_LAST_LISTED_NEWS_TIMESTAMP, null);

                // Check if JS build number corresponds to Ruby build number
                if (EXTENSION_BUILD !== that.capabilities.build) {

                    // Flag as sleeping
                    that.zzz = true;

                    // Render and append layout-locked template
                    that.$element.append(Twig.twig({ref: 'core/layout-zzz.twig'}).render());

                    // Fetch useful elements
                    var $btnZzz = $('.ladb-zzz a', that.$element);

                    // Bind button
                    $btnZzz.on('click', function() {
                        alert(i18next.t('core.upgrade.zzz'));
                    });

                } else {

                    // Render and append layout template
                    that.$element.append(Twig.twig({ref: 'core/layout-tabs.twig'}).render({
                        capabilities: that.capabilities,
                        tabDefs: that.options.tabDefs
                    }));

                    // Fetch useful elements
                    that.$wrapper = $('#ladb_wrapper', that.$element);
                    that.$wrapperSlides = $('#ladb_wrapper_slides', that.$element);
                    that.$leftbar = $('#ladb_leftbar', that.$element).ladbLeftbar({ dialog: that });
                    for (var i = 0; i < that.options.tabDefs.length; i++) {
                        var tabDef = that.options.tabDefs[i];
                        that.$tabBtns[tabDef.name] = $('#ladb_tab_btn_' + tabDef.name, that.$element);
                    }

                    // Push desired notifications
                    if (that.capabilities.update_available) {
                        if (that.capabilities.update_muted) {
                            that.$leftbar.ladbLeftbar('pushNotification', [ '#ladb_leftbar_btn_upgrade', { muted: true } ]);
                        } else {
                            that.$leftbar.ladbLeftbar('pushNotification', [ '#ladb_leftbar_btn_upgrade', { silent: true } ]);
                        }
                    }
                    if (that.capabilities.last_news_timestamp > that.lastListedNewsTimestamp) {
                        that.$leftbar.ladbLeftbar('pushNotification', [ '#ladb_leftbar_btn_news', { silent: true } ]);
                    }

                    that.bind();

                    if (that.options.tabs_dialog_table_row_size) {
                        that.setCompact(true);
                    }

                    if (that.options.dialog_startup_tab_name) {
                        that.selectTab(that.options.dialog_startup_tab_name);
                    }

                    // Dev alert
                    var $devAlert = $('#ladb_dev_alert');
                    if ($devAlert.length > 0) {
                        var devAlertTotalTime = 20000;
                        var devAlertRemaining = devAlertTotalTime;
                        var fnDevAlertCountdown = function () {
                            if ($devAlert.is(':visible')) {
                                devAlertRemaining -= 200;
                                $('.countdown-bar', $devAlert).css('width', Math.max((devAlertRemaining / devAlertTotalTime) * 100, 0) + '%');
                                if (devAlertRemaining < 0) {
                                    $devAlert.hide();
                                    return;
                                }
                            }
                            setTimeout(function () {
                                window.requestAnimationFrame(fnDevAlertCountdown);
                            }, 200);
                        }
                        window.requestAnimationFrame(fnDevAlertCountdown);
                    }

                }

            });

    };


    // PLUGIN DEFINITION
    // =======================

    function Plugin(option, params) {
        return this.each(function () {
            var $this = $(this);
            var data = $this.data('ladb.dialog');
            var options = $.extend({}, LadbDialogTabs.DEFAULTS, $this.data(), typeof option === 'object' && option);

            if (!data) {
                $this.data('ladb.dialog', (data = new LadbDialogTabs(this, options)));
            }
            if (typeof option === 'string') {
                data[option].apply(data, Array.isArray(params) ? params : [ params ])
            } else {
                data.init();
            }
        })
    }

    var old = $.fn.ladbDialogTabs;

    $.fn.ladbDialogTabs = Plugin;
    $.fn.ladbDialogTabs.Constructor = LadbDialogTabs;


    // NO CONFLICT
    // =================

    $.fn.ladbDialogTabs.noConflict = function () {
        $.fn.ladbDialogTabs = old;
        return this;
    }

}(jQuery);
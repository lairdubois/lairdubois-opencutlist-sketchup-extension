+function ($) {
    'use strict';

    // CONSTANTS
    // ======================

    var EW_URL = 'https://www.lairdubois.fr/opencutlist';

    var MANIFEST_URL = 'https://www.lairdubois.fr/opencutlist/manifest'
    var MANIFEST_DEV_URL = 'https://www.lairdubois.fr/opencutlist/manifest-dev'

    var DOCS_URL = 'https://www.lairdubois.fr/opencutlist/docs';
    var DOCS_DEV_URL = 'https://www.lairdubois.fr/opencutlist/docs-dev';

    var CHANGELOG_URL = 'https://www.lairdubois.fr/opencutlist/changelog';
    var CHANGELOG_DEV_URL = 'https://www.lairdubois.fr/opencutlist/changelog-dev';

    var SETTING_KEY_MUTED_UPDATE_BUILD = 'core.muted_update_build';
    var SETTING_KEY_LAST_LISTED_NEWS_TIMESTAMP = 'core.last_listed_news_timestamp';

    // CLASS DEFINITION
    // ======================

    var LadbDialog = function (element, options) {
        this.options = options;
        this.$element = $(element);

        this.capabilities = {
            version: options.version,
            build: options.build,
            is_rbz: options.is_rbz,
            is_dev: options.is_dev,
            sketchup_is_pro: options.sketchup_is_pro,
            sketchup_version: options.sketchup_version,
            sketchup_version_number: options.sketchup_version_number,
            ruby_version: options.ruby_version,
            chrome_version: options.chrome_version,
            platform_name: options.platform_name,
            is_64bit: options.is_64bit,
            user_agent: window.navigator.userAgent,
            locale: options.locale,
            language: options.language,
            available_languages: options.available_languages,
            decimal_separator: options.decimal_separator,
            webgl_available: options.webgl_available,
            manifest: options.manifest,
            update_available: options.update_available,
            update_muted: options.update_muted,
            last_news_timestamp: options.last_news_timestamp,
            dialog_print_margin: options.dialog_print_margin,
        };

        this.settings = {};

        this.zzz = false;

        this.minimizing = false;
        this.maximizing = false;
        this.maximized = false;

        this.activeTabName = null;
        this.$tabs = {};
        this.$tabBtns = {};

        this._$modal = null;

        this.$wrapper = null;
        this.$wrapperSlides = null;
        this.$leftbar = null;

    };

    LadbDialog.DEFAULTS = {
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

    LadbDialog.prototype.loadManifest = function () {
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

    LadbDialog.prototype.checkNews = function () {
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

    LadbDialog.prototype.setLastListedNewsTimestamp = function (lastListedNewsTimestamp) {
        this.lastListedNewsTimestamp = lastListedNewsTimestamp;
        this.setSetting(SETTING_KEY_LAST_LISTED_NEWS_TIMESTAMP, this.lastListedNewsTimestamp);
    }

    // Settings /////

    LadbDialog.prototype.pullSettings = function (keys, callback) {
        var that = this;

        // Read settings values from SU default or Model attributes according to the strategy
        rubyCallCommand('core_read_settings', { keys: keys }, function (data) {
            var values = data.values;
            for (var i = 0; i < values.length; i++) {
                var value = values[i];
                that.settings[value.key] = value.value;
            }
            if (typeof callback === 'function') {
                callback();
            }
        });
    };

    LadbDialog.prototype.setSettings = function (settings) {
        for (var i = 0; i < settings.length; i++) {
            var setting = settings[i];
            this.settings[setting.key] = setting.value;
        }
        // Write settings values to SU default or Model attributes according to the strategy
        rubyCallCommand('core_write_settings', { settings: settings });
    };

    LadbDialog.prototype.setSetting = function (key, value) {
        this.setSettings([ { key: key, value: value } ]);
    };

    LadbDialog.prototype.getSetting = function (key, defaultValue) {
        var value = this.settings[key];
        if (value != null) {
            if (defaultValue !== undefined) {
                if (typeof defaultValue === 'number' && isNaN(value)) {
                    return defaultValue;
                }
            }
            return value;
        }
        return defaultValue;
    };

    // Actions /////

    LadbDialog.prototype.minimize = function () {
        var that = this;
        if (that.maximized && !that.minimizing) {
            that.minimizing = true;
            that.$element.trigger(jQuery.Event('minimizing.ladb.dialog'));
            rubyCallCommand('core_dialog_minimize', null, function () {
                that.minimizing = false;
                Noty.closeAll();
                that.$wrapper.hide();
                that.maximized = false;
                that.$element.trigger(jQuery.Event('minimized.ladb.dialog'));
            });
        }
    };

    LadbDialog.prototype.maximize = function () {
        var that = this;
        if (!that.maximized && !that.maximizing) {
            that.maximizing = true;
            that.$element.trigger(jQuery.Event('maximizing.ladb.dialog'));
            rubyCallCommand('core_dialog_maximize', null, function () {
                that.maximizing = false;
                that.$wrapper.show();
                that.maximized = true;
                that.$element.trigger(jQuery.Event('maximized.ladb.dialog'));
            });
        }
    };

    LadbDialog.prototype.getTabDef = function (tabName) {
        for (var i = 0; i < this.options.tabDefs.length; i++) {
            var tabDef = this.options.tabDefs[i];
            if (tabDef.name === tabName) {
                return tabDef;
            }
        }
        return null;
    };

    LadbDialog.prototype.getActiveTab = function () {
        return this.$tabs[this.activeTabName];
    };

    LadbDialog.prototype.getActiveTabBtn = function () {
        return this.$tabBtns[this.activeTabName];
    };

    LadbDialog.prototype.getTabPlugin = function ($tab) {
        if ($tab) {
            return $tab.data('ladb.tab.plugin');
        }
    };

    LadbDialog.prototype.unselectActiveTab = function () {
        if (this.activeTabName) {

            // Flag as inactive
            this.getActiveTabBtn().removeClass('ladb-active');
            $('[data-ladb-tab-name="' + this.activeTabName + '"]').removeClass('ladb-active');

            // Hide active tab
            this.getActiveTab().hide();

        }
    };

    LadbDialog.prototype.loadTab = function (tabName, callback) {

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

    LadbDialog.prototype.selectTab = function (tabName, callback) {

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

    LadbDialog.prototype.executeCommandOnTab = function (tabName, command, parameters, callback, keepTabInBackground) {
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

    LadbDialog.prototype.showSponsorAd = function () {

        // Render ad in bottombar
        $('#ladb_bottombar').append(Twig.twig({ ref: "tabs/sponsor/_ad.twig" }).render());

        // Auto hide on next mouse down
        $(window).on('mousedown', this.hideSponsorAd);

    };

    LadbDialog.prototype.hideSponsorAd = function () {

        // Remove ad
        $('#ladb_sponsor_ad').remove();

        // Unbind auto hide
        $(window).off('mousedown', this.hideSponsorAd);

    };

    // Progress /////

    LadbDialog.prototype.startProgress = function (maxSteps) {

        this.progressMaxSteps = Math.max(1, maxSteps);
        this.progressStep = 0;

        this.$progress = $(Twig.twig({ref: 'core/_progress.twig'}).render({
            hiddenProgressBar: this.progressMaxSteps <= 1
        }));
        this.$progressBar = $('.progress-bar', this.$progress);

        $('body').append(this.$progress);

    };

    LadbDialog.prototype.advanceProgress = function (step) {
        if (this.$progress) {
            this.progressStep = Math.min(this.progressMaxSteps, this.progressStep + step);
            this.$progressBar.css('width', ((this.progressStep / this.progressMaxSteps) * 100) + '%');
        }
    };

    LadbDialog.prototype.finishProgress = function () {
        if (this.$progress) {
            this.$progressBar = null;
            this.progressMaxSteps = 0;
            this.progressStep = 0;
            this.$progress.remove();
        }
    };

    // Modal /////

    LadbDialog.prototype.appendModal = function (id, twigFile, renderParams) {
        var that = this;

        // Hide previously opened modal
        if (this._$modal) {
            this._$modal.modal('hide');
        }

        // Create modal element
        this._$modal = $(Twig.twig({ref: twigFile}).render(renderParams));

        // Bind modal
        this._$modal.on('hidden.bs.modal', function () {
            $(this)
                .data('bs.modal', null)
                .remove();
            that._$modal = null;
            $('input[autofocus]', that._$modal).first().focus();
        });

        // Append modal
        this.$element.append(this._$modal);

        // Bind help buttons (if exist)
        this.bindHelpButtonsInParent(this._$modal);

        return this._$modal;
    };

    LadbDialog.prototype.showUpgradeModal = function () {
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

    LadbDialog.prototype.alert = function (title, text, callback, options) {

        // Append modal
        var $modal = this.appendModal('ladb_core_modal_alert', 'core/_modal-alert.twig', {
            title: title,
            text: text,
            options: options
        });

        // Fetch UI elements
        var $btnOk = $('#ladb_confirm_btn_ok', $modal);

        // Bind buttons
        $btnOk.on('click', function() {

            if (callback) {
                callback();
            }

            // Hide modal
            $modal.modal('hide');

        });

        // Show modal
        $modal.modal('show');

    };

    LadbDialog.prototype.confirm = function (title, text, callback, options) {

        // Append modal
        var $modal = this.appendModal('ladb_core_modal_confirm', 'core/_modal-confirm.twig', {
            title: title,
            text: text,
            options: options
        });

        // Fetch UI elements
        var $btnConfirm = $('#ladb_confirm_btn_confirm', $modal);

        // Bind buttons
        $btnConfirm.on('click', function() {

            if (callback) {
                callback();
            }

            // Hide modal
            $modal.modal('hide');

        });

        // Show modal
        $modal.modal('show');

    };

    LadbDialog.prototype.prompt = function (title, text, value, callback, options) {

        // Append modal
        var $modal = this.appendModal('ladb_core_modal_prompt', 'core/_modal-prompt.twig', {
            title: title,
            text: text,
            value: value,
            options: options
        });

        // Fetch UI elements
        var $input = $('#ladb_prompt_input', $modal);
        var $btnValidate = $('#ladb_prompt_btn_validate', $modal);

        // Bind input
        $input.on('keyup change', function () {
            $btnValidate.prop('disabled', $(this).val().trim().length === 0);
        });

        // Bind buttons
        $btnValidate.on('click', function() {

            if (callback) {
                callback($input.val().trim());
            }

            // Hide modal
            $modal.modal('hide');

        });

        // State
        $btnValidate.prop('disabled', $input.val().trim().length === 0);

        // Show modal
        $modal.modal('show');

        // Bring focus to input
        $input.focus();
        $input[0].selectionStart = $input[0].selectionEnd = $input.val().trim().length;

    };

    LadbDialog.prototype.notify = function (text, type, buttons, timeout) {
        if (undefined === type) {
            type = 'alert';
        }
        if (undefined === buttons) {
            buttons = [];
        }
        if (undefined === timeout) {
            timeout = 5000;
        }
        var n = new Noty({
            type: type,
            layout: 'bottomRight',
            theme: 'bootstrap-v3',
            text: text,
            timeout: timeout,
            buttons: buttons
        }).show();

        return n;
    };

    LadbDialog.prototype.notifyErrors = function (errors) {
        if (Array.isArray(errors)) {
            for (var i = 0; i < errors.length; i++) {
                var error = errors[i];
                var key = error;
                var options = {};
                if (Array.isArray(error) && error.length > 0) {
                    key = error[0];
                    if (error.length > 1) {
                        options = error[1];
                    }
                }
                this.notify('<i class="ladb-opencutlist-icon-warning"></i> ' + i18next.t(key, options), 'error');
            }
        }
    };

    LadbDialog.prototype.notifySuccess = function (text, buttons) {
        this.notify('<i class="ladb-opencutlist-icon-check-mark"></i> ' + text, 'success', buttons);
    };

    LadbDialog.prototype.setupTooltips = function ($element) {
        $('.tooltip').tooltip('hide'); // Assume that previouly created tooltips are closed
        $('[data-toggle="tooltip"]', $element).tooltip({
            container: 'body'
        });
    };

    LadbDialog.prototype.setupPopovers = function ($element) {
        $('[data-toggle="popover"]', $element).popover({
            html: true
        });
    };

    // Utils /////

    LadbDialog.prototype.amountToLocaleString = function (amount, currency) {
        return amount.toLocaleString(this.capabilities.language, {
            style: 'currency',
            currency: currency,
            currencyDisplay: 'symbol',
            minimumFractionDigits: 0,
            maximumFractionDigits: 0
        });
    }

    LadbDialog.prototype.appendOclMetasToUrlQueryParams = function (url, params) {
        url = url + '?v=' + this.capabilities.version + '&build=' + this.capabilities.build + '-' + (this.capabilities.is_rbz ? 'rbz' : 'src') + '&language=' + this.capabilities.language + '&locale=' + this.capabilities.locale;
        if (params && (typeof params  === "object")) {
            for (const property in params) {
                url += '&' + property + '=' + params[property];
            }
        }
        return url
    }

    LadbDialog.prototype.getDocsPageUrl = function (page) {
        return this.appendOclMetasToUrlQueryParams(
            this.capabilities.is_dev ? DOCS_DEV_URL : DOCS_URL,
            (page && (typeof page  === "string")) ? { page: page } : null
        );
    }

    LadbDialog.prototype.getChangelogUrl = function () {
        return this.appendOclMetasToUrlQueryParams(
            this.capabilities.is_dev ? CHANGELOG_DEV_URL : CHANGELOG_URL
        );
    }

    LadbDialog.prototype.bindHelpButtonsInParent = function ($parent) {
        var that = this;
        let $btns = $('[data-help-page]', $parent);
        $btns.on('click', function () {
            let page = $(this).data('help-page');
            $.getJSON(that.getDocsPageUrl(page ? page : ''), function (data) {
                rubyCallCommand('core_open_url', data);
            })
                .fail(function () {
                    that.notifyErrors([
                        'core.docs.error.failed_to_load'
                    ]);
                })
            ;
            $(this).blur();
        });
    }

    LadbDialog.prototype.copyToClipboard = function (text) {
        // Create new element
        var el = document.createElement('textarea');
        // Set value (string to be copied)
        el.value = text;
        // Set non-editable to avoid focus and move outside of view
        el.setAttribute('readonly', '');
        el.style = { position: 'absolute', left: '-9999px' };
        document.body.appendChild(el);
        // Select text inside element
        el.select();
        // Copy text to clipboard
        document.execCommand('copy');
        // Remove temporary element
        document.body.removeChild(el);
    }

    // Internals /////

    LadbDialog.prototype.bind = function () {
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

    LadbDialog.prototype.init = function () {
        var that = this;

        this.pullSettings([
                SETTING_KEY_MUTED_UPDATE_BUILD,
                SETTING_KEY_LAST_LISTED_NEWS_TIMESTAMP
            ],
            function () {

                that.mutedUpdateBuild = that.getSetting(SETTING_KEY_MUTED_UPDATE_BUILD, null);
                that.lastListedNewsTimestamp = that.getSetting(SETTING_KEY_LAST_LISTED_NEWS_TIMESTAMP, null);

                // Add compatible_with twig function
                Twig.extendFunction('compatible_with', function(value) {
                    switch (value) {
                        case 'svg.height-auto':
                            return !($('body').hasClass('ie') || $('body').hasClass('edge'));
                    }
                    return true;
                });

                // Add i18next twig filter
                Twig.extendFilter('i18next', function (value, options) {
                    return i18next.t(value, options ? options[0] : {});
                });
                // Add ... filter
                Twig.extendFilter('url_beautify', function (value) {
                    var parser = document.createElement('a');
                    parser.href = value;
                    var str = '<span class="ladb-url-host">' + parser.host + '</span>';
                    if (parser.pathname && parser.pathname !== '/') {
                        str += '<span class="ladb-url-path">' + parser.pathname + '</span>';
                    }
                    return '<span class="ladb-url">' + str + '</span>';
                });
                Twig.extendFilter('format_currency', function (value, options) {
                    return value.toLocaleString(that.capabilities.language, {
                        style: 'currency',
                        currency: options ? options[0] : 'USD',
                        currencyDisplay: 'symbol',
                        minimumFractionDigits: 0,
                        maximumFractionDigits: 0
                    });
                });
                Twig.extendFilter('sanitize_links', function (value, options) {
                    return value.replace(/<a\s+(?:[^>]*?\s+)?href=(["'])(.*?)\1>/g, '<a href="$2" target="_blank">');
                });
                Twig.extendFilter('type_of', function (value) {
                    return typeof value;
                });
                Twig.extendFilter('trim_tilde', function (value) {
                    if (value.startsWith('~ ')) {
                        return value.slice(2);
                    }
                    return value;
                });

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
                    that.$element.append(Twig.twig({ref: 'core/layout.twig'}).render({
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
            var options = $.extend({}, LadbDialog.DEFAULTS, $this.data(), typeof option === 'object' && option);

            if (!data) {
                $this.data('ladb.dialog', (data = new LadbDialog(this, options)));
            }
            if (typeof option === 'string') {
                data[option].apply(data, Array.isArray(params) ? params : [ params ])
            } else {
                data.init();
            }
        })
    }

    var old = $.fn.ladbDialog;

    $.fn.ladbDialog = Plugin;
    $.fn.ladbDialog.Constructor = LadbDialog;


    // NO CONFLICT
    // =================

    $.fn.ladbDialog.noConflict = function () {
        $.fn.ladbDialog = old;
        return this;
    }

}(jQuery);
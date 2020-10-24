+function ($) {
    'use strict';

    // CONSTANTS
    // ======================

    var SETTING_KEY_COMPATIBILITY_ALERT_HIDDEN = 'compatibility_alert_hidden';

    // CLASS DEFINITION
    // ======================

    var LadbDialog = function (element, options) {
        this.options = options;
        this.$element = $(element);

        this.capabilities = {
            version: options.version,
            build: options.build,
            debug: options.debug,
            sketchupIsPro: options.sketchup_is_pro,
            sketchupVersion: options.sketchup_version,
            sketchupVersionNumber: options.sketchup_version_number,
            rubyVersion: options.ruby_version,
            currentOS: options.current_os,
            is64bit: options.is_64bit,
            userAgent: window.navigator.userAgent,
            locale: options.locale,
            language: options.language,
            availableLanguages: options.available_languages,
            htmlDialogCompatible: options.html_dialog_compatible,
            manifest: options.manifest,
            upgradable: options.upgradable,
            dialogMaximizedWidth: options.dialog_maximized_width,
            dialogMaximizedHeight: options.dialog_maximized_height,
            dialogLeft: options.dialog_left,
            dialogTop: options.dialog_top,
        };

        this.settings = {};

        this.minimizing = false;
        this.maximizing = false;
        this.maximized = false;

        this.activeTabName = null;
        this.tabs = {};
        this.tabBtns = {};

        this._$modal = null;

        this.$wrapper = null;
        this.$wrapperSlides = null;
        this.$leftbarBottom = null;
        this.$btnMinimize = null;
        this.$btnMaximize = null;
        this.$btnUpgrade = null;
        this.$btnCloseCompatibilityAlert = null;
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

        if (this.capabilities.manifest == null && this.capabilities.upgradable == null) {
            $.getJSON((this.capabilities.debug ? MANIFEST_DEV_URL : MANIFEST_URL) + '?v=' + this.capabilities.version, function (data) {

                // Keep manifest data
                that.capabilities.manifest = data;

                // Compare versions
                if (data.build && data.build > that.capabilities.build) {

                    // Flag as upgradable
                    that.capabilities.upgradable = true;

                    // Trigger updatable event
                    setTimeout(function () {
                        that.$element.trigger(jQuery.Event('updatable.ladb.core'));
                    }, 1000);

                } else {

                    // Flag as not upgradable
                    that.capabilities.upgradable = false;

                }

                // Inform ruby that updates was checked
                rubyCallCommand('core_updates_checked', {
                    manifest: that.capabilities.manifest,
                    upgradable: that.capabilities.upgradable
                });

            }).fail(function(e) {
                that.capabilities.manifest = {}
                that.capabilities.upgradable = false;
            });
        }

    };

    // Settings /////

    LadbDialog.prototype.pullSettings = function (keys, strategy, callback) {
        var that = this;

        // Read settings values from SU default or Model attributes according to the strategy
        rubyCallCommand('core_read_settings', { keys: keys, strategy: strategy ? strategy : 0 /* SETTINGS_RW_STRATEGY_GLOBAL */ }, function (data) {
            var values = data.values;
            for (var i = 0; i < values.length; i++) {
                var value = values[i];
                that.settings[value.key] = value.value;
            }
            if (callback && typeof callback == 'function') {
                callback();
            }
        });
    };

    LadbDialog.prototype.setSettings = function (settings, strategy) {
        for (var i = 0; i < settings.length; i++) {
            var setting = settings[i];
            this.settings[setting.key] = setting.value;
        }
        // Write settings values to SU default or Model attributes according to the strategy
        rubyCallCommand('core_write_settings', { settings: settings, strategy: strategy ? strategy : 0 /* SETTINGS_RW_STRATEGY_GLOBAL */ });
    };

    LadbDialog.prototype.setSetting = function (key, value, strategy) {
        this.setSettings([ { key: key, value: value } ], strategy);
    };

    LadbDialog.prototype.getSetting = function (key, defaultValue) {
        var value = this.settings[key];
        if (value != null) {
            if (defaultValue !== undefined) {
                if (typeof(defaultValue) === 'number' && isNaN(value)) {
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
            that.$leftbarBottom.hide();
            rubyCallCommand('core_dialog_minimize', null, function () {
                that.minimizing = false;
                Noty.closeAll();
                that.$wrapper.hide();
                that.$btnMinimize.hide();
                that.$btnMaximize.show();
                that.maximized = false;
                that.$element.trigger(jQuery.Event('minimized.ladb.dialog'));
            });
        }
    };

    LadbDialog.prototype.maximize = function () {
        var that = this;
        if (!that.maximized && !that.maximizing) {
            that.maximizing = true;
            rubyCallCommand('core_dialog_maximize', null, function () {
                that.maximizing = false;
                that.$wrapper.show();
                that.$btnMinimize.show();
                that.$btnMaximize.hide();
                that.$leftbarBottom.show();
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

    LadbDialog.prototype.unselectActiveTab = function () {
        if (this.activeTabName) {

            // Flag as inactive
            this.tabBtns[this.activeTabName].removeClass('ladb-active');

            // Hide active tab
            this.tabs[this.activeTabName].hide();

        }
    };

    LadbDialog.prototype.loadTab = function (tabName, callback) {

        var $tab = this.tabs[tabName];
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

            // Cache tab
            this.tabs[tabName] = $tab;

            // Hide tab
            $tab.hide();

        } else {

            // Callback
            if (callback && typeof(callback) == 'function') {
                callback($tab);
            }

        }

        return $tab;
    };

    LadbDialog.prototype.selectTab = function (tabName, callback) {

        var $tab = this.tabs[tabName];
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
            this.tabBtns[tabName].addClass('ladb-active');
            this.activeTabName = tabName;

        }

        // By default maximize the dialog
        this.maximize();

        // If fresh tab, callback is invoke through 'initializedCallback'
        if (!$freshTab) {

            // Callback
            if (callback && typeof(callback) == 'function') {
                callback($tab);
            } else {

                var jQueryPlugin = $tab.data('ladb.tab.plugin');
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

        var fnExecute = function ($tab) {
            var jQueryPlugin = $tab.data('ladb.tab.plugin');
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

    // Modal /////

    LadbDialog.prototype.appendModal = function (id, twigFile, renderParams) {
        var that = this;

        // Hide previously opened modal
        if (this._$modal) {
            this._$modal.modal('hide');
        }

        // Render modal
        this.$element.append(Twig.twig({ref: twigFile}).render(renderParams));

        // Fetch UI elements
        this._$modal = $('#' + id, this.$element);

        // Bind modal
        this._$modal.on('hidden.bs.modal', function () {
            $(this)
                .data('bs.modal', null)
                .remove();
        });

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
        var $btnUpgrade = $('#ladb_btn_upgrade', $modal);
        var $btnDownload = $('#ladb_btn_download', $modal);
        var $btnSponsor = $('#ladb_btn_sponsor', $modal);
        var $progressBar = $('div[role=progressbar]', $modal);

        // Bind buttons
        $btnUpgrade.on('click', function() {

            $panelInfos.hide();
            $panelProgress.show();
            $footer.hide();

            rubyCallCommand('core_upgrade', { url: that.capabilities.manifest && that.capabilities.manifest.url ? that.capabilities.manifest.url + '?v=' + that.capabilities.version : EW_URL }, function (response) {
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
        $btnDownload.on('click', function() {

            // Open url
            rubyCallCommand('core_open_url', { url: that.capabilities.manifest && that.capabilities.manifest.url ? that.capabilities.manifest.url : EW_URL });

            // Close and remove modal
            $modal.modal('hide');
            $modal.remove();

            return false;
        });
        $btnSponsor.on('click', function() {

            // Open sponsor tab
            that.selectTab('sponsor');

            // Close and remove modal
            $modal.modal('hide');
            $modal.remove();

            return false;
        });

        // Show modal
        $modal.modal('show');

    };

    LadbDialog.prototype.notify = function (text, type, buttons, timeout) {
        if (undefined === type) {
            type = 'alert';
        }
        if (undefined === buttons) {
            buttons = [];
        }
        if (undefined === timeout) {
            timeout = 3000;
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

    LadbDialog.prototype.setupTooltips = function () {
        $('.tooltip').tooltip('hide'); // Assume that previouly created tooltips are closed
        $('[data-toggle="tooltip"]').tooltip({
            container: 'body'
        });
    };

    LadbDialog.prototype.setupPopovers = function () {
        $('[data-toggle="popover"]').popover({
            html: true
        });
    };

    LadbDialog.prototype.amountToLocaleString = function (amount, currency) {
        return amount.toLocaleString(this.capabilities.language, {
            style: 'currency',
            currency: currency,
            currencyDisplay: 'symbol',
            minimumFractionDigits: 0,
            maximumFractionDigits: 0
        });
    }

    // Internals /////

    LadbDialog.prototype.bind = function () {
        var that = this;

        // Bind buttons
        this.$btnMinimize.on('click', function () {
            that.minimize();
        });
        this.$btnMaximize.on('click', function () {
            that.maximize();
            if (!that.activeTabName) {
                that.selectTab(that.options.defaultTabName);
            }
        });
        $.each(this.tabBtns, function (tabName, $tabBtn) {
            $tabBtn.on('click', function () {
                that.maximize();
                that.selectTab(tabName);
            });
        });
        this.$btnUpgrade.on('click', function() {
            that.showUpgradeModal();
        });
        this.$btnCloseCompatibilityAlert.on('click', function () {
            $('#ladb_compatibility_alert').hide();
            that.compatibilityAlertHidden = true;
            that.setSetting(SETTING_KEY_COMPATIBILITY_ALERT_HIDDEN, that.compatibilityAlertHidden);
        });
        $('#ladb_btn_more .ladb-subbar-toggle', this.$element).mouseover(function () {
            $('.badge.badge-notification', this).removeClass('ladb-bounce-y');
        });

        // Bind fake tabs
        $('a[data-ladb-tab-name]', this.$element).on('click', function() {
            var tabName = $(this).data('ladb-tab-name');
            that.selectTab(tabName);
        });

        // Bind dialog maximized events
        this.$element.on('maximized.ladb.dialog', function() {
            that.loadManifest();
        });

        // Bind core updatable events
        this.$element.on('updatable.ladb.core', function() {
            $('#ladb_btn_more .ladb-subbar-toggle .badge.badge-notification', that.$element)
                .addClass('ladb-bounce-y')
            $('#ladb_btn_more .badge.badge-notification', that.$element)
                .show();
            rubyCallCommand('core_play_sound', {
                filename: 'wav/notification.wav'
            });
        });

    };

    LadbDialog.prototype.init = function () {
        var that = this;

        this.pullSettings([
                SETTING_KEY_COMPATIBILITY_ALERT_HIDDEN
            ],
            0 /* SETTINGS_RW_STRATEGY_GLOBAL */,
            function () {

                that.compatibilityAlertHidden = that.getSetting(SETTING_KEY_COMPATIBILITY_ALERT_HIDDEN, false);

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
                        currency: options.currency ? options.currency : 'USD',
                        currencyDisplay: 'symbol',
                        minimumFractionDigits: 0,
                        maximumFractionDigits: 0
                    });
                });

                // Render and append layout template
                that.$element.append(Twig.twig({ref: 'core/layout.twig'}).render({
                    capabilities: that.capabilities,
                    compatibilityAlertHidden: that.compatibilityAlertHidden,
                    tabDefs: that.options.tabDefs
                }));

                // Fetch usefull elements
                that.$wrapper = $('#ladb_wrapper', that.$element);
                that.$wrapperSlides = $('#ladb_wrapper_slides', that.$element);
                that.$btnMinimize = $('#ladb_btn_minimize', that.$element);
                that.$btnMaximize = $('#ladb_btn_maximize', that.$element);
                that.$leftbarBottom = $('.ladb-leftbar-bottom', that.$element);
                that.$btnUpgrade = $('#ladb_btn_upgrade', that.$element);
                that.$btnCloseCompatibilityAlert = $('#ladb_btn_close_compatibility_alert', that.$element);
                for (var i = 0; i < that.options.tabDefs.length; i++) {
                    var tabDef = that.options.tabDefs[i];
                    that.tabBtns[tabDef.name] = $('#ladb_tab_btn_' + tabDef.name, that.$element);
                }

                that.bind();

                if (that.options.dialog_startup_tab_name) {
                    that.selectTab(that.options.dialog_startup_tab_name);
                }

            });

    };


    // PLUGIN DEFINITION
    // =======================

    function Plugin(option, params) {
        return this.each(function () {
            var $this = $(this);
            var data = $this.data('ladb.dialog');
            var options = $.extend({}, LadbDialog.DEFAULTS, $this.data(), typeof option == 'object' && option);

            if (!data) {
                $this.data('ladb.dialog', (data = new LadbDialog(this, options)));
            }
            if (typeof option == 'string') {
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
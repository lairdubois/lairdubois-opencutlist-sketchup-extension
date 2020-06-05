+function ($) {
    'use strict';

    // CONSTANTS
    // ======================

    var EW_URL = 'https://extensions.sketchup.com/extension/00f0bf69-7a42-4295-9e1c-226080814e3e/opencutlist';

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
            available_languages: options.available_languages,
            htmlDialogCompatible: options.html_dialog_compatible,
            dialogMaximizedWidth: options.dialog_maximized_width,
            dialogMaximizedHeight: options.dialog_maximized_height,
            dialogLeft: options.dialog_left,
            dialogTop: options.dialog_top
        };

        this.manifest = null;
        this.upgradable = false;

        this.settings = {};

        this.minimizing = false;
        this.maximizing = false;
        this.maximized = false;

        this.activeTabName = null;
        this.tabs = {};
        this.tabBtns = {};

        this.$wrapper = null;
        this.$wrapperSlides = null;
        this.$btnMinimize = null;
        this.$btnMaximize = null;
        this.$btnMore = null;
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

        if (this.manifest == null) {
            $.getJSON('https://github.com/lairdubois/lairdubois-opencutlist-sketchup-extension/raw/master/dist/manifest' + (this.capabilities.debug ? '-dev' : '') + '.json', function (data) {

                // Keep manifest data
                that.manifest = data;

                var fnCompareBuild = function(b1, b2) {
                    if (b1 === b2) {
                        return 0;
                    }
                    if (parseInt(b1) > parseInt(b2)) {
                        return 1;
                    } else {
                        return -1
                    }
                }
                var fnCompareVersion = function(v1, v2, b1, b2) {
                    if (v1 === v2) {
                        return fnCompareBuild(b1, b2);
                    }

                    var v1_components = v1.split(".");
                    var v2_components = v2.split(".");

                    var len = Math.min(v1_components.length, v2_components.length);

                    // Loop while the components are equal
                    for (var i = 0; i < len; i++) {
                        if (parseInt(v1_components[i]) > parseInt(v2_components[i])) {
                            return 1;
                        }
                        if (parseInt(v1_components[i]) < parseInt(v2_components[i])) {
                            return -1;
                        }
                    }

                    // If one's a prefix of the other, the longer one is greater.
                    if (v1_components.length > v2_components.length) {
                        return 1;
                    }

                    if (v1_components.length < v2_components.length) {
                        return -1;
                    }

                    // Otherwise they are the same.
                    return fnCompareBuild(b1, b2);
                }

                // Compare versions
                if (data.version) {
                    var len = data.version.indexOf('-');    // Remove possible '-dev'
                    var version = data.version.substring(0, len === -1 ? data.version.length : len);
                    if (data.build && fnCompareVersion(version, that.capabilities.version, data.build, that.capabilities.build) > 0) {

                        // Flag as upgradable
                        that.upgradable = true;

                        // Trigger updatable event
                        that.$element.trigger(jQuery.Event('updatable.ladb.core'));

                    }
                }

            }).fail(function(e) {
                that.manifest = {}
                that.upgradable = false;
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
            rubyCallCommand('core_dialog_minimize', null, function () {
                that.minimizing = false;
                Noty.closeAll();
                that.$wrapper.hide();
                that.$btnMinimize.hide();
                that.$btnMaximize.show();
                that.$btnMore.hide();
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
                that.$btnMore.show();
                that.maximized = true;
                that.$element.trigger(jQuery.Event('maximized.ladb.dialog'));
            });
        }
    };

    LadbDialog.prototype.unselectActiveTab = function () {
        if (this.activeTabName) {

            // Flag as inactive
            this.tabBtns[this.activeTabName].removeClass('ladb-active');

            // Hide active tab
            this.tabs[this.activeTabName].hide();

        }
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

                // Display tab
                $tab.show();

            } else {

                $freshTab = true;

                // Render and append tab
                this.$wrapperSlides.append(Twig.twig({ ref: "tabs/" + tabName + "/tab.twig" }).render({
                    tabName: tabName,
                    capabilities: this.capabilities
                }));

                // Fetch tab
                $tab = $('#ladb_tab_' + tabName, this.$wrapperSlides);

                // Initialize tab (with its jQuery plugin)
                var jQueryPluginFn = 'ladbTab' + tabName.charAt(0).toUpperCase() + tabName.slice(1);
                $tab[jQueryPluginFn]({
                    opencutlist: this,
                    initializedCallback: callback
                });

                // Setup tooltips & popovers
                this.setupTooltips();
                this.setupPopovers();

                // Cache tab
                this.tabs[tabName] = $tab;

            }

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

    LadbDialog.prototype.executeCommandOnTab = function (tabName, command, parameters, callback) {

        // Select tab and execute command
        this.selectTab(tabName, function ($tab) {
            var jQueryPlugin = $tab.data('ladb.tab' + tabName.charAt(0).toUpperCase() + tabName.slice(1));
            if (jQueryPlugin) {
                jQueryPlugin.executeCommand(command, parameters, callback);
            }
        });

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

    LadbDialog.prototype.showUpgradeModal = function () {
        var that = this;

        // Render modal
        this.$element.append(Twig.twig({ref: 'core/_modal-upgrade.twig'}).render({
            capabilities: this.capabilities,
            manifest: this.manifest,
            upgradable: this.upgradable,
        }));

        // Fetch UI elements
        var $modal = $('#ladb_core_modal_upgrade');
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

            rubyCallCommand('core_upgrade', { url: that.manifest && that.manifest.url ? that.manifest.url : EW_URL }, function (response) {
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
            rubyCallCommand('core_open_url', { url: that.manifest && that.manifest.url ? that.manifest.url : EW_URL });

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

    // Internals /////

    LadbDialog.prototype.getTabDef = function (tabName) {
        for (var i = 0; i < this.options.tabDefs.length; i++) {
            var tabDef = this.options.tabDefs[i];
            if (tabDef.name === tabName) {
                return tabDef;
            }
        }
        return null;
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
            $('#ladb_btn_more .badge.badge-notification', that.$element).show();
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
                Twig.extendFilter("i18next", function (value, options) {
                    return i18next.t(value, options ? options[0] : {});
                });
                // Add ... filter
                Twig.extendFilter("url_beautify", function (value, options) {
                    var parser = document.createElement('a');
                    parser.href = value;
                    var str = '<span class="ladb-url-host">' + parser.host + '</span>';
                    if (parser.pathname && parser.pathname !== '/') {
                        str += '<span class="ladb-url-path">' + parser.pathname + '</span>';
                    }
                    return '<span class="ladb-url">' + str + '</span>';
                });

                // Render and append layout template
                that.$element.append(Twig.twig({ref: "core/layout.twig"}).render({
                    capabilities: that.capabilities,
                    compatibilityAlertHidden: that.compatibilityAlertHidden,
                    tabDefs: that.options.tabDefs
                }));

                // Fetch usefull elements
                that.$wrapper = $('#ladb_wrapper', that.$element);
                that.$wrapperSlides = $('#ladb_wrapper_slides', that.$element);
                that.$btnMinimize = $('#ladb_btn_minimize', that.$element);
                that.$btnMaximize = $('#ladb_btn_maximize', that.$element);
                that.$btnMore = $('#ladb_btn_more', that.$element);
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
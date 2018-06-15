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
            sketchupIsPro: options.sketchup_is_pro,
            sketchupVersion: options.sketchup_version,
            rubyVersion: options.ruby_version,
            currentOS: options.current_os,
            is64bit: options.is_64bit,
            userAgent: window.navigator.userAgent,
            locale: options.locale,
            language: options.language,
            htmlDialogCompatible: options.html_dialog_compatible
        };

        this.settings = {};

        this.maximized = false;

        this.activeTabName = null;
        this.tabs = {};
        this.tabBtns = {};

        this.$wrapper = null;
        this.$btnMinimize = null;
        this.$btnMaximize = null;
        this.$btnCloseCompatibilityAlert = null;
    };

    LadbDialog.DEFAULTS = {
        defaultTabName: 'cutlist',
        tabDefs: [
            {
                name: 'materials',
                bar: 'leftbar',
                icon: 'ladb-opencutlist-icon-materials'
            },
            {
                name: 'cutlist',
                bar: 'leftbar',
                icon: 'ladb-opencutlist-icon-cutlist'
            },
            {
                name: 'about',
                bar: 'bottombar',
                icon: null
            }
        ]
    };

    // Settings /////

    LadbDialog.prototype.pullSettings = function (keys, strategy, callback) {
        var that = this;

        // Read settings values from SU default or Model attributes according to the strategy
        rubyCallCommand('core_read_settings', { keys: keys, strategy: strategy ? strategy : 0 /* SETTINGS_RW_STRATEGY_GLOBAL */ }, function(data) {
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
        if (value) {
            if (defaultValue != undefined) {
                if (typeof(defaultValue) == 'number' && isNaN(value)) {
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
        if (that.maximized) {
            rubyCallCommand('core_dialog_minimize', null, function () {
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
        if (!that.maximized) {
            rubyCallCommand('core_dialog_maximize', null, function() {
                that.$wrapper.show();
                that.$btnMinimize.show();
                that.$btnMaximize.hide();
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
        var $tab = null;
        var $freshTab = false;
        if (tabName != this.activeTabName) {
            if (this.activeTabName) {
                this.unselectActiveTab();
            }
            $tab = this.tabs[tabName];
            if ($tab) {

                $freshTab = false;

                // Display tab
                $tab.show();

            } else {

                $freshTab = true;

                // Render and append tab
                this.$wrapper.append(Twig.twig({ ref: "tabs/" + tabName + "/tab.twig" }).render({
                    tabName: tabName,
                    capabilities: this.capabilities
                }));

                // Fetch tab
                $tab = $('#ladb_tab_' + tabName, this.$wrapper);

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

        }

        // Trigger event
        if ($tab) {
            $tab.trigger(jQuery.Event('shown.ladb.tab'));
        }

        return $tab;
    };

    LadbDialog.prototype.executeCommandOnTab = function(tabName, command, parameters, callback) {

        // Select tab and execute command
        this.selectTab(tabName, function($tab) {
            var jQueryPlugin = $tab.data('ladb.tab' + tabName.charAt(0).toUpperCase() + tabName.slice(1));
            if (jQueryPlugin) {
                jQueryPlugin.executeCommand(command, parameters, callback);
            }
        });

    };

    // Internals /////

    LadbDialog.prototype.notify = function(text, type, buttons, timeout) {
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

    LadbDialog.prototype.notifyErrors = function(errors) {
        if (Array.isArray(errors)) {
            for (var i = 0; i < errors.length; i++) {
                this.notify('<i class="ladb-opencutlist-icon-warning"></i> ' + i18next.t(errors[i]), 'error');
            }
        }
    };

    LadbDialog.prototype.setupTooltips = function() {
        $('[data-toggle="tooltip"]').tooltip({
            container: 'body'
        });
    };

    LadbDialog.prototype.setupPopovers = function() {
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
        this.$btnCloseCompatibilityAlert.on('click', function () {
            $('#ladb_compatibility_alert').hide();
            that.compatibilityAlertHidden = true;
            that.setSetting(SETTING_KEY_COMPATIBILITY_ALERT_HIDDEN, that.compatibilityAlertHidden);
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

                // Render and append layout template
                that.$element.append(Twig.twig({ref: "core/layout.twig"}).render({
                    capabilities: that.capabilities,
                    compatibilityAlertHidden: that.compatibilityAlertHidden,
                    tabDefs: that.options.tabDefs
                }));

                // Fetch usefull elements
                that.$wrapper = $('#ladb_wrapper', that.$element);
                that.$btnMinimize = $('#ladb_btn_minimize', that.$element);
                that.$btnMaximize = $('#ladb_btn_maximize', that.$element);
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
                data[option](params);
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
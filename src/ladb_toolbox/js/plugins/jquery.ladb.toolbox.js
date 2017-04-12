+function ($) {
    'use strict';

    // CONSTANTS
    // ======================

    var SETTING_KEY_COMPATIBILITY_ALERT_HIDDEN = 'compatibility_alert_hidden';

    // CLASS DEFINITION
    // ======================

    var LadbToolbox = function (element, options) {
        this.options = options;
        this.$element = $(element);

        this.capabilities = {
            version: options.version,
            sketchupVersion: options.sketchup_version,
            currentOS: options.current_os,
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

    LadbToolbox.DEFAULTS = {
        defaultTabName: 'cutlist',
        tabDefs: [
            {
                name: 'cutlist',
                bar: 'leftbar',
                icon: 'ladb-toolbox-icon-cutlist'
            },
            {
                name: 'materials',
                bar: 'leftbar',
                icon: 'ladb-toolbox-icon-materials'
            },
            {
                name: 'about',
                bar: 'bottombar',
                icon: null
            }
        ]
    };

    // Settings /////

    LadbToolbox.prototype.pullSettings = function (keys, callback) {
        var that = this;

        rubyCallCommand('core_read_settings', { keys: keys }, function(data) {          // Read settings values from SU default
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

    LadbToolbox.prototype.setSettings = function (settings) {
        for (var i = 0; i < settings.length; i++) {
            var setting = settings[i];
            this.settings[setting.key] = setting.value;
        }
        rubyCallCommand('core_write_settings', { settings: settings });                 // Write settings values to SU default
    };

    LadbToolbox.prototype.setSetting = function (key, value) {
        this.setSettings([ { key: key, value: value } ]);
    };

    LadbToolbox.prototype.getSetting = function (key, defaultValue) {
        var value = this.settings[key];
        if (value != null) {
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

    LadbToolbox.prototype.minimize = function () {
        var that = this;
        if (that.maximized) {

            // Unbind window.onresize
            window.onresize = undefined;

            rubyCallCommand('core_dialog_minimize', null, function () {
                that.$wrapper.hide();
                that.$btnMinimize.hide();
                that.$btnMaximize.show();
                that.maximized = false;
            });
        }
    };

    LadbToolbox.prototype.maximize = function () {
        var that = this;
        if (!that.maximized) {
            rubyCallCommand('core_dialog_maximize', null, function() {
                that.$wrapper.show();
                that.$btnMinimize.show();
                that.$btnMaximize.hide();
                that.maximized = true;

                if (that.capabilities.htmlDialogCompatible) {

                    // Bind window.onresize
                    window.onresize = function () {
                        var windowWidth = $(window).width();
                        var windowHeight = $(window).height();
                        if (windowWidth > 0 && windowHeight > 0) {
                            rubyCallCommand('core_dialog_resized', {
                                width: windowWidth + that.frameBorderW,
                                height: windowHeight + that.frameBorderH
                            });
                        }
                    };

                }

            });
        }
    };

    LadbToolbox.prototype.unselectActiveTab = function () {
        if (this.activeTabName) {

            // Flag as inactive
            this.tabBtns[this.activeTabName].removeClass('ladb-active');

            // Hide active tab
            this.tabs[this.activeTabName].hide();

        }
    };

    LadbToolbox.prototype.selectTab = function (tabName) {
        if (tabName != this.activeTabName) {
            if (this.activeTabName) {
                this.unselectActiveTab();
            }
            var $tab = this.tabs[tabName];
            if ($tab) {

                // Display tab
                $tab.show();

                // Flag tab as active
                this.tabBtns[tabName].addClass('ladb-active');
                this.activeTabName = tabName;

            } else {

                // Render and append tab
                this.$wrapper.append(Twig.twig({ ref: "tabs/" + tabName + "/tab.twig" }).render({
                    tabName: tabName,
                    capabilities: this.capabilities
                }));

                // Fetch tab
                $tab = $('#ladb_tab_' + tabName, this.$wrapper);

                // Initialize tab (with its jQuery plugin)
                var jQueryPluginFn = 'ladbTab' + tabName.charAt(0).toUpperCase() + tabName.slice(1);
                $tab[jQueryPluginFn]({ toolbox: this });

                // Setup tooltips & popovers
                this.setupTooltips();
                this.setupPopovers();

                // Cache tab
                this.tabs[tabName] = $tab;

                // Flag tab as active
                this.tabBtns[tabName].addClass('ladb-active');
                this.activeTabName = tabName;

            }
        }

        // By default maximize the dialog
        this.maximize();
    };

    // Internals /////

    LadbToolbox.prototype.notify = function(text, type, buttons) {
        if (type == undefined) {
            type = 'alert';
        }
        if (buttons == undefined) {
            buttons = [];
        }
        var n = new Noty({
            type: type,
            layout: 'bottomRight',
            theme: 'bootstrap-v3',
            text: text,
            timeout: 3000,
            buttons: buttons
        }).show();

        return n;
    };

    LadbToolbox.prototype.setupTooltips = function() {
        $('[data-toggle="tooltip"]').tooltip({
            container: 'body'
        });
    };

    LadbToolbox.prototype.setupPopovers = function() {
        $('[data-toggle="popover"]').popover({
            html: true
        });
    };

    LadbToolbox.prototype.bind = function () {
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

    LadbToolbox.prototype.init = function () {
        var that = this;

        // Compute dialog frame borders
        this.frameBorderW = Math.max(0, this.options.dialog_startup_size.width - $(window).width());
        this.frameBorderH = Math.max(0, this.options.dialog_startup_size.height - $(window).height());

        this.pullSettings([
            SETTING_KEY_COMPATIBILITY_ALERT_HIDDEN
        ], function() {

            that.compatibilityAlertHidden = that.getSetting(SETTING_KEY_COMPATIBILITY_ALERT_HIDDEN, false);

            // Add i18next twig filter
            Twig.extendFilter("i18next", function(value, options) {
                return i18next.t(value, options ? options[0] : {});
            });

            // Render and append layout template
            that.$element.append(Twig.twig({ ref: "core/layout.twig" }).render({
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
            var data = $this.data('ladb.toolbox');
            var options = $.extend({}, LadbToolbox.DEFAULTS, $this.data(), typeof option == 'object' && option);

            if (!data) {
                $this.data('ladb.toolbox', (data = new LadbToolbox(this, options)));
            }
            if (typeof option == 'string') {
                data[option](params);
            } else {
                data.init();
            }
        })
    }

    var old = $.fn.ladbToolbox;

    $.fn.ladbToolbox = Plugin;
    $.fn.ladbToolbox.Constructor = LadbToolbox;


    // NO CONFLICT
    // =================

    $.fn.ladbToolbox.noConflict = function () {
        $.fn.ladbToolbox = old;
        return this;
    }

}(jQuery);
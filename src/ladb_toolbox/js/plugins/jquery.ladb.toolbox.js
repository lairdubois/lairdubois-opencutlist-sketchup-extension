+function ($) {
    'use strict';

    // CLASS DEFINITION
    // ======================

    var LadbToolbox = function (element, settings) {
        this.settings = settings;
        this.$element = $(element);

        this.capabilities = {
            version: settings.version,
            sketchupVersion: settings.sketchup_version,
            currentOS: settings.current_os,
            locale: settings.locale,
            language: settings.language,
            htmlDialogCompatible: settings.html_dialog_compatible
        };

        this.compatibilityAlertHidden = this.getSettingsValue('compatibilityAlertHidden', false);

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

    LadbToolbox.prototype.setSettingsValue = function (key, value) {
        if (typeof(Storage) !== "undefined" && localStorage != undefined) {
            localStorage.setItem('ladb_toolbox_' + key, value);
        }
    };

    LadbToolbox.prototype.getSettingsValue = function (key, defaultValue) {
        if (typeof(Storage) !== "undefined" && localStorage != undefined) {
            var value = localStorage.getItem('ladb_toolbox_' + key);
            if (value) {
                if (defaultValue != undefined) {
                    if (typeof(defaultValue) == 'boolean') {
                        return 'true' == value;
                    } else if (typeof(defaultValue) == 'number' && isNaN(value)) {
                        return defaultValue;
                    }
                }
                return value;
            }
        }
        return defaultValue;
    };

    LadbToolbox.prototype.minimize = function () {
        var that = this;
        rubyCallCommand('dialog_minimize', null, function() {
            that.$wrapper.hide();
            that.$btnMinimize.hide();
            that.$btnMaximize.show();
        });
    };

    LadbToolbox.prototype.maximize = function () {
        var that = this;
        rubyCallCommand('dialog_maximize', null, function() {
            that.$wrapper.show();
            that.$btnMinimize.show();
            that.$btnMaximize.hide();
        });
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

                // Cache tab
                this.tabs[tabName] = $tab;

                // Flag tab as active
                this.tabBtns[tabName].addClass('ladb-active');
                this.activeTabName = tabName;

            }
        }
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
                that.selectTab(that.settings.defaultTabName);
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
            that.setSettingsValue('compatibilityAlertHidden', that.compatibilityAlertHidden);
        });

    };

    LadbToolbox.prototype.init = function () {
        var that = this;

        // Init i18next
        $('<script>')
            .attr('src', '../js/i18n/' + this.capabilities.language + '.js')
            .appendTo('body');

        // Continue with a timeout to be sure that translations are loaded
        setTimeout(function() {

            // Add i18next twig filter
            Twig.extendFilter("i18next", function(value, options) {
                return i18next.t(value, options ? options[0] : {});
            });

            // Render and append layout template
            that.$element.append(Twig.twig({ ref: "core/layout.twig" }).render({
                capabilities: that.capabilities,
                compatibilityAlertHidden: that.compatibilityAlertHidden,
                tabDefs: that.settings.tabDefs
            }));

            // Fetch usefull elements
            that.$wrapper = $('#ladb_wrapper', that.$element);
            that.$btnMinimize = $('#ladb_btn_minimize', that.$element);
            that.$btnMaximize = $('#ladb_btn_maximize', that.$element);
            that.$btnCloseCompatibilityAlert = $('#ladb_btn_close_compatibility_alert', that.$element);
            for (var i = 0; i < that.settings.tabDefs.length; i++) {
                var tabDef = that.settings.tabDefs[i];
                that.tabBtns[tabDef.name] = $('#ladb_tab_btn_' + tabDef.name, that.$element);
            }

            that.bind();

        }, 1);

    };


    // PLUGIN DEFINITION
    // =======================

    function Plugin(setting, params) {
        return this.each(function () {
            var $this = $(this);
            var data = $this.data('ladb.toolbox');
            var settings = $.extend({}, LadbToolbox.DEFAULTS, $this.data(), typeof setting == 'object' && setting);

            if (!data) {
                $this.data('ladb.toolbox', (data = new LadbToolbox(this, settings)));
            }
            if (typeof settings == 'string') {
                data[settings](params);
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
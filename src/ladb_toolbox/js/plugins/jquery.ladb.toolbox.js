+function ($) {
    'use strict';

    // CLASS DEFINITION
    // ======================

    var LadbToolbox = function (element, options) {
        this.options = options;
        this.$element = $(element);

        this.activeTabName = null;
        this.tabs = {};
        this.tabBtns = {};

        this.$wrapper = null;
        this.$btnMinimize = null;
        this.$btnMaximize = null;
    };

    LadbToolbox.DEFAULTS = {
        version: '0.0.0',
        htmlDialogCompatible: true,
        defaultTabName: 'cutlist',
        tabDefs: [
            {
                name: 'cutlist',
                icon: 'glyphicon glyphicon-list-alt',
                label: 'Débit'
            }/*,
            {
                name: 'materials',
                icon: 'glyphicon glyphicon-leaf',
                label: 'Matières'
            }*/
        ]
    };

    LadbToolbox.prototype.rubyCall = function (fn, params) {
        window.location.href = "skp:" + fn + "@" + JSON.stringify(params);
    };

    LadbToolbox.prototype.getTabDef = function (tabName) {
        var tabDef;
        for (var i = 0; i < this.options.tabDefs.length; i++) {
            tabDef = this.options.tabDefs[i];
            if (tabDef.name == tabName) {
                return tabDef;
            }
        }
    };

    LadbToolbox.prototype.minimize = function () {
        this.rubyCall('ladb_minimize', null);
        this.$wrapper.hide();
        this.$btnMinimize.hide();
        this.$btnMaximize.show();
    };

    LadbToolbox.prototype.maximize = function () {
        this.rubyCall('ladb_maximize', null);
        this.$wrapper.show();
        this.$btnMinimize.show();
        this.$btnMaximize.hide();
    };

    LadbToolbox.prototype.selectTab = function (tabName) {
        if (tabName != this.activeTabName) {
            if (this.activeTabName) {

                // Flag as inactive
                this.tabBtns[this.activeTabName].removeClass('ladb-active');

                // Hide active tab
                this.tabs[this.activeTabName].hide();

            }
            var $tab = this.tabs[tabName];
            if ($tab) {

                // Display tab
                $tab.show();

                // Flag tab as active
                this.tabBtns[tabName].addClass('ladb-active');
                this.activeTabName = tabName;

            } else {
                var that = this;
                Twig.twig({
                    href: "../twig/tabs/" + tabName + "/tab.twig",
                    load: function (template) {

                        // Render and append tab
                        that.$wrapper.append(template.render({
                            tabName: tabName
                        }));

                        // Fetch tab
                        var $tab = $('#ladb_tab_' + tabName, that.$wrapper);

                        // Initialize tab (with its jQuery plugin)
                        var jQueryPluginFn = 'ladbTab' + tabName.charAt(0).toUpperCase() + tabName.slice(1);
                        $tab[jQueryPluginFn]();

                        // Store tab
                        that.tabs[tabName] = $tab;

                        // Flag tab as active
                        that.tabBtns[tabName].addClass('ladb-active');
                        that.activeTabName = tabName;
                    }
                });
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
                that.selectTab(that.options.defaultTabName);
            }
        });
        $.each(this.tabBtns, function(tabName, tabBtn){
            tabBtn.on('click', function () {
                that.maximize();
                that.selectTab(tabName);
            });
        })

    };

    LadbToolbox.prototype.init = function () {
        var that = this;

        // Twig lib workaround (Check twig.js @5421:52)
        window.cordova = 1;

        // Build layout
        Twig.twig({
            href: "../twig/core/layout.twig",
            load: function (template) {

                // Render and append template
                that.$element.append(template.render({
                    version: that.options.version,
                    htmlDialogCompatible: that.options.htmlDialogCompatible,
                    tabDefs: that.options.tabDefs
                }));

                // Fetch usefull elements
                that.$wrapper = $('#ladb_wrapper', that.$element);
                that.$btnMinimize = $('#ladb_btn_minimize', that.$element);
                that.$btnMaximize = $('#ladb_btn_maximize', that.$element);
                for (var i = 0; i < that.options.tabDefs.length; i++) {
                    var tabDef = that.options.tabDefs[i];
                    that.tabBtns[tabDef.name] = $('#ladb_btn_' + tabDef.name, that.$element);
                }

                that.bind();
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
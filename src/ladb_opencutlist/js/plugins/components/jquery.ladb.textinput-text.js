+function ($) {
    'use strict';

    // CLASS DEFINITION
    // ======================

    const LadbTextinputText = function(element, options) {
        LadbTextinputAbstract.call(this, element, options);
    };
    LadbTextinputText.prototype = new LadbTextinputAbstract;

    LadbTextinputText.DEFAULTS = $.extend( {
    }, LadbTextinputAbstract.DEFAULTS);

    LadbTextinputText.prototype.createLeftToolsContainer = function ($toolContainer) {
        // Do not create left tools container
    };

    LadbTextinputText.prototype.init = function () {
        LadbTextinputAbstract.prototype.init.call(this);

        let that = this;

        if (this.options.autocomplete) {

            const autocompleteOptions = this.options.autocomplete;
            $.widget("ui.autocomplete", $.ui.autocomplete, {
                _create: function () {
                    this._super();
                    this.widget().menu("option", "items", "> :not(.ui-autocomplete-category)");
                },
                _renderMenu: function (ul, items) {
                    items = items.sort(function (a, b) {
                        if (typeof a == 'object' && typeof b == 'object') {
                            if (a.category > b.category) {
                                return 1;
                            } else if (a.category < b.category) {
                                return -1;
                            }
                            if (a.label > b.label) {
                                return 1;
                            } else if (a.label < b.label) {
                                return -1;
                            }
                            return 0;
                        }
                        return a > b ? 1 : a === b ? 0 : -1;
                    })
                    const uiAutocomplete = this;
                    let currentCategory = "";
                    $.each(items, function (index, item) {
                        let li;
                        if (item.category) {
                            if (item.category !== currentCategory) {
                                let categoryIcon = '';
                                if (autocompleteOptions.categoryIcon) {
                                    categoryIcon = '<i class="ladb-opencutlist-icon-' + autocompleteOptions.categoryIcon + '"></i> ';
                                }
                                ul.append('<li class="ui-autocomplete-category">' + categoryIcon + item.category + "</li>");
                                currentCategory = item.category;
                            }
                        }
                        li = uiAutocomplete._renderItemData(ul, item);
                        if (item.category) {
                            li.attr("aria-label", item.category + " : " + item.label);
                            li.find('div').css('padding-left', '24px');
                        }
                        if (item.icon) {
                            li.find('div').prepend('<i class="ladb-opencutlist-icon-' + item.icon + '"' + (item.color ? ' style="color:' + item.color + '"' : '') + '></i> ');
                        }
                    });
                },
            });

            if (this.options.autocomplete.minLength === 0) {
                this.$element.on('focus', function() {
                    $(this).autocomplete('search');
                });
            }

            this.$element.autocomplete(this.options.autocomplete);
            this.$element.on('autocompletechange', function () {
                that.$element.trigger('change');
            })

        }

    };


    // PLUGIN DEFINITION
    // =======================

    function Plugin(option, params) {
        let value;
        const elements = this.each(function () {
            const $this = $(this);
            let data = $this.data('ladb.textinputText');
            if (!data) {
                const options = $.extend({}, LadbTextinputText.DEFAULTS, $this.data(), typeof option === 'object' && option);
                $this.data('ladb.textinputText', (data = new LadbTextinputText(this, options)));
            }
            if (typeof option === 'string') {
                value = data[option].apply(data, Array.isArray(params) ? params : [ params ])
            } else {
                data.init();
            }
        });
        return typeof value !== 'undefined' ? value : elements;
    }

    const old = $.fn.ladbTextinputText;

    $.fn.ladbTextinputText             = Plugin;
    $.fn.ladbTextinputText.Constructor = LadbTextinputText;


    // NO CONFLICT
    // =================

    $.fn.ladbTextinputText.noConflict = function () {
        $.fn.ladbTextinputText = old;
        return this;
    }

}(jQuery);
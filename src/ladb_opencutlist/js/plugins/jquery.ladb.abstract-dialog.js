'use strict';

// CONSTANTS
// ======================

var DOCS_URL = 'https://www.lairdubois.fr/opencutlist/docs';
var DOCS_DEV_URL = 'https://www.lairdubois.fr/opencutlist/docs-dev';

var CHANGELOG_URL = 'https://www.lairdubois.fr/opencutlist/changelog';
var CHANGELOG_DEV_URL = 'https://www.lairdubois.fr/opencutlist/changelog-dev';

function LadbAbstractDialog(element, options) {
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
        tabs_dialog_print_margin: options.tabs_dialog_print_margin,
        tabs_dialog_table_row_size: options.tabs_dialog_table_row_size,
    };

    this.settings = {};

    this._$modal = null;

}

// Settings /////

LadbAbstractDialog.prototype.pullSettings = function (keys, callback) {
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

LadbAbstractDialog.prototype.setSettings = function (settings) {
    for (var i = 0; i < settings.length; i++) {
        var setting = settings[i];
        this.settings[setting.key] = setting.value;
    }
    // Write settings values to SU default or Model attributes according to the strategy
    rubyCallCommand('core_write_settings', { settings: settings });
};

LadbAbstractDialog.prototype.setSetting = function (key, value) {
    this.setSettings([ { key: key, value: value } ]);
};

LadbAbstractDialog.prototype.getSetting = function (key, defaultValue) {
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

// Progress /////

LadbAbstractDialog.prototype.startProgress = function (maxSteps) {

    this.progressMaxSteps = Math.max(1, maxSteps);
    this.progressStep = 0;

    this.$progress = $(Twig.twig({ref: 'core/_progress.twig'}).render({
        hiddenProgressBar: this.progressMaxSteps <= 1
    }));
    this.$progressBar = $('.progress-bar', this.$progress);

    $('body').append(this.$progress);

};

LadbAbstractDialog.prototype.advanceProgress = function (step) {
    if (this.$progress) {
        this.progressStep = Math.min(this.progressMaxSteps, this.progressStep + step);
        this.$progressBar.css('width', ((this.progressStep / this.progressMaxSteps) * 100) + '%');
    }
};

LadbAbstractDialog.prototype.finishProgress = function () {
    if (this.$progress) {
        this.$progressBar = null;
        this.progressMaxSteps = 0;
        this.progressStep = 0;
        this.$progress.remove();
    }
};

// Modal /////

LadbAbstractDialog.prototype.appendModal = function (id, twigFile, renderParams) {
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

LadbAbstractDialog.prototype.alert = function (title, text, callback, options) {

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

LadbAbstractDialog.prototype.confirm = function (title, text, callback, options) {

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

LadbAbstractDialog.prototype.prompt = function (title, text, value, callback, options) {

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

// Notify /////

LadbAbstractDialog.prototype.notify = function (text, type, buttons, timeout) {
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
        layout: this.options.noty_layout,
        theme: 'bootstrap-v3',
        text: text,
        timeout: timeout,
        buttons: buttons
    }).show();

    return n;
};

LadbAbstractDialog.prototype.notifyErrors = function (errors) {
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

LadbAbstractDialog.prototype.notifySuccess = function (text, buttons) {
    this.notify('<i class="ladb-opencutlist-icon-check-mark"></i> ' + text, 'success', buttons);
};

// Tooltips & Popovers /////

LadbAbstractDialog.prototype.setupTooltips = function ($element) {
    $('.tooltip').tooltip('hide'); // Assume that previouly created tooltips are closed
    $('[data-toggle="tooltip"]', $element).tooltip({
        container: 'body'
    });
};

LadbAbstractDialog.prototype.setupPopovers = function ($element) {
    $('[data-toggle="popover"]', $element).popover({
        html: true
    });
};

// Utils /////

LadbAbstractDialog.prototype.amountToLocaleString = function (amount, currency) {
    return amount.toLocaleString(this.capabilities.language, {
        style: 'currency',
        currency: currency,
        currencyDisplay: 'symbol',
        minimumFractionDigits: 0,
        maximumFractionDigits: 0
    });
}

LadbAbstractDialog.prototype.appendOclMetasToUrlQueryParams = function (url, params) {
    url = url + '?v=' + this.capabilities.version + '&build=' + this.capabilities.build + '-' + (this.capabilities.is_rbz ? 'rbz' : 'src') + '&language=' + this.capabilities.language + '&locale=' + this.capabilities.locale;
    if (params && (typeof params  === "object")) {
        for (const property in params) {
            url += '&' + property + '=' + params[property];
        }
    }
    return url
}

LadbAbstractDialog.prototype.getDocsPageUrl = function (page) {
    return this.appendOclMetasToUrlQueryParams(
        this.capabilities.is_dev ? DOCS_DEV_URL : DOCS_URL,
        (page && (typeof page  === "string")) ? { page: page } : null
    );
}

LadbAbstractDialog.prototype.getChangelogUrl = function () {
    return this.appendOclMetasToUrlQueryParams(
        this.capabilities.is_dev ? CHANGELOG_DEV_URL : CHANGELOG_URL
    );
}

LadbAbstractDialog.prototype.bindHelpButtonsInParent = function ($parent) {
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

LadbAbstractDialog.prototype.copyToClipboard = function (text, notifySuccess) {
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
    // Notify success
    if (notifySuccess !== false) {
        this.notifySuccess(i18next.t('core.success.copied_to_clipboard'));
    }
}

LadbAbstractDialog.prototype.measureText = function (text, fontSize /* default = 14 */, fontName /* default = 'sans-serif' */) {
    let canvas = this.canvas || (this.canvas = document.createElement('canvas'));
    let context = canvas.getContext('2d');
    if (fontSize === undefined) fontSize = 14
    if (fontName === undefined) fontName = 'sans-serif'
    context.font = fontSize + 'pt ' + fontName;
    let metrics = context.measureText(text);
    return metrics.width;
}

// Init /////

LadbAbstractDialog.prototype.init = function () {

    var that = this;

    // Add compatible_with twig function
    Twig.extendFunction('compatible_with', function(value) {
        switch (value) {
            case 'svg.height-auto':
                return !($('body').hasClass('ie') || $('body').hasClass('edge'));
        }
        return true;
    });
    Twig.extendFunction('blend_colors', function (color1, color2, percentage) {

        // Code from : https://coderwall.com/p/z8uxzw/javascript-color-blender

        /*
            convert a Number to a two character hex string
            must round, or we will end up with more digits than expected (2)
            note: can also result in single digit, which will need to be padded with a 0 to the left
            @param: num         => the number to conver to hex
            @returns: string    => the hex representation of the provided number
        */
        var fnIntToHex = function (num) {
            var hex = Math.round(num).toString(16);
            if (hex.length === 1)
                hex = '0' + hex;
            return hex;
        }


        // check input
        color1 = color1 || '#000000';
        color2 = color2 || '#ffffff';
        percentage = Math.max(0, Math.min(percentage, 1.0)) || 0.5;

        // 1: validate input, make sure we have provided a valid hex
        if (color1.length !== 4 && color1.length !== 7) {
            throw new Error('colors must be provided as hexes');
        }

        if (color2.length !== 4 && color2.length !== 7) {
            throw new Error('colors must be provided as hexes');
        }

        // 2: check to see if we need to convert 3 char hex to 6 char hex, else slice off hash
        //      the three character hex is just a representation of the 6 hex where each character is repeated
        //      ie: #060 => #006600 (green)
        if (color1.length === 4)
            color1 = color1[1] + color1[1] + color1[2] + color1[2] + color1[3] + color1[3];
        else
            color1 = color1.substring(1);
        if (color2.length === 4)
            color2 = color2[1] + color2[1] + color2[2] + color2[2] + color2[3] + color2[3];
        else
            color2 = color2.substring(1);

        // 3: we have valid input, convert colors to rgb
        color1 = [parseInt(color1[0] + color1[1], 16), parseInt(color1[2] + color1[3], 16), parseInt(color1[4] + color1[5], 16)];
        color2 = [parseInt(color2[0] + color2[1], 16), parseInt(color2[2] + color2[3], 16), parseInt(color2[4] + color2[5], 16)];

        // 4: blend
        var color3 = [
            (1 - percentage) * color1[0] + percentage * color2[0],
            (1 - percentage) * color1[1] + percentage * color2[1],
            (1 - percentage) * color1[2] + percentage * color2[2]
        ];

        // 5: convert to hex
        color3 = '#' + fnIntToHex(color3[0]) + fnIntToHex(color3[1]) + fnIntToHex(color3[2]);

        // return hex
        return color3;
    });
    Twig.extendFunction('mesure_text', function(text, fontSize, fontName) {
        return that.measureText(text, fontSize, fontName);
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

}

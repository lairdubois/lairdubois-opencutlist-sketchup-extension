+function ($) {
    'use strict';

    // CLASS DEFINITION
    // ======================

    const LadbTextinputFile = function(element, options) {
        LadbTextinputAbstract.call(this, element, options);

        this.$display = null;
        this.$displayDir = null;
        this.$displayName = null;
    };
    LadbTextinputFile.prototype = new LadbTextinputAbstract;

    LadbTextinputFile.DEFAULTS = $.extend( {
        library: false      // If true, the browsed file is copied into OCL's asset library and stored as a portable '$LIB/…' ref
    }, LadbTextinputAbstract.DEFAULTS);

    LadbTextinputFile.prototype.val = function (value) {
        const val =  LadbTextinputAbstract.prototype.val.call(this, value);
        if (value !== undefined) {
            this.updateDisplay();
            this.scrollToTheEnd();
        }
        return val;
    };

    LadbTextinputFile.prototype.createLeftToolsContainer = function ($toolContainer) {
        // Do not create left tools container
    };

    // Splits a path into its folders part and its file name, keeping only the
    // first and the last folder when there are more than two.
    LadbTextinputFile.prototype.splitValue = function (value) {
        const segments = value.split(/[\/\\]/);
        const name = segments.pop();
        if (segments.length === 0) {
            return { dir: '', name: name };     // Not a path (a definition or a material name)
        }
        const separator = value.indexOf('/') === -1 ? '\\' : '/';
        let root = '';
        if (segments[0] === '') {
            segments.shift();                   // Absolute path : the leading separator is kept as root
            root = separator;
        }
        let dirs = segments;
        if (dirs.length === 0) {
            return { dir: root, name: name };   // File at the root
        }
        if (dirs.length > 2) {
            dirs = [ dirs[0], '…', dirs[dirs.length - 1] ];
        }
        return { dir: root + dirs.join(separator) + separator, name: name };
    };

    // The full value is only displayed while editing. The rest of the time an
    // abbreviated version is overlaid on the input, with the file name highlighted.
    LadbTextinputFile.prototype.updateDisplay = function () {
        if (this.$display === null) {
            return;
        }
        const value = this.$element.val();
        if (value === '' || this.$element.is(':focus')) {
            this.$wrapper.removeClass('ladb-textinput-file-collapsed');
            return;
        }
        const parts = this.splitValue(value);
        this.$displayDir.text(parts.dir);
        this.$displayName.text(parts.name);
        this.$display.attr('title', value);
        this.$wrapper.addClass('ladb-textinput-file-collapsed');
    };

    LadbTextinputFile.prototype.appendRightTools = function ($toolsContainer) {
        const that = this;

        const $browseBtn =
            $('<div class="ladb-textinput-tool ladb-textinput-tool-btn ladb-btn-browse" tabindex="-1" data-toggle="tooltip" title="' + i18next.t(that.options.library ? 'core.component.textinput_file.browse_library' : 'core.component.textinput_file.browse') + '"><i class="ladb-opencutlist-icon-folder-open"></i></div>')
                .on('click', function() {
                    rubyCallCommand(that.options.library ? 'core_browse_library_file' : 'core_browse_file', {  title: i18next.t('default.open'),  file_path: that.val() }, function (response) {
                        if (response.file_path !== '') {
                           that.val(response.file_path);
                        }
                    });
                })
        ;

        $toolsContainer.append($browseBtn);

        LadbTextinputAbstract.prototype.appendRightTools.call(this, $toolsContainer);
    };

    LadbTextinputFile.prototype.init = function () {
        LadbTextinputAbstract.prototype.init.call(this);

        const that = this;

        this.$wrapper.addClass('ladb-textinput-file');

        this.$displayDir = $('<span class="ladb-textinput-file-display-dir" />');
        this.$displayName = $('<span class="ladb-textinput-file-display-name" />');
        this.$display = $('<div class="ladb-textinput-file-display" />')
            .append(this.$displayDir)
            .append(this.$displayName)
            .appendTo(this.$inputWrapper)
        ;

        this.$element
            .on('focus', function () {
                that.$wrapper.removeClass('ladb-textinput-file-collapsed');
                that.scrollToTheEnd();
            })
            .on('blur change input', function () {
                that.updateDisplay();
            })
        ;

        this.updateDisplay();
        this.scrollToTheEnd();

    };


    // PLUGIN DEFINITION
    // =======================

    function Plugin(option, params) {
        let value;
        const elements = this.each(function () {
            const $this = $(this);
            let data = $this.data('ladb.textinputText');
            if (!data) {
                const options = $.extend({}, LadbTextinputFile.DEFAULTS, $this.data(), typeof option === 'object' && option);
                $this.data('ladb.textinputText', (data = new LadbTextinputFile(this, options)));
            }
            if (typeof option === 'string') {
                value = data[option].apply(data, Array.isArray(params) ? params : [ params ])
            } else {
                data.init();
            }
        });
        return typeof value !== 'undefined' ? value : elements;
    }

    const old = $.fn.ladbTextinputFile;

    $.fn.ladbTextinputFile             = Plugin;
    $.fn.ladbTextinputFile.Constructor = LadbTextinputFile;


    // NO CONFLICT
    // =================

    $.fn.ladbTextinputFile.noConflict = function () {
        $.fn.ladbTextinputFile = old;
        return this;
    }

}(jQuery);

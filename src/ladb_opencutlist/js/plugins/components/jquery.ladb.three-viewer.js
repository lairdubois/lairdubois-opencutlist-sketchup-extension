+function ($) {
    'use strict';

    // CLASS DEFINITION
    // ======================

    var LadbThreeViewer = function (element, options, dialog) {
        this.options = options;
        this.$element = $(element);
        this.dialog = dialog;

        this.$iframe = $('iframe', this.$element);

    };

    LadbThreeViewer.DEFAULTS = {
        autoload: true,
        modelDef: null,
        partsColored: false,
        partsOpacity: 1.0,
        pinsHidden: false,
        pinsColored: false,
        pinsRounded: true,
        pinsText: 0,        // PINS_TEXT_NUMBER
        pinsLength: 1,      // PINS_LENGTH_SHORT
        pinsDirection: 4,   // PINS_DIRECTION_MODEL_CENTER
        cameraView: null,
        cameraZoom: null,
        cameraTarget: null,
        explodeFactor: 0,
        showBoxHelper: false,
    };

    LadbThreeViewer.prototype.callCommand = function (command, params, callback) {
        var that = this;
        if (callback !== undefined) {
            var fnCallback = function (e) {
                callback(e.data);
                that.$iframe.get(0).removeEventListener('callback.' + command, fnCallback);
            }
            this.$iframe.get(0).addEventListener('callback.' + command, fnCallback);
        }
        this.$iframe.get(0).contentWindow.postMessage({
            command: command,
            params: params
        }, '*');
    };

    LadbThreeViewer.prototype.loadFrame = function () {
        this.$iframe.attr('src', 'viewer.html');
    };

    LadbThreeViewer.prototype.destroy = function () {
        $('input[data-command]', this.$element).slider('destroy');
    };

    LadbThreeViewer.prototype.bind = function () {
        var that = this;

        // Bind iframe
        this.$iframe
            .on('load', function () {

                that.callCommand(
                    'setup_model',
                    {
                        modelDef: that.options.modelDef,
                        partsColored: that.options.partsColored,
                        partsOpacity: that.options.partsOpacity,
                        pinsHidden: that.options.pinsHidden,
                        pinsColored: that.options.pinsColored,
                        pinsRounded: that.options.pinsRounded,
                        pinsText: that.options.pinsText,
                        pinsLength: that.options.pinsLength,
                        pinsDirection: that.options.pinsDirection,
                        cameraView: that.options.cameraView,
                        cameraZoom: that.options.cameraZoom,
                        cameraTarget: that.options.cameraTarget,
                        explodeFactor: that.options.explodeFactor,
                    }
                );
                if (that.options.showBoxHelper) {
                    that.callCommand(
                        'set_box_helper_visible',
                        {
                            visible: true,
                        }
                    );
                }

            });

        this.$iframe.get(0).addEventListener('changed.controls', function (e) {

            // Update buttons status
            $('[data-command="set_view"]', that.$element).each(function (index, el) {
                var $btn = $(el);
                var params = $btn.data('params');
                if (JSON.stringify(params.view) === JSON.stringify(e.data.cameraView)) {
                    $btn.addClass('active');
                } else {
                    $btn.removeClass('active');
                }
            });
            $('[data-command="set_zoom"]', that.$element).each(function (index, el) {
                var $btn = $(el);
                var params = $btn.data('params');
                if (params.zoom === e.data.cameraZoom || params.zoom == null && e.data.cameraZoomIsAuto) {
                    $btn.addClass('active');
                } else {
                    $btn.removeClass('active');
                }
            });

            // Update slider status
            $('[data-command="set_explode_factor"]', that.$element).each(function (index, el) {
                var $input = $(el);
                $input.slider('setValue', e.data.explodeFactor);
            });

            // Forward event
            that.$element.trigger('changed.controls', [ e.data ]);

        });
        this.$iframe.get(0).addEventListener('changed.helpers', function (e) {

            // Update buttons status
            $('[data-command="set_box_helper_visible"]', that.$element).each(function (index, el) {
                var $btn = $(el);
                var params = $btn.data('params');
                if (params.visible == null && e.data.boxHelperVisible) {
                    $btn.addClass('active');
                } else {
                    $btn.removeClass('active');
                }
            });
            $('[data-command="set_box_dimensions_helper_visible"]', that.$element).each(function (index, el) {
                var $btn = $(el);
                var params = $btn.data('params');
                if (params.visible == null && e.data.boxDimensionsHelperVisible) {
                    $btn.addClass('active');
                } else {
                    $btn.removeClass('active');
                }
            });
            $('[data-command="set_axes_helper_visible"]', that.$element).each(function (index, el) {
                var $btn = $(el);
                var params = $btn.data('params');
                if (params.visible == null && e.data.axesHelperVisible) {
                    $btn.addClass('active');
                } else {
                    $btn.removeClass('active');
                }
            });

            // Forward event
            that.$element.trigger('changed.helpers', [ e.data ]);

        });

        // Bind buttons
        $('button[data-command]', this.$element).on('click', function () {
            this.blur();
            var command = $(this).data('command');
            var params = $(this).data('params');
            that.callCommand(command, params);
        });

        // Bind sliders
        $('input[data-command]', this.$element).on('change', function () {
            this.blur();
            var command = $(this).data('command');
            var paramName = $(this).data('param-name');
            var params = {};
            params[paramName] = $(this).slider('getValue');
            that.callCommand(command, params);
        });

        if (this.options.modelDef.part_instance_count <= 1) {
            $('[data-command="set_explode_factor"]', this.$element).closest('.ladb-three-viewer-explode-factor-slider-wrapper').hide();
        }

    };

    LadbThreeViewer.prototype.init = function () {

        this.bind();
        this.dialog.setupTooltips(this.$element);

        if (this.options.autoload) {
            this.loadFrame();
        }

        $('input[data-command]', this.$element).slider(SLIDER_OPTIONS);

    };

    // PLUGIN DEFINITION
    // =======================

    function Plugin(option, params) {
        var value;
        var elements = this.each(function () {
            var $this = $(this);
            var data = $this.data('ladb.threeviewer');
            var options = $.extend({}, LadbThreeViewer.DEFAULTS, $this.data(), typeof option === 'object' && option);

            if (!data) {
                if (undefined === options.dialog) {
                    throw 'dialog option is mandatory.';
                }
                $this.data('ladb.threeviewer', (data = new LadbThreeViewer(this, options, options.dialog)));
            }
            if (typeof option === 'string') {
                value = data[option].apply(data, Array.isArray(params) ? params : [ params ])
            } else {
                data.init(params);
            }
        });
        return typeof value !== 'undefined' ? value : elements;
    }

    var old = $.fn.ladbThreeViewer;

    $.fn.ladbThreeViewer = Plugin;
    $.fn.ladbThreeViewer.Constructor = LadbThreeViewer;


    // NO CONFLICT
    // =================

    $.fn.ladbThreeViewer.noConflict = function () {
        $.fn.ladbThreeViewer = old;
        return this;
    }

}(jQuery);
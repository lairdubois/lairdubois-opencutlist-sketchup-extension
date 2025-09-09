'use strict';

function LadbAbstractTab(element, options, dialog) {
    this.options = options;
    this.$element = $(element);
    this.dialog = dialog;

    this.defaultInitializedCallbackCalled = false;

    this._commands = {};

    this._$modal = null;

    this.$rootSlide = $('.ladb-slide', this.$element).first();
    this._$slides = [ this.$rootSlide ];

    this._obsolete = false;
}

// Init /////

LadbAbstractTab.prototype.init = function (initializedCallback) {

    // Register commands
    this.registerCommands();

    // Bind element
    this.bind();

    // Callback
    this.processInitializedCallback(initializedCallback);

};

LadbAbstractTab.prototype.registerCommands = function () {
    // Override to implements
};

LadbAbstractTab.prototype.bind = function () {
    const that = this;

    const fnComputeStuckSlideHeadersWidth = function (event) {

        // Recompute stuck slides header width
        $('.ladb-slide:visible', that.$element).each(function (index) {
            that.computeStuckSlideHeaderWidth($(this));
        });

    };

    // Bind window resize event
    $(window).on('resize', fnComputeStuckSlideHeadersWidth);

    // Bind dialog maximized and minimized events
    this.dialog.$element.on('maximized.ladb.dialog', fnComputeStuckSlideHeadersWidth);

    // Bind tab shown events
    this.$element.on('shown.ladb.tab', fnComputeStuckSlideHeadersWidth);

};

LadbAbstractTab.prototype.processInitializedCallback = function (initializedCallback) {
    if (initializedCallback && typeof(initializedCallback) === 'function') {
        initializedCallback(this.$element);
    } else {
        this.defaultInitializedCallback();
    }
};

LadbAbstractTab.prototype.defaultInitializedCallback = function () {
    this.defaultInitializedCallbackCalled = true;
};

// Slide /////

LadbAbstractTab.prototype.topSlide = function () {
    if (this._$slides.length > 0) {
        return this._$slides[this._$slides.length - 1];
    }
    return null;
};

LadbAbstractTab.prototype.pushNewSlide = function (id, twigFile, renderParams, callback) {

    // Check if top slide has the same id
    const $topSlide = this.topSlide();
    if ($topSlide.attr('id') === id) {
        $topSlide.attr('id', id + '_obsolete');
        $topSlide.data('remove-after-animation', true);
    }

    // Render slide
    this.$element.append(Twig.twig({ref: twigFile}).render(renderParams));

    // Fetch UI elements
    const $slide = $('#' + id, this.$element).first();

    return this.pushSlide($slide, callback);
};

LadbAbstractTab.prototype.pushSlide = function ($slide, callback) {
    const that = this;

    const $topSlide = this.topSlide();

    // Push in slides stack
    this._$slides.push($slide);

    // Bind help buttons (if exist)
    this.dialog.bindHelpButtonsInParent($slide);

    // Animation
    $slide.addClass('animated');
    $slide.switchClass('out', 'in', {
        duration: 300,
        complete: function () {
            $slide.removeClass('animated');
            that.stickSlideHeader($slide);
            if ($topSlide) {
                $topSlide.hide();
                if ($topSlide.data('remove-after-animation')) {
                    that.removeSlide($topSlide);
                }
            }
            if (typeof callback === 'function') {
                callback();
            }
        }
    });

    return $slide;
};

LadbAbstractTab.prototype.popToRootSlide = function () {
    if (this._$slides.length > 2) {
        // Remove hidden slides
        const $removedSlides = this._$slides.splice(1, this._$slides.length - 2);
        for (let i = 0; i < $removedSlides.length; i++) {
            $removedSlides[i].remove(); // Remove from DOM
        }
    }
    this.popSlide(true);
};

LadbAbstractTab.prototype.popSlide = function (noAnimation) {
    if (this._$slides.length > 1) {
        const $poppedSlide = this._$slides.pop();
        const $topSlide = this.topSlide();
        if ($topSlide) {
            $topSlide.show();
            this.computeStuckSlideHeaderWidth($topSlide);
        }
        if (noAnimation) {
            $poppedSlide.remove();
        } else {
            this.unstickSlideHeader($poppedSlide);
            $poppedSlide.addClass('animated');
            $poppedSlide.switchClass('in', 'out', {
                duration: 300,
                complete: function () {
                    $poppedSlide
                        .removeClass('animated')
                        .remove();
                }
            });
        }
    }
};

LadbAbstractTab.prototype.removeSlide = function ($slide) {
    const $removedSlides = this._$slides.splice(this._$slides.indexOf($slide), 1);    // Remove from slide stack
    if ($removedSlides.length > 0) {
        $removedSlides[0].remove(); // Remove from DOM
    }
};

LadbAbstractTab.prototype.stickSlideHeader = function ($slide) {
    const $headerWrapper = $('.ladb-header-wrapper', $slide).first();
    const $header = $('.ladb-header', $slide).first();
    const $container = $('.ladb-container', $slide).first();
    const outerWidth = $container.outerWidth();
    const outerHeight = $header.outerHeight();
    $headerWrapper
        .css('height', outerHeight);
    $header
        .css('width', outerWidth)
        .addClass('stuck');
};

LadbAbstractTab.prototype.unstickSlideHeader = function ($slide) {
    const $headerWrapper = $('.ladb-header-wrapper', $slide).first();
    const $header = $('.ladb-header', $slide).first();
    $headerWrapper
        .css('height', 'auto');
    $header
        .css('width', 'auto')
        .removeClass('stuck');
};

LadbAbstractTab.prototype.computeStuckSlideHeaderWidth = function ($slide) {

    // Compute stuck slide header width
    const $header = $('.ladb-header', $slide).first();
    if ($header.hasClass('stuck')) {
        const $container = $('.ladb-container', $slide).first();
        $header
            .css('width', $container.outerWidth());
    }

};

LadbAbstractTab.prototype.scrollSlideToTarget = function($slide, $target, animated /* = false */, onAfterHighlight /* = false */) {
    if ($target && $target.length) {
        if ($slide === null) {
            $slide = this.topSlide();   // No slide, use topSlide
        }
        if ($slide) {
            const scrollTop = $slide.scrollTop() + $target.position().top - $('.ladb-header', $slide).outerHeight(true) - 20;
            const fnHighlight = function () {
                if (onAfterHighlight) {
                    const $highlightable = $('.ladb-highlightable', $target);
                    const $effectTarget = $highlightable.length > 0 ? $highlightable.first() : $target;
                    $effectTarget.effect('highlight', {}, 1500);
                }
            }
            if (animated) {
                $slide.animate({ scrollTop: scrollTop }, 200).promise().then(fnHighlight);
            } else {
                $slide.scrollTop(scrollTop);
                fnHighlight();
            }
        }
    }
}

// Modal /////

LadbAbstractTab.prototype.appendModalInside = function (id, twigFile, renderParams) {
    const that = this;

    // Hide previously opened modal
    if (this._$modal) {
        this._$modal.modal('hide');
    }

    // Create modal element
    this._$modal = $(Twig.twig({ref: twigFile}).render(renderParams));

    // Add modal extra classes
    this._$modal.addClass('modal-inside');

    // Bind modal
    this._$modal
        .on('shown.bs.modal', function () {
            $('body > .modal-backdrop').first().appendTo(that.$element);
            $('body')
                .removeClass('modal-open')
                .css('padding-right', 0);
            that.$element.addClass('modal-open');
            $('input[autofocus]', that._$modal).first().focus();
            that.dialog.setupTooltips(that._$modal);
            that.dialog.setupPopovers(that._$modal);
        })
        .on('hidden.bs.modal', function () {
            $(this)
                .data('bs.modal', null)
                .remove();
            that.$element.removeClass('modal-open');
            that._$modal = null;
            that.dialog.hideTooltips();
            that.dialog.hidePopovers();
        })
    ;

    // Append modal
    this.$element.append(this._$modal);

    // Bind help buttons (if exist)
    this.dialog.bindHelpButtonsInParent(this._$modal);

    return this._$modal;
};

LadbAbstractTab.prototype.hideModalInside = function () {
    if (this._$modal) {
        this._$modal.modal('hide');
    }
}

// Print /////

LadbAbstractTab.prototype.print = function (title, margin, size) {

    if (title === undefined) {
        title = 'OpenCutList';
    }
    // document.title = title;

    if (margin === undefined) {
        if (this.dialog.capabilities.tabs_dialog_print_margin === 1) {     /* 1 = Small */
            margin = '0.25in 0.25in 0.5in 0.25in';
        } else {
            margin = '';
        }
    }

    if (size === undefined) {
        size = '';
    }

    // Retrieve and modifiy Page rule to set margin and size to desired one
    const cssPageRuleStyle = document.styleSheets[0].cssRules[0].style;
    cssPageRuleStyle.margin = margin;
    cssPageRuleStyle.size = size;

    // Print
    window.print();

    // Restore margin
    cssPageRuleStyle.margin = '';
    cssPageRuleStyle.size = '';

};

// Command /////

LadbAbstractTab.prototype.registerCommand = function (command, block) {
    if (typeof block === 'function') {
        this._commands[command] = block;
    } else {
        alert('Action\'s block must be a function');
    }
};

LadbAbstractTab.prototype.executeCommand = function (command, parameters, callback) {
    if (this._commands.hasOwnProperty(command)) {

        // Retrieve action block
        const block = this._commands[command];

        // Execute action block with parameters
        block(parameters);

        // Invoke the callback
        if (typeof callback === 'function') {
            callback();
        }

    } else {
        alert('Command ' + command + ' not found');
    }
};

// Obsolete /////

LadbAbstractTab.prototype.setObsolete = function (obsolete) {
    this._obsolete = obsolete
    if (this._obsolete) {
        $('.ladb-obsolete', this.$rootSlide).removeClass('hidden');
    } else {
        $('.ladb-obsolete', this.$rootSlide).addClass('hidden');
    }
}

LadbAbstractTab.prototype.isObsolete = function () {
    return this._obsolete;
}

// Data /////

LadbAbstractTab.prototype.toBool = function (value) {
    if (value === 1) return true;
    return value === '1';
}

LadbAbstractTab.prototype.toInt = function (value) {
    let i = parseInt(value);
    if (isNaN(i)) {
        return 0;
    }
    return i;
}
'use strict';

function LadbAbstractTab(element, options, opencutlist) {
    this.options = options;
    this.$element = $(element);
    this.opencutlist = opencutlist;

    this._commands = {};

    this._$modal = null;

    this.$rootSlide = $('.ladb-slide', this.$element).first();
    this._$slides = [ this.$rootSlide ];

    this._obsolete = false;
}

// Slide /////

LadbAbstractTab.prototype.topSlide = function () {
    if (this._$slides.length > 0) {
        return this._$slides[this._$slides.length - 1];
    }
    return null;
};

LadbAbstractTab.prototype.pushNewSlide = function (id, twigFile, renderParams, callback) {

    // Check if top slide has the same id
    var $topSlide = this.topSlide();
    if ($topSlide.attr('id') === id) {
        $topSlide.attr('id', id + '_obsolete');
        $topSlide.data('remove-after-animation', true);
    }

    // Render slide
    this.$element.append(Twig.twig({ref: twigFile}).render(renderParams));

    // Fetch UI elements
    var $slide = $('#' + id, this.$element).first();

    return this.pushSlide($slide, callback);
};

LadbAbstractTab.prototype.pushSlide = function ($slide, callback) {
    var that = this;

    var $topSlide = this.topSlide();

    // Push in slides stack
    this._$slides.push($slide);

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
            if (typeof(callback) == 'function') {
                callback();
            }
        }
    });

    return $slide;
};

LadbAbstractTab.prototype.popSlide = function () {
    if (this._$slides.length > 1) {
        var $poppedSlide = this._$slides.pop();
        var $topSlide = this.topSlide();
        if ($topSlide) {
            $topSlide.show();
            this.computeStuckSlideHeaderWidth($topSlide);
        }
        this.unstickSlideHeader($poppedSlide);
        $poppedSlide.addClass('animated');
        $poppedSlide.switchClass('in', 'out', {
            duration: 300,
            complete: function () {
                $poppedSlide.removeClass('animated');
                $poppedSlide.remove();
            }
        });
    }
};

LadbAbstractTab.prototype.removeSlide = function ($slide) {
    var $removedSlides = this._$slides.splice(this._$slides.indexOf($slide), 1);    // Remove from slide stack
    if ($removedSlides.length > 0) {
        $removedSlides[0].remove(); // Remove from DOM
    }
};

LadbAbstractTab.prototype.stickSlideHeader = function ($slide) {
    var $headerWrapper = $('.ladb-header-wrapper', $slide).first();
    var $header = $('.ladb-header', $slide).first();
    var $container = $('.ladb-container', $slide).first();
    var outerWidth = $container.outerWidth();
    var outerHeight = $header.outerHeight();
    $headerWrapper
        .css('height', outerHeight);
    $header
        .css('width', outerWidth)
        .addClass('stuck');
};

LadbAbstractTab.prototype.unstickSlideHeader = function ($slide) {
    var $headerWrapper = $('.ladb-header-wrapper', $slide).first();
    var $header = $('.ladb-header', $slide).first();
    $headerWrapper
        .css('height', 'auto');
    $header
        .css('width', 'auto')
        .removeClass('stuck');
};

LadbAbstractTab.prototype.computeStuckSlideHeaderWidth = function ($slide) {

    // Compute stuck slide header width
    var $header = $('.ladb-header', $slide).first();
    if ($header.hasClass('stuck')) {
        var $container = $('.ladb-container', $slide).first();
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
            var scrollTop = $slide.scrollTop() + $target.position().top - $('.ladb-header', $slide).outerHeight(true) - 20;
            var highlightFn = function () {
                if (onAfterHighlight) {
                    var $highlightable = $('.ladb-highlightable', $target);
                    var $effectTarget = $highlightable.length > 0 ? $highlightable.first() : $target;
                    $effectTarget.effect('highlight', {}, 1500);
                }
            }
            if (animated) {
                $slide.animate({ scrollTop: scrollTop }, 200).promise().then(highlightFn);
            } else {
                $slide.scrollTop(scrollTop);
                highlightFn();
            }
        }
    }
}

// Modal /////

LadbAbstractTab.prototype.appendModalInside = function (id, twigFile, renderParams, validateWithEnter) {
    var that = this;

    // Hide previously opened modal
    if (this._$modal) {
        this._$modal.modal('hide');
    }

    // Render modal
    this.$element.append(Twig.twig({ref: twigFile}).render(renderParams));

    // Fetch UI elements
    this._$modal = $('#' + id, this.$element);

    // Add modal extra classes
    this._$modal.addClass('modal-inside');

    // Bind modal
    this._$modal.on('shown.bs.modal', function () {
        $('body > .modal-backdrop').first().appendTo(that.$element);
        $('body')
            .removeClass('modal-open')
            .css('padding-right', 0);
        that.$element.addClass('modal-open');
    });
    this._$modal.on('hidden.bs.modal', function () {
        $(this)
            .data('bs.modal', null)
            .remove();
        that.$element.removeClass('modal-open');
    });

    // Bind enter keyup on text input if configured
    if (validateWithEnter) {
        $('input[type=text]', that._$modal).on('keyup', function(e) {
            if (e.keyCode === 13) {
                e.preventDefault();
                var $btnValidate = $('.btn-validate-modal', that._$modal).first();
                if ($btnValidate && $btnValidate.is(':enabled')) {
                    $btnValidate.click();
                }
            }
        });
    }

    return this._$modal;
};

// Action /////

LadbAbstractTab.prototype.registerCommand = function (command, block) {
    if (typeof(block) == 'function') {
        this._commands[command] = block;
    } else {
        alert('Action\'s block must be a function');
    }
};

LadbAbstractTab.prototype.executeCommand = function (command, parameters, callback) {
    if (this._commands.hasOwnProperty(command)) {

        // Retrieve action block
        var block = this._commands[command];

        // Execute action block with parameters
        block(parameters);

        // Invoke the callback
        if (typeof(callback) == 'function') {
            callback();
        }

    } else {
        alert('Command ' + command + ' not found');
    }
};

// Helper /////

LadbAbstractTab.prototype.tokenfieldValidatorFn_d = function (e) {
    var re = /^([\d.,]+\s*(mm|cm|m|'|"|)|[\d.,]*\s*[\d]+\/[\d]+\s*('|"|))$/;
    var valid = re.test(e.attrs.value);
    if (!valid) {
        $(e.relatedTarget).addClass('invalid')
    }
};

LadbAbstractTab.prototype.tokenfieldValidatorFn_dxd = function (e) {
    var re = /^([\d.,]+\s*(mm|cm|m|'|"|)|[\d.,]*\s*[\d]+\/[\d]+\s*('|"|))\s*x\s*([\d.,]+\s*(mm|cm|m|'|"|)|[\d.,]*\s*[\d]+\/[\d]+\s*('|"|))$/;
    var valid = re.test(e.attrs.value);
    if (!valid) {
        $(e.relatedTarget).addClass('invalid')
    }
};

// Bind /////

LadbAbstractTab.prototype.bind = function () {
    var that = this;

    var fnComputeStuckSlideHeadersWidth = function (event) {

        // Recompute stuck slides header width
        $('.ladb-slide:visible', that.$element).each(function (index) {
            that.computeStuckSlideHeaderWidth($(this));
        });

    };

    // Bind window resize event
    $(window).on('resize', fnComputeStuckSlideHeadersWidth);

    // Bind dialog maximized and minimized events
    this.opencutlist.$element.on('maximized.ladb.dialog', fnComputeStuckSlideHeadersWidth);

    // Bind tab shown events
    this.$element.on('shown.ladb.tab', fnComputeStuckSlideHeadersWidth);

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

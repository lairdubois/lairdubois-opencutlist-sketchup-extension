'use strict';

function LadbAbstractTab(element, options, opencutlist) {
    this.options = options;
    this.$element = $(element);
    this.opencutlist = opencutlist;

    this._commands = {};

    this._$modal = null;

    this.$baseSlide = $('.ladb-slide', this.$element).first();
    this._$slides = [ this.$baseSlide ];
}

// Slide /////

LadbAbstractTab.prototype.topSlide = function() {
    if (this._$slides.length > 0) {
        return this._$slides[this._$slides.length - 1];
    }
    return null;
};

LadbAbstractTab.prototype.pushSlide = function(id, twigFile, renderParams) {
    var that = this;

    var $topSlide = this.topSlide();

    // Render slide
    this.$element.append(Twig.twig({ref: twigFile}).render(renderParams));

    // Fetch UI elements
    var $pushedSlide = $('#' + id, this.$element);

    // Push in slides stack
    this._$slides.push($pushedSlide);

    // Animation
    $pushedSlide.addClass('animated');
    $pushedSlide.switchClass('out', 'in', {
        duration: 300,
        complete: function() {
            $pushedSlide.removeClass('animated');
            that.stickSlideHeader($pushedSlide);
            if ($topSlide) {
                $topSlide.hide();
            }
        }
    });

    return $pushedSlide;
};

LadbAbstractTab.prototype.popSlide = function() {
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
        complete: function() {
            $poppedSlide.removeClass('animated');
            $poppedSlide.remove();
        }
    });
};

LadbAbstractTab.prototype.stickSlideHeader = function($slide) {
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

LadbAbstractTab.prototype.unstickSlideHeader = function($slide) {
    var $headerWrapper = $('.ladb-header-wrapper', $slide).first();
    var $header = $('.ladb-header', $slide).first();
    $headerWrapper
        .css('height', 'auto');
    $header
        .css('width', 'auto')
        .removeClass('stuck');
};

LadbAbstractTab.prototype.computeStuckSlideHeaderWidth = function($slide) {

    // Compute stuck slide header width
    var $header = $('.ladb-header', $slide).first();
    if ($header.hasClass('stuck')) {
        var $container = $('.ladb-container', $slide).first();
        $header
            .css('width', $container.outerWidth());
    }

};

// Modal /////

LadbAbstractTab.prototype.appendModalInside = function(id, twigFile, renderParams) {
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
    });
    this._$modal.on('hidden.bs.modal', function () {
        $(this)
            .data('bs.modal', null)
            .remove();
    });

    return this._$modal;
};

// Action /////

LadbAbstractTab.prototype.registerCommand = function(command, block) {
    if (typeof(block) == 'function') {
        this._commands[command] = block;
    } else {
        alert('Action\'s block must be a function');
    }
};

LadbAbstractTab.prototype.executeCommand = function(command, parameters, callback) {
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

LadbAbstractTab.prototype.bind = function() {
    var that = this;

    var fnComputeStuckSlideHeadersWidth = function(event) {

        // Recompute stuck slides header width
        $('.ladb-slide:visible', that.$element).each(function(index) {
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
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

// Screen /////

LadbAbstractTab.prototype.pushSlide = function(id, twigFile, renderParams) {
    var that = this;

    var $topSlide = that._$slides[that._$slides.length - 1];

    // Render slide
    this.$element.append(Twig.twig({ref: twigFile}).render(renderParams));

    // Fetch UI elements
    var $pushedSlide = $('#' + id, this.$element);

    // Push in slides stack
    this._$slides.push($pushedSlide);

    // Animation
    $pushedSlide.switchClass('out', 'in', {
        duration: 300,
        complete: function() {
            $topSlide.hide();
        }
    });

    return $pushedSlide;
};

LadbAbstractTab.prototype.popSlide = function() {
    var $poppedSlide = this._$slides.pop();
    this._$slides[this._$slides.length - 1].show();
    $poppedSlide.switchClass('in', 'out', {
        duration: 300,
        complete: function() {
            $poppedSlide.remove();
        }
    });
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

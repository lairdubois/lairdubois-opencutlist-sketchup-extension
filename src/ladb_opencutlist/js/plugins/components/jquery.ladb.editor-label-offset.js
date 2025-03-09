+function ($) {
    'use strict';

    const XMLNS = "http://www.w3.org/2000/svg";
    const PAGE_MAX_WIDTH = 400;
    const PAGE_MAX_HEIGHT = 300;

    // CLASS DEFINITION
    // ======================

    const LadbEditorLabelOffset = function (element, options) {
        this.options = options;
        this.$element = $(element);

    };

    LadbEditorLabelOffset.DEFAULTS = {
    };

    LadbEditorLabelOffset.prototype.createSvg = function () {
        const that = this;

        // Check invalid size
        if (this.options.pageWidth <= 0 || isNaN(this.options.pageWidth) || this.options.pageHeight <= 0 || isNaN(this.options.pageHeight)) {

            this.$element.append(Twig.twig({ref: 'core/_alert-errors.twig'}).render({
                errors: [ 'tab.cutlist.labels.error.invalid_size' ]
            }));

            return;
        }

        const $svgContaner = $('<div class="ladb-editor-label-offset-preview"></div>');
        this.$element.append($svgContaner);

        const svg = document.createElementNS(XMLNS, 'svg');
        $svgContaner.append(svg);
        svg.setAttributeNS(null, 'viewBox', '0 0 ' + this.options.pageWidth + ' ' + this.options.pageHeight);
        if (this.options.pageHeight > this.options.pageWidth) {
            svg.setAttributeNS(null, 'width',  (PAGE_MAX_HEIGHT / this.options.pageHeight) * this.options.pageWidth + 'px');
            svg.setAttributeNS(null, 'height', PAGE_MAX_HEIGHT + 'px');
        } else {
            svg.setAttributeNS(null, 'width',   PAGE_MAX_WIDTH + 'px');
            svg.setAttributeNS(null, 'height', (PAGE_MAX_WIDTH / this.options.pageWidth) * this.options.pageHeight + 'px');
        }

        this.svg = svg;

        // Grid lines

        const svgGrid = document.createElementNS(XMLNS, 'g');
        svg.appendChild(svgGrid);

        const sw = Math.min(that.options.pageWidth, that.options.pageHeight) / 100;

        const fnDrawRect = function (x, y, width, height, offset) {
            const r = Math.min(width, height) / 10;
            const svgRect = document.createElementNS(XMLNS, 'rect');
            svgGrid.appendChild(svgRect);
            svgRect.setAttributeNS(null, 'x', x + sw);
            svgRect.setAttributeNS(null, 'y', y + sw);
            svgRect.setAttributeNS(null, 'width', width - sw * 2);
            svgRect.setAttributeNS(null, 'height', height - sw * 2);
            svgRect.setAttributeNS(null, 'rx', r);
            svgRect.setAttributeNS(null, 'ry', r);
            svgRect.setAttributeNS(null, 'fill', '#fff');
            svgRect.setAttributeNS(null, 'stroke-width', sw);
            svgRect.setAttributeNS(null, 'data-offset', offset);
            $(svgRect).on('click', function () {
                fnSetOffset(offset);
            });
            if (offset >= that.offset) {
                $(svgRect).addClass('active');
            }
        }

        const fnSetOffset = function (offset) {
            that.offset = offset;
            $('rect', svgGrid).each(function () {
                const $rect = $(this);
                if (parseInt($rect.data('offset')) < offset) {
                    $rect.removeClass('active');
                } else {
                    $rect.addClass('active');
                }
            });
        };

        let x;
        let y;
        const lw = (this.options.pageWidth - this.options.marginLeft - this.options.marginRight - this.options.spacingV * (this.options.colCount - 1)) / this.options.colCount;
        const lh = (this.options.pageHeight - this.options.marginTop - this.options.marginBottom - this.options.spacingH * (this.options.rowCount - 1)) / this.options.rowCount;

        for (let i = 0; i < this.options.colCount; i++) {
            x = this.options.marginLeft + i * (lw + this.options.spacingV);
            for (let j = 0; j < this.options.rowCount; j++) {
                y = this.options.marginTop + j * (lh + this.options.spacingH);
                fnDrawRect(x, y, lw, lh, i + j * this.options.colCount);
            }
        }

    };

    LadbEditorLabelOffset.prototype.updateSizeAndOffset = function (pageWidth, pageHeight, marginTop, marginRight, marginBottom, marginLeft, spacingH, spacingV, colCount, rowCount, offset) {

        if (offset == null) {
            if (this.options.colCount !== colCount ||
                this.options.rowCount !== rowCount
            ) {
                // Reset offset if new col or row count
                offset = 0
            } else {
                offset = this.offset;
            }
        }
        this.offset = offset;

        this.options.pageWidth = pageWidth;
        this.options.pageHeight = pageHeight;
        this.options.marginTop = marginTop;
        this.options.marginRight = marginRight;
        this.options.marginBottom = marginBottom;
        this.options.marginLeft = marginLeft;
        this.options.spacingH = spacingH;
        this.options.spacingV = spacingV;
        this.options.colCount = colCount;
        this.options.rowCount = rowCount;

        // Empty the container
        this.$element.empty();

        // Recreate the SVG
        this.createSvg();

    };

    LadbEditorLabelOffset.prototype.getOffset = function () {
        return this.offset;
    };

    LadbEditorLabelOffset.prototype.init = function () {
    };

    // PLUGIN DEFINITION
    // =======================

    function Plugin(option, params) {
        let value;
        const elements = this.each(function () {
            const $this = $(this);
            let data = $this.data('ladb.editorLabelOffset');
            if (!data) {
                const options = $.extend({}, LadbEditorLabelOffset.DEFAULTS, $this.data(), typeof option === 'object' && option);
                $this.data('ladb.editorLabelOffset', (data = new LadbEditorLabelOffset(this, options)));
            }
            if (typeof option === 'string') {
                value = data[option].apply(data, Array.isArray(params) ? params : [ params ])
            } else {
                data.init(params);
            }
        });
        return typeof value !== 'undefined' ? value : elements;
    }

    const old = $.fn.ladbEditorLabelOffsetOffset;

    $.fn.ladbEditorLabelOffset = Plugin;
    $.fn.ladbEditorLabelOffset.Constructor = LadbEditorLabelOffset;


    // NO CONFLICT
    // =================

    $.fn.ladbEditorLabelOffset.noConflict = function () {
        $.fn.ladbEditorLabelOffset = old;
        return this;
    }

}(jQuery);
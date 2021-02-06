+function ($) {
    'use strict';

    var XMLNS = "http://www.w3.org/2000/svg";
    var GRID_DIVISION = 12;
    var LABEL_MAX_WIDTH = 400;
    var LABEL_MAX_HEIGHT = 300;

    // CLASS DEFINITION
    // ======================

    var LadbLabelEditor = function (element, options) {
        this.options = options;
        this.$element = $(element);

        this.$editingSvgGroup = null;
        this.$editingForm = null;

    };

    LadbLabelEditor.DEFAULTS = {
        group: null,
        part: null,
        labelWidth: 100,
        labelHeight: 100,
    };

    LadbLabelEditor.prototype.createSvg = function () {
        var that = this;

        rubyCallCommand('core_float_to_length', {
            width: this.options.labelWidth,
            height: this.options.labelHeight,
        }, function (response) {

            var $sizeContaner = $('<div class="ladb-label-editor-size">' + i18next.t('tab.cutlist.labels.size') + ' : ' + response.width.replace('~', '') + ' x ' + response.height.replace('~', '') + '</div>');
            that.$element.prepend($sizeContaner);

        })

        var $svgContaner = $('<div class="ladb-label-editor-preview"></div>');
        this.$element.append($svgContaner);

        var svg = document.createElementNS(XMLNS, 'svg');
        $svgContaner.append(svg);
        svg.setAttributeNS(null, 'viewBox', '0 0 ' + this.options.labelWidth + ' ' + this.options.labelHeight);
        if (this.options.labelHeight > this.options.labelWidth) {
            svg.setAttributeNS(null, 'width',  (LABEL_MAX_HEIGHT / this.options.labelHeight) * this.options.labelWidth + 'px');
            svg.setAttributeNS(null, 'height', LABEL_MAX_HEIGHT + 'px');
        } else {
            svg.setAttributeNS(null, 'width',   LABEL_MAX_WIDTH + 'px');
            svg.setAttributeNS(null, 'height', (LABEL_MAX_WIDTH / this.options.labelWidth) * this.options.labelHeight + 'px');
        }

        this.svg = svg;

        var svgLabel = document.createElementNS(XMLNS, 'g');
        svg.appendChild(svgLabel);
        svgLabel.setAttributeNS(null, 'transform', 'translate(' + this.options.labelWidth / 2 + ' ' + this.options.labelHeight / 2 + ')');

        this.svgLabel = svgLabel;

        // Grid lines

        var svgGrid = document.createElementNS(XMLNS, 'g');
        svgLabel.appendChild(svgGrid);

        var fnDrawLine = function (x1, y1, x2, y2, stroke) {
            var svgLine = document.createElementNS(XMLNS, 'line');
            svgGrid.appendChild(svgLine);
            svgLine.setAttributeNS(null, 'x1', x1);
            svgLine.setAttributeNS(null, 'y1', y1);
            svgLine.setAttributeNS(null, 'x2', x2);
            svgLine.setAttributeNS(null, 'y2', y2);
            svgLine.setAttributeNS(null, 'stroke', stroke ? stroke : '#ddd');
            svgLine.setAttributeNS(null, 'stroke-width', 0.01 );
            svgLine.setAttributeNS(null, 'stroke-dasharray', that.options.minUnit / 10);
        }

        var y = 0;
        while (y < this.options.labelHeight / 2) {
            if (y > 0) {
                fnDrawLine(-this.options.labelWidth / 2, -y, this.options.labelWidth / 2, -y);
            }
            fnDrawLine(-this.options.labelWidth / 2, y, this.options.labelWidth / 2, y, y === 0 ? '#999' : null);
            y = y + this.options.minUnit;
        }
        var x = 0;
        while (x < this.options.labelWidth / 2) {
            if (x > 0) {
                fnDrawLine(-x, -this.options.labelHeight / 2, -x, this.options.labelHeight / 2);
            }
            fnDrawLine(x, -this.options.labelHeight / 2, x, this.options.labelHeight / 2, x === 0 ? '#999' : null);
            x = x + this.options.minUnit;
        }

        var fnGetMousePosition = function (e) {
            var CTM = svg.getScreenCTM();
            return {
                x: (e.clientX - CTM.e) / CTM.a,
                y: (e.clientY - CTM.f) / CTM.d
            };
        }

        var draggingElement, draggingElementDef, offset, transform;
        $(svg)
            .on('mousedown', function (e) {
                var $draggable = $(e.target).closest('.draggable');
                if ($draggable.length > 0) {

                    draggingElement = $draggable[0];
                    draggingElementDef = $draggable.data('def');
                    offset = fnGetMousePosition(e);

                    that.editElement(draggingElement, draggingElementDef);

                    // Get all the transforms currently on this element
                    var transforms = draggingElement.transform.baseVal;

                    // Ensure the first transform is a translate transform
                    if (transforms.length === 0 || transforms.getItem(0).type !== SVGTransform.SVG_TRANSFORM_TRANSLATE) {

                        // Create an transform that translates by (0, 0)
                        var translate = svg.createSVGTransform();
                        translate.setTranslate(0, 0);

                        // Add the translation to the front of the transforms list
                        draggingElement.transform.baseVal.insertItemBefore(translate, 0);

                    }

                    // Get initial translation amount
                    transform = transforms.getItem(0);
                    offset.x -= transform.matrix.e;
                    offset.y -= transform.matrix.f;

                } else {
                    that.editElement(null);
                }
            })
            .on('mousemove', function (e) {
                if (draggingElement) {
                    e.preventDefault();
                    var coord = fnGetMousePosition(e);
                    var gridX = Math.round((coord.x - offset.x) / that.options.minUnit);
                    var gridY = Math.round((coord.y - offset.y) / that.options.minUnit);

                    // Update def
                    draggingElementDef.x = gridX * that.options.minUnit / that.options.labelWidth;
                    draggingElementDef.y = gridY * that.options.minUnit / that.options.labelHeight;

                    // Update element translation
                    transform.setTranslate(draggingElementDef.x * that.options.labelWidth, draggingElementDef.y * that.options.labelHeight);

                }
            })
            .on('mouseup mouseleave', function (e) {
                draggingElement = null;
            })
        ;

        // Append elementDefs
        for (var i = 0; i < this.elementDefs.length; i++) {
            this.appendElementDef(this.elementDefs[i]);
        }

        var $btnAdd = $('<button class="btn btn-default"><i class="ladb-opencutlist-icon-plus"></i> ' + i18next.t('tab.cutlist.labels.add_element') + '</button>');
        $btnAdd
            .on('click', function () {

                var elementDef = {
                    formula: 'part.name',
                    x: 0,
                    y: 0,
                    fontSize: 1,
                    textAnchor: 'middle',
                    color: '#000'
                }

                that.elementDefs.push(elementDef);
                that.editElement(that.appendElementDef(elementDef), elementDef);

            })
        ;

        var $btnRemove = $('<button class="btn btn-danger" style="display: none;"><i class="ladb-opencutlist-icon-minus"></i> ' + i18next.t('tab.cutlist.labels.remove_element') + '</button>');
        $btnRemove
            .on('click', function () {
                that.elementDefs.splice(that.elementDefs.indexOf(that.$editingSvgGroup.data('def')), 1);
                that.$editingSvgGroup.remove();
                that.editElement(null);
            })
        ;

        this.$element.append(
            $('<div class="ladb-label-editor-buttons" style="margin: 10px;"></div>')
                .append($btnAdd)
                .append('&nbsp;')
                .append($btnRemove)
        );

        this.$btnRemove = $btnRemove;

    };

    LadbLabelEditor.prototype.appendElementDef = function (elementDef) {
        var svgGroup, svgCrossLineV, svgCrossLineH, svgTextGroup;

        svgGroup = document.createElementNS(XMLNS, 'g');
        svgGroup.setAttributeNS(null, 'class', 'draggable');
        svgGroup.setAttributeNS(null, 'transform', 'translate(' + elementDef.x * this.options.labelWidth + ' ' + elementDef.y * this.options.labelHeight + ')');
        this.svgLabel.appendChild(svgGroup);

        $(svgGroup).data('def', elementDef);

        svgCrossLineH = document.createElementNS(XMLNS, 'line');
        svgCrossLineH.setAttributeNS(null, 'x1', -this.options.minUnit / 3);
        svgCrossLineH.setAttributeNS(null, 'y1', 0);
        svgCrossLineH.setAttributeNS(null, 'x2', this.options.minUnit / 3);
        svgCrossLineH.setAttributeNS(null, 'y2', 0);
        svgCrossLineH.setAttributeNS(null, 'stroke', '#f00');
        svgCrossLineH.setAttributeNS(null, 'stroke-width', 0.01);
        svgGroup.appendChild(svgCrossLineH);

        svgCrossLineV = document.createElementNS(XMLNS, 'line');
        svgCrossLineV.setAttributeNS(null, 'x1', 0);
        svgCrossLineV.setAttributeNS(null, 'y1', -this.options.minUnit / 3);
        svgCrossLineV.setAttributeNS(null, 'x2', 0);
        svgCrossLineV.setAttributeNS(null, 'y2', this.options.minUnit / 3);
        svgCrossLineV.setAttributeNS(null, 'stroke', '#f00');
        svgCrossLineV.setAttributeNS(null, 'stroke-width', 0.01);
        svgGroup.appendChild(svgCrossLineV);

        svgTextGroup = document.createElementNS(XMLNS, 'g');
        svgGroup.appendChild(svgTextGroup);

        this.appendFormula(svgTextGroup, elementDef);

        return svgGroup;
    }

    LadbLabelEditor.prototype.appendFormula = function (svgTextGroup, elementDef) {
        svgTextGroup.innerHTML = Twig.twig({ref: 'tabs/cutlist/_label-element.twig'}).render($.extend({
            elementDef: elementDef,
            part_info: {
                position_in_batch: 1,
                part: this.options.part
            },
            noEmptyValue: true
        }, this.options));

        var svgText = $(svgTextGroup).children('text')[0];
        if (svgText) {
            var bbox = svgText.getBBox();
            var svgSelectionRect = document.createElementNS(XMLNS, 'rect');
            svgSelectionRect.setAttributeNS(null, 'class', 'selection');
            svgSelectionRect.setAttributeNS(null, 'x', bbox.x - 0.02);
            svgSelectionRect.setAttributeNS(null, 'y', bbox.y - 0.02);
            svgSelectionRect.setAttributeNS(null, 'width', bbox.width + 0.04);
            svgSelectionRect.setAttributeNS(null, 'height', bbox.height + 0.04);
            svgSelectionRect.setAttributeNS(null, 'fill', 'none');
            svgSelectionRect.setAttributeNS(null, 'stroke-width', 0.01);
            svgSelectionRect.setAttributeNS(null, 'stroke-dasharray', this.options.minUnit / 5);
            svgSelectionRect.setAttributeNS(null, 'rx', 0.02);
            svgSelectionRect.setAttributeNS(null, 'ry', 0.02);
            svgTextGroup.insertBefore(svgSelectionRect, svgText);
        }

    }

    LadbLabelEditor.prototype.editElement = function (svgElement, elementDef) {
        var that = this;

        // Editing flag
        if (this.$editingSvgGroup) {
            this.$editingSvgGroup.removeClass('active');
        }
        if (svgElement == null) {
            this.$editingSvgGroup = null;
            if (this.$editingForm) {
                this.$editingForm.remove();
            }
            this.$btnRemove.hide();
            return;
        }
        this.$editingSvgGroup = $(svgElement)
        this.$editingSvgGroup.addClass('active');

        if (this.$btnRemove) {
            this.$btnRemove.show();
        }

        var svgTextGroup = this.$editingSvgGroup.children('g')[0];
        var svgText = $(svgTextGroup).children('text')[0];

        // Form
        if (this.$editingForm) {
            this.$editingForm.remove();
        }
        this.$element.append(Twig.twig({ref: "tabs/cutlist/_label-element-form.twig"}).render());
        this.$editingForm = $('#ladb_cutlist_form_label_element');

        // UI
        var $selectFormula = $('#ladb_select_formula', this.$editingForm);
        var $selectFontSize = $('#ladb_select_font_size', this.$editingForm);
        var $selectTextAnchor = $('#ladb_select_text_anchor', this.$editingForm);
        var $inputColor = $('#ladb_input_color', this.$editingForm);

        // Bind
        $selectFormula
            .val(elementDef.formula)
            .selectpicker(SELECT_PICKER_OPTIONS)
            .on('change', function () {
                elementDef.formula = $(this).val();
                that.appendFormula(svgTextGroup, elementDef);
            })
        ;
        $selectFontSize
            .val(elementDef.fontSize)
            .selectpicker(SELECT_PICKER_OPTIONS)
            .on('change', function () {
                elementDef.fontSize = $(this).val();
                that.appendFormula(svgTextGroup, elementDef);
            })
        ;
        $selectTextAnchor
            .val(elementDef.textAnchor)
            .selectpicker(SELECT_PICKER_OPTIONS)
            .on('change', function () {
                elementDef.textAnchor = $(this).val();
                that.appendFormula(svgTextGroup, elementDef);
            })
        ;
        $inputColor
            .val(elementDef.color)
            .ladbTextinputColor()
            .on('change', function () {
                elementDef.color = $(this).val();
                that.appendFormula(svgTextGroup, elementDef);
            })
        ;

    };

    LadbLabelEditor.prototype.updateSize = function (labelWidth, labelHeight) {

        this.options.labelWidth = labelWidth;
        this.options.labelHeight = labelHeight;
        this.options.xUnit = labelWidth / GRID_DIVISION;
        this.options.yUnit = labelHeight / GRID_DIVISION;
        this.options.minUnit = Math.min(this.options.xUnit, this.options.yUnit);

        // Empty the container
        this.$element.empty();

        // Recreate the SVG
        this.createSvg();

    };

    LadbLabelEditor.prototype.updateSizeAndElementDefs = function (labelWidth, labelHeight, elementDefs) {
        this.elementDefs = elementDefs;

        // Empty the container
        this.updateSize(labelWidth, labelHeight);

    };

    LadbLabelEditor.prototype.getElementDefs = function () {
        return this.elementDefs;
    };

    LadbLabelEditor.prototype.init = function (elementDefs) {
        this.elementDefs = elementDefs;
    };

    // PLUGIN DEFINITION
    // =======================

    function Plugin(option, params) {
        var value;
        var elements = this.each(function () {
            var $this = $(this);
            var data = $this.data('ladb.labelEditor');
            var options = $.extend({}, LadbLabelEditor.DEFAULTS, $this.data(), typeof option == 'object' && option);

            if (!data) {
                $this.data('ladb.labelEditor', (data = new LadbLabelEditor(this, options)));
            }
            if (typeof option == 'string') {
                value = data[option].apply(data, Array.isArray(params) ? params : [ params ])
            } else {
                data.init(params);
            }
        });
        return typeof value !== 'undefined' ? value : elements;
    }

    var old = $.fn.ladbLabelEditor;

    $.fn.ladbLabelEditor = Plugin;
    $.fn.ladbLabelEditor.Constructor = LadbLabelEditor;


    // NO CONFLICT
    // =================

    $.fn.ladbLabelEditor.noConflict = function () {
        $.fn.ladbLabelEditor = old;
        return this;
    }

}(jQuery);
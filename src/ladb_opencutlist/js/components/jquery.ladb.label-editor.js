+function ($) {
    'use strict';

    var XMLNS = "http://www.w3.org/2000/svg";

    // CLASS DEFINITION
    // ======================

    var LadbLabelEditor = function (element, options) {
        this.options = options;
        this.$element = $(element);

        this.$editingXGroup = null;
        this.$editingForm = null;

    };

    LadbLabelEditor.DEFAULTS = {
        part: null,
        labelWidth: 100,
        labelHeight: 100,
    };

    LadbLabelEditor.prototype.createSvg = function () {
        var that = this;

        var $svgContaner = $('<div class="text-center"></div>');
        this.$element.append($svgContaner);

        var svg = document.createElementNS(XMLNS, 'svg');
        $svgContaner.append(svg);
        svg.setAttributeNS(null, 'viewBox', '0 0 ' + this.options.labelWidth + ' ' + this.options.labelHeight);
        svg.setAttributeNS(null, 'width', '80%');

        this.svg = svg;

        // Grid lines
        var lines = document.createElementNS(XMLNS, 'g');
        var line;
        for (var row = 1; row < 12; row++) {
            line = document.createElementNS(XMLNS, 'line');
            line.setAttributeNS(null, 'x1', 0);
            line.setAttributeNS(null, 'y1', row * this.options.yUnit);
            line.setAttributeNS(null, 'x2', this.options.labelWidth);
            line.setAttributeNS(null, 'y2', row * this.options.yUnit);
            line.setAttributeNS(null, 'stroke', '#ddd');
            line.setAttributeNS(null, 'stroke-width', 0.01);
            lines.appendChild(line);
        }
        for (var col = 1; col < 12; col++) {
            line = document.createElementNS(XMLNS, 'line');
            line.setAttributeNS(null, 'x1', col * this.options.xUnit);
            line.setAttributeNS(null, 'y1', 0);
            line.setAttributeNS(null, 'x2', col * this.options.xUnit);
            line.setAttributeNS(null, 'y2', this.options.labelHeight);
            line.setAttributeNS(null, 'stroke', '#ddd');
            line.setAttributeNS(null, 'stroke-width', 0.01);
            lines.appendChild(line);
        }
        svg.appendChild(lines);

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
                    var newX = Math.round((coord.x - offset.x) / that.options.xUnit);
                    var newY = Math.round((coord.y - offset.y) / that.options.yUnit);

                    // Update def
                    draggingElementDef.x = newX;
                    draggingElementDef.y = newY;

                    // Update element translation
                    transform.setTranslate(newX * that.options.xUnit, newY * that.options.yUnit);


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

        var $btnAdd = $('<button class="btn btn-default"><i class="ladb-opencutlist-icon-plus"></i> Ajouter un champ</button>');
        $btnAdd
            .on('click', function () {

                var elementDef = {
                    formula: 'part.name',
                    x: 1,
                    y: 1,
                    fontSize: 1,
                    textAnchor: 'start',
                    color: '#000'
                }

                that.elementDefs.push(elementDef);
                that.editElement(that.appendElementDef(elementDef), elementDef);

            })
        ;

        var $btnRemove = $('<button class="btn btn-danger" style="display: none;"><i class="ladb-opencutlist-icon-minus"></i> Retirer le champ</button>');
        $btnRemove
            .on('click', function () {
                that.elementDefs.splice(that.elementDefs.indexOf(that.$editingXGroup.data('def')), 1);
                that.$editingXGroup.remove();
                that.editElement(null);
            })
        ;

        this.$element.append(
            $('<div class="text-center" style="margin: 10px;"></div>')
                .append($btnAdd)
                .append('&nbsp;')
                .append($btnRemove)
        );

        this.$btnRemove = $btnRemove;

    };

    LadbLabelEditor.prototype.appendElementDef = function (elementDef) {
        var xGroup, xLineV, xLineH, xTextGroup;

        xGroup = document.createElementNS(XMLNS, 'g');
        xGroup.setAttributeNS(null, 'class', 'draggable');
        xGroup.setAttributeNS(null, 'transform', 'translate(' + elementDef.x * this.options.xUnit + ' ' + elementDef.y * this.options.yUnit + ')');
        this.svg.appendChild(xGroup);

        $(xGroup).data('def', elementDef);

        xLineH = document.createElementNS(XMLNS, 'line');
        xLineH.setAttributeNS(null, 'x1', -this.options.minUnit / 2);
        xLineH.setAttributeNS(null, 'y1', 0);
        xLineH.setAttributeNS(null, 'x2', this.options.minUnit / 2);
        xLineH.setAttributeNS(null, 'y2', 0);
        xLineH.setAttributeNS(null, 'stroke', '#f00');
        xLineH.setAttributeNS(null, 'stroke-width', 0.01);
        xGroup.appendChild(xLineH);

        xLineV = document.createElementNS(XMLNS, 'line');
        xLineV.setAttributeNS(null, 'x1', 0);
        xLineV.setAttributeNS(null, 'y1', -this.options.minUnit / 2);
        xLineV.setAttributeNS(null, 'x2', 0);
        xLineV.setAttributeNS(null, 'y2', this.options.minUnit / 2);
        xLineV.setAttributeNS(null, 'stroke', '#f00');
        xLineV.setAttributeNS(null, 'stroke-width', 0.01);
        xGroup.appendChild(xLineV);

        xTextGroup = document.createElementNS(XMLNS, 'g');
        xGroup.appendChild(xTextGroup);

        this.appendFormula(xTextGroup, elementDef);

        return xGroup;
    }

    LadbLabelEditor.prototype.appendFormula = function (xTextGroup, elementDef) {
        xTextGroup.innerHTML = Twig.twig({ref: 'tabs/cutlist/_label-element.twig'}).render($.extend({
            elementDef: elementDef,
            part_info: {
                position_in_batch: 1,
                part: this.options.part
            },
            noEmptyValue: true
        }, this.options));

        var xText = $(xTextGroup).children('text')[0];
        var bbox = xText.getBBox();
        var xActiveRect = document.createElementNS(XMLNS, 'rect');
        xActiveRect.setAttributeNS(null, 'class', 'selection');
        xActiveRect.setAttributeNS(null, 'x', bbox.x - 0.02);
        xActiveRect.setAttributeNS(null, 'y', bbox.y - 0.02);
        xActiveRect.setAttributeNS(null, 'width', bbox.width + 0.04);
        xActiveRect.setAttributeNS(null, 'height', bbox.height + 0.04);
        xActiveRect.setAttributeNS(null, 'fill', 'none');
        xActiveRect.setAttributeNS(null, 'stroke-width', 0.01);
        xActiveRect.setAttributeNS(null, 'rx', 0.02);
        xActiveRect.setAttributeNS(null, 'ry', 0.02);
        xTextGroup.appendChild(xActiveRect);

    }

    LadbLabelEditor.prototype.editElement = function (element, elementDef) {
        var that = this;

        // Editing flag
        if (this.$editingXGroup) {
            this.$editingXGroup.removeClass('active');
        }
        if (element == null) {
            this.$editingXGroup = null;
            if (this.$editingForm) {
                this.$editingForm.remove();
            }
            this.$btnRemove.hide();
            return;
        }
        this.$editingXGroup = $(element)
        this.$editingXGroup.addClass('active');

        if (this.$btnRemove) {
            this.$btnRemove.show();
        }

        var xTextGroup = this.$editingXGroup.children('g')[0];
        var xText = $(xTextGroup).children('text')[0];

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

        console.log($selectFormula);

        // Bind
        $selectFormula
            .val(elementDef.formula)
            .selectpicker(SELECT_PICKER_OPTIONS)
            .on('change', function () {
                elementDef.formula = $(this).val();
                that.appendFormula(xTextGroup, elementDef);
            })
        ;
        $selectFontSize
            .val(elementDef.fontSize)
            .selectpicker(SELECT_PICKER_OPTIONS)
            .on('change', function () {
                elementDef.fontSize = $(this).val();
                that.appendFormula(xTextGroup, elementDef);
            })
        ;
        $selectTextAnchor
            .val(elementDef.textAnchor)
            .selectpicker(SELECT_PICKER_OPTIONS)
            .on('change', function () {
                elementDef.textAnchor = $(this).val();
                that.appendFormula(xTextGroup, elementDef);
            })
        ;
        $inputColor
            .val(elementDef.color)
            .on('change', function () {
                elementDef.color = $(this).val();
                that.appendFormula(xTextGroup, elementDef);
            })
        ;

        // Create color picker
        var hueb = new Huebee($inputColor.get(0) , {
            notation: 'hex',
            saturations: 2,
            shades: 7,
            customColors: [ '#4F78A7', '#EF8E2C', '#DE545A', '#79B8B2', '#5CA34D', '#ECCA48', '#AE78A2', '#FC9CA8', '#9B755F', '#BAB0AC' ]
        });
        hueb.on('change', function() {
            hueb.close();
            $inputColor.trigger('change');
        });

    };

    LadbLabelEditor.prototype.updateSize = function (labelWidth, labelHeight) {

        this.options.labelWidth = labelWidth;
        this.options.labelHeight = labelHeight;
        this.options.xUnit = labelWidth / 12;
        this.options.yUnit = labelHeight / 12;
        this.options.minUnit = Math.min(this.options.xUnit, this.options.yUnit);

        // Empty the container
        this.$element.empty();

        // Recreate the SVG
        this.createSvg();

    };

    LadbLabelEditor.prototype.updateSizeAndLayout = function (labelWidth, labelHeight, elementDefs) {
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
                $this.data('ladb.labelEditor', (data = new LadbLabelEditor(this, options, options.dialog)));
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
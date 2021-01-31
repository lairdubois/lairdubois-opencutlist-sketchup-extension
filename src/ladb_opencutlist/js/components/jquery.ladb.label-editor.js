+function ($) {
    'use strict';

    var XMLNS = "http://www.w3.org/2000/svg";

    // CLASS DEFINITION
    // ======================

    var LadbLabelEditor = function (element, options) {
        this.options = options;
        this.$element = $(element);

        this.$editingElement = null;
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
                    formula: 'name',
                    x: 1,
                    y: 1,
                    fontSize: 1,
                    textAnchor: 'start'
                }

                that.elementDefs.push(elementDef);
                that.editElement(that.appendElementDef(elementDef), elementDef);

            })
        ;

        var $btnRemove = $('<button class="btn btn-danger" style="display: none;"><i class="ladb-opencutlist-icon-minus"></i> Supprimer le champ</button>');
        $btnRemove
            .on('click', function () {
                that.elementDefs.splice(that.elementDefs.indexOf(that.$editingElement.data('def')), 1);
                that.$editingElement.remove();
                that.editElement(null);
                $(this).hide();
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
        var group, text, crossLineV, crossLineH;

        group = document.createElementNS(XMLNS, 'g');
        group.setAttributeNS(null, 'class', 'draggable');
        group.setAttributeNS(null, 'transform', 'translate(' + elementDef.x * this.options.xUnit + ' ' + elementDef.y * this.options.yUnit + ')');
        this.svg.appendChild(group);

        $(group).data('def', elementDef);

        crossLineH = document.createElementNS(XMLNS, 'line');
        crossLineH.setAttributeNS(null, 'x1', -this.options.minUnit / 2);
        crossLineH.setAttributeNS(null, 'y1', 0);
        crossLineH.setAttributeNS(null, 'x2', this.options.minUnit / 2);
        crossLineH.setAttributeNS(null, 'y2', 0);
        crossLineH.setAttributeNS(null, 'stroke', '#f00');
        crossLineH.setAttributeNS(null, 'stroke-width', 0.01);
        group.appendChild(crossLineH);

        crossLineV = document.createElementNS(XMLNS, 'line');
        crossLineV.setAttributeNS(null, 'x1', 0);
        crossLineV.setAttributeNS(null, 'y1', -this.options.minUnit / 2);
        crossLineV.setAttributeNS(null, 'x2', 0);
        crossLineV.setAttributeNS(null, 'y2', this.options.minUnit / 2);
        crossLineV.setAttributeNS(null, 'stroke', '#f00');
        crossLineV.setAttributeNS(null, 'stroke-width', 0.01);
        group.appendChild(crossLineV);

        text = document.createElementNS(XMLNS, 'text');
        text.setAttributeNS(null, 'x', 0);
        text.setAttributeNS(null, 'y', 0);
        text.setAttributeNS(null, 'font-size', elementDef.fontSize * this.options.minUnit);
        text.setAttributeNS(null, 'text-anchor', elementDef.textAnchor);
        text.appendChild(document.createTextNode(this.options.part[elementDef.formula]));
        group.appendChild(text);

        return group;
    }

    LadbLabelEditor.prototype.editElement = function (element, elementDef) {
        var that = this;

        // Editing flag
        if (this.$editingElement) {
            this.$editingElement.removeClass('editing');
        }
        if (element == null) {
            this.$editingElement = null;
            if (this.$editingForm) {
                this.$editingForm.remove();
            }
            return;
        }
        this.$editingElement = $(element)
        this.$editingElement.addClass('editing');

        if (this.$btnRemove) {
            this.$btnRemove.show();
        }

        var editingText = this.$editingElement.children('text')[0];

        // Form
        if (this.$editingForm) {
            this.$editingForm.remove();
        }
        this.$editingForm = $('<div class="form-horizontal row"></div>');
        this.$element.append(this.$editingForm);

        var $selectFormula = $('<select class="form-control">' +
            '<option value="number">' + i18next.t('tab.cutlist.list.number') + '</option>' +
            '<option value="name">' + i18next.t('tab.cutlist.list.name') + '</option>' +
            '<option value="length">' + i18next.t('tab.cutlist.list.length') + '</option>' +
            '<option value="width">' + i18next.t('tab.cutlist.list.width') + '</option>' +
            '</select>');
        this.$editingForm.append(
            $('<div class="col-xs-4"></div>')
                .append($('<label>Valeur</label>'))
                .append($selectFormula)
        );
        $selectFormula
            .val(elementDef.formula)
            .selectpicker(SELECT_PICKER_OPTIONS)
            .on('change', function () {
                elementDef.formula = $selectFormula.val();
                editingText.innerHTML = '';
                editingText.appendChild(document.createTextNode(that.options.part[elementDef.formula]));
            })
        ;

        var $selectFontSize = $('<select class="form-control ">' +
                '<option value="1">1</option>' +
                '<option value="1.5">1.5</option>' +
                '<option value="2">2</option>' +
                '<option value="3">3</option>' +
                '<option value="4">4</option>' +
            '</select>');
        this.$editingForm.append(
            $('<div class="col-xs-4"></div>')
                .append($('<label>Taille</label>'))
                .append($selectFontSize)
        );
        $selectFontSize
            .val(elementDef.fontSize)
            .selectpicker(SELECT_PICKER_OPTIONS)
            .on('change', function () {
                elementDef.fontSize = $selectFontSize.val();
                editingText.setAttributeNS(null, 'font-size', elementDef.fontSize * that.options.minUnit);
            })
        ;

        var $selectTextAnchor = $('<select class="form-control">' +
                '<option value="start">START</option>' +
                '<option value="middle">MIDDLE</option>' +
                '<option value="end">END</option>' +
            '</select>');
        this.$editingForm.append(
            $('<div class="col-xs-4"></div>')
                .append($('<label>Ancrage</label>'))
                .append($selectTextAnchor)
        );
        $selectTextAnchor
            .val(elementDef.textAnchor)
            .selectpicker(SELECT_PICKER_OPTIONS)
            .on('change', function () {
                elementDef.textAnchor = $selectTextAnchor.val();
                editingText.setAttributeNS(null, 'text-anchor', elementDef.textAnchor);
            })
        ;

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
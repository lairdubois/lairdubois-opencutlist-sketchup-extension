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
                    textAnchor: 'start'
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
            }
        }, this.options));
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
        this.$editingForm = $('<div class="form-horizontal row"></div>');
        this.$element.append(this.$editingForm);

        var $selectFormula = $('<select class="form-control">' +
            '<option value="part.number">' + i18next.t('tab.cutlist.label.formula.part_number') + '</option>' +
            '<option value="part.name">' + i18next.t('tab.cutlist.label.formula.part_name') + '</option>' +
            '<option value="part.length">' + i18next.t('tab.cutlist.label.formula.part_length') + '</option>' +
            '<option value="part.width">' + i18next.t('tab.cutlist.label.formula.part_width') + '</option>' +
            '<option value="part.size">' + i18next.t('tab.cutlist.label.formula.part_size') + '</option>' +
            '<option value="part.tags">' + i18next.t('tab.cutlist.label.formula.part_tags') + '</option>' +
            '<option value="batch">' + i18next.t('tab.cutlist.label.formula.batch') + '</option>' +
            '<option data-divider="true"></option>' +
            '<option value="group.material_name">' + i18next.t('tab.cutlist.label.formula.group_material_name') + '</option>' +
            '<option value="group.std_dimension">' + i18next.t('tab.cutlist.label.formula.group_std_dimension') + '</option>' +
            '<option data-divider="true"></option>' +
            '<option value="filename">' + i18next.t('tab.cutlist.label.formula.filename') + '</option>' +
            '<option value="page_label">' + i18next.t('tab.cutlist.label.formula.page_label') + '</option>' +
            '<option value="length_unit">' + i18next.t('tab.cutlist.label.formula.length_unit') + '</option>' +
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
                that.appendFormula(xTextGroup, elementDef);
            })
        ;

        var $selectFontSize = $('<select class="form-control ">' +
                '<option value="0.5">0.5</option>' +
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
                xText.setAttributeNS(null, 'font-size', elementDef.fontSize * that.options.minUnit);
            })
        ;

        var $selectTextAnchor = $('<select class="form-control">' +
                '<option value="start" data-content="<i class=\'ladb-opencutlist-icon-anchor-start\'></i> ' + i18next.t('tab.cutlist.labels.option_text_anchor_start') + '"></option>' +
                '<option value="middle" data-content="<i class=\'ladb-opencutlist-icon-anchor-middle\'></i> ' + i18next.t('tab.cutlist.labels.option_text_anchor_middle') + '"></option>' +
                '<option value="end" data-content="<i class=\'ladb-opencutlist-icon-anchor-end\'></i> ' + i18next.t('tab.cutlist.labels.option_text_anchor_end') + '"></option>' +
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
                xText.setAttributeNS(null, 'text-anchor', elementDef.textAnchor);
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
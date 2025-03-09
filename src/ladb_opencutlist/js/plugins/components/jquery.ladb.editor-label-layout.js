+function ($) {
    'use strict';

    const XMLNS = "http://www.w3.org/2000/svg";
    const GRID_DIVISION = 12;
    const LABEL_MAX_WIDTH = 400;
    const LABEL_MAX_HEIGHT = 300;

    // CLASS DEFINITION
    // ======================

    const LadbEditorLabelLayout = function (element, options, dialog) {
        this.options = options;
        this.$element = $(element);
        this.dialog = dialog;

        this.$editingSvgGroup = null;
        this.$editingForm = null;

        this.entry = null;

    };

    LadbEditorLabelLayout.DEFAULTS = {
        group: null,
        partId: null,
        labelWidth: 100,
        labelHeight: 100,
        hideMaterialColors: false
    };

    LadbEditorLabelLayout.prototype.createSvg = function () {
        const that = this;

        // Check invalid size
        if (this.options.labelWidth <= 0 || isNaN(this.options.labelWidth) || this.options.labelHeight <= 0 || isNaN(this.options.labelHeight)) {

            this.$element.append(Twig.twig({ref: 'core/_alert-errors.twig'}).render({
                errors: [ 'tab.cutlist.labels.error.invalid_size' ]
            }));

            return;
        }

        const $sizeContainer = $('<div class="ladb-editor-label-layout-size">');
        that.$element.prepend($sizeContainer);

        rubyCallCommand('core_float_to_length', {
            width: this.options.labelWidth,
            height: this.options.labelHeight,
        }, function (response) {

            $sizeContainer.append(i18next.t('tab.cutlist.labels.size') + ' : ' + response.width.replace('~', '') + ' x ' + response.height.replace('~', ''));

        })

        const $svgContainer = $('<div class="ladb-editor-label-layout-preview"></div>');
        this.$element.append($svgContainer);

        const svg = document.createElementNS(XMLNS, 'svg');
        $svgContainer.append(svg);
        svg.setAttributeNS(null, 'focusable', 'true');
        svg.setAttributeNS(null, 'tabindex', '-1');
        svg.setAttributeNS(null, 'viewBox', '0 0 ' + this.options.labelWidth + ' ' + this.options.labelHeight);
        if (this.options.labelHeight > this.options.labelWidth) {
            svg.setAttributeNS(null, 'width',  (LABEL_MAX_HEIGHT / this.options.labelHeight) * this.options.labelWidth + 'px');
            svg.setAttributeNS(null, 'height', LABEL_MAX_HEIGHT + 'px');
        } else {
            svg.setAttributeNS(null, 'width',   LABEL_MAX_WIDTH + 'px');
            svg.setAttributeNS(null, 'height', (LABEL_MAX_WIDTH / this.options.labelWidth) * this.options.labelHeight + 'px');
        }

        this.svg = svg;

        const svgLabel = document.createElementNS(XMLNS, 'g');
        svg.appendChild(svgLabel);
        svgLabel.setAttributeNS(null, 'transform', 'translate(' + this.options.labelWidth / 2 + ' ' + this.options.labelHeight / 2 + ')');

        this.svgLabel = svgLabel;

        // Grid lines

        const svgGrid = document.createElementNS(XMLNS, 'g');
        svgLabel.appendChild(svgGrid);

        const fnDrawLine = function (x1, y1, x2, y2, stroke) {
            const svgLine = document.createElementNS(XMLNS, 'line');
            svgGrid.appendChild(svgLine);
            svgLine.setAttributeNS(null, 'x1', x1);
            svgLine.setAttributeNS(null, 'y1', y1);
            svgLine.setAttributeNS(null, 'x2', x2);
            svgLine.setAttributeNS(null, 'y2', y2);
            svgLine.setAttributeNS(null, 'stroke', stroke ? stroke : '#ddd');
            svgLine.setAttributeNS(null, 'stroke-width', 0.01 );
            svgLine.setAttributeNS(null, 'stroke-dasharray', that.options.minUnit / 10);
        }

        let y = 0;
        while (y < this.options.labelHeight / 2) {
            if (y > 0) {
                fnDrawLine(-this.options.labelWidth / 2, -y, this.options.labelWidth / 2, -y);
            }
            fnDrawLine(-this.options.labelWidth / 2, y, this.options.labelWidth / 2, y, y === 0 ? '#999' : null);
            y = y + this.options.minUnit;
        }
        let x = 0;
        while (x < this.options.labelWidth / 2) {
            if (x > 0) {
                fnDrawLine(-x, -this.options.labelHeight / 2, -x, this.options.labelHeight / 2);
            }
            fnDrawLine(x, -this.options.labelHeight / 2, x, this.options.labelHeight / 2, x === 0 ? '#999' : null);
            x = x + this.options.minUnit;
        }

        const fnGetMousePosition = function (e) {
            const CTM = svg.getScreenCTM();
            return {
                x: (e.clientX - CTM.e) / CTM.a,
                y: (e.clientY - CTM.f) / CTM.d
            };
        }

        let selectedElement, selectedElementDef, offset, transform;
        let dragging = false;
        $(svg)
            .on('mousedown', function (e) {
                const $draggable = $(e.target).closest('.draggable');
                if ($draggable.length > 0) {

                    selectedElement = $draggable[0];
                    selectedElementDef = $draggable.data('def');
                    offset = fnGetMousePosition(e);

                    that.editElement(selectedElement, selectedElementDef);

                    // Get all the transforms currently on this element
                    const transforms = selectedElement.transform.baseVal;

                    // Ensure the first transform is a translate transform
                    if (transforms.length === 0 || transforms.getItem(0).type !== SVGTransform.SVG_TRANSFORM_TRANSLATE) {

                        // Create an transform that translates by (0, 0)
                        const translate = svg.createSVGTransform();
                        translate.setTranslate(0, 0);

                        // Add the translation to the front of the transforms list
                        selectedElement.transform.baseVal.insertItemBefore(translate, 0);

                    }

                    // Get initial translation amount
                    transform = transforms.getItem(0);
                    offset.x -= transform.matrix.e;
                    offset.y -= transform.matrix.f;

                    dragging = true;

                } else {
                    that.editElement(null);
                    selectedElement = null;
                    selectedElementDef = null;
                }
            })
            .on('mousemove', function (e) {
                if (dragging && selectedElement) {
                    e.preventDefault();
                    const coord = fnGetMousePosition(e);
                    const gridX = Math.round((coord.x - offset.x) / that.options.minUnit);
                    const gridY = Math.round((coord.y - offset.y) / that.options.minUnit);

                    // Update def
                    selectedElementDef.x = Math.min(Math.max(gridX * that.options.minUnit / that.options.labelWidth, -0.5), 0.5);
                    selectedElementDef.y = Math.min(Math.max(gridY * that.options.minUnit / that.options.labelHeight, -0.5), 0.5);

                    // Update element translation
                    transform.setTranslate(selectedElementDef.x * that.options.labelWidth, selectedElementDef.y * that.options.labelHeight);

                }
            })
            .on('mouseup', function (e) {
                dragging = false;
            })
            .on('keydown', function (e) {
                if (selectedElement) {

                    let dx = 0;
                    let dy = 0;
                    switch (e.key) {
                        case "Down": // IE/Edge specific value
                        case "ArrowDown":
                            dy = 1;
                            break;
                        case "Up": // IE/Edge specific value
                        case "ArrowUp":
                            dy = -1;
                            break;
                        case "Left": // IE/Edge specific value
                        case "ArrowLeft":
                            dx = -1;
                            break;
                        case "Right": // IE/Edge specific value
                        case "ArrowRight":
                            dx = 1;
                            break;
                        default:
                            return;
                    }

                    // Prevent default event behavior
                    e.preventDefault();

                    // Snap to grid
                    const gridX = Math.round(selectedElementDef.x * that.options.labelWidth / that.options.minUnit + dx);
                    const gridY = Math.round(selectedElementDef.y * that.options.labelHeight / that.options.minUnit + dy);

                    // Update def
                    selectedElementDef.x = Math.min(Math.max(gridX * that.options.minUnit / that.options.labelWidth, -0.5), 0.5);
                    selectedElementDef.y = Math.min(Math.max(gridY * that.options.minUnit / that.options.labelHeight, -0.5), 0.5);

                    // Update element translation
                    transform.setTranslate(selectedElementDef.x * that.options.labelWidth, selectedElementDef.y * that.options.labelHeight);

                }
            })
        ;

        // Append elementDefs
        for (let i = 0; i < this.elementDefs.length; i++) {
            this.appendElementDef(this.elementDefs[i]);
        }

        const $btnAdd = $('<button class="btn btn-default"><i class="ladb-opencutlist-icon-plus"></i> ' + i18next.t('tab.cutlist.labels.add_element') + '</button>');
        $btnAdd
            .on('click', function () {

                const elementDef = {
                    formula: 'part.name',
                    x: 0,
                    y: 0,
                    rotation: 0,
                    size: 1,
                    anchor: 'middle',
                    color: '#000000'
                }

                that.elementDefs.push(elementDef);
                that.editElement(that.appendElementDef(elementDef), elementDef);

            })
        ;
        const $btnRemoveAll = $('<button class="btn btn-danger"><i class="ladb-opencutlist-icon-clear"></i> ' + i18next.t('tab.cutlist.labels.remove_all_elements') + '</button>');
        $btnRemoveAll
            .on('click', function () {

                that.elementDefs.length = 0;
                $('g.draggable', $(svg)).remove();

            })
        ;

        const $btnContainer = $('<div style="display: inline-block" />')

        this.$element.append(
            $('<div class="ladb-editor-label-layout-buttons" style="margin: 10px;"></div>')
                .append($btnAdd)
                .append('&nbsp;')
                .append($btnRemoveAll)
                .append($btnContainer)
        );

        this.$btnRemoveAll = $btnRemoveAll;
        this.$btnContainer = $btnContainer;

    };

    LadbEditorLabelLayout.prototype.appendElementDef = function (elementDef) {
        let svgGroup, svgCrossLineV, svgCrossLineH, svgContentGroup;

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

        svgContentGroup = document.createElementNS(XMLNS, 'g');
        svgContentGroup.setAttributeNS(null, 'transform', 'rotate(' + elementDef.rotation + ')');
        svgGroup.appendChild(svgContentGroup);

        this.appendFormula(svgContentGroup, elementDef);

        return svgGroup;
    }

    LadbEditorLabelLayout.prototype.appendFormula = function (svgContentGroup, elementDef) {

        const formula = Twig.twig({ref: 'tabs/cutlist/_label-element.twig'}).render($.extend({
            index: this.elementDefs ? this.elementDefs.indexOf(elementDef) : 0,
            elementDef: elementDef,
            entry: this.entry,
            noEmptyValue: true,
            hideMaterialColors: this.options.hideMaterialColors
        }, this.options));

        // Workaround to avoid use of innerHtml on an svg element (not implemented on IE and Safari)
        svgContentGroup.innerHTML = ''; // doesn't work in IE but works on Chrome
        svgContentGroup.textContent = ''; // works on IE
        const tmpDiv = document.createElement('div');
        const tmpSvg = '<svg>' + formula + '</svg>';
        tmpDiv.innerHTML = '' + tmpSvg;
        Array.prototype.slice.call(tmpDiv.childNodes[0].childNodes).forEach(function (el) {
            svgContentGroup.appendChild(el)
        })

        const svgContent = $(svgContentGroup).children('.ladb-label-element')[0];
        if (svgContent) {
            const bbox = svgContent.getBBox();
            const svgSelectionRect = document.createElementNS(XMLNS, 'rect');
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
            svgContentGroup.insertBefore(svgSelectionRect, svgContent);
        }

    }

    LadbEditorLabelLayout.prototype.editElement = function (svgElement, elementDef) {
        const that = this;

        // Cleanup
        if (this.$editingForm) {
            this.$editingForm.remove();
        }
        if (this.$btnContainer) {
            this.$btnContainer.empty();
        }
        if (this.$btnRemoveAll) {
            if (svgElement) {
                this.$btnRemoveAll.hide();
            } else {
                this.$btnRemoveAll.show();
            }
        }

        // Editing flag
        if (this.$editingSvgGroup) {
            this.$editingSvgGroup.removeClass('active');
        }
        if (svgElement == null) {
            this.$editingSvgGroup = null;
            return;
        }
        this.$editingSvgGroup = $(svgElement)
        this.$editingSvgGroup.addClass('active');

        const svgContentGroup = this.$editingSvgGroup.children('g')[0];

        // Buttons

        const $btnDuplicate = $('<button class="btn btn-default"><i class="ladb-opencutlist-icon-copy"></i> ' + i18next.t('tab.cutlist.labels.duplicate_element') + '</button>');
        $btnDuplicate
            .on('click', function () {

                const newElementDef = JSON.parse(JSON.stringify(elementDef));
                const dx = that.options.minUnit / that.options.labelWidth;
                const dy = that.options.minUnit / that.options.labelHeight;
                if (newElementDef.x < 0) newElementDef.x += dx; else newElementDef.x -= dx;
                if (newElementDef.y < 0) newElementDef.y += dy; else newElementDef.y -= dy;

                that.elementDefs.push(newElementDef);

                const index = that.elementDefs.indexOf(elementDef);
                const newIndex = that.elementDefs.indexOf(newElementDef);
                that.entry.custom_values[newIndex] = that.entry.custom_values[index];

                that.editElement(that.appendElementDef(newElementDef), newElementDef);

            })
        ;

        const $btnRemove = $('<button class="btn btn-danger"><i class="ladb-opencutlist-icon-clear"></i> ' + i18next.t('tab.cutlist.labels.remove_element') + '</button>');
        $btnRemove
            .on('click', function () {
                that.elementDefs.splice(that.elementDefs.indexOf(elementDef), 1);
                that.$editingSvgGroup.remove();
                that.editElement(null);
            })
        ;

        const $btnRotateLeft = $('<button class="btn btn-default"><i class="ladb-opencutlist-icon-rotate-left" style="font-size: 120%"></i></button>');
        $btnRotateLeft
            .on('click', function () {
                if (elementDef.rotation === undefined) {
                    elementDef.rotation = 0;
                }
                elementDef.rotation = (elementDef.rotation - 90) % 360;
                svgContentGroup.setAttributeNS(null, 'transform', 'rotate(' + elementDef.rotation + ')');
                this.blur();
            })
        ;

        const $btnRotateRight = $('<button class="btn btn-default"><i class="ladb-opencutlist-icon-rotate-right" style="font-size: 120%"></i></button>');
        $btnRotateRight
            .on('click', function () {
                if (elementDef.rotation === undefined) {
                    elementDef.rotation = 0;
                }
                elementDef.rotation = (elementDef.rotation + 90) % 360;
                svgContentGroup.setAttributeNS(null, 'transform', 'rotate(' + elementDef.rotation + ')');
                this.blur();
            })
        ;

        this.$btnContainer
            .append($btnDuplicate)
            .append('&nbsp;')
            .append($btnRemove)
            .append('<div style="display: inline-block; width: 20px;" />')
            .append($btnRotateLeft)
            .append('&nbsp;')
            .append($btnRotateRight)
        ;

        // Form
        this.$editingForm = $(Twig.twig({ref: 'components/_editor-label-element-form.twig'}).render());
        this.$element.append(this.$editingForm);

        // UI
        const $selectFormula = $('#ladb_select_formula', this.$editingForm);
        const $selectSize = $('#ladb_select_size', this.$editingForm);
        const $divCustomFormula = $('#ladb_div_custom_formula', this.$editingForm);
        const $textareaCustomFormula = $('#ladb_textarea_custom_formula', this.$editingForm);
        const $selectAnchor = $('#ladb_select_anchor', this.$editingForm);
        const $inputColor = $('#ladb_input_color', this.$editingForm);

        const fnConvertToVariableDefs = function (vars) {

            // Generate variableDefs for formula editor
            const variableDefs = [];
            for (let i = 0; i < vars.length; i++) {
                variableDefs.push({
                    text: vars[i].name,
                    displayText: i18next.t('tab.cutlist.export.' + vars[i].name),
                    type: vars[i].type
                });
            }

            return variableDefs;
        }
        const fnUpdateCustomFormulaVisibility = function () {
            if (elementDef.formula.startsWith('custom')) {
                $divCustomFormula.show();
            } else {
                $divCustomFormula.hide();
            }
        }
        const fnComputeCustomFormula = function () {
            rubyCallCommand('cutlist_labels', { part_ids: [ that.options.partId ], layout: [ elementDef ], compute_first_instance_only: true }, function (response) {

                if (response.errors) {
                    console.log(response.errors);
                }
                if (response.entries) {
                    for (const entry of response.entries) {
                        entry.group = that.options.group;
                    }
                    const index = that.elementDefs.indexOf(elementDef);
                    that.entry.custom_values[index] = response.entries[0].custom_values[0];
                    that.appendFormula(svgContentGroup, elementDef);
                    fnUpdateCustomFormulaVisibility();
                }

            });
        }

        fnUpdateCustomFormulaVisibility();

        // Bind
        $selectFormula
            .val(elementDef.formula)
            .selectpicker(SELECT_PICKER_OPTIONS)
            .on('change', function () {
                elementDef.formula = $(this).val();
                if (elementDef.formula.startsWith('custom') && elementDef.custom_formula == null) {
                    elementDef.custom_formula = '';
                    $textareaCustomFormula.ladbTextinputCode('val', '');
                }
                fnComputeCustomFormula();
            })
        ;
        $selectSize
            .val(elementDef.size)
            .selectpicker(SELECT_PICKER_OPTIONS)
            .on('change', function () {
                elementDef.size = $(this).val();
                that.appendFormula(svgContentGroup, elementDef);
            })
        ;
        $textareaCustomFormula
            .val(elementDef.custom_formula)
            .ladbTextinputCode({
                variableDefs: fnConvertToVariableDefs([
                    { name: 'number', type: 'string' },
                    { name: 'path', type: 'path' },
                    { name: 'instance_name', type: 'string' },
                    { name: 'name', type: 'string' },
                    { name: 'cutting_length', type: 'length' },
                    { name: 'cutting_width', type: 'length' },
                    { name: 'cutting_thickness', type: 'length' },
                    { name: 'edge_cutting_length', type: 'length' },
                    { name: 'edge_cutting_width', type: 'length' },
                    { name: 'bbox_length', type: 'length' },
                    { name: 'bbox_width', type: 'length' },
                    { name: 'bbox_thickness', type: 'length' },
                    { name: 'final_area', type: 'area' },
                    { name: 'material', type: 'material' },
                    { name: 'material_type', type: 'material-type' },
                    { name: 'material_name', type: 'string' },
                    { name: 'material_description', type: 'string' },
                    { name: 'material_url', type: 'string' },
                    { name: 'description', type: 'string' },
                    { name: 'url', type: 'string' },
                    { name: 'tags', type: 'array' },
                    { name: 'edge_ymin', type: 'edge' },
                    { name: 'edge_ymax', type: 'edge' },
                    { name: 'edge_xmin', type: 'edge' },
                    { name: 'edge_xmax', type: 'edge' },
                    { name: 'face_zmax', type: 'veneer' },
                    { name: 'face_zmin', type: 'veneer' },
                    { name: 'layer', type: 'string' },
                    { name: 'component_definition', type: 'component_definition' },
                    { name: 'component_instance', type: 'component_instance' },
                    { name: 'batch', type: 'batch' },
                    { name: 'bin', type: 'integer' },
                    { name: 'filename', type: 'string' },
                    { name: 'model_name', type: 'string' },
                    { name: 'model_description', type: 'string' },
                    { name: 'page_name', type: 'string' },
                    { name: 'page_description', type: 'string' }
                ]),
                snippetDefs: [
                    { name: i18next.t('tab.cutlist.snippet.hello') + ' 👋', value: '"' + i18next.t('tab.cutlist.snippet.hello') + ' 👋"' },
                    { name: '-' },
                    { name: i18next.t('tab.cutlist.snippet.number'), value: '@number' },
                    { name: i18next.t('tab.cutlist.snippet.name'), value: '@name' },
                    { name: i18next.t('tab.cutlist.snippet.number_and_name'), value: '@number + " - " + @name' },
                    { name: '-' },
                    { name: i18next.t('tab.cutlist.snippet.size'), value: '@bbox_length + " x " + @bbox_width' },
                    { name: i18next.t('tab.cutlist.snippet.area'), value: '@bbox_length * @bbox_width' },
                    { name: i18next.t('tab.cutlist.snippet.volume'), value: '@bbox_length * @bbox_width * @bbox_thickness' },
                ]
            })
            .on('change', function () {
                elementDef.custom_formula = $(this).val();
                fnComputeCustomFormula();
            })
        ;
        $selectAnchor
            .val(elementDef.anchor)
            .selectpicker(SELECT_PICKER_OPTIONS)
            .on('change', function () {
                elementDef.anchor = $(this).val();
                that.appendFormula(svgContentGroup, elementDef);
            })
        ;
        $inputColor
            .val(elementDef.color)
            .ladbTextinputColor()
            .on('change', function () {
                elementDef.color = $(this).val();
                that.appendFormula(svgContentGroup, elementDef);
            })
        ;

        this.dialog.setupTooltips(this.$element);

    };

    LadbEditorLabelLayout.prototype.updateSize = function (labelWidth, labelHeight) {

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

    LadbEditorLabelLayout.prototype.updateSizeAndElementDefs = function (labelWidth, labelHeight, elementDefs) {
        const that = this;

        this.elementDefs = elementDefs;

        rubyCallCommand('cutlist_labels', { part_ids: [ this.options.partId ], layout: elementDefs, compute_first_instance_only: true }, function (response) {

            if (response.errors) {
                console.log(response.errors);
            }
            if (response.entries) {
                that.entry = response.entries[0];
                that.entry.group = that.options.group;
            }

            // Empty the container
            that.updateSize(labelWidth, labelHeight);

        });

    };

    LadbEditorLabelLayout.prototype.getElementDefs = function () {
        return this.elementDefs;
    };

    LadbEditorLabelLayout.prototype.init = function () {
    };

    // PLUGIN DEFINITION
    // =======================

    function Plugin(option, params) {
        let value;
        const elements = this.each(function () {
            const $this = $(this);
            let data = $this.data('ladb.editorLabelLayout');
            if (!data) {
                const options = $.extend({}, LadbEditorLabelLayout.DEFAULTS, $this.data(), typeof option === 'object' && option);
                $this.data('ladb.editorLabelLayout', (data = new LadbEditorLabelLayout(this, options, options.dialog)));
            }
            if (typeof option === 'string') {
                value = data[option].apply(data, Array.isArray(params) ? params : [ params ])
            } else {
                data.init(params);
            }
        });
        return typeof value !== 'undefined' ? value : elements;
    }

    const old = $.fn.ladbEditorLabelLayout;

    $.fn.ladbEditorLabelLayout = Plugin;
    $.fn.ladbEditorLabelLayout.Constructor = LadbEditorLabelLayout;


    // NO CONFLICT
    // =================

    $.fn.ladbEditorLabelLayout.noConflict = function () {
        $.fn.ladbEditorLabelLayout = old;
        return this;
    }

}(jQuery);
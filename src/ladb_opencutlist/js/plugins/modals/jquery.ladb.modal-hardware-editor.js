+function ($) {
    'use strict';

    // CONSTANTS
    // ======================

    const COMPUTE_DELAY = 300;  // ms after the last edit

    // The size of the editor while a part is shaped in SketchUp
    const SHAPING_WIDTH = 380;
    const SHAPING_HEIGHT = 240;

    const PARTS = [ 'hardware', 'machining' ];
    const PRIMITIVE_KEYS = [ 'cylinders', 'oblongs', 'drillings', 'mortises' ];

    // 4x4 matrices, column after column - as THREE.Matrix4#fromArray
    const IDENTITY = [ 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1 ];
    const fnMultiply = function (a, b) {
        const m = [];
        for (let col = 0; col < 4; col++) {
            for (let row = 0; row < 4; row++) {
                let sum = 0;
                for (let k = 0; k < 4; k++) {
                    sum += a[k * 4 + row] * b[col * 4 + k];
                }
                m.push(Math.round(sum * 1e9) / 1e9 + 0);   // + 0 : no -0
            }
        }
        return m;
    };
    const fnIsIdentity = function (m) {
        return m.every(function (v, i) { return Math.abs(v - IDENTITY[i]) < 1e-9; });
    };
    // A quarter turn around the given axis, or the mirror across YZ
    const PLACEMENT_MATRICES = {
        x: [ 1, 0, 0, 0, 0, 0, 1, 0, 0, -1, 0, 0, 0, 0, 0, 1 ],
        y: [ 0, 0, -1, 0, 0, 1, 0, 0, 1, 0, 0, 0, 0, 0, 0, 1 ],
        z: [ 0, 1, 0, 0, -1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1 ],
        mirror: [ -1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1 ]
    };

    // A new descriptor of the given type : empty, its slots to fill.
    const fnNewDescriptor = function (type) {
        return {
            format: 'ocl-hardware',
            version: 1,
            id: fnUuid(),
            type: type,
            name: i18next.t('core.hardware_editor.new_name'),
            variables: {},
            asserts: [],
            components: {
                a: {},
                b: {}
            }
        };
    };

    const fnUuid = function () {
        return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function (c) {
            const r = Math.random() * 16 | 0;
            return (c === 'x' ? r : (r & 0x3 | 0x8)).toString(16);
        });
    };

    // A file name - no folder, no extension - from the given text.
    const fnSanitizeFileName = function (text) {
        return text.replace(/[\\/:*?"<>|]/g, '-').replace(/\.json$/i, '').trim();
    };

    const FILE_NAME_REGEX = /^[^.\\/:*?"<>|][^\\/:*?"<>|]*$/;

    // The name of the file of the given ref, without its extension.
    const fnFileStem = function (ref) {
        return ref.substring(ref.lastIndexOf('/') + 1).replace(/\.json$/i, '');
    };

    // CodeMirror mode of the descriptor : JSON, its keys apart, the @variables
    // of its expressions spotted.
    CodeMirror.defineSimpleMode('ocl-hardware-json', {
        start: [
            { regex: /"(?:[^\\"]|\\.)*"(?=\s*:)/, token: 'property' },
            { regex: /"/, token: 'string', push: 'string' },
            { regex: /-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?/, token: 'number' },
            { regex: /(?:true|false|null)\b/, token: 'atom' },
            { regex: /[{\[]/, indent: true },
            { regex: /[}\]]/, dedent: true },
        ],
        string: [
            { regex: /"/, token: 'string', pop: true },
            { regex: /@[A-Za-z_]\w*/, token: 'variable-2' },
            { regex: /(?:[^\\"@]|\\.)+/, token: 'string' },
            { regex: /@/, token: 'string' },
        ],
        meta: {
            electricChars: '}]'
        }
    });

    // CLASS DEFINITION
    // ======================

    const LadbModalHardwareEditor = function (element, options, dialog) {
        LadbAbstractModal.call(this, element, options, dialog);

        this.ref = null;
        this.readonly = false;
        this.fileName = null;   // Typed : the file is written - renamed - with it

        this.topology = null;
        this.response = null;

        this._computeTimeout = null;
        this._computeId = 0;
        this._settingsSignature = null;
        this._benchDef = null;
        this._errorLine = null;

        // SKP files, by ref : their meshes - by source - the ones picked to
        // replace them, and the placement to bake into them at save.
        this.meshes = {};
        this.imports = {};
        this.placements = {};

        this.shaping = null;    // A part edited in SketchUp : { ref, size }

    };
    LadbModalHardwareEditor.prototype = Object.create(LadbAbstractModal.prototype);

    LadbModalHardwareEditor.DEFAULTS = {
        ref: null,
        type: null,
        dir_ref: null
    };

    // Compute /////

    LadbModalHardwareEditor.prototype.compute = function (delayed) {
        const that = this;

        clearTimeout(this._computeTimeout);
        if (delayed) {
            this._computeTimeout = setTimeout(function () {
                that.compute(false);
            }, COMPUTE_DELAY);
            return;
        }

        const computeId = ++this._computeId;
        rubyCallCommand('hardware_bench_compute', {
            descriptor: this.cm.getValue(),
            ref: this.ref || this.provisionalRef(),
            topology: this.topology,
            thickness_a: this.$inputThicknessA.val(),
            thickness_b: this.$inputThicknessB.val()
        }, function (response) {
            if (computeId !== that._computeId) {
                return; // An older one, overtaken by an edit
            }
            if (response.type === undefined && that.response && that.response.type !== undefined) {
                // Not a descriptor for now - the JSON is being typed : the last bench stays
                that.renderErrors(response.errors);
                return;
            }
            that.response = response;
            that.topology = response.topology || that.topology;
            that.renderName();
            that.renderTopologies();
            that.renderBench();
            that.renderComputations();
            that.renderSettings();
            that.renderParts();
            that.renderErrors();
            that.renderStatus();
            that.fetchMeshes();
        });

    };

    // Render /////

    LadbModalHardwareEditor.prototype.renderName = function () {
        let name = null;
        try {
            name = JSON.parse(this.cm.getValue()).name;
        } catch (e) {
            // Keep the previous one while the JSON is being edited
            return;
        }
        $('.ladb-hardware-editor-name', this.$element).text(typeof name === 'string' ? name : '');
        if (!this.$inputName.is(':focus')) {
            this.$inputName.val(typeof name === 'string' ? name : '');
        }
        this.$inputName.prop('disabled', this.readonly || typeof name !== 'string');
        this.renderFile();
    };

    LadbModalHardwareEditor.prototype.renderFile = function () {
        const dirRef = this.fileDirRef();
        const targetRef = this.targetRef();
        $('.ladb-hardware-editor-file-dir', this.$element)
            .text(dirRef ? '\u200E' + dirRef + '/\u200E' : '')   // LRM : the rtl ellipsis mustn't move '$' and '/' around
            .attr('title', dirRef ? dirRef + '/' : '');
        if (!this.$inputFile.is(':focus')) {
            this.$inputFile.val(this.fileStem());
        }
        this.$inputFile.prop('disabled', this.readonly || !dirRef);
        const renamed = this.ref && targetRef && targetRef !== this.ref;
        $('.ladb-hardware-editor-file-renamed', this.$element)
            .text(renamed ? i18next.t('core.hardware_editor.file_renamed', { name: fnFileStem(this.ref) + '.json' }) : '')
            .toggle(!!renamed);
    };

    LadbModalHardwareEditor.prototype.renderTopologies = function () {
        const that = this;

        const topologies = this.response.topologies || [];
        const signature = topologies.join(',');
        if (this.$topologies.data('signature') !== signature) {
            this.$topologies
                .data('signature', signature)
                .empty();
            for (const topology of topologies) {
                this.$topologies.append(
                    $('<button type="button" class="btn btn-default">')
                        .attr('data-topology', topology)
                        .text(this.topologyLabel(topology))
                        .on('click', function () {
                            this.blur();
                            that.topology = topology;
                            that.compute(false);
                        })
                );
            }
        }
        $('button', this.$topologies).each(function () {
            $(this).toggleClass('active', $(this).data('topology') === that.topology);
        });

    };

    LadbModalHardwareEditor.prototype.renderBench = function () {
        const that = this;

        const supported = this.response.supported === true;
        $('.ladb-hardware-editor-trial', this.$element).toggle(supported);
        this.$viewer.toggle(supported);
        this.$unsupported
            .toggle(!supported)
            .text(this.response.type ? i18next.t('core.hardware_editor.unsupported_type', { type: this.response.type }) : i18next.t('core.hardware_editor.no_descriptor'));
        if (!supported) {
            return;
        }

        this._benchDef = {
            panels: this.response.panels,
            solids: this.response.solids,
            skps: this.benchSkps()
        };
        const $threeViewer = $('.ladb-three-viewer', this.$viewer);
        if ($threeViewer.length === 0) {

            // First bench : the viewer is created, the bench given once it is loaded
            const $newThreeViewer = $(Twig.twig({ ref: 'modals/_hardware-editor-three-viewer.twig' }).render({
                THREE_CAMERA_VIEWS: THREE_CAMERA_VIEWS
            }));
            this.$viewer.append($newThreeViewer);
            $newThreeViewer
                .on('loaded.ladb.threeviewer', function () {
                    $newThreeViewer.ladbThreeViewer('callCommand', [ 'setup_bench', { benchDef: that._benchDef } ]);
                })
                .ladbThreeViewer({
                    dialog: this.dialog
                });

        } else if ($threeViewer.data('ladb.threeviewer').loaded) {
            $threeViewer.ladbThreeViewer('callCommand', [ 'setup_bench', { benchDef: this._benchDef } ]);
        }

    };

    LadbModalHardwareEditor.prototype.renderComputations = function () {

        this.$computations.empty();
        if (this.response.supported !== true) {
            return;
        }

        const variables = this.response.variables || [];
        const asserts = this.response.asserts || [];
        const measures = this.response.measures || [];

        const $table = $('<table class="table table-condensed">');

        const fnSlotsLabel = function (results, result) {
            return results.length > 1 ? '<span class="ladb-hardware-editor-slots">' + result.slots.join(', ') + '</span> ' : '';
        };

        // Measures of the bench
        if (measures.length > 0) {
            $table.append($('<tr class="ladb-hardware-editor-computations-header">').append($('<th colspan="3">').text(i18next.t('core.hardware_editor.measures'))));
            for (const measure of measures) {
                $table.append($('<tr>')
                    .append($('<td class="ladb-hardware-editor-computation-name">').text('@' + measure.name))
                    .append($('<td>'))
                    .append($('<td class="ladb-hardware-editor-computation-value">').text(measure.text))
                );
            }
        }

        // Variables, per group of slots they are the same for
        if (variables.length > 0) {
            $table.append($('<tr class="ladb-hardware-editor-computations-header">').append($('<th colspan="3">').text(i18next.t('core.hardware_editor.variables'))));
            for (const variable of variables) {
                const $value = $('<td class="ladb-hardware-editor-computation-value">');
                for (const result of variable.results) {
                    const $result = $('<div>').html(fnSlotsLabel(variable.results, result));
                    if (result.error) {
                        $result
                            .addClass('text-danger')
                            .append($('<span>').text(this.errorLabel(result.error)));
                    } else {
                        $result.append($('<span>').text(result.text));
                    }
                    $value.append($result);
                }
                $table.append($('<tr>')
                    .append($('<td class="ladb-hardware-editor-computation-name">')
                        .text('@' + variable.name)
                        .append(variable.setting ? ' <i class="ladb-opencutlist-icon-settings" title="' + i18next.t('core.hardware_editor.setting') + '"></i>' : '')
                    )
                    .append($('<td class="ladb-hardware-editor-computation-expression">').text(variable.setting ? '' : variable.expression))
                    .append($value)
                );
            }
        }

        // Asserts, both sides in numbers
        if (asserts.length > 0) {
            $table.append($('<tr class="ladb-hardware-editor-computations-header">').append($('<th colspan="3">').text(i18next.t('core.hardware_editor.asserts'))));
            for (const assert of asserts) {
                const $value = $('<td class="ladb-hardware-editor-computation-value">');
                let ok = true;
                for (const result of assert.results) {
                    ok = ok && result.ok;
                    const $result = $('<div>')
                        .addClass(result.ok ? 'text-success' : 'text-danger')
                        .html(fnSlotsLabel(assert.results, result));
                    if (result.left_text === null || result.right_text === null) {
                        $result.append($('<span>').text(i18next.t('core.hardware_editor.assert_unresolved')));
                    } else {
                        $result.append($('<span>').text(result.left_text + ' ' + result.operator + ' ' + result.right_text));
                    }
                    $result.append(' <i class="ladb-opencutlist-icon-' + (result.ok ? 'check-mark' : 'warning') + '"></i>');
                    $value.append($result);
                }
                $table.append($('<tr' + (ok ? '' : ' class="danger"') + '>')
                    .append($('<td class="ladb-hardware-editor-computation-expression" colspan="2">').text(assert.expression))
                    .append($value)
                );
            }
        }

        this.$computations.append($table);

    };

    LadbModalHardwareEditor.prototype.renderSettings = function () {
        const that = this;

        const settings = this.response.settings || [];
        const signature = JSON.stringify(settings.map(function (setting) { return [ setting.name, setting.raw ]; }));
        if (signature === this._settingsSignature) {
            return;
        }
        this._settingsSignature = signature;

        this.$settings.empty();

        if (settings.length === 0) {
            this.$settings.append($('<div class="ladb-hardware-editor-empty">').html(i18next.t('core.hardware_editor.no_settings')));
            return;
        }

        for (const setting of settings) {

            const raw = setting.raw;
            const $formGroup = $('<div class="form-group">');
            const $label = $('<label class="control-label col-xs-5">').text(setting.label || setting.name);
            const $control = $('<div class="col-xs-7">');
            $formGroup
                .append($label)
                .append($control);

            if (Array.isArray(raw.steps)) {

                // A value among its steps
                const $select = $('<select class="form-control">');
                for (const step of raw.steps) {
                    $select.append($('<option>')
                        .attr('value', step)
                        .text(step)
                    );
                }
                $select
                    .val(raw.value)
                    .prop('disabled', this.readonly)
                    .on('change', function () {
                        that.setSettingValue(setting.name, $(this).val());
                    });
                $control.append($select);
                $select.selectpicker(SELECT_PICKER_MODAL_OPTIONS);

            } else {

                // Any length, between its bounds if it has any
                const $input = $('<input type="text" class="form-control">');
                $control.append($input);
                $input
                    .val(typeof raw.value === 'string' ? raw.value : '')
                    .ladbTextinputDimension({ resetValue: typeof raw.value === 'string' ? raw.value : '' })
                    .on('change', function () {
                        const value = $(this).val();
                        if (value !== raw.value) {
                            that.setSettingValue(setting.name, value);
                        }
                    });
                if (setting.min || setting.max) {
                    $control.append($('<div class="help-block">').text(i18next.t('core.hardware_editor.setting_bounds', {
                        min: setting.min ? setting.min.text : '-',
                        max: setting.max ? setting.max.text : '-'
                    })));
                }

            }

            if (this.readonly) {
                $('input', $control).prop('disabled', true);
            }

            this.$settings.append($formGroup);

        }

    };

    LadbModalHardwareEditor.prototype.renderErrors = function (errors) {

        errors = errors || this.response.errors || [];

        // An invalid JSON : where, as the browser's parser tells it - its line marked
        if (this._errorLine !== null) {
            this.cm.removeLineClass(this._errorLine, 'background', 'ladb-hardware-editor-error-line');
            this._errorLine = null;
        }
        const jsonError = this.jsonError();

        this.$errors.empty();
        if (errors.length > 0) {
            const $list = $('<ul>');
            for (const error of errors) {
                if (jsonError && error.indexOf('json:') === 0) {
                    this._errorLine = this.cm.addLineClass(jsonError.line, 'background', 'ladb-hardware-editor-error-line');
                    $list.append($('<li>').text(i18next.t('core.hardware_editor.error.invalid_json', { line: jsonError.line + 1, error: jsonError.message })));
                } else {
                    $list.append($('<li>').text(error));
                }
            }
            this.$errors.append($('<div class="alert alert-danger">').append($list));
        }
        this.$errorCount
            .text(errors.length)
            .toggle(errors.length > 0);

    };

    LadbModalHardwareEditor.prototype.renderStatus = function () {

        const $status = $('.ladb-hardware-editor-status', this.$element).empty();
        if (this.readonly) {
            $status.append($('<span class="label label-default">').text(i18next.t('core.hardware_editor.readonly')));
            $status.append(' ');
        }
        if (this.response.supported !== true) {
            return;
        }
        if (this.response.accepted) {
            $status.append($('<span class="text-success">')
                .append('<i class="ladb-opencutlist-icon-check-mark"></i> ')
                .append($('<span>').text(i18next.t('core.hardware_editor.accepted')))
            );
        } else {
            $status.append($('<span class="text-danger">')
                .append('<i class="ladb-opencutlist-icon-warning"></i> ')
                .append($('<span>').text(i18next.t('core.hardware_editor.refused')))
            );
        }

    };

    // Parts /////

    LadbModalHardwareEditor.prototype.renderParts = function () {
        const that = this;

        let data;
        try {
            data = JSON.parse(this.cm.getValue());
        } catch (e) {
            return; // The JSON is being typed : the parts stay
        }

        const components = data.components && typeof data.components === 'object' ? data.components : {};
        const slots = Object.keys(components);

        this.$parts.empty();
        for (const slot of slots) {

            const component = components[slot];
            const slotResponse = (this.response.slots || {})[slot];
            const resolved = slotResponse ? slotResponse.component : null;
            const $slot = $('<div class="ladb-hardware-editor-slot">');
            const $head = $('<div class="ladb-hardware-editor-slot-head">')
                .append($('<span class="ladb-hardware-editor-slot-letter">').text(slot.toUpperCase()))
                .append($('<span class="ladb-hardware-editor-slot-name">').text(resolved && resolved.name ? resolved.name : (data.name || '')));
            $slot.append($head);
            this.$parts.append($slot);

            if (!component || typeof component !== 'object') {
                $slot.append($('<div class="ladb-hardware-editor-slot-note">').text(i18next.t('core.hardware_editor.parts_no_component')));
                continue;
            }
            if (component.same_as || component.mirror_of) {
                $slot.append($('<div class="ladb-hardware-editor-slot-note">').text(i18next.t('core.hardware_editor.parts_' + (component.same_as ? 'same_as' : 'mirror_of'), { slot: String(component.same_as || component.mirror_of).toUpperCase() })));
                continue;
            }

            // Its name - the descriptor's one if it has none
            $slot.append(this.renderPartName([ 'components', slot ], component, 'part_name', data.name || ''));

            // A component with variants : the one on the bench - the others by the trial
            let path = [ 'components', slot ];
            let target = component;
            if (component.variants && typeof component.variants === 'object') {
                const variant = resolved ? resolved.variant : null;
                if (this.response.type === 'hinge' && component.variants.items) {
                    const $variants = $('<div class="btn-group btn-group-xs">');
                    for (const key of Object.keys(component.variants.items)) {
                        $variants.append($('<button type="button" class="btn btn-default">')
                            .toggleClass('active', key === variant)
                            .text(this.topologyLabel(key))
                            .on('click', function () {
                                this.blur();
                                that.topology = key;
                                that.compute(false);
                            })
                        );
                    }
                    $head.append($variants);
                }
                target = variant && component.variants.items ? component.variants.items[variant] : null;
                if (!target || typeof target !== 'object') {
                    $slot.append($('<div class="ladb-hardware-editor-slot-note">').text(i18next.t('core.hardware_editor.parts_no_variant')));
                    continue;
                }
                path = path.concat([ 'variants', 'items', variant ]);
                $slot.append(this.renderPartName(path, target, 'variant_name', ''));
            }

            for (const part of PARTS) {
                $slot.append(this.renderPart(data, slot, path, target, part, slots));
            }

        }

    };

    LadbModalHardwareEditor.prototype.renderPart = function (data, slot, path, target, part, slots) {
        const that = this;

        const value = target[part];
        let kind = 'none';
        if (value === true || typeof value === 'string') {
            kind = 'skp';
        } else if (value && typeof value === 'object') {
            kind = value.same_as ? 'same_as:' + value.same_as : 'primitives';
        }

        const $row = $('<div class="ladb-hardware-editor-part">');
        const $body = $('<div class="ladb-hardware-editor-part-body">');
        const $select = $('<select class="form-control input-sm">');
        const kinds = [ 'none', 'skp', 'primitives' ].concat(slots.filter(function (s) { return s !== slot; }).map(function (s) { return 'same_as:' + s; }));
        for (const k of kinds) {
            $select.append($('<option>')
                .attr('value', k)
                .text(k.indexOf('same_as:') === 0 ? i18next.t('core.hardware_editor.part_kind_same_as', { slot: k.substring(8).toUpperCase() }) : i18next.t('core.hardware_editor.part_kind_' + k))
            );
        }
        $select
            .val(kind)
            .prop('disabled', this.readonly)
            .on('change', function () {
                that.setPartKind(path, part, $(this).val());
            });
        $row
            .append($('<label class="control-label">').text(i18next.t('core.hardware_descriptor.part_' + part)))
            .append($body.append($select));
        $select.selectpicker(SELECT_PICKER_MODAL_OPTIONS);

        if (kind === 'skp') {

            const skp = (this.response.skps || []).find(function (skp) { return skp.slot === slot && skp.part === part; });
            const ref = skp ? skp.ref : null;
            const imported = ref ? this.imports[ref] : null;
            const mesh = ref ? this.meshes[this.skpSource(ref)] : null;
            const missing = !mesh || mesh.error;
            const placed = ref && this.placements[ref] && !fnIsIdentity(this.placements[ref]);

            const $file = $('<div class="ladb-hardware-editor-file">');
            if (ref) {
                $file.append($('<code>').text(imported ? imported.name : ref.split('/').pop()));
            }
            let chip;
            if (!ref) {
                chip = [ 'danger', 'chip_no_folder' ];
            } else if (imported) {
                chip = [ 'warning', imported.edited ? 'chip_edited' : 'chip_imported' ];
            } else if (mesh === undefined || mesh === 'loading') {
                chip = [ 'default', 'chip_loading' ];
            } else if (missing) {
                chip = [ 'danger', 'chip_missing' ];
            } else if (placed) {
                chip = [ 'warning', 'chip_placed' ];
            } else {
                chip = [ 'default', ref.indexOf('$OCL/') === 0 ? 'chip_bundled' : 'chip_user' ];
            }
            $file.append($('<span class="label label-' + chip[0] + '">').text(i18next.t('core.hardware_editor.' + chip[1])));
            $body.append($file);

            if (ref && !this.readonly) {
                const $buttons = $('<div class="ladb-hardware-editor-part-buttons">');
                $buttons.append($('<button type="button" class="btn btn-default btn-xs">')
                    .text(i18next.t('core.hardware_editor.' + (missing && !imported ? 'choose_file' : 'replace_file')))
                    .on('click', function () {
                        this.blur();
                        that.chooseSkp(ref);
                    })
                );
                const shapeable = mesh !== undefined && mesh !== 'loading' && (!mesh.error || mesh.error === 'not_found' || mesh.error === 'empty');
                if (shapeable) {
                    $buttons.append($('<button type="button" class="btn btn-default btn-xs">')
                        .text(i18next.t('core.hardware_editor.' + (missing ? 'create_in_sketchup' : 'edit_in_sketchup')))
                        .on('click', function () {
                            this.blur();
                            that.startShaping(skp);
                        })
                    );
                }
                $body.append($buttons);
            }
            if (ref && !this.readonly && mesh && !mesh.error && mesh !== 'loading') {
                $body.append(this.renderPlacement(ref));
            }

        } else if (kind === 'primitives') {

            const counts = [];
            for (const key of PRIMITIVE_KEYS) {
                if (Array.isArray(value[key]) && value[key].length > 0) {
                    counts.push(i18next.t('core.hardware_editor.primitive_' + key, { count: value[key].length }));
                }
            }
            $body.append($('<div class="ladb-hardware-editor-part-text">')
                .text((counts.length > 0 ? counts.join(' · ') : i18next.t('core.hardware_editor.primitive_none')) + ' · ')
                .append($('<a href="#">')
                    .text(i18next.t('core.hardware_editor.edit_in_json'))
                    .on('click', function (e) {
                        e.preventDefault();
                        that.showInJson(path.concat([ part ]));
                    })
                )
            );

        } else if (kind.indexOf('same_as:') === 0) {

            $body.append($('<div class="ladb-hardware-editor-part-text">').text(i18next.t('core.hardware_editor.part_same_as', { slot: value.same_as.toUpperCase() })));

        }

        return $row;
    };

    // The name of the component - or variant - at the given path, edited in place.
    LadbModalHardwareEditor.prototype.renderPartName = function (path, target, label, placeholder) {
        const that = this;

        const $input = $('<input type="text" class="form-control input-sm">')
            .val(typeof target.name === 'string' ? target.name : '')
            .attr('placeholder', placeholder)
            .prop('disabled', this.readonly)
            .on('change', function () {
                that.setPartName(path, $(this).val().trim());
            });
        return $('<div class="ladb-hardware-editor-part">')
            .append($('<label class="control-label">').text(i18next.t('core.hardware_editor.' + label)))
            .append($('<div class="ladb-hardware-editor-part-body">').append($input));
    };

    // Sets the name of the component - or variant - at the given path : only
    // its text if it has one, else the component rewritten, its name first.
    LadbModalHardwareEditor.prototype.setPartName = function (path, name) {

        const range = this.findJsonValueRange(this.cm.getValue(), path.concat([ 'name' ]));
        if (range !== null && name) {
            this.cm.replaceRange(JSON.stringify(name), this.cm.posFromIndex(range.start), this.cm.posFromIndex(range.end));
            this.compute(false);
            return;
        }

        let data;
        try {
            data = JSON.parse(this.cm.getValue());
        } catch (e) {
            return;
        }
        let target = data;
        for (const key of path) {
            target = target[key];
        }
        const value = name ? { name: name } : {};
        for (const key of Object.keys(target)) {
            if (key !== 'name') {
                value[key] = target[key];
            }
        }
        this.replaceJsonValue(path, value);

    };

    // The tools to lay the SKP file of the given ref in its frame - baked
    // into the file at save, never written in the JSON.
    LadbModalHardwareEditor.prototype.renderPlacement = function (ref) {
        const that = this;

        const placement = this.placements[ref] || IDENTITY;
        const $placement = $('<div class="ladb-hardware-editor-placement">');

        const fnApply = function (matrix) {
            that.placements[ref] = matrix;
            that.renderBench();
            that.renderParts();
        };
        const fnButton = function (label, onClick) {
            return $('<button type="button" class="btn btn-default btn-xs">')
                .html(label)
                .on('click', function () {
                    this.blur();
                    onClick();
                });
        };

        // Orientation
        const $orientation = $('<div class="ladb-hardware-editor-placement-row">')
            .append($('<span class="ladb-hardware-editor-placement-label">').text(i18next.t('core.hardware_editor.placement_orientation')));
        for (const axis of [ 'x', 'y', 'z' ]) {
            $orientation.append(fnButton(axis.toUpperCase() + ' +90°', function () {
                fnApply(fnMultiply(PLACEMENT_MATRICES[axis], that.placements[ref] || IDENTITY));
            }));
        }
        $orientation.append(fnButton(i18next.t('core.hardware_editor.placement_mirror'), function () {
            fnApply(fnMultiply(PLACEMENT_MATRICES.mirror, that.placements[ref] || IDENTITY));
        }));
        $placement.append($orientation);

        // Translation, in millimeters
        const $translation = $('<div class="ladb-hardware-editor-placement-row">')
            .append($('<span class="ladb-hardware-editor-placement-label">').text(i18next.t('core.hardware_editor.placement_translation')));
        [ 'x', 'y', 'z' ].forEach(function (axis, index) {
            const $input = $('<input type="number" step="0.5" class="form-control input-sm">')
                .val(Math.round(placement[12 + index] * 25.4 * 100) / 100)
                .on('change', function () {
                    const value = parseFloat($(this).val());
                    if (!isNaN(value)) {
                        const matrix = (that.placements[ref] || IDENTITY).slice();
                        matrix[12 + index] = value / 25.4;
                        fnApply(matrix);
                    }
                });
            $translation.append($('<label>').append($('<span>').text(axis.toUpperCase())).append($input));
        });
        $translation.append($('<span class="ladb-hardware-editor-placement-unit">').text('mm'));
        $placement.append($translation);

        // Centering, reset
        const $center = $('<div class="ladb-hardware-editor-placement-row">')
            .append($('<span class="ladb-hardware-editor-placement-label">'));
        [ 'x', 'y' ].forEach(function (axis, index) {
            $center.append(fnButton(i18next.t('core.hardware_editor.placement_center', { axis: axis.toUpperCase() }), function () {
                const matrix = (that.placements[ref] || IDENTITY).slice();
                const box = that.meshBox(that.meshes[that.skpSource(ref)], matrix);
                matrix[12 + index] -= (box.min[index] + box.max[index]) / 2;
                fnApply(matrix);
            }));
        });
        $center.append(fnButton(i18next.t('core.hardware_editor.placement_reset'), function () {
            fnApply(IDENTITY.slice());
        }));
        $placement.append($center);

        $placement.append($('<div class="ladb-hardware-editor-placement-foot">').text(i18next.t('core.hardware_editor.placement_help')));

        return $placement;
    };

    // The box of the given mesh laid by the given matrix : { min, max }.
    LadbModalHardwareEditor.prototype.meshBox = function (mesh, matrix) {
        const min = [ Infinity, Infinity, Infinity ];
        const max = [ -Infinity, -Infinity, -Infinity ];
        for (let i = 0; i < mesh.faces.length; i += 3) {
            const x = mesh.faces[i], y = mesh.faces[i + 1], z = mesh.faces[i + 2];
            for (let axis = 0; axis < 3; axis++) {
                const v = matrix[axis] * x + matrix[4 + axis] * y + matrix[8 + axis] * z + matrix[12 + axis];
                min[axis] = Math.min(min[axis], v);
                max[axis] = Math.max(max[axis], v);
            }
        }
        return { min: min, max: max };
    };

    // Sets the given part of the component at the given path to the given
    // kind - rewriting only that component in the JSON.
    LadbModalHardwareEditor.prototype.setPartKind = function (path, part, kind) {

        let data;
        try {
            data = JSON.parse(this.cm.getValue());
        } catch (e) {
            return;
        }
        let target = data;
        for (const key of path) {
            target = target[key];
        }

        if (kind === 'none') {
            delete target[part];
        } else if (kind === 'skp') {
            target[part] = true;
        } else if (kind === 'primitives') {
            target[part] = part === 'hardware'
                ? { cylinders: [ { diameter: '8mm', from: '-10mm', to: '10mm' } ] }
                : { drillings: [ { diameter: '8mm', depth: '10mm' } ] };
        } else if (kind.indexOf('same_as:') === 0) {
            target[part] = { same_as: kind.substring(8) };
        }

        this.replaceJsonValue(path, target);

    };

    // Replaces the value at the given path of the JSON by the given one -
    // indented as where it stands, the rest of the JSON as written.
    LadbModalHardwareEditor.prototype.replaceJsonValue = function (path, value) {

        const text = this.cm.getValue();
        const range = this.findJsonValueRange(text, path);
        if (range === null) {
            return;
        }
        const lineStart = text.lastIndexOf('\n', range.start - 1) + 1;
        const indent = /^\s*/.exec(text.substring(lineStart, range.start))[0];
        this.cm.replaceRange(
            JSON.stringify(value, null, 2).replace(/\n/g, '\n' + indent),
            this.cm.posFromIndex(range.start),
            this.cm.posFromIndex(range.end)
        );
        this.compute(false);

    };

    // Shows the value at the given path in the JSON tab, selected.
    LadbModalHardwareEditor.prototype.showInJson = function (path) {
        const range = this.findJsonValueRange(this.cm.getValue(), path);
        $('a[href="#ladb_hardware_editor_tab_json"]', this.$element).tab('show');
        if (range !== null) {
            this.cm.setSelection(this.cm.posFromIndex(range.start), this.cm.posFromIndex(range.end));
            this.cm.scrollIntoView({ from: this.cm.posFromIndex(range.start), to: this.cm.posFromIndex(range.end) }, 50);
        }
        this.cm.focus();
    };

    // Save /////

    // Writes the descriptor - its SKP files picked or placed - then closes :
    // the tool picks it.
    LadbModalHardwareEditor.prototype.save = function () {
        const that = this;

        const ref = this.targetRef();
        if (!ref) {
            return;
        }
        if (!FILE_NAME_REGEX.test(this.fileStem())) {
            this.dialog.notifyErrors([ [ 'core.hardware_editor.error.invalid_file_name', { name: this.fileStem() } ] ]);
            return;
        }

        const imports = {};
        for (const skpRef of Object.keys(this.imports)) {
            imports[skpRef] = this.imports[skpRef].path;
        }
        const placements = {};
        for (const skpRef of Object.keys(this.placements)) {
            if (!fnIsIdentity(this.placements[skpRef])) {
                placements[skpRef] = this.placements[skpRef];
            }
        }

        this.$btnValidate.prop('disabled', true);
        rubyCallCommand('hardware_descriptor_save', {
            ref: ref,
            new: !this.ref,
            from: this.ref && this.ref !== ref ? this.ref : null,
            text: this.cm.getValue(),
            imports: imports,
            placements: placements
        }, function (response) {
            that.$btnValidate.prop('disabled', false);
            if (response.errors) {
                that.dialog.notifyErrors(response.errors);
                return;
            }
            that.dialog.hide();
        });

    };

    // Copies the descriptor of the OCL library - read only - into the
    // user's one, then edits the copy.
    LadbModalHardwareEditor.prototype.duplicate = function () {
        const that = this;

        this.$btnDuplicate.prop('disabled', true);
        rubyCallCommand('hardware_descriptor_duplicate', { ref: this.ref }, function (response) {
            that.$btnDuplicate.prop('disabled', false);
            if (response.errors) {
                that.dialog.notifyErrors(response.errors);
                return;
            }
            that.load(response.ref);
            that.dialog.notifySuccess(i18next.t('core.hardware_editor.duplicated', { ref: response.ref }));
        });

    };

    // Deletes the descriptor - its file and the folder of its parts - once confirmed.
    LadbModalHardwareEditor.prototype.delete = function () {
        const that = this;

        const ref = this.ref;
        this.dialog.confirm(i18next.t('default.caution'), i18next.t('core.hardware_editor.delete_confirm', { name: fnFileStem(ref) + '.json' }), function () {
            rubyCallCommand('hardware_descriptor_delete', { ref: ref }, function (response) {
                if (response.errors) {
                    that.dialog.notifyErrors(response.errors);
                    return;
                }
                that.dialog.hide();
            });
        }, {
            confirmBtnType: 'danger',
            confirmBtnLabel: i18next.t('default.delete')
        });

    };

    // SKP files /////

    // The ref the descriptor will have once saved - where its parts declared
    // true are looked for - for a new one.
    LadbModalHardwareEditor.prototype.provisionalRef = function () {
        return this.ref ? null : this.targetRef();
    };

    // File /////

    // The folder the descriptor lives in - or will be written in.
    LadbModalHardwareEditor.prototype.fileDirRef = function () {
        return this.ref ? this.ref.substring(0, this.ref.lastIndexOf('/')) : this.options.dir_ref;
    };

    // The name the file is written with : typed, else its own, else - a new
    // one - the name of the descriptor.
    LadbModalHardwareEditor.prototype.fileStem = function () {
        if (this.fileName) {
            return this.fileName;
        }
        if (this.ref) {
            return fnFileStem(this.ref);
        }
        let name = '';
        try {
            name = JSON.parse(this.cm.getValue()).name;
        } catch (e) {
            // No name for now
        }
        return fnSanitizeFileName(typeof name === 'string' ? name : '') || i18next.t('core.hardware_editor.new_name');
    };

    // The ref the descriptor is written at.
    LadbModalHardwareEditor.prototype.targetRef = function () {
        const dirRef = this.fileDirRef();
        return dirRef ? dirRef + '/' + this.fileStem() + '.json' : null;
    };

    // Where the mesh of the given ref comes from : the file picked to replace it, or itself.
    LadbModalHardwareEditor.prototype.skpSource = function (ref) {
        return this.imports[ref] ? this.imports[ref].path : ref;
    };

    // The SKP files on the bench, laid by their placement - those loaded.
    LadbModalHardwareEditor.prototype.benchSkps = function () {
        const skps = [];
        for (const skp of this.response.skps || []) {
            const mesh = this.meshes[this.skpSource(skp.ref)];
            if (!mesh || mesh === 'loading' || mesh.error) {
                continue;
            }
            skps.push({
                part: skp.part,
                transformation: fnMultiply(skp.transformation, this.placements[skp.ref] || IDENTITY),
                faces: mesh.faces,
                edges: mesh.edges
            });
        }
        return skps;
    };

    // Loads the meshes of the SKP files the bench shows and doesn't have yet.
    LadbModalHardwareEditor.prototype.fetchMeshes = function () {
        const that = this;

        const sources = [];
        for (const skp of this.response.skps || []) {
            const source = this.skpSource(skp.ref);
            if (this.meshes[source] === undefined && sources.indexOf(source) < 0) {
                sources.push(source);
                this.meshes[source] = 'loading';
            }
        }
        if (sources.length === 0) {
            return;
        }
        rubyCallCommand('hardware_skp_mesh', { refs: sources }, function (response) {
            $.extend(that.meshes, response.meshes || {});
            that.renderBench();
            that.renderParts();
        });

    };

    // Picks a SKP file to replace the one of the given ref - copied there at save.
    LadbModalHardwareEditor.prototype.chooseSkp = function (ref) {
        const that = this;
        rubyCallCommand('hardware_skp_choose', null, function (response) {
            if (response.errors) {
                that.dialog.notifyErrors(response.errors);
                return;
            }
            if (!response.path) {
                return;
            }
            that.imports[ref] = response;
            that.placements[ref] = IDENTITY.slice();
            that.fetchMeshes();
            that.renderBench();
            that.renderParts();
        });
    };

    // Shaping /////

    // Opens the part of the given SKP of the bench for edit in SketchUp, on
    // a bench laid in the model - its placement baked in. The editor waits, small.
    LadbModalHardwareEditor.prototype.startShaping = function (skp) {
        const that = this;

        const ref = skp.ref;
        const mesh = this.meshes[this.skpSource(ref)];
        const name = ref.split('/').pop();
        rubyCallCommand('hardware_skp_edit', {
            action: 'start',
            source: mesh && !mesh.error ? this.skpSource(ref) : null,
            placement: this.placements[ref] || IDENTITY,
            transformation: skp.transformation,
            panels: this.response.panels,
            name: name.replace(/\.skp$/i, '')
        }, function (response) {
            if (response.errors) {
                that.dialog.notifyErrors(response.errors);
                return;
            }
            that.shaping = { ref: ref, size: null };
            $('.ladb-hardware-editor-shaping-name', that.$element).text(i18next.t('core.hardware_editor.shaping', { name: name }));
            that.$element.addClass('ladb-hardware-editor-shaping');
            rubyCallCommand('hardware_editor_resize', { width: SHAPING_WIDTH, height: SHAPING_HEIGHT }, function (response) {
                if (that.shaping && response.width) {
                    that.shaping.size = response;
                }
            });
        });

    };

    // The part shaped in SketchUp comes back : imported at save, its
    // placement baked in - or not (cancel).
    LadbModalHardwareEditor.prototype.endShaping = function (finish) {
        const that = this;

        const shaping = this.shaping;
        if (!shaping) {
            return;
        }
        rubyCallCommand('hardware_skp_edit', { action: finish ? 'finish' : 'cancel' }, function (response) {
            that.shaping = null;
            that.$element.removeClass('ladb-hardware-editor-shaping');
            rubyCallCommand('hardware_editor_resize', shaping.size || { width: 1100, height: 760 });
            if (response.errors) {
                that.dialog.notifyErrors(response.errors);
                return;
            }
            if (finish && response.path) {
                that.imports[shaping.ref] = { path: response.path, name: shaping.ref.split('/').pop(), edited: true };
                that.placements[shaping.ref] = IDENTITY.slice();
                that.fetchMeshes();
                that.renderBench();
                that.renderParts();
            }
        });

    };

    // The parse error of the JSON - { line, message } - null if it is valid
    // or the browser doesn't tell where.
    LadbModalHardwareEditor.prototype.jsonError = function () {
        const text = this.cm.getValue();
        try {
            JSON.parse(text);
        } catch (e) {
            let line = null;
            let match = /position (\d+)/.exec(e.message);
            if (match) {
                line = this.cm.posFromIndex(parseInt(match[1])).line;
            } else if ((match = /line (\d+)/.exec(e.message))) {
                line = parseInt(match[1]) - 1;
            } else if (/end of (JSON|data) input/.test(e.message)) {
                line = this.cm.lastLine();
            }
            if (line === null) {
                return null;
            }
            return { line: line, message: e.message.replace(/\s*(in JSON )?at position \d+.*$/, '') };
        }
        return null;
    };

    // Labels /////

    LadbModalHardwareEditor.prototype.topologyLabel = function (topology) {
        if (this.response && this.response.type === 'hinge') {
            return i18next.t('core.hardware_descriptor.variant_' + topology);
        }
        return i18next.t('core.hardware_editor.topology_' + topology);
    };

    LadbModalHardwareEditor.prototype.errorLabel = function (error) {
        const params = error.params || {};
        switch (error.key) {
            case 'unresolved_variable':
            case 'not_a_length':
                return i18next.t('core.hardware_editor.error.' + error.key, params);
            default:
                return i18next.t('tool.default.error.' + error.key, params);
        }
    };

    // Edit /////

    // Rewrites the value of the given setting in the JSON - only its text,
    // the rest of the JSON stays as written.
    LadbModalHardwareEditor.prototype.setSettingValue = function (name, value) {

        const text = this.cm.getValue();
        const range = this.findJsonValueRange(text, [ 'variables', name, 'value' ]);
        if (range === null) {
            return;
        }
        this.cm.replaceRange(
            JSON.stringify(value),
            this.cm.posFromIndex(range.start),
            this.cm.posFromIndex(range.end)
        );
        this.compute(false);

    };

    // The range - { start, end } offsets - of the value at the given path of
    // the given JSON text, null if it isn't there or the JSON is invalid.
    LadbModalHardwareEditor.prototype.findJsonValueRange = function (text, path) {

        let i = 0;
        let found = null;

        const fnSkipSpaces = function () {
            while (i < text.length && /\s/.test(text[i])) i++;
        };
        const fnString = function () {
            const start = i;
            i++;
            while (i < text.length && text[i] !== '"') {
                if (text[i] === '\\') i++;
                i++;
            }
            if (i >= text.length) throw 'unterminated';
            i++;
            return JSON.parse(text.substring(start, i));
        };
        const fnValue = function (depth, onPath) {
            fnSkipSpaces();
            const start = i;
            const c = text[i];
            if (c === '{' || c === '[') {
                const object = c === '{';
                let index = 0;
                i++;
                fnSkipSpaces();
                if (text[i] === (object ? '}' : ']')) {
                    i++;
                } else {
                    for (;;) {
                        let key = index++;
                        if (object) {
                            fnSkipSpaces();
                            if (text[i] !== '"') throw 'key';
                            key = fnString();
                            fnSkipSpaces();
                            if (text[i] !== ':') throw 'colon';
                            i++;
                        }
                        fnValue(depth + 1, onPath && depth < path.length && path[depth] === key);
                        fnSkipSpaces();
                        if (text[i] === ',') {
                            i++;
                        } else if (text[i] === (object ? '}' : ']')) {
                            i++;
                            break;
                        } else {
                            throw 'separator';
                        }
                    }
                }
            } else if (c === '"') {
                fnString();
            } else {
                while (i < text.length && !/[\s,}\]]/.test(text[i])) i++;
                if (i === start) throw 'value';
            }
            if (onPath && depth === path.length) {
                found = { start: start, end: i };
            }
        };

        try {
            fnValue(0, true);
        } catch (e) {
            return null;
        }
        return found;
    };

    // Load /////

    // Edits the given text - of this.ref, or of a new descriptor.
    LadbModalHardwareEditor.prototype.start = function (text) {
        this.response = null;
        this._settingsSignature = null;
        this.fileName = null;
        this.imports = {};
        this.placements = {};
        this.cm.setValue(text);
        this.cm.clearHistory();
        this.cm.setOption('readOnly', this.readonly);
        this.$btnValidate.toggle(!this.readonly);
        this.$btnValidate.prop('disabled', !this.ref && !this.options.dir_ref);
        this.$btnDuplicate.toggle(this.readonly);
        $('.ladb-hardware-editor-readonly', this.$element).toggle(this.readonly);
        $('.ladb-hardware-editor-json', this.$element).toggleClass('ladb-hardware-editor-json-readonly', this.readonly);
        this.$btnDelete.toggle(!!this.ref && !this.readonly);
        this.compute(false);
    };

    // Edits the descriptor of the given ref : its text as written.
    LadbModalHardwareEditor.prototype.load = function (ref) {
        const that = this;
        rubyCallCommand('hardware_descriptor_load', { ref: ref }, function (response) {
            if (response.errors) {
                that.dialog.notifyErrors(response.errors);
                that.start('');
                return;
            }
            that.ref = response.ref;
            that.readonly = response.readonly === true;
            that.start(response.text);
        });
    };

    // Init /////

    LadbModalHardwareEditor.prototype.bind = function () {
        LadbAbstractModal.prototype.bind.call(this);

        const that = this;

        // Bind tabs
        $('a[data-toggle="tab"]', this.$element).on('shown.bs.tab', function (e) {
            if ($(e.target).attr('href') === '#ladb_hardware_editor_tab_json') {
                that.cm.refresh();
            }
        });

    };

    LadbModalHardwareEditor.prototype.init = function () {
        LadbAbstractModal.prototype.init.call(this);

        const that = this;

        // Fetch UI elements
        this.$topologies = $('.ladb-hardware-editor-topologies', this.$element);
        this.$inputThicknessA = $('#ladb_hardware_editor_input_thickness_a', this.$element);
        this.$inputThicknessB = $('#ladb_hardware_editor_input_thickness_b', this.$element);
        this.$viewer = $('.ladb-hardware-editor-viewer', this.$element);
        this.$unsupported = $('.ladb-hardware-editor-unsupported', this.$element);
        this.$computations = $('.ladb-hardware-editor-computations', this.$element);
        this.$settings = $('.ladb-hardware-editor-settings', this.$element);
        this.$parts = $('.ladb-hardware-editor-parts', this.$element);
        this.$errors = $('.ladb-hardware-editor-errors', this.$element);
        this.$errorCount = $('.ladb-hardware-editor-error-count', this.$element);
        this.$btnValidate = $('#ladb_hardware_editor_btn_validate', this.$element);
        this.$btnDuplicate = $('#ladb_hardware_editor_btn_duplicate', this.$element);
        this.$btnDelete = $('#ladb_hardware_editor_btn_delete', this.$element);
        this.$inputFile = $('#ladb_hardware_editor_input_file', this.$element);
        this.$inputName = $('#ladb_hardware_editor_input_name', this.$element);

        // Name of the descriptor : only its text in the JSON
        this.$inputName
            .on('input', function () {
                const range = that.findJsonValueRange(that.cm.getValue(), [ 'name' ]);
                if (range !== null) {
                    that.cm.replaceRange(JSON.stringify($(this).val()), that.cm.posFromIndex(range.start), that.cm.posFromIndex(range.end));
                }
            })
            .on('change', function () {
                that.renderName();
            });

        // Shaping : the part edited in SketchUp comes back, or not
        $('#ladb_hardware_editor_btn_shaping_finish', this.$element).on('click', function () {
            this.blur();
            that.endShaping(true);
        });
        $('#ladb_hardware_editor_btn_shaping_cancel', this.$element).on('click', function () {
            this.blur();
            that.endShaping(false);
        });

        // File name : renames at save - a new one follows its name until typed
        this.$inputFile
            .on('input', function () {
                that.fileName = fnSanitizeFileName($(this).val()) || null;
                that.renderFile();
                if (!that.ref) {
                    that.compute(true);   // Its parts are looked for in the folder named after it
                }
            })
            .on('change', function () {
                $(this).val(that.fileStem());
            });

        // Save : not for the OCL library, nor without a folder to write in
        this.$btnValidate.on('click', function () {
            this.blur();
            that.save();
        });
        this.$btnDuplicate.on('click', function () {
            this.blur();
            that.duplicate();
        });
        this.$btnDelete.on('click', function () {
            this.blur();
            that.delete();
        });

        // Trial thicknesses : not saved
        this.$inputThicknessA
            .val('19mm')
            .ladbTextinputDimension({ resetValue: '19mm' })
            .on('change', function () {
                that.compute(false);
            });
        this.$inputThicknessB
            .val('19mm')
            .ladbTextinputDimension({ resetValue: '19mm' })
            .on('change', function () {
                that.compute(false);
            });

        // JSON
        this.cm = CodeMirror.fromTextArea($('#ladb_hardware_editor_input_json', this.$element).get(0), {
            mode: 'ocl-hardware-json',
            indentUnit: 2,
            tabSize: 2,
            lineNumbers: true,
            lineWrapping: false,
            autoCloseBrackets: true,
            matchBrackets: true
        });
        this.cm.on('change', function (cm, change) {
            if (change.origin !== 'setValue') {
                that.compute(true);
            }
        });

        if (this.options.ref) {
            this.load(this.options.ref);
        } else {
            // A new one of the given type
            this.start(JSON.stringify(fnNewDescriptor(this.options.type || 'connector'), null, 2));
        }

    };

    // PLUGIN DEFINITION
    // =======================

    function Plugin(option, params) {
        return this.each(function () {
            const $this = $(this);
            let data = $this.data('ladb.modal.plugin');
            const options = $.extend({}, LadbModalHardwareEditor.DEFAULTS, $this.data(), typeof option === 'object' && option);

            if (!data) {
                if (undefined === options.dialog) {
                    throw 'dialog option is mandatory.';
                }
                $this.data('ladb.modal.plugin', (data = new LadbModalHardwareEditor(this, options, options.dialog)));
            }
            if (typeof option === 'string') {
                data[option].apply(data, Array.isArray(params) ? params : [ params ])
            } else {
                data.init();
            }
        })
    }

    const old = $.fn.ladbModalHardwareEditor;

    $.fn.ladbModalHardwareEditor = Plugin;
    $.fn.ladbModalHardwareEditor.Constructor = LadbModalHardwareEditor;


    // NO CONFLICT
    // =================

    $.fn.ladbModalHardwareEditor.noConflict = function () {
        $.fn.ladbModalHardwareEditor = old;
        return this;
    }

}(jQuery);

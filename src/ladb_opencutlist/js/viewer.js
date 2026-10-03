// Classes

class ConditionalLineMaterial extends THREE.ShaderMaterial {

    constructor( parameters ) {

        super( {

            uniforms: THREE.UniformsUtils.merge( [
                THREE.UniformsLib.fog,
                {
                    diffuse: {
                        value: new THREE.Color()
                    },
                    opacity: {
                        value: 1.0
                    }
                }
            ] ),

            vertexShader: /* glsl */`
				attribute vec3 control0;
				attribute vec3 control1;
				attribute vec3 direction;
				varying float discardFlag;

				#include <common>
				#include <color_pars_vertex>
				#include <fog_pars_vertex>
				#include <logdepthbuf_pars_vertex>
				#include <clipping_planes_pars_vertex>
				void main() {
					#include <color_vertex>

					vec4 mvPosition = modelViewMatrix * vec4( position, 1.0 );
					gl_Position = projectionMatrix * mvPosition;

					// Transform the line segment ends and control points into camera clip space
					vec4 c0 = projectionMatrix * modelViewMatrix * vec4( control0, 1.0 );
					vec4 c1 = projectionMatrix * modelViewMatrix * vec4( control1, 1.0 );
					vec4 p0 = projectionMatrix * modelViewMatrix * vec4( position, 1.0 );
					vec4 p1 = projectionMatrix * modelViewMatrix * vec4( position + direction, 1.0 );

					c0.xy /= c0.w;
					c1.xy /= c1.w;
					p0.xy /= p0.w;
					p1.xy /= p1.w;

					// Get the direction of the segment and an orthogonal vector
					vec2 dir = p1.xy - p0.xy;
					vec2 norm = vec2( -dir.y, dir.x );

					// Get control point directions from the line
					vec2 c0dir = c0.xy - p1.xy;
					vec2 c1dir = c1.xy - p1.xy;

					// If the vectors to the controls points are pointed in different directions away
					// from the line segment then the line should not be drawn.
					float d0 = dot( normalize( norm ), normalize( c0dir ) );
					float d1 = dot( normalize( norm ), normalize( c1dir ) );
					discardFlag = float( sign( d0 ) != sign( d1 ) );

					#include <logdepthbuf_vertex>
					#include <clipping_planes_vertex>
					#include <fog_vertex>
				}
			`,

            fragmentShader: /* glsl */`
			uniform vec3 diffuse;
			uniform float opacity;
			varying float discardFlag;

			#include <common>
			#include <color_pars_fragment>
			#include <fog_pars_fragment>
			#include <logdepthbuf_pars_fragment>
			#include <clipping_planes_pars_fragment>
			void main() {

				if ( discardFlag > 0.5 ) discard;

				#include <clipping_planes_fragment>
				vec3 outgoingLight = vec3( 0.0 );
				vec4 diffuseColor = vec4( diffuse, opacity );
				#include <logdepthbuf_fragment>
				#include <color_fragment>
				outgoingLight = diffuseColor.rgb; // simple shader
				gl_FragColor = vec4( outgoingLight, diffuseColor.a );
				#include <tonemapping_fragment>
				#include <encodings_fragment>
				#include <fog_fragment>
				#include <premultiplied_alpha_fragment>
			}
			`,

        } );

        Object.defineProperties( this, {

            opacity: {
                get: function () {

                    return this.uniforms.opacity.value;

                },

                set: function ( value ) {

                    this.uniforms.opacity.value = value;

                }
            },

            color: {
                get: function () {

                    return this.uniforms.diffuse.value;

                }
            }

        } );

        this.setValues( parameters );
        this.isConditionalLineMaterial = true;

    }

}

class Box3HelperDashed extends THREE.LineSegments {

    constructor(box, color = 0xffff00) {

        let baseLines = [
            new THREE.Vector3(1, 1, 1),
            new THREE.Vector3(1, 1, -1),
            new THREE.Vector3(1, 1, -1),
            new THREE.Vector3(1, -1, -1),
            new THREE.Vector3(1, -1, -1),
            new THREE.Vector3(1, -1, 1)
        ]
        let axis = new THREE.Vector3(0, 1, 0);
        let pts = [];
        for (let i = 0; i < 4; i++) {
            baseLines.forEach(bl => {
                pts.push(bl.clone().applyAxisAngle(axis, Math.PI * 0.5 * i));
            })
        }

        const geometry = new THREE.BufferGeometry().setFromPoints(pts);

        super(geometry, new THREE.LineDashedMaterial({ color: color, toneMapped: false, dashSize: 0.1, gapSize: 0.1 }));

        this.box = box;

        this.type = 'Box3HelperDashed';

        this.geometry.computeBoundingSphere();
        this.computeLineDistances();

    }

    updateMatrixWorld(force) {

        const box = this.box;

        if (box.isEmpty()) return;

        box.getCenter(this.position);

        box.getSize(this.scale);

        this.scale.multiplyScalar(0.5);

        super.updateMatrixWorld(force);

    }
}


// Declarations

const DPI = 96;

let renderer,
    cssRenderer,
    container,
    scene,
    controls,

    meshMaterial,
    lineMaterial,
    benchOutlineMaterial,
    pinLineMaterial,

    viewportWidth,
    viewportHeight,

    model,
    baseModelSize,
    baseModelCenter,
    baseModelRadius,
    explodedModelSize,
    explodedModelCenter,
    explodedModelRadius,

    explodeFactor,

    boxHelper,
    boxDimensionsHelper,
    boxDimensionsHelperXDiv,
    boxDimensionsHelperYDiv,
    boxDimensionsHelperZDiv,
    axesHelper,

    pinsGroup,
    pinsOptions,

    bench,
    benchSlotGroups,
    benchHiddenSlots = {},
    benchPanels,
    benchHighlightedSlot,
    benchSolidMeshes,
    benchHoveredMesh,
    benchHoveredDimensions,
    benchSelectedSolid,
    benchSelectedDimensions,
    benchPointerDown,
    benchMeasureDimension,
    benchHingeDef,
    benchHingeDimensions,
    benchRaycaster
;

let animating, animateRequestId;

// Functions

const fnInit = function() {

    // Define the default Up vector

    THREE.Object3D.DefaultUp.set(0, 0, 1);

    // Create the renderers

    renderer = new THREE.WebGLRenderer({ antialias: true });
    renderer.setPixelRatio(window.devicePixelRatio);
    document.body.appendChild(renderer.domElement);

    cssRenderer = new THREE.CSS2DRenderer();
    cssRenderer.domElement.style.position = 'absolute';
    cssRenderer.domElement.style.top = '0px';
    document.body.appendChild(cssRenderer.domElement);

    // Create the scene

    scene = new THREE.Scene();
    scene.background = new THREE.Color(0xffffff);

    // Create the camera

    camera = new THREE.OrthographicCamera(-1, 1, 1, -1, -1, 1);

    // Create controls

    controls = new THREE.OrbitControls(camera, cssRenderer.domElement);
    controls.rotateSpeed = 0.5;
    controls.zoomSpeed = 1.5;
    controls.enableRotate = true;
    controls.mouseButtons = {
        LEFT: THREE.MOUSE.ROTATE,
        MIDDLE: THREE.MOUSE.ROTATE,
        RIGHT: THREE.MOUSE.PAN
    }

    // Create default materials

    meshMaterial = new THREE.MeshBasicMaterial({
        side: THREE.DoubleSide,
        color: 0xffffff,
        polygonOffset: true,
        polygonOffsetFactor: 1,
        polygonOffsetUnits: 1,
    });
    lineMaterial = new THREE.LineBasicMaterial({
        color: 0x000000
    });
    defaultConditionalLineMaterial = new ConditionalLineMaterial({
        fog: false,
        color: 0x000000
    });
    benchOutlineMaterial = new THREE.LineMaterial({
        color: BENCH_OUTLINE_COLOR,
        linewidth: BENCH_OUTLINE_WIDTH,   // In pixels
        transparent: true,   // Drawn after the translucent solids - see BENCH_OUTLINE_RENDER_ORDER - not under them
        side: THREE.DoubleSide,   // Its quads turn their back in a mirrored slot
    });
    pinLineMaterial = new THREE.LineBasicMaterial({
        color: 0x000000,
        depthTest: false,
        depthWrite: false,
    });

    fnAddListeners();
    fnUpdateViewportSize();
}

const fnAddListeners = function () {

    // Bench : a primitive hovered
    cssRenderer.domElement.addEventListener('pointermove', fnOnBenchPointerMove);
    cssRenderer.domElement.addEventListener('pointerleave', function () {
        fnHoverBenchSolid(null);
    });
    controls.addEventListener('start', function () {
        fnHoverBenchSolid(null);   // Orbiting, zooming : the label would be left behind
    });
    // Bench : a primitive clicked - not dragged
    cssRenderer.domElement.addEventListener('pointerdown', function (event) {
        benchPointerDown = { x: event.clientX, y: event.clientY };
    });
    cssRenderer.domElement.addEventListener('pointerup', fnOnBenchPointerUp);

    // Controls listeners
    controls.addEventListener('change', function () {
        fnRender();
    });
    controls.addEventListener('end', function () {
        fnDispatchControlsChangedEvent();
    });

    // Window listeners
    window.onresize = function () {
        fnUpdateViewportSize();
        fnRender();
    };
    window.onmessage = function (e) {

        let call = e.data;
        if (call.command) {

            switch (call.command) {

                case 'setup_model':
                    fnSetupModel(
                        call.params.modelDef,
                        call.params.partsColored,
                        call.params.partsOpacity,
                        call.params.pinsHidden,
                        call.params.pinsColored,
                        call.params.pinsRounded,
                        call.params.pinsLength,
                        call.params.pinsDirection,
                        call.params.cameraView,
                        call.params.cameraZoom,
                        call.params.cameraTarget,
                        call.params.explodeFactor
                    );
                    if (call.params.showBoxHelper) {
                        fnSetBoxHelperVisible(true);
                    }
                    break;

                case 'setup_bench':
                    fnSetupBench(call.params.benchDef);
                    break;

                case 'select_bench_solid':
                    fnSelectBenchSolid(call.params.solid);
                    break;

                case 'highlight_bench_panel':
                    fnHighlightBenchPanel(call.params.slot);
                    break;

                case 'show_bench_measure':
                    fnShowBenchMeasure(call.params.measure);
                    break;

                case 'show_bench_hinge_cotes':
                    fnShowBenchHingeCotes(call.params.visible);
                    break;

                case 'set_bench_slot_visible':
                    fnSetBenchSlotVisible(call.params.slot, call.params.visible);
                    break;

                case 'set_zoom':
                    fnSetZoom(call.params.zoom);
                    break;

                case 'set_view':
                    fnSetView(call.params.view);
                    break;

                case 'set_box_helper_visible':
                    fnSetBoxHelperVisible(call.params.visible);
                    break;

                case 'set_box_dimensions_helper_visible':
                    fnSetBoxDimensionsHelperVisible(call.params.visible);
                    break;

                case 'set_axes_helper_visible':
                    fnSetAxesHelperVisible(call.params.visible);
                    break;

                case 'set_explode_factor':
                    fnSetExplodeFactor(call.params.factor);
                    break;

                case 'get_exploded_parts_matrices':
                    window.frameElement.dispatchEvent(new MessageEvent('callback.get_exploded_parts_matrices', {
                        data: fnGetExplodedEntitiesInfos()
                    }));
                    break;

                default:
                    console.log('Unknow command : ', call.command);
            }

        }

    };

}

const fnDispatchControlsChangedEvent = function (trigger = 'user') {

    let view = fnGetCurrentView();

    window.frameElement.dispatchEvent(new MessageEvent('changed.controls', {
        data: {
            trigger: trigger,
            cameraView: view,
            cameraZoom: camera.zoom,
            cameraTarget: controls.target.toArray([]),
            cameraZoomIsAuto: camera.zoom === fnGetZoomAutoByView(view),
            cameraTargetIsAuto: controls.target.equals(fnGetTargetAutoByView(view).target),
            explodeFactor: explodeFactor,
            explodedModelRadius: explodedModelRadius
        }
    }));

}

const fnDispatchHelpersChangedEvent = function () {

    window.frameElement.dispatchEvent(new MessageEvent('changed.helpers', {
        data: {
            boxHelperVisible: boxHelper ? boxHelper.visible : false,
            boxDimensionsHelperVisible: boxDimensionsHelper ? boxDimensionsHelper.visible : false,
            axesHelperVisible: axesHelper ? axesHelper.visible : false,
            benchSlotsVisible: fnGetBenchSlotsVisible()
        }
    }));

}

const fnUpdateViewportSize = function () {

    viewportWidth = window.innerWidth / DPI;
    viewportHeight = window.innerHeight / DPI;

    camera.left = viewportWidth / -2.0;
    camera.right = viewportWidth / 2.0;
    camera.top = viewportHeight / 2.0;
    camera.bottom = viewportHeight / -2.0;
    camera.updateProjectionMatrix();

    renderer.setSize(window.innerWidth, window.innerHeight);
    benchOutlineMaterial.resolution.set(window.innerWidth, window.innerHeight);
    cssRenderer.setSize(window.innerWidth, window.innerHeight);

}

const fnRender = function () {
    for (const mesh of benchSolidMeshes || []) {
        if (mesh.userData.benchOutline.visible) fnUpdateBenchOutline(mesh);   // Its silhouette follows the view
    }
    renderer.render(scene, camera);
    cssRenderer.render(scene, camera);
}

const fnAnimate = function () {
    animateRequestId = requestAnimationFrame(fnAnimate);
    controls.update();
    fnRender();
}

const fnStartAnimate = function () {
    if (!animating) {
        fnAnimate();
        animating = true;
    }
}

const fnStopAnimate = function () {
    cancelAnimationFrame(animateRequestId);
    animating = false;
}

const fnIsDarkColor = function (color) {
    return (0.2126 * color.r + 0.7152 * color.g + 0.0722 * color.b) <= 0.51
}

const fnComputeExplodeVectors = function (group, worldParentCenter) {

    const worldGroupBox = new THREE.Box3().setFromObject(group);
    const worldGroupCenter = worldGroupBox.getCenter(new THREE.Vector3());

    const localParentCenter = group.parent.worldToLocal(worldParentCenter.clone());
    const localGroupCenter = group.parent.worldToLocal(worldGroupCenter.clone());

    group.userData.explodeVector = localGroupCenter.clone().sub(localParentCenter);

    if (!group.userData.isPart) {
        for (let object of group.children) {
            if (object.isGroup) {
                fnComputeExplodeVectors(object, worldGroupCenter);
            }
        }
    }

}

const fnExplodeModel = function (factor = 0, updatePins = true) {

    // Compute explode vectors if not already done
    if (model.userData.explodeVector === undefined) {
        fnComputeExplodeVectors(model, baseModelCenter)
    }

    // Keep current factor
    explodeFactor = factor;

    // Apply explosion
    fnExplodeGroup(model, factor);

    // Compute the new exploded model box
    const modelBox = new THREE.Box3().setFromObject(model);
    explodedModelSize = modelBox.getSize(new THREE.Vector3());
    explodedModelCenter = modelBox.getCenter(new THREE.Vector3());
    explodedModelRadius = modelBox.getBoundingSphere(new THREE.Sphere()).radius;

    if (updatePins) {
        fnCreateModelPins();
    }

}

const fnExplodeGroup = function (group, factor, factorDivider = 1) {

    // Reset group transformations
    if (group.userData.basePosition) {
        group.position.copy(group.userData.basePosition);
    } else {
        group.position.set(0, 0, 0);
    }
    if (group.userData.baseRotation) {
        group.rotation.copy(group.userData.baseRotation);
    } else {
        group.rotation.set(0, 0, 0);
    }
    if (group.userData.baseScale) {
        group.scale.copy(group.userData.baseScale);
    } else {
        group.scale.set(1, 1, 1);
    }

    // Explode children
    if (!group.userData.isPart) {

        // Increment divider only if group contains more than 1 child
        const childPressureDivider = factorDivider + (group.children.length > 1 ? 1 : 0);

        // Iterate on children
        for (let object of group.children) {
            if (object.isGroup) {
                fnExplodeGroup(object, factor, childPressureDivider);
            }
        }

    }

    if (factor > 0) {

        const groupTranslation = group.userData.explodeVector.clone().multiplyScalar(factor / factorDivider);

        // Translate group
        group.applyMatrix4(new THREE.Matrix4().makeTranslation(groupTranslation.x, groupTranslation.y, groupTranslation.z));

    }

};

const fnGetExplodedEntitiesInfos = function () {

    const partsInfos = [];
    const pinsInfos = [];
    fnPopulateExplodedEntitiesInfos(scene, partsInfos, pinsInfos)

    return {
        parts_infos: partsInfos,
        pins_infos: pinsInfos,
    };
};

const fnPopulateExplodedEntitiesInfos = function (group, partsInfos, pinsInfos) {
    if (group.userData.isPart) {
        partsInfos.push({
            id: group.userData.id,
            matrix: group.matrixWorld.toArray()
        });
    } else {
        for (let object of group.children) {
            if (object.isGroup) {
                fnPopulateExplodedEntitiesInfos(object, partsInfos, pinsInfos);
            } else if (object.userData.isPin) {
                pinsInfos.push({
                    text: object.userData.text,
                    target: object.userData.target.toArray(),
                    position: object.userData.position.toArray(),
                    background_color: object.userData.backgroundColor,
                    border_color: object.userData.borderColor,
                    color: object.userData.color
                });
            }
        }
    }
};

const fnGetZoomAutoByView = function (view) {

    switch (JSON.stringify(view)) {

        case JSON.stringify(THREE_CAMERA_VIEWS.none):
            return 1;

        case JSON.stringify(THREE_CAMERA_VIEWS.isometric):
            let width2d = (explodedModelSize.x + explodedModelSize.y) * Math.cos(Math.PI / 6);
            let height2d = (explodedModelSize.x + explodedModelSize.y) * Math.cos(Math.PI / 3) + explodedModelSize.z;
            return Math.min(viewportWidth / width2d, viewportHeight / height2d);

        case JSON.stringify(THREE_CAMERA_VIEWS.top):
            return Math.min(viewportWidth / explodedModelSize.x, viewportHeight / explodedModelSize.y) * 0.8;

        case JSON.stringify(THREE_CAMERA_VIEWS.bottom):
            return Math.min(viewportWidth / explodedModelSize.x, viewportHeight / explodedModelSize.y) * 0.8;

        case JSON.stringify(THREE_CAMERA_VIEWS.front):
            return Math.min(viewportWidth / explodedModelSize.x, viewportHeight / explodedModelSize.z) * 0.8;

        case JSON.stringify(THREE_CAMERA_VIEWS.back):
            return Math.min(viewportWidth / explodedModelSize.x, viewportHeight / explodedModelSize.z) * 0.8;

        case JSON.stringify(THREE_CAMERA_VIEWS.left):
            return Math.min(viewportWidth / explodedModelSize.y, viewportHeight / explodedModelSize.z) * 0.8;

        case JSON.stringify(THREE_CAMERA_VIEWS.right):
            return Math.min(viewportWidth / explodedModelSize.y, viewportHeight / explodedModelSize.z) * 0.8;

        default:
            return Math.min(viewportWidth / explodedModelRadius, viewportHeight / explodedModelRadius) * 0.5;

    }
}

const fnGetTargetAutoByView = function (view) {
    return {
        target: explodedModelCenter,
        position: new THREE.Vector3().fromArray(view).multiplyScalar(explodedModelRadius).add(explodedModelCenter)
    };
}

const fnGetCurrentView = function () {
    return camera.position.clone()
        .sub(controls.target)
        .normalize()
        .toArray().map(function (v) {
            return Number.parseFloat(v.toFixed(4)); // Round to 4 digits
        });
}

const fnSetZoom = function (zoom, dispatchChangedEvent = true) {

    if (zoom) {
        controls.target0.copy(controls.target);
        controls.position0.copy(camera.position);
        controls.zoom0 = zoom;
    } else {
        const currentView = fnGetCurrentView();
        const targetAuto = fnGetTargetAutoByView(currentView);
        controls.target0.copy(targetAuto.target);
        controls.position0.copy(targetAuto.position);
        controls.zoom0 = fnGetZoomAutoByView(currentView);
    }

    controls.reset();

    if (dispatchChangedEvent) {
        fnDispatchControlsChangedEvent();
    }

}

const fnSetView = function (view = THREE_CAMERA_VIEWS.isometric, dispatchChangedEvent = true) {

    let currentView = fnGetCurrentView();
    let currentZoomAuto = fnGetZoomAutoByView(currentView);
    let currentZoomIsAuto = camera.zoom === currentZoomAuto;

    let targetAuto = fnGetTargetAutoByView(view);

    if (view[0] === THREE_CAMERA_VIEWS.bottom[0] &&
        view[1] === THREE_CAMERA_VIEWS.bottom[1] &&
        view[2] === THREE_CAMERA_VIEWS.bottom[2]) {
        camera.up.set(0, 1, 0)
    } else {
        camera.up.set(0, 0, 1)
    }

    controls.target0 = targetAuto.target;
    controls.position0 = targetAuto.position;
    controls.zoom0 = currentZoomIsAuto ? fnGetZoomAutoByView(view) : camera.zoom;

    controls.reset();

    if (dispatchChangedEvent) {
        fnDispatchControlsChangedEvent();
    }

}

const fnSetExplodeFactor = function (factor, dispatchChangedEvent = true) {
    const oldFactor = explodeFactor;
    fnExplodeModel(factor);
    fnRender();
    if (dispatchChangedEvent && oldFactor !== explodeFactor) {
        fnDispatchControlsChangedEvent();
    }
}

const fnSetBoxHelperVisible = function (visible) {
    if (boxHelper) {
        let oldVisible = boxHelper.visible;
        if (visible == null) {
            boxHelper.visible = !boxHelper.visible;
        } else {
            boxHelper.visible = visible === true
        }
        fnRender();
        if (oldVisible !== boxHelper.visible) {
            fnDispatchHelpersChangedEvent();
        }
    }
}

const fnSetBoxDimensionsHelperVisible = function (visible) {
    if (boxDimensionsHelper) {
        let oldVisible = boxDimensionsHelper.visible;
        if (visible == null) {
            boxDimensionsHelper.visible = !boxDimensionsHelper.visible;
        } else {
            boxDimensionsHelper.visible = visible === true
        }
        if (boxDimensionsHelper.visible) {
            boxDimensionsHelperXDiv.classList.remove('hide');
            boxDimensionsHelperYDiv.classList.remove('hide');
            boxDimensionsHelperZDiv.classList.remove('hide');
        } else {
            boxDimensionsHelperXDiv.classList.add('hide');
            boxDimensionsHelperYDiv.classList.add('hide');
            boxDimensionsHelperZDiv.classList.add('hide');
        }
        fnRender();
        if (oldVisible !== boxDimensionsHelper.visible) {
            fnDispatchHelpersChangedEvent();
        }
    }
}

const fnSetAxesHelperVisible = function (visible) {
    if (axesHelper) {
        let oldVisible = axesHelper.visible;
        if (visible == null) {
            axesHelper.visible = !axesHelper.visible;
        } else {
            axesHelper.visible = visible === true
        }
        fnRender();
        if (oldVisible !== axesHelper.visible) {
            fnDispatchHelpersChangedEvent();
        }
    }
}

const fnCreateModelPins = function () {
    if (pinsGroup) {
        pinsGroup.clear();
    }
    if (model && pinsOptions && !pinsOptions.pinsHidden) {
        if (!pinsGroup) {
            pinsGroup = new THREE.Group();
            scene.add(pinsGroup);
        }
        fnCreateGroupPins(model, pinsOptions.pinsColored, pinsOptions.pinsRounded, pinsOptions.pinsLength, pinsOptions.pinsDirection, baseModelCenter);
    }
}

const fnCreateGroupPins = function (group, pinsColored, pinsRounded, pinsLength, pinsDirection, parentCenter) {

    const groupBox = new THREE.Box3().setFromObject(group);
    const groupCenter = groupBox.getCenter(new THREE.Vector3());

    if (group.userData.isPart) {

        if (group.userData.text) {

            let pinLengthFactor;
            switch (pinsLength) {
                case 0:   // PINS_LENGTH_NONE
                    pinLengthFactor = 0
                    break;
                case 2:   // PINS_LENGTH_MEDIUM
                    pinLengthFactor = 0.2
                    break;
                case 3:   // PINS_LENGTH_LONG
                    pinLengthFactor = 0.4
                    break;
                case 1:   // PINS_LENGTH_SHORT
                default:
                    pinLengthFactor = 0.1
                    break;
            }

            const pinPosition = groupCenter.clone();
            if (pinLengthFactor > 0) {
                switch (pinsDirection) {
                    case 0: // PINS_DIRECTION_X
                        pinPosition.add(new THREE.Vector3(baseModelRadius * pinLengthFactor, 0, 0));
                        break;
                    case 1: // PINS_DIRECTION_Y
                        pinPosition.add(new THREE.Vector3(0, baseModelRadius * pinLengthFactor, 0));
                        break;
                    case 2: // PINS_DIRECTION_Z
                        pinPosition.add(new THREE.Vector3(0, 0, baseModelRadius * pinLengthFactor));
                        break;
                    case 3: // PINS_DIRECTION_PARENT_CENTER
                        pinPosition.sub(parentCenter).setLength(baseModelRadius * pinLengthFactor).add(groupCenter);
                        break;
                    default:
                    case 4: // PINS_DIRECTION_MODEL_CENTER
                        pinPosition.sub(baseModelCenter).setLength(baseModelRadius * pinLengthFactor).add(groupCenter);
                        break;
                }
            }

            const pinTextIsError = group.userData.text && group.userData.text.error !== undefined;
            const pinText = pinTextIsError ? group.userData.text.error : group.userData.text;
            const pinClass = !pinTextIsError && pinsRounded ? 'rounded' : 'squared';

            let pinBackgroundColor, pinBorderColor, pinColor;
            if (pinTextIsError) {
                pinBackgroundColor = '#ffdddd';
                pinBorderColor = '#d9534f';
                pinColor = '#d9534f';
            } else if (pinsColored && group.userData.color) {
                pinBackgroundColor = '#' + group.userData.color.getHexString();
                pinBorderColor = '#' + group.userData.color.clone().addScalar(-0.5).getHexString();
                pinColor = fnIsDarkColor(group.userData.color) ? '#ffffff' : '#000000';
            }

            const pinDiv = document.createElement('div');
            pinDiv.className = 'pin pin-' + pinClass;
            pinDiv.textContent = pinText;   // Line breaks kept by the .pin "white-space: pre-line" - see viewer.html
            if (pinBackgroundColor) {
                pinDiv.style.backgroundColor = pinBackgroundColor;
                pinDiv.style.borderColor = pinBorderColor;
                pinDiv.style.color = pinColor;
            }

            const pin = new THREE.CSS2DObject(pinDiv);
            pin.userData.isPin = true;
            pin.userData.text = pinText;
            pin.userData.target = groupCenter;
            pin.userData.position = pinPosition;
            if (pinBackgroundColor) {
                pin.userData.backgroundColor = pinBackgroundColor;
                pin.userData.borderColor = pinBorderColor;
                pin.userData.color = pinColor;
            }
            pin.position.copy(pinPosition);
            pinsGroup.add(pin);

            if (pinLengthFactor > 0) {
                const line = new THREE.Line(new THREE.BufferGeometry().setFromPoints([groupCenter, pinPosition]), pinLineMaterial);
                line.renderOrder = 1;
                pinsGroup.add(line);
            }

        }

    } else {

        for (let object of group.children) {
            if (object.isGroup) {
                fnCreateGroupPins(object, pinsColored, pinsRounded, pinsLength, pinsDirection, groupCenter);
            }
        }

    }

};

const fnAddObjectDef = function (modelDef, objectDef, parent, partsColored) {

    let group = new THREE.Group();
    if (objectDef.matrix) {
        let matrix = new THREE.Matrix4();
        matrix.elements = objectDef.matrix;
        group.applyMatrix4(matrix);
        group.userData.basePosition = group.position.clone();
        group.userData.baseRotation = group.rotation.clone();
        group.userData.baseScale = group.scale.clone();
    }
    for (childObjectDef of objectDef.children) {
        fnAddObjectDef(modelDef, childObjectDef, group, partsColored);
    }
    if (objectDef.type === 3 /* TYPE_PART_INSTANCE */) {

        let partDef = modelDef.part_defs[objectDef.id];
        if (partDef) {

            group.userData.isPart = true;
            group.userData.id = objectDef.id;
            group.userData.text = objectDef.text;
            group.userData.color = new THREE.Color(partDef.color);

            // Mesh

            let facesGeometry = new THREE.BufferGeometry();
            facesGeometry.setAttribute('position', new THREE.Float32BufferAttribute(partDef.face_vertices, 3));
            if (partsColored) {
                facesGeometry.setAttribute('color', new THREE.Float32BufferAttribute(partDef.face_colors, 3));
            }

            let mesh = new THREE.Mesh(facesGeometry, meshMaterial);
            group.add(mesh);

            // Line

            let hardEdgesGeometry = new THREE.BufferGeometry();
            hardEdgesGeometry.setAttribute('position', new THREE.Float32BufferAttribute(partDef.hard_edge_vertices, 3));

            let hardEdgesLine = new THREE.LineSegments(hardEdgesGeometry, lineMaterial);
            group.add(hardEdgesLine);

            let softEdgesGeometry = new THREE.BufferGeometry();
            softEdgesGeometry.setAttribute('position', new THREE.Float32BufferAttribute(partDef.soft_edge_vertices, 3));
            softEdgesGeometry.setAttribute('control0', new THREE.Float32BufferAttribute(partDef.soft_edge_controls0, 3));
            softEdgesGeometry.setAttribute('control1', new THREE.Float32BufferAttribute(partDef.soft_edge_controls1, 3));
            softEdgesGeometry.setAttribute('direction', new THREE.Float32BufferAttribute(partDef.soft_edge_directions, 3));

            let softEdgesLine = new THREE.LineSegments(softEdgesGeometry, defaultConditionalLineMaterial);
            group.add(softEdgesLine);

        }

    }
    parent.add(group);

    return group;
};

const fnSetupModel = function(modelDef, partsColored, partsOpacity, pinsHidden, pinsColored, pinsRounded, pinsLength, pinsDirection, cameraView, cameraZoom, cameraTarget, explodeFactor) {

    if (partsColored) {
        meshMaterial.vertexColors = true;
    }
    if (partsOpacity < 1) {
        meshMaterial.opacity = partsOpacity;
        meshMaterial.transparent = true;
        pinLineMaterial.transparent = true; // To force pin line to be on the same sort as parts
    }

    model = fnAddObjectDef(modelDef, modelDef, scene, partsColored);
    if (model) {

        // Compute model box properties

        const modelBox = new THREE.Box3().setFromObject(model);
        baseModelSize = explodedModelSize = modelBox.getSize(new THREE.Vector3());
        baseModelCenter = explodedModelCenter = modelBox.getCenter(new THREE.Vector3());
        baseModelRadius = explodedModelRadius = modelBox.getBoundingSphere(new THREE.Sphere()).radius;

        // Option

        pinsOptions = {
            pinsHidden: pinsHidden,
            pinsColored: pinsColored,
            pinsRounded: pinsRounded,
            pinsLength: pinsLength,
            pinsDirection: pinsDirection
        };

        // Create box helper
        boxHelper = new THREE.Box3Helper(modelBox, 0x0000ff);
        boxHelper.visible = false;
        scene.add(boxHelper);

        // Create box dimension helper
        if (modelDef.x_dim != null && modelDef.y_dim != null && modelDef.z_dim != null) {

            boxDimensionsHelper = new THREE.Group();
            boxDimensionsHelper.visible = false;

            let dimOffsetA = baseModelRadius / 6;
            let dimOffsetB = dimOffsetA * 1.3;
            let dimArrowColor = 0x0000ff;

            boxDimensionsHelperXDiv = document.createElement('div');
            boxDimensionsHelperXDiv.className = 'dim hide';
            boxDimensionsHelperXDiv.textContent = modelDef.x_dim;

            const xDim = new THREE.CSS2DObject(boxDimensionsHelperXDiv);
            xDim.position.copy(new THREE.Vector3(modelBox.min.x + baseModelSize.x / 2, modelBox.min.y - dimOffsetA, modelBox.min.z));
            boxDimensionsHelper.add(xDim);

            boxDimensionsHelperYDiv = document.createElement('div');
            boxDimensionsHelperYDiv.className = 'dim hide';
            boxDimensionsHelperYDiv.textContent = modelDef.y_dim;

            const yDim = new THREE.CSS2DObject(boxDimensionsHelperYDiv);
            yDim.position.copy(new THREE.Vector3(modelBox.min.x + baseModelSize.x + dimOffsetA, modelBox.min.y + baseModelSize.y / 2, modelBox.min.z));
            boxDimensionsHelper.add(yDim);

            boxDimensionsHelperZDiv = document.createElement('div');
            boxDimensionsHelperZDiv.className = 'dim hide';
            boxDimensionsHelperZDiv.textContent = modelDef.z_dim;

            const zDim = new THREE.CSS2DObject(boxDimensionsHelperZDiv);
            zDim.position.copy(new THREE.Vector3(modelBox.min.x + baseModelSize.x + dimOffsetA * 0.707, modelBox.min.y + baseModelSize.y + dimOffsetA * 0.707, modelBox.min.z + baseModelSize.z / 2));
            boxDimensionsHelper.add(zDim);

            boxDimensionsHelper.add(new THREE.ArrowHelper(
                new THREE.Vector3(0, 1, 0),
                new THREE.Vector3(modelBox.min.x, modelBox.min.y - dimOffsetB, modelBox.min.z),
                dimOffsetA,
                dimArrowColor,
                0
            ));
            boxDimensionsHelper.add(new THREE.ArrowHelper(
                new THREE.Vector3(0, 1, 0),
                new THREE.Vector3(modelBox.min.x + baseModelSize.x, modelBox.min.y - dimOffsetB, modelBox.min.z),
                dimOffsetA,
                dimArrowColor,
                0
            ));

            boxDimensionsHelper.add(new THREE.ArrowHelper(
                new THREE.Vector3(-1, 0, 0),
                new THREE.Vector3(modelBox.min.x + baseModelSize.x + dimOffsetB, modelBox.min.y, modelBox.min.z),
                dimOffsetA,
                dimArrowColor,
                0
            ));
            boxDimensionsHelper.add(new THREE.ArrowHelper(
                new THREE.Vector3(-1, 0, 0),
                new THREE.Vector3(modelBox.min.x + baseModelSize.x + dimOffsetB, modelBox.min.y + baseModelSize.y, modelBox.min.z),
                dimOffsetA,
                dimArrowColor,
                0
            ));

            boxDimensionsHelper.add(new THREE.ArrowHelper(
                new THREE.Vector3(-1, -1, 0).normalize(),
                new THREE.Vector3(modelBox.min.x + baseModelSize.x + dimOffsetB * 0.707, modelBox.min.y + baseModelSize.y + dimOffsetB * 0.707, modelBox.min.z),
                dimOffsetA,
                dimArrowColor,
                0
            ));
            boxDimensionsHelper.add(new THREE.ArrowHelper(
                new THREE.Vector3(-1, -1, 0).normalize(),
                new THREE.Vector3(modelBox.min.x + baseModelSize.x + dimOffsetB * 0.707, modelBox.min.y + baseModelSize.y + dimOffsetB * 0.707, modelBox.min.z + baseModelSize.z),
                dimOffsetA,
                dimArrowColor,
                0
            ));


            boxDimensionsHelper.add(new THREE.ArrowHelper(
                new THREE.Vector3(1, 0, 0),
                new THREE.Vector3(modelBox.min.x, modelBox.min.y - dimOffsetA, modelBox.min.z),
                baseModelSize.x,
                dimArrowColor,
                0
            ));
            boxDimensionsHelper.add(new THREE.ArrowHelper(
                new THREE.Vector3(0, 1, 0),
                new THREE.Vector3(modelBox.min.x + baseModelSize.x + dimOffsetA, modelBox.min.y, modelBox.min.z),
                baseModelSize.y,
                dimArrowColor,
                0
            ));
            boxDimensionsHelper.add(new THREE.ArrowHelper(
                new THREE.Vector3(0, 0, 1),
                new THREE.Vector3(modelBox.min.x + baseModelSize.x + dimOffsetA * 0.707, modelBox.min.y +  + baseModelSize.y + dimOffsetA * 0.707, modelBox.min.z),
                baseModelSize.z,
                dimArrowColor,
                0
            ));
            scene.add(boxDimensionsHelper);

        }

        // Create axes helper
        axesHelper = new THREE.Group();
        axesHelper.visible = false;
        if (modelDef.axes_matrix) {
            axesHelper.applyMatrix4(new THREE.Matrix4().fromArray(modelDef.axes_matrix));
        }
        axesHelper.add(new THREE.ArrowHelper(
            new THREE.Vector3(1, 0, 0),
            new THREE.Vector3(0, 0, 0),
            baseModelRadius * 5,
            0xff0000,
            0
        ));
        axesHelper.add(new THREE.ArrowHelper(
            new THREE.Vector3(0, 1, 0),
            new THREE.Vector3(0, 0, 0),
            baseModelRadius * 5,
            0x00dd00,
            0
        ));
        axesHelper.add(new THREE.ArrowHelper(
            new THREE.Vector3(0, 0, 1),
            new THREE.Vector3(0, 0, 0),
            baseModelRadius * 5,
            0x0000ff,
            0
        ));
        scene.add(axesHelper);

        // Adjust camera near and far
        camera.near = -baseModelRadius * 2;
        camera.far = baseModelRadius * 4;

        // This will explode the model AND create pins if necessary
        fnSetExplodeFactor(explodeFactor, false);

        if (cameraView) {

            if (cameraTarget) {
                controls.target0.fromArray(cameraTarget);
            } else {
                controls.target0.copy(explodedModelCenter); // Auto target
            }

            controls.position0.fromArray(cameraView).multiplyScalar(explodedModelRadius).add(controls.target0);

            if (cameraZoom) {
                controls.zoom0 = cameraZoom;
            } else {
                controls.zoom0 = fnGetZoomAutoByView(cameraView);   // Auto zoom
            }

            controls.reset();

        } else {

            // Default, start with isometric view + auto target + auto zoom
            fnSetView(THREE_CAMERA_VIEWS.isometric, false);

        }

        fnDispatchControlsChangedEvent('init');

    }

}

// Bench (hardware editor) : fictional panels and the solids of the hardware
// laid on them, rebuilt on each edit - the camera stays where it is.

const BENCH_PANEL_COLORS = { a: 0xf0c987, b: 0xa9d19e };
const BENCH_PANEL_PIN_COLORS = { a: '#c98a1c', b: '#4e9442' };
const BENCH_PANEL_OPACITY = 0.45;
const BENCH_REFERENCE_DARKEN = 0.4;   // Its panel's color darkened, as SmartJoin shows it - see COLOR_REF_DARKEN_A
const BENCH_REFERENCE_ARROW_LENGTH = 50 / 25.4;
const BENCH_PANEL_HIGHLIGHTED_OPACITY = 0.85;
const BENCH_PART_COLORS = { hardware: 0x8c8c8c, machining: 0x2e7fd9 };
const BENCH_OUTLINE_COLOR = 0xffffff;
const BENCH_OUTLINE_WIDTH = 1;
const BENCH_OUTLINE_RENDER_ORDER = 1;
const BENCH_OUTLINE_HARD_COS = Math.cos(30 * Math.PI / 180);   // As the edges drawn - see fnAddBenchObject
const BENCH_AXIS_COLORS = { x: 0xff000f, y: 0x00bb00, z: 0x0032ff };   // As SketchUp draws them - see Kuix::COLOR_X, COLOR_Y, COLOR_Z
const BENCH_DIMENSION_HEAD_LENGTH = 3 / 25.4;
const BENCH_DIMENSION_RENDER_ORDER = 999;
const BENCH_MEASURE_DARKEN = 0.4;   // Its panel's pin color darkened, to be seen over the panels
const BENCH_HINGE_COLOR = 0xd9368f;
const BENCH_HINGE_DOOR_OPACITY = 0.12;
const BENCH_HINGE_AXIS_RADIUS = 0.75 / 25.4;
const BENCH_HINGE_AXIS_OVERRUN = 15 / 25.4;   // Past the door, at each end
const BENCH_HINGE_AXIS_DASH = 6 / 25.4;
const BENCH_HINGE_ARC_SEGMENTS = 48;

const fnCreateBenchSolidGeometry = function (solidDef) {

    const height = solidDef.z_max - solidDef.z_min;
    const radius = solidDef.diameter / 2;
    let geometry;

    if (solidDef.outline) {

        // A prism : its outline extruded along Z
        const shape = new THREE.Shape(solidDef.outline.map(function (point) { return new THREE.Vector2(point[0], point[1]); }));
        geometry = new THREE.ExtrudeGeometry(shape, { depth: height, bevelEnabled: false });
        geometry.translate(0, 0, solidDef.z_min);

    } else if (solidDef.profile) {

        // A round solid widened at one end : its outline revolved around Z
        const points = [ new THREE.Vector2(0, solidDef.profile[0][1]) ];
        for (const point of solidDef.profile) {
            points.push(new THREE.Vector2(point[0], point[1]));
        }
        points.push(new THREE.Vector2(0, solidDef.profile[solidDef.profile.length - 1][1]));
        geometry = new THREE.LatheGeometry(points, 32);
        geometry.rotateX(Math.PI / 2);   // Its axis from Y to Z

    } else if (solidDef.length) {

        // A slot with round ends, its length along X
        const straight = solidDef.length / 2 - radius;
        const shape = new THREE.Shape();
        shape.moveTo(-straight, -radius);
        shape.lineTo(straight, -radius);
        shape.absarc(straight, 0, radius, -Math.PI / 2, Math.PI / 2, false);
        shape.lineTo(-straight, radius);
        shape.absarc(-straight, 0, radius, Math.PI / 2, Math.PI * 3 / 2, false);
        geometry = new THREE.ExtrudeGeometry(shape, { depth: height, bevelEnabled: false, curveSegments: 16 });
        geometry.translate(0, 0, solidDef.z_min);

    } else {

        geometry = new THREE.CylinderGeometry(radius, radius, height, 32);
        geometry.rotateX(Math.PI / 2);   // Its axis from Y to Z
        geometry.translate(0, 0, solidDef.z_min + height / 2);

    }
    geometry.translate(solidDef.x, solidDef.y, 0);

    return geometry;
};

const fnAddBenchObject = function (parent, geometry, color, opacity) {

    const mesh = new THREE.Mesh(geometry, new THREE.MeshBasicMaterial({
        side: THREE.DoubleSide,
        color: color,
        transparent: opacity < 1,
        opacity: opacity,
        depthWrite: opacity >= 1,
        polygonOffset: true,
        polygonOffsetFactor: 1,
        polygonOffsetUnits: 1,
    }));
    parent.add(mesh);

    const edges = new THREE.LineSegments(new THREE.EdgesGeometry(geometry, 30), lineMaterial);
    parent.add(edges);

    return mesh;
};

// The reference face of a panel - [ axis, 'min' | 'max' ] - : an arrow
// along its normal, from its center - as SmartJoin shows it.
const fnAddBenchReferenceFace = function (parent, reference, min, max, color) {

    const axis = reference[0];
    const direction = new THREE.Vector3();
    direction.setComponent(axis, reference[1] === 'max' ? 1 : -1);
    const origin = min.clone().add(max).multiplyScalar(0.5);
    origin.setComponent(axis, (reference[1] === 'max' ? max : min).getComponent(axis));

    parent.add(new THREE.ArrowHelper(
        direction,
        origin,
        BENCH_REFERENCE_ARROW_LENGTH,
        new THREE.Color(color).multiplyScalar(1 - BENCH_REFERENCE_DARKEN),
        BENCH_REFERENCE_ARROW_LENGTH * 0.25,
        BENCH_REFERENCE_ARROW_LENGTH * 0.12
    ));

};

// The pin of a panel : at the center of its face the farthest from the
// joint - the origin - so it doesn't hide the hardware.
const fnAddBenchPanelPin = function (parent, slot, min, max) {

    const position = min.clone().add(max).multiplyScalar(0.5);
    let farthest = -1;
    for (const axis of [ 'x', 'y', 'z' ]) {
        for (const value of [ min[axis], max[axis] ]) {
            if (Math.abs(value) > farthest) {
                farthest = Math.abs(value);
                position.copy(min.clone().add(max).multiplyScalar(0.5));
                position[axis] = value;
            }
        }
    }

    const pinDiv = document.createElement('div');
    pinDiv.className = 'pin pin-rounded bench-pin';
    pinDiv.textContent = slot.toUpperCase();
    pinDiv.style.backgroundColor = BENCH_PANEL_PIN_COLORS[slot] || '#000000';
    pinDiv.style.borderColor = BENCH_PANEL_PIN_COLORS[slot] || '#000000';

    const pin = new THREE.CSS2DObject(pinDiv);
    pin.position.copy(position);
    parent.add(pin);

    return pin;
};

// Where the given mesh is on the screen : the rectangle - in pixels of the
// page - around its bounding box's corners.
const fnGetBenchScreenRect = function (mesh) {
    if (!mesh.geometry.boundingBox) mesh.geometry.computeBoundingBox();
    const box = mesh.geometry.boundingBox;
    const rect = renderer.domElement.getBoundingClientRect();
    let left = Infinity, top = Infinity, right = -Infinity, bottom = -Infinity;
    for (let i = 0; i < 8; i++) {
        const corner = new THREE.Vector3(
            i & 1 ? box.max.x : box.min.x,
            i & 2 ? box.max.y : box.min.y,
            i & 4 ? box.max.z : box.min.z
        ).applyMatrix4(mesh.matrixWorld).project(camera);
        const x = rect.left + (corner.x + 1) / 2 * rect.width;
        const y = rect.top + (1 - corner.y) / 2 * rect.height;
        left = Math.min(left, x);
        right = Math.max(right, x);
        top = Math.min(top, y);
        bottom = Math.max(bottom, y);
    }
    return { left: left, top: top, width: right - left, height: bottom - top };
};

// A cote : two arrows from its middle to its ends, its text at the middle.
const fnAddBenchDimension = function (group, from, to, text, color) {
    const length = from.distanceTo(to);
    if (length < 1e-6) return;
    const middle = from.clone().add(to).multiplyScalar(0.5);
    const headLength = Math.min(BENCH_DIMENSION_HEAD_LENGTH, length / 3);
    for (const [ start, end ] of [ [ middle, from ], [ middle, to ] ]) {
        const arrow = new THREE.ArrowHelper(end.clone().sub(start).normalize(), start, length / 2, color, headLength, headLength * 0.5);
        arrow.traverse(function (object) {
            if (object.material) {
                // Seen through the geometry : drawn last - with the transparent objects, after them - whatever the depth
                object.material.depthTest = false;
                object.material.depthWrite = false;
                object.material.transparent = true;
            }
            object.renderOrder = BENCH_DIMENSION_RENDER_ORDER;
        });
        group.add(arrow);
    }
    const div = document.createElement('div');
    div.className = 'dim bench-dim';
    div.textContent = text;
    div.style.color = '#' + new THREE.Color(color).getHexString();
    const label = new THREE.CSS2DObject(div);
    label.position.copy(middle);
    group.add(label);
};

// The position of the given solid, as the descriptor gives it : its x, y
// and z in the frame of its part - one cote along each axis, from the
// origin to its axis, on the plane of the joint or its nearest end.
const fnAddBenchSolidDimensions = function (mesh) {

    const solidDef = mesh.userData.benchSolidDef;
    if (!solidDef.cotes) return null;   // One of an article
    const group = new THREE.Group();
    group.applyMatrix4(new THREE.Matrix4().fromArray(solidDef.part_transformation));

    const position = new THREE.Vector3().fromArray(solidDef.cotes.position);
    const from = new THREE.Vector3().fromArray(solidDef.cotes.origin);
    for (const axis of [ 'x', 'y', 'z' ]) {
        const to = from.clone();
        to[axis] = position[axis];
        fnAddBenchDimension(group, from, to, solidDef.texts[axis], BENCH_AXIS_COLORS[axis]);   // Its axis' color
        from.copy(to);
    }

    bench.add(group);

    return group;
};

const fnRemoveBenchObject = function (object) {
    object.traverse(function (child) {
        if (child.geometry) child.geometry.dispose();
        if (child.material && child.material !== lineMaterial && child.material !== benchOutlineMaterial) child.material.dispose();
        // Its own 'removed' only fires when a CSS2DObject is removed itself, not its parent
        if (child.isCSS2DObject && child.element.parentNode) child.element.parentNode.removeChild(child.element);
    });
    if (object.parent) object.parent.remove(object);
};

// The solid under the pointer - a primitive - stands out with its position
// cotes, and the page
// is told - 'hovered.bench' - to show its label beside it : { label, rect }
// - see fnGetBenchScreenRect. null : none.
const fnHoverBenchSolid = function (mesh) {
    if (mesh === benchHoveredMesh) return;
    const previous = benchHoveredMesh;
    if (benchHoveredDimensions) {
        fnRemoveBenchObject(benchHoveredDimensions);
        benchHoveredDimensions = null;
    }
    benchHoveredMesh = mesh;
    if (previous) {
        fnPaintBenchSolid(previous);
    }
    if (mesh) {
        fnPaintBenchSolid(mesh);
        if (!fnIsBenchSolidSelected(mesh)) {
            benchHoveredDimensions = fnAddBenchSolidDimensions(mesh);   // The selected one has its own
        }
    }
    fnRender();
    window.frameElement.dispatchEvent(new MessageEvent('hovered.bench', {
        data: mesh ? { label: mesh.userData.benchLabel, rect: fnGetBenchScreenRect(mesh) } : null
    }));
};

// The look of the given solid : its outline stands out when hovered or
// selected, its faces stay as they are.
const fnPaintBenchSolid = function (mesh) {
    mesh.userData.benchOutline.visible = mesh === benchHoveredMesh || fnIsBenchSolidSelected(mesh);
    if (mesh.userData.benchOutline.visible) fnUpdateBenchOutline(mesh);
};

// The edges of the given geometry - its vertices welded - with the normals
// of their faces : [ { a, b, normals } ].
const fnGetBenchSolidEdges = function (geometry) {
    const position = geometry.attributes.position;
    const index = geometry.index;
    const count = index ? index.count : position.count;
    const vertices = [];
    const vertexIds = {};
    const fnVertexId = function (i) {
        const vertex = new THREE.Vector3().fromBufferAttribute(position, index ? index.getX(i) : i);
        const key = vertex.toArray().map(function (c) { return Math.round(c * 1e5); }).join(',');
        if (vertexIds[key] === undefined) {
            vertexIds[key] = vertices.length;
            vertices.push(vertex);
        }
        return vertexIds[key];
    };
    const edges = {};
    const triangle = new THREE.Triangle();
    for (let i = 0; i + 2 < count; i += 3) {
        const ids = [ fnVertexId(i), fnVertexId(i + 1), fnVertexId(i + 2) ];
        triangle.set(vertices[ids[0]], vertices[ids[1]], vertices[ids[2]]);
        if (triangle.getArea() < 1e-12) continue;   // The poles of a lathe
        const normal = triangle.getNormal(new THREE.Vector3());
        for (let j = 0; j < 3; j++) {
            const a = Math.min(ids[j], ids[(j + 1) % 3]);
            const b = Math.max(ids[j], ids[(j + 1) % 3]);
            const key = a + '_' + b;
            if (!edges[key]) edges[key] = { a: vertices[a], b: vertices[b], normals: [] };
            edges[key].normals.push(normal);
        }
    }
    return Object.values(edges);
};

// The outline of the given solid, as seen now : its hard edges and its
// silhouette - the smooth edges between a face toward the camera and a face
// away from it.
const fnUpdateBenchOutline = function (mesh) {
    if (!mesh.userData.benchEdges) mesh.userData.benchEdges = fnGetBenchSolidEdges(mesh.geometry);
    mesh.updateWorldMatrix(true, false);
    const direction = camera.getWorldDirection(new THREE.Vector3()).transformDirection(mesh.matrixWorld.clone().invert());
    const positions = [];
    for (const edge of mesh.userData.benchEdges) {
        const hard = edge.normals.length !== 2 || edge.normals[0].dot(edge.normals[1]) < BENCH_OUTLINE_HARD_COS;
        if (hard || edge.normals[0].dot(direction) * edge.normals[1].dot(direction) < 0) {
            positions.push(edge.a.x, edge.a.y, edge.a.z, edge.b.x, edge.b.y, edge.b.z);
        }
    }
    const outline = mesh.userData.benchOutline;
    outline.geometry.dispose();
    outline.geometry = new THREE.LineSegmentsGeometry().setPositions(positions);
};

// The primitive of the given solid - { slot, part, key, index } - see
// HardwareBenchComputeWorker#_slot.
const fnGetBenchSolidPrimitive = function (mesh) {
    const solidDef = mesh.userData.benchSolidDef;
    const primitive = { slot: solidDef.slot, part: solidDef.part, key: solidDef.key, index: solidDef.index };
    if (solidDef.article) primitive.article = solidDef.article;
    return primitive;
};

// Selected : the primitive, or any solid of the article - { slot, article }.
const fnIsBenchSolidSelected = function (mesh) {
    if (!benchSelectedSolid) return false;
    const primitive = fnGetBenchSolidPrimitive(mesh);
    if (benchSelectedSolid.article && benchSelectedSolid.key === undefined) {
        return primitive.slot === benchSelectedSolid.slot && primitive.article === benchSelectedSolid.article;
    }
    return primitive.slot === benchSelectedSolid.slot
        && primitive.article === benchSelectedSolid.article
        && primitive.part === benchSelectedSolid.part
        && primitive.key === benchSelectedSolid.key
        && primitive.index === benchSelectedSolid.index;
};

// The primitive the editor works on - { slot, part, key, index } - stands
// out with its position cotes, through the rebuilds. null : none.
const fnSelectBenchSolid = function (solid) {
    benchSelectedSolid = solid || null;
    if (benchSelectedDimensions) {
        fnRemoveBenchObject(benchSelectedDimensions);
        benchSelectedDimensions = null;
    }
    for (const mesh of benchSolidMeshes || []) {
        fnPaintBenchSolid(mesh);
        if (!benchSelectedDimensions && fnIsBenchSolidSelected(mesh) && benchSelectedSolid.key !== undefined) {   // Not of a whole article
            benchSelectedDimensions = fnAddBenchSolidDimensions(mesh);
        }
    }
    if (benchHoveredDimensions && benchHoveredMesh && fnIsBenchSolidSelected(benchHoveredMesh)) {
        fnRemoveBenchObject(benchHoveredDimensions);
        benchHoveredDimensions = null;
    }
    fnRender();
};

// A solid clicked : the page is told - 'clicked.bench' - its primitive.
const fnOnBenchPointerUp = function (event) {
    const down = benchPointerDown;
    benchPointerDown = null;
    if (!down || Math.abs(event.clientX - down.x) + Math.abs(event.clientY - down.y) > 3) {
        return; // Orbited
    }
    fnOnBenchPointerMove(event);   // What is under it now
    if (benchHoveredMesh) {
        window.frameElement.dispatchEvent(new MessageEvent('clicked.bench', {
            data: fnGetBenchSolidPrimitive(benchHoveredMesh)
        }));
    }
};

const fnOnBenchPointerMove = function (event) {
    if (!bench || !benchSolidMeshes || benchSolidMeshes.length === 0 || event.buttons !== 0) {
        fnHoverBenchSolid(null);   // None, or orbiting
        return;
    }
    const rect = renderer.domElement.getBoundingClientRect();
    const pointer = new THREE.Vector2(
        (event.clientX - rect.left) / rect.width * 2 - 1,
        -(event.clientY - rect.top) / rect.height * 2 + 1
    );
    if (!benchRaycaster) benchRaycaster = new THREE.Raycaster();
    benchRaycaster.setFromCamera(pointer, camera);
    const intersects = benchRaycaster.intersectObjects(benchSolidMeshes.filter(function (mesh) { return !benchHiddenSlots[mesh.userData.benchSlot]; }), false);
    fnHoverBenchSolid(intersects.length > 0 ? intersects[0].object : null);
};

// The door turning on its hinge - see HardwareBenchComputeWorker#_hinge - :
// the axis - dashed when it only stands in for a moving one - the door at
// its widest opening, and the arcs its hinged edge sweeps to get there, at
// its end toward -X.
const fnAddBenchHinge = function (parent, hingeDef, doorPanelDef) {

    const origin = new THREE.Vector3().fromArray(hingeDef.origin);
    const axis = new THREE.Vector3().fromArray(hingeDef.axis).normalize();
    const angle = THREE.MathUtils.degToRad(hingeDef.max_angle);
    const fnRotation = function (a) {
        return new THREE.Matrix4().makeTranslation(origin.x, origin.y, origin.z)
            .multiply(new THREE.Matrix4().makeRotationAxis(axis, a))
            .multiply(new THREE.Matrix4().makeTranslation(-origin.x, -origin.y, -origin.z));
    };
    const material = new THREE.MeshBasicMaterial({ color: BENCH_HINGE_COLOR });
    const lineMaterial = new THREE.LineBasicMaterial({ color: BENCH_HINGE_COLOR });

    const min = doorPanelDef ? new THREE.Vector3().fromArray(doorPanelDef.min) : origin.clone();
    const max = doorPanelDef ? new THREE.Vector3().fromArray(doorPanelDef.max) : origin.clone();
    const corners = [];
    for (let i = 0; i < 8; i++) {
        corners.push(new THREE.Vector3(i & 1 ? max.x : min.x, i & 2 ? max.y : min.y, i & 4 ? max.z : min.z));
    }

    // The axis, along the door
    let start = Infinity, end = -Infinity;
    for (const corner of corners) {
        const t = corner.clone().sub(origin).dot(axis);
        start = Math.min(start, t);
        end = Math.max(end, t);
    }
    start -= BENCH_HINGE_AXIS_OVERRUN;
    end += BENCH_HINGE_AXIS_OVERRUN;
    const dash = hingeDef.approximate ? BENCH_HINGE_AXIS_DASH : end - start;
    const orientation = new THREE.Quaternion().setFromUnitVectors(new THREE.Vector3(0, 1, 0), axis);
    for (let t = start; t < end - 1e-9; t += dash * 2) {
        const length = Math.min(dash, end - t);
        const cylinder = new THREE.Mesh(new THREE.CylinderGeometry(BENCH_HINGE_AXIS_RADIUS, BENCH_HINGE_AXIS_RADIUS, length, 12), material);
        cylinder.quaternion.copy(orientation);
        cylinder.position.copy(origin).addScaledVector(axis, t + length / 2);
        parent.add(cylinder);
    }

    if (!doorPanelDef) return;

    // The door, wide open
    const size = max.clone().sub(min);
    const geometry = new THREE.BoxGeometry(size.x, size.y, size.z);
    geometry.translate(min.x + size.x / 2, min.y + size.y / 2, min.z + size.z / 2);
    geometry.applyMatrix4(fnRotation(angle));
    parent.add(new THREE.Mesh(geometry, new THREE.MeshBasicMaterial({
        side: THREE.DoubleSide,
        color: BENCH_HINGE_COLOR,
        transparent: true,
        opacity: BENCH_HINGE_DOOR_OPACITY,
        depthWrite: false,
    })));
    parent.add(new THREE.LineSegments(new THREE.EdgesGeometry(geometry, 30), lineMaterial));

    // The arcs of its hinged edge - toward +Y - at its end toward -X
    for (const corner of corners.filter(function (c) { return c.x === min.x && c.y === max.y; })) {
        const points = [];
        for (let i = 0; i <= BENCH_HINGE_ARC_SEGMENTS; i++) {
            points.push(corner.clone().applyMatrix4(fnRotation(angle * i / BENCH_HINGE_ARC_SEGMENTS)));
        }
        parent.add(new THREE.Line(new THREE.BufferGeometry().setFromPoints(points), lineMaterial));
    }

};

// The position of the hinge's axis - its pivot row hovered - : its y and
// z in the frame of the hardware, from its origin. false : hidden.
const fnShowBenchHingeCotes = function (visible) {
    if (benchHingeDimensions) {
        fnRemoveBenchObject(benchHingeDimensions);
        benchHingeDimensions = null;
    }
    if (bench && visible && benchHingeDef) {
        const cotes = benchHingeDef.cotes;
        const origin = new THREE.Vector3().fromArray(cotes.origin);
        const y = new THREE.Vector3().fromArray(cotes.y);
        benchHingeDimensions = new THREE.Group();
        fnAddBenchDimension(benchHingeDimensions, origin, y, benchHingeDef.texts.y, BENCH_AXIS_COLORS.y);
        fnAddBenchDimension(benchHingeDimensions, y, new THREE.Vector3().fromArray(cotes.position), benchHingeDef.texts.z, BENCH_AXIS_COLORS.z);
        fnGetBenchSlotGroup('a').add(benchHingeDimensions);
        fnApplyBenchSlotsVisible();
    }
    fnRender();
};

// The cote of a measure of the joint - its row hovered - : { slot, from,
// to, text }, points of the bench frame - see HardwareBenchDef#measure_cotes.
// null : none.
const fnShowBenchMeasure = function (measure) {
    if (benchMeasureDimension) {
        fnRemoveBenchObject(benchMeasureDimension);
        benchMeasureDimension = null;
    }
    if (bench && measure) {
        benchMeasureDimension = new THREE.Group();
        fnAddBenchDimension(benchMeasureDimension, new THREE.Vector3().fromArray(measure.from), new THREE.Vector3().fromArray(measure.to), measure.text, new THREE.Color(BENCH_PANEL_PIN_COLORS[measure.slot] || '#000000').multiplyScalar(1 - BENCH_MEASURE_DARKEN));
        fnGetBenchSlotGroup(measure.slot).add(benchMeasureDimension);
        fnApplyBenchSlotsVisible();
    }
    fnRender();
};

// The group holding everything of the given slot - its panel, its
// component, its cotes -, created on demand. No slot : the bench itself.
const fnGetBenchSlotGroup = function (slot) {
    if (!slot) return bench;
    if (!benchSlotGroups[slot]) {
        benchSlotGroups[slot] = new THREE.Group();
        bench.add(benchSlotGroups[slot]);
    }
    return benchSlotGroups[slot];
};

// The slots on the bench : { slot => visible }.
const fnGetBenchSlotsVisible = function () {
    const slotsVisible = {};
    for (const slot in benchSlotGroups || {}) {
        slotsVisible[slot] = !benchHiddenSlots[slot];
    }
    return slotsVisible;
};

// Hidden slots - kept through the rebuilds - hidden. Their pins and cotes
// too : the CSS2DRenderer only looks at their own visibility.
const fnApplyBenchSlotsVisible = function () {
    for (const slot in benchSlotGroups || {}) {
        const visible = !benchHiddenSlots[slot];
        benchSlotGroups[slot].visible = visible;
        benchSlotGroups[slot].traverse(function (child) {
            if (child.isCSS2DObject) child.visible = visible;
        });
    }
};

// Shows or hides everything of a slot. null : toggles it.
const fnSetBenchSlotVisible = function (slot, visible) {
    if (!benchSlotGroups || !benchSlotGroups[slot]) return;
    const hidden = visible == null ? !benchHiddenSlots[slot] : visible !== true;
    if (hidden === !!benchHiddenSlots[slot]) return;
    benchHiddenSlots[slot] = hidden;
    if (hidden && benchHoveredMesh && benchHoveredMesh.userData.benchSlot === slot) {
        fnHoverBenchSolid(null);
    }
    fnApplyBenchSlotsVisible();
    fnRender();
    fnDispatchHelpersChangedEvent();
};

// One panel stands out - its setting is hovered or edited -, or none.
const fnHighlightBenchPanel = function (slot) {
    benchHighlightedSlot = slot || null;
    if (!benchPanels) return;
    for (const panelSlot in benchPanels) {
        const highlighted = panelSlot === benchHighlightedSlot;
        benchPanels[panelSlot].mesh.material.opacity = highlighted ? BENCH_PANEL_HIGHLIGHTED_OPACITY : BENCH_PANEL_OPACITY;
        benchPanels[panelSlot].pin.element.classList.toggle('bench-pin-highlighted', highlighted);
    }
    fnRender();
};

const fnSetupBench = function (benchDef) {

    // No more hovered solid : its label hidden
    fnHoverBenchSolid(null);
    fnShowBenchMeasure(null);
    fnShowBenchHingeCotes(false);

    // Drop the previous bench - the cotes of its selected solid with it
    if (bench) {
        fnRemoveBenchObject(bench);
    }
    benchSelectedDimensions = null;
    const firstSetup = !bench;

    bench = new THREE.Group();
    benchSlotGroups = {};
    benchPanels = {};
    benchSolidMeshes = [];

    // Panels, with their pins
    for (const panelDef of benchDef.panels || []) {
        const min = new THREE.Vector3().fromArray(panelDef.min);
        const max = new THREE.Vector3().fromArray(panelDef.max);
        const size = max.clone().sub(min);
        const geometry = new THREE.BoxGeometry(size.x, size.y, size.z);
        geometry.translate(min.x + size.x / 2, min.y + size.y / 2, min.z + size.z / 2);
        const parent = fnGetBenchSlotGroup(panelDef.slot);
        const mesh = fnAddBenchObject(parent, geometry, BENCH_PANEL_COLORS[panelDef.slot] || 0xffffff, BENCH_PANEL_OPACITY);
        if (panelDef.reference) {
            fnAddBenchReferenceFace(parent, panelDef.reference, min, max, BENCH_PANEL_COLORS[panelDef.slot] || 0xffffff);
        }
        if (panelDef.slot) {
            benchPanels[panelDef.slot] = {
                mesh: mesh,
                pin: fnAddBenchPanelPin(parent, panelDef.slot, min, max)
            };
        }
    }

    // Solids of the primitives, in the frame of their slot
    for (const solidDef of benchDef.solids || []) {
        const group = new THREE.Group();
        group.applyMatrix4(new THREE.Matrix4().fromArray(solidDef.transformation));
        const opacity = solidDef.part === 'machining' ? 0.5 : 1;
        const mesh = fnAddBenchObject(group, fnCreateBenchSolidGeometry(solidDef), BENCH_PART_COLORS[solidDef.part], opacity);
        if (solidDef.label) {
            mesh.userData.benchLabel = solidDef.label;
            mesh.userData.benchSolidDef = solidDef;
            mesh.userData.benchSlot = solidDef.slot;
            mesh.userData.benchOutline = new THREE.LineSegments2(new THREE.LineSegmentsGeometry(), benchOutlineMaterial);
            mesh.userData.benchOutline.renderOrder = BENCH_OUTLINE_RENDER_ORDER;
            mesh.userData.benchOutline.visible = false;
            group.add(mesh.userData.benchOutline);
            benchSolidMeshes.push(mesh);
        }
        fnGetBenchSlotGroup(solidDef.slot).add(group);
    }

    // SKP files : their triangles and hard edges, in the frame of their slot
    for (const skpDef of benchDef.skps || []) {
        const group = new THREE.Group();
        group.applyMatrix4(new THREE.Matrix4().fromArray(skpDef.transformation));
        const opacity = skpDef.part === 'machining' ? 0.5 : 1;
        const facesGeometry = new THREE.BufferGeometry();
        facesGeometry.setAttribute('position', new THREE.Float32BufferAttribute(skpDef.faces, 3));
        group.add(new THREE.Mesh(facesGeometry, new THREE.MeshBasicMaterial({
            side: THREE.DoubleSide,
            color: BENCH_PART_COLORS[skpDef.part],
            transparent: opacity < 1,
            opacity: opacity,
            depthWrite: opacity >= 1,
            polygonOffset: true,
            polygonOffsetFactor: 1,
            polygonOffsetUnits: 1,
        })));
        const edgesGeometry = new THREE.BufferGeometry();
        edgesGeometry.setAttribute('position', new THREE.Float32BufferAttribute(skpDef.edges, 3));
        group.add(new THREE.LineSegments(edgesGeometry, lineMaterial));
        fnGetBenchSlotGroup(skpDef.slot).add(group);
    }

    // The door turning on its hinge
    benchHingeDef = benchDef.hinge || null;
    if (benchHingeDef) {
        fnAddBenchHinge(fnGetBenchSlotGroup('a'), benchHingeDef, (benchDef.panels || []).find(function (panelDef) { return panelDef.slot === 'a'; }));
    }

    // Shown as the bench says - its frame turned
    const viewMatrix = benchDef.view ? new THREE.Matrix4().fromArray(benchDef.view) : new THREE.Matrix4();
    bench.applyMatrix4(viewMatrix);

    scene.add(bench);
    fnApplyBenchSlotsVisible();   // Hidden slots kept through the rebuilds
    fnHighlightBenchPanel(benchHighlightedSlot);   // Kept through the rebuilds
    fnSelectBenchSolid(benchSelectedSolid);   // Kept through the rebuilds

    // Bench box properties - what zoom and views fit : centered on the
    // origin of the joint, the views turn and zoom around it
    const benchBox = new THREE.Box3().setFromObject(bench);
    if (benchBox.isEmpty()) {
        benchBox.set(new THREE.Vector3(-1, -1, -1), new THREE.Vector3(1, 1, 1));
    }
    const extent = benchBox.max.clone().max(benchBox.min.clone().negate());
    baseModelSize = explodedModelSize = extent.clone().multiplyScalar(2);
    baseModelCenter = explodedModelCenter = new THREE.Vector3();
    baseModelRadius = explodedModelRadius = extent.length();
    explodeFactor = 0;

    camera.near = -baseModelRadius * 4;
    camera.far = baseModelRadius * 8;
    camera.updateProjectionMatrix();

    // Axes of the joint, at its origin - shown until hidden
    const axesVisible = axesHelper ? axesHelper.visible : true;
    if (axesHelper) {
        scene.remove(axesHelper);
    }
    axesHelper = new THREE.Group();
    axesHelper.visible = axesVisible;
    axesHelper.applyMatrix4(viewMatrix);
    for (const [ direction, color ] of [ [ new THREE.Vector3(1, 0, 0), BENCH_AXIS_COLORS.x ], [ new THREE.Vector3(0, 1, 0), BENCH_AXIS_COLORS.y ], [ new THREE.Vector3(0, 0, 1), BENCH_AXIS_COLORS.z ] ]) {
        axesHelper.add(new THREE.ArrowHelper(direction, new THREE.Vector3(), baseModelRadius * 1.5, color, 0));
    }
    scene.add(axesHelper);

    if (firstSetup) {
        fnSetView(THREE_CAMERA_VIEWS.isometric, false);
        fnDispatchControlsChangedEvent('init');
    }
    fnDispatchHelpersChangedEvent();   // The axes and slots buttons show them - the slots may change

    fnRender();

};

// Startup

fnInit();

// Ready : told to the component - see LadbThreeViewer#bind
window.ladbViewerReady = true;
if (window.frameElement) {
    window.frameElement.dispatchEvent(new MessageEvent('ready.viewer'));
}

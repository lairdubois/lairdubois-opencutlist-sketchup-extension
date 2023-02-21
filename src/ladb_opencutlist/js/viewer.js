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

// Declarations

const DPI = 96;

let renderer,
    cssRenderer,
    container,
    scene,
    controls,

    defaultMeshMaterial,
    defaultLineMaterial,

    viewportWidth,
    viewportHeight,

    model,
    modelBox,
    modelSize,
    modelCenter,
    modelRadius,

    explodeFactor,

    boxHelper,
    axesHelper,

    pinsGroup,
    pinsOptions
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

    camera = new THREE.OrthographicCamera(-1, 1, 1, -1, -1000, 1000);

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

    defaultMeshMaterial = new THREE.MeshBasicMaterial({
        side: THREE.DoubleSide,
        color: 0xffffff,
        polygonOffset: true,
        polygonOffsetFactor: 1,
        polygonOffsetUnits: 1,
    });
    defaultLineMaterial = new THREE.LineBasicMaterial({
        color: 0x000000
    });
    defaultConditionalLineMaterial = new ConditionalLineMaterial({
        fog: false,
        color: 0x000000
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

    // Controls listeners
    controls.addEventListener('change', function () {
        fnRender();
    });
    controls.addEventListener('end', function () {
        fnDispatchCameraChangedEvent();
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
                        call.params.pinsText,
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

                case 'set_zoom':
                    fnSetZoom(call.params.zoom);
                    break;

                case 'set_view':
                    fnSetView(call.params.view);
                    break;

                case 'set_box_helper_visible':
                    fnSetBoxHelperVisible(call.params.visible);
                    break;

                case 'set_axes_helper_visible':
                    fnSetAxesHelperVisible(call.params.visible);
                    break;

                case 'set_explode_factor':
                    fnSetExplodeFactor(call.params.factor);
                    break;

            }

        }

    };

}

const fnGetCurrentView = function () {
    return camera.position.clone().sub(controls.target).multiplyScalar(1 / modelRadius).toArray().map(function (v) { return Number.parseFloat(v.toFixed(4)); });
}

const fnGetZoomAutoByView = function (view) {

    switch (JSON.stringify(view)) {

        case JSON.stringify(THREE_CAMERA_VIEWS.none):
            return 1;

        case JSON.stringify(THREE_CAMERA_VIEWS.isometric):
            let width2d = (modelSize.x + modelSize.y) * Math.cos(Math.PI / 6);
            let height2d = (modelSize.x + modelSize.y) * Math.cos(Math.PI / 3) + modelSize.z;
            return Math.min(viewportWidth / width2d, viewportHeight / height2d);

        case JSON.stringify(THREE_CAMERA_VIEWS.top):
            return Math.min(viewportWidth / modelSize.x, viewportHeight / modelSize.y) * 0.8;

        case JSON.stringify(THREE_CAMERA_VIEWS.bottom):
            return Math.min(viewportWidth / modelSize.x, viewportHeight / modelSize.y) * 0.8;

        case JSON.stringify(THREE_CAMERA_VIEWS.front):
            return Math.min(viewportWidth / modelSize.x, viewportHeight / modelSize.z) * 0.8;

        case JSON.stringify(THREE_CAMERA_VIEWS.back):
            return Math.min(viewportWidth / modelSize.x, viewportHeight / modelSize.z) * 0.8;

        case JSON.stringify(THREE_CAMERA_VIEWS.left):
            return Math.min(viewportWidth / modelSize.y, viewportHeight / modelSize.z) * 0.8;

        case JSON.stringify(THREE_CAMERA_VIEWS.right):
            return Math.min(viewportWidth / modelSize.y, viewportHeight / modelSize.z) * 0.8;

        default:
            return Math.min(viewportWidth / modelRadius, viewportHeight / modelRadius) * 0.5;

    }
}

const fnDispatchCameraChangedEvent = function () {

    let view = fnGetCurrentView();

    window.frameElement.dispatchEvent(new MessageEvent('camera.changed', {
        data: {
            cameraView: view,
            cameraZoom: camera.zoom,
            cameraTarget: controls.target.toArray([]),
            cameraZoomIsAuto: camera.zoom === fnGetZoomAutoByView(view),
            cameraTargetIsAuto: controls.target.equals(modelCenter),
        }
    }));

}

const fnDispatchExplodeChangedEvent = function () {

    window.frameElement.dispatchEvent(new MessageEvent('explode.changed', {
        data: {
            explodeFactor: explodeFactor,
        }
    }));

}

const fnDispatchHelpersChangedEvent = function () {

    window.frameElement.dispatchEvent(new MessageEvent('helpers.changed', {
        data: {
            boxHelperVisible: boxHelper ? boxHelper.visible : false,
            axesHelperVisible: axesHelper ? axesHelper.visible : false
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
    cssRenderer.setSize(window.innerWidth, window.innerHeight);

}

const fnRender = function () {
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

        let partDef = modelDef.definitions[objectDef.part_id];
        if (partDef) {

            group.userData.isPart = true;
            group.userData.name = partDef.name;
            group.userData.number = partDef.number;
            group.userData.color = new THREE.Color(partDef.color);

            // Mesh

            let facesGeometry = new THREE.BufferGeometry();
            facesGeometry.setAttribute('position', new THREE.Float32BufferAttribute(partDef.face_vertices, 3));
            if (partsColored) {
                facesGeometry.setAttribute('color', new THREE.Float32BufferAttribute(partDef.face_colors, 3));
            }

            let mesh = new THREE.Mesh(facesGeometry, defaultMeshMaterial);
            group.add(mesh);

            // Line

            let hardEdgesGeometry = new THREE.BufferGeometry();
            hardEdgesGeometry.setAttribute('position', new THREE.Float32BufferAttribute(partDef.hard_edge_vertices, 3));

            let hardEdgesLine = new THREE.LineSegments(hardEdgesGeometry, defaultLineMaterial);
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

const fnUpdateExplodeVectors = function (group, parentCenter) {

    const worldGroupBox = new THREE.Box3().setFromObject(group);
    const worldGroupCenter = worldGroupBox.getCenter(new THREE.Vector3());

    const localParentCenter = group.parent.worldToLocal(parentCenter.clone());
    const localGroupCenter = group.parent.worldToLocal(worldGroupCenter.clone());

    group.userData.explodeVector =  localGroupCenter.clone().sub(localParentCenter);

    if (!group.userData.isPart) {
        for (let object of group.children) {
            if (object.isGroup) {
                fnUpdateExplodeVectors(object, worldGroupCenter);
            }
        }
    }

}

const fnExplodeModel = function (factor = 0) {
    explodeFactor = factor;
    fnExplodeGroup(model, factor);
    fnCreateModelPins();
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

const fnCreateModelPins = function () {
    if (pinsGroup) {
        pinsGroup.clear();
    }
    if (model && pinsOptions && !pinsOptions.pinsHidden) {
        if (!pinsGroup) {
            pinsGroup = new THREE.Group();
            scene.add(pinsGroup);
        }
        fnCreateGroupPins(model, pinsOptions.pinsColored, pinsOptions.pinsText, pinsOptions.pinsLength, pinsOptions.pinsDirection, modelCenter);
    }
}

const fnCreateGroupPins = function (group, pinsColored, pinsText, pinsLength, pinsDirection, parentCenter) {

    const groupBox = new THREE.Box3().setFromObject(group);
    const groupCenter = groupBox.getCenter(new THREE.Vector3());

    if (group.userData.isPart) {

        let pinText, pinClass;
        switch (pinsText) {
            case 0: // PINS_TEXT_NUMBER
                pinText = group.userData.number;
                pinClass = null;
                break;
            case 1: // PINS_TEXT_NAME
                pinText = group.userData.name;
                pinClass = 'square';
                break;
            case 2: // PINS_TEXT_NUMBER_AND_NAME
                pinText = group.userData.number + ' - ' + group.userData.name;
                pinClass = 'square';
                break;
        }

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
                    pinPosition.add(new THREE.Vector3(modelRadius * pinLengthFactor, 0, 0));
                    break;
                case 1: // PINS_DIRECTION_Y
                    pinPosition.add(new THREE.Vector3(0, modelRadius * pinLengthFactor, 0));
                    break;
                case 2: // PINS_DIRECTION_Z
                    pinPosition.add(new THREE.Vector3(0, 0, modelRadius * pinLengthFactor));
                    break;
                case 3: // PINS_DIRECTION_PARENT_CENTER
                    pinPosition.sub(parentCenter).setLength(modelRadius * pinLengthFactor).add(groupCenter);
                    break;
                default:
                case 4: // PINS_DIRECTION_MODEL_CENTER
                    pinPosition.sub(modelCenter).setLength(modelRadius * pinLengthFactor).add(groupCenter);
                    break;
            }
        }

        const pinDiv = document.createElement('div');
        pinDiv.className = 'pin' + (pinClass ? ' pin-' + pinClass : '');
        pinDiv.textContent = pinText;
        if (pinsColored && group.userData.color) {
            pinDiv.style.backgroundColor = '#' + group.userData.color.getHexString();
            pinDiv.style.borderColor = '#' + group.userData.color.clone().addScalar(-0.5).getHexString();
            pinDiv.style.color = fnIsDarkColor(group.userData.color) ? 'white' : 'black';
        }

        const pin = new THREE.CSS2DObject(pinDiv);
        pin.position.copy(pinPosition);
        pinsGroup.add(pin);

        if (pinLengthFactor > 0) {
            const line = new THREE.Line(new THREE.BufferGeometry().setFromPoints([ groupCenter, pinPosition ]), pinLineMaterial);
            line.renderOrder = 1;
            pinsGroup.add(line);
        }

    } else {

        for (let object of group.children) {
            if (object.isGroup) {
                fnCreateGroupPins(object, pinsColored, pinsText, pinsLength, pinsDirection, groupCenter);
            }
        }

    }

};

const fnSetZoom = function (zoom) {
    controls.target0.copy(controls.target);
    controls.position0.copy(camera.position);
    controls.zoom0 = zoom ? zoom : fnGetZoomAutoByView(fnGetCurrentView());
    controls.reset();
    fnDispatchCameraChangedEvent();
}

const fnSetView = function (view = THREE_CAMERA_VIEWS.isometric) {

    let currentView = fnGetCurrentView();
    let currentZoomAuto = fnGetZoomAutoByView(currentView);
    let currentZoomIsAuto = camera.zoom === currentZoomAuto;

    controls.target0.copy(modelCenter);
    controls.position0.fromArray(view).multiplyScalar(modelRadius).add(controls.target0);
    controls.zoom0 = currentZoomIsAuto ? fnGetZoomAutoByView(view) : camera.zoom;

    controls.reset();

    fnDispatchCameraChangedEvent();

}

const fnSetExplodeFactor = function (factor) {
    const oldFactor = explodeFactor;
    fnExplodeModel(factor);
    fnRender();
    if (oldFactor !== explodeFactor) {
        fnDispatchExplodeChangedEvent();
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

const fnSetupModel = function(modelDef, partsColored, partsOpacity, pinsHidden, pinsColored, pinsText, pinsLength, pinsDirection, cameraView, cameraZoom, cameraTarget, explodeFactor) {

    if (partsColored) {
        defaultMeshMaterial.vertexColors = true;
    }
    if (partsOpacity < 1) {
        defaultMeshMaterial.opacity = partsOpacity;
        defaultMeshMaterial.transparent = true;
    }

    model = fnAddObjectDef(modelDef, modelDef, scene, partsColored);
    if (model) {

        // Compute model box properties

        modelBox = new THREE.Box3().setFromObject(model);
        modelSize = modelBox.getSize(new THREE.Vector3());
        modelCenter = modelBox.getCenter(new THREE.Vector3());
        modelRadius = modelBox.getBoundingSphere(new THREE.Sphere()).radius;

        // Option

        pinsOptions = {
            pinsHidden: pinsHidden,
            pinsColored: pinsColored,
            pinsText: pinsText,
            pinsLength: pinsLength,
            pinsDirection: pinsDirection
        };

        fnUpdateExplodeVectors(model, modelCenter);

        if (explodeFactor > 0) {
            fnExplodeModel(explodeFactor);
            fnDispatchExplodeChangedEvent();
        }

        if (explodeFactor === 0 && !pinsHidden) {   // Else explode already create pins
            fnCreateModelPins();
        }

        if (cameraView) {

            if (cameraTarget) {
                controls.target0.fromArray(cameraTarget);
            } else {
                controls.target0.copy(modelCenter); // Auto target
            }

            controls.position0.fromArray(cameraView).multiplyScalar(modelRadius).add(controls.target0);

            if (cameraZoom) {
                controls.zoom0 = cameraZoom;
            } else {
                controls.zoom0 = fnGetZoomAutoByView(cameraView);   // Auto zoom
            }

            controls.reset();

            fnDispatchCameraChangedEvent();

        } else {

            // Start with isometric view + auto target + auto zoom
            fnSetView(THREE_CAMERA_VIEWS.isometric);

        }

        // Create box helper
        boxHelper = new THREE.BoxHelper(model, 0x0000ff);
        boxHelper.visible = false;
        scene.add(boxHelper);

        // Create axes helper
        axesHelper = new THREE.Group();
        axesHelper.visible = false;
        axesHelper.applyMatrix4(model.matrixWorld.invert());
        axesHelper.add(new THREE.ArrowHelper(
            new THREE.Vector3(1, 0, 0),
            new THREE.Vector3(0, 0, 0),
            modelRadius * 5,
            0xff0000,
            0
        ));
        axesHelper.add(new THREE.ArrowHelper(
            new THREE.Vector3(0, 1, 0),
            new THREE.Vector3(0, 0, 0),
            modelRadius * 5,
            0x00ff00,
            0
        ));
        axesHelper.add(new THREE.ArrowHelper(
            new THREE.Vector3(0, 0, 1),
            new THREE.Vector3(0, 0, 0),
            modelRadius * 5,
            0x0000ff,
            0
        ));
        scene.add(axesHelper);

    }

}

const fnIsDarkColor = function (color) {
    return (0.2126 * color.r + 0.7152 * color.g + 0.0722 * color.b) <= 0.51
}

// Startup

fnInit();

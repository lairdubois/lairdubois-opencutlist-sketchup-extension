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

    boxHelper,
    axesHelper
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

    // Create axes helper

    axesHelper = new THREE.Group();
    axesHelper.visible = false;
    scene.add(axesHelper);

    const lengthArrowHelper = new THREE.ArrowHelper(
        new THREE.Vector3(1, 0, 0),
        new THREE.Vector3(0, 0, 0),
        100,
        0xff0000,
        0
    );
    axesHelper.add(lengthArrowHelper);

    const widthArrowHelper = new THREE.ArrowHelper(
        new THREE.Vector3(0, 1, 0),
        new THREE.Vector3(0, 0, 0),
        100,
        0x00ff00,
        0
    );
    axesHelper.add(widthArrowHelper);

    const thicknessArrowHelper = new THREE.ArrowHelper(
        new THREE.Vector3(0, 0, 1),
        new THREE.Vector3(0, 0, 0),
        100,
        0x0000ff,
        0
    );
    axesHelper.add(thicknessArrowHelper);

    // Create the camera

    camera = new THREE.OrthographicCamera(-1, 1, 1, -1, -1000, 1000);

    // Create controls

    controls = new THREE.OrbitControls(camera, cssRenderer.domElement);
    controls.rotateSpeed = 0.5;
    controls.zoomSpeed = 1.5;
    controls.enableRotate = true;
    controls.autoRotateSpeed = 3.0;
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
        fnDispatchCameraChanged();
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
                        call.params.pinsHidden,
                        call.params.pinsLength,
                        call.params.pinsDirection,
                        call.params.pinsColored,
                        call.params.cameraView,
                        call.params.cameraZoom,
                        call.params.cameraTarget
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

                case 'set_auto_rotate_enable':
                    fnSetAutoRotateEnable(call.params.enable);
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

const fnDispatchCameraChanged = function () {

    let view = fnGetCurrentView();

    window.frameElement.dispatchEvent(new MessageEvent('camera.changed', {
        data: {
            cameraView: view,
            cameraZoom: camera.zoom,
            cameraTarget: controls.target.toArray([]),
            cameraZoomIsAuto: camera.zoom === fnGetZoomAutoByView(view),
            cameraTargetIsAuto: controls.target.equals(modelCenter)
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

const fnAddObjectDef = function (objectDef, parent, material, partsColored) {

    if (objectDef.color) {
        material = defaultMeshMaterial.clone();
        material.color.set(objectDef.color);
    }

    switch (objectDef.type) {

        case 1: // TYPE_MODEL
        case 2: // TYPE_PART
        case 3: // TYPE_GROUP

            let group = new THREE.Group();
            if (objectDef.matrix) {
                let matrix = new THREE.Matrix4();
                matrix.elements = objectDef.matrix;
                group.applyMatrix4(matrix);
            }
            for (childObjectDef of objectDef.children) {
                fnAddObjectDef(childObjectDef, group, material, partsColored);
            }
            if (objectDef.type === 2 && objectDef.pin_text) {
                group.userData = {
                    pinText: objectDef.pin_text,
                    pinClass: objectDef.pin_class,
                    pinColor: material.color
                }
            }
            parent.add(group);

            return group;

        case 4: // TYPE_MESH

            let vertices = new Float32Array(objectDef.vertices)
            let geometry = new THREE.BufferGeometry();
            geometry.setAttribute('position', new THREE.BufferAttribute(vertices, 3));

            let mesh = new THREE.Mesh(geometry, partsColored ? material : defaultMeshMaterial);
            parent.add(mesh);

            let edges = new THREE.EdgesGeometry(geometry, 36);
            let line = new THREE.LineSegments(edges, defaultLineMaterial);
            parent.add(line);

            return mesh;

    }

    return null;
};

const fnCreatePins = function (group, pinsLength, pinsDirection, pinsColored, parentCenter) {

    const groupBox = new THREE.Box3().setFromObject(group);
    const groupCenter = groupBox.getCenter(new THREE.Vector3());

    if (group.userData.pinText) {

        let pinsLengthFactor;
        switch (pinsLength) {
            case 0:   // PINS_LENGTH_NONE
                pinsLengthFactor = 0
                break;
            case 2:   // PINS_LENGTH_MEDIUM
                pinsLengthFactor = 0.2
                break;
            case 3:   // PINS_LENGTH_LONG
                pinsLengthFactor = 0.4
                break;
            case 1:   // PINS_LENGTH_SHORT
            default:
                pinsLengthFactor = 0.1
                break;
        }

        const pinPosition = groupCenter.clone();
        if (pinsLengthFactor > 0) {
            switch (pinsDirection) {
                case 0: // PINS_DIRECTION_X
                    pinPosition.add(new THREE.Vector3(modelRadius * pinsLengthFactor, 0, 0));
                    break;
                case 1: // PINS_DIRECTION_Y
                    pinPosition.add(new THREE.Vector3(0, modelRadius * pinsLengthFactor, 0));
                    break;
                case 2: // PINS_DIRECTION_Z
                    pinPosition.add(new THREE.Vector3(0, 0, modelRadius * pinsLengthFactor));
                    break;
                case 3: // PINS_DIRECTION_PARENT_CENTER
                    pinPosition.sub(parentCenter).setLength(modelRadius * pinsLengthFactor).add(groupCenter);
                    break;
                default:
                case 4: // PINS_DIRECTION_MODEL_CENTER
                    pinPosition.sub(modelCenter).setLength(modelRadius * pinsLengthFactor).add(groupCenter);
                    break;
            }
        }

        const pinDiv = document.createElement('div');
        pinDiv.className = 'pin' + (group.userData.pinClass ? ' pin-' + group.userData.pinClass : '');
        pinDiv.textContent = group.userData.pinText;
        if (pinsColored && group.userData.pinColor) {
            pinDiv.style.backgroundColor = '#' + group.userData.pinColor.getHexString();
            pinDiv.style.borderColor = '#' + group.userData.pinColor.clone().addScalar(-0.5).getHexString();
            pinDiv.style.color = fnIsDarkColor(group.userData.pinColor) ? 'white' : 'black';
        }

        const pin = new THREE.CSS2DObject(pinDiv);
        pin.position.copy(pinPosition);
        scene.add(pin);

        if (pinsLengthFactor > 0) {
            const line = new THREE.Line(new THREE.BufferGeometry().setFromPoints([ groupCenter, pinPosition ]), pinLineMaterial);
            line.renderOrder = 1;
            scene.add(line);
        }

    }

    for (let object of group.children) {
        if (object.isGroup) {
            fnCreatePins(object, pinsLength, pinsDirection, pinsColored, groupCenter);
        }
    }

};

const fnSetZoom = function (zoom) {
    controls.target0.copy(controls.target);
    controls.position0.copy(camera.position);
    controls.zoom0 = zoom ? zoom : fnGetZoomAutoByView(fnGetCurrentView());
    controls.reset();
    fnDispatchCameraChanged();
}

const fnSetView = function (view = THREE_CAMERA_VIEWS.isometric) {

    let currentView = fnGetCurrentView();
    let currentZoomAuto = fnGetZoomAutoByView(currentView);
    let currentZoomIsAuto = camera.zoom === currentZoomAuto;

    controls.target0.copy(modelCenter);
    controls.position0.fromArray(view).multiplyScalar(modelRadius).add(controls.target0);
    controls.zoom0 = currentZoomIsAuto ? fnGetZoomAutoByView(view) : camera.zoom;

    controls.reset();

    fnDispatchCameraChanged();
    fnSetAutoRotateEnable(false);

}

const fnSetBoxHelperVisible = function (visible) {
    if (boxHelper) {
        if (visible == null) {
            boxHelper.visible = !boxHelper.visible;
        } else {
            boxHelper.visible = visible === true
        }
        fnRender();
    }
}

const fnSetAxesHelperVisible = function (visible) {
    if (axesHelper) {
        if (visible == null) {
            axesHelper.visible = !axesHelper.visible;
        } else {
            axesHelper.visible = visible === true
        }
        fnRender();
    }
}

const fnSetAutoRotateEnable = function (enable) {
    if (controls) {
        if (enable == null) {
            fnStartAnimate();
            controls.autoRotate = !controls.autoRotate;
        } else {
            fnStopAnimate();
            controls.autoRotate = enable === true
        }
    }
}

const fnSetupModel = function(modelDef, partsColored, pinsHidden, pinsLength, pinsDirection, pinsColored, cameraView, cameraZoom, cameraTarget) {

    model = fnAddObjectDef(modelDef, scene, defaultMeshMaterial, partsColored);
    if (model) {

        // Compute model box properties

        modelBox = new THREE.Box3().setFromObject(model);
        modelSize = modelBox.getSize(new THREE.Vector3());
        modelCenter = modelBox.getCenter(new THREE.Vector3());
        modelRadius = modelBox.getBoundingSphere(new THREE.Sphere()).radius;

        if (!pinsHidden) {

            // Create labels
            fnCreatePins(model, pinsLength, pinsDirection, pinsColored, modelCenter);

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

            fnDispatchCameraChanged();

        } else {

            // Start with isometric view + auto target + auto zoom
            fnSetView(THREE_CAMERA_VIEWS.isometric);

        }

        // Create box helper
        boxHelper = new THREE.BoxHelper(model, 0x0000ff);
        boxHelper.visible = false;
        scene.add(boxHelper);

    }

}

const fnIsDarkColor = function (color) {
    return (0.2126 * color.r + 0.7152 * color.g + 0.0722 * color.b) <= 0.51
}

// Startup

fnInit();



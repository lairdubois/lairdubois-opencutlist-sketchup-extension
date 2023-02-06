// Declarations

let renderer,
    textRenderer,
    container,
    scene,
    controls,
    defaultMeshMaterial,
    defaultLineMaterial,
    model,
    modelBox,
    modelSize,
    modelCenter,
    modelRadius,
    boxHelper,
    axesHelper
;

// Functions

const fnInit = function() {

    // Define the default Up vector

    THREE.Object3D.DefaultUp.set(0, 0, 1);

    // Create the renderers

    renderer = new THREE.WebGLRenderer();
    renderer.antialias = true;
    renderer.setPixelRatio(window.devicePixelRatio);
    document.body.appendChild(renderer.domElement);

    textRenderer = new THREE.CSS2DRenderer();
    textRenderer.domElement.style.position = 'absolute';
    textRenderer.domElement.style.top = '0px';
    document.body.appendChild(textRenderer.domElement);

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

    camera = new THREE.OrthographicCamera(-1, 1, 1, -1, -0.1, 1000);

    // Create controls

    controls = new THREE.OrbitControls(camera, textRenderer.domElement);
    controls.rotateSpeed = 0.5;
    controls.zoomSpeed = 2.0;
    controls.autoRotateSpeed = 3.0;
    controls.mouseButtons = {
        LEFT: THREE.MOUSE.ROTATE,
        MIDDLE: THREE.MOUSE.ROTATE,
        RIGHT: null
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

    // Add listeners
    window.onresize = function () {
        fnUpdateViewportSize();
        fnRender();
    };
    window.onmessage = function (e) {

        let call = e.data;
        if (call.command) {

            switch (call.command) {

                case 'setup_model':
                    fnSetupModel(call.params.modelDef, call.params.pinsHidden, call.params.pinsColored, call.params.partsColored);
                    if (call.params.showBoxHelper) {
                        fnSetBoxHelperVisible(true);
                    }
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

    fnUpdateViewportSize();
}

const fnUpdateViewportSize = function () {

    camera.left = window.innerWidth / -2;
    camera.right = window.innerWidth / 2;
    camera.top = window.innerHeight / 2;
    camera.bottom = window.innerHeight / -2;
    camera.updateProjectionMatrix();

    renderer.setSize(window.innerWidth, window.innerHeight);
    textRenderer.setSize(window.innerWidth, window.innerHeight);

}

const fnRender = function () {
    renderer.render(scene, camera);
    textRenderer.render(scene, camera);
}

const fnAnimate = function () {
    requestAnimationFrame(fnAnimate);
    fnRender();
    controls.update();
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
                    pinColor: '#' + material.color.getHexString()
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
            line.computeLineDistances();
            parent.add(line);

            return mesh;

    }

    return null;
};

const fnCreatePins = function (group, pinsColored) {

    if (group.userData.pinText) {

        const groupBox = new THREE.Box3().setFromObject(group);
        const groupCenter = groupBox.getCenter(new THREE.Vector3());
        const pinPoint = groupCenter.clone().sub(modelCenter).setLength(modelRadius / 10).add(groupCenter);

        const pinDiv = document.createElement('div');
        pinDiv.className = 'pin';
        pinDiv.textContent = group.userData.pinText;
        if (pinsColored) {
            pinDiv.style.borderColor = group.userData.pinColor;
        }

        const pin = new THREE.CSS2DObject(pinDiv);
        pin.position.copy(pinPoint);
        scene.add(pin);

        const line = new THREE.Line(new THREE.BufferGeometry().setFromPoints([ groupCenter, pinPoint ]), pinLineMaterial);
        line.renderOrder = 1;
        scene.add(line);

    }

    for (let object of group.children) {
        fnCreatePins(object, pinsColored);
    }

};

const fnSetView = function (view) {

    switch (view) {

        case 'isometric':

            let width2d = (modelSize.x + modelSize.y) * Math.cos(Math.PI / 6);
            let height2d = (modelSize.x + modelSize.y) * Math.cos(Math.PI / 3) + modelSize.z;

            controls.position0.set(1, -1, 1).multiplyScalar(modelRadius).add(controls.target0);
            controls.zoom0 = Math.min(window.innerWidth / width2d, window.innerHeight / height2d);

            break;

        case 'top':

            controls.position0.set(0, 0, 1).multiplyScalar(modelRadius).add(controls.target0);
            controls.zoom0 = Math.min(window.innerWidth / modelSize.x, window.innerHeight / modelSize.y) * 0.8;

            break

        case 'bottom':

            controls.position0.set(0, 0, -1).multiplyScalar(modelRadius).add(controls.target0);
            controls.zoom0 = Math.min(window.innerWidth / modelSize.x, window.innerHeight / modelSize.y) * 0.8;

            break

        case 'front':

            controls.position0.set(0, -1, 0).multiplyScalar(modelRadius).add(controls.target0);
            controls.zoom0 = Math.min(window.innerWidth / modelSize.x, window.innerHeight / modelSize.z) * 0.8;

            break

        case 'back':

            controls.position0.set(0, 1, 0).multiplyScalar(modelRadius).add(controls.target0);
            controls.zoom0 = Math.min(window.innerWidth / modelSize.x, window.innerHeight / modelSize.z) * 0.8;

            break

        case 'left':

            controls.position0.set(-1, 0, 0).multiplyScalar(modelRadius).add(controls.target0);
            controls.zoom0 = Math.min(window.innerWidth / modelSize.y, window.innerHeight / modelSize.z) * 0.8;

            break

        case 'right':

            controls.position0.set(1, 0, 0).multiplyScalar(modelRadius).add(controls.target0);
            controls.zoom0 = Math.min(window.innerWidth / modelSize.y, window.innerHeight / modelSize.z) * 0.8;

            break

    }

    controls.reset();

    controls.enableRotate = true;
    controls.autoRotate = false;

}

const fnSetBoxHelperVisible = function (visible) {
    if (boxHelper) {
        if (visible == null) {
            boxHelper.visible = !boxHelper.visible;
        } else {
            boxHelper.visible = visible === true
        }
    }
}

const fnSetAxesHelperVisible = function (visible) {
    if (axesHelper) {
        if (visible == null) {
            axesHelper.visible = !axesHelper.visible;
        } else {
            axesHelper.visible = visible === true
        }
    }
}

const fnSetAutoRotateEnable = function (enable) {
    if (controls) {
        if (enable == null) {
            controls.autoRotate = !controls.autoRotate;
        } else {
            controls.autoRotate = enable === true
        }
    }
}

const fnSetupModel = function(modelDef, pinsHidden, pinsColored, partsColored) {

    model = fnAddObjectDef(modelDef, scene, defaultMeshMaterial, partsColored);
    if (model) {

        // Compute model box properties

        modelBox = new THREE.Box3().setFromObject(model);
        modelSize = modelBox.getSize(new THREE.Vector3());
        modelCenter = modelBox.getCenter(new THREE.Vector3());
        modelRadius = modelBox.getBoundingSphere(new THREE.Sphere()).radius;

        if (!pinsHidden) {

            // Create labels
            fnCreatePins(model, pinsColored);

        }

        // Center controle on model
        controls.target0.copy(modelCenter);

        // Start with isometric view
        fnSetView('isometric');

        // Create box helper
        boxHelper = new THREE.BoxHelper(model, 0x0000ff);
        boxHelper.visible = false;
        scene.add(boxHelper);

        // Ready to animate
        fnAnimate();

    }

}

// Startup

fnInit();



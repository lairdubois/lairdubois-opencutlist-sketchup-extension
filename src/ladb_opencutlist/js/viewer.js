// Declarations

let renderer,
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

    // Create the renderer

    renderer = new THREE.WebGLRenderer();
    renderer.antialias = true;
    renderer.setPixelRatio(window.devicePixelRatio);
    renderer.setSize(window.innerWidth, window.innerHeight);

    // Create the container

    container = document.createElement('div');
    container.appendChild(renderer.domElement);
    document.body.appendChild(container);

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

    camera = new THREE.OrthographicCamera(
        container.offsetWidth / -2,
        container.offsetWidth / 2,
        container.offsetHeight / 2,
        container.offsetHeight / -2,
        -0.1,
        1000
    );

    // Create controls

    controls = new THREE.OrbitControls(camera, renderer.domElement);
    controls.rotateSpeed = 0.5;
    controls.zoomSpeed = 2.0;
    controls.autoRotateSpeed = 3.0;
    controls.mouseButtons = {
        LEFT: THREE.MOUSE.ROTATE,
        MIDDLE: THREE.MOUSE.ROTATE,
        RIGHT: THREE.MOUSE.PAN
    }

    // Create default materials

    defaultMeshMaterial = new THREE.MeshBasicMaterial({
        side: THREE.DoubleSide,
        color: 0xeeeeee,
        polygonOffset: true,
        polygonOffsetFactor: 1,
        polygonOffsetUnits: 1
    });
    defaultLineMaterial = new THREE.LineBasicMaterial({
        color: 0x000000
    });

    // Add listeners
    window.onmessage = function (e) {
        fnSetupModel(e.data.objectDef);
    };

    // UI

    document.getElementById('btn_front').addEventListener('click' , function () {
        fnSetFrontView();
    });
    document.getElementById('btn_back').addEventListener('click' , function () {
        fnSetBackView();
    });
    document.getElementById('btn_iso').addEventListener('click' , function () {
        fnSetIsometricView();
    });
    document.getElementById('btn_bbox').addEventListener('click' , function () {
        fnToggleBox();
    });
    document.getElementById('btn_axes').addEventListener('click' , function () {
        fnToggleAxes()
    });
    document.getElementById('btn_disco').addEventListener('click' , function () {
        fnToggleAutoRotate();
    });



}

const fnAnimate = function () {
    requestAnimationFrame(fnAnimate);
    renderer.render(scene, camera);
    controls.update();
}

const fnAddObjectDef = function (objectDef, parent, material) {

    if (objectDef.color) {
        material = defaultMeshMaterial.clone();
        material.color.set(objectDef.color);
    }

    switch (objectDef.type) {

        case 1: // TYPE_GROUP

            let group = new THREE.Group();
            if (objectDef.matrix) {
                let matrix = new THREE.Matrix4();
                matrix.elements = objectDef.matrix;
                group.applyMatrix4(matrix);
            }
            for (childObjectDef of objectDef.children) {
                fnAddObjectDef(childObjectDef, group, material);
            }
            parent.add(group);

            return group;

        case 2: // TYPE_MESH

            let vertices = new Float32Array(objectDef.vertices)
            let geometry = new THREE.BufferGeometry();
            geometry.setAttribute('position', new THREE.BufferAttribute(vertices, 3));

            let mesh = new THREE.Mesh(geometry, material);
            parent.add(mesh);

            let edges = new THREE.EdgesGeometry(geometry, 36);
            let line = new THREE.LineSegments(edges, defaultLineMaterial);
            parent.add(line);

            return mesh;

    }

    return null;
}

const fnSetIsometricView = function() {
    if (model) {

        let width2d = (modelSize.x + modelSize.y) * Math.cos(Math.PI / 6);
        let height2d = (modelSize.x + modelSize.y) * Math.cos(Math.PI / 3) + modelSize.z;

        controls.position0.set(1, -1, 1).multiplyScalar(modelRadius).add(controls.target0);
        controls.zoom0 = Math.min(container.offsetWidth / width2d, container.offsetHeight / height2d);
        controls.reset();

        controls.enableRotate = true;

    }
}

const fnSetFrontView = function () {
    if (model) {

        controls.position0.set(0, 0, 1).multiplyScalar(modelRadius).add(controls.target0);
        controls.zoom0 = Math.min(container.offsetWidth / modelSize.x, container.offsetHeight / modelSize.y) * 0.8;
        controls.reset();

        controls.enableRotate = false;

    }
}

const fnSetBackView = function () {
    if (model) {

        controls.position0.set(0, 0, -1).multiplyScalar(modelRadius).add(controls.target0);
        controls.zoom0 = Math.min(container.offsetWidth / modelSize.x, container.offsetHeight / modelSize.y) * 0.8;
        controls.reset();

        controls.enableRotate = false;

    }
}

const fnToggleBox = function () {
    if (boxHelper) {
        boxHelper.visible = !boxHelper.visible;
    }
}

const fnToggleAxes = function () {
    if (axesHelper) {
        axesHelper.visible = !axesHelper.visible;
    }
}

const fnToggleAutoRotate = function () {
    if (controls) {
        controls.autoRotate = !controls.autoRotate;
    }
}

const fnSetupModel = function(objectDef) {

    model = fnAddObjectDef(objectDef, scene, defaultMeshMaterial);
    if (model) {

        // Compute model box properties

        modelBox = new THREE.Box3().setFromObject(model);
        modelSize = modelBox.getSize(new THREE.Vector3());
        modelCenter = modelBox.getCenter(new THREE.Vector3());
        modelRadius = modelBox.getBoundingSphere(new THREE.Sphere()).radius;

        // Center controle on model
        controls.target0.copy(modelCenter);

        // Start with isometric view
        fnSetIsometricView();

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



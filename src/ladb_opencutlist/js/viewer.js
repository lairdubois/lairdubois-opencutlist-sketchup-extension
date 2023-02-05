
let camera, renderer, scene, controls;

let container = document.createElement('div');
document.body.appendChild(container);

// Materials

const defaultMaterial = new THREE.MeshBasicMaterial({
    side: THREE.DoubleSide,
    color: 0xeeeeee,
    polygonOffset: true,
    polygonOffsetFactor: 1,
    polygonOffsetUnits: 1
});
const lineBasicMaterial = new THREE.LineBasicMaterial({
    color: 0x000000
});

const fnAddObject = function (objectDef, parent, material) {

    if (objectDef.color) {
        material = defaultMaterial.clone();
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
                fnAddObject(childObjectDef, group, material);
            }
            parent.add(group);

            break;

        case 2: // TYPE_MESH

            let vertices = new Float32Array(objectDef.vertices)
            let geometry = new THREE.BufferGeometry();
            geometry.setAttribute('position', new THREE.BufferAttribute(vertices, 3));

            let mesh = new THREE.Mesh(geometry, material);
            parent.add(mesh);

            let edges = new THREE.EdgesGeometry(geometry, 36);
            let line = new THREE.LineSegments(edges, lineBasicMaterial);
            parent.add(line);

            break;

    }

}

const fnSetup = function (object) {

    let part = object.children[0];

    const bbox = new THREE.Box3().setFromObject(part);
    const center = bbox.getCenter(new THREE.Vector3());
    const size = bbox.getSize(new THREE.Vector3());
    const radius = Math.max(size.x, Math.max(size.y, size.z));

    let width2d = (size.x + size.y) * Math.cos(Math.PI / 6);
    let height2d = (size.x + size.y) * Math.cos(Math.PI / 3) + size.z;

    camera.left = container.offsetWidth / -2;
    camera.right = container.offsetWidth / 2;
    camera.top = container.offsetHeight / 2;
    camera.bottom = container.offsetHeight / -2;

    controls.target0.copy(center);
    controls.position0.set(1, -1, 1).multiplyScalar(radius).add(controls.target0);
    controls.zoom0 = Math.min(container.offsetWidth / width2d, container.offsetHeight / height2d);
    controls.reset();

    const boxHelper = new THREE.BoxHelper(part, 0x0000ff);
    boxHelper.visible = false;
    object.add(boxHelper);

    const axes = new THREE.Group();
    axes.visible = false;
    object.add(axes);

    const lengthArrowHelper = new THREE.ArrowHelper(
        new THREE.Vector3(1, 0, 0),
        new THREE.Vector3(0, 0, 0),
        radius * 10,
        0xff0000,
        0
    );
    axes.add(lengthArrowHelper);

    const widthArrowHelper = new THREE.ArrowHelper(
        new THREE.Vector3(0, 1, 0),
        new THREE.Vector3(0, 0, 0),
        radius * 10,
        0x00ff00,
        0
    );
    axes.add(widthArrowHelper);

    const thicknessArrowHelper = new THREE.ArrowHelper(
        new THREE.Vector3(0, 0, 1),
        new THREE.Vector3(0, 0, 0),
        radius * 10,
        0x0000ff,
        0
    );
    axes.add(thicknessArrowHelper);

    document.getElementById('btn_front').addEventListener('click' , function () {
        controls.position0.set(0, 0, 1).multiplyScalar(radius).add(controls.target0);
        controls.zoom0 = Math.min(container.offsetWidth / size.x, container.offsetHeight / size.y) * 0.8;
        controls.reset();
        controls.enableRotate = false;
    });
    document.getElementById('btn_back').addEventListener('click' , function () {
        controls.position0.set(0, 0, -1).multiplyScalar(radius).add(controls.target0);
        controls.zoom0 = Math.min(container.offsetWidth / size.x, container.offsetHeight / size.y) * 0.8;
        controls.reset();
        controls.enableRotate = false;
    });
    document.getElementById('btn_iso').addEventListener('click' , function () {
        controls.position0.set(1, -1, 1).multiplyScalar(radius).add(controls.target0);
        controls.zoom0 = Math.min(container.offsetWidth / width2d, container.offsetHeight / height2d);
        controls.reset();
        controls.enableRotate = true;
    });
    document.getElementById('btn_bbox').addEventListener('click' , function () {
        boxHelper.visible = !boxHelper.visible;
    });
    document.getElementById('btn_axes').addEventListener('click' , function () {
        axes.visible = !axes.visible;
    });
    document.getElementById('btn_disco').addEventListener('click' , function () {
        controls.autoRotate = !controls.autoRotate;
    });

    fnAnimate();

}

const fnAnimate = function () {
    requestAnimationFrame(fnAnimate);
    renderer.render(scene, camera);
    controls.update();
}


// Up

THREE.Object3D.DefaultUp.set(0, 0, 1);

// Camera

camera = new THREE.OrthographicCamera( -1, 1, 1, -1, -1, 1000 );

// Renderers

renderer = new THREE.WebGLRenderer({antialias: true});
renderer.setPixelRatio(window.devicePixelRatio);
renderer.setSize(window.innerWidth, window.innerHeight);
renderer.outputEncoding = THREE.sRGBEncoding;
renderer.toneMapping = THREE.NoToneMapping;
container.appendChild(renderer.domElement);

// Scene

scene = new THREE.Scene();
scene.background = new THREE.Color(0xffffff);

// Controls

controls = new THREE.OrbitControls(camera, renderer.domElement);
controls.rotateSpeed = 0.5;
controls.zoomSpeed = 2.0;
controls.autoRotateSpeed = 3.0;
controls.mouseButtons = {
    LEFT: THREE.MOUSE.ROTATE,
    MIDDLE: THREE.MOUSE.ROTATE,
    RIGHT: THREE.MOUSE.PAN
}

window.onmessage = function (e) {
    fnAddObject(e.data.objectDef, scene, defaultMaterial);
    fnSetup(scene);
};
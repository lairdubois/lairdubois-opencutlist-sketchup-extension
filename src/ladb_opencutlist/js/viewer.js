let container = document.createElement('div');
document.body.appendChild(container);

// Camera

const camera = new THREE.OrthographicCamera( -1, 1, 1, -1, 0.1, 1000 );
camera.up.set(0, 0, 1);

// Renderers

const renderer = new THREE.WebGLRenderer({antialias: true});
renderer.setPixelRatio(window.devicePixelRatio);
renderer.setSize(window.innerWidth, window.innerHeight);
renderer.outputEncoding = THREE.sRGBEncoding;
container.appendChild(renderer.domElement);

// Scene

const pmremGenerator = new THREE.PMREMGenerator(renderer);

let scene = new THREE.Scene();
scene.background = new THREE.Color(0xffffff);
scene.environment = pmremGenerator.fromScene(new THREE.RoomEnvironment()).texture;

// Controls

let controls = new THREE.OrbitControls(camera, renderer.domElement);
controls.minZoom = 0.8;
controls.maxZoom = 2.0;
controls.zoomSpeed = 2.0;
controls.autoRotateSpeed = 2.0;
controls.autoRotate = true;
controls.mouseButtons = {
    LEFT: THREE.MOUSE.ROTATE,
    MIDDLE: THREE.MOUSE.ROTATE,
    RIGHT: null
}
controls.enablePan = false;

// Materials

const defaultMaterial = new THREE.MeshBasicMaterial({
    color: 0xeeeeee,
    polygonOffset: true,
    polygonOffsetFactor: 1,
    polygonOffsetUnits: 0
});
const lineMaterial = new THREE.LineBasicMaterial({
    color: 0x000000,
});

const fnAddObject = function (objectDef, parent, material) {

    if (objectDef.color) {
        material = new THREE.MeshBasicMaterial({
            color: objectDef.color,
            polygonOffset: true,
            polygonOffsetFactor: 1,
            polygonOffsetUnits: 0
        });
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

            let edges = new THREE.EdgesGeometry(geometry, 90);
            let line = new THREE.LineSegments(edges, lineMaterial);
            parent.add(line);

            break;

    }

}

const fnSetup = function (model) {

    const bbox = new THREE.Box3().setFromObject(scene);
    const size = bbox.getSize(new THREE.Vector3());
    const radius = Math.max(size.x, Math.max(size.y, size.z));

    //

    let ratio = window.innerHeight / window.innerWidth

    camera.left = -radius * 2;
    camera.right = radius * 2;
    camera.top = radius * 2 * ratio;
    camera.bottom = -radius * 2 * ratio;

    controls.target0.copy(bbox.getCenter(new THREE.Vector3()));
    controls.position0.set(1, -1, 1).multiplyScalar(radius).add(controls.target0);
    controls.reset();

    const boxHelper = new THREE.BoxHelper(model, 0x0000ff);
    scene.add(boxHelper);

    let axesHelper = new THREE.AxesHelper(radius / 2.0);
    scene.add(axesHelper);

    fnAnimate();

}

//

const fnAnimate = function () {
    requestAnimationFrame(fnAnimate);
    renderer.render(scene, camera);
    controls.update();
}

window.onmessage = function (e) {
    fnAddObject(e.data.objectDef, scene, defaultMaterial);
    fnSetup();
};
let container = document.createElement('div');
document.body.appendChild(container);

// let camera = new THREE.PerspectiveCamera(45, window.innerWidth / window.innerHeight, 0.1, 10000);
const camera = new THREE.OrthographicCamera( -1, 1, 1, -1, 0.1, 1000 );

let renderer = new THREE.WebGLRenderer({antialias: true});
// let renderer = new THREE.SVGRenderer();
renderer.setPixelRatio(window.devicePixelRatio);
renderer.setSize(window.innerWidth, window.innerHeight);
renderer.outputEncoding = THREE.sRGBEncoding;
container.appendChild(renderer.domElement);

const pmremGenerator = new THREE.PMREMGenerator(renderer);

let scene = new THREE.Scene();
scene.background = new THREE.Color(0xffffff);
scene.environment = pmremGenerator.fromScene(new THREE.RoomEnvironment()).texture;

let controls = new THREE.OrbitControls(camera, renderer.domElement);
controls.autoRotateSpeed = 10.0;
controls.zoomSpeed = 2.0;
controls.autoRotate = false;

const material = new THREE.MeshBasicMaterial({
    color: 0xeeeeee,
    polygonOffset: true,
    polygonOffsetFactor: 1,
    polygonOffsetUnits: 0
});
const lineMaterial = new THREE.LineBasicMaterial({
    color: 0x000000,
});

const fnAdd = function (meshDefs) {

    const model = new THREE.Group();
    scene.add(model);

    for (let meshDef of meshDefs) {

        const vertices = new Float32Array(meshDef)
        const geometry = new THREE.BufferGeometry();
        geometry.setAttribute('position', new THREE.BufferAttribute(vertices, 3));

        const mesh = new THREE.Mesh(geometry, material);
        model.add(mesh);

        const edges = new THREE.EdgesGeometry(geometry, 90);
        const line = new THREE.LineSegments(edges, lineMaterial);
        model.add(line);

    }

    const bbox = new THREE.Box3().setFromObject(model);
    const size = bbox.getSize(new THREE.Vector3());
    const radius = Math.max(size.x, Math.max(size.y, size.z));

    //

    let ratio = window.innerHeight / window.innerWidth

    camera.left = -radius * 1.4;
    camera.right = radius * 1.4;
    camera.top = radius * 1.4 * ratio;
    camera.bottom = -radius * 1.4 * ratio;

    controls.target0.copy(bbox.getCenter(new THREE.Vector3()));
    controls.position0.set(1, 1, 1).multiplyScalar(radius).add(controls.target0);
    controls.reset();

    // let axesHelper = new THREE.AxesHelper(radius / 2.0);
    // scene.add(axesHelper);

    fnAnimate();

}

//

const fnAnimate = function () {
    requestAnimationFrame(fnAnimate);
    renderer.render(scene, camera);
    controls.update();
}

window.onmessage = function (e) {
    fnAdd(e.data);
};
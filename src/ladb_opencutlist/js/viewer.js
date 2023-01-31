let container = document.createElement('div');
document.body.appendChild(container);

let camera = new THREE.PerspectiveCamera(45, window.innerWidth / window.innerHeight, 1, 10000);
camera.position.set(0, 0, 50);

let renderer = new THREE.WebGLRenderer({antialias: true});
// renderer.setPixelRatio(window.devicePixelRatio);
renderer.setSize(window.innerWidth, window.innerHeight);
renderer.outputEncoding = THREE.sRGBEncoding;
container.appendChild(renderer.domElement);

const pmremGenerator = new THREE.PMREMGenerator(renderer);

let scene = new THREE.Scene();
scene.background = new THREE.Color(0xffffff);
scene.environment = pmremGenerator.fromScene(new THREE.RoomEnvironment()).texture;

let axesHelper = new THREE.AxesHelper(1);
scene.add(axesHelper);

let controls = new THREE.OrbitControls(camera, renderer.domElement);
controls.autoRotateSpeed = 10.0;
controls.zoomSpeed = 2.0;
controls.autoRotate = !controls.autoRotate;

//

const group = new THREE.Group();
scene.add(group);

const material = new THREE.MeshBasicMaterial({
    color: 0xffff00,
    polygonOffset: true,
    polygonOffsetFactor: 1,
    polygonOffsetUnits: 0
});
const lineMaterial = new THREE.LineBasicMaterial({
    color: 0x000000
});

const fnAdd = function (meshDefs) {
    for (let meshDef of meshDefs) {

        const vertices = new Float32Array(meshDef)
        const geometry = new THREE.BufferGeometry();
        geometry.setAttribute('position', new THREE.BufferAttribute(vertices, 3));

        const mesh = new THREE.Mesh(geometry, material);
        group.add(mesh);

        const edges = new THREE.EdgesGeometry(geometry);
        const line = new THREE.LineSegments(edges, lineMaterial);
        group.add(line);

    }

    const bbox = new THREE.Box3().setFromObject(group);
    const size = bbox.getSize(new THREE.Vector3());
    const radius = Math.max(size.x, Math.max(size.y, size.z));

    controls.target0.copy(bbox.getCenter(new THREE.Vector3()));
    controls.position0.set(0, 0, 2).multiplyScalar(radius).add(controls.target0);
    controls.reset();

}

//

const fnAnimate = function () {
    requestAnimationFrame(fnAnimate);
    renderer.render(scene, camera);
    controls.update();
}
fnAnimate();

window.onmessage = function (e) {
    fnAdd(e.data);
};
/* eslint-disable no-new */
import { AnimationPropertiesOverride, ArcRotateCamera, Color3, DirectionalLight, EnvironmentHelper, FreeCamera, HemisphericLight, MeshBuilder, PolygonMeshBuilder, Quaternion, Scene, SceneLoader, ShadowGenerator, StandardMaterial, Vector2, Vector3, WebXRAnchorSystem, WebXRBackgroundRemover, WebXRHitTest, WebXRPlaneDetector, WebXRState } from '@babylonjs/core'
import { GlobalInstance } from './instance'

export async function createVRScene() {
  const engine = GlobalInstance.engine
  const scene = new Scene(engine)

  // Add a basic light
  new HemisphericLight('light1', new Vector3(0, 2, 0), scene)

  // Add a camera for the non-VR view in browser
  const camera = new ArcRotateCamera('Camera', -(Math.PI / 4) * 3, Math.PI / 4, 10, new Vector3(0, 0, 0), scene)
  camera.attachControl(true)

  // Add a sphere to have something to look at
  const sphereD = 1.0
  const sphere = MeshBuilder.CreateSphere('xSphere', { segments: 16, diameter: sphereD }, scene)
  sphere.position.x = 0
  sphere.position.y = sphereD * 2
  sphere.position.z = 0
  const rMat = new StandardMaterial('matR', scene)
  rMat.diffuseColor = new Color3(1.0, 0, 0)
  sphere.material = rMat

  // Create a default environment (skybox, ground mesh, etc)
  const envHelper = new EnvironmentHelper({
    skyboxSize: 30,
    groundColor: new Color3(0.5, 0.5, 0.5),
  }, scene)

  // Setup default WebXR experience
  // Use the enviroment floor to enable teleportation
  await scene.createDefaultXRExperienceAsync({
    floorMeshes: [envHelper.ground],
    optionalFeatures: true,
  })

  return scene
}

export async function createARScene() {
  const { engine, canvas } = GlobalInstance

  const scene = new Scene(engine)
  // const light = new HemisphericLight('light1', new Vector3(0, 1, 0), scene)
  // light.intensity = 0.7
  // const sphere = MeshBuilder.CreateSphere('sphere1', { segments: 16, diameter: 2 }, scene)
  // sphere.position.y = 2
  // sphere.position.z = 5

  // await scene.createDefaultXRExperienceAsync({
  //   // ask for an ar-session
  //   uiOptions: {
  //     sessionMode: 'immersive-ar',
  //   },
  //   optionalFeatures: true,
  // })

  // This creates and positions a free camera (non-mesh)
  const camera = new FreeCamera('camera1', new Vector3(0, 1, -5), scene)
  // This targets the camera to scene origin
  camera.setTarget(Vector3.Zero())
  // This attaches the camera to the canvas
  camera.attachControl(canvas, true)

  // This creates a light, aiming 0,1,0 - to the sky (non-mesh)
  const light = new HemisphericLight('light', new Vector3(0, 1, 0), scene)
  // Default intensity is 1. Let's dim the light a small amount
  light.intensity = 0.7

  const dirLight = new DirectionalLight('light', new Vector3(0, -1, -0.5), scene)
  dirLight.position = new Vector3(0, 5, -5)

  const shadowGenerator = new ShadowGenerator(1024, dirLight)
  shadowGenerator.useBlurExponentialShadowMap = true
  shadowGenerator.blurKernel = 32

  const model = await SceneLoader.ImportMeshAsync('', 'https://playground.babylonjs.com/scenes/', 'dummy3.babylon', scene)

  const xr = await scene.createDefaultXRExperienceAsync({
    uiOptions: {
      sessionMode: 'immersive-ar',
      referenceSpaceType: 'local-floor',
    },
    optionalFeatures: true,
  })

  const fm = xr.baseExperience.featuresManager

  const xrTest = fm.enableFeature(WebXRHitTest.Name, 'latest')
  const xrPlanes = fm.enableFeature(WebXRPlaneDetector.Name, 'latest')
  const anchors = fm.enableFeature(WebXRAnchorSystem.Name, 'latest')

  const xrBackgroundRemover = fm.enableFeature(WebXRBackgroundRemover.Name)

  const b = model.meshes[0]// CylinderBuilder.CreateCylinder('cylinder', { diameterBottom: 0.2, diameterTop: 0.4, height: 0.5 });
  b.rotationQuaternion = new Quaternion()
  // b.isVisible = false;
  shadowGenerator.addShadowCaster(b, true)

  const marker = MeshBuilder.CreateTorus('marker', { diameter: 0.15, thickness: 0.05 })
  marker.isVisible = false
  marker.rotationQuaternion = new Quaternion()

  const skeleton = model.skeletons[0]

  // ROBOT
  skeleton.animationPropertiesOverride = new AnimationPropertiesOverride()
  skeleton.animationPropertiesOverride.enableBlending = true
  skeleton.animationPropertiesOverride.blendingSpeed = 0.05
  skeleton.animationPropertiesOverride.loopMode = 1

  const idleRange = skeleton.getAnimationRange('YBot_Idle')
  const walkRange = skeleton.getAnimationRange('YBot_Walk')
  const runRange = skeleton.getAnimationRange('YBot_Run')
  const leftRange = skeleton.getAnimationRange('YBot_LeftStrafeWalk')
  const rightRange = skeleton.getAnimationRange('YBot_RightStrafeWalk')
  scene.beginAnimation(skeleton, idleRange.from, idleRange.to, true)

  let hitTest

  b.isVisible = false

  xrTest.onHitTestResultObservable.add((results) => {
    if (results.length) {
      marker.isVisible = true
      hitTest = results[0]
      hitTest.transformationMatrix.decompose(undefined, b.rotationQuaternion, b.position)
      hitTest.transformationMatrix.decompose(undefined, marker.rotationQuaternion, marker.position)
    }
    else {
      marker.isVisible = false
      hitTest = undefined
    }
  })
  const mat1 = new StandardMaterial('1', scene)
  mat1.diffuseColor = Color3.Red()
  const mat2 = new StandardMaterial('1', scene)
  mat2.diffuseColor = Color3.Blue()

  if (anchors) {
    console.log('anchors attached')
    anchors.onAnchorAddedObservable.add((anchor) => {
      console.log('attaching', anchor)
      b.isVisible = true
      anchor.attachedNode = b.clone('mensch')
      anchor.attachedNode.skeleton = skeleton.clone('skelet')
      shadowGenerator.addShadowCaster(anchor.attachedNode, true)
      scene.beginAnimation(anchor.attachedNode.skeleton, idleRange.from, idleRange.to, true)
      b.isVisible = false
    })

    anchors.onAnchorRemovedObservable.add((anchor) => {
      console.log('disposing', anchor)
      if (anchor) {
        anchor.attachedNode.isVisible = false
        anchor.attachedNode.dispose()
      }
    })
  }

  scene.onPointerDown = (evt, pickInfo) => {
    if (hitTest && anchors && xr.baseExperience.state === WebXRState.IN_XR)
      anchors.addAnchorPointUsingHitTestResultAsync(hitTest)
  }

  const planes = []

  xrPlanes.onPlaneAddedObservable.add((plane) => {
    plane.polygonDefinition.push(plane.polygonDefinition[0])
    const polygon_triangulation = new PolygonMeshBuilder('name', plane.polygonDefinition.map(p => new Vector2(p.x, p.z)), scene)
    const polygon = polygon_triangulation.build(false, 0.01)
    plane.mesh = polygon // BABYLON.TubeBuilder.CreateTube("tube", { path: plane.polygonDefinition, radius: 0.02, sideOrientation: BABYLON.Mesh.FRONTSIDE, updatable: true }, scene);
    // }
    planes[plane.id] = (plane.mesh)
    const mat = new StandardMaterial('mat', scene)
    mat.alpha = 0.5
    mat.diffuseColor = Color3.Random()
    polygon.createNormals()
    // polygon.receiveShadows = true;
    plane.mesh.material = mat

    plane.mesh.rotationQuaternion = new Quaternion()
    plane.transformationMatrix.decompose(plane.mesh.scaling, plane.mesh.rotationQuaternion, plane.mesh.position)
  })

  xrPlanes.onPlaneUpdatedObservable.add((plane) => {
    let mat
    if (plane.mesh) {
      mat = plane.mesh.material
      plane.mesh.dispose(false, false)
    }
    const some = plane.polygonDefinition.some(p => !p)
    if (some)
      return

    plane.polygonDefinition.push(plane.polygonDefinition[0])
    const polygon_triangulation = new PolygonMeshBuilder('name', plane.polygonDefinition.map(p => new Vector2(p.x, p.z)), scene)
    const polygon = polygon_triangulation.build(false, 0.01)
    polygon.createNormals()
    plane.mesh = polygon// TubeBuilder.CreateTube("tube", { path: plane.polygonDefinition, radius: 0.02, sideOrientation: Mesh.FRONTSIDE, updatable: true }, scene);
    // }
    planes[plane.id] = (plane.mesh)
    plane.mesh.material = mat
    plane.mesh.rotationQuaternion = new Quaternion()
    plane.transformationMatrix.decompose(plane.mesh.scaling, plane.mesh.rotationQuaternion, plane.mesh.position)
    plane.mesh.receiveShadows = true
  })

  xrPlanes.onPlaneRemovedObservable.add((plane) => {
    if (plane && planes[plane.id])
      planes[plane.id].dispose()
  })

  xr.baseExperience.sessionManager.onXRSessionInit.add(() => {
    planes.forEach(plane => plane.dispose())
    while (planes.pop()) { }
  })

  return scene
}

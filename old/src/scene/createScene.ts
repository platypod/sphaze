import { Engine } from "@babylonjs/core/Engines/engine";
import { Scene } from "@babylonjs/core/scene";
import { UniversalCamera } from "@babylonjs/core/Cameras/universalCamera";
import { HemisphericLight } from "@babylonjs/core/Lights/hemisphericLight";
import { Vector3 } from "@babylonjs/core/Maths/math.vector";
import { Color3 } from "@babylonjs/core/Maths/math.color";
import { MeshBuilder } from "@babylonjs/core/Meshes/meshBuilder";
import { Mesh } from "@babylonjs/core/Meshes/mesh";
import { StandardMaterial } from "@babylonjs/core/Materials/standardMaterial";
import { PlayerController } from "./playerController";
import { buildMazeWalls } from "./mazeMesh";
import { createGrassTexture } from "./textures";

export const MAZE_SPHERE_RADIUS = 20;
const EYE_HEIGHT = 1; // player stands this far in from the shell
export const PLAYER_RADIUS = MAZE_SPHERE_RADIUS - EYE_HEIGHT;

export function createScene(canvas: HTMLCanvasElement): {
  engine: Engine;
  scene: Scene;
  camera: UniversalCamera;
  player: PlayerController;
  mazeWalls: Mesh[];
} {
  const engine = new Engine(canvas, true);
  const scene = new Scene(engine);

  const light = new HemisphericLight("light", new Vector3(0, 1, 0), scene);
  light.intensity = 0.5;

  // Rendered from the inside: BACKSIDE flips winding so the sphere's interior
  // faces are the ones that get drawn instead of the (normally outward-facing) exterior.
  const mazeSphere = MeshBuilder.CreateSphere(
    "mazeSphere",
    { diameter: MAZE_SPHERE_RADIUS * 2, segments: 32, sideOrientation: Mesh.BACKSIDE },
    scene,
  );
  const material = new StandardMaterial("mazeSphereMaterial", scene);
  // Neutral tint so the grass texture's own green shows through — mostly
  // self-lit (low diffuse, soft emissive) so it stays evenly lit regardless
  // of the hemispheric light's direction.
  material.diffuseColor = new Color3(0.3, 0.3, 0.3);
  material.emissiveColor = new Color3(0.4, 0.4, 0.4);
  material.backFaceCulling = false;
  material.specularColor = Color3.Black();

  const grass = createGrassTexture(scene, "mazeSphereGrass");
  grass.uScale = 48;
  grass.vScale = 24;
  material.diffuseTexture = grass;
  material.emissiveTexture = grass;

  mazeSphere.material = material;

  const mazeWalls = buildMazeWalls(scene, MAZE_SPHERE_RADIUS);

  const sphereCenter = Vector3.Zero();
  const startPosition = new Vector3(0, -PLAYER_RADIUS, 0);
  const startForward = new Vector3(0, 0, 1);
  const player = new PlayerController(startPosition, startForward, sphereCenter, PLAYER_RADIUS, mazeWalls);

  // Position/rotation are fully driven by PlayerController each frame instead
  // of Babylon's built-in camera inputs, since "up" has to track the local
  // sphere normal rather than stay fixed to a world axis.
  const camera = new UniversalCamera("playerCamera", startPosition.clone(), scene);
  camera.minZ = 0.01;

  return { engine, scene, camera, player, mazeWalls };
}

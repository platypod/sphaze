import type { Scene } from "@babylonjs/core/scene";
import { Mesh } from "@babylonjs/core/Meshes/mesh";
import { VertexData } from "@babylonjs/core/Meshes/mesh.vertexData";
import { StandardMaterial } from "@babylonjs/core/Materials/standardMaterial";
import type { Texture } from "@babylonjs/core/Materials/Textures/texture";
import { Color3 } from "@babylonjs/core/Maths/math.color";
import { Vector3 } from "@babylonjs/core/Maths/math.vector";
import { phiTangentAt, sphericalToCartesian, thetaTangentAt } from "./sphereMath";
import { animateCircuitPulses, createCircuitStoneTexture } from "./textures";
import { generateMaze, isOpen, MAZE_COLS, MAZE_ROWS, type MazeNode } from "../maze/mazeGenerator";

const WALL_HEIGHT = 1.5;
const WALL_THICKNESS = 0.15;

function thetaOfRow(row: number): number {
  return (row / MAZE_ROWS) * Math.PI;
}
function phiOfCol(col: number): number {
  return (col / MAZE_COLS) * Math.PI * 2;
}

interface WallEdge {
  thetaA: number;
  phiA: number;
  thetaB: number;
  phiB: number;
  /** Unit tangent along the boundary curve at a given point on it. */
  tangentAt: (theta: number, phi: number) => Vector3;
}

// Dim but saturated — reads as neon glow rather than either a harsh
// full-brightness neon or a washed-out grey. Each wall gets one of these at
// random rather than a single uniform color.
function createWallMaterials(scene: Scene): StandardMaterial[] {
  const palette: Color3[] = [
    new Color3(0.02, 0.1, 0.35), // blue
    new Color3(0.02, 0.32, 0.08), // green
    new Color3(0.32, 0.03, 0.03), // red
  ];
  const pulseTextures: Texture[] = [];
  const materials = palette.map((color, index) => {
    const material = new StandardMaterial(`mazeWallMaterial${index}`, scene);
    // The stone base carries its own dim gray, unrelated to the wall's
    // color — that color lives entirely in the glowing circuit dashes.
    material.diffuseColor = new Color3(1, 1, 1);
    material.emissiveColor = new Color3(0.6, 0.6, 0.6);
    material.specularColor = Color3.Black();
    material.backFaceCulling = false;

    const circuitStone = createCircuitStoneTexture(scene, `mazeWallCircuit${index}`, color);
    circuitStone.uScale = 2;
    material.diffuseTexture = circuitStone;
    material.emissiveTexture = circuitStone;
    pulseTextures.push(circuitStone);

    return material;
  });

  animateCircuitPulses(scene, pulseTextures);
  return materials;
}

function pickRandomMaterial(materials: readonly StandardMaterial[]): StandardMaterial {
  const material = materials[Math.floor(Math.random() * materials.length)];
  if (!material) {
    throw new Error("materials must not be empty");
  }
  return material;
}

/**
 * Builds one wall as a curvature-following wedge rather than a box: the top
 * face (closer to the sphere's center) is genuinely smaller than the base
 * (at the shell), and the side faces incline to match, because every corner
 * is placed via real spherical coordinates at its own radius instead of
 * offsetting a single "center" point by a flat height vector.
 */
function buildWallMesh(scene: Scene, material: StandardMaterial, sphereRadius: number, edge: WallEdge): Mesh {
  const radiusTop = sphereRadius - WALL_HEIGHT;

  const corner = (radius: number, theta: number, phi: number, side: number): Vector3 => {
    const point = sphericalToCartesian(radius, theta, phi);
    // Vector3.normalize() mutates in place and returns `this`, so this must
    // not touch `point` itself — it's still needed at full radius below.
    const radial = point.scale(1 / radius);
    const tangent = edge.tangentAt(theta, phi);
    const right = Vector3.Cross(radial, tangent).normalize();
    return point.add(right.scale(side * (WALL_THICKNESS / 2)));
  };

  // 0-3: base corners (A-left, A-right, B-right, B-left), 4-7: same order at the top.
  const v = [
    corner(sphereRadius, edge.thetaA, edge.phiA, -1),
    corner(sphereRadius, edge.thetaA, edge.phiA, 1),
    corner(sphereRadius, edge.thetaB, edge.phiB, 1),
    corner(sphereRadius, edge.thetaB, edge.phiB, -1),
    corner(radiusTop, edge.thetaA, edge.phiA, -1),
    corner(radiusTop, edge.thetaA, edge.phiA, 1),
    corner(radiusTop, edge.thetaB, edge.phiB, 1),
    corner(radiusTop, edge.thetaB, edge.phiB, -1),
  ];

  const positions = v.flatMap((p) => [p.x, p.y, p.z]);
  const indices = [
    0, 1, 2, 0, 2, 3, // base
    4, 6, 5, 4, 7, 6, // top
    0, 3, 7, 0, 7, 4, // side A→B, left
    1, 5, 6, 1, 6, 2, // side A→B, right
    0, 4, 5, 0, 5, 1, // end cap at A
    3, 2, 6, 3, 6, 7, // end cap at B
  ];
  // Rough unwrap for the gradient texture — u along the wall's length (A to
  // B, unused since the gradient is constant across it), v along its height
  // (base to top, 0 to 1) which is what the gradient actually reads.
  const uvs = [0, 0, 0, 0, 1, 0, 1, 0, 0, 1, 0, 1, 1, 1, 1, 1];
  const normals: number[] = [];
  VertexData.ComputeNormals(positions, indices, normals);

  const vertexData = new VertexData();
  vertexData.positions = positions;
  vertexData.indices = indices;
  vertexData.normals = normals;
  vertexData.uvs = uvs;

  const mesh = new Mesh("mazeWall", scene);
  vertexData.applyToMesh(mesh);
  mesh.material = material;
  return mesh;
}

/**
 * Builds one wall per closed boundary of a freshly generated maze on the
 * sphere's lat/long grid. The maze itself (which boundaries are open) is
 * pure logic in ../maze/mazeGenerator — this only turns it into geometry.
 */
export function buildMazeWalls(scene: Scene, sphereRadius: number): Mesh[] {
  const maze = generateMaze();
  const materials = createWallMaterials(scene);

  const walls: Mesh[] = [];

  const addWallIfClosed = (a: MazeNode, b: MazeNode, edge: WallEdge): void => {
    if (!isOpen(maze, a, b)) {
      walls.push(buildWallMesh(scene, pickRandomMaterial(materials), sphereRadius, edge));
    }
  };

  // Vertical boundaries: between (row,col) and (row,col+1) within each inner ring.
  for (let row = 1; row <= MAZE_ROWS - 2; row++) {
    for (let col = 0; col < MAZE_COLS; col++) {
      const phiBoundary = phiOfCol(col + 1);
      addWallIfClosed(
        { kind: "ring", row, col },
        { kind: "ring", row, col: (col + 1) % MAZE_COLS },
        {
          thetaA: thetaOfRow(row),
          phiA: phiBoundary,
          thetaB: thetaOfRow(row + 1),
          phiB: phiBoundary,
          tangentAt: thetaTangentAt,
        },
      );
    }
  }

  // Horizontal boundaries: between adjacent inner rings.
  for (let row = 1; row < MAZE_ROWS - 2; row++) {
    const thetaBoundary = thetaOfRow(row + 1);
    for (let col = 0; col < MAZE_COLS; col++) {
      addWallIfClosed({ kind: "ring", row, col }, { kind: "ring", row: row + 1, col }, {
        thetaA: thetaBoundary,
        phiA: phiOfCol(col),
        thetaB: thetaBoundary,
        phiB: phiOfCol(col + 1),
        tangentAt: (_theta, phi) => phiTangentAt(phi),
      });
    }
  }

  // Pole boundaries: between each pole's merged node and its adjacent ring.
  for (const pole of ["north", "south"] as const) {
    const row = pole === "north" ? 1 : MAZE_ROWS - 2;
    const thetaBoundary = pole === "north" ? thetaOfRow(1) : thetaOfRow(MAZE_ROWS - 1);
    for (let col = 0; col < MAZE_COLS; col++) {
      addWallIfClosed({ kind: "pole", pole }, { kind: "ring", row, col }, {
        thetaA: thetaBoundary,
        phiA: phiOfCol(col),
        thetaB: thetaBoundary,
        phiB: phiOfCol(col + 1),
        tangentAt: (_theta, phi) => phiTangentAt(phi),
      });
    }
  }

  return walls;
}

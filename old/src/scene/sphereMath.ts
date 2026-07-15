import { Vector3 } from "@babylonjs/core/Maths/math.vector";

/**
 * Local "up" for a point standing on the sphere's interior surface: the
 * direction from that point back toward the sphere's center. Will anchor the
 * player camera's orientation as they move across the maze.
 */
export function upVectorAt(pointOnSphere: Vector3, sphereCenter: Vector3): Vector3 {
  return sphereCenter.subtract(pointOnSphere).normalize();
}

/**
 * Rotates `vector` by `angle` radians around `axis` (Rodrigues' rotation
 * formula). Used to turn the player's forward direction around their local
 * up axis without needing a quaternion for a single-axis rotation.
 */
export function rotateAroundAxis(vector: Vector3, axis: Vector3, angle: number): Vector3 {
  const cos = Math.cos(angle);
  const sin = Math.sin(angle);
  const cross = Vector3.Cross(axis, vector);
  const dot = Vector3.Dot(axis, vector);
  return vector.scale(cos).add(cross.scale(sin)).add(axis.scale(dot * (1 - cos)));
}

/**
 * Converts spherical coordinates — theta: polar angle from +Y, 0 at the
 * north pole, pi at the south pole; phi: azimuth around Y — to a Cartesian
 * point on a sphere of the given radius centered at the world origin. Used
 * to lay the maze grid out on the sphere's surface.
 */
export function sphericalToCartesian(radius: number, theta: number, phi: number): Vector3 {
  return new Vector3(
    radius * Math.sin(theta) * Math.cos(phi),
    radius * Math.cos(theta),
    radius * Math.sin(theta) * Math.sin(phi),
  );
}

/** Unit tangent in the direction of increasing theta at a given spherical position. */
export function thetaTangentAt(theta: number, phi: number): Vector3 {
  return new Vector3(Math.cos(theta) * Math.cos(phi), -Math.sin(theta), Math.cos(theta) * Math.sin(phi));
}

/** Unit tangent in the direction of increasing phi (independent of theta). */
export function phiTangentAt(phi: number): Vector3 {
  return new Vector3(-Math.sin(phi), 0, Math.cos(phi));
}

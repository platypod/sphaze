import { describe, expect, it } from "vitest";
import { Vector3 } from "@babylonjs/core/Maths/math.vector";
import {
  phiTangentAt,
  rotateAroundAxis,
  sphericalToCartesian,
  thetaTangentAt,
  upVectorAt,
} from "./sphereMath";

describe("upVectorAt", () => {
  it("points from the surface back toward the sphere center", () => {
    const center = Vector3.Zero();
    const pointOnSphere = new Vector3(10, 0, 0);

    const up = upVectorAt(pointOnSphere, center);

    expect(up.x).toBeCloseTo(-1);
    expect(up.y).toBeCloseTo(0);
    expect(up.z).toBeCloseTo(0);
  });

  it("returns a unit vector regardless of sphere radius", () => {
    const center = Vector3.Zero();
    const pointOnSphere = new Vector3(0, 0, 250);

    const up = upVectorAt(pointOnSphere, center);

    expect(up.length()).toBeCloseTo(1);
  });
});

describe("rotateAroundAxis", () => {
  it("rotates a vector 90 degrees around the Z axis", () => {
    const rotated = rotateAroundAxis(new Vector3(1, 0, 0), new Vector3(0, 0, 1), Math.PI / 2);

    expect(rotated.x).toBeCloseTo(0);
    expect(rotated.y).toBeCloseTo(1);
    expect(rotated.z).toBeCloseTo(0);
  });

  it("leaves the vector unchanged for a zero-angle rotation", () => {
    const original = new Vector3(3, -2, 5);

    const rotated = rotateAroundAxis(original, new Vector3(0, 1, 0), 0);

    expect(rotated.x).toBeCloseTo(original.x);
    expect(rotated.y).toBeCloseTo(original.y);
    expect(rotated.z).toBeCloseTo(original.z);
  });

  it("preserves vector length", () => {
    const rotated = rotateAroundAxis(new Vector3(2, 3, -1), new Vector3(0, 1, 0), 1.234);

    expect(rotated.length()).toBeCloseTo(new Vector3(2, 3, -1).length());
  });
});

describe("sphericalToCartesian", () => {
  it("places theta=0 at the north pole regardless of phi", () => {
    const point = sphericalToCartesian(10, 0, 2.7);

    expect(point.x).toBeCloseTo(0);
    expect(point.y).toBeCloseTo(10);
    expect(point.z).toBeCloseTo(0);
  });

  it("places theta=pi at the south pole regardless of phi", () => {
    const point = sphericalToCartesian(10, Math.PI, 1.1);

    expect(point.x).toBeCloseTo(0);
    expect(point.y).toBeCloseTo(-10);
    expect(point.z).toBeCloseTo(0);
  });

  it("places the equator (theta=pi/2, phi=0) on the +X axis", () => {
    const point = sphericalToCartesian(10, Math.PI / 2, 0);

    expect(point.x).toBeCloseTo(10);
    expect(point.y).toBeCloseTo(0);
    expect(point.z).toBeCloseTo(0);
  });
});

describe("thetaTangentAt / phiTangentAt", () => {
  it("are unit length and mutually perpendicular, and perpendicular to the radial direction", () => {
    const theta = 1.0;
    const phi = 2.3;
    const radial = sphericalToCartesian(1, theta, phi);
    const thetaTangent = thetaTangentAt(theta, phi);
    const phiTangent = phiTangentAt(phi);

    expect(thetaTangent.length()).toBeCloseTo(1);
    expect(phiTangent.length()).toBeCloseTo(1);
    expect(Vector3.Dot(thetaTangent, phiTangent)).toBeCloseTo(0);
    expect(Vector3.Dot(thetaTangent, radial)).toBeCloseTo(0);
    expect(Vector3.Dot(phiTangent, radial)).toBeCloseTo(0);
  });
});

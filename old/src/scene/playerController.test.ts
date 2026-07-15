import { describe, expect, it } from "vitest";
import { NullEngine } from "@babylonjs/core/Engines/nullEngine";
import { Scene } from "@babylonjs/core/scene";
import { UniversalCamera } from "@babylonjs/core/Cameras/universalCamera";
import { Vector3 } from "@babylonjs/core/Maths/math.vector";
import { MeshBuilder } from "@babylonjs/core/Meshes/meshBuilder";
import { createIdlePlayerInput, PlayerController } from "./playerController";

// NullEngine runs Babylon's real math/scene-graph code with no WebGL/DOM, so
// this exercises the same camera-mutation logic the game uses, just without
// a browser round-trip for every check.
function setupTest(startPosition: Vector3, startForward: Vector3, radius: number, walls: ReturnType<typeof MeshBuilder.CreateBox>[] = []) {
  const engine = new NullEngine();
  const scene = new Scene(engine);
  const camera = new UniversalCamera("camera", startPosition.clone(), scene);
  const player = new PlayerController(startPosition, startForward, Vector3.Zero(), radius, walls);
  return { camera, player, scene };
}

describe("PlayerController walking", () => {
  it("keeps the player at a constant distance from the center while walking (gravity-stick)", () => {
    const { camera, player } = setupTest(new Vector3(0, -10, 0), new Vector3(0, 0, 1), 10);
    const input = { ...createIdlePlayerInput(), forward: true };

    let maxDrift = 0;
    for (let i = 0; i < 300; i++) {
      player.update(1 / 60, input, camera);
      maxDrift = Math.max(maxDrift, Math.abs(player.position.length() - 10));
    }

    expect(maxDrift).toBeLessThan(1e-9);
  });

  it("backward undoes forward motion (opposite tangential direction)", () => {
    const { camera, player } = setupTest(new Vector3(0, -10, 0), new Vector3(0, 0, 1), 10);
    const forwardInput = { ...createIdlePlayerInput(), forward: true };
    for (let i = 0; i < 60; i++) {
      player.update(1 / 60, forwardInput, camera);
    }
    const afterForward = player.position.clone();
    expect(afterForward.subtract(new Vector3(0, -10, 0)).length()).toBeGreaterThan(1);

    const backwardInput = { ...createIdlePlayerInput(), backward: true };
    for (let i = 0; i < 60; i++) {
      player.update(1 / 60, backwardInput, camera);
    }

    expect(player.position.subtract(new Vector3(0, -10, 0)).length()).toBeLessThan(0.5);
  });

  it("D+Shift turns the camera without moving the player", () => {
    const { camera, player } = setupTest(new Vector3(0, -10, 0), new Vector3(0, 0, 1), 10);
    const idle = createIdlePlayerInput();
    player.update(1 / 60, idle, camera);
    const rotationBefore = camera.rotation.clone();

    const turnInput = { ...createIdlePlayerInput(), right: true, shift: true };
    for (let i = 0; i < 30; i++) {
      player.update(1 / 60, turnInput, camera);
    }

    expect(camera.rotation.equalsWithEpsilon(rotationBefore)).toBe(false);
    expect(player.position.equalsWithEpsilon(new Vector3(0, -10, 0))).toBe(true);
  });

  it("D without Shift strafes sideways (moves the player) instead of turning", () => {
    const { camera, player } = setupTest(new Vector3(0, -10, 0), new Vector3(0, 0, 1), 10);
    const strafeInput = { ...createIdlePlayerInput(), right: true };

    let maxDrift = 0;
    for (let i = 0; i < 60; i++) {
      player.update(1 / 60, strafeInput, camera);
      maxDrift = Math.max(maxDrift, Math.abs(player.position.length() - 10));
    }

    expect(player.position.equalsWithEpsilon(new Vector3(0, -10, 0))).toBe(false);
    expect(maxDrift).toBeLessThan(1e-9); // still gravity-stuck to the shell while strafing
  });

  it("Q and D strafe in opposite directions", () => {
    const { camera: cameraA, player: playerA } = setupTest(new Vector3(0, -10, 0), new Vector3(0, 0, 1), 10);
    const { camera: cameraB, player: playerB } = setupTest(new Vector3(0, -10, 0), new Vector3(0, 0, 1), 10);

    const rightInput = { ...createIdlePlayerInput(), right: true };
    const leftInput = { ...createIdlePlayerInput(), left: true };
    for (let i = 0; i < 60; i++) {
      playerA.update(1 / 60, rightInput, cameraA);
      playerB.update(1 / 60, leftInput, cameraB);
    }

    expect(playerA.position.equalsWithEpsilon(playerB.position)).toBe(false);
    const spawn = new Vector3(0, -10, 0);
    const driftA = playerA.position.subtract(spawn);
    const driftB = playerB.position.subtract(spawn);
    expect(Vector3.Dot(driftA, driftB)).toBeLessThan(0); // opposite directions
  });

  it("switching Shift mid-hold stops strafing and starts turning", () => {
    const { camera, player } = setupTest(new Vector3(0, -10, 0), new Vector3(0, 0, 1), 10);
    const strafeInput = { ...createIdlePlayerInput(), right: true };
    for (let i = 0; i < 30; i++) {
      player.update(1 / 60, strafeInput, camera);
    }
    const positionAfterStrafe = player.position.clone();

    const turnInput = { ...createIdlePlayerInput(), right: true, shift: true };
    for (let i = 0; i < 30; i++) {
      player.update(1 / 60, turnInput, camera);
    }

    expect(player.position.equalsWithEpsilon(positionAfterStrafe)).toBe(true);
  });

  it("strafing alone covers less distance than walking forward alone over the same time (strafe is slower)", () => {
    const { camera: cameraForward, player: playerForward } = setupTest(new Vector3(0, -10, 0), new Vector3(0, 0, 1), 10);
    const { camera: cameraStrafe, player: playerStrafe } = setupTest(new Vector3(0, -10, 0), new Vector3(0, 0, 1), 10);

    const forwardInput = { ...createIdlePlayerInput(), forward: true };
    const strafeInput = { ...createIdlePlayerInput(), right: true };
    for (let i = 0; i < 60; i++) {
      playerForward.update(1 / 60, forwardInput, cameraForward);
      playerStrafe.update(1 / 60, strafeInput, cameraStrafe);
    }

    const spawn = new Vector3(0, -10, 0);
    const forwardDistance = playerForward.position.subtract(spawn).length();
    const strafeDistance = playerStrafe.position.subtract(spawn).length();
    expect(strafeDistance).toBeLessThan(forwardDistance);
  });

  it("does not move faster when holding forward and strafe together than forward alone (no diagonal speedup)", () => {
    const { camera: cameraForward, player: playerForward } = setupTest(new Vector3(0, -10, 0), new Vector3(0, 0, 1), 10);
    const { camera: cameraBoth, player: playerBoth } = setupTest(new Vector3(0, -10, 0), new Vector3(0, 0, 1), 10);

    const forwardInput = { ...createIdlePlayerInput(), forward: true };
    const bothInput = { ...createIdlePlayerInput(), forward: true, right: true };
    for (let i = 0; i < 60; i++) {
      playerForward.update(1 / 60, forwardInput, cameraForward);
      playerBoth.update(1 / 60, bothInput, cameraBoth);
    }

    const spawn = new Vector3(0, -10, 0);
    const forwardOnlyDistance = playerForward.position.subtract(spawn).length();
    const bothDistance = playerBoth.position.subtract(spawn).length();
    // A small epsilon for floating point/reprojection slack, not a real speedup.
    expect(bothDistance).toBeLessThanOrEqual(forwardOnlyDistance + 1e-6);
  });
});

const PITCH_BASELINE = (8 * Math.PI) / 180;

describe("PlayerController pitch (Space)", () => {
  it("rests at a slight upward tilt by default, with no input at all", () => {
    const { camera, player } = setupTest(new Vector3(0, -10, 0), new Vector3(0, 0, 1), 10);
    const idle = createIdlePlayerInput();

    for (let i = 0; i < 10; i++) {
      player.update(1 / 60, idle, camera);
    }

    expect((player as unknown as { pitch: number }).pitch).toBeCloseTo(PITCH_BASELINE, 5);
  });

  it("tilts further up toward the center while held, without moving the player", () => {
    const { camera, player } = setupTest(new Vector3(0, -10, 0), new Vector3(0, 0, 1), 10);
    const lookUpInput = { ...createIdlePlayerInput(), lookUp: true };

    for (let i = 0; i < 30; i++) {
      player.update(1 / 60, lookUpInput, camera);
    }

    expect((player as unknown as { pitch: number }).pitch).toBeGreaterThan(PITCH_BASELINE);
    expect(player.position.equalsWithEpsilon(new Vector3(0, -10, 0))).toBe(true);
  });

  it("caps pitch at 85 degrees and never moves the player regardless of how long it's held", () => {
    const { camera, player } = setupTest(new Vector3(0, -10, 0), new Vector3(0, 0, 1), 10);
    const lookUpInput = { ...createIdlePlayerInput(), lookUp: true };

    for (let i = 0; i < 600; i++) {
      player.update(1 / 60, lookUpInput, camera);
    }

    expect((player as unknown as { pitch: number }).pitch).toBeCloseTo((85 * Math.PI) / 180, 5);
    expect(player.position.equalsWithEpsilon(new Vector3(0, -10, 0))).toBe(true);
  });

  it("eases back to the baseline tilt after release, never below it", () => {
    const { camera, player } = setupTest(new Vector3(0, -10, 0), new Vector3(0, 0, 1), 10);
    const lookUpInput = { ...createIdlePlayerInput(), lookUp: true };
    for (let i = 0; i < 120; i++) {
      player.update(1 / 60, lookUpInput, camera);
    }
    expect((player as unknown as { pitch: number }).pitch).toBeGreaterThan(PITCH_BASELINE);

    const idle = createIdlePlayerInput();
    for (let i = 0; i < 300; i++) {
      player.update(1 / 60, idle, camera);
    }

    expect((player as unknown as { pitch: number }).pitch).toBeCloseTo(PITCH_BASELINE, 5);
  });

  it("holds pitch steady for the 1s hang time after release before it starts descending", () => {
    const { camera, player } = setupTest(new Vector3(0, -10, 0), new Vector3(0, 0, 1), 10);
    const lookUpInput = { ...createIdlePlayerInput(), lookUp: true };
    for (let i = 0; i < 120; i++) {
      player.update(1 / 60, lookUpInput, camera);
    }
    const pitchAtRelease = (player as unknown as { pitch: number }).pitch;

    const idle = createIdlePlayerInput();
    // Just under the 1s hang time — should not have moved yet.
    for (let i = 0; i < 60 * 0.9; i++) {
      player.update(1 / 60, idle, camera);
    }
    expect((player as unknown as { pitch: number }).pitch).toBeCloseTo(pitchAtRelease, 5);

    // Well past the hang time — should now be descending.
    for (let i = 0; i < 60 * 1; i++) {
      player.update(1 / 60, idle, camera);
    }
    expect((player as unknown as { pitch: number }).pitch).toBeLessThan(pitchAtRelease - 0.01);
  });

  it("eases in and out instead of moving at constant speed (slow start, faster middle, slow end)", () => {
    const { camera, player } = setupTest(new Vector3(0, -10, 0), new Vector3(0, 0, 1), 10);
    const lookUpInput = { ...createIdlePlayerInput(), lookUp: true };

    const pitchBeforeFirstFrame = (player as unknown as { pitch: number }).pitch;
    player.update(1 / 60, lookUpInput, camera);
    const firstFrameDelta = (player as unknown as { pitch: number }).pitch - pitchBeforeFirstFrame;

    for (let i = 0; i < 30; i++) {
      player.update(1 / 60, lookUpInput, camera);
    }
    const pitchBeforeMidFrame = (player as unknown as { pitch: number }).pitch;
    player.update(1 / 60, lookUpInput, camera);
    const midFrameDelta = (player as unknown as { pitch: number }).pitch - pitchBeforeMidFrame;

    // The very first frame's step should be much smaller than a step taken
    // once the motion is up to speed (ease-in).
    expect(firstFrameDelta).toBeLessThan(midFrameDelta * 0.5);
  });
});

describe("PlayerController mouse look", () => {
  it("moving the mouse horizontally turns the camera without moving the player", () => {
    const { camera, player } = setupTest(new Vector3(0, -10, 0), new Vector3(0, 0, 1), 10);
    player.update(1 / 60, createIdlePlayerInput(), camera);
    const rotationBefore = camera.rotation.clone();

    player.applyMouseMovement(50, 0);
    player.update(1 / 60, createIdlePlayerInput(), camera);

    expect(camera.rotation.equalsWithEpsilon(rotationBefore)).toBe(false);
    expect(player.position.equalsWithEpsilon(new Vector3(0, -10, 0))).toBe(true);
  });

  it("moving the mouse up (negative deltaY) increases pitch", () => {
    const { player } = setupTest(new Vector3(0, -10, 0), new Vector3(0, 0, 1), 10);
    const pitchBefore = (player as unknown as { pitch: number }).pitch;

    player.applyMouseMovement(0, -100);

    expect((player as unknown as { pitch: number }).pitch).toBeGreaterThan(pitchBefore);
  });

  it("moving the mouse down (positive deltaY) decreases pitch, below the baseline", () => {
    const { player } = setupTest(new Vector3(0, -10, 0), new Vector3(0, 0, 1), 10);

    player.applyMouseMovement(0, 100);

    expect((player as unknown as { pitch: number }).pitch).toBeLessThan(0);
  });

  it("clamps pitch to +/- the 85 degree limit regardless of how far the mouse moves", () => {
    const { player } = setupTest(new Vector3(0, -10, 0), new Vector3(0, 0, 1), 10);
    const limit = (85 * Math.PI) / 180;

    player.applyMouseMovement(0, -1_000_000);
    expect((player as unknown as { pitch: number }).pitch).toBeCloseTo(limit, 5);

    player.applyMouseMovement(0, 2_000_000);
    expect((player as unknown as { pitch: number }).pitch).toBeCloseTo(-limit, 5);
  });

  it("does not auto-recenter mouse-set pitch just because Space was never touched", () => {
    const { camera, player } = setupTest(new Vector3(0, -10, 0), new Vector3(0, 0, 1), 10);
    player.applyMouseMovement(0, -500);
    const pitchAfterMouse = (player as unknown as { pitch: number }).pitch;
    expect(pitchAfterMouse).toBeGreaterThan((8 * Math.PI) / 180);

    // Standing still, never touching Space or the mouse again — should not drift.
    const idle = createIdlePlayerInput();
    for (let i = 0; i < 60 * 5; i++) {
      player.update(1 / 60, idle, camera);
    }

    expect((player as unknown as { pitch: number }).pitch).toBeCloseTo(pitchAfterMouse, 5);
  });

  it("does not auto-recenter while walking if the mouse was touched recently (under the idle threshold)", () => {
    const { camera, player } = setupTest(new Vector3(0, -10, 0), new Vector3(0, 0, 1), 10);
    player.applyMouseMovement(0, -500);
    const pitchAfterMouse = (player as unknown as { pitch: number }).pitch;

    const walking = { ...createIdlePlayerInput(), forward: true };
    // Just under the 3s idle threshold.
    for (let i = 0; i < 60 * 2.9; i++) {
      player.update(1 / 60, walking, camera);
    }

    expect((player as unknown as { pitch: number }).pitch).toBeCloseTo(pitchAfterMouse, 5);
  });

  it("auto-recenters to baseline if the mouse sits idle for 3s while walking, even without touching Space", () => {
    const { camera, player } = setupTest(new Vector3(0, -10, 0), new Vector3(0, 0, 1), 10);
    player.applyMouseMovement(0, -500);
    const pitchAfterMouse = (player as unknown as { pitch: number }).pitch;

    const walking = { ...createIdlePlayerInput(), forward: true };
    for (let i = 0; i < 60 * 6; i++) {
      player.update(1 / 60, walking, camera);
    }

    expect((player as unknown as { pitch: number }).pitch).toBeCloseTo((8 * Math.PI) / 180, 5);
    expect((player as unknown as { pitch: number }).pitch).toBeLessThan(pitchAfterMouse);
  });

  it("does not auto-recenter from mouse-idle alone while standing still (not walking)", () => {
    const { camera, player } = setupTest(new Vector3(0, -10, 0), new Vector3(0, 0, 1), 10);
    player.applyMouseMovement(0, -500);
    const pitchAfterMouse = (player as unknown as { pitch: number }).pitch;

    const idle = createIdlePlayerInput();
    for (let i = 0; i < 60 * 6; i++) {
      player.update(1 / 60, idle, camera);
    }

    expect((player as unknown as { pitch: number }).pitch).toBeCloseTo(pitchAfterMouse, 5);
  });
});

describe("PlayerController collision", () => {
  it("stops the player at a wall instead of passing through it", () => {
    const engine = new NullEngine();
    const scene = new Scene(engine);
    const wall = MeshBuilder.CreateBox("wall", { width: 4, height: 4, depth: 0.5 }, scene);
    wall.position = new Vector3(0, -10, 3);

    const { camera, player } = setupTest(new Vector3(0, -10, 0), new Vector3(0, 0, 1), 10, [wall]);
    const forwardInput = { ...createIdlePlayerInput(), forward: true };

    for (let i = 0; i < 300; i++) {
      player.update(1 / 60, forwardInput, camera);
    }

    // Should have stopped short of the wall, not tunneled past z=3.
    expect(player.position.z).toBeLessThan(2.75);
    expect(player.position.z).toBeGreaterThan(0.5);
  });

  it("does not block movement when no wall is in the way", () => {
    const engine = new NullEngine();
    const scene = new Scene(engine);
    const wall = MeshBuilder.CreateBox("wall", { width: 4, height: 4, depth: 0.5 }, scene);
    wall.position = new Vector3(0, -10, -3); // behind the player, not in its path

    const { camera, player } = setupTest(new Vector3(0, -10, 0), new Vector3(0, 0, 1), 10, [wall]);
    const forwardInput = { ...createIdlePlayerInput(), forward: true };

    for (let i = 0; i < 60; i++) {
      player.update(1 / 60, forwardInput, camera);
    }

    expect(player.position.z).toBeGreaterThan(1);
  });
});

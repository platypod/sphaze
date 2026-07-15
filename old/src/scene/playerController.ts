import { Vector3 } from "@babylonjs/core/Maths/math.vector";
import type { UniversalCamera } from "@babylonjs/core/Cameras/universalCamera";
import type { AbstractMesh } from "@babylonjs/core/Meshes/abstractMesh";
import { Ray } from "@babylonjs/core/Culling/ray";
import { rotateAroundAxis, upVectorAt } from "./sphereMath";

// Forward/backward and strafe each get their own speed, both derived from one
// shared base so they stay proportional if the base is ever retuned.
const PLAYER_MOVEMENT_SPEED_GLOBAL = 6; // units/sec
const PLAYER_MOVEMENT_SPEED_FORWARD_RATIO = 1; // forward/backward: full speed
const PLAYER_MOVEMENT_SPEED_STRAFE_RATIO = 0.6; // strafe: slower, it read as too fast at full speed
const FORWARD_SPEED = PLAYER_MOVEMENT_SPEED_GLOBAL * PLAYER_MOVEMENT_SPEED_FORWARD_RATIO;
const STRAFE_SPEED = PLAYER_MOVEMENT_SPEED_GLOBAL * PLAYER_MOVEMENT_SPEED_STRAFE_RATIO;
const TURN_SPEED = Math.PI * 0.6; // rad/sec, yaw around the local up axis
const PITCH_LIMIT = (85 * Math.PI) / 180;
const PITCH_BASELINE = (8 * Math.PI) / 180; // resting pitch — always looking slightly up, never dead level
const PITCH_ACCELERATION = 3; // rad/sec^2 — eases in from rest and (via braking distance) eases out at each end
const PITCH_MAX_SPEED = 1.5; // rad/sec cap
const PITCH_HANG_TIME = 1; // seconds the pitch holds still after releasing lookUp, before descending
const MOUSE_YAW_SENSITIVITY = 0.0025; // rad per pixel of mouse movement
const MOUSE_PITCH_SENSITIVITY = 0.0025; // rad per pixel of mouse movement
const MOUSE_IDLE_RECENTER_TIME = 3; // seconds of no mouse movement (while walking) before pitch auto-recenters

export interface PlayerInput {
  left: boolean; // Q — strafes left by default, turns left while shift is held
  right: boolean; // D — strafes right by default, turns right while shift is held
  forward: boolean; // Z
  backward: boolean; // S
  lookUp: boolean; // Space (held)
  shift: boolean; // Shift (held) — switches Q/D from strafing to turning
}

export function createIdlePlayerInput(): PlayerInput {
  return { left: false, right: false, forward: false, backward: false, lookUp: false, shift: false };
}

/**
 * Player position is always pinned to the sphere's shell at a fixed radius
 * ("gravity-stick") — Z/S walk forward/backward there, Q/D strafe sideways
 * by default or turn while Shift is held (also free mouse-look via
 * applyMouseMovement). The camera rests at a slight
 * upward tilt (PITCH_BASELINE) by default. Space pitches further up toward
 * the center — simulating raising your head to see across to the far side —
 * and auto-eases back to baseline after a hang time on release. That
 * auto-tilt-and-back only engages for an active Space press/release cycle,
 * or when the mouse has sat idle for a while during walking; otherwise
 * mouse-set pitch just stays where it was left.
 */
export class PlayerController {
  position: Vector3;
  private readonly sphereCenter: Vector3;
  private readonly playerRadius: number;
  private readonly walls: readonly AbstractMesh[];
  private forward: Vector3;
  private pitch = PITCH_BASELINE;
  private pitchVelocity = 0;
  private timeSinceRelease = 0;
  // True from the moment Space is pressed until pitch has eased all the way
  // back to baseline afterward — scopes the hang-time/ease-back behavior to
  // an actual Space press instead of running it any time Space isn't held.
  private spaceCycleActive = false;
  private timeSinceMouseMove = Number.POSITIVE_INFINITY;

  constructor(
    position: Vector3,
    forward: Vector3,
    sphereCenter: Vector3,
    playerRadius: number,
    walls: readonly AbstractMesh[] = [],
  ) {
    this.position = position;
    this.sphereCenter = sphereCenter;
    this.playerRadius = playerRadius;
    this.walls = walls;
    // .normalize() mutates in place — clone first so we don't silently
    // alter the caller's vector out from under them.
    this.forward = forward.clone().normalize();
  }

  /**
   * Free mouse-look: yaw from horizontal movement (same rotation Q/D use,
   * just continuous), pitch from vertical movement, applied directly rather
   * than eased — the mouse itself is already an analog, human-paced input.
   * Composes with (and can be overridden by) Space's own eased pitch target
   * on the next update() call, since both drive the same `pitch` field.
   */
  applyMouseMovement(deltaX: number, deltaY: number): void {
    if (deltaX === 0 && deltaY === 0) {
      return;
    }
    this.timeSinceMouseMove = 0;

    const up = upVectorAt(this.position, this.sphereCenter);
    this.orthogonalizeForward(up);
    if (deltaX !== 0) {
      this.forward = rotateAroundAxis(this.forward, up, deltaX * MOUSE_YAW_SENSITIVITY);
    }
    if (deltaY !== 0) {
      this.pitch = Math.min(PITCH_LIMIT, Math.max(-PITCH_LIMIT, this.pitch - deltaY * MOUSE_PITCH_SENSITIVITY));
    }
  }

  update(deltaSeconds: number, input: PlayerInput, camera: UniversalCamera): void {
    const up = upVectorAt(this.position, this.sphereCenter);
    this.orthogonalizeForward(up);

    if (input.shift) {
      // Shift held: Q/D turn, same as before.
      if (input.left) {
        this.forward = rotateAroundAxis(this.forward, up, -TURN_SPEED * deltaSeconds);
      }
      if (input.right) {
        this.forward = rotateAroundAxis(this.forward, up, TURN_SPEED * deltaSeconds);
      }
    }

    const forwardAxis = input.forward ? 1 : input.backward ? -1 : 0;
    const strafeAxis = !input.shift && (input.left || input.right) ? (input.right ? 1 : -1) : 0;

    if (forwardAxis !== 0 || strafeAxis !== 0) {
      // Normalize the raw input axes (not the final velocity) when both are
      // held, so pressing forward+strafe together can't add up to a faster
      // diagonal than either axis alone — the classic diagonal-speed bug.
      const normalization = forwardAxis !== 0 && strafeAxis !== 0 ? Math.SQRT1_2 : 1;
      const right = Vector3.Cross(up, this.forward).normalize();
      const velocity = this.forward
        .scale(forwardAxis * FORWARD_SPEED * normalization)
        .add(right.scale(strafeAxis * STRAFE_SPEED * normalization));
      this.moveBy(velocity.scale(deltaSeconds));
    }

    this.updatePitch(deltaSeconds, input);

    const finalUp = upVectorAt(this.position, this.sphereCenter);
    const lookDirection = this.forward.scale(Math.cos(this.pitch)).add(finalUp.scale(Math.sin(this.pitch)));

    camera.position.copyFrom(this.position);
    camera.upVector.copyFrom(finalUp);
    camera.setTarget(this.position.add(lookDirection));
  }

  /**
   * The auto-tilt-and-back behavior (hang, then ease to baseline) only
   * engages for two reasons: an active Space press/release cycle, or the
   * mouse having sat idle for MOUSE_IDLE_RECENTER_TIME while walking. Any
   * other time (e.g. the mouse alone set the pitch and neither condition
   * holds), pitch just stays where it was left — free mouse-look shouldn't
   * get quietly dragged back by logic it never asked for.
   */
  private updatePitch(deltaSeconds: number, input: PlayerInput): void {
    this.timeSinceMouseMove += deltaSeconds;

    let target: number;
    if (input.lookUp) {
      this.spaceCycleActive = true;
      this.timeSinceRelease = 0;
      target = PITCH_LIMIT;
    } else if (this.spaceCycleActive) {
      this.timeSinceRelease += deltaSeconds;
      if (this.timeSinceRelease < PITCH_HANG_TIME) {
        target = this.pitch; // hold steady during the hang time
      } else {
        target = PITCH_BASELINE;
        if (Math.abs(this.pitch - PITCH_BASELINE) < 1e-4) {
          this.spaceCycleActive = false; // cycle complete, back to idle
        }
      }
    } else if (this.timeSinceMouseMove >= MOUSE_IDLE_RECENTER_TIME && (input.forward || input.backward)) {
      target = PITCH_BASELINE;
    } else {
      target = this.pitch; // no active reason to move pitch — leave it alone
    }

    this.easePitchTowards(target, deltaSeconds);
  }

  /**
   * Acceleration ramps velocity up from rest (ease-in) and the desired speed
   * is capped by how much distance is left to brake within (ease-out), so
   * motion is slow at both ends instead of constant-speed with a hard stop.
   */
  private easePitchTowards(target: number, deltaSeconds: number): void {
    const remaining = target - this.pitch;
    const distance = Math.abs(remaining);
    if (distance < 1e-4) {
      this.pitch = target;
      this.pitchVelocity = 0;
      return;
    }

    const direction = Math.sign(remaining);
    const brakingSpeed = Math.sqrt(2 * PITCH_ACCELERATION * distance);
    const desiredVelocity = direction * Math.min(PITCH_MAX_SPEED, brakingSpeed);
    const maxVelocityDelta = PITCH_ACCELERATION * deltaSeconds;
    const velocityDelta = desiredVelocity - this.pitchVelocity;
    this.pitchVelocity += Math.sign(velocityDelta) * Math.min(Math.abs(velocityDelta), maxVelocityDelta);

    this.pitch += this.pitchVelocity * deltaSeconds;
    if ((direction > 0 && this.pitch > target) || (direction < 0 && this.pitch < target)) {
      this.pitch = target;
      this.pitchVelocity = 0;
    }
  }

  /** Applies a (already speed-scaled) tangential displacement, blocked by walls, then re-pins to the shell. */
  private moveBy(displacement: Vector3): void {
    const moved = this.position.add(displacement);
    if (!this.isBlocked(this.position, moved)) {
      this.position = this.sphereCenter.add(moved.subtract(this.sphereCenter).normalize().scale(this.playerRadius));
      this.orthogonalizeForward(upVectorAt(this.position, this.sphereCenter));
    }
  }

  private orthogonalizeForward(up: Vector3): void {
    this.forward = this.forward.subtract(up.scale(Vector3.Dot(this.forward, up))).normalize();
  }

  private isBlocked(from: Vector3, to: Vector3): boolean {
    const delta = to.subtract(from);
    const distance = delta.length();
    if (distance < 1e-6) {
      return false;
    }
    const ray = new Ray(from, delta.scale(1 / distance), distance);
    return this.walls.some((wall) => ray.intersectsMesh(wall).hit);
  }
}

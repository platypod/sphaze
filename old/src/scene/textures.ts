import type { Scene } from "@babylonjs/core/scene";
import type { Color3 } from "@babylonjs/core/Maths/math.color";
import { DynamicTexture } from "@babylonjs/core/Materials/Textures/dynamicTexture";
import { Texture } from "@babylonjs/core/Materials/Textures/texture";

function toRgb(color: Color3): string {
  return `rgb(${Math.round(color.r * 255)}, ${Math.round(color.g * 255)}, ${Math.round(color.b * 255)})`;
}

/**
 * Alien turf: a muted green base with randomly placed clump blotches and
 * short blade-like strokes for texture. Kept deliberately dim/desaturated —
 * a fully-saturated grass green read as too bright against the dim walls.
 */
export function createGrassTexture(scene: Scene, name: string): DynamicTexture {
  const size = 128;
  const texture = new DynamicTexture(name, { width: size, height: size }, scene, false);
  const context = texture.getContext();

  context.fillStyle = "rgb(42, 50, 32)";
  context.fillRect(0, 0, size, size);

  for (let i = 0; i < 60; i++) {
    const x = Math.random() * size;
    const y = Math.random() * size;
    const radius = 4 + Math.random() * 9;
    const shade = 34 + Math.floor(Math.random() * 26);
    context.fillStyle = `rgb(${shade + 14}, ${shade + 26}, ${shade + 10})`;
    context.beginPath();
    context.arc(x, y, radius, 0, Math.PI * 2);
    context.fill();
  }

  for (let i = 0; i < 500; i++) {
    const x = Math.random() * size;
    const y = Math.random() * size;
    const length = 3 + Math.random() * 5;
    const shade = 40 + Math.floor(Math.random() * 45);
    context.strokeStyle = `rgb(${shade}, ${shade + 28}, ${shade})`;
    context.lineWidth = 1;
    context.beginPath();
    context.moveTo(x, y);
    context.lineTo(x + (Math.random() - 0.5) * 2, y - length);
    context.stroke();
  }

  texture.update(false);
  texture.wrapU = Texture.WRAP_ADDRESSMODE;
  texture.wrapV = Texture.WRAP_ADDRESSMODE;

  return texture;
}

const CIRCUIT_LANES = 3;
const CIRCUIT_DASH_PERIOD = 16; // must divide the texture size evenly for seamless vertical tiling/scrolling

/**
 * Stone-and-circuitry wall texture: a mottled rock base with a few vertical
 * conduits of glowing dashes in the given accent color running through it.
 * The dashes are static here — animatePulses() scrolls their V offset over
 * time to make them read as pulses of light traveling through the stone.
 */
export function createCircuitStoneTexture(scene: Scene, name: string, accent: Color3): DynamicTexture {
  const size = 128;
  const texture = new DynamicTexture(name, { width: size, height: size }, scene, false);
  const context = texture.getContext();

  context.fillStyle = "rgb(45, 45, 48)";
  context.fillRect(0, 0, size, size);

  for (let i = 0; i < 70; i++) {
    const x = Math.random() * size;
    const y = Math.random() * size;
    const radius = 3 + Math.random() * 8;
    const gray = 34 + Math.floor(Math.random() * 26);
    context.fillStyle = `rgb(${gray}, ${gray}, ${gray + 2})`;
    context.beginPath();
    context.arc(x, y, radius, 0, Math.PI * 2);
    context.fill();
  }

  const accentRgb = toRgb(accent);
  const dashLength = CIRCUIT_DASH_PERIOD / 2;
  for (let lane = 0; lane < CIRCUIT_LANES; lane++) {
    const x = Math.round(((lane + 0.5) / CIRCUIT_LANES) * size);
    context.strokeStyle = accentRgb;
    context.lineWidth = 3;
    for (let y = 0; y < size; y += CIRCUIT_DASH_PERIOD) {
      context.beginPath();
      context.moveTo(x, y);
      context.lineTo(x, y + dashLength);
      context.stroke();
    }
  }

  texture.update(false);
  texture.wrapU = Texture.WRAP_ADDRESSMODE;
  texture.wrapV = Texture.WRAP_ADDRESSMODE;

  return texture;
}

const PULSE_SPEED = 0.15; // texture-space V units per second

/** Scrolls a set of circuit textures' V offset over time, in lockstep, to animate the light pulses. */
export function animateCircuitPulses(scene: Scene, textures: readonly Texture[]): void {
  scene.onBeforeRenderObservable.add(() => {
    const deltaSeconds = scene.getEngine().getDeltaTime() / 1000;
    for (const texture of textures) {
      texture.vOffset = (texture.vOffset + PULSE_SPEED * deltaSeconds) % 1;
    }
  });
}

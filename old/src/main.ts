import { createScene } from "./scene/createScene";
import { createIdlePlayerInput, type PlayerInput } from "./scene/playerController";

const canvas = document.querySelector<HTMLCanvasElement>("#renderCanvas");
if (!canvas) {
  throw new Error("Missing #renderCanvas element");
}

const { engine, scene, camera, player, mazeWalls } = createScene(canvas);

const input = createIdlePlayerInput();

if (import.meta.env.DEV) {
  (window as unknown as Record<string, unknown>).__sphaze = { engine, scene, camera, player, input, mazeWalls };
}

// Z/S walk forward/backward, Q/D strafe sideways by default (turn instead
// while Shift is held), Space (held) tilts the view toward the sphere's
// center without moving the player.
const keyBindings: Partial<Record<string, keyof PlayerInput>> = {
  q: "left",
  d: "right",
  z: "forward",
  s: "backward",
};

window.addEventListener("keydown", (event) => {
  if (event.code === "Space") {
    event.preventDefault();
    input.lookUp = true;
    return;
  }
  if (event.key === "Shift") {
    input.shift = true;
    return;
  }
  if (event.key === "i") {
    void import("@babylonjs/inspector").then(() => {
      scene.debugLayer.show({ overlay: true });
    });
    return;
  }
  const action = keyBindings[event.key.toLowerCase()];
  if (action) {
    input[action] = true;
  }
});

window.addEventListener("keyup", (event) => {
  if (event.code === "Space") {
    input.lookUp = false;
    return;
  }
  if (event.key === "Shift") {
    input.shift = false;
    return;
  }
  const action = keyBindings[event.key.toLowerCase()];
  if (action) {
    input[action] = false;
  }
});

// Pointer lock gives free-look mouse movement without the cursor leaving the
// canvas or getting stuck at the screen edge.
canvas.addEventListener("click", () => {
  canvas.requestPointerLock();
});

window.addEventListener("mousemove", (event) => {
  if (document.pointerLockElement !== canvas) {
    return;
  }
  player.applyMouseMovement(event.movementX, event.movementY);
});

engine.runRenderLoop(() => {
  const deltaSeconds = engine.getDeltaTime() / 1000;
  player.update(deltaSeconds, input, camera);
  scene.render();
});

window.addEventListener("resize", () => {
  engine.resize();
});

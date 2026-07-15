import { describe, expect, it } from "vitest";
import { allNodes, generateMaze, isOpen, MAZE_COLS, neighborsOf, nodeKey } from "./mazeGenerator";

// Deterministic PRNG (mulberry32) so the spanning-tree checks aren't at the
// mercy of Math.random flakiness.
function seededRandom(seed: number): () => number {
  let state = seed;
  return () => {
    state |= 0;
    state = (state + 0x6d2b79f5) | 0;
    let t = Math.imul(state ^ (state >>> 15), 1 | state);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

describe("generateMaze", () => {
  it("produces a spanning tree: exactly nodeCount - 1 open edges", () => {
    const maze = generateMaze(seededRandom(1));
    const nodes = allNodes();

    expect(maze.openEdges.size).toBe(nodes.length - 1);
  });

  it("connects every node to every other node through open edges only", () => {
    const maze = generateMaze(seededRandom(42));
    const nodes = allNodes();

    const visited = new Set<string>();
    const stack = [nodes[0]];
    if (stack[0]) {
      visited.add(nodeKey(stack[0]));
    }

    while (stack.length > 0) {
      const current = stack.pop();
      if (!current) {
        continue;
      }
      for (const neighbor of neighborsOf(current)) {
        if (isOpen(maze, current, neighbor) && !visited.has(nodeKey(neighbor))) {
          visited.add(nodeKey(neighbor));
          stack.push(neighbor);
        }
      }
    }

    expect(visited.size).toBe(nodes.length);
  });

  it("wraps the longitude columns around (column 0 is adjacent to the last column)", () => {
    const ringNeighbors = neighborsOf({ kind: "ring", row: 3, col: 0 });

    expect(ringNeighbors).toContainEqual({ kind: "ring", row: 3, col: MAZE_COLS - 1 });
  });
});

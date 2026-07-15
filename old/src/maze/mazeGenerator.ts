// The maze lives on a latitude/longitude grid over the sphere. The two pole
// rows would otherwise collapse into MAZE_COLS degenerate slivers meeting at
// a point, so each pole is a single merged node that every cell in the
// adjacent ring connects to directly.
export const MAZE_ROWS = 16;
export const MAZE_COLS = 32;

export type MazeNode = { kind: "pole"; pole: "north" | "south" } | { kind: "ring"; row: number; col: number };

export interface Maze {
  openEdges: Set<string>;
}

export function nodeKey(node: MazeNode): string {
  return node.kind === "pole" ? `pole:${node.pole}` : `ring:${node.row}:${node.col}`;
}

function edgeKey(a: MazeNode, b: MazeNode): string {
  const keyA = nodeKey(a);
  const keyB = nodeKey(b);
  return keyA < keyB ? `${keyA}|${keyB}` : `${keyB}|${keyA}`;
}

export function neighborsOf(node: MazeNode): MazeNode[] {
  if (node.kind === "pole") {
    const row = node.pole === "north" ? 1 : MAZE_ROWS - 2;
    return Array.from({ length: MAZE_COLS }, (_, col): MazeNode => ({ kind: "ring", row, col }));
  }

  const { row, col } = node;
  const neighbors: MazeNode[] = [
    { kind: "ring", row, col: (col - 1 + MAZE_COLS) % MAZE_COLS },
    { kind: "ring", row, col: (col + 1) % MAZE_COLS },
  ];
  neighbors.push(row === 1 ? { kind: "pole", pole: "north" } : { kind: "ring", row: row - 1, col });
  neighbors.push(row === MAZE_ROWS - 2 ? { kind: "pole", pole: "south" } : { kind: "ring", row: row + 1, col });
  return neighbors;
}

export function allNodes(): MazeNode[] {
  const nodes: MazeNode[] = [
    { kind: "pole", pole: "north" },
    { kind: "pole", pole: "south" },
  ];
  for (let row = 1; row <= MAZE_ROWS - 2; row++) {
    for (let col = 0; col < MAZE_COLS; col++) {
      nodes.push({ kind: "ring", row, col });
    }
  }
  return nodes;
}

/**
 * Generates a perfect maze (spanning tree — exactly one path between any two
 * cells) over the sphere's lat/long grid via randomized depth-first search.
 */
export function generateMaze(random: () => number = Math.random): Maze {
  const visited = new Set<string>();
  const openEdges = new Set<string>();

  const start = allNodes()[0];
  if (!start) {
    return { openEdges };
  }

  const stack: MazeNode[] = [start];
  visited.add(nodeKey(start));

  while (stack.length > 0) {
    const current = stack[stack.length - 1];
    if (!current) {
      break;
    }

    const unvisited = neighborsOf(current).filter((neighbor) => !visited.has(nodeKey(neighbor)));
    if (unvisited.length === 0) {
      stack.pop();
      continue;
    }

    const next = unvisited[Math.floor(random() * unvisited.length)];
    if (!next) {
      continue;
    }
    openEdges.add(edgeKey(current, next));
    visited.add(nodeKey(next));
    stack.push(next);
  }

  return { openEdges };
}

export function isOpen(maze: Maze, a: MazeNode, b: MazeNode): boolean {
  return maze.openEdges.has(edgeKey(a, b));
}

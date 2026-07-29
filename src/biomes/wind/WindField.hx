package biomes.wind;

import biomes.common.grass.GrassMesh.WindSample;
import biomes.common.grid.GridModel;
import biomes.common.grid.GridModel.GridData;
import biomes.common.grid.GridModel.GridNode;
import biomes.common.space.sphere.SphereMath;

/**
	Where the wind blows, everywhere on a grid maze: a breadth-first distance
	from the exit over *open* edges only, which makes the wind flow along the
	corridors rather than through walls — that's the whole trick, and it's why
	the field is worth anything as a wayfinding cue. Following the wind
	upstream is following the maze's own solution, and no line of sight is
	needed to do it.

	The design intent, per `docs/game-design/ideas-backlog.md`'s perception
	entry: one tuft of grass tells the player nothing (it just leans), but the
	whole sphere's grass seen from across it is a flow field converging on one
	point. Illegible up close, legible at distance — the game's core
	asymmetry, expressed by something that isn't geometry.

	Pure model: distances and directions, no scene graph, same `Model`/`Mesh`
	split as every other biome piece (`biomes.common.grass.GrassMesh` is what
	turns a direction into vertices).
**/
class WindField {
	/**
		Fallback direction where the field has nothing to say — a pole cell
		(`SphereMath.thetaTangentAt` is singular there, and the merged pole
		isn't a corridor anyway) or an unreachable cell (impossible in a
		perfect maze, but a braided or rule-driven layout could produce one
		later). Blades there sway along the local east-west tangent, which
		reads as "no draft here" rather than as a direction pointing somewhere
		false.
	**/
	static inline final NO_DRAFT_FALLBACK_PHI:Float = 0;

	/**
		Gust phase added per step away from the exit, in radians — what turns
		the whole field's sway into a wave that visibly travels *downwind*
		rather than every blade wobbling on its own clock (see
		`graphics.shaders.GrassWindField`). At this value a gust's wavelength is
		roughly seven cells: long enough that neighbouring corridors move
		together and the motion reads as one sweep, short enough that a player
		can see a crest pass rather than waiting for the whole sphere to
		breathe in unison.
	**/
	public static inline final PHASE_PER_STEP:Float = 0.9;

	final distances:Map<String, Int> = [];

	final maze:GridData;

	/**
		@param maze the layout the wind flows through.
		@param exit the node the draft comes from — the maze's own exit (see `biomes.maze.MazeExitWall`).
	**/
	public function new(maze:GridData, exit:GridNode) {
		this.maze = maze;
		floodFrom(exit);
	}

	/**
		Breadth-first flood from the exit over open edges — so `distances`
		holds each cell's distance *along the corridors*, not through the
		sphere.
		@param exit the node to flood from.
	**/
	function floodFrom(exit:GridNode):Void {
		distances.set(GridModel.nodeKey(exit), 0);
		var frontier:Array<GridNode> = [exit];
		while (frontier.length > 0) {
			var next:Array<GridNode> = [];
			for (node in frontier) {
				var depth = distances.get(GridModel.nodeKey(node));
				if (depth == null) {
					continue;
				}
				for (neighbor in GridModel.neighborsOf(node)) {
					var key = GridModel.nodeKey(neighbor);
					if (distances.exists(key) || !GridModel.isOpen(maze, node, neighbor)) {
						continue;
					}
					distances.set(key, depth + 1);
					next.push(neighbor);
				}
			}
			frontier = next;
		}
	}

	/**
		Everything a blade at `pos` needs: which way the draft blows, and how
		far along the flow it stands.

		The direction blows *away* from the exit — from the neighbouring cell
		one step closer to it, toward this one. Outward rather than inward is
		deliberate: the player walks into the wind to leave, and the field's one
		convergence point is the way out.

		The flow position is that cell's own distance from the exit turned into
		a phase (`PHASE_PER_STEP`). Direction alone is only an *axis* on screen
		— a lean looks the same bent either way from a distance — so the
		travelling gust this phase produces is what actually distinguishes "the
		exit is that way" from "the exit is behind me". That omission is
		precisely why the first version of this biome showed nothing readable.
		@param pos a world position on the maze's own sphere.
		@return the draft direction (a unit tangent at `pos`) and this cell's own gust phase.
	**/
	public function sampleAt(pos:h3d.Vector):WindSample {
		var theta = SphereMath.thetaOf(pos);
		var phi = SphereMath.phiOf(pos);
		var here = GridModel.nodeAt(theta, phi);
		var depth = distances.get(GridModel.nodeKey(here));
		var flowPosition = (depth != null ? depth : 0) * PHASE_PER_STEP;

		var upstream = upstreamOf(here);
		if (upstream == null) {
			return {dir: SphereMath.phiTangentAt(NO_DRAFT_FALLBACK_PHI + phi), flowPosition: flowPosition};
		}

		var from = centreOf(upstream);
		var to = centreOf(here);
		return {dir: tangentAt(pos, to.sub(from)), flowPosition: flowPosition};
	}

	/**
		Whichever of `node`'s open neighbours is one step closer to the exit —
		where the draft reaching `node` comes from.
		@param node the cell to look upstream of.
		@return that neighbour, or null at the exit itself and anywhere the flood didn't reach.
	**/
	function upstreamOf(node:GridNode):Null<GridNode> {
		var depth = distances.get(GridModel.nodeKey(node));
		if (depth == null || depth == 0) {
			return null;
		}
		for (neighbor in GridModel.neighborsOf(node)) {
			if (!GridModel.isOpen(maze, node, neighbor)) {
				continue;
			}
			if (distances.get(GridModel.nodeKey(neighbor)) == depth - 1) {
				return neighbor;
			}
		}
		return null;
	}

	static function centreOf(node:GridNode):h3d.Vector {
		var centre = GridModel.centerOf(node);
		return SphereMath.sphericalToCartesian(1, centre.theta, centre.phi);
	}

	/**
		`direction` projected onto the tangent plane at `pos` and normalized —
		two cell centres on a sphere are never exactly tangent to either of
		them (the same approximation `entities.painting.PaintingModel`'s own
		wall mounting relies on), and the shader needs a genuine tangent.
		@param pos the position whose tangent plane to project onto.
		@param direction the direction to project.
		@return a unit tangent at `pos`.
	**/
	static function tangentAt(pos:h3d.Vector, direction:h3d.Vector):h3d.Vector {
		var posDir = pos.normalized();
		var tangent = direction.sub(posDir.scaled(direction.dot(posDir)));
		// Degenerate only if the two centres are radially aligned, which
		// adjacent cells never are — but a zero vector would come out of the
		// shader as a NaN sway, so it's worth the guard.
		return tangent.length() < 1e-6 ? SphereMath.phiTangentAt(SphereMath.phiOf(pos)) : tangent.normalized();
	}
}

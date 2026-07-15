package maze;

import maze.Maze.MazeNode;

/**
	Maps the abstract maze grid (Maze.hx, deliberately engine-agnostic) onto
	concrete 3D positions on a physical sphere, via SphereMath. This is where
	"physical space" enters the maze subsystem — both the camera/player
	placement and the maze mesh (once it exists) go through here so the
	grid-to-sphere mapping is defined in exactly one place.
**/
class MazeGeometry {
	/** Radius of the physical sphere the maze grid is mapped onto. **/
	public static inline final RADIUS:Float = 50;

	/**
		Spherical angles (see SphereMath) for a grid node. Ring cells spread
		evenly across the 14 latitude bands strictly between the poles (row 0
		and row `Maze.ROWS - 1` are the poles themselves, handled directly
		rather than iterated as rows); a pole node sits exactly at its pole,
		where phi is irrelevant.
		@param node the grid node to place.
		@return the node's {theta, phi} on the sphere.
	**/
	public static function anglesOf(node:MazeNode):{theta:Float, phi:Float} {
		return switch node {
			case PoleNode(North): {theta: 0.0, phi: 0.0};
			case PoleNode(South): {theta: Math.PI, phi: 0.0};
			case RingNode(row, col): {theta: Math.PI * row / (Maze.ROWS - 1), phi: 2 * Math.PI * col / Maze.COLS};
		}
	}

	/**
		3D position of a grid node on the sphere, centered at the world
		origin.
		@param node the grid node to place.
		@return the node's position in world space.
	**/
	public static function positionOf(node:MazeNode):h3d.Vector {
		var angles = anglesOf(node);
		return game.SphereMath.sphericalToCartesian(RADIUS, angles.theta, angles.phi);
	}
}

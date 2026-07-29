package biomes.twosided;

import biomes.common.space.sphere.SphereMath;
import entities.Entity;
import game.MeshBuilder;
import graphics.Colours;
import graphics.shaders.UnlitTexture;

/**
	A mark the player left on the shell — the thing that makes
	`TwoSidedBiome`'s two faces one place rather than two levels.

	Built as a post that **pierces** the shell, sticking out by the same amount
	on both sides, so a mark placed while walking the inside is visible while
	walking the outside and vice versa. That's the entire point: the player
	surveys from the inside (where you can see clear across), marks what they
	spotted, crosses over, and then has something to navigate toward on a face
	where surveying is impossible. Nothing else in the game currently carries
	information between two viewpoints like that.

	An `Entity` for the same reason `entities.painting.PaintingModel` is one —
	it's a thing that exists in the world at a position — and the same
	discipline applies: only the shape this mechanic actually needs is built.
	There's no mark *type*, no orientation, no arrow yet, because the backlog's
	"mark now, see later" entry is explicit that what a mark should *say* is
	unproven. A post that says "here" is the cheapest thing that tests whether
	cross-face marking is worth designing around at all.
**/
class MarkModel extends Entity {
	/** How far the post stands out of the shell, on each side. Tall enough to clear `biomes.common.grid.GridMesh.WALL_HEIGHT` so a mark isn't hidden by the corridor it stands in. **/
	public static inline final REACH:Float = 16;

	/** Post thickness. Deliberately thin: a mark should read as a line at distance, not as a landmark that blocks a corridor. **/
	static inline final THICKNESS:Float = 1.2;

	/** Where on the shell this mark stands — the player's own position when they placed it. **/
	public final pos:h3d.Vector;

	public function new(pos:h3d.Vector) {
		super();
		this.pos = pos;
	}

	/**
		Builds every mark as one four-sided post each, batched into a single
		mesh — marks are placed at runtime and the whole set is rebuilt when it
		changes (see `TwoSidedBiome.rebuildMarks`), so this stays one draw call
		regardless of how many the player leaves.
		@param parent the scene object to attach the marks mesh under.
		@param marks the marks to build.
	**/
	public static function build(parent:h3d.scene.Object, marks:Array<MarkModel>):Void {
		if (marks.length == 0) {
			return;
		}

		var points:Array<h3d.Vector> = [];
		var idx = new hxd.IndexBuffer();
		var uvs:Array<h3d.prim.UV> = [];
		for (mark in marks) {
			addPost(points, idx, uvs, mark.pos);
		}

		var prim = new h3d.prim.Polygon(points, idx);
		prim.uvs = uvs;
		var mesh = new h3d.scene.Mesh(prim, parent);
		mesh.material.mainPass.addShader(new UnlitTexture(h3d.mat.Texture.fromColor(Colours.MARK_POST)));
		mesh.material.mainPass.culling = None;
	}

	/**
		One post: a square prism along the radial direction at `pos`, running
		from `REACH` inside the shell to `REACH` outside it.
		@param points vertex buffer to append to.
		@param idx index buffer to append to.
		@param uvs UV buffer to append to.
		@param pos where on the shell the post stands.
	**/
	static function addPost(points:Array<h3d.Vector>, idx:hxd.IndexBuffer, uvs:Array<h3d.prim.UV>, pos:h3d.Vector):Void {
		var outward = pos.normalized();
		// Any two tangents perpendicular to each other will do for a square
		// cross-section; the sphere's own theta/phi tangents are already an
		// orthonormal pair at this point (see `SphereMath`), so there's no
		// basis to invent here.
		var theta = SphereMath.thetaOf(pos);
		var phi = SphereMath.phiOf(pos);
		var right = SphereMath.thetaTangentAt(theta, phi).scaled(THICKNESS / 2);
		var forward = SphereMath.phiTangentAt(phi).scaled(THICKNESS / 2);

		var inner = pos.sub(outward.scaled(REACH));
		var outer = pos.add(outward.scaled(REACH));
		// Perimeter order around the post's cross-section, so consecutive
		// pairs are its four sides.
		var offsets = [
			right.add(forward),
			right.sub(forward),
			forward.scaled(-1).sub(right),
			forward.sub(right)
		];
		for (i in 0...offsets.length) {
			var a = offsets[i];
			var b = offsets[(i + 1) % offsets.length];
			if (a == null || b == null) {
				continue;
			}
			MeshBuilder.addQuad(points, idx, inner.add(a), inner.add(b), outer.add(b), outer.add(a));
			uvs.push(new h3d.prim.UV(0, 0));
			uvs.push(new h3d.prim.UV(1, 0));
			uvs.push(new h3d.prim.UV(1, 1));
			uvs.push(new h3d.prim.UV(0, 1));
		}
	}
}

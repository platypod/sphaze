package game;

/**
	Accumulates axis-aligned boxes and emits them as meshes, splitting
	automatically before any one mesh outgrows a 16-bit index buffer.

	**The splitting is why this exists, and it is a bug fix rather than an
	optimisation.** `biomes.ribbon.RibbonBiome` builds about 7,300 boxes;
	at twenty vertices each that is roughly 146,000, well past the 65,535
	an index buffer can address. Heaps raised no error and WebGL reported
	nothing — the indices simply wrapped and the terrain rendered as an
	empty plane, indistinguishable from geometry that had never been
	generated at all. It cost a debugging session to find, and nothing
	else in the codebase guards against it.

	Extracted here once a second biome (`biomes.repeat.RepeatBiome`)
	needed the same thing, per `docs/rules/guidelines.md`'s rule about waiting
	for the second use case rather than generalising on the first.

	Stateful, unlike `MeshBuilder`'s own static helpers: the whole point
	is carrying a running vertex count across many `add` calls, which a
	stateless function cannot do.
**/
class BoxBatch {
	/** Four sides and a cap, four vertices each — see `add`. **/
	public static inline final VERTICES_PER_BOX:Int = 20;

	/** The largest index a 16-bit buffer can address, rounded down to a whole number of boxes. **/
	public static inline final MAX_VERTICES_PER_MESH:Int = 65520;

	final parent:h3d.scene.Object;
	final color:Int;

	var points:Array<h3d.Vector>;
	var idx:hxd.IndexBuffer;

	/**
		@param parent the scene object emitted meshes are attached to.
		@param color the flat colour every box in this batch is drawn in — one batch per colour, since a `FixedColor` pass covers the whole mesh.
	**/
	public function new(parent:h3d.scene.Object, color:Int) {
		this.parent = parent;
		this.color = color;
		points = [];
		idx = new hxd.IndexBuffer();
	}

	/**
		One box, standing on `baseY`: four sides and a cap, no underside
		(nothing ever sees it).

		Boxes stay axis-aligned even where the ground they stand on is not
		— a building or a cell is a discrete thing sitting on the terrain,
		not a shear of it.
		@param x centre, east-west.
		@param z centre, north-south.
		@param halfX half-extent east-west.
		@param halfZ half-extent north-south.
		@param baseY the height its foot sits at.
		@param height how tall it stands above `baseY`.
	**/
	public function add(x:Float, z:Float, halfX:Float, halfZ:Float, baseY:Float, height:Float):Void {
		if (points.length + VERTICES_PER_BOX > MAX_VERTICES_PER_MESH) {
			flush();
		}

		var x0 = x - halfX;
		var x1 = x + halfX;
		var z0 = z - halfZ;
		var z1 = z + halfZ;

		var feet = [
			new h3d.Vector(x0, baseY, z0),
			new h3d.Vector(x1, baseY, z0),
			new h3d.Vector(x1, baseY, z1),
			new h3d.Vector(x0, baseY, z1)
		];
		var tops = [for (c in feet) new h3d.Vector(c.x, baseY + height, c.z)];

		for (k in 0...4) {
			var next = (k + 1) % 4;
			MeshBuilder.addQuad(points, idx, feet[k], feet[next], tops[next], tops[k]);
		}
		MeshBuilder.addQuad(points, idx, tops[0], tops[1], tops[2], tops[3]);
	}

	/**
		Emits whatever has accumulated as one mesh and starts a fresh
		buffer. Called automatically when a batch would overflow; callers
		must call it once at the end to emit the remainder.
	**/
	public function flush():Void {
		if (points.length == 0) {
			return; // Polygon rejects an empty vertex list, and an empty batch legitimately produces one
		}
		var mesh = new h3d.scene.Mesh(new h3d.prim.Polygon(points, idx), parent);
		mesh.material.mainPass.addShader(new h3d.shader.FixedColor(color));
		mesh.material.mainPass.culling = None;

		points = [];
		idx = new hxd.IndexBuffer();
	}
}

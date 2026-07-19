package biomes.mobius;

import biomes.common.space.mobius.MobiusMath;

/**
	One placed tree's own position and per-instance variation — everything
	`biomes.mobius.MobiusMesh` needs to build its trunk/foliage geometry and
	`biomes.mobius.MobiusCollision` needs for its own hitbox check. `u`/`v`
	are the ribbon's own parameter coordinates (kept alongside the resolved
	`x`/`y`/`z` mainly for debugging/future use — nothing reads them back
	today); `x`/`y`/`z` are the actual world position, resolved once here at
	generation time rather than re-derived from `u`/`v` on every collision
	check, which would mean re-running `MobiusMath.pointAt`'s own trig for
	every tree, every fixed step (`biomes.mobius.MobiusCollision.tryMove`
	runs at 60Hz) — cheap for one tree, not free at `MobiusModel.TARGET_TREE_COUNT`-many.

	`species` is one of `MobiusForestGenerator.SPECIES_CONIFER`/`_ROUND`/`_DEAD`
	— a plain `Int`, not a real Haxe enum, so this stays a flat, directly
	JSON-serializable structure (an enum instance isn't). `rotation` spins
	a tree's own `tangent`/`right` basis around `up` before
	`biomes.common.tree.TreeMesh` builds anything from it — without it,
	every tree's own faceted seams (and every dead tree's own branches)
	would line up identically, reading as stamped copies rather than a
	natural forest.
**/
typedef PlacedTree = {
	var u:Float;
	var v:Float;
	var x:Float;
	var y:Float;
	var z:Float;
	var species:Int;
	var rotation:Float;
	var trunkHeight:Float;
	var trunkRadius:Float;
	var foliageRadius:Float;
	var foliageHeight:Float;
}

/** A whole generated forest — just the placed trees, but its own typedef (rather than a bare `Array<PlacedTree>`) so `MobiusBiome`'s own field/serialize signatures read as "a forest," matching `biomes.tower.TowerModel.TowerData`'s own reasoning. **/
typedef ForestLayout = {
	var trees:Array<PlacedTree>;
}

/**
	Generates the Möbius ribbon's own forest — pure data, no scene graph,
	same `Generator` role `biomes.tower.TowerGenerator`/`biomes.maze.MazeGenerator`
	play for their own biomes. Direct ask: "fully dense, weave required" —
	no guaranteed clear lane, so this scatters across the ribbon's *entire*
	usable width (short of `MobiusModel.TREE_EDGE_MARGIN` at either edge),
	not just a margin either side of a walkway.

	Rejection sampling in `(u, v)` parameter space, uniform over `u ∈ [0,
	2*PI)` and `v` over the usable width — a known simplification, not
	exactly uniform by real surface area: `MobiusMath`'s own metric isn't
	flat (`|Pu|` varies with both `u` and `v`, since the twist's own angular
	rate scales with `v`), so this can bunch trees very slightly denser or
	sparser in some regions rather than a perfectly even scatter. Cheap to
	fix later (weight the rejection by the local metric) if it ever reads
	as visibly uneven; not worth the complexity for a first pass.

	Minimum spacing (`MobiusModel.MIN_TREE_SPACING`) is checked in real
	world 3D distance between resolved positions, not parameter distance —
	the only distance that actually matches what a player sees/walks
	through. This makes each new candidate's own rejection check
	`O(placed so far)`, and the whole generation `O(count²)` in the worst
	case — fine here since it's a one-time cost at `game.GameLoop` startup,
	never repeated per-frame (contrast `MobiusCollision`'s own per-tick
	scan, which is why positions are pre-resolved — see `PlacedTree`'s own
	doc).
**/
class MobiusForestGenerator {
	/** A layered-conifer silhouette (`biomes.common.tree.TreeMesh.addConiferFoliage`) — the most common species. **/
	public static inline final SPECIES_CONIFER:Int = 0;

	/** A round-canopy silhouette (`biomes.common.tree.TreeMesh.addRoundFoliage`). **/
	public static inline final SPECIES_ROUND:Int = 1;

	/** A bare trunk with a few stub branches, no foliage (`biomes.common.tree.TreeMesh.addDeadBranches`) — an accent, not the norm. **/
	public static inline final SPECIES_DEAD:Int = 2;

	/** Chance a given tree rolls `SPECIES_CONIFER` — checked first, so this is its own share of the total. **/
	static inline final CONIFER_CHANCE:Float = 0.5;

	/** Chance a given tree rolls `SPECIES_ROUND`, checked after `SPECIES_CONIFER` — the remaining `1 - CONIFER_CHANCE - ROUND_CHANCE` falls through to `SPECIES_DEAD`. **/
	static inline final ROUND_CHANCE:Float = 0.35;

	/**
		Scatters `count` trees (or however many fit before
		`MobiusModel.TREE_SCATTER_MAX_ATTEMPTS` runs out) across the
		ribbon's own usable width, clear of the entrance spawn point.
		@param twists half-twists over one full lap around the loop — must match whatever `biomes.mobius.MobiusBiome` this layout is built for.
		@param random source of randomness in [0, 1); defaults to `Math.random`.
		@param count how many trees to scatter; defaults to `MobiusModel.TARGET_TREE_COUNT` — a caller with its own denser/sparser forest (or a test wanting a small, fast-to-check layout) passes its own rather than this hardcoding one absolute count for everyone, same reasoning `biomes.common.grass.GrassModel.scatter`'s own `count` parameter gives.
		@return the generated forest.
	**/
	public static function generate(twists:Int = MobiusModel.DEFAULT_TWISTS, ?random:Void->Float, count:Int = MobiusModel.TARGET_TREE_COUNT):ForestLayout {
		var rng = random != null ? random : Math.random;
		var trees:Array<PlacedTree> = [];
		var usableHalfWidth = MobiusModel.HALF_WIDTH - MobiusModel.TREE_EDGE_MARGIN;
		var spawn = MobiusModel.spawnPosition(twists);
		var attempts = 0;

		while (trees.length < count && attempts < MobiusModel.TREE_SCATTER_MAX_ATTEMPTS) {
			attempts++;
			var u = rng() * 2 * Math.PI;
			var v = (rng() * 2 - 1) * usableHalfWidth;
			var pos = MobiusMath.pointAt(u, v, twists, MobiusModel.RADIUS);

			if (distance(pos, spawn) < MobiusModel.TREE_SPAWN_CLEARANCE) {
				continue;
			}
			if (tooCloseToAnother(pos, trees)) {
				continue;
			}

			var speciesRoll = rng();
			var species = speciesRoll < CONIFER_CHANCE ? SPECIES_CONIFER : (speciesRoll < CONIFER_CHANCE + ROUND_CHANCE ? SPECIES_ROUND : SPECIES_DEAD);

			trees.push({
				u: u,
				v: v,
				x: pos.x,
				y: pos.y,
				z: pos.z,
				species: species,
				rotation: rng() * 2 * Math.PI,
				trunkHeight: MobiusModel.TRUNK_HEIGHT_MIN + rng() * (MobiusModel.TRUNK_HEIGHT_MAX - MobiusModel.TRUNK_HEIGHT_MIN),
				trunkRadius: MobiusModel.TRUNK_RADIUS_MIN + rng() * (MobiusModel.TRUNK_RADIUS_MAX - MobiusModel.TRUNK_RADIUS_MIN),
				foliageRadius: MobiusModel.FOLIAGE_RADIUS_MIN + rng() * (MobiusModel.FOLIAGE_RADIUS_MAX - MobiusModel.FOLIAGE_RADIUS_MIN),
				foliageHeight: MobiusModel.FOLIAGE_HEIGHT_MIN + rng() * (MobiusModel.FOLIAGE_HEIGHT_MAX - MobiusModel.FOLIAGE_HEIGHT_MIN)
			});
		}

		return {trees: trees};
	}

	static function tooCloseToAnother(pos:h3d.Vector, trees:Array<PlacedTree>):Bool {
		for (t in trees) {
			var dx = pos.x - t.x;
			var dy = pos.y - t.y;
			var dz = pos.z - t.z;
			if (dx * dx + dy * dy + dz * dz < MobiusModel.MIN_TREE_SPACING * MobiusModel.MIN_TREE_SPACING) {
				return true;
			}
		}
		return false;
	}

	static inline function distance(a:h3d.Vector, b:h3d.Vector):Float {
		return a.sub(b).length();
	}

	/**
		Serializes a generated forest to a JSON string — same role as
		`biomes.tower.TowerGenerator.serialize`, for `game.GameLoop`'s E
		(export) dev tool. A forest layout is already a plain nested
		array/object, so this needs no encoding beyond `haxe.Json.stringify`
		itself.
		@param layout the forest to serialize.
		@return a JSON string.
	**/
	public static function serialize(layout:ForestLayout):String {
		return haxe.Json.stringify(layout);
	}

	/**
		Inverse of `serialize`.
		@param json a JSON string produced by `serialize`.
		@return the forest layout it encodes.
	**/
	public static function deserialize(json:String):ForestLayout {
		var parsed:ForestLayout = haxe.Json.parse(json);
		return parsed;
	}
}

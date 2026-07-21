package biomes.mobius;

import biomes.common.space.mobius.MobiusMath;
import biomes.mobius.MobiusForestGenerator.ForestLayout;
import game.MeshBuilder;
import graphics.Colours;
import graphics.shaders.UnlitTexture;

/**
	Builds the Möbius biome's own visible world: the ribbon itself, now
	textured with the project's usual grass; a low parapet wall along both
	open edges; the forest scattered across it; and a simple space backdrop
	(stars + a few colored planets) so the strip reads as suspended in void
	rather than against the engine's default flat clear color alone.

	The ribbon geometry is still a plain rectangular `(u, v)` grid sampled
	through `MobiusMath.pointAt`: the twist and the seam closure are entirely
	a property of that math, not special cases in this mesh builder.
**/
class MobiusMesh {
	/** Samples around the loop — fine enough to read as smoothly curved through several twists. **/
	static inline final U_SEGMENTS:Int = 180;

	/** Across-width floor subdivisions — enough that the textured ribbon still reads smooth across its width and under the parapet. **/
	static inline final V_SEGMENTS:Int = 8;

	/**
		How many trees' worth of geometry go into one trunk/foliage mesh —
		`addQuad`/`addTriangle` never share or reuse a vertex, so a single
		mesh spanning the whole forest could rack up more distinct vertices
		than `hxd.IndexBuffer` can actually index (an `Array<UInt16>` under
		the hood, silently wrapping indices past `65536` back to `0` instead
		of erroring — the exact bug `biomes.tower.TowerMesh.LAYERS_PER_CHUNK`'s
		own doc already ran into once). Foliage is the worse case per tree
		(two cones, `TreeMesh.FOLIAGE_SIDES` triangles each, 3 new vertices
		per triangle): `500 * 2 * 8 * 3 = 24000`, comfortably clear of the
		limit regardless of how many trees `biomes.mobius.MobiusForestGenerator`
		actually manages to place.
	**/
	static inline final TREES_PER_CHUNK:Int = 500;

	static inline final STAR_COUNT:Int = 180;

	static inline final STAR_FIELD_RADIUS:Float = 5200;

	static inline final STAR_MIN_RADIUS:Float = 5;

	static inline final STAR_MAX_RADIUS:Float = 11;

	static inline final PLANET_DISTANCE:Float = 4300;

	static inline final PLANET_SEGS_W:Int = 18;

	static inline final PLANET_SEGS_H:Int = 12;

	/** Summer-season trees from Quaternius Ultimate Nature Pack (CC0). One file per model. **/
	static final IMPORTED_TREE_MODEL_PATHS = [
		"models/quaternius-ultimate-nature-pack/BirchTree_1.fbx",
		"models/quaternius-ultimate-nature-pack/BirchTree_2.fbx",
		"models/quaternius-ultimate-nature-pack/BirchTree_3.fbx",
		"models/quaternius-ultimate-nature-pack/BirchTree_4.fbx",
		"models/quaternius-ultimate-nature-pack/BirchTree_5.fbx",
		"models/quaternius-ultimate-nature-pack/CommonTree_1.fbx",
		"models/quaternius-ultimate-nature-pack/CommonTree_2.fbx",
		"models/quaternius-ultimate-nature-pack/CommonTree_3.fbx",
		"models/quaternius-ultimate-nature-pack/CommonTree_4.fbx",
		"models/quaternius-ultimate-nature-pack/CommonTree_5.fbx",
		"models/quaternius-ultimate-nature-pack/PineTree_1.fbx",
		"models/quaternius-ultimate-nature-pack/PineTree_2.fbx",
		"models/quaternius-ultimate-nature-pack/PineTree_3.fbx",
		"models/quaternius-ultimate-nature-pack/PineTree_4.fbx",
		"models/quaternius-ultimate-nature-pack/PineTree_5.fbx",
		"models/quaternius-ultimate-nature-pack/Willow_1.fbx",
		"models/quaternius-ultimate-nature-pack/Willow_2.fbx",
		"models/quaternius-ultimate-nature-pack/Willow_3.fbx",
		"models/quaternius-ultimate-nature-pack/Willow_4.fbx",
		"models/quaternius-ultimate-nature-pack/Willow_5.fbx",
	];

	static final IMPORTED_TREE_BARK_COLOR = 0xFF4D2E12;

	static final IMPORTED_TREE_FOLIAGE_COLOR = 0xFF2E6B2E;

	// `setDirection` aligns local +X to the surface normal; all Quaternius models
	// share the same up-axis convention, so one shared alignment covers all variants.
	static inline final HALF_PI:Float = 1.5707963267948966;
	static inline final ROTATION_STEP:Float = 0.2617993877991494; // 15°
	static inline final GROUND_BIAS_STEP:Float = 0.05;

	static final importedTreeModelCache = new h3d.prim.ModelCache();

	static var importedTreeHeights:Array<Float> = [];

	static var importedTreePivots:Array<h3d.Vector> = [];

	static var importedTreePrototypes:Array<Null<h3d.scene.Object>> = [];

	/** Shared alignment for all Quaternius models — T/Y/U keys tune it live. **/
	static var importedTreeAlignmentRot:{rx:Float, ry:Float, rz:Float} = {rx: 0.0, ry: HALF_PI, rz: 0.0};

	/** Extra downward offset applied at placement time for all variants — I key tunes it live. **/
	static var importedTreeGroundBias:Float = 0.0;

	/**
		@param parent the scene object to attach the meshes under.
		@param twists half-twists over one full lap around the loop.
		@param forest the generated forest to render alongside the ribbon itself.
	**/
	public static function build(parent:h3d.scene.Object, twists:Int, forest:ForestLayout, forestCutU:Float = MobiusModel.TREE_FRAME_CUT_U,
			forestFlipped:Bool = false):Void {
		buildStatic(parent, twists);
		buildForest(parent, twists, forest, forestCutU, forestFlipped);
	}

	public static function buildStatic(parent:h3d.scene.Object, twists:Int):Void {
		buildBackdrop(parent);
		buildGround(parent, twists);
		buildWalls(parent, twists);
	}

	static function buildGround(parent:h3d.scene.Object, twists:Int):Void {
		var points:Array<h3d.Vector> = [];
		var idx = new hxd.IndexBuffer();
		var uvs:Array<h3d.prim.UV> = [];

		var bandWidth = 2 * MobiusModel.HALF_WIDTH / V_SEGMENTS;
		for (band in 0...V_SEGMENTS) {
			var vLo = -MobiusModel.HALF_WIDTH + band * bandWidth;
			var vHi = vLo + bandWidth;
			addTexturedBandStrip(points, idx, uvs, vLo, vHi, twists);
		}

		var grassTexture = hxd.Res.textures.grass.toTexture();
		grassTexture.wrap = Repeat;
		buildTexturedMesh(parent, points, idx, uvs, grassTexture);
	}

	static function buildWalls(parent:h3d.scene.Object, twists:Int):Void {
		var points:Array<h3d.Vector> = [];
		var idx = new hxd.IndexBuffer();
		var uvs:Array<h3d.prim.UV> = [];

		for (edgeSign in [-1, 1]) {
			addWallCap(points, idx, uvs, twists, edgeSign, MobiusModel.WALL_HEIGHT);
			addWallCap(points, idx, uvs, twists, edgeSign, -MobiusModel.WALL_HEIGHT);
			addWallSides(points, idx, uvs, twists, edgeSign);
		}

		var wallTexture = hxd.Res.textures.wall_stone.toTexture();
		wallTexture.wrap = Repeat;
		buildTexturedMesh(parent, points, idx, uvs, wallTexture);
	}

	/** The whole forest's own trunks and foliage, chunked (see `TREES_PER_CHUNK`'s own doc) into as few draw calls as the index-buffer limit allows. **/
	public static function buildForest(parent:h3d.scene.Object, twists:Int, forest:ForestLayout, forestCutU:Float, forestFlipped:Bool):Void {
		var fromIndex = 0;
		while (fromIndex < forest.trees.length) {
			var toIndex = hxd.Math.imin(fromIndex + TREES_PER_CHUNK, forest.trees.length);
			buildForestChunk(parent, twists, forest, fromIndex, toIndex, forestCutU, forestFlipped);
			fromIndex = toIndex;
		}
	}

	/** One forest chunk's own trunk and foliage meshes, covering trees `fromIndex` (inclusive) to `toIndex` (exclusive). **/
	static function buildForestChunk(parent:h3d.scene.Object, twists:Int, forest:ForestLayout, fromIndex:Int, toIndex:Int, forestCutU:Float,
			forestFlipped:Bool):Void {
		for (i in fromIndex...toIndex) {
			var tree = forest.trees[i];
			var frame = MobiusMath.localFrameWithCutAndOrientationAt(tree.u, tree.v, twists, MobiusModel.RADIUS, forestCutU, forestFlipped);
			addImportedTree(parent, tree, frame, i);
		}
	}

	static function addImportedTree(parent:h3d.scene.Object, tree:MobiusForestGenerator.PlacedTree, frame:{
		tu:h3d.Vector,
		tv:h3d.Vector,
		normal:h3d.Vector,
		tuLength:Float
	}, treeIndex:Int):Void {
		var variantIndex = importedTreeVariantIndex(treeIndex);
		var holder = new h3d.scene.Object(parent);
		holder.setPosition(tree.x
			+ frame.normal.x * MobiusModel.TREE_ROOT_LIFT, tree.y
			+ frame.normal.y * MobiusModel.TREE_ROOT_LIFT,
			tree.z
			+ frame.normal.z * MobiusModel.TREE_ROOT_LIFT);
		var tangent = frame.tu.scaled(Math.cos(tree.rotation)).add(frame.tv.scaled(Math.sin(tree.rotation))).normalized();
		holder.setDirection(frame.normal, tangent);
		holder.setScale((tree.trunkHeight + tree.foliageHeight) / importedTreeHeights[variantIndex]);

		var aligner = new h3d.scene.Object(holder);
		aligner.setRotation(importedTreeAlignmentRot.rx, importedTreeAlignmentRot.ry, importedTreeAlignmentRot.rz);

		var model = getImportedTreePrototype(variantIndex).clone();
		var pivot = importedTreePivots[variantIndex];
		model.setPosition(-pivot.x, -pivot.y, -pivot.z - importedTreeGroundBias);
		aligner.addChild(model);
	}

	static inline function importedTreeVariantIndex(treeIndex:Int):Int {
		return treeIndex % IMPORTED_TREE_MODEL_PATHS.length;
	}

	/** Rotate the shared alignment on one axis (0=X, 1=Y, 2=Z). Invalidates all prototypes. **/
	public static function rotateImportedTreeAlignment(axis:Int, direction:Int = 1):Void {
		var delta = ROTATION_STEP * (direction < 0 ? -1.0 : 1.0);
		switch (axis) {
			case 0:
				importedTreeAlignmentRot.rx = normalizeAngle(importedTreeAlignmentRot.rx + delta);
			case 1:
				importedTreeAlignmentRot.ry = normalizeAngle(importedTreeAlignmentRot.ry + delta);
			case 2:
				importedTreeAlignmentRot.rz = normalizeAngle(importedTreeAlignmentRot.rz + delta);
			default:
				return;
		}
		invalidateAllImportedTreePrototypes();
	}

	/** Nudge the shared ground offset up/down. No prototype invalidation needed — applied at placement time. **/
	public static function adjustImportedTreeGroundBias(direction:Int = 1):Void {
		importedTreeGroundBias = hxd.Math.clamp(importedTreeGroundBias + GROUND_BIAS_STEP * (direction < 0 ? -1.0 : 1.0), -1.0, 6.0);
	}

	public static function importedTreeDebugLabel():String {
		return
			'trees alignment (rx=${angleDegreesLabel(importedTreeAlignmentRot.rx)}, ry=${angleDegreesLabel(importedTreeAlignmentRot.ry)}, rz=${angleDegreesLabel(importedTreeAlignmentRot.rz)}, offset=${hxd.Math.fmt(importedTreeGroundBias)})';
	}

	static inline function angleDegreesLabel(radians:Float):String {
		return Std.string(Math.round(radians * 180 / Math.PI));
	}

	static function normalizeAngle(radians:Float):Float {
		var wrapped = radians % (2 * Math.PI);
		if (wrapped > Math.PI) {
			wrapped -= 2 * Math.PI;
		} else if (wrapped < -Math.PI) {
			wrapped += 2 * Math.PI;
		}
		return wrapped;
	}

	static function invalidateAllImportedTreePrototypes():Void {
		importedTreePrototypes = [];
		importedTreeHeights = [];
		importedTreePivots = [];
	}

	static function getImportedTreePrototype(variantIndex:Int):h3d.scene.Object {
		if (importedTreePrototypes[variantIndex] != null) {
			return importedTreePrototypes[variantIndex];
		}
		var path = IMPORTED_TREE_MODEL_PATHS[variantIndex];
		var parts = path.split("/");
		var fileName = parts[parts.length - 1];
		var modelName = fileName.substr(0, fileName.length - 4); // strip ".fbx"
		var resource = hxd.Res.load(path).to(hxd.res.Model);
		var root = importedTreeModelCache.loadModel(resource);
		root.applyAnimationTransform();
		var found = root.find(o -> o.name == modelName ? o : null);
		if (found == null) {
			found = root;
		}
		found.applyAnimationTransform();
		var bounds = found.getBounds();
		var metrics = importedTreeMetrics(bounds, found);
		importedTreeHeights[variantIndex] = metrics.height;
		importedTreePivots[variantIndex] = metrics.pivot;
		for (mesh in found.findAll(function(o:h3d.scene.Object):Null<h3d.scene.Mesh> {
			return Std.downcast(o, h3d.scene.Mesh);
		})) {
			mesh.material.mainPass.culling = None;
		}
		applyImportedTreeMaterials(found, modelName);
		importedTreePrototypes[variantIndex] = found.clone();
		return importedTreePrototypes[variantIndex];
	}

	static function importedTreeMetrics(bounds:h3d.col.Bounds, found:h3d.scene.Object):{height:Float, pivot:h3d.Vector} {
		var alignment = importedTreeAlignmentRot;
		var q = new h3d.Quat();
		q.initRotation(alignment.rx, alignment.ry, alignment.rz);
		var alignMatrix = q.toMatrix();
		var inverseAlign = alignMatrix.clone();
		inverseAlign.invert();

		var lx0 = bounds.xMin - found.x;
		var lx1 = bounds.xMax - found.x;
		var ly0 = bounds.yMin - found.y;
		var ly1 = bounds.yMax - found.y;
		var lz0 = bounds.zMin - found.z;
		var lz1 = bounds.zMax - found.z;
		var corners = [
			new h3d.Vector(lx0, ly0, lz0),
			new h3d.Vector(lx0, ly0, lz1),
			new h3d.Vector(lx0, ly1, lz0),
			new h3d.Vector(lx0, ly1, lz1),
			new h3d.Vector(lx1, ly0, lz0),
			new h3d.Vector(lx1, ly0, lz1),
			new h3d.Vector(lx1, ly1, lz0),
			new h3d.Vector(lx1, ly1, lz1)
		];

		var axMin = 1e30;
		var axMax = -1e30;
		var ayMin = 1e30;
		var ayMax = -1e30;
		var azMin = 1e30;
		var azMax = -1e30;
		for (corner in corners) {
			var aligned = corner.transformed3x3(alignMatrix);
			if (aligned.x < axMin)
				axMin = aligned.x;
			if (aligned.x > axMax)
				axMax = aligned.x;
			if (aligned.y < ayMin)
				ayMin = aligned.y;
			if (aligned.y > ayMax)
				ayMax = aligned.y;
			if (aligned.z < azMin)
				azMin = aligned.z;
			if (aligned.z > azMax)
				azMax = aligned.z;
		}

		var pivotAligned = new h3d.Vector(axMin, (ayMin + ayMax) * 0.5, (azMin + azMax) * 0.5);
		var pivotLocal = pivotAligned.transformed3x3(inverseAlign);
		return {
			height: axMax - axMin,
			pivot: pivotLocal
		};
	}

	static function applyImportedTreeMaterials(object:h3d.scene.Object, modelName:String):Void {
		for (mesh in object.findAll(function(o:h3d.scene.Object):Null<h3d.scene.Mesh> {
			return Std.downcast(o, h3d.scene.Mesh);
		})) {
			var multi = Std.downcast(mesh, h3d.scene.MultiMaterial);
			if (multi != null) {
				for (i in 0...multi.materials.length) {
					multi.materials[i] = makeImportedTreeMaterial(multi.materials[i], modelName, i, multi.materials.length);
				}
				multi.material = multi.materials[0];
			} else {
				mesh.material = makeImportedTreeMaterial(mesh.material, modelName, 0, 1);
			}
		}
	}

	static function makeImportedTreeMaterial(original:h3d.mat.Material, modelName:String, materialIndex:Int, materialCount:Int):h3d.mat.Material {
		if (original == null) {
			return null;
		}
		var color = isImportedTreeFoliageMaterial(original.name, materialIndex, materialCount) ? IMPORTED_TREE_FOLIAGE_COLOR : IMPORTED_TREE_BARK_COLOR;
		var material = h3d.mat.Material.create();
		material.name = original.name;
		var props:Dynamic = material.getDefaultProps();
		props.light = false;
		props.shadows = false;
		props.culling = false;
		material.props = props;
		material.mainPass.culling = None;
		material.color.setColor(color);
		material.specularAmount = 0;
		material.specularPower = 0;
		material.shadows = false;
		return material;
	}

	static function isImportedTreeFoliageMaterial(name:String, materialIndex:Int, materialCount:Int):Bool {
		var lowered = name.toLowerCase();
		return lowered.indexOf("leaf") >= 0
			|| lowered.indexOf("leaves") >= 0
			|| lowered.indexOf("foliage") >= 0
			|| (materialCount == 2 && materialIndex == 1);
	}

	/** One across-width band's own quad strip, `v` fixed to `vLo`/`vHi`, `u` swept the whole way around `[0, 2*PI]`. **/
	static function addTexturedBandStrip(points:Array<h3d.Vector>, idx:hxd.IndexBuffer, uvs:Array<h3d.prim.UV>, vLo:Float, vHi:Float, twists:Int):Void {
		var step = 2 * Math.PI / U_SEGMENTS;
		for (i in 0...U_SEGMENTS) {
			var u0 = i * step;
			var u1 = (i + 1) * step;
			var loA = MobiusMath.pointAt(u0, vLo, twists, MobiusModel.RADIUS);
			var hiA = MobiusMath.pointAt(u0, vHi, twists, MobiusModel.RADIUS);
			var loB = MobiusMath.pointAt(u1, vLo, twists, MobiusModel.RADIUS);
			var hiB = MobiusMath.pointAt(u1, vHi, twists, MobiusModel.RADIUS);
			MeshBuilder.addQuad(points, idx, loA, loB, hiB, hiA);
			addQuadUvs(uvs, uRepeatAt(u0), uRepeatAt(u1), acrossRepeatAt(vLo), acrossRepeatAt(vHi));
		}
	}

	static function addWallCap(points:Array<h3d.Vector>, idx:hxd.IndexBuffer, uvs:Array<h3d.prim.UV>, twists:Int, edgeSign:Int, heightOffset:Float):Void {
		var outerV = edgeSign * MobiusModel.HALF_WIDTH;
		var innerV = edgeSign * (MobiusModel.HALF_WIDTH - MobiusModel.WALL_THICKNESS);
		var step = 2 * Math.PI / U_SEGMENTS;
		for (i in 0...U_SEGMENTS) {
			var u0 = i * step;
			var u1 = (i + 1) * step;
			var innerBaseA = MobiusMath.pointAt(u0, innerV, twists, MobiusModel.RADIUS);
			var innerBaseB = MobiusMath.pointAt(u1, innerV, twists, MobiusModel.RADIUS);
			var outerBaseA = MobiusMath.pointAt(u0, outerV, twists, MobiusModel.RADIUS);
			var outerBaseB = MobiusMath.pointAt(u1, outerV, twists, MobiusModel.RADIUS);
			var innerFrameA = MobiusMath.localFrameAt(u0, innerV, twists, MobiusModel.RADIUS);
			var innerFrameB = MobiusMath.localFrameAt(u1, innerV, twists, MobiusModel.RADIUS);
			var outerFrameA = MobiusMath.localFrameAt(u0, outerV, twists, MobiusModel.RADIUS);
			var outerFrameB = MobiusMath.localFrameAt(u1, outerV, twists, MobiusModel.RADIUS);
			var innerCapA = innerBaseA.add(innerFrameA.normal.scaled(heightOffset));
			var innerCapB = innerBaseB.add(innerFrameB.normal.scaled(heightOffset));
			var outerCapA = outerBaseA.add(outerFrameA.normal.scaled(heightOffset));
			var outerCapB = outerBaseB.add(outerFrameB.normal.scaled(heightOffset));
			MeshBuilder.addQuad(points, idx, innerCapA, innerCapB, outerCapB, outerCapA);
			addQuadUvs(uvs, uRepeatAt(u0), uRepeatAt(u1), 0, MobiusModel.WALL_THICKNESS / MeshBuilder.WALL_TEXTURE_TILE_SIZE);
		}
	}

	static function addWallSides(points:Array<h3d.Vector>, idx:hxd.IndexBuffer, uvs:Array<h3d.prim.UV>, twists:Int, edgeSign:Int):Void {
		var innerV = edgeSign * (MobiusModel.HALF_WIDTH - MobiusModel.WALL_THICKNESS);
		var outerV = edgeSign * MobiusModel.HALF_WIDTH;
		var step = 2 * Math.PI / U_SEGMENTS;
		for (i in 0...U_SEGMENTS) {
			var u0 = i * step;
			var u1 = (i + 1) * step;
			addWallFace(points, idx, uvs, twists, u0, u1, innerV, -MobiusModel.WALL_HEIGHT, MobiusModel.WALL_HEIGHT);
			addWallFace(points, idx, uvs, twists, u0, u1, outerV, -MobiusModel.WALL_HEIGHT, MobiusModel.WALL_HEIGHT);
		}
	}

	static function addWallFace(points:Array<h3d.Vector>, idx:hxd.IndexBuffer, uvs:Array<h3d.prim.UV>, twists:Int, u0:Float, u1:Float, v:Float,
			lowHeight:Float, highHeight:Float):Void {
		var baseA = MobiusMath.pointAt(u0, v, twists, MobiusModel.RADIUS);
		var baseB = MobiusMath.pointAt(u1, v, twists, MobiusModel.RADIUS);
		var frameA = MobiusMath.localFrameAt(u0, v, twists, MobiusModel.RADIUS);
		var frameB = MobiusMath.localFrameAt(u1, v, twists, MobiusModel.RADIUS);
		var lowA = baseA.add(frameA.normal.scaled(lowHeight));
		var lowB = baseB.add(frameB.normal.scaled(lowHeight));
		var highA = baseA.add(frameA.normal.scaled(highHeight));
		var highB = baseB.add(frameB.normal.scaled(highHeight));
		MeshBuilder.addQuad(points, idx, lowA, lowB, highB, highA);
		addQuadUvs(uvs, uRepeatAt(u0), uRepeatAt(u1), 0, (highHeight - lowHeight) / MeshBuilder.WALL_TEXTURE_TILE_SIZE);
	}

	static function buildBackdrop(parent:h3d.scene.Object):Void {
		var brightStars:Array<h3d.Vector> = [];
		var brightIdx = new hxd.IndexBuffer();
		var warmStars:Array<h3d.Vector> = [];
		var warmIdx = new hxd.IndexBuffer();
		var coolStars:Array<h3d.Vector> = [];
		var coolIdx = new hxd.IndexBuffer();
		var rng = seededRandom(0x5F3759DF);

		for (i in 0...STAR_COUNT) {
			var direction = randomDirection(rng);
			var center = direction.scaled(STAR_FIELD_RADIUS);
			var radius = STAR_MIN_RADIUS + rng() * (STAR_MAX_RADIUS - STAR_MIN_RADIUS);
			var roll = rng();
			if (roll < 0.7) {
				addOctahedron(brightStars, brightIdx, center, radius);
			} else if (roll < 0.88) {
				addOctahedron(warmStars, warmIdx, center, radius);
			} else {
				addOctahedron(coolStars, coolIdx, center, radius);
			}
		}

		buildColoredMesh(parent, brightStars, brightIdx, 0xFFF6F8FF);
		buildColoredMesh(parent, warmStars, warmIdx, 0xFFFFE1A8);
		buildColoredMesh(parent, coolStars, coolIdx, 0xFFB9D7FF);

		buildPlanet(parent, new h3d.Vector(0.85, 0.35, 0.4), 260, 0xFF8458D9);
		buildPlanet(parent, new h3d.Vector(-0.62, 0.58, 0.53), 180, 0xFF6A9CDA);
		buildPlanet(parent, new h3d.Vector(-0.18, -0.42, 0.89), 320, 0xFFC26A4A);
	}

	static function buildPlanet(parent:h3d.scene.Object, direction:h3d.Vector, radius:Float, color:Int):Void {
		var mesh = new h3d.scene.Mesh(new h3d.prim.Sphere(radius, PLANET_SEGS_W, PLANET_SEGS_H), parent);
		var center = direction.normalized().scaled(PLANET_DISTANCE);
		mesh.x = center.x;
		mesh.y = center.y;
		mesh.z = center.z;
		mesh.material.mainPass.addShader(new h3d.shader.FixedColor(color));
		mesh.material.mainPass.culling = None;
	}

	static function addOctahedron(points:Array<h3d.Vector>, idx:hxd.IndexBuffer, center:h3d.Vector, radius:Float):Void {
		var px = center.add(new h3d.Vector(radius, 0, 0));
		var nx = center.add(new h3d.Vector(-radius, 0, 0));
		var py = center.add(new h3d.Vector(0, radius, 0));
		var ny = center.add(new h3d.Vector(0, -radius, 0));
		var pz = center.add(new h3d.Vector(0, 0, radius));
		var nz = center.add(new h3d.Vector(0, 0, -radius));
		MeshBuilder.addTriangle(points, idx, py, px, pz);
		MeshBuilder.addTriangle(points, idx, py, pz, nx);
		MeshBuilder.addTriangle(points, idx, py, nx, nz);
		MeshBuilder.addTriangle(points, idx, py, nz, px);
		MeshBuilder.addTriangle(points, idx, ny, pz, px);
		MeshBuilder.addTriangle(points, idx, ny, nx, pz);
		MeshBuilder.addTriangle(points, idx, ny, nz, nx);
		MeshBuilder.addTriangle(points, idx, ny, px, nz);
	}

	static function randomDirection(rng:Void->Float):h3d.Vector {
		var z = 1 - 2 * rng();
		var phi = 2 * Math.PI * rng();
		var r = Math.sqrt(1 - z * z);
		return new h3d.Vector(r * Math.cos(phi), z, r * Math.sin(phi));
	}

	static function seededRandom(seed:Int):Void->Float {
		var state = seed;
		return () -> {
			state += 0x6D2B79F5;
			var t = state;
			t = (t ^ (t >>> 15)) * (t | 1);
			t ^= t + (t ^ (t >>> 7)) * (t | 61);
			return ((t ^ (t >>> 14)) >>> 0) / 4294967296.0;
		};
	}

	static function addQuadUvs(uvs:Array<h3d.prim.UV>, u0:Float, u1:Float, v0:Float, v1:Float):Void {
		uvs.push(new h3d.prim.UV(u0, v0));
		uvs.push(new h3d.prim.UV(u1, v0));
		uvs.push(new h3d.prim.UV(u1, v1));
		uvs.push(new h3d.prim.UV(u0, v1));
	}

	static inline function uRepeatAt(u:Float):Float {
		return u * MobiusModel.RADIUS / MeshBuilder.WALL_TEXTURE_TILE_SIZE;
	}

	static inline function acrossRepeatAt(v:Float):Float {
		return (v + MobiusModel.HALF_WIDTH) / MeshBuilder.WALL_TEXTURE_TILE_SIZE;
	}

	static function buildColoredMesh(parent:h3d.scene.Object, points:Array<h3d.Vector>, idx:hxd.IndexBuffer, color:Int):Void {
		var mesh = new h3d.scene.Mesh(new h3d.prim.Polygon(points, idx), parent);
		mesh.material.mainPass.addShader(new h3d.shader.FixedColor(color));
		mesh.material.mainPass.culling = None;
	}

	static function buildTexturedMesh(parent:h3d.scene.Object, points:Array<h3d.Vector>, idx:hxd.IndexBuffer, uvs:Array<h3d.prim.UV>,
			texture:h3d.mat.Texture):Void {
		var prim = new h3d.prim.Polygon(points, idx);
		prim.uvs = uvs;
		var mesh = new h3d.scene.Mesh(prim, parent);
		mesh.material.mainPass.addShader(new UnlitTexture(texture));
		mesh.material.mainPass.culling = None;
	}

	/** One base-to-tip gradient-shaded mesh (`graphics.shaders.HeightGradient`) — trunks/foliage, per `TreeMesh`'s own UV convention. Same `culling = None` reasoning `buildColoredMesh` already gives. **/
	static function buildGradientMesh(parent:h3d.scene.Object, points:Array<h3d.Vector>, idx:hxd.IndexBuffer, uvs:Array<h3d.prim.UV>, colorBase:Int,
			colorTip:Int):Void {
		var prim = new h3d.prim.Polygon(points, idx);
		prim.uvs = uvs;
		var mesh = new h3d.scene.Mesh(prim, parent);
		mesh.material.mainPass.addShader(new graphics.shaders.HeightGradient(colorBase, colorTip));
		mesh.material.mainPass.culling = None;
	}
}

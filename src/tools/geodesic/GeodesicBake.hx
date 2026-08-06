package tools.geodesic;

/**
	Build-time entry point: generate a geodesic sphere at `FREQUENCY`,
	validate it, and write it to `res/geodesic/conway-sphere.json` — a
	checked-in data asset loaded through `hxd.Res` at runtime, not
	recomputed live (see the engineering note's own "not lazy-on-boot"
	requirement). Run via `make bake-geodesic`, compiled by `bake.hxml`
	against a native target (`neko`) rather than this project's usual
	`-js`, since writing a file needs `sys.io.File` and the game itself
	never does — and since `tools.geodesic` has no dependency on Heaps,
	nothing about the game engine needs to compile for this to run.
**/
class GeodesicBake {
	/**
		`10 * FREQUENCY² + 2` total nodes — see `GeodesicSphere.generate`'s
		own doc. Chosen to land in the same order of magnitude as
		`ConwayGrid`'s current ~1234-cell lat/long grid
		(`10 * 11 * 11 + 2 = 1212`) — a starting point for pacing, not a
		final tuned value; retuning this is exactly what re-running
		`make bake-geodesic` is for.
	**/
	static inline final FREQUENCY:Int = 11;

	static inline final OUTPUT_PATH:String = "res/geodesic/conway-sphere.json";

	public static function main():Void {
		var sphere = GeodesicSphere.generate(FREQUENCY);
		var problems = GeodesicValidator.validate(sphere, FREQUENCY);
		if (problems.length > 0) {
			Sys.println("geodesic bake failed validation:");
			for (problem in problems) {
				Sys.println(' - $problem');
			}
			Sys.exit(1);
			return;
		}

		var json = haxe.Json.stringify({
			frequency: FREQUENCY,
			positions: [for (p in sphere.positions) {x: p.x, y: p.y, z: p.z}],
			neighbors: sphere.neighbors,
			pentagons: GeodesicSphere.pentagons(sphere),
		});

		var dir = haxe.io.Path.directory(OUTPUT_PATH);
		if (!sys.FileSystem.exists(dir)) {
			sys.FileSystem.createDirectory(dir);
		}
		sys.io.File.saveContent(OUTPUT_PATH, json);
		Sys.println('baked ${sphere.neighbors.length} nodes (${GeodesicSphere.pentagons(sphere).length} pentagons) to $OUTPUT_PATH');
	}
}

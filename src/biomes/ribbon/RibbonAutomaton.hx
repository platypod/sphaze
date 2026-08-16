package biomes.ribbon;

/**
	An **elementary cellular automaton** — Wolfram's one-dimensional,
	two-state, three-neighbour family — run forward from a single live
	cell and kept as its whole history, generation by generation.

	The history is the point. Everywhere else in this project a CA's past
	is discarded the instant the next generation is computed; here the
	stack of generations *is* the biome's terrain (see `RibbonBiome`), so
	this class deliberately keeps every row rather than stepping in place.

	**Why elementary rather than the Ventrella rule the Fold uses.** The
	Ribbon exists to say "this world is really a computation," and
	`docs/game-design/direction/world-and-threads.md` names the strongest
	available evidence for that: Rule 110 is Turing-complete (Cook, 2004).
	A player who has spent hours in a cellular world should be able to walk
	on a proof rather than be told about one. Elementary rules are also the
	only family whose entire spacetime diagram is two-dimensional, which is
	what makes "the past is terrain" expressible as terrain at all.

	Pure and Heaps-free, like `geometry`: the whole class is arithmetic on
	`Bool`s, and it is tested against hand-computable properties rather
	than against a screenshot.
**/
class RibbonAutomaton {
	/** Which rule was run, 0-255 in Wolfram's own numbering — the byte whose bit `n` gives the successor of neighbourhood `n`. **/
	public final rule:Int;

	/** Cells per generation. **/
	public final width:Int;

	/**
		`rows[g][i]` — whether cell `i` is live in generation `g`. Index `0`
		is the **initial condition**, the oldest generation, which is the
		one the player walks north to reach.
	**/
	public final rows:Array<Array<Bool>>;

	/**
		Runs `rule` forward from a single live cell.

		Cells beyond either edge count as dead rather than wrapping. A
		wrapped strip would be a cylinder, and this space is deliberately
		*a line* — an edge that stays dead is the honest boundary, and it
		reads as the diagram simply not extending that far.
		@param rule the elementary rule number, 0-255.
		@param width cells per generation; must be at least 1.
		@param generations how many rows to compute, including the initial condition; must be at least 1.
		@param seedIndex which cell starts live.
	**/
	public function new(rule:Int, width:Int, generations:Int, seedIndex:Int) {
		if (width < 1 || generations < 1) {
			throw "a ribbon needs at least one cell and one generation";
		}
		if (seedIndex < 0 || seedIndex >= width) {
			throw 'seed index $seedIndex is outside a strip of width $width';
		}
		this.rule = rule;
		this.width = width;

		rows = [[for (i in 0...width) i == seedIndex]];
		for (g in 1...generations) {
			rows.push(step(rows[g - 1]));
		}
	}

	/** How many generations were computed, including the initial condition. **/
	public function generations():Int {
		return rows.length;
	}

	/**
		Whether a cell is live, with anything off the diagram reading as
		dead — so callers (collision, mesh building) never have to bounds-
		check first.
		@param generation row index; `0` is the initial condition.
		@param index cell index within the row.
		@return true if that cell exists and is live.
	**/
	public function isLive(generation:Int, index:Int):Bool {
		if (generation < 0 || generation >= rows.length || index < 0 || index >= width) {
			return false;
		}
		return rows[generation][index];
	}

	/**
		One generation, from the three-cell neighbourhood of each cell.

		The neighbourhood `(left, self, right)` is read as a three-bit
		number and the rule's bit at that position is the successor — which
		*is* Wolfram's numbering, not an encoding chosen here, so a reader
		can check any row of this against a published Rule 110 diagram
		directly.
		@param previous the generation to advance.
		@return the next generation.
	**/
	function step(previous:Array<Bool>):Array<Bool> {
		return [
			for (i in 0...width) {
				var left = i > 0 && previous[i - 1] ? 4 : 0;
				var self = previous[i] ? 2 : 0;
				var right = i < width - 1 && previous[i + 1] ? 1 : 0; (rule >> (left + self + right)) & 1 == 1;
			}
		];
	}
}

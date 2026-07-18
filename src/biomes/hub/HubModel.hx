package biomes.hub;

/**
	The hub's own fixed scale and spawn point. Everything else that makes
	the room what it is — the shell/grass `HubMesh` builds directly, and
	the two landmark structures (`MazeShrine`, `TowerReplica`) — is either
	scale-free or anchored via its own `HubStructure` local frame, so
	nothing else needs to live here.

	This used to also carry a central octagonal column, kept purely to
	mount each biome's to-biome painting on one of its faces — removed
	entirely once paintings moved into freestanding buildings instead (see
	`docs/PROJECT_LOG.md`'s entry on the redesign). The column's own
	near-pole mounting turned out to be a genuine, numerically-confirmed
	squeeze between the rising floor and the column's own end cap, fought
	across several rounds of retuning; an ordinary building standing
	anywhere on this sphere's open floor, away from either pole, simply
	doesn't have that problem, which is what actually made the column
	worth removing rather than continuing to retune.
**/
class HubModel {
	/** This sphere's own radius. **/
	public static inline final RADIUS:Float = 70;

	/** Where the player spawns entering the hub: the equator — the room's widest, most open point. **/
	public static final SPAWN_THETA:Float = Math.PI / 2;

	public static final SPAWN_PHI:Float = 0;
}

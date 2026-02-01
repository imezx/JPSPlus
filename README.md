# JPSPlus

JPSPlus is a high-performance **2D grid pathfinding** library for Roblox based on **Jump Point Search Plus (JPS+)** algorithm. It preprocesses static maps to enable very fast A* queries by “jumping” between critical nodes while preserving **optimal** paths on uniform-cost grids.

**The Concept:**
Traditional **Jump Point Search (JPS)** was originally developed as a superior competitor to standard A* for 2D grids, designed to speed up search by "jumping" over redundant nodes rather than checking every neighbor. **JPS+** takes this evolution a step further by using **preprocessing** to pre-calculate these jump distances. This results in ultra-fast queries that maintain A*'s **optimality** but with significantly reduced runtime overhead on static maps.

## When to use
Best for:
- top-down / flat worlds
- maze/indoor navigation on a plane
- many repeated queries on mostly static maps

## When NOT to use
Avoid if:
- **dynamic maps:** If your map changes every few seconds (e.g., destructible terrain), the cost of repeatedly "baking" the map data outweighs the search speed benefits.
- **Weighted Terrain:** If you need movement penalties (e.g., "mud is slower than grass"), use standard A*. JPS relies on uniform costs to skip nodes safely.
- **complex 3D verticality:** This is strictly for 2D grids; it does not handle multi-floor navigation natively without logical separation.

## Limitations
- 2D grid navigation (X/Z plane); not a 3D navmesh
- Static or mostly-static obstacles (changing obstacles require rebuild or custom updates)
- Uniform movement costs (no weighted terrain without modification)

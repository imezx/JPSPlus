# JPSPlus

JPSPlus is a high-performance **2D grid pathfinding** library for Roblox based on **Jump Point Search Plus (JPS+)** algorithm. It preprocesses static maps to enable very fast A* queries by “jumping” between critical nodes while preserving **optimal** paths on uniform-cost grids.

## When to use
Best for:
- top-down / flat worlds
- maze/indoor navigation on a plane
- many repeated queries on mostly static maps

## Limitations
- 2D grid navigation (X/Z plane); not a 3D navmesh
- Static or mostly-static obstacles (changing obstacles require rebuild or custom updates)
- Uniform movement costs (no weighted terrain without modification)

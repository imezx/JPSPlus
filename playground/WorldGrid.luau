local WorldGrid = {}
WorldGrid.__index = WorldGrid

function WorldGrid.new(origin: Vector3, cellSize: number, width: number, height: number)
	return setmetatable({
		Origin = origin,
		CellSize = cellSize,
		Width = width,
		Height = height,
	}, WorldGrid)
end

function WorldGrid:worldToCell(pos: Vector3)
	local p = pos - self.Origin
	local x = math.floor(p.X / self.CellSize) + 1
	local y = math.floor(p.Z / self.CellSize) + 1

	if x < 1 or x > self.Width or y < 1 or y > self.Height then
		return nil
	end
	return x, y
end

function WorldGrid:cellToWorldCenter(x: number, y: number)
	return self.Origin + Vector3.new((x - 0.5) * self.CellSize, 0, (y - 0.5) * self.CellSize)
end

return WorldGrid

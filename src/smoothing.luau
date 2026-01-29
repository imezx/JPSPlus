--!native
--!optimize 2
local Smoothing = {}

local function hasLOS(grid, x0, y0, x1, y1)
	local dx = math.abs(x1 - x0)
	local dy = math.abs(y1 - y0)
	local sx = (x0 < x1) and 1 or -1
	local sy = (y0 < y1) and 1 or -1
	local err = dx - dy

	while true do
		if not grid:isWalkableId(grid:id(x0, y0)) then
			return false
		end
		if x0 == x1 and y0 == y1 then break end
		local e2 = 2 * err
		if e2 > -dy then err -= dy; x0 += sx end
		if e2 <  dx then err += dx; y0 += sy end
	end

	return true
end

function Smoothing.simplify(grid, path)
	if not path or #path <= 2 then return path end
	local out = { path[1] }
	local i = 1
	while i < #path do
		local best = i + 1
		for j = #path, i + 1, -1 do
			if hasLOS(grid, path[i].x, path[i].y, path[j].x, path[j].y) then
				best = j
				break
			end
		end
		table.insert(out, path[best])
		i = best
	end
	return out
end

return Smoothing
